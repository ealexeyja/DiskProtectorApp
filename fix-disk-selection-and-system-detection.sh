#!/bin/bash

# Actualizar el modelo de datos para manejar mejor la selección y estado del disco del sistema
cat > src/DiskProtectorApp/Models/DiskInfo.cs << 'MODELEOF'
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace DiskProtectorApp.Models
{
    public class DiskInfo : INotifyPropertyChanged
    {
        private bool _isSelected;
        private bool _isSelectable = true;
        private string? _driveLetter;
        private string? _volumeName;
        private string? _totalSize;
        private string? _freeSpace;
        private string? _fileSystem;
        private string? _diskType;
        private string? _protectionStatus;
        private bool _isProtected;

        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                if (_isSelectable)
                {
                    _isSelected = value;
                    OnPropertyChanged();
                }
            }
        }

        public bool IsSelectable
        {
            get => _isSelectable;
            set
            {
                _isSelectable = value;
                OnPropertyChanged();
                // Si no es seleccionable, deseleccionar
                if (!value && _isSelected)
                {
                    IsSelected = false;
                }
            }
        }

        public string? DriveLetter
        {
            get => _driveLetter;
            set
            {
                _driveLetter = value;
                OnPropertyChanged();
            }
        }

        public string? VolumeName
        {
            get => _volumeName;
            set
            {
                _volumeName = value;
                OnPropertyChanged();
            }
        }

        public string? TotalSize
        {
            get => _totalSize;
            set
            {
                _totalSize = value;
                OnPropertyChanged();
            }
        }

        public string? FreeSpace
        {
            get => _freeSpace;
            set
            {
                _freeSpace = value;
                OnPropertyChanged();
            }
        }

        public string? FileSystem
        {
            get => _fileSystem;
            set
            {
                _fileSystem = value;
                OnPropertyChanged();
            }
        }

        public string? DiskType
        {
            get => _diskType;
            set
            {
                _diskType = value;
                OnPropertyChanged();
            }
        }

        public string? ProtectionStatus
        {
            get => _protectionStatus;
            set
            {
                _protectionStatus = value;
                OnPropertyChanged();
            }
        }

        public bool IsProtected
        {
            get => _isProtected;
            set
            {
                _isProtected = value;
                ProtectionStatus = value ? "Protegido" : "Desprotegido";
                OnPropertyChanged();
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
MODELEOF

# Actualizar el servicio de discos para mejor detección del sistema y manejo de selección
cat > src/DiskProtectorApp/Services/DiskService.cs << 'SERVICESDISKEOF'
using DiskProtectorApp.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Management;
using System.Security.AccessControl;
using System.Security.Principal;

namespace DiskProtectorApp.Services
{
    public class DiskService
    {
        public List<DiskInfo> GetDisks()
        {
            var disks = new List<DiskInfo>();
            var systemDrive = Path.GetPathRoot(Environment.SystemDirectory);

            foreach (var drive in DriveInfo.GetDrives())
            {
                try
                {
                    // Solo procesar discos fijos con sistema de archivos NTFS
                    if (drive.DriveType != DriveType.Fixed || drive.DriveFormat != "NTFS")
                    {
                        continue;
                    }

                    var disk = new DiskInfo
                    {
                        DriveLetter = drive.Name,
                        VolumeName = drive.VolumeLabel ?? "Sin etiqueta",
                        TotalSize = FormatBytes(drive.TotalSize),
                        FreeSpace = $"{FormatBytes(drive.TotalFreeSpace)} ({(double)drive.TotalFreeSpace / drive.TotalSize * 100:F1}%)",
                        FileSystem = drive.DriveFormat,
                        DiskType = IsSSD(drive.Name) ? "SSD" : "HDD",
                        IsProtected = IsDriveProtected(drive.RootDirectory.FullName),
                        IsSelected = false
                    };

                    // Marcar el disco del sistema
                    if (drive.Name.Equals(systemDrive, StringComparison.OrdinalIgnoreCase))
                    {
                        disk.VolumeName += " (Sistema)";
                        disk.IsSelectable = false;
                        disk.ProtectionStatus = "No Elegible (disco de sistema)";
                    }

                    disks.Add(disk);
                }
                catch (Exception ex)
                {
                    // Loggear errores pero continuar con otros discos
                    Console.WriteLine($"Error procesando disco {drive.Name}: {ex.Message}");
                }
            }

            return disks;
        }

        private bool IsSSD(string driveName)
        {
            try
            {
                var driveLetter = driveName.TrimEnd('\\');
                var searcher = new ManagementObjectSearcher($"SELECT * FROM Win32_PhysicalMedia WHERE Tag LIKE '%{driveLetter}%'");
                
                foreach (ManagementObject queryObj in searcher.Get())
                {
                    var mediaType = queryObj["MediaType"]?.ToString();
                    if (!string.IsNullOrEmpty(mediaType) && mediaType.Contains("SSD"))
                        return true;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error determinando tipo de disco para {driveName}: {ex.Message}");
            }

            return false;
        }

        private bool IsDriveProtected(string drivePath)
        {
            try
            {
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                // Verificar si el usuario actual tiene acceso denegado
                var currentUser = WindowsIdentity.GetCurrent().Name;
                foreach (FileSystemAccessRule rule in rules)
                {
                    if (rule.IdentityReference.Value.Equals(currentUser, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Deny &&
                        (rule.FileSystemRights & FileSystemRights.FullControl) == FileSystemRights.FullControl)
                    {
                        return true;
                    }
                }

                return false;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
                return false;
            }
        }

        public bool ProtectDrive(string drivePath)
        {
            try
            {
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                
                // Denegar acceso al usuario actual
                var currentUser = WindowsIdentity.GetCurrent();
                var rule = new FileSystemAccessRule(
                    currentUser.Name,
                    FileSystemRights.FullControl,
                    InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                    PropagationFlags.None,
                    AccessControlType.Deny);
                
                security.AddAccessRule(rule);
                directoryInfo.SetAccessControl(security);
                
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error protegiendo disco {drivePath}: {ex.Message}");
                return false;
            }
        }

        public bool UnprotectDrive(string drivePath)
        {
            try
            {
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));
                
                var currentUser = WindowsIdentity.GetCurrent().Name;
                var rulesToRemove = new List<FileSystemAccessRule>();
                
                foreach (FileSystemAccessRule rule in rules)
                {
                    if (rule.IdentityReference.Value.Equals(currentUser, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Deny &&
                        (rule.FileSystemRights & FileSystemRights.FullControl) == FileSystemRights.FullControl)
                    {
                        rulesToRemove.Add(rule);
                    }
                }
                
                foreach (var rule in rulesToRemove)
                {
                    security.RemoveAccessRule(rule);
                }
                
                directoryInfo.SetAccessControl(security);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error desprotegiendo disco {drivePath}: {ex.Message}");
                return false;
            }
        }

        private string FormatBytes(long bytes)
        {
            string[] sizes = { "B", "KB", "MB", "GB", "TB" };
            double len = bytes;
            int order = 0;
            while (len >= 1024 && order < sizes.Length - 1)
            {
                order++;
                len = len / 1024;
            }
            return $"{len:0.##} {sizes[order]}";
        }
    }
}
SERVICESDISKEOF

# Actualizar el ViewModel para manejar mejor la lógica de selección
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'VIEWMODELEOF'
using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Windows.Input;

namespace DiskProtectorApp.ViewModels
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private readonly DiskService _diskService;
        private readonly OperationLogger _logger;
        private ObservableCollection<DiskInfo> _disks = new();
        private string _statusMessage = "Listo";
        private bool _isWorking;

        public ObservableCollection<DiskInfo> Disks
        {
            get => _disks;
            set
            {
                _disks = value;
                OnPropertyChanged();
            }
        }

        public string StatusMessage
        {
            get => _statusMessage;
            set
            {
                _statusMessage = value;
                OnPropertyChanged();
            }
        }

        public bool IsWorking
        {
            get => _isWorking;
            set
            {
                _isWorking = value;
                OnPropertyChanged();
                // Notificar que los comandos pueden haber cambiado
                ((RelayCommand)ProtectCommand).RaiseCanExecuteChanged();
                ((RelayCommand)UnprotectCommand).RaiseCanExecuteChanged();
            }
        }

        public ICommand ProtectCommand { get; }
        public ICommand UnprotectCommand { get; }
        public ICommand RefreshCommand { get; }

        public MainViewModel()
        {
            _diskService = new DiskService();
            _logger = new OperationLogger();
            
            ProtectCommand = new RelayCommand(ProtectSelectedDisks, CanPerformOperation);
            UnprotectCommand = new RelayCommand(UnprotectSelectedDisks, CanPerformOperation);
            RefreshCommand = new RelayCommand(ExecuteRefreshDisks);
            
            RefreshDisks();
        }

        private void ExecuteRefreshDisks(object? parameter)
        {
            RefreshDisks();
        }

        private void RefreshDisks()
        {
            IsWorking = true;
            StatusMessage = "Actualizando lista de discos...";
            
            var disks = _diskService.GetDisks();
            Disks.Clear();
            
            foreach (var disk in disks)
            {
                Disks.Add(disk);
                // Suscribirse al cambio de propiedad para actualizar comandos
                disk.PropertyChanged += (sender, e) => {
                    if (e.PropertyName == nameof(DiskInfo.IsSelected))
                    {
                        ((RelayCommand)ProtectCommand).RaiseCanExecuteChanged();
                        ((RelayCommand)UnprotectCommand).RaiseCanExecuteChanged();
                    }
                };
            }
            
            StatusMessage = $"Se encontraron {disks.Count} discos";
            IsWorking = false;
            
            // Notificar que los comandos pueden haber cambiado
            ((RelayCommand)ProtectCommand).RaiseCanExecuteChanged();
            ((RelayCommand)UnprotectCommand).RaiseCanExecuteChanged();
        }

        private bool CanPerformOperation(object? parameter)
        {
            return !IsWorking && Disks.Any(d => d.IsSelected && d.IsSelectable);
        }

        private void ProtectSelectedDisks(object? parameter)
        {
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable).ToList();
            if (!selectedDisks.Any()) return;

            IsWorking = true;
            StatusMessage = $"Protegiendo {selectedDisks.Count} disco(s)...";

            int successCount = 0;
            
            foreach (var disk in selectedDisks)
            {
                bool success = _diskService.ProtectDrive(disk.DriveLetter ?? "");
                if (success)
                {
                    disk.IsProtected = true;
                    successCount++;
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", true);
                }
                else
                {
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                }
            }

            StatusMessage = $"Protegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // Notificar que los comandos pueden haber cambiado
            ((RelayCommand)ProtectCommand).RaiseCanExecuteChanged();
            ((RelayCommand)UnprotectCommand).RaiseCanExecuteChanged();
        }

        private void UnprotectSelectedDisks(object? parameter)
        {
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable).ToList();
            if (!selectedDisks.Any()) return;

            IsWorking = true;
            StatusMessage = $"Desprotegiendo {selectedDisks.Count} disco(s)...";

            int successCount = 0;
            foreach (var disk in selectedDisks)
            {
                bool success = _diskService.UnprotectDrive(disk.DriveLetter ?? "");
                if (success)
                {
                    disk.IsProtected = false;
                    successCount++;
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", true);
                }
                else
                {
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                }
            }

            StatusMessage = $"Desprotegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // Notificar que los comandos pueden haber cambiado
            ((RelayCommand)ProtectCommand).RaiseCanExecuteChanged();
            ((RelayCommand)UnprotectCommand).RaiseCanExecuteChanged();
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
VIEWMODELEOF

# Actualizar RelayCommand para agregar método RaiseCanExecuteChanged
cat > src/DiskProtectorApp/RelayCommand.cs << 'RELAYCOMMANDEOF'
using System;
using System.Windows.Input;

namespace DiskProtectorApp
{
    public class RelayCommand : ICommand
    {
        private readonly Action<object?> _execute;
        private readonly Predicate<object?>? _canExecute;

        public RelayCommand(Action<object?> execute, Predicate<object?>? canExecute = null)
        {
            _execute = execute ?? throw new ArgumentNullException(nameof(execute));
            _canExecute = canExecute;
        }

        public bool CanExecute(object? parameter)
        {
            return _canExecute?.Invoke(parameter) ?? true;
        }

        public void Execute(object? parameter)
        {
            _execute(parameter);
        }

        public event EventHandler? CanExecuteChanged
        {
            add { CommandManager.RequerySuggested += value; }
            remove { CommandManager.RequerySuggested -= value; }
        }

        public void RaiseCanExecuteChanged()
        {
            CommandManager.InvalidateRequerySuggested();
        }
    }
}
RELAYCOMMANDEOF

# Actualizar MainWindow.xaml para mostrar mejor el estado de los discos no seleccionables
cat > src/DiskProtectorApp/Views/MainWindow.xaml << 'MAINWINDOWXAMLEOF'
<controls:MetroWindow x:Class="DiskProtectorApp.Views.MainWindow"
                      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                      xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
                      xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
                      xmlns:controls="http://metro.mahapps.com/winfx/xaml/controls"
                      xmlns:iconPacks="http://metro.mahapps.com/winfx/xaml/iconpacks"
                      mc:Ignorable="d"
                      Title="DiskProtectorApp" Height="600" Width="1000"
                      WindowStartupLocation="CenterScreen"
                      GlowBrush="{DynamicResource AccentColorBrush}"
                      BorderThickness="1"
                      BorderBrush="{DynamicResource AccentColorBrush}"
                      Background="{DynamicResource MahApps.Brushes.ThemeBackground}"
                      Foreground="{DynamicResource MahApps.Brushes.Text}">
    
    <controls:MetroWindow.RightWindowCommands>
        <controls:WindowCommands>
            <Button Content="Ayuda" Click="HelpButton_Click"/>
        </controls:WindowCommands>
    </controls:MetroWindow.RightWindowCommands>
    
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Barra de herramientas -->
        <ToolBarTray Grid.Row="0" Background="{DynamicResource MahApps.Brushes.Gray10}">
            <ToolBar Style="{DynamicResource MahApps.Styles.ToolBar}" Background="{DynamicResource MahApps.Brushes.Gray10}">
                <Button Command="{Binding RefreshCommand}" 
                        ToolTip="Actualizar lista de discos">
                    <StackPanel Orientation="Horizontal">
                        <iconPacks:PackIconMaterial Kind="Refresh" VerticalAlignment="Center"/>
                        <TextBlock Margin="5,0,0,0" Text="Actualizar" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                
                <Separator/>
                
                <Button Command="{Binding ProtectCommand}" 
                        ToolTip="Proteger discos seleccionados">
                    <StackPanel Orientation="Horizontal">
                        <iconPacks:PackIconMaterial Kind="ShieldLock" VerticalAlignment="Center"/>
                        <TextBlock Margin="5,0,0,0" Text="Proteger" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                
                <Button Command="{Binding UnprotectCommand}" 
                        ToolTip="Desproteger discos seleccionados">
                    <StackPanel Orientation="Horizontal">
                        <iconPacks:PackIconMaterial Kind="ShieldOff" VerticalAlignment="Center"/>
                        <TextBlock Margin="5,0,0,0" Text="Desproteger" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
            </ToolBar>
        </ToolBarTray>
        
        <!-- Lista de discos -->
        <DataGrid Grid.Row="1" 
                  ItemsSource="{Binding Disks}" 
                  AutoGenerateColumns="False"
                  CanUserAddRows="False"
                  CanUserDeleteRows="False"
                  CanUserReorderColumns="False"
                  CanUserResizeRows="False"
                  SelectionMode="Single"
                  GridLinesVisibility="Horizontal"
                  HeadersVisibility="Column"
                  IsReadOnly="True"
                  Margin="10">
            
            <DataGrid.Columns>
                <DataGridTemplateColumn Header="Seleccionar" Width="Auto">
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <CheckBox IsChecked="{Binding IsSelected, Mode=TwoWay}" 
                                      IsEnabled="{Binding IsSelectable}"
                                      HorizontalAlignment="Center" 
                                      VerticalAlignment="Center"/>
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
                
                <DataGridTextColumn Header="Letra" 
                                    Binding="{Binding DriveLetter}" 
                                    Width="Auto"/>
                
                <DataGridTextColumn Header="Nombre" 
                                    Binding="{Binding VolumeName}" 
                                    Width="*"/>
                
                <DataGridTextColumn Header="Capacidad" 
                                    Binding="{Binding TotalSize}" 
                                    Width="Auto"/>
                
                <DataGridTextColumn Header="Libre" 
                                    Binding="{Binding FreeSpace}" 
                                    Width="Auto"/>
                
                <DataGridTextColumn Header="Sistema" 
                                    Binding="{Binding FileSystem}" 
                                    Width="Auto"/>
                
                <DataGridTextColumn Header="Tipo" 
                                    Binding="{Binding DiskType}" 
                                    Width="Auto"/>
                
                <DataGridTemplateColumn Header="Estado" Width="Auto">
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <StackPanel Orientation="Horizontal">
                                <Ellipse Width="12" Height="12" Margin="0,0,5,0">
                                    <Ellipse.Style>
                                        <Style TargetType="Ellipse">
                                            <Setter Property="Fill" Value="#F44336"/>
                                            <Style.Triggers>
                                                <DataTrigger Binding="{Binding IsProtected}" Value="True">
                                                    <Setter Property="Fill" Value="#4CAF50"/>
                                                </DataTrigger>
                                                <DataTrigger Binding="{Binding IsSelectable}" Value="False">
                                                    <Setter Property="Fill" Value="#9E9E9E"/>
                                                </DataTrigger>
                                            </Style.Triggers>
                                        </Style>
                                    </Ellipse.Style>
                                </Ellipse>
                                <TextBlock Text="{Binding ProtectionStatus}" VerticalAlignment="Center">
                                    <TextBlock.Style>
                                        <Style TargetType="TextBlock">
                                            <Style.Triggers>
                                                <DataTrigger Binding="{Binding IsSelectable}" Value="False">
                                                    <Setter Property="Foreground" Value="#9E9E9E"/>
                                                </DataTrigger>
                                            </Style.Triggers>
                                        </Style>
                                    </TextBlock.Style>
                                </TextBlock>
                            </StackPanel>
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
            </DataGrid.Columns>
        </DataGrid>
        
        <!-- Barra de estado -->
        <StatusBar Grid.Row="2" Background="{DynamicResource MahApps.Brushes.Gray10}">
            <StatusBarItem>
                <StackPanel Orientation="Horizontal">
                    <controls:ProgressRing IsActive="{Binding IsWorking}" 
                                           Width="16" Height="16" 
                                           Margin="0,0,10,0"/>
                    <TextBlock Text="{Binding StatusMessage}" 
                               VerticalAlignment="Center"/>
                </StackPanel>
            </StatusBarItem>
        </StatusBar>
    </Grid>
</controls:MetroWindow>
MAINWINDOWXAMLEOF

# Actualizar la versión del proyecto
cat > src/DiskProtectorApp/DiskProtectorApp.csproj << 'PROJECTEOF'
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows</TargetFramework>
    <Nullable>enable</Nullable>
    <UseWPF>true</UseWPF>
    <ApplicationManifest>app.manifest</ApplicationManifest>
    <PlatformTarget>x64</PlatformTarget>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <SelfContained>false</SelfContained>
    <ApplicationIcon>Resources\app.ico</ApplicationIcon>
    
    <!-- Configuración de versionado completa -->
    <Version>1.0.9</Version>
    <AssemblyVersion>1.0.9.0</AssemblyVersion>
    <FileVersion>1.0.9.0</FileVersion>
    <InformationalVersion>1.0.9</InformationalVersion>
    
    <!-- Propiedades adicionales para el ejecutable -->
    <Product>DiskProtectorApp</Product>
    <AssemblyTitle>Disk Protector Application</AssemblyTitle>
    <AssemblyDescription>Aplicación para protección de discos mediante gestión de permisos NTFS</AssemblyDescription>
    <AssemblyCompany>Emigdio Alexey Jimenez Acosta</AssemblyCompany>
    <AssemblyCopyright>Copyright © Emigdio Alexey Jimenez Acosta 2024</AssemblyCopyright>
    <AssemblyTrademark></AssemblyTrademark>
    
    <!-- Habilitar targeting de Windows en Linux -->
    <EnableWindowsTargeting>true</EnableWindowsTargeting>
    <!-- Configuración adicional para mejor diagnóstico -->
    <DebugType>portable</DebugType>
    <DebugSymbols>true</DebugSymbols>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="MahApps.Metro" Version="2.4.10" />
    <PackageReference Include="MahApps.Metro.IconPacks" Version="4.11.0" />
    <PackageReference Include="ControlzEx" Version="5.0.2" />
    <PackageReference Include="Microsoft.Xaml.Behaviors.Wpf" Version="1.1.77" />
    <PackageReference Include="System.Management" Version="8.0.0" />
  </ItemGroup>

  <ItemGroup>
    <None Remove="Resources\app.ico" />
    <None Remove="Resources\shield-protected.png" />
    <None Remove="Resources\shield-unprotected.png" />
  </ItemGroup>

  <ItemGroup>
    <Resource Include="Resources\app.ico" />
    <Resource Include="Resources\shield-protected.png" />
    <Resource Include="Resources\shield-unprotected.png" />
  </ItemGroup>

</Project>
PROJECTEOF

echo "Correcciones de funcionalidad aplicadas!"
echo "Cambios realizados:"
echo "1. Agregada propiedad IsSelectable al modelo DiskInfo"
echo "2. Mejorada la detección del disco del sistema"
echo "3. Actualizado el servicio de discos para marcar discos no seleccionables"
echo "4. Mejorado el ViewModel para manejar cambios en selección"
echo "5. Actualizado RelayCommand con método RaiseCanExecuteChanged"
echo "6. Mejorada la interfaz para mostrar discos no seleccionables"
echo "7. Actualizada la versión a 1.0.9"
echo ""
echo "Para crear una nueva versión con las correcciones:"
echo "1. git add src/DiskProtectorApp/Models/DiskInfo.cs"
echo "2. git add src/DiskProtectorApp/Services/DiskService.cs"
echo "3. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "4. git add src/DiskProtectorApp/RelayCommand.cs"
echo "5. git add src/DiskProtectorApp/Views/MainWindow.xaml"
echo "6. git add src/DiskProtectorApp/DiskProtectorApp.csproj"
echo "7. git commit -m \"fix: Corregir selección de discos y detección del sistema\""
echo "8. git push origin main"
echo "9. Crear nuevo tag:"
echo "   git tag -a v1.0.9 -m \"Release v1.0.9 - Corrección de selección\""
echo "   git push origin v1.0.9"

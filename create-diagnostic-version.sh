#!/bin/bash

echo "=== Creando versión de diagnóstico ==="

# Actualizar el modelo de datos con más logging
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
        private bool _isSystemDisk = false;

        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                System.Diagnostics.Debug.WriteLine($"[DISK MODEL] Setting IsSelected for {DriveLetter}: {value}");
                System.Console.WriteLine($"[DISK MODEL] Setting IsSelected for {DriveLetter}: {value}");
                
                if (_isSelectable && _isSelected != value)
                {
                    _isSelected = value;
                    System.Diagnostics.Debug.WriteLine($"[DISK MODEL] IsSelected CHANGED for {DriveLetter}: {value}");
                    System.Console.WriteLine($"[DISK MODEL] IsSelected CHANGED for {DriveLetter}: {value}");
                    OnPropertyChanged();
                }
                else
                {
                    System.Diagnostics.Debug.WriteLine($"[DISK MODEL] IsSelected NOT CHANGED for {DriveLetter}: old={_isSelected}, new={value}, selectable={_isSelectable}");
                    System.Console.WriteLine($"[DISK MODEL] IsSelected NOT CHANGED for {DriveLetter}: old={_isSelected}, new={value}, selectable={_isSelectable}");
                }
            }
        }

        public bool IsSelectable
        {
            get => _isSelectable;
            set
            {
                System.Diagnostics.Debug.WriteLine($"[DISK MODEL] Setting IsSelectable for {DriveLetter}: {value}");
                System.Console.WriteLine($"[DISK MODEL] Setting IsSelectable for {DriveLetter}: {value}");
                
                _isSelectable = value;
                OnPropertyChanged();
                
                // Si no es seleccionable, deseleccionar
                if (!value && _isSelected)
                {
                    System.Diagnostics.Debug.WriteLine($"[DISK MODEL] Deselecting non-selectable disk {DriveLetter}");
                    System.Console.WriteLine($"[DISK MODEL] Deselecting non-selectable disk {DriveLetter}");
                    IsSelected = false;
                }
            }
        }

        public bool IsSystemDisk
        {
            get => _isSystemDisk;
            set
            {
                _isSystemDisk = value;
                OnPropertyChanged();
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
                ProtectionStatus = value ? "Protegido" : (_isSystemDisk ? "No Elegible" : "Desprotegido");
                OnPropertyChanged();
                System.Diagnostics.Debug.WriteLine($"[DISK MODEL] IsProtected changed for {DriveLetter}: {value}");
                System.Console.WriteLine($"[DISK MODEL] IsProtected changed for {DriveLetter}: {value}");
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            System.Diagnostics.Debug.WriteLine($"[DISK MODEL] Property changed: {propertyName} on disk {DriveLetter}");
            System.Console.WriteLine($"[DISK MODEL] Property changed: {propertyName} on disk {DriveLetter}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
MODELEOF

# Actualizar MainWindow.xaml con un botón de diagnóstico adicional
cat > src/DiskProtectorApp/Views/MainWindow.xaml << 'MAINWINDOWXAMLEOF'
<controls:MetroWindow x:Class="DiskProtectorApp.Views.MainWindow"
                      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                      xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
                      xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
                      xmlns:controls="http://metro.mahapps.com/winfx/xaml/controls"
                      xmlns:iconPacks="http://metro.mahapps.com/winfx/xaml/iconpacks"
                      mc:Ignorable="d"
                      Title="DiskProtectorApp v1.2.0" Height="700" Width="1000"
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
                
                <Separator/>
                
                <Button Click="DiagnosticButton_Click" 
                        ToolTip="Mostrar diagnóstico de discos seleccionados">
                    <StackPanel Orientation="Horizontal">
                        <iconPacks:PackIconMaterial Kind="Bug" VerticalAlignment="Center"/>
                        <TextBlock Margin="5,0,0,0" Text="Diagnóstico" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
            </ToolBar>
        </ToolBarTray>
        
        <!-- Información de discos seleccionados -->
        <Border Grid.Row="1" 
                Background="{DynamicResource MahApps.Brushes.Gray10}" 
                Padding="10,5" 
                BorderBrush="{DynamicResource MahApps.Brushes.Gray8}" 
                BorderThickness="0,0,0,1">
            <StackPanel>
                <TextBlock Text="{Binding SelectedDisksInfo}" 
                           TextWrapping="Wrap" 
                           FontSize="12"
                           Foreground="{DynamicResource MahApps.Brushes.Text}"/>
                <TextBlock Text="{Binding DiagnosticInfo}" 
                           TextWrapping="Wrap" 
                           FontSize="10"
                           Foreground="{DynamicResource MahApps.Brushes.Gray3}"
                           Margin="0,2,0,0"/>
            </StackPanel>
        </Border>
        
        <!-- Lista de discos -->
        <DataGrid Grid.Row="2" 
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
                                      VerticalAlignment="Center"
                                      Click="CheckBox_Click"/>
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
        <StatusBar Grid.Row="3" Background="{DynamicResource MahApps.Brushes.Gray10}">
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

# Actualizar MainWindow.xaml.cs con handlers para diagnóstico
cat > src/DiskProtectorApp/Views/MainWindow.xaml.cs << 'MAINWINDOWCSHARPEOF'
using DiskProtectorApp.ViewModels;
using MahApps.Metro.Controls;
using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;

namespace DiskProtectorApp.Views
{
    public partial class MainWindow : MetroWindow
    {
        private string logPath;

        public MainWindow()
        {
            InitializeComponent();
            
            // Configurar logging
            string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string logDirectory = Path.Combine(appDataPath, "DiskProtectorApp");
            Directory.CreateDirectory(logDirectory);
            logPath = Path.Combine(logDirectory, "app-debug.log");
            
            LogMessage("MainWindow constructor starting...");
            
            try
            {
                // Actualizar el título con la versión de la aplicación
                var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
                if (version != null)
                {
                    this.Title = $"DiskProtectorApp v{version.Major}.{version.Minor}.{version.Build}";
                }
                
                DataContext = new MainViewModel();
                LogMessage("MainWindow initialized successfully");
            }
            catch (Exception ex)
            {
                LogMessage($"Error initializing MainWindow: {ex}");
                MessageBox.Show($"Error al inicializar la ventana principal:\n{ex.Message}\n\n{ex.StackTrace}", 
                                "Error de inicialización", 
                                MessageBoxButton.OK, 
                                MessageBoxImage.Error);
            }
        }

        private void HelpButton_Click(object sender, RoutedEventArgs e)
        {
            var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
            string versionText = version != null ? $"v{version.Major}.{version.Minor}.{version.Build}" : "v1.2.0";
            
            var helpText = $@"INFORMACIÓN DEL DESARROLLADOR:
- Nombre: Emigdio Alexey Jimenez Acosta
- Email: ealexeyja@gmail.com
- Teléfono: +53 5586 0259

DESCRIPCIÓN:
Aplicación para protección de discos mediante gestión de permisos NTFS.

⚠️ REQUERIMIENTOS TÉCNICOS:

🔷 EJECUCIÓN COMO ADMINISTRADOR:
• La aplicación DEBE ejecutarse con privilegios de administrador
• Click derecho → ""Ejecutar como administrador""

🔷 RUNTIME NECESARIO:
• Microsoft .NET 8.0 Desktop Runtime x64
• Descargar desde: https://dotnet.microsoft.com/download/dotnet/8.0  

🔷 SISTEMA OPERATIVO:
• Windows 10/11 x64
• Sistema de archivos NTFS

INSTRUCCIONES DE USO:
1. Ejecutar la aplicación como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Click en el botón correspondiente
4. Esperar confirmación de la operación

📝 REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\operations.log
• Se conservan los últimos 30 días de registros

 Versión actual: {versionText}";

            MessageBox.Show(helpText, "Ayuda de DiskProtectorApp", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void LogMessage(string message)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
                string logEntry = $"[{timestamp}] {message}";
                File.AppendAllText(logPath, logEntry + Environment.NewLine);
                
                // También escribir en la consola para debugging
                Debug.WriteLine(logEntry);
                Console.WriteLine(logEntry);
            }
            catch
            {
                // Silenciar errores de logging
            }
        }

        protected override void OnContentRendered(EventArgs e)
        {
            base.OnContentRendered(e);
            LogMessage("MainWindow content rendered");
        }
        
        // Handler para diagnóstico de checkboxes
        private void CheckBox_Click(object sender, RoutedEventArgs e)
        {
            var checkBox = sender as CheckBox;
            if (checkBox?.DataContext is Models.DiskInfo disk)
            {
                LogMessage($"[UI] CheckBox clicked for disk {disk.DriveLetter}. IsChecked: {checkBox.IsChecked}");
                Debug.WriteLine($"[UI] CheckBox clicked for disk {disk.DriveLetter}. IsChecked: {checkBox.IsChecked}");
                Console.WriteLine($"[UI] CheckBox clicked for disk {disk.DriveLetter}. IsChecked: {checkBox.IsChecked}");
            }
        }
        
        // Handler para botón de diagnóstico
        private void DiagnosticButton_Click(object sender, RoutedEventArgs e)
        {
            if (DataContext is ViewModels.MainViewModel viewModel)
            {
                viewModel.ShowDiagnosticInfo();
            }
        }
    }
}
MAINWINDOWCSHARPEOF

# Actualizar el ViewModel con diagnóstico completo
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'VIEWMODELEOF'
using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Input;

namespace DiskProtectorApp.ViewModels
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private readonly DiskService _diskService;
        private readonly OperationLogger _logger;
        private ObservableCollection<DiskInfo> _disks = new();
        private string _statusMessage = "Listo";
        private string _selectedDisksInfo = "Discos seleccionados: Ninguno";
        private string _diagnosticInfo = "";
        private bool _isWorking;

        public ObservableCollection<DiskInfo> Disks
        {
            get => _disks;
            set
            {
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Setting Disks collection. Old count: {_disks?.Count ?? 0}, New count: {value?.Count ?? 0}");
                Console.WriteLine($"[VIEWMODEL] Setting Disks collection. Old count: {_disks?.Count ?? 0}, New count: {value?.Count ?? 0}");
                
                // Desuscribirse de los eventos de los discos anteriores
                if (_disks != null)
                {
                    foreach (var disk in _disks)
                    {
                        disk.PropertyChanged -= OnDiskPropertyChanged;
                        System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Unsubscribed from disk {disk.DriveLetter}");
                        Console.WriteLine($"[VIEWMODEL] Unsubscribed from disk {disk.DriveLetter}");
                    }
                }
                
                _disks = value;
                
                // Suscribirse a los eventos de los nuevos discos
                if (_disks != null)
                {
                    foreach (var disk in _disks)
                    {
                        disk.PropertyChanged += OnDiskPropertyChanged;
                        System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Subscribed to disk {disk.DriveLetter}");
                        Console.WriteLine($"[VIEWMODEL] Subscribed to disk {disk.DriveLetter}");
                    }
                }
                
                OnPropertyChanged();
                UpdateCommandStates();
                UpdateSelectedDisksInfo();
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

        public string SelectedDisksInfo
        {
            get => _selectedDisksInfo;
            set
            {
                _selectedDisksInfo = value;
                OnPropertyChanged();
            }
        }

        public string DiagnosticInfo
        {
            get => _diagnosticInfo;
            set
            {
                _diagnosticInfo = value;
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
                UpdateCommandStates();
            }
        }

        public ICommand ProtectCommand { get; }
        public ICommand UnprotectCommand { get; }
        public ICommand RefreshCommand { get; }

        public MainViewModel()
        {
            _diskService = new DiskService();
            _logger = new OperationLogger();
            
            ProtectCommand = new RelayCommand(ExecuteProtectTest, CanAlwaysExecute);
            UnprotectCommand = new RelayCommand(ExecuteUnprotectTest, CanAlwaysExecute);
            RefreshCommand = new RelayCommand(ExecuteRefreshDisks);
            
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] MainViewModel initialized");
            Console.WriteLine("[VIEWMODEL] MainViewModel initialized");
            RefreshDisks();
        }

        private void OnDiskPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(DiskInfo.IsSelected) || 
                e.PropertyName == nameof(DiskInfo.IsProtected))
            {
                var disk = sender as DiskInfo;
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Disk property changed: {disk?.DriveLetter} - {e.PropertyName}");
                Console.WriteLine($"[VIEWMODEL] Disk property changed: {disk?.DriveLetter} - {e.PropertyName}");
                
                // Actualizar información de discos seleccionados cuando cambia IsSelected
                if (e.PropertyName == nameof(DiskInfo.IsSelected))
                {
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] IsSelected changed for {disk?.DriveLetter}, updating selected disks info");
                    Console.WriteLine($"[VIEWMODEL] IsSelected changed for {disk?.DriveLetter}, updating selected disks info");
                    UpdateSelectedDisksInfo();
                }
                
                // Actualizar estado de comandos
                UpdateCommandStates();
            }
        }

        public void ShowDiagnosticInfo()
        {
            if (_disks == null)
            {
                DiagnosticInfo = "No hay discos cargados";
                return;
            }
            
            var selectedDisks = _disks.Where(d => d.IsSelected).ToList();
            var diagnostic = $"Total discos: {_disks.Count}\n" +
                           $"Discos seleccionados: {selectedDisks.Count}\n" +
                           $"Estado de trabajo: {IsWorking}\n" +
                           $"Comandos activos: Protect={CanAlwaysExecute(null)}, Unprotect={CanAlwaysExecute(null)}";
            
            if (selectedDisks.Count > 0)
            {
                diagnostic += "\n\nDiscos seleccionados:\n";
                foreach (var disk in selectedDisks)
                {
                    diagnostic += $"  {disk.DriveLetter} ({disk.VolumeName}) - Selected: {disk.IsSelected}, Protected: {disk.IsProtected}\n";
                }
            }
            
            DiagnosticInfo = diagnostic;
            
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Diagnostic info: {diagnostic}");
            Console.WriteLine($"[VIEWMODEL] Diagnostic info: {diagnostic}");
        }

        private void UpdateSelectedDisksInfo()
        {
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] UpdateSelectedDisksInfo called. Disks count: {_disks?.Count ?? 0}");
            Console.WriteLine($"[VIEWMODEL] UpdateSelectedDisksInfo called. Disks count: {_disks?.Count ?? 0}");
            
            if (_disks == null)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
                System.Diagnostics.Debug.WriteLine("[VIEWMODEL] Disks is null, setting to 'Ninguno'");
                Console.WriteLine("[VIEWMODEL] Disks is null, setting to 'Ninguno'");
                return;
            }
            
            var selectedDisks = _disks.Where(d => d.IsSelected).ToList();
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Found {selectedDisks.Count} selected disks");
            Console.WriteLine($"[VIEWMODEL] Found {selectedDisks.Count} selected disks");
            
            if (selectedDisks.Count == 0)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
                System.Diagnostics.Debug.WriteLine("[VIEWMODEL] No disks selected, setting to 'Ninguno'");
                Console.WriteLine("[VIEWMODEL] No disks selected, setting to 'Ninguno'");
            }
            else
            {
                var diskList = string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})"));
                SelectedDisksInfo = $"Discos seleccionados ({selectedDisks.Count}): {diskList}";
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks: {diskList}");
                Console.WriteLine($"[VIEWMODEL] Selected disks: {diskList}");
            }
        }

        private void UpdateCommandStates()
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] Updating command states");
            Console.WriteLine("[VIEWMODEL] Updating command states");
            
            // Forzar actualización de comandos
            CommandManager.InvalidateRequerySuggested();
        }

        private bool CanAlwaysExecute(object? parameter)
        {
            // Siempre retornar true para que los botones estén activos (modo prueba)
            bool canExecute = !IsWorking;
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] CanAlwaysExecute: IsWorking={IsWorking}, Result={canExecute}");
            Console.WriteLine($"[VIEWMODEL] CanAlwaysExecute: IsWorking={IsWorking}, Result={canExecute}");
            return canExecute;
        }

        private void ExecuteRefreshDisks(object? parameter)
        {
            RefreshDisks();
        }

        private void RefreshDisks()
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] RefreshDisks called");
            Console.WriteLine("[VIEWMODEL] RefreshDisks called");
            
            IsWorking = true;
            StatusMessage = "Actualizando lista de discos...";
            
            var disks = _diskService.GetDisks();
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Got {disks.Count} disks from service");
            Console.WriteLine($"[VIEWMODEL] Got {disks.Count} disks from service");
            
            // Desuscribirse de los eventos de los discos anteriores
            if (_disks != null)
            {
                foreach (var disk in _disks)
                {
                    disk.PropertyChanged -= OnDiskPropertyChanged;
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Unsubscribed from old disk {disk.DriveLetter}");
                    Console.WriteLine($"[VIEWMODEL] Unsubscribed from old disk {disk.DriveLetter}");
                }
            }
            
            Disks.Clear();
            
            foreach (var disk in disks)
            {
                Disks.Add(disk);
                // Suscribirse al cambio de propiedad para actualizar comandos
                disk.PropertyChanged += OnDiskPropertyChanged;
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Added and subscribed to disk {disk.DriveLetter}");
                Console.WriteLine($"[VIEWMODEL] Added and subscribed to disk {disk.DriveLetter}");
            }
            
            StatusMessage = $"Se encontraron {disks.Count} discos";
            IsWorking = false;
            
            // Actualizar información de discos seleccionados
            UpdateSelectedDisksInfo();
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private void ExecuteProtectTest(object? parameter)
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] ExecuteProtectTest called");
            Console.WriteLine("[VIEWMODEL] ExecuteProtectTest called");
            
            var selectedDisks = _disks?.Where(d => d.IsSelected).ToList() ?? new List<DiskInfo>();
            string diskInfo = selectedDisks.Count > 0 ? 
                string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})")) : 
                "Ninguno";
            
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] PROTECT BUTTON CLICKED - Test function executed");
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks count: {selectedDisks.Count}");
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            Console.WriteLine($"[VIEWMODEL] PROTECT BUTTON CLICKED - Test function executed");
            Console.WriteLine($"[VIEWMODEL] Selected disks count: {selectedDisks.Count}");
            Console.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            _logger.LogOperation("TEST", "ProtectButton", true, $"Protect button clicked. Selected disks: {diskInfo}");
            
            // Mostrar mensaje de prueba con información de discos seleccionados
            string message = $"¡Botón de Protección presionado!\n\n" +
                           $"Esta es una versión de prueba para verificar el funcionamiento de los botones.\n\n" +
                           $"Discos seleccionados ({selectedDisks.Count}):\n{diskInfo}";
            
            MessageBox.Show(message, 
                          "Prueba de Botones", 
                          MessageBoxButton.OK, 
                          MessageBoxImage.Information);
            
            StatusMessage = $"Botón de Protección presionado (modo prueba) - {selectedDisks.Count} discos seleccionados";
        }

        private void ExecuteUnprotectTest(object? parameter)
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] ExecuteUnprotectTest called");
            Console.WriteLine("[VIEWMODEL] ExecuteUnprotectTest called");
            
            var selectedDisks = _disks?.Where(d => d.IsSelected).ToList() ?? new List<DiskInfo>();
            string diskInfo = selectedDisks.Count > 0 ? 
                string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})")) : 
                "Ninguno";
            
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] UNPROTECT BUTTON CLICKED - Test function executed");
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks count: {selectedDisks.Count}");
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            Console.WriteLine($"[VIEWMODEL] UNPROTECT BUTTON CLICKED - Test function executed");
            Console.WriteLine($"[VIEWMODEL] Selected disks count: {selectedDisks.Count}");
            Console.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            _logger.LogOperation("TEST", "UnprotectButton", true, $"Unprotect button clicked. Selected disks: {diskInfo}");
            
            // Mostrar mensaje de prueba con información de discos seleccionados
            string message = $"¡Botón de Desprotección presionado!\n\n" +
                           $"Esta es una versión de prueba para verificar el funcionamiento de los botones.\n\n" +
                           $"Discos seleccionados ({selectedDisks.Count}):\n{diskInfo}";
            
            MessageBox.Show(message, 
                          "Prueba de Botones", 
                          MessageBoxButton.OK, 
                          MessageBoxImage.Information);
            
            StatusMessage = $"Botón de Desprotección presionado (modo prueba) - {selectedDisks.Count} discos seleccionados";
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] OnPropertyChanged: {propertyName}");
            Console.WriteLine($"[VIEWMODEL] OnPropertyChanged: {propertyName}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
VIEWMODELEOF

echo "✅ Versión de diagnóstico creada"
echo "   Cambios principales:"
echo "   - Agregado logging exhaustivo en todos los componentes"
echo "   - Añadido botón de diagnóstico en la interfaz"
echo "   - Añadido handler para clicks en checkboxes"
echo "   - Mejorada la información de diagnóstico"
echo "   - Logging en múltiples canales (Debug, Console, File)"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/Models/DiskInfo.cs"
echo "2. git add src/DiskProtectorApp/Views/MainWindow.xaml"
echo "3. git add src/DiskProtectorApp/Views/MainWindow.xaml.cs"
echo "4. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "5. git commit -m \"diagnostic: Versión de diagnóstico para selección de discos\""
echo "6. git push origin main"
echo ""
echo "Para compilar y generar el release:"
echo "./build-and-release.sh"

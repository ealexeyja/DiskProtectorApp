#!/bin/bash

echo "=== Implementando funcionalidad de protección de discos ==="

# Actualizar el servicio de discos con mejor manejo de errores y logging
cat > src/DiskProtectorApp/Services/DiskService.cs << 'SERVICESDISKEOF'
using DiskProtectorApp.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Management;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Threading.Tasks;

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

                    bool isSystemDisk = drive.Name.Equals(systemDrive, StringComparison.OrdinalIgnoreCase);
                    
                    var disk = new DiskInfo
                    {
                        DriveLetter = drive.Name,
                        VolumeName = drive.VolumeLabel ?? "Sin etiqueta",
                        TotalSize = FormatBytes(drive.TotalSize),
                        FreeSpace = $"{FormatBytes(drive.TotalFreeSpace)} ({(double)drive.TotalFreeSpace / drive.TotalSize * 100:F1}%)",
                        FileSystem = drive.DriveFormat,
                        DiskType = IsSSD(drive.Name) ? "SSD" : "HDD",
                        IsProtected = IsDriveProtected(drive.RootDirectory.FullName),
                        IsSelected = false,
                        IsSystemDisk = isSystemDisk,
                        IsSelectable = !isSystemDisk
                    };

                    // Marcar el disco del sistema
                    if (isSystemDisk)
                    {
                        disk.VolumeName += " (Sistema)";
                        disk.ProtectionStatus = "No Elegible";
                    }
                    else
                    {
                        disk.ProtectionStatus = disk.IsProtected ? "Protegido" : "Desprotegido";
                    }

                    disks.Add(disk);
                }
                catch (Exception ex)
                {
                    // Loggear errores pero continuar con otros discos
                    System.Diagnostics.Debug.WriteLine($"Error procesando disco {drive.Name}: {ex.Message}");
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
                System.Diagnostics.Debug.WriteLine($"Error determinando tipo de disco para {driveName}: {ex.Message}");
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
                System.Diagnostics.Debug.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
                return false;
            }
        }

        public async Task<bool> ProtectDriveAsync(string drivePath, IProgress<string> progress)
        {
            return await Task.Run(() =>
            {
                try
                {
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    
                    progress?.Report("Agregando regla de denegación...");
                    // Denegar acceso al usuario actual
                    var currentUser = WindowsIdentity.GetCurrent();
                    var rule = new FileSystemAccessRule(
                        currentUser.Name,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Deny);
                    
                    security.AddAccessRule(rule);
                    
                    progress?.Report("Aplicando cambios de permisos...");
                    directoryInfo.SetAccessControl(security);
                    
                    progress?.Report("Protección completada");
                    return true;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error protegiendo disco {drivePath}: {ex.Message}");
                    progress?.Report($"Error: {ex.Message}");
                    return false;
                }
            });
        }

        public async Task<bool> UnprotectDriveAsync(string drivePath, IProgress<string> progress)
        {
            return await Task.Run(() =>
            {
                try
                {
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    var rules = security.GetAccessRules(true, true, typeof(NTAccount));
                    
                    progress?.Report("Buscando reglas de denegación...");
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
                    
                    progress?.Report($"Removiendo {rulesToRemove.Count} reglas de denegación...");
                    foreach (var rule in rulesToRemove)
                    {
                        security.RemoveAccessRule(rule);
                    }
                    
                    progress?.Report("Aplicando cambios de permisos...");
                    directoryInfo.SetAccessControl(security);
                    
                    progress?.Report("Desprotección completada");
                    return true;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error desprotegiendo disco {drivePath}: {ex.Message}");
                    progress?.Report($"Error: {ex.Message}");
                    return false;
                }
            });
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

# Crear ventana de progreso
cat > src/DiskProtectorApp/Views/ProgressDialog.xaml << 'PROGRESSDIALOGXAMLEOF'
<controls:MetroWindow x:Class="DiskProtectorApp.Views.ProgressDialog"
                      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                      xmlns:controls="http://metro.mahapps.com/winfx/xaml/controls"
                      Title="Procesando..." 
                      Height="150" 
                      Width="400"
                      WindowStartupLocation="CenterOwner"
                      ResizeMode="NoResize"
                      ShowInTaskbar="False"
                      Topmost="True"
                      GlowBrush="{DynamicResource AccentColorBrush}">
    
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock x:Name="OperationText" 
                   Text="Procesando discos..." 
                   FontSize="14" 
                   Margin="0,0,0,10"
                   Grid.Row="0"/>
        
        <ProgressBar x:Name="ProgressBar" 
                     IsIndeterminate="True" 
                     Height="10" 
                     Margin="0,0,0,10"
                     Grid.Row="1"/>
        
        <TextBlock x:Name="ProgressText" 
                   Text="Iniciando..." 
                   FontSize="12" 
                   Foreground="{DynamicResource MahApps.Brushes.Gray3}"
                   Grid.Row="2"/>
    </Grid>
</controls:MetroWindow>
PROGRESSDIALOGXAMLEOF

# Crear código de la ventana de progreso
cat > src/DiskProtectorApp/Views/ProgressDialog.xaml.cs << 'PROGRESSDIALOGCSHARPEOF'
using MahApps.Metro.Controls;
using System.Windows;

namespace DiskProtectorApp.Views
{
    public partial class ProgressDialog : MetroWindow
    {
        public ProgressDialog()
        {
            InitializeComponent();
        }

        public void UpdateProgress(string operation, string progress)
        {
            OperationText.Text = operation;
            ProgressText.Text = progress;
        }

        public void SetProgressIndeterminate(bool isIndeterminate)
        {
            ProgressBar.IsIndeterminate = isIndeterminate;
        }
    }
}
PROGRESSDIALOGCSHARPEOF

# Actualizar el ViewModel con funcionalidad asíncrona y progreso
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'VIEWMODELEOF'
using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using DiskProtectorApp.Views;
using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
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
        private bool _isWorking;

        public ObservableCollection<DiskInfo> Disks
        {
            get => _disks;
            set
            {
                // Desuscribirse de los eventos de los discos anteriores
                if (_disks != null)
                {
                    foreach (var disk in _disks)
                    {
                        disk.PropertyChanged -= OnDiskPropertyChanged;
                    }
                }
                
                _disks = value;
                
                // Suscribirse a los eventos de los nuevos discos
                if (_disks != null)
                {
                    foreach (var disk in _disks)
                    {
                        disk.PropertyChanged += OnDiskPropertyChanged;
                    }
                }
                
                OnPropertyChanged();
                UpdateCommandStates();
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
            
            ProtectCommand = new RelayCommand(async (parameter) => await ProtectSelectedDisksAsync(), CanAlwaysExecute);
            UnprotectCommand = new RelayCommand(async (parameter) => await UnprotectSelectedDisksAsync(), CanAlwaysExecute);
            RefreshCommand = new RelayCommand(ExecuteRefreshDisks);
            
            System.Diagnostics.Debug.WriteLine("MainViewModel initialized");
            RefreshDisks();
        }

        private void OnDiskPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(DiskInfo.IsSelected) || 
                e.PropertyName == nameof(DiskInfo.IsProtected))
            {
                var disk = sender as DiskInfo;
                System.Diagnostics.Debug.WriteLine($"Disk property changed: {disk?.DriveLetter} - {e.PropertyName}");
                
                // Usar Dispatcher para asegurar que la actualización ocurra en el hilo UI
                if (System.Windows.Application.Current?.Dispatcher != null)
                {
                    System.Windows.Application.Current.Dispatcher.Invoke(() => {
                        UpdateCommandStates();
                    });
                }
                else
                {
                    UpdateCommandStates();
                }
            }
        }

        private void UpdateCommandStates()
        {
            System.Diagnostics.Debug.WriteLine("Updating command states");
            
            // Forzar actualización de comandos
            CommandManager.InvalidateRequerySuggested();
        }

        private bool CanAlwaysExecute(object? parameter)
        {
            // Siempre retornar true para que los botones estén activos
            bool canExecute = !IsWorking;
            System.Diagnostics.Debug.WriteLine($"CanExecute check: IsWorking={IsWorking}, Result={canExecute}");
            return canExecute;
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
            
            // Desuscribirse de los eventos de los discos anteriores
            foreach (var disk in _disks)
            {
                disk.PropertyChanged -= OnDiskPropertyChanged;
            }
            
            Disks.Clear();
            
            foreach (var disk in disks)
            {
                Disks.Add(disk);
                // Suscribirse al cambio de propiedad para actualizar comandos
                disk.PropertyChanged += OnDiskPropertyChanged;
            }
            
            StatusMessage = $"Se encontraron {disks.Count} discos";
            IsWorking = false;
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private async Task ProtectSelectedDisksAsync()
        {
            // Obtener todos los discos seleccionados, independientemente de su estado
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable).ToList();
            if (!selectedDisks.Any()) return;

            System.Diagnostics.Debug.WriteLine($"Protecting {selectedDisks.Count} disks");
            
            IsWorking = true;
            StatusMessage = $"Protegiendo {selectedDisks.Count} disco(s)...";

            // Crear y mostrar ventana de progreso
            var progressDialog = new ProgressDialog();
            progressDialog.UpdateProgress("Protegiendo discos", $"Procesando 0 de {selectedDisks.Count} discos...");
            
            var mainWindow = Application.Current.MainWindow;
            if (mainWindow != null)
            {
                progressDialog.Owner = mainWindow;
            }
            
            progressDialog.Show();

            int successCount = 0;
            int currentDisk = 0;
            
            foreach (var disk in selectedDisks)
            {
                currentDisk++;
                progressDialog.UpdateProgress($"Protegiendo disco {disk.DriveLetter}", $"Procesando {currentDisk} de {selectedDisks.Count} discos...");
                
                var progress = new Progress<string>(message => {
                    progressDialog.UpdateProgress($"Protegiendo disco {disk.DriveLetter}", message);
                });
                
                bool success = await _diskService.ProtectDriveAsync(disk.DriveLetter ?? "", progress);
                if (success)
                {
                    disk.IsProtected = true;
                    successCount++;
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", true);
                    System.Diagnostics.Debug.WriteLine($"Successfully protected disk {disk.DriveLetter}");
                }
                else
                {
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                    System.Diagnostics.Debug.WriteLine($"Failed to protect disk {disk.DriveLetter}");
                }
            }

            progressDialog.Close();
            
            StatusMessage = $"Protegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // Mostrar mensaje de resultado
            string resultMessage = $"Protección completada.\n\nDiscos protegidos: {successCount}\nDiscos con error: {selectedDisks.Count - successCount}";
            MessageBox.Show(resultMessage, "Protección de discos", MessageBoxButton.OK, MessageBoxImage.Information);
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private async Task UnprotectSelectedDisksAsync()
        {
            // Obtener todos los discos seleccionados, independientemente de su estado
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable).ToList();
            if (!selectedDisks.Any()) return;

            System.Diagnostics.Debug.WriteLine($"Unprotecting {selectedDisks.Count} disks");
            
            IsWorking = true;
            StatusMessage = $"Desprotegiendo {selectedDisks.Count} disco(s)...";

            // Crear y mostrar ventana de progreso
            var progressDialog = new ProgressDialog();
            progressDialog.UpdateProgress("Desprotegiendo discos", $"Procesando 0 de {selectedDisks.Count} discos...");
            
            var mainWindow = Application.Current.MainWindow;
            if (mainWindow != null)
            {
                progressDialog.Owner = mainWindow;
            }
            
            progressDialog.Show();

            int successCount = 0;
            int currentDisk = 0;
            
            foreach (var disk in selectedDisks)
            {
                currentDisk++;
                progressDialog.UpdateProgress($"Desprotegiendo disco {disk.DriveLetter}", $"Procesando {currentDisk} de {selectedDisks.Count} discos...");
                
                var progress = new Progress<string>(message => {
                    progressDialog.UpdateProgress($"Desprotegiendo disco {disk.DriveLetter}", message);
                });
                
                bool success = await _diskService.UnprotectDriveAsync(disk.DriveLetter ?? "", progress);
                if (success)
                {
                    disk.IsProtected = false;
                    successCount++;
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", true);
                    System.Diagnostics.Debug.WriteLine($"Successfully unprotected disk {disk.DriveLetter}");
                }
                else
                {
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                    System.Diagnostics.Debug.WriteLine($"Failed to unprotect disk {disk.DriveLetter}");
                }
            }

            progressDialog.Close();
            
            StatusMessage = $"Desprotegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // Mostrar mensaje de resultado
            string resultMessage = $"Desprotección completada.\n\nDiscos desprotegidos: {successCount}\nDiscos con error: {selectedDisks.Count - successCount}";
            MessageBox.Show(resultMessage, "Desprotección de discos", MessageBoxButton.OK, MessageBoxImage.Information);
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
VIEWMODELEOF

# Actualizar RelayCommand para manejar comandos asíncronos
cat > src/DiskProtectorApp/RelayCommand.cs << 'RELAYCOMMANDEOF'
using System;
using System.Threading.Tasks;
using System.Windows.Input;

namespace DiskProtectorApp
{
    public class RelayCommand : ICommand
    {
        private readonly Action<object?> _execute;
        private readonly Func<object?, Task> _executeAsync;
        private readonly Predicate<object?>? _canExecute;

        public RelayCommand(Action<object?> execute, Predicate<object?>? canExecute = null)
        {
            _execute = execute ?? throw new ArgumentNullException(nameof(execute));
            _canExecute = canExecute;
        }

        public RelayCommand(Func<object?, Task> executeAsync, Predicate<object?>? canExecute = null)
        {
            _executeAsync = executeAsync ?? throw new ArgumentNullException(nameof(executeAsync));
            _canExecute = canExecute;
        }

        public bool CanExecute(object? parameter)
        {
            bool result = _canExecute?.Invoke(parameter) ?? true;
            return result;
        }

        public async void Execute(object? parameter)
        {
            if (_executeAsync != null)
            {
                await _executeAsync(parameter);
            }
            else
            {
                _execute?.Invoke(parameter);
            }
        }

        public event EventHandler? CanExecuteChanged
        {
            add 
            { 
                CommandManager.RequerySuggested += value; 
            }
            remove 
            { 
                CommandManager.RequerySuggested -= value; 
            }
        }

        public void RaiseCanExecuteChanged()
        {
            CommandManager.InvalidateRequerySuggested();
        }
    }
}
RELAYCOMMANDEOF

echo "✅ Funcionalidad de protección de discos implementada"
echo "   Cambios principales:"
echo "   - Implementada protección/desprotección asíncrona con progreso"
echo "   - Agregada ventana de diálogo de progreso con el mismo tema"
echo "   - Mejorado el servicio de discos con manejo de errores"
echo "   - Agregado feedback visual durante las operaciones"
echo "   - Ventana principal bloqueada durante las operaciones"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/Services/DiskService.cs"
echo "2. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "3. git add src/DiskProtectorApp/RelayCommand.cs"
echo "4. git add src/DiskProtectorApp/Views/ProgressDialog.xaml"
echo "5. git add src/DiskProtectorApp/Views/ProgressDialog.xaml.cs"
echo "6. git commit -m \"feat: Implementar funcionalidad completa de protección de discos\""
echo "7. git push origin main"

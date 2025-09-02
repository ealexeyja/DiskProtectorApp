#!/bin/bash

echo "=== Corrigiendo activación de botones y agregando logging ==="

# Actualizar el modelo de datos para mejor manejo de propiedades
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
                if (_isSelectable && _isSelected != value)
                {
                    _isSelected = value;
                    OnPropertyChanged();
                    System.Diagnostics.Debug.WriteLine($"Disk {_driveLetter}: IsSelected changed to {value}");
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
                System.Diagnostics.Debug.WriteLine($"Disk {_driveLetter}: IsProtected changed to {value}");
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

# Actualizar el ViewModel con mejor manejo de comandos y logging
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
            
            ProtectCommand = new RelayCommand(ProtectSelectedDisks, CanPerformProtectOperation);
            UnprotectCommand = new RelayCommand(UnprotectSelectedDisks, CanPerformUnprotectOperation);
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
            System.Diagnostics.Debug.WriteLine($"Protect command can execute: {CanPerformProtectOperation(null)}");
            System.Diagnostics.Debug.WriteLine($"Unprotect command can execute: {CanPerformUnprotectOperation(null)}");
            
            // Forzar actualización de comandos
            CommandManager.InvalidateRequerySuggested();
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

        private bool CanPerformProtectOperation(object? parameter)
        {
            bool canProtect = !IsWorking && Disks.Any(d => d.IsSelected && d.IsSelectable && !d.IsProtected);
            int selectedCount = Disks.Count(d => d.IsSelected && d.IsSelectable && !d.IsProtected);
            System.Diagnostics.Debug.WriteLine($"CanProtect check: IsWorking={IsWorking}, SelectedCount={selectedCount}, Result={canProtect}");
            return canProtect;
        }

        private bool CanPerformUnprotectOperation(object? parameter)
        {
            bool canUnprotect = !IsWorking && Disks.Any(d => d.IsSelected && d.IsSelectable && d.IsProtected);
            int selectedCount = Disks.Count(d => d.IsSelected && d.IsSelectable && d.IsProtected);
            System.Diagnostics.Debug.WriteLine($"CanUnprotect check: IsWorking={IsWorking}, SelectedCount={selectedCount}, Result={canUnprotect}");
            return canUnprotect;
        }

        private void ProtectSelectedDisks(object? parameter)
        {
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable && !d.IsProtected).ToList();
            if (!selectedDisks.Any()) return;

            System.Diagnostics.Debug.WriteLine($"Protecting {selectedDisks.Count} disks");
            
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
                    System.Diagnostics.Debug.WriteLine($"Successfully protected disk {disk.DriveLetter}");
                }
                else
                {
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                    System.Diagnostics.Debug.WriteLine($"Failed to protect disk {disk.DriveLetter}");
                }
            }

            StatusMessage = $"Protegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private void UnprotectSelectedDisks(object? parameter)
        {
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable && d.IsProtected).ToList();
            if (!selectedDisks.Any()) return;

            System.Diagnostics.Debug.WriteLine($"Unprotecting {selectedDisks.Count} disks");
            
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
                    System.Diagnostics.Debug.WriteLine($"Successfully unprotected disk {disk.DriveLetter}");
                }
                else
                {
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                    System.Diagnostics.Debug.WriteLine($"Failed to unprotect disk {disk.DriveLetter}");
                }
            }

            StatusMessage = $"Desprotegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
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

# Actualizar App.xaml.cs para mejor logging
cat > src/DiskProtectorApp/App.xaml.cs << 'APPCSHARPEOF'
using System;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Windows;

namespace DiskProtectorApp
{
    public partial class App : Application
    {
        private string? logPath;

        protected override void OnStartup(StartupEventArgs e)
        {
            // Configurar logging
            string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string logDirectory = Path.Combine(appDataPath, "DiskProtectorApp");
            Directory.CreateDirectory(logDirectory);
            logPath = Path.Combine(logDirectory, "app-debug.log");
            
            LogMessage("Application starting...");
            
            try
            {
                // Verificar si se está ejecutando como administrador
                LogMessage("Checking administrator privileges...");
                if (!IsRunningAsAdministrator())
                {
                    LogMessage("Administrator privileges required - showing message");
                    MessageBox.Show("Esta aplicación requiere privilegios de administrador.\nPor favor, ejecútela como administrador.", 
                                    "Privilegios requeridos", 
                                    MessageBoxButton.OK, 
                                    MessageBoxImage.Warning);
                    Shutdown();
                    return;
                }

                LogMessage("Administrator privileges confirmed");
                
                // Crear y mostrar la ventana principal
                LogMessage("Creating main window...");
                var mainWindow = new DiskProtectorApp.Views.MainWindow();
                LogMessage("Main window created successfully");
                
                // Mostrar la ventana
                mainWindow.Show();
                LogMessage("Main window shown");
                
                LogMessage("Application startup completed");
            }
            catch (Exception ex)
            {
                LogMessage($"Error during startup: {ex}");
                MessageBox.Show($"Error al iniciar la aplicación:\n{ex.Message}\n\n{ex.StackTrace}", 
                                "Error de inicio", 
                                MessageBoxButton.OK, 
                                MessageBoxImage.Error);
                Shutdown();
            }
        }

        private bool IsRunningAsAdministrator()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch (Exception ex)
            {
                LogMessage($"Error checking admin privileges: {ex}");
                return false;
            }
        }

        private void LogMessage(string message)
        {
            try
            {
                if (logPath != null)
                {
                    string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
                    string logEntry = $"[{timestamp}] {message}";
                    File.AppendAllText(logPath, logEntry + Environment.NewLine);
                }
            }
            catch
            {
                // Silenciar errores de logging
            }
        }
    }
}
APPCSHARPEOF

echo "✅ Correcciones aplicadas para activación de botones y logging"
echo "   Cambios principales:"
echo "   - Mejorado el modelo de datos con logging"
echo "   - Corregida la lógica de comandos con mejor manejo de eventos"
echo "   - Agregado logging detallado para diagnóstico"
echo "   - Forzada actualización de comandos con Dispatcher.Invoke"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/Models/DiskInfo.cs"
echo "2. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "3. git add src/DiskProtectorApp/App.xaml.cs"
echo "4. git commit -m \"fix: Corregir activación de botones y agregar logging\""
echo "5. git push origin main"

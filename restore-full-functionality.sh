#!/bin/bash

echo "=== Restaurando funcionalidad completa de protección/desprotección ==="

# Actualizar el ViewModel con la funcionalidad real de protección/desprotección
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'VIEWMODELEOF'
using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using DiskProtectorApp.Views;
using System;
using System.Collections.Generic;
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
            
            ProtectCommand = new RelayCommand(async (parameter) => await ExecuteProtectDisksAsync(), CanAlwaysExecute);
            UnprotectCommand = new RelayCommand(async (parameter) => await ExecuteUnprotectDisksAsync(), CanAlwaysExecute);
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
            // Siempre retornar true para que los botones estén activos (modo producción)
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

        private async Task ExecuteProtectDisksAsync()
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] ExecuteProtectDisksAsync called");
            Console.WriteLine("[VIEWMODEL] ExecuteProtectDisksAsync called");
            
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && !d.IsSystemDisk).ToList() ?? new List<DiskInfo>();
            if (selectedDisks.Count == 0)
            {
                MessageBox.Show("No hay discos seleccionados para proteger.\n\nPor favor, seleccione al menos un disco no protegido.", 
                              "Protección de discos", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Information);
                return;
            }
            
            string diskInfo = string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})"));
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] PROTECT DISKS - Count: {selectedDisks.Count}");
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            Console.WriteLine($"[VIEWMODEL] PROTECT DISKS - Count: {selectedDisks.Count}");
            Console.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            // Crear y mostrar ventana de progreso
            var progressDialog = new ProgressDialog();
            progressDialog.UpdateProgress("Protegiendo discos", $"Procesando 0 de {selectedDisks.Count} discos...");
            
            var mainWindow = Application.Current.MainWindow;
            if (mainWindow != null)
            {
                progressDialog.Owner = mainWindow;
            }
            
            progressDialog.Show();
            
            try
            {
                IsWorking = true;
                StatusMessage = $"Protegiendo {selectedDisks.Count} disco(s)...";
                
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
                        System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Successfully protected disk {disk.DriveLetter}");
                        Console.WriteLine($"[VIEWMODEL] Successfully protected disk {disk.DriveLetter}");
                    }
                    else
                    {
                        _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                        System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Failed to protect disk {disk.DriveLetter}");
                        Console.WriteLine($"[VIEWMODEL] Failed to protect disk {disk.DriveLetter}");
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
            catch (Exception ex)
            {
                progressDialog.Close();
                IsWorking = false;
                StatusMessage = "Error durante la protección de discos";
                
                _logger.LogOperation("ERROR", "ProtectDisks", false, $"Exception: {ex.Message}");
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Exception during protect: {ex}");
                Console.WriteLine($"[VIEWMODEL] Exception during protect: {ex}");
                
                MessageBox.Show($"Error durante la protección de discos:\n{ex.Message}", 
                              "Error de protección", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Error);
                
                UpdateCommandStates();
            }
        }

        private async Task ExecuteUnprotectDisksAsync()
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] ExecuteUnprotectDisksAsync called");
            Console.WriteLine("[VIEWMODEL] ExecuteUnprotectDisksAsync called");
            
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && d.IsProtected && !d.IsSystemDisk).ToList() ?? new List<DiskInfo>();
            if (selectedDisks.Count == 0)
            {
                MessageBox.Show("No hay discos seleccionados para desproteger.\n\nPor favor, seleccione al menos un disco protegido.", 
                              "Desprotección de discos", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Information);
                return;
            }
            
            string diskInfo = string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})"));
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] UNPROTECT DISKS - Count: {selectedDisks.Count}");
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            Console.WriteLine($"[VIEWMODEL] UNPROTECT DISKS - Count: {selectedDisks.Count}");
            Console.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            // Crear y mostrar ventana de progreso
            var progressDialog = new ProgressDialog();
            progressDialog.UpdateProgress("Desprotegiendo discos", $"Procesando 0 de {selectedDisks.Count} discos...");
            
            var mainWindow = Application.Current.MainWindow;
            if (mainWindow != null)
            {
                progressDialog.Owner = mainWindow;
            }
            
            progressDialog.Show();
            
            try
            {
                IsWorking = true;
                StatusMessage = $"Desprotegiendo {selectedDisks.Count} disco(s)...";
                
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
                        System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Successfully unprotected disk {disk.DriveLetter}");
                        Console.WriteLine($"[VIEWMODEL] Successfully unprotected disk {disk.DriveLetter}");
                    }
                    else
                    {
                        _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                        System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Failed to unprotect disk {disk.DriveLetter}");
                        Console.WriteLine($"[VIEWMODEL] Failed to unprotect disk {disk.DriveLetter}");
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
            catch (Exception ex)
            {
                progressDialog.Close();
                IsWorking = false;
                StatusMessage = "Error durante la desprotección de discos";
                
                _logger.LogOperation("ERROR", "UnprotectDisks", false, $"Exception: {ex.Message}");
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Exception during unprotect: {ex}");
                Console.WriteLine($"[VIEWMODEL] Exception during unprotect: {ex}");
                
                MessageBox.Show($"Error durante la desprotección de discos:\n{ex.Message}", 
                              "Error de desprotección", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Error);
                
                UpdateCommandStates();
            }
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

# Actualizar el servicio de discos con métodos asíncronos mejorados
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
                System.Diagnostics.Debug.WriteLine($"Error determinando tipo de disco para {driveName}: {ex.Message}");
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
                System.Diagnostics.Debug.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
                Console.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
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
                    
                    progress?.Report("Verificando permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    
                    progress?.Report("Agregando regla de denegación de acceso...");
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
                    
                    progress?.Report("Protección completada exitosamente");
                    return true;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error protegiendo disco {drivePath}: {ex.Message}");
                    Console.WriteLine($"Error protegiendo disco {drivePath}: {ex.Message}");
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
                    
                    progress?.Report("Desprotección completada exitosamente");
                    return true;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error desprotegiendo disco {drivePath}: {ex.Message}");
                    Console.WriteLine($"Error desprotegiendo disco {drivePath}: {ex.Message}");
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

echo "✅ Funcionalidad completa restaurada"
echo "   Cambios principales:"
echo "   - Restaurada la funcionalidad real de protección/desprotección"
echo "   - Agregada ventana de progreso con el mismo tema visual"
echo "   - Mantenida la funcionalidad de diagnóstico"
echo "   - Mejorada la gestión de errores"
echo "   - Agregado logging completo para diagnóstico"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "2. git add src/DiskProtectorApp/Services/DiskService.cs"
echo "3. git commit -m \"feat: Restaurar funcionalidad completa de protección/desprotección\""
echo "4. git push origin main"
echo ""
echo "Para compilar y generar el release:"
echo "./build-and-release.sh"

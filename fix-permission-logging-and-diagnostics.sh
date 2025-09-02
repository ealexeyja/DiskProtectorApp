#!/bin/bash

echo "=== Corrigiendo logging de permisos y agregando diagnóstico ==="

# Actualizar el servicio de discos con logging más detallado y manejo de errores
cat > src/DiskProtectorApp/Services/DiskService.cs << 'SERVICESDISKEOF'
using DiskProtectorApp.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Threading.Tasks;

namespace DiskProtectorApp.Services
{
    public class DiskService
    {
        // SID constantes para grupos bien conocidos
        private static readonly SecurityIdentifier BUILTIN_USERS_SID = new SecurityIdentifier(WellKnownSidType.BuiltinUsersSid, null);
        private static readonly SecurityIdentifier BUILTIN_ADMINS_SID = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        private static readonly SecurityIdentifier LOCAL_SYSTEM_SID = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);
        private static readonly SecurityIdentifier AUTHENTICATED_USERS_SID = new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null);

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

        /// <summary>
        /// Detecta si un disco está protegido verificando si tiene una regla explícita que deniega Modify a Usuarios.
        /// </summary>
        private bool IsDriveProtected(string drivePath)
        {
            try
            {
                System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Iniciando verificación de protección para: {drivePath}");
                Console.WriteLine($"[PERMISSIONS] Iniciando verificación de protección para: {drivePath}");
                
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                // Buscar una regla explícita que deniega Modify a Usuarios
                foreach (FileSystemAccessRule rule in rules)
                {
                    // Verificar si es una regla de denegación para el grupo de Usuarios
                    if (rule.AccessControlType == AccessControlType.Deny)
                    {
                        System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Regla Deny encontrada - Identity: {rule.IdentityReference.Value}, Rights: {rule.FileSystemRights}");
                        Console.WriteLine($"[PERMISSIONS] Regla Deny encontrada - Identity: {rule.IdentityReference.Value}, Rights: {rule.FileSystemRights}");
                        
                        // Verificar si es el grupo de Usuarios y deniega Modify
                        if (rule.IdentityReference.Value.Equals("Usuarios", StringComparison.OrdinalIgnoreCase) ||
                            rule.IdentityReference.Value.Equals("Users", StringComparison.OrdinalIgnoreCase))
                        {
                            if ((rule.FileSystemRights & FileSystemRights.Modify) == FileSystemRights.Modify)
                            {
                                System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Disco {drivePath} está protegido (regla Deny Modify encontrada)");
                                Console.WriteLine($"[PERMISSIONS] Disco {drivePath} está protegido (regla Deny Modify encontrada)");
                                return true;
                            }
                        }
                    }
                }

                System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Disco {drivePath} NO está protegido (no se encontró regla Deny Modify)");
                Console.WriteLine($"[PERMISSIONS] Disco {drivePath} NO está protegido (no se encontró regla Deny Modify)");
                return false;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
                Console.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
                return false; // En caso de error, asumir que no está protegido
            }
        }

        public async Task<bool> ProtectDriveAsync(string drivePath, IProgress<string> progress)
        {
            return await Task.Run(() =>
            {
                try
                {
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Iniciando protección para: {drivePath}");
                    Console.WriteLine($"[PROTECT] Iniciando protección para: {drivePath}");
                    
                    progress?.Report("Iniciando proceso de protección...");
                    
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Directorio info obtenida: {directoryInfo.FullName}");
                    Console.WriteLine($"[PROTECT] Directorio info obtenida: {directoryInfo.FullName}");
                    
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Permisos actuales obtenidos");
                    Console.WriteLine($"[PROTECT] Permisos actuales obtenidos");
                    
                    progress?.Report("Verificando grupo de Usuarios...");
                    // Obtener el grupo de Usuarios usando su SID
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Grupo Usuarios identificado: {usersAccount.Value}");
                    Console.WriteLine($"[PROTECT] Grupo Usuarios identificado: {usersAccount.Value}");
                    
                    progress?.Report($"Agregando regla de denegación de modificación para {usersAccount.Value}...");
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Creando regla Deny Modify para {usersAccount.Value}");
                    Console.WriteLine($"[PROTECT] Creando regla Deny Modify para {usersAccount.Value}");
                    
                    // Crear una regla que deniega específicamente permisos de modificación a Usuarios
                    var denyRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.Modify, // Denegar solo permisos de modificación
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Deny);
                    
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Regla creada: {denyRule.IdentityReference.Value} - {denyRule.FileSystemRights} - {denyRule.AccessControlType}");
                    Console.WriteLine($"[PROTECT] Regla creada: {denyRule.IdentityReference.Value} - {denyRule.FileSystemRights} - {denyRule.AccessControlType}");
                    
                    security.AddAccessRule(denyRule);
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Regla agregada exitosamente");
                    Console.WriteLine($"[PROTECT] Regla agregada exitosamente");
                    
                    progress?.Report("Aplicando cambios de permisos...");
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Aplicando cambios de seguridad...");
                    Console.WriteLine($"[PROTECT] Aplicando cambios de seguridad...");
                    
                    directoryInfo.SetAccessControl(security);
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Cambios aplicados exitosamente para {drivePath}");
                    Console.WriteLine($"[PROTECT] Cambios aplicados exitosamente para {drivePath}");
                    
                    progress?.Report("Protección completada exitosamente");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] ERROR DE PERMISOS CRÍTICO: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    Console.WriteLine($"[PROTECT] ERROR DE PERMISOS CRÍTICO: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Detalles del error: {authEx.StackTrace}");
                    Console.WriteLine($"[PROTECT] Detalles del error: {authEx.StackTrace}");
                    progress?.Report($"Error de permisos crítico: {authEx.Message}");
                    return false;
                }
                catch (System.Security.SecurityException secEx)
                {
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] ERROR DE SEGURIDAD: No se puede acceder a los permisos de {drivePath}: {secEx.Message}");
                    Console.WriteLine($"[PROTECT] ERROR DE SEGURIDAD: No se puede acceder a los permisos de {drivePath}: {secEx.Message}");
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Detalles del error de seguridad: {secEx.StackTrace}");
                    Console.WriteLine($"[PROTECT] Detalles del error de seguridad: {secEx.StackTrace}");
                    progress?.Report($"Error de seguridad: {secEx.Message}");
                    return false;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Error protegiendo disco {drivePath}: {ex.Message}");
                    Console.WriteLine($"[PROTECT] Error protegiendo disco {drivePath}: {ex.Message}");
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Detalles del error: {ex.StackTrace}");
                    Console.WriteLine($"[PROTECT] Detalles del error: {ex.StackTrace}");
                    progress?.Report($"Error general: {ex.Message}");
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
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Iniciando desprotección para: {drivePath}");
                    Console.WriteLine($"[UNPROTECT] Iniciando desprotección para: {drivePath}");
                    
                    progress?.Report("Iniciando proceso de desprotección...");
                    
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Directorio info obtenida: {directoryInfo.FullName}");
                    Console.WriteLine($"[UNPROTECT] Directorio info obtenida: {directoryInfo.FullName}");
                    
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    var rules = security.GetAccessRules(true, true, typeof(NTAccount));
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Permisos actuales obtenidos. Reglas encontradas: {rules.Count}");
                    Console.WriteLine($"[UNPROTECT] Permisos actuales obtenidos. Reglas encontradas: {rules.Count}");
                    
                    progress?.Report("Buscando reglas de denegación para Usuarios...");
                    // Obtener el grupo de Usuarios usando su SID
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Grupo Usuarios identificado: {usersAccount.Value}");
                    Console.WriteLine($"[UNPROTECT] Grupo Usuarios identificado: {usersAccount.Value}");
                    
                    var rulesToRemove = new List<FileSystemAccessRule>();
                    
                    // Buscar reglas que deniegan Modify a Usuarios
                    foreach (FileSystemAccessRule rule in rules)
                    {
                        System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Evaluando regla - Identity: {rule.IdentityReference.Value}, Type: {rule.AccessControlType}, Rights: {rule.FileSystemRights}");
                        Console.WriteLine($"[UNPROTECT] Evaluando regla - Identity: {rule.IdentityReference.Value}, Type: {rule.AccessControlType}, Rights: {rule.FileSystemRights}");
                        
                        if (rule.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                            rule.AccessControlType == AccessControlType.Deny &&
                            (rule.FileSystemRights & FileSystemRights.Modify) == FileSystemRights.Modify)
                        {
                            rulesToRemove.Add(rule);
                            System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Regla Deny Modify encontrada para remover");
                            Console.WriteLine($"[UNPROTECT] Regla Deny Modify encontrada para remover");
                        }
                    }
                    
                    progress?.Report($"Removiendo {rulesToRemove.Count} reglas de denegación...");
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Reglas para remover: {rulesToRemove.Count}");
                    Console.WriteLine($"[UNPROTECT] Reglas para remover: {rulesToRemove.Count}");
                    
                    foreach (var rule in rulesToRemove)
                    {
                        security.RemoveAccessRule(rule);
                        System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Regla removida: {rule.IdentityReference.Value}");
                        Console.WriteLine($"[UNPROTECT] Regla removida: {rule.IdentityReference.Value}");
                    }
                    
                    progress?.Report("Aplicando cambios de permisos...");
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Aplicando cambios de seguridad...");
                    Console.WriteLine($"[UNPROTECT] Aplicando cambios de seguridad...");
                    
                    directoryInfo.SetAccessControl(security);
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Cambios aplicados exitosamente para {drivePath}");
                    Console.WriteLine($"[UNPROTECT] Cambios aplicados exitosamente para {drivePath}");
                    
                    progress?.Report("Desprotección completada exitosamente");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] ERROR DE PERMISOS CRÍTICO: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    Console.WriteLine($"[UNPROTECT] ERROR DE PERMISOS CRÍTICO: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Detalles del error: {authEx.StackTrace}");
                    Console.WriteLine($"[UNPROTECT] Detalles del error: {authEx.StackTrace}");
                    progress?.Report($"Error de permisos crítico: {authEx.Message}");
                    return false;
                }
                catch (System.Security.SecurityException secEx)
                {
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] ERROR DE SEGURIDAD: No se puede acceder a los permisos de {drivePath}: {secEx.Message}");
                    Console.WriteLine($"[UNPROTECT] ERROR DE SEGURIDAD: No se puede acceder a los permisos de {drivePath}: {secEx.Message}");
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Detalles del error de seguridad: {secEx.StackTrace}");
                    Console.WriteLine($"[UNPROTECT] Detalles del error de seguridad: {secEx.StackTrace}");
                    progress?.Report($"Error de seguridad: {secEx.Message}");
                    return false;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Error desprotegiendo disco {drivePath}: {ex.Message}");
                    Console.WriteLine($"[UNPROTECT] Error desprotegiendo disco {drivePath}: {ex.Message}");
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Detalles del error: {ex.StackTrace}");
                    Console.WriteLine($"[UNPROTECT] Detalles del error: {ex.StackTrace}");
                    progress?.Report($"Error general: {ex.Message}");
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

# Actualizar el ViewModel para asegurar logging completo
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
                
                _disks = value ?? new ObservableCollection<DiskInfo>(); // Corrección CS8601: Asegurar que nunca sea null
                
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
                UpdateSelectedDisksInfo();
            }
        }

        public string StatusMessage
        {
            get => _statusMessage;
            set
            {
                _statusMessage = value ?? string.Empty;
                OnPropertyChanged();
            }
        }

        public string SelectedDisksInfo
        {
            get => _selectedDisksInfo;
            set
            {
                _selectedDisksInfo = value ?? string.Empty;
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
                    UpdateSelectedDisksInfo();
                }
                
                // Actualizar estado de comandos
                UpdateCommandStates();
            }
        }

        private void UpdateSelectedDisksInfo()
        {
            if (_disks == null)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
                return;
            }
            
            var selectedDisks = _disks.Where(d => d.IsSelected).ToList();
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Updating selected disks info. Count: {selectedDisks.Count}");
            Console.WriteLine($"[VIEWMODEL] Updating selected disks info. Count: {selectedDisks.Count}");
            
            if (selectedDisks.Count == 0)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
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
            
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && !d.IsProtected).ToList() ?? new List<DiskInfo>();
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
            
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && d.IsProtected).ToList() ?? new List<DiskInfo>();
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

echo "✅ Logging de permisos y diagnóstico mejorados"
echo "   Cambios principales:"
echo "   - Agregado logging detallado en cada paso del proceso de permisos"
echo "   - Manejo específico de UnauthorizedAccessException y SecurityException"
echo "   - Registro de cada regla de permiso encontrada/creada"
echo "   - Registro de errores críticos con stack trace completo"
echo "   - Logging en múltiples canales (Debug, Console, File)"
echo "   - Mantenido el enfoque de Deny Modify para el grupo Usuarios"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/Services/DiskService.cs"
echo "2. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "3. git commit -m \"fix: Mejorar logging de permisos y diagnóstico detallado\""
echo "4. git push origin main"
echo ""
echo "Luego ejecuta './build-and-release.sh' para generar la nueva versión"
echo ""
echo "Para diagnosticar problemas:"
echo "1. Ejecuta la aplicación y observa los logs en tiempo real"
echo "2. Revisa %APPDATA%\\DiskProtectorApp\\app-debug.log"
echo "3. Revisa %APPDATA%\\DiskProtectorApp\\operations.log"
echo "4. Busca mensajes específicos con prefijos [PERMISSIONS], [PROTECT], [UNPROTECT]"
echo "5. Presta atención a errores de UnauthorizedAccessException o SecurityException"

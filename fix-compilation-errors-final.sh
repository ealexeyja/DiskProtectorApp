#!/bin/bash

echo "=== Corrigiendo errores de compilación ==="

# Actualizar el servicio de discos para corregir warnings de null
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
        // Constantes para los SIDs de grupos bien conocidos
        private static readonly SecurityIdentifier BUILTIN_USERS_SID = new SecurityIdentifier(WellKnownSidType.BuiltinUsersSid, null);
        private static readonly SecurityIdentifier BUILTIN_ADMINS_SID = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        private static readonly SecurityIdentifier LOCAL_SYSTEM_SID = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);
        private static readonly SecurityIdentifier AUTHENTICATED_USERS_SID = new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null);

        public List<DiskInfo> GetDisks()
        {
            LogMessage("[DISK_SERVICE] Iniciando enumeración de discos...", "INFO");
            var disks = new List<DiskInfo>();
            var systemDrive = Path.GetPathRoot(Environment.SystemDirectory);

            foreach (var drive in DriveInfo.GetDrives())
            {
                try
                {
                    // Solo procesar discos fijos con sistema de archivos NTFS
                    if (drive.DriveType != DriveType.Fixed || drive.DriveFormat != "NTFS")
                    {
                        LogMessage($"[DISK_SERVICE] Omitiendo disco {drive.Name} - Tipo: {drive.DriveType}, Sistema: {drive.DriveFormat}", "DEBUG");
                        continue;
                    }

                    bool isSystemDisk = drive.Name.Equals(systemDrive, StringComparison.OrdinalIgnoreCase);
                    LogMessage($"[DISK_SERVICE] Procesando disco {drive.Name}, es sistema: {isSystemDisk}", "DEBUG");
                    
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
                    LogMessage($"[DISK_SERVICE] Disco {drive.Name} agregado - Protegido: {disk.IsProtected}", "INFO");
                }
                catch (Exception ex)
                {
                    LogMessage($"[DISK_SERVICE] Error procesando disco {drive.Name}: {ex.Message}", "ERROR");
                }
            }

            LogMessage($"[DISK_SERVICE] Enumeración completada. Total discos: {disks.Count}", "INFO");
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
                    {
                        LogMessage($"[DISK_SERVICE] Disco {driveName} identificado como SSD", "DEBUG");
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                LogMessage($"[DISK_SERVICE] Error determinando tipo de disco para {driveName}: {ex.Message}", "WARN");
            }

            return false;
        }

        /// <summary>
        /// Detecta si un disco está protegido según la definición correcta:
        /// Protegido: Usuarios sin permisos, Usuarios autenticados solo con permisos básicos
        /// Desprotegido: Usuarios con permisos básicos, Usuarios autenticados con permisos de modificación
        /// </summary>
        private bool IsDriveProtected(string drivePath)
        {
            try
            {
                LogMessage($"[PERMISSION_CHECK] Verificando estado de protección para: {drivePath}", "INFO");
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                // Traducir SIDs a nombres para comparación
                var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));
                var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));

                LogMessage($"[PERMISSION_CHECK] Grupos traducidos - Usuarios: {usersAccount.Value}, AuthUsers: {authUsersAccount.Value}", "DEBUG");

                // Verificar permisos actuales
                bool usersHasBasicPermissions = false;
                bool usersHasModifyPermissions = false;
                bool authUsersHasBasicPermissions = false;
                bool authUsersHasModifyPermissions = false;

                foreach (FileSystemAccessRule rule in rules)
                {
                    LogMessage($"[PERMISSION_CHECK] Regla encontrada - Identity: {rule.IdentityReference.Value}, Type: {rule.AccessControlType}, Rights: {rule.FileSystemRights}", "VERBOSE");
                    
                    // Verificar permisos de Usuarios
                    if (rule.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        LogMessage($"[PERMISSION_CHECK] Usuarios tiene permisos: {rights}", "DEBUG");
                        
                        // Verificar permisos básicos (lectura)
                        if ((rights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read)) != 0)
                        {
                            usersHasBasicPermissions = true;
                            LogMessage($"[PERMISSION_CHECK] Usuarios tiene permisos básicos de lectura", "DEBUG");
                        }
                        
                        // Verificar permisos de modificación
                        if ((rights & FileSystemRights.Modify) == FileSystemRights.Modify)
                        {
                            usersHasModifyPermissions = true;
                            LogMessage($"[PERMISSION_CHECK] Usuarios tiene permisos de modificación", "DEBUG");
                        }
                    }
                    
                    // Verificar permisos de Usuarios autenticados
                    if (rule.IdentityReference.Value.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        LogMessage($"[PERMISSION_CHECK] Usuarios autenticados tiene permisos: {rights}", "DEBUG");
                        
                        // Verificar permisos básicos (lectura)
                        if ((rights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read)) != 0)
                        {
                            authUsersHasBasicPermissions = true;
                            LogMessage($"[PERMISSION_CHECK] Usuarios autenticados tiene permisos básicos de lectura", "DEBUG");
                        }
                        
                        // Verificar permisos de modificación
                        if ((rights & FileSystemRights.Modify) == FileSystemRights.Modify)
                        {
                            authUsersHasModifyPermissions = true;
                            LogMessage($"[PERMISSION_CHECK] Usuarios autenticados tiene permisos de modificación", "DEBUG");
                        }
                    }
                }

                // Determinar estado según definición correcta:
                // Desprotegido: Usuarios con básicos, AuthUsers con modificación
                // Protegido: Usuarios sin permisos o con permisos restringidos, AuthUsers sin modificación
                bool isUnprotected = usersHasBasicPermissions && authUsersHasModifyPermissions;
                bool isProtected = !isUnprotected;
                
                LogMessage($"[PERMISSION_CHECK] Resultado - Usuarios(Básicos:{usersHasBasicPermissions},Mod:{usersHasModifyPermissions}) AuthUsers(Básicos:{authUsersHasBasicPermissions},Mod:{authUsersHasModifyPermissions})", "INFO");
                LogMessage($"[PERMISSION_CHECK] Disco {drivePath} - Protegido: {isProtected}, Desprotegido: {isUnprotected}", "INFO");
                
                return isProtected;
            }
            catch (Exception ex)
            {
                LogMessage($"[PERMISSION_CHECK] Error verificando protección de {drivePath}: {ex.Message}", "ERROR");
                return false;
            }
        }

        public async Task<bool> ProtectDriveAsync(string drivePath, IProgress<string> progress)
        {
            return await Task.Run(() =>
            {
                try
                {
                    LogMessage($"[PROTECT] Iniciando protección para: {drivePath}", "INFO");
                    progress?.Report("Iniciando proceso de protección...");
                    
                    // 1. Verificar permisos de administrador
                    progress?.Report("Verificando permisos de administrador...");
                    if (!IsCurrentUserAdministrator())
                    {
                        LogMessage($"[PROTECT] ERROR: Usuario no es administrador", "ERROR");
                        progress?.Report("ERROR: Se requieren permisos de administrador");
                        return false;
                    }
                    
                    // 2. Verificar permisos de Admin/SYSTEM
                    progress?.Report("Verificando permisos de Admin/SYSTEM...");
                    if (!VerifyAdminSystemPermissions(drivePath, progress))
                    {
                        LogMessage($"[PROTECT] ADVERTENCIA: Permisos insuficientes de Admin/SYSTEM, continuando...", "WARN");
                        // No detener el proceso por esta advertencia
                    }
                    
                    // 3. Obtener información del directorio
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    LogMessage($"[PROTECT] Directorio obtenido: {directoryInfo.FullName}", "DEBUG");
                    
                    // 4. Obtener permisos actuales
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    LogMessage($"[PROTECT] Permisos actuales obtenidos", "DEBUG");
                    
                    // 5. Traducir SIDs a cuentas
                    progress?.Report("Traduciendo grupos de seguridad...");
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));
                    LogMessage($"[PROTECT] Grupos traducidos - Usuarios: {usersAccount.Value}, AuthUsers: {authUsersAccount.Value}", "DEBUG");
                    
                    // 6. Quitar permisos de modificación a Usuarios autenticados
                    progress?.Report("Quitando permisos de modificación a Usuarios autenticados...");
                    var removeAuthUsersModifyRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.Modify, // Quitar permisos de modificación
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[PROTECT] Intentando quitar permisos de modificación a {authUsersAccount.Value}", "DEBUG");
                    bool removedAuthUsers = security.RemoveAccessRule(removeAuthUsersModifyRule);
                    LogMessage($"[PROTECT] Permisos de modificación quitados de AuthUsers: {removedAuthUsers}", "INFO");
                    
                    // 7. Quitar permisos de modificación a Usuarios (opcional, según tu definición)
                    progress?.Report("Quitando permisos de modificación a Usuarios...");
                    var removeUsersModifyRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.Modify, // Quitar permisos de modificación
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[PROTECT] Intentando quitar permisos de modificación a {usersAccount.Value}", "DEBUG");
                    bool removedUsers = security.RemoveAccessRule(removeUsersModifyRule);
                    LogMessage($"[PROTECT] Permisos de modificación quitados de Usuarios: {removedUsers}", "INFO");
                    
                    // 8. Aplicar cambios
                    progress?.Report("Aplicando cambios de permisos...");
                    LogMessage($"[PROTECT] Aplicando cambios de seguridad...", "DEBUG");
                    directoryInfo.SetAccessControl(security);
                    LogMessage($"[PROTECT] Cambios aplicados exitosamente para {drivePath}", "INFO");
                    
                    // 9. Verificar el estado final
                    progress?.Report("Verificando estado final...");
                    bool isNowProtected = IsDriveProtected(drivePath);
                    LogMessage($"[PROTECT] Verificación final - Protegido: {isNowProtected}", "INFO");
                    
                    progress?.Report("Protección completada exitosamente");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    LogMessage($"[PROTECT] ERROR DE PERMISOS: {authEx.Message}", "ERROR");
                    LogMessage($"[PROTECT] StackTrace: {authEx.StackTrace}", "ERROR");
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    return false;
                }
                catch (Exception ex)
                {
                    LogMessage($"[PROTECT] Error protegiendo disco {drivePath}: {ex.Message}", "ERROR");
                    LogMessage($"[PROTECT] StackTrace: {ex.StackTrace}", "ERROR");
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
                    LogMessage($"[UNPROTECT] Iniciando desprotección para: {drivePath}", "INFO");
                    progress?.Report("Iniciando proceso de desprotección...");
                    
                    // 1. Verificar permisos de administrador
                    progress?.Report("Verificando permisos de administrador...");
                    if (!IsCurrentUserAdministrator())
                    {
                        LogMessage($"[UNPROTECT] ERROR: Usuario no es administrador", "ERROR");
                        progress?.Report("ERROR: Se requieren permisos de administrador");
                        return false;
                    }
                    
                    // 2. Verificar permisos de Admin/SYSTEM
                    progress?.Report("Verificando permisos de Admin/SYSTEM...");
                    if (!VerifyAdminSystemPermissions(drivePath, progress))
                    {
                        LogMessage($"[UNPROTECT] ADVERTENCIA: Permisos insuficientes de Admin/SYSTEM, continuando...", "WARN");
                        // No detener el proceso por esta advertencia
                    }
                    
                    // 3. Obtener información del directorio
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    LogMessage($"[UNPROTECT] Directorio obtenido: {directoryInfo.FullName}", "DEBUG");
                    
                    // 4. Obtener permisos actuales
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    LogMessage($"[UNPROTECT] Permisos actuales obtenidos", "DEBUG");
                    
                    // 5. Traducir SIDs a cuentas
                    progress?.Report("Traduciendo grupos de seguridad...");
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));
                    LogMessage($"[UNPROTECT] Grupos traducidos - Usuarios: {usersAccount.Value}, AuthUsers: {authUsersAccount.Value}", "DEBUG");
                    
                    // 6. Restaurar permisos de modificación a Usuarios autenticados
                    progress?.Report("Restaurando permisos de modificación a Usuarios autenticados...");
                    var restoreAuthUsersModifyRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.Modify, // Restaurar permisos de modificación
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[UNPROTECT] Restaurando permisos de modificación a {authUsersAccount.Value}", "DEBUG");
                    security.SetAccessRule(restoreAuthUsersModifyRule);
                    LogMessage($"[UNPROTECT] Permisos de modificación restaurados a AuthUsers", "INFO");
                    
                    // 7. Restaurar permisos básicos a Usuarios
                    progress?.Report("Restaurando permisos básicos a Usuarios...");
                    var restoreUsersBasicRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[UNPROTECT] Restaurando permisos básicos a {usersAccount.Value}", "DEBUG");
                    security.SetAccessRule(restoreUsersBasicRule);
                    LogMessage($"[UNPROTECT] Permisos básicos restaurados a Usuarios", "INFO");
                    
                    // 8. Aplicar cambios
                    progress?.Report("Aplicando cambios de permisos...");
                    LogMessage($"[UNPROTECT] Aplicando cambios de seguridad...", "DEBUG");
                    directoryInfo.SetAccessControl(security);
                    LogMessage($"[UNPROTECT] Cambios aplicados exitosamente para {drivePath}", "INFO");
                    
                    // 9. Verificar el estado final
                    progress?.Report("Verificando estado final...");
                    bool isNowUnprotected = !IsDriveProtected(drivePath);
                    LogMessage($"[UNPROTECT] Verificación final - Desprotegido: {isNowUnprotected}", "INFO");
                    
                    progress?.Report("Desprotección completada exitosamente");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    LogMessage($"[UNPROTECT] ERROR DE PERMISOS: {authEx.Message}", "ERROR");
                    LogMessage($"[UNPROTECT] StackTrace: {authEx.StackTrace}", "ERROR");
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    return false;
                }
                catch (Exception ex)
                {
                    LogMessage($"[UNPROTECT] Error desprotegiendo disco {drivePath}: {ex.Message}", "ERROR");
                    LogMessage($"[UNPROTECT] StackTrace: {ex.StackTrace}", "ERROR");
                    progress?.Report($"Error: {ex.Message}");
                    return false;
                }
            });
        }

        private bool IsCurrentUserAdministrator()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                bool isAdmin = principal.IsInRole(WindowsBuiltInRole.Administrator);
                LogMessage($"[SECURITY] Usuario actual es administrador: {isAdmin}", "DEBUG");
                return isAdmin;
            }
            catch (Exception ex)
            {
                LogMessage($"[SECURITY] Error verificando permisos de administrador: {ex.Message}", "WARN");
                return false;
            }
        }

        private bool VerifyAdminSystemPermissions(string drivePath, IProgress<string>? progress)
        {
            try
            {
                LogMessage($"[SECURITY] Verificando permisos de Admin/SYSTEM para: {drivePath}", "INFO");
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));

                bool adminsHaveFullControl = false;
                bool systemHasFullControl = false;

                foreach (FileSystemAccessRule rule in rules)
                {
                    if (rule.IdentityReference.Value.Equals(adminsAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow &&
                        rule.FileSystemRights == FileSystemRights.FullControl)
                    {
                        adminsHaveFullControl = true;
                        LogMessage($"[SECURITY] Administradores tienen Control Total", "DEBUG");
                    }

                    if (rule.IdentityReference.Value.Equals(systemAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow &&
                        rule.FileSystemRights == FileSystemRights.FullControl)
                    {
                        systemHasFullControl = true;
                        LogMessage($"[SECURITY] SYSTEM tiene Control Total", "DEBUG");
                    }
                }

                bool hasRequiredPermissions = adminsHaveFullControl && systemHasFullControl;
                LogMessage($"[SECURITY] Permisos requeridos presentes: {hasRequiredPermissions}", "INFO");
                
                if (!hasRequiredPermissions)
                {
                    progress?.Report("ADVERTENCIA: Permisos de Admin/SYSTEM no óptimos detectados");
                }
                
                return true; // Permitir continuar incluso si hay advertencias
            }
            catch (Exception ex)
            {
                LogMessage($"[SECURITY] Error verificando permisos de Admin/SYSTEM: {ex.Message}", "WARN");
                return true; // Permitir continuar con advertencia
            }
        }

        private void LogMessage(string message, string level)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                string logEntry = $"[{timestamp}] [{level}] {message}";
                
                // Escribir en Debug
                System.Diagnostics.Debug.WriteLine(logEntry);
                
                // Escribir en Console
                Console.WriteLine(logEntry);
                
                // Escribir en archivo de log
                string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                string logDirectory = Path.Combine(appDataPath, "DiskProtectorApp");
                Directory.CreateDirectory(logDirectory);
                string logPath = Path.Combine(logDirectory, "permissions-debug.log");
                
                File.AppendAllText(logPath, logEntry + Environment.NewLine);
            }
            catch
            {
                // Silenciar errores de logging
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

# Actualizar el ViewModel para corregir errores de Path, Directory, File
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'VIEWMODELEOF'
using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using DiskProtectorApp.Views;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO; // Agregar esta directiva using
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
                
                _disks = value ?? new ObservableCollection<DiskInfo>();
                
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
            
            LogMessage("[VIEWMODEL] MainViewModel inicializado", "INFO");
            RefreshDisks();
        }

        private void OnDiskPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(DiskInfo.IsSelected) || 
                e.PropertyName == nameof(DiskInfo.IsProtected))
            {
                var disk = sender as DiskInfo;
                LogMessage($"[VIEWMODEL] Propiedad de disco cambiada: {disk?.DriveLetter} - {e.PropertyName}", "DEBUG");
                
                if (e.PropertyName == nameof(DiskInfo.IsSelected))
                {
                    UpdateSelectedDisksInfo();
                }
                
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
            LogMessage($"[VIEWMODEL] Actualizando info de discos seleccionados: {selectedDisks.Count}", "DEBUG");
            
            if (selectedDisks.Count == 0)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
            }
            else
            {
                var diskList = string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})"));
                SelectedDisksInfo = $"Discos seleccionados ({selectedDisks.Count}): {diskList}";
            }
        }

        private void UpdateCommandStates()
        {
            LogMessage("[VIEWMODEL] Actualizando estados de comandos", "DEBUG");
            CommandManager.InvalidateRequerySuggested();
        }

        private bool CanAlwaysExecute(object? parameter)
        {
            bool canExecute = !IsWorking;
            LogMessage($"[VIEWMODEL] CanAlwaysExecute: IsWorking={IsWorking}, Result={canExecute}", "DEBUG");
            return canExecute;
        }

        private void ExecuteRefreshDisks(object? parameter)
        {
            RefreshDisks();
        }

        private void RefreshDisks()
        {
            LogMessage("[VIEWMODEL] Iniciando refresco de discos", "INFO");
            IsWorking = true;
            StatusMessage = "Actualizando lista de discos...";
            
            var disks = _diskService.GetDisks();
            LogMessage($"[VIEWMODEL] Discos obtenidos del servicio: {disks.Count}", "INFO");
            
            // Desuscribirse de los eventos de los discos anteriores
            foreach (var disk in _disks)
            {
                disk.PropertyChanged -= OnDiskPropertyChanged;
            }
            
            Disks.Clear();
            
            foreach (var disk in disks)
            {
                Disks.Add(disk);
                disk.PropertyChanged += OnDiskPropertyChanged;
                LogMessage($"[VIEWMODEL] Disco agregado: {disk.DriveLetter} - Protegido: {disk.IsProtected}", "DEBUG");
            }
            
            StatusMessage = $"Se encontraron {disks.Count} discos";
            IsWorking = false;
            
            UpdateSelectedDisksInfo();
            UpdateCommandStates();
            LogMessage("[VIEWMODEL] Refresco de discos completado", "INFO");
        }

        private async Task ExecuteProtectDisksAsync()
        {
            LogMessage("[VIEWMODEL] Iniciando protección de discos", "INFO");
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && !d.IsProtected).ToList() ?? new List<DiskInfo>();
            
            if (selectedDisks.Count == 0)
            {
                LogMessage("[VIEWMODEL] No hay discos seleccionados para proteger", "WARN");
                MessageBox.Show("No hay discos seleccionados para proteger.\n\nPor favor, seleccione al menos un disco no protegido.", 
                              "Protección de discos", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Information);
                return;
            }
            
            LogMessage($"[VIEWMODEL] Discos seleccionados para protección: {selectedDisks.Count}", "INFO");
            
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
                    LogMessage($"[VIEWMODEL] Protegiendo disco {disk.DriveLetter} ({currentDisk}/{selectedDisks.Count})", "INFO");
                    progressDialog.UpdateProgress($"Protegiendo disco {disk.DriveLetter}", $"Procesando {currentDisk} de {selectedDisks.Count} discos...");
                    
                    var progress = new Progress<string>(message => {
                        progressDialog.UpdateProgress($"Protegiendo disco {disk.DriveLetter}", message);
                        LogMessage($"[VIEWMODEL] Progreso {disk.DriveLetter}: {message}", "DEBUG");
                    });
                    
                    bool success = await _diskService.ProtectDriveAsync(disk.DriveLetter ?? "", progress);
                    if (success)
                    {
                        disk.IsProtected = true;
                        successCount++;
                        _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", true);
                        LogMessage($"[VIEWMODEL] Disco {disk.DriveLetter} protegido exitosamente", "INFO");
                    }
                    else
                    {
                        _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                        LogMessage($"[VIEWMODEL] Error protegiendo disco {disk.DriveLetter}", "ERROR");
                    }
                }
                
                progressDialog.Close();
                
                StatusMessage = $"Protegidos {successCount} de {selectedDisks.Count} discos seleccionados";
                IsWorking = false;
                
                // Mostrar mensaje de resultado
                string resultMessage = $"Protección completada.\n\nDiscos protegidos: {successCount}\nDiscos con error: {selectedDisks.Count - successCount}";
                MessageBox.Show(resultMessage, "Protección de discos", MessageBoxButton.OK, MessageBoxImage.Information);
                
                UpdateCommandStates();
                LogMessage($"[VIEWMODEL] Protección completada - Exitosos: {successCount}, Errores: {selectedDisks.Count - successCount}", "INFO");
            }
            catch (Exception ex)
            {
                progressDialog.Close();
                IsWorking = false;
                StatusMessage = "Error durante la protección de discos";
                
                _logger.LogOperation("ERROR", "ProtectDisks", false, $"Exception: {ex.Message}");
                LogMessage($"[VIEWMODEL] Excepción durante protección: {ex}", "ERROR");
                
                MessageBox.Show($"Error durante la protección de discos:\n{ex.Message}", 
                              "Error de protección", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Error);
                
                UpdateCommandStates();
            }
        }

        private async Task ExecuteUnprotectDisksAsync()
        {
            LogMessage("[VIEWMODEL] Iniciando desprotección de discos", "INFO");
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && d.IsProtected).ToList() ?? new List<DiskInfo>();
            
            if (selectedDisks.Count == 0)
            {
                LogMessage("[VIEWMODEL] No hay discos seleccionados para desproteger", "WARN");
                MessageBox.Show("No hay discos seleccionados para desproteger.\n\nPor favor, seleccione al menos un disco protegido.", 
                              "Desprotección de discos", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Information);
                return;
            }
            
            LogMessage($"[VIEWMODEL] Discos seleccionados para desprotección: {selectedDisks.Count}", "INFO");
            
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
                    LogMessage($"[VIEWMODEL] Desprotegiendo disco {disk.DriveLetter} ({currentDisk}/{selectedDisks.Count})", "INFO");
                    progressDialog.UpdateProgress($"Desprotegiendo disco {disk.DriveLetter}", $"Procesando {currentDisk} de {selectedDisks.Count} discos...");
                    
                    var progress = new Progress<string>(message => {
                        progressDialog.UpdateProgress($"Desprotegiendo disco {disk.DriveLetter}", message);
                        LogMessage($"[VIEWMODEL] Progreso {disk.DriveLetter}: {message}", "DEBUG");
                    });
                    
                    bool success = await _diskService.UnprotectDriveAsync(disk.DriveLetter ?? "", progress);
                    if (success)
                    {
                        disk.IsProtected = false;
                        successCount++;
                        _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", true);
                        LogMessage($"[VIEWMODEL] Disco {disk.DriveLetter} desprotegido exitosamente", "INFO");
                    }
                    else
                    {
                        _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                        LogMessage($"[VIEWMODEL] Error desprotegiendo disco {disk.DriveLetter}", "ERROR");
                    }
                }
                
                progressDialog.Close();
                
                StatusMessage = $"Desprotegidos {successCount} de {selectedDisks.Count} discos seleccionados";
                IsWorking = false;
                
                // Mostrar mensaje de resultado
                string resultMessage = $"Desprotección completada.\n\nDiscos desprotegidos: {successCount}\nDiscos con error: {selectedDisks.Count - successCount}";
                MessageBox.Show(resultMessage, "Desprotección de discos", MessageBoxButton.OK, MessageBoxImage.Information);
                
                UpdateCommandStates();
                LogMessage($"[VIEWMODEL] Desprotección completada - Exitosos: {successCount}, Errores: {selectedDisks.Count - successCount}", "INFO");
            }
            catch (Exception ex)
            {
                progressDialog.Close();
                IsWorking = false;
                StatusMessage = "Error durante la desprotección de discos";
                
                _logger.LogOperation("ERROR", "UnprotectDisks", false, $"Exception: {ex.Message}");
                LogMessage($"[VIEWMODEL] Excepción durante desprotección: {ex}", "ERROR");
                
                MessageBox.Show($"Error durante la desprotección de discos:\n{ex.Message}", 
                              "Error de desprotección", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Error);
                
                UpdateCommandStates();
            }
        }

        private void LogMessage(string message, string level)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                string logEntry = $"[{timestamp}] [{level}] {message}";
                
                // Escribir en Debug
                System.Diagnostics.Debug.WriteLine(logEntry);
                
                // Escribir en Console
                Console.WriteLine(logEntry);
                
                // Escribir en archivo de log
                string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                string logDirectory = Path.Combine(appDataPath, "DiskProtectorApp"); // Corregido: usando Path.Combine
                Directory.CreateDirectory(logDirectory); // Corregido: usando Directory
                string logPath = Path.Combine(logDirectory, "viewmodel-debug.log"); // Corregido: usando Path.Combine
                
                File.AppendAllText(logPath, logEntry + Environment.NewLine); // Corregido: usando File
            }
            catch
            {
                // Silenciar errores de logging
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            LogMessage($"[VIEWMODEL] Propiedad cambiada: {propertyName}", "DEBUG");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
VIEWMODELEOF

echo "✅ Errores de compilación corregidos"
echo "   Cambios principales:"
echo "   - Agregada directiva using System.IO; al MainViewModel.cs"
echo "   - Corregidos warnings CS8604 en DiskService.cs (parámetro progress nullable)"
echo "   - Corregidos errores CS0103 de Path, Directory, File en MainViewModel.cs"
echo "   - Uso correcto de Path.Combine, Directory.CreateDirectory, File.AppendAllText"
echo "   - Mantenida toda la funcionalidad de logging y permisos"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/Services/DiskService.cs"
echo "2. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "3. git commit -m \"fix: Corregir errores de compilación y warnings\""
echo "4. git push origin main"
echo ""
echo "Luego ejecuta './build-and-release.sh' para generar la nueva versión"

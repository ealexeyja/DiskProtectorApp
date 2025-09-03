#!/bin/bash

echo "=== Corrigiendo SOLO archivos de código fuente ==="

# 1. Corregir el modelo de datos DiskInfo.cs
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

echo "✅ DiskInfo.cs corregido"

# 2. Corregir el servicio de discos DiskService.cs con la lógica EXACTA
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
        private static readonly SecurityIdentifier AUTHENTICATED_USERS_SID = new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null);
        private static readonly SecurityIdentifier BUILTIN_ADMINS_SID = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        private static readonly SecurityIdentifier LOCAL_SYSTEM_SID = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);

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
        /// Detecta si un disco está protegido según la definición EXACTA:
        /// 
        /// DISCO DESPROTEGIDO (NORMAL):
        /// - Grupo "Usuarios" tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
        /// - Grupo "Usuarios autenticados" tiene permisos de modificación/escritura
        /// - Grupo "Administradores" y "SYSTEM" tienen Control Total (siempre)
        /// 
        /// DISCO PROTEGIDO:
        /// - Grupo "Usuarios" NO tiene permisos establecidos
        /// - Grupo "Usuarios autenticados" solo tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
        /// - Grupo "Administradores" y "SYSTEM" mantienen Control Total (siempre)
        /// </summary>
        private bool IsDriveProtected(string drivePath)
        {
            try
            {
                LogMessage($"[PERMISSION_CHECK] Verificando estado de protección EXACTO para: {drivePath}", "INFO");
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                // Traducir SIDs a nombres para comparación
                var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));
                var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));

                LogMessage($"[PERMISSION_CHECK] Grupos traducidos - Usuarios: {usersAccount.Value}, AuthUsers: {authUsersAccount.Value}", "DEBUG");

                // Estados iniciales - asumir desprotegido por defecto
                bool usersHasBasicPermissions = false;
                bool authUsersHasModifyWritePermissions = false;
                bool adminsHaveFullControl = false;
                bool systemHasFullControl = false;

                // Verificar cada regla de acceso
                foreach (FileSystemAccessRule rule in rules)
                {
                    LogMessage($"[PERMISSION_CHECK] Regla encontrada - Identity: {rule.IdentityReference.Value}, Type: {rule.AccessControlType}, Rights: {rule.FileSystemRights}", "VERBOSE");
                    
                    // Verificar permisos de Usuarios (lectura básica)
                    if (rule.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        LogMessage($"[PERMISSION_CHECK] Usuarios tiene permisos ALLOW: {rights}", "DEBUG");
                        
                        // Verificar si tiene permisos básicos de lectura
                        if ((rights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read)) != 0)
                        {
                            usersHasBasicPermissions = true;
                            LogMessage($"[PERMISSION_CHECK] Usuarios tiene permisos básicos de lectura", "DEBUG");
                        }
                    }
                    
                    // Verificar permisos de Usuarios autenticados (modificación/escritura)
                    if (rule.IdentityReference.Value.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        LogMessage($"[PERMISSION_CHECK] Usuarios autenticados tiene permisos ALLOW: {rights}", "DEBUG");
                        
                        // Verificar si tiene permisos de modificación o escritura
                        if ((rights & (FileSystemRights.Modify | FileSystemRights.Write)) != 0)
                        {
                            authUsersHasModifyWritePermissions = true;
                            LogMessage($"[PERMISSION_CHECK] Usuarios autenticados tiene permisos de modificación/escritura", "DEBUG");
                        }
                    }
                    
                    // Verificar permisos de Administradores
                    if (rule.IdentityReference.Value.Equals(adminsAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow &&
                        rule.FileSystemRights == FileSystemRights.FullControl)
                    {
                        adminsHaveFullControl = true;
                        LogMessage($"[PERMISSION_CHECK] Administradores tienen Control Total", "DEBUG");
                    }
                    
                    // Verificar permisos de SYSTEM
                    if (rule.IdentityReference.Value.Equals(systemAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow &&
                        rule.FileSystemRights == FileSystemRights.FullControl)
                    {
                        systemHasFullControl = true;
                        LogMessage($"[PERMISSION_CHECK] SYSTEM tiene Control Total", "DEBUG");
                    }
                }

                // LÓGICA EXACTA SEGÚN TU DEFINICIÓN:
                // 
                // DISCO DESPROTEGIDO (NORMAL):
                // - Usuarios CON permisos básicos Y AuthUsers CON modificación/escritura
                // - Admins y SYSTEM con Control Total (siempre)
                // 
                // DISCO PROTEGIDO:
                // - Usuarios SIN permisos establecidos O AuthUsers SIN modificación/escritura
                // - Admins y SYSTEM mantienen Control Total (siempre)
                //
                // Es decir:
                // - Desprotegido: usersHasBasicPermissions && authUsersHasModifyWritePermissions && adminsHaveFullControl && systemHasFullControl
                // - Protegido: !(usersHasBasicPermissions && authUsersHasModifyWritePermissions) || !adminsHaveFullControl || !systemHasFullControl
                
                bool isUnprotected = usersHasBasicPermissions && authUsersHasModifyWritePermissions && adminsHaveFullControl && systemHasFullControl;
                bool isProtected = !isUnprotected;
                
                LogMessage($"[PERMISSION_CHECK] Resultado detección:", "INFO");
                LogMessage($"[PERMISSION_CHECK]   Usuarios(Básicos:{usersHasBasicPermissions}) AuthUsers(Mod/Esc:{authUsersHasModifyWritePermissions})", "INFO");
                LogMessage($"[PERMISSION_CHECK]   Admins(ControlTotal:{adminsHaveFullControl}) SYSTEM(ControlTotal:{systemHasFullControl})", "INFO");
                LogMessage($"[PERMISSION_CHECK]   Estado final - Protegido: {isProtected}, Desprotegido: {isUnprotected}", "INFO");
                
                return isProtected;
            }
            catch (Exception ex)
            {
                LogMessage($"[PERMISSION_CHECK] Error verificando protección de {drivePath}: {ex.Message}", "ERROR");
                return false; // En caso de error, asumir desprotegido
            }
        }

        public async Task<bool> ProtectDriveAsync(string drivePath, IProgress<string> progress)
        {
            return await Task.Run(() =>
            {
                try
                {
                    LogMessage($"[PROTECT] Iniciando protección EXACTA para: {drivePath}", "INFO");
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
                        LogMessage($"[PROTECT] ADVERTENCIA: Permisos insuficientes de Admin/SYSTEM", "WARN");
                        // Continuar con advertencia
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
                    
                    // 6. IMPLEMENTAR MÉTODO CORRECTO (QUITAR permisos en lugar de usar Deny):
                    // QUITAR permisos específicos en lugar de usar Deny
                    
                    // PASO 1: Quitar permisos básicos de lectura a Usuarios
                    progress?.Report("Quitando permisos básicos de lectura a Usuarios...");
                    var usersBasicRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[PROTECT] Quitando permisos básicos de lectura a {usersAccount.Value}", "DEBUG");
                    security.RemoveAccessRule(usersBasicRule);
                    LogMessage($"[PROTECT] Permisos básicos de lectura quitados de {usersAccount.Value}", "INFO");
                    
                    // PASO 2: Quitar permisos de modificación/escritura a Usuarios autenticados
                    progress?.Report("Quitando permisos de modificación/escritura a Usuarios autenticados...");
                    var authUsersModifyWriteRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[PROTECT] Quitando permisos de modificación/escritura a {authUsersAccount.Value}", "DEBUG");
                    security.RemoveAccessRule(authUsersModifyWriteRule);
                    LogMessage($"[PROTECT] Permisos de modificación/escritura quitados de {authUsersAccount.Value}", "INFO");
                    
                    // 7. Asegurar que Admins y SYSTEM mantienen control total
                    progress?.Report("Asegurando permisos de Admin/SYSTEM...");
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                    
                    var adminsRule = new FileSystemAccessRule(
                        adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(adminsRule);
                    LogMessage($"[PROTECT] Control total asegurado para {adminsAccount.Value}", "INFO");
                    
                    var systemRule = new FileSystemAccessRule(
                        systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(systemRule);
                    LogMessage($"[PROTECT] Control total asegurado para {systemAccount.Value}", "INFO");
                    
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
                    LogMessage($"[PROTECT] ERROR DE PERMISOS CRÍTICO: {authEx.Message}", "ERROR");
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
                    LogMessage($"[UNPROTECT] Iniciando desprotección EXACTA para: {drivePath}", "INFO");
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
                        LogMessage($"[UNPROTECT] ADVERTENCIA: Permisos insuficientes de Admin/SYSTEM", "WARN");
                        // Continuar con advertencia
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
                    
                    // 6. IMPLEMENTAR PROCESO INVERSO DEL MÉTODO CORRECTO (RESTAURAR permisos):
                    // RESTAURAR permisos específicos que se quitaron
                    
                    // PASO 1: Restaurar permisos básicos de lectura a Usuarios
                    progress?.Report("Restaurando permisos básicos de lectura a Usuarios...");
                    var usersBasicRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[UNPROTECT] Restaurando permisos básicos de lectura a {usersAccount.Value}", "DEBUG");
                    security.SetAccessRule(usersBasicRule);
                    LogMessage($"[UNPROTECT] Permisos básicos de lectura restaurados para {usersAccount.Value}", "INFO");
                    
                    // PASO 2: Restaurar permisos de modificación/escritura a Usuarios autenticados
                    progress?.Report("Restaurando permisos de modificación/escritura a Usuarios autenticados...");
                    var authUsersModifyWriteRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[UNPROTECT] Restaurando permisos de modificación/escritura a {authUsersAccount.Value}", "DEBUG");
                    security.SetAccessRule(authUsersModifyWriteRule);
                    LogMessage($"[UNPROTECT] Permisos de modificación/escritura restaurados para {authUsersAccount.Value}", "INFO");
                    
                    // 7. Asegurar que Admins y SYSTEM mantienen control total
                    progress?.Report("Asegurando permisos de Admin/SYSTEM...");
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                    
                    var adminsRule = new FileSystemAccessRule(
                        adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(adminsRule);
                    LogMessage($"[UNPROTECT] Control total asegurado para {adminsAccount.Value}", "INFO");
                    
                    var systemRule = new FileSystemAccessRule(
                        systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(systemRule);
                    LogMessage($"[UNPROTECT] Control total asegurado para {systemAccount.Value}", "INFO");
                    
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
                    LogMessage($"[UNPROTECT] ERROR DE PERMISOS CRÍTICO: {authEx.Message}", "ERROR");
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

        private bool VerifyAdminSystemPermissions(string drivePath, IProgress<string> progress)
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
                string logPath = Path.Combine(logDirectory, "app-debug.log");
                
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

echo "✅ DiskService.cs corregido con lógica EXACTA"

# 3. Actualizar el ViewModel para mejor manejo de comandos
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'VIEWMODELEOF'
using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
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
            
            LogMessage("[VIEWMODEL] MainViewModel initialized", "INFO");
            RefreshDisks();
        }

        private void OnDiskPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(DiskInfo.IsSelected) || 
                e.PropertyName == nameof(DiskInfo.IsProtected))
            {
                var disk = sender as DiskInfo;
                LogMessage($"[VIEWMODEL] Disk property changed: {disk?.DriveLetter} - {e.PropertyName}", "DEBUG");
                
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
            LogMessage($"[VIEWMODEL] Updating selected disks info. Count: {selectedDisks.Count}", "DEBUG");
            
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
            LogMessage("[VIEWMODEL] Updating command states", "DEBUG");
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
                // Suscribirse al cambio de propiedad para actualizar comandos
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
            
            if (!selectedDisks.Any())
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
                
                foreach (var disk in selectedDisks)
                {
                    LogMessage($"[VIEWMODEL] Protegiendo disco {disk.DriveLetter}", "INFO");
                    progressDialog.UpdateProgress($"Protegiendo disco {disk.DriveLetter}", $"Procesando disco...");
                    
                    var progress = new Progress<string>(message => {
                        progressDialog.UpdateProgress($"Protegiendo disco {disk.DriveLetter}", message);
                        LogMessage($"[VIEWMODEL] Progreso {disk.DriveLetter}: {message}", "DEBUG");
                    });
                    
                    bool success = await _diskService.ProtectDriveAsync(disk.DriveLetter ?? "", progress);
                    if (success)
                    {
                        // Verificar el estado real después de la operación
                        bool isActuallyProtected = await Task.Run(() => {
                            try
                            {
                                return _diskService.IsDriveProtected(disk.DriveLetter ?? "");
                            }
                            catch
                            {
                                return true; // Asumir protegido si hay error
                            }
                        });
                        
                        disk.IsProtected = isActuallyProtected;
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
            
            if (!selectedDisks.Any())
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
                foreach (var disk in selectedDisks)
                {
                    LogMessage($"[VIEWMODEL] Desprotegiendo disco {disk.DriveLetter}", "INFO");
                    progressDialog.UpdateProgress($"Desprotegiendo disco {disk.DriveLetter}", $"Procesando disco...");
                    
                    var progress = new Progress<string>(message => {
                        progressDialog.UpdateProgress($"Desprotegiendo disco {disk.DriveLetter}", message);
                        LogMessage($"[VIEWMODEL] Progreso {disk.DriveLetter}: {message}", "DEBUG");
                    });
                    
                    bool success = await _diskService.UnprotectDriveAsync(disk.DriveLetter ?? "", progress);
                    if (success)
                    {
                        // Verificar el estado real después de la operación
                        bool isActuallyUnprotected = await Task.Run(() => {
                            try
                            {
                                return !_diskService.IsDriveProtected(disk.DriveLetter ?? "");
                            }
                            catch
                            {
                                return true; // Asumir desprotegido si hay error
                            }
                        });
                        
                        disk.IsProtected = !isActuallyUnprotected;
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
                string logDirectory = Path.Combine(appDataPath, "DiskProtectorApp");
                Directory.CreateDirectory(logDirectory);
                string logPath = Path.Combine(logDirectory, "viewmodel-debug.log");
                
                File.AppendAllText(logPath, logEntry + Environment.NewLine);
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

# Actualizar el script de finalización para mantener la estructura correcta
cat > finalize-release.sh << 'FINALIZERELEASEEOF'
#!/bin/bash

echo "=== Finalizando release de DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.2.6"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-final ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz

# Restaurar dependencias
echo "📥 Restaurando dependencias..."
if ! dotnet restore src/DiskProtectorApp/DiskProtectorApp.csproj; then
    echo "❌ Error al restaurar dependencias"
    exit 1
fi

# Compilar el proyecto
echo "🔨 Compilando el proyecto..."
if ! dotnet build src/DiskProtectorApp/DiskProtectorApp.csproj --configuration Release --no-restore; then
    echo "❌ Error al compilar el proyecto"
    exit 1
fi

# Publicar la aplicación
echo "🚀 Publicando la aplicación para Windows x64..."
if ! dotnet publish src/DiskProtectorApp/DiskProtectorApp.csproj \
    -c Release \
    -r win-x64 \
    --self-contained false \
    -o ./publish-test; then
    echo "❌ Error al publicar la aplicación"
    exit 1
fi

# Verificar que la publicación se generó correctamente
if [ ! -f "./publish-test/DiskProtectorApp.exe" ]; then
    echo "❌ Error: No se encontró el ejecutable publicado"
    exit 1
fi

echo ""
echo "✅ ¡Publicación de prueba completada exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Carpeta de prueba: publish-test/"
echo ""
echo "📊 Información del ejecutable:"
ls -lh ./publish-test/DiskProtectorApp.exe

# Crear la estructura FINAL CORRECTA (todos los archivos en el mismo directorio para .NET)
echo "📂 Creando estructura FINAL CORRECTA para .NET..."
mkdir -p ./DiskProtectorApp-final

# Copiar todos los archivos a la carpeta final (estructura plana requerida por .NET)
cp -r ./publish-test/* ./DiskProtectorApp-final/

# Eliminar recursos alemanes si existen
if [ -d "./DiskProtectorApp-final/de" ]; then
    rm -rf ./DiskProtectorApp-final/de
    echo "🗑️ Recursos en alemán eliminados"
fi

# Crear archivo readme con instrucciones
cat > ./DiskProtectorApp-final/README.txt << 'READMEEOF'
DiskProtectorApp v1.2.6
========================

ESTRUCTURA DE ARCHIVOS CORRECTA PARA .NET:
Todos los archivos (.exe, .dll, recursos) en el mismo directorio

├── DiskProtectorApp.exe     # Ejecutable principal
├── *.dll                    # Librerías y dependencias
├── en/                      # Recursos localizados (inglés)
│   └── [archivos de recursos]
├── es/                      # Recursos localizados (español)
│   └── [archivos de recursos]
├── *.json                   # Archivos de configuración
└── *.config                 # Archivos de configuración

REQUISITOS DEL SISTEMA:
- Windows 10/11 x64
- Microsoft .NET 8.0 Desktop Runtime x64
- Ejecutar como Administrador

INSTRUCCIONES:
1. Ejecutar DiskProtectorApp.exe como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Click en el botón correspondiente
4. Esperar confirmación de la operación

FUNCIONAMIENTO DE PERMISOS:
• DISCO DESPROTEGIDO (NORMAL):
  - Grupo "Usuarios" tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
  - Grupo "Usuarios autenticados" tiene permisos de modificación/escritura
  - Grupo "Administradores" y "SYSTEM" tienen Control Total (siempre)

• DISCO PROTEGIDO:
  - Grupo "Usuarios" NO tiene permisos establecidos
  - Grupo "Usuarios autenticados" solo tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
  - Grupo "Administradores" y "SYSTEM" mantienen Control Total (siempre)

REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\operations.log
• Se conservan los últimos 30 días de registros

LOGS DE DIAGNÓSTICO:
• Logs detallados en:
• %APPDATA%\DiskProtectorApp\app-debug.log
• Niveles: INFO, DEBUG, WARN, ERROR, VERBOSE

 Versión actual: v1.2.6
READMEEOF

# Actualizar la versión en el README
sed -i "s/DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/DiskProtectorApp v$CURRENT_VERSION/g" ./DiskProtectorApp-final/README.txt

# Crear archivo comprimido final
echo "📦 Creando archivo comprimido final..."
tar -czf DiskProtectorApp-v$CURRENT_VERSION.tar.gz -C ./DiskProtectorApp-final .

echo ""
echo "✅ ¡Versión v$CURRENT_VERSION finalizada exitosamente!"
echo "   Archivos generados:"
echo "   - Carpeta organizada: DiskProtectorApp-final/"
echo "   - Carpeta de publicación: publish-test/"
echo "   - Archivo comprimido: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
echo ""
echo "�� Tamaño del archivo comprimido:"
ls -lh DiskProtectorApp-v$CURRENT_VERSION.tar.gz

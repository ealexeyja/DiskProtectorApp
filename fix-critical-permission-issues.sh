#!/bin/bash

echo "=== Corrigiendo problemas críticos de permisos y activación de botones ==="

# Crear un script de diagnóstico completo para permisos
cat > src/DiskProtectorApp/Services/PermissionDiagnosticService.cs << 'DIAGNOSTICSERVICEEOF'
using System;
using System.Collections.Generic;
using System.IO;
using System.Security.AccessControl;
using System.Security.Principal;

namespace DiskProtectorApp.Services
{
    public class PermissionDiagnosticService
    {
        public class PermissionInfo
        {
            public string GroupName { get; set; } = string.Empty;
            public string Permissions { get; set; } = string.Empty;
            public string AccessType { get; set; } = string.Empty;
            public bool IsProtectedGroup { get; set; }
            public bool HasBasicReadPermissions { get; set; }
            public bool HasModifyPermissions { get; set; }
        }

        public List<PermissionInfo> GetDetailedPermissions(string drivePath)
        {
            var permissions = new List<PermissionInfo>();
            
            try
            {
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                foreach (FileSystemAccessRule rule in rules)
                {
                    var permissionInfo = new PermissionInfo
                    {
                        GroupName = rule.IdentityReference.Value,
                        Permissions = rule.FileSystemRights.ToString(),
                        AccessType = rule.AccessControlType.ToString(),
                        IsProtectedGroup = IsProtectedGroup(rule.IdentityReference.Value),
                        HasBasicReadPermissions = HasBasicReadPermissions(rule.FileSystemRights),
                        HasModifyPermissions = HasModifyPermissions(rule.FileSystemRights)
                    };
                    
                    permissions.Add(permissionInfo);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error obteniendo permisos detallados para {drivePath}: {ex.Message}");
            }
            
            return permissions;
        }

        private bool IsProtectedGroup(string groupName)
        {
            return groupName.Equals("Usuarios", StringComparison.OrdinalIgnoreCase) ||
                   groupName.Equals("Users", StringComparison.OrdinalIgnoreCase) ||
                   groupName.Equals("Usuarios autenticados", StringComparison.OrdinalIgnoreCase) ||
                   groupName.Equals("Authenticated Users", StringComparison.OrdinalIgnoreCase);
        }

        private bool HasBasicReadPermissions(FileSystemRights rights)
        {
            return (rights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read)) != 0;
        }

        private bool HasModifyPermissions(FileSystemRights rights)
        {
            return (rights & FileSystemRights.Modify) == FileSystemRights.Modify;
        }

        public string GetPermissionSummary(string drivePath)
        {
            var permissions = GetDetailedPermissions(drivePath);
            var summary = $"Permisos detallados para {drivePath}:\n";
            
            foreach (var permission in permissions)
            {
                summary += $"  {permission.GroupName}: {permission.Permissions} ({permission.AccessType})\n";
                summary += $"    - Lectura básica: {permission.HasBasicReadPermissions}\n";
                summary += $"    - Modificación: {permission.HasModifyPermissions}\n";
                summary += $"    - Grupo protegido: {permission.IsProtectedGroup}\n\n";
            }
            
            return summary;
        }
    }
}
DIAGNOSTICSERVICEEOF

# Actualizar el servicio de discos con la lógica correcta de protección/desprotección
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
                        IsSelectable = !isSystemDisk,
                        IsSelectableReason = isSystemDisk ? "Disco del sistema" : "Seleccionable"
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
        /// Detecta si un disco está protegido según la definición CORRECTA:
        /// 
        /// DISCO DESPROTEGIDO (NORMAL):
        /// - Grupo "Usuarios" tiene permisos básicos de lectura (ReadAndExecute, ListDirectory, Read)
        /// - Grupo "Usuarios autenticados" tiene permisos de modificación (Modify)
        /// 
        /// DISCO PROTEGIDO:
        /// - Grupo "Usuarios" NO tiene permisos básicos de lectura
        /// - Grupo "Usuarios autenticados" NO tiene permisos de modificación
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
                bool usersHasBasicReadPermissions = false;
                bool authUsersHasModifyPermissions = false;

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
                            usersHasBasicReadPermissions = true;
                            LogMessage($"[PERMISSION_CHECK] Usuarios tiene permisos básicos de lectura", "DEBUG");
                        }
                    }
                    
                    // Verificar permisos de Usuarios autenticados (modificación)
                    if (rule.IdentityReference.Value.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        LogMessage($"[PERMISSION_CHECK] Usuarios autenticados tiene permisos ALLOW: {rights}", "DEBUG");
                        
                        // Verificar si tiene permisos de modificación
                        if ((rights & FileSystemRights.Modify) == FileSystemRights.Modify)
                        {
                            authUsersHasModifyPermissions = true;
                            LogMessage($"[PERMISSION_CHECK] Usuarios autenticados tiene permisos de modificación", "DEBUG");
                        }
                    }
                }

                // LÓGICA EXACTA CORRECTA:
                // 
                // DESPROTEGIDO (NORMAL): Usuarios CON lectura básica Y AuthUsers CON modificación
                // PROTEGIDO: Usuarios SIN lectura básica O AuthUsers SIN modificación
                //
                // Es decir:
                // - Protegido: !usersHasBasicReadPermissions || !authUsersHasModifyPermissions
                // - Desprotegido: usersHasBasicReadPermissions && authUsersHasModifyPermissions
                
                bool isUnprotected = usersHasBasicReadPermissions && authUsersHasModifyPermissions;
                bool isProtected = !isUnprotected;
                
                LogMessage($"[PERMISSION_CHECK] Resultado detección - Usuarios(Lectura:{usersHasBasicReadPermissions}) AuthUsers(Modificación:{authUsersHasModifyPermissions})", "INFO");
                LogMessage($"[PERMISSION_CHECK] Estado final - Protegido: {isProtected}, Desprotegido: {isUnprotected}", "INFO");
                
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
                    
                    // 2. Verificar permisos de Admin/SYSTEM antes de operar
                    progress?.Report("Verificando permisos de Admin/SYSTEM...");
                    if (!VerifyAdminSystemPermissions(drivePath, progress))
                    {
                        LogMessage($"[PROTECT] ADVERTENCIA: Permisos insuficientes de Admin/SYSTEM", "WARN");
                        progress?.Report("ADVERTENCIA: Permisos insuficientes de Admin/SYSTEM");
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
                    
                    // 6. QUITAR permisos específicos (NO usar Deny):
                    // QUITAR permisos básicos de lectura a Usuarios
                    progress?.Report("Quitando permisos básicos de lectura a Usuarios...");
                    var usersBasicReadRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[PROTECT] Quitando permisos básicos de lectura a {usersAccount.Value}", "DEBUG");
                    security.RemoveAccessRule(usersBasicReadRule);
                    LogMessage($"[PROTECT] Permisos básicos de lectura quitados de {usersAccount.Value}", "INFO");
                    
                    // QUITAR permisos de modificación a Usuarios autenticados
                    progress?.Report("Quitando permisos de modificación a Usuarios autenticados...");
                    var authUsersModifyRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.Modify,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[PROTECT] Quitando permisos de modificación a {authUsersAccount.Value}", "DEBUG");
                    security.RemoveAccessRule(authUsersModifyRule);
                    LogMessage($"[PROTECT] Permisos de modificación quitados de {authUsersAccount.Value}", "INFO");
                    
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
                    
                    // 2. Verificar permisos de Admin/SYSTEM antes de operar
                    progress?.Report("Verificando permisos de Admin/SYSTEM...");
                    if (!VerifyAdminSystemPermissions(drivePath, progress))
                    {
                        LogMessage($"[UNPROTECT] ADVERTENCIA: Permisos insuficientes de Admin/SYSTEM", "WARN");
                        progress?.Report("ADVERTENCIA: Permisos insuficientes de Admin/SYSTEM");
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
                    
                    // 6. RESTAURAR permisos específicos (operación inversa):
                    // RESTAURAR permisos básicos de lectura a Usuarios
                    progress?.Report("Restaurando permisos básicos de lectura a Usuarios...");
                    var usersBasicReadRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[UNPROTECT] Restaurando permisos básicos de lectura a {usersAccount.Value}", "DEBUG");
                    security.SetAccessRule(usersBasicReadRule);
                    LogMessage($"[UNPROTECT] Permisos básicos de lectura restaurados para {usersAccount.Value}", "INFO");
                    
                    // RESTAURAR permisos de modificación a Usuarios autenticados
                    progress?.Report("Restaurando permisos de modificación a Usuarios autenticados...");
                    var authUsersModifyRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.Modify,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[UNPROTECT] Restaurando permisos de modificación a {authUsersAccount.Value}", "DEBUG");
                    security.SetAccessRule(authUsersModifyRule);
                    LogMessage($"[UNPROTECT] Permisos de modificación restaurados para {authUsersAccount.Value}", "INFO");
                    
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

# Actualizar el ViewModel para corregir la activación de botones
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
            
            ProtectCommand = new RelayCommand(async (parameter) => await ExecuteProtectDisksAsync(), CanPerformProtectOperation);
            UnprotectCommand = new RelayCommand(async (parameter) => await ExecuteUnprotectDisksAsync(), CanPerformUnprotectOperation);
            RefreshCommand = new RelayCommand(ExecuteRefreshDisks);
            
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] MainViewModel initialized");
            RefreshDisks();
        }

        private void OnDiskPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(DiskInfo.IsSelected) || 
                e.PropertyName == nameof(DiskInfo.IsProtected))
            {
                var disk = sender as DiskInfo;
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Disk property changed: {disk?.DriveLetter} - {e.PropertyName}");
                
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
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] Updating command states");
            
            // Forzar actualización de comandos
            CommandManager.InvalidateRequerySuggested();
        }

        private bool CanPerformProtectOperation(object? parameter)
        {
            // Puede proteger si:
            // - No está trabajando
            // - Hay discos seleccionados
            // - Los discos seleccionados son seleccionables
            // - Los discos seleccionados NO están protegidos actualmente
            bool canProtect = !IsWorking && 
                             _disks != null && 
                             _disks.Any(d => d.IsSelected && d.IsSelectable && !d.IsProtected);
            
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] CanPerformProtectOperation: IsWorking={IsWorking}, DisksCount={_disks?.Count ?? 0}, SelectedCount={_disks?.Count(d => d.IsSelected && d.IsSelectable && !d.IsProtected) ?? 0}, Result={canProtect}");
            return canProtect;
        }

        private bool CanPerformUnprotectOperation(object? parameter)
        {
            // Puede desproteger si:
            // - No está trabajando
            // - Hay discos seleccionados
            // - Los discos seleccionados son seleccionables
            // - Los discos seleccionados ESTÁN protegidos actualmente
            bool canUnprotect = !IsWorking && 
                               _disks != null && 
                               _disks.Any(d => d.IsSelected && d.IsSelectable && d.IsProtected);
            
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] CanPerformUnprotectOperation: IsWorking={IsWorking}, DisksCount={_disks?.Count ?? 0}, SelectedCount={_disks?.Count(d => d.IsSelected && d.IsSelectable && d.IsProtected) ?? 0}, Result={canUnprotect}");
            return canUnprotect;
        }

        private void ExecuteRefreshDisks(object? parameter)
        {
            RefreshDisks();
        }

        private void RefreshDisks()
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] Refreshing disks");
            IsWorking = true;
            StatusMessage = "Actualizando lista de discos...";
            
            var disks = _diskService.GetDisks();
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Got {disks.Count} disks from service");
            
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
            
            // Actualizar información de discos seleccionados
            UpdateSelectedDisksInfo();
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private async Task ExecuteProtectDisksAsync()
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] Executing protect disks");
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && !d.IsProtected).ToList() ?? new List<DiskInfo>();
            
            if (selectedDisks.Count == 0)
            {
                System.Diagnostics.Debug.WriteLine("[VIEWMODEL] No disks selected for protection");
                MessageBox.Show("No hay discos seleccionados para proteger.\n\nPor favor, seleccione al menos un disco no protegido.", 
                              "Protección de discos", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Information);
                return;
            }
            
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Protecting {selectedDisks.Count} disks");
            
            IsWorking = true;
            StatusMessage = $"Protegiendo {selectedDisks.Count} disco(s)...";

            int successCount = 0;
            
            foreach (var disk in selectedDisks)
            {
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Protecting disk {disk.DriveLetter}");
                var progress = new Progress<string>(message => {
                    StatusMessage = $"Protegiendo {disk.DriveLetter}: {message}";
                });
                
                bool success = await _diskService.ProtectDriveAsync(disk.DriveLetter ?? "", progress);
                if (success)
                {
                    // ACTUALIZAR EL ESTADO INMEDIATAMENTE DESPUÉS DE LA OPERACIÓN
                    disk.IsProtected = true;
                    successCount++;
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", true);
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Successfully protected disk {disk.DriveLetter}");
                }
                else
                {
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Failed to protect disk {disk.DriveLetter}");
                }
            }

            StatusMessage = $"Protegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // Mostrar mensaje de resultado
            string resultMessage = $"Protección completada.\n\nDiscos protegidos: {successCount}\nDiscos con error: {selectedDisks.Count - successCount}";
            MessageBox.Show(resultMessage, "Protección de discos", MessageBoxButton.OK, MessageBoxImage.Information);
            
            // ACTUALIZAR INMEDIATAMENTE LOS ESTADOS DE LOS COMANDOS
            UpdateCommandStates();
        }

        private async Task ExecuteUnprotectDisksAsync()
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] Executing unprotect disks");
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && d.IsProtected).ToList() ?? new List<DiskInfo>();
            
            if (selectedDisks.Count == 0)
            {
                System.Diagnostics.Debug.WriteLine("[VIEWMODEL] No disks selected for unprotection");
                MessageBox.Show("No hay discos seleccionados para desproteger.\n\nPor favor, seleccione al menos un disco protegido.", 
                              "Desprotección de discos", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Information);
                return;
            }
            
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Unprotecting {selectedDisks.Count} disks");
            
            IsWorking = true;
            StatusMessage = $"Desprotegiendo {selectedDisks.Count} disco(s)...";

            int successCount = 0;
            foreach (var disk in selectedDisks)
            {
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Unprotecting disk {disk.DriveLetter}");
                var progress = new Progress<string>(message => {
                    StatusMessage = $"Desprotegiendo {disk.DriveLetter}: {message}";
                });
                
                bool success = await _diskService.UnprotectDriveAsync(disk.DriveLetter ?? "", progress);
                if (success)
                {
                    // ACTUALIZAR EL ESTADO INMEDIATAMENTE DESPUÉS DE LA OPERACIÓN
                    disk.IsProtected = false;
                    successCount++;
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", true);
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Successfully unprotected disk {disk.DriveLetter}");
                }
                else
                {
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Failed to unprotect disk {disk.DriveLetter}");
                }
            }

            StatusMessage = $"Desprotegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // Mostrar mensaje de resultado
            string resultMessage = $"Desprotección completada.\n\nDiscos desprotegidos: {successCount}\nDiscos con error: {selectedDisks.Count - successCount}";
            MessageBox.Show(resultMessage, "Desprotección de discos", MessageBoxButton.OK, MessageBoxImage.Information);
            
            // ACTUALIZAR INMEDIATAMENTE LOS ESTADOS DE LOS COMANDOS
            UpdateCommandStates();
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] OnPropertyChanged: {propertyName}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
VIEWMODELEOF

# Actualizar el script de finalización para mantener la estructura correcta
cat > src/DiskProtectorApp/Scripts/finalize-release.sh << 'FINALIZERELEASEEOF'
#!/bin/bash

echo "=== Finalizando release de DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto. Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.1.0"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-final

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
    -o ./publish-v$CURRENT_VERSION; then
    echo "❌ Error al publicar la aplicación"
    exit 1
fi

# Verificar que la publicación se generó correctamente
if [ ! -f "./publish-v$CURRENT_VERSION/DiskProtectorApp.exe" ]; then
    echo "❌ Error: No se encontró el ejecutable publicado"
    exit 1
fi

echo ""
echo "✅ ¡Publicación completada exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Carpeta de publicación: publish-v$CURRENT_VERSION/"
echo ""
echo "📊 Información del ejecutable:"
ls -lh ./publish-v$CURRENT_VERSION/DiskProtectorApp.exe

# Crear la estructura FINAL CORRECTA (todos los archivos en el mismo directorio para .NET)
echo "📂 Creando estructura FINAL CORRECTA para .NET..."

# La estructura correcta para aplicaciones .NET es:
# Todos los archivos (.exe, .dll, recursos) en el mismo directorio
mkdir -p ./DiskProtectorApp-final

# Copiar todos los archivos a la carpeta final (estructura plana requerida por .NET)
cp -r ./publish-v$CURRENT_VERSION/* ./DiskProtectorApp-final/

# Eliminar recursos alemanes si existen
if [ -d "./DiskProtectorApp-final/de" ]; then
    rm -rf ./DiskProtectorApp-final/de
    echo "🗑️ Recursos en alemán eliminados"
fi

# Crear archivo readme con instrucciones
cat > ./DiskProtectorApp-final/README.txt << 'READMEEOF'
DiskProtectorApp v1.1.0
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
  - Grupo "Usuarios" tiene permisos básicos de lectura (ReadAndExecute, ListDirectory, Read)
  - Grupo "Usuarios autenticados" tiene permisos de modificación (Modify)
  
• DISCO PROTEGIDO:
  - Grupo "Usuarios" NO tiene permisos básicos de lectura
  - Grupo "Usuarios autenticados" NO tiene permisos de modificación

• GRUPOS QUE MANTIENEN CONTROL TOTAL:
  - Administradores
  - SYSTEM

REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\operations.log
• Se conservan los últimos 30 días de registros

LOGS DE DIAGNÓSTICO:
• Logs detallados en:
• %APPDATA%\DiskProtectorApp\app-debug.log
• Niveles: INFO, DEBUG, WARN, ERROR, VERBOSE

 Versión actual: v1.1.0
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
echo "   - Carpeta de publicación: publish-v$CURRENT_VERSION/"
echo "   - Archivo comprimido: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
echo ""
echo "📊 Tamaño del archivo comprimido:"
ls -lh DiskProtectorApp-v$CURRENT_VERSION.tar.gz

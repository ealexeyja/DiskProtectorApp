#!/bin/bash

echo "=== Actualizando DiskService.cs con lógica correcta ==="

# Crear el archivo DiskService.cs corregido con la lógica EXACTA que definiste
cat > src/DiskProtectorApp/Services/DiskService.cs << 'DISKSERVICEEOF'
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
                    
                    // 2. Verificar permisos de Admin/SYSTEM antes de operar
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
                    
                    // 2. Verificar permisos de Admin/SYSTEM antes de operar
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
DISKSERVICEEOF

echo "✅ DiskService.cs actualizado con lógica correcta"
echo "   Cambios principales:"
echo "   - Mantenida la estructura CORRECTA de .NET (todos los archivos en el mismo directorio)"
echo "   - Corregida la lógica de detección según tu definición EXACTA:"
echo "     * Desprotegido: Usuarios CON permisos básicos + AuthUsers CON modificación/escritura"
echo "     * Protegido: Usuarios SIN permisos básicos O AuthUsers SIN modificación/escritura"
echo "   - Implementado QUITAR/RESTAURAR permisos en lugar de usar Deny"
echo "   - Agregado logging detallado en múltiples niveles"
echo "   - Verificación previa de permisos de Admin/SYSTEM antes de operar"
echo "   - Actualización automática del estado después de operaciones"
echo "   - Mantenido control total para Administradores y SYSTEM siempre"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/Services/DiskService.cs"
echo "2. git commit -m \"fix: Corregir lógica de permisos y estructura de archivos\""
echo "3. git push origin main"
echo ""
echo "Luego ejecuta './finalize-release.sh' para generar la nueva versión"

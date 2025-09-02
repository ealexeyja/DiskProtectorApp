#!/bin/bash

echo "=== Implementando lógica EXACTA de permisos según especificación ==="

# Actualizar el servicio de discos con la lógica correcta
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
        /// Detecta si un disco está protegido según la definición EXACTA:
        /// 
        /// DESPROTEGIDO (NORMAL):
        /// - Grupo "Usuarios" tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
        /// - Grupo "Usuarios autenticados" tiene permisos de modificación y escritura
        /// 
        /// PROTEGIDO:
        /// - Grupo "Usuarios" NO tiene NINGÚN permiso establecido
        /// - Grupo "Usuarios autenticados" solo tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
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
                bool usersHasAnyPermissions = false;
                bool usersHasBasicPermissions = false;
                bool authUsersHasModifyWritePermissions = false;
                bool authUsersHasBasicPermissions = false;

                // Verificar cada regla de acceso
                foreach (FileSystemAccessRule rule in rules)
                {
                    LogMessage($"[PERMISSION_CHECK] Regla encontrada - Identity: {rule.IdentityReference.Value}, Type: {rule.AccessControlType}, Rights: {rule.FileSystemRights}", "VERBOSE");
                    
                    // Verificar permisos de Usuarios
                    if (rule.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        usersHasAnyPermissions = true;
                        var rights = rule.FileSystemRights;
                        LogMessage($"[PERMISSION_CHECK] Usuarios tiene permisos ALLOW: {rights}", "DEBUG");
                        
                        // Verificar permisos básicos (lectura y ejecución, mostrar contenido de carpeta, lectura)
                        if ((rights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read)) != 0)
                        {
                            usersHasBasicPermissions = true;
                            LogMessage($"[PERMISSION_CHECK] Usuarios tiene permisos básicos de lectura", "DEBUG");
                        }
                    }
                    
                    // Verificar permisos de Usuarios autenticados
                    if (rule.IdentityReference.Value.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        LogMessage($"[PERMISSION_CHECK] Usuarios autenticados tiene permisos ALLOW: {rights}", "DEBUG");
                        
                        // Verificar permisos básicos (lectura y ejecución, mostrar contenido de carpeta, lectura)
                        if ((rights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read)) != 0)
                        {
                            authUsersHasBasicPermissions = true;
                            LogMessage($"[PERMISSION_CHECK] Usuarios autenticados tiene permisos básicos de lectura", "DEBUG");
                        }
                        
                        // Verificar permisos de modificación/escritura
                        if ((rights & (FileSystemRights.Modify | FileSystemRights.Write)) != 0)
                        {
                            authUsersHasModifyWritePermissions = true;
                            LogMessage($"[PERMISSION_CHECK] Usuarios autenticados tiene permisos de modificación/escritura", "DEBUG");
                        }
                    }
                }

                // LÓGICA EXACTA SEGÚN TU DEFINICIÓN:
                // 
                // DESPROTEGIDO (NORMAL):
                // - Usuarios CON permisos básicos Y AuthUsers CON modificación/escritura
                // 
                // PROTEGIDO:
                // - Usuarios SIN permisos Y AuthUsers SOLO con permisos básicos (sin modificación/escritura)
                //
                // Es decir:
                // - Desprotegido: usersHasBasicPermissions=true && authUsersHasModifyWritePermissions=true
                // - Protegido: usersHasAnyPermissions=false && authUsersHasBasicPermissions=true && authUsersHasModifyWritePermissions=false
                
                bool isUnprotected = usersHasBasicPermissions && authUsersHasModifyWritePermissions;
                bool isProtected = !usersHasAnyPermissions && authUsersHasBasicPermissions && !authUsersHasModifyWritePermissions;
                
                LogMessage($"[PERMISSION_CHECK] Resultado detección:", "INFO");
                LogMessage($"[PERMISSION_CHECK]   Usuarios(Cualquier:{usersHasAnyPermissions}, Básicos:{usersHasBasicPermissions})", "INFO");
                LogMessage($"[PERMISSION_CHECK]   AuthUsers(Básicos:{authUsersHasBasicPermissions}, Mod/Esc:{authUsersHasModifyWritePermissions})", "INFO");
                LogMessage($"[PERMISSION_CHECK]   Estado final - Protegido: {isProtected}, Desprotegido: {isUnprotected}", "INFO");
                
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
                    
                    // 6. IMPLEMENTAR MÉTODO EXACTO SEGÚN TU DEFINICIÓN:
                    // QUITAR permisos específicos SIN USAR DENY
                    progress?.Report("Quitando permisos de Usuarios...");
                    
                    // Quitar TODOS los permisos de Usuarios
                    var usersAllRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[PROTECT] Quitando todos los permisos de {usersAccount.Value}", "DEBUG");
                    security.RemoveAccessRuleAll(usersAllRule);
                    LogMessage($"[PROTECT] Todos los permisos quitados de {usersAccount.Value}", "INFO");
                    
                    // Quitar permisos de modificación/escritura de Usuarios autenticados
                    progress?.Report("Quitando permisos de modificación/escritura de Usuarios autenticados...");
                    var authUsersModifyWriteRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[PROTECT] Quitando permisos de modificación/escritura de {authUsersAccount.Value}", "DEBUG");
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
                    
                    // 6. IMPLEMENTAR PROCESO INVERSO DEL MÉTODO EXACTO:
                    // RESTAURAR permisos específicos que se quitaron
                    progress?.Report("Restaurando permisos básicos de lectura a Usuarios...");
                    
                    // Restaurar permisos básicos de lectura a Usuarios
                    var usersBasicRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    LogMessage($"[UNPROTECT] Restaurando permisos básicos de lectura a {usersAccount.Value}", "DEBUG");
                    security.SetAccessRule(usersBasicRule);
                    LogMessage($"[UNPROTECT] Permisos básicos de lectura restaurados para {usersAccount.Value}", "INFO");
                    
                    progress?.Report("Restaurando permisos de modificación/escritura a Usuarios autenticados...");
                    // Restaurar permisos de modificación/escritura a Usuarios autenticados
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
rm -rf ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-final ./DiskProtectorApp-organized

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

# Crear la estructura CORRECTA para .NET (todos los archivos en el mismo directorio)
echo "📂 Creando estructura CORRECTA para .NET..."
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

INSTRUCCIONES DE USO:
1. Ejecutar DiskProtectorApp.exe como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Click en el botón correspondiente
4. Esperar confirmación de la operación

FUNCIONAMIENTO DE PERMISOS:
• DESPROTEGIDO (NORMAL):
  - Grupo "Usuarios" tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
  - Grupo "Usuarios autenticados" tiene permisos de modificación y escritura
  - Grupo "Administradores" y "SYSTEM" tienen Control Total

• PROTEGIDO:
  - Grupo "Usuarios" NO tiene NINGÚN permiso establecido
  - Grupo "Usuarios autenticados" solo tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
  - Grupo "Administradores" y "SYSTEM" mantienen Control Total

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

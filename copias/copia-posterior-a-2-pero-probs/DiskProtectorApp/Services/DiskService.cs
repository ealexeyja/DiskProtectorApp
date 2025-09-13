using DiskProtectorApp.Logging;
using DiskProtectorApp.Models;
using System;
using System.Collections.Generic;
using System.Diagnostics;
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
            SimpleLogger.LogService("Starting GetDisks");
            var disks = new List<DiskInfo>();
            var systemDrive = Path.GetPathRoot(Environment.SystemDirectory);

            foreach (var drive in DriveInfo.GetDrives())
            {
                try
                {
                    SimpleLogger.LogService($"Processing drive: {drive.Name}");
                    
                    // Solo procesar discos fijos con sistema de archivos NTFS
                    if (drive.DriveType != DriveType.Fixed || drive.DriveFormat != "NTFS")
                    {
                        SimpleLogger.LogService($"Drive {drive.Name} is not fixed or not NTFS, marking as not selectable...");
                        var nonFixedDisk = new DiskInfo
                        {
                            DriveLetter = drive.Name,
                            VolumeName = drive.VolumeLabel ?? "Sin etiqueta",
                            TotalSize = FormatBytes(drive.TotalSize),
                            FreeSpace = FormatBytes(drive.AvailableFreeSpace),
                            IsSelectable = false, // No es seleccionable porque no es fijo o no es NTFS
                            IsProtected = false, // No aplica
                            ProtectionStatus = "No Elegible",
                            IsSystemDisk = false,
                            IsManageable = false
                        };
                        disks.Add(nonFixedDisk);
                        continue;
                    }

                    var drivePath = drive.Name;
                    bool isSystemDisk = string.Equals(drivePath, systemDrive, StringComparison.OrdinalIgnoreCase);
                    
                    SimpleLogger.LogService($"Drive {drive.Name} is NTFS. Is system drive: {isSystemDisk}");

                    var disk = new DiskInfo
                    {
                        DriveLetter = drive.Name,
                        VolumeName = drive.VolumeLabel ?? "Sin etiqueta",
                        TotalSize = FormatBytes(drive.TotalSize),
                        FreeSpace = FormatBytes(drive.AvailableFreeSpace),
                        IsSystemDisk = isSystemDisk,
                        IsSelectable = !isSystemDisk, // El disco del sistema no es seleccionable
                        IsProtected = false // Valor inicial, se determinará después
                    };

                    // Establecer estado de protección y administrabilidad (solo si es seleccionable)
                    if (disk.IsSelectable)
                    {
                        // Verificar si es administrable primero
                        disk.IsManageable = IsDriveManageable(drivePath);
                        SimpleLogger.LogService($"Drive {drive.Name} is manageable: {disk.IsManageable}");
                        
                        if (!disk.IsManageable)
                        {
                            disk.ProtectionStatus = "No Administrable";
                            disk.IsProtected = false; // No puede estar protegido si no es administrable
                        }
                        else
                        {
                            // Solo verificar estado de protección si es administrable
                            disk.IsProtected = IsDriveProtected(drivePath);
                            SimpleLogger.LogService($"Drive {drive.Name} is selectable and manageable. Protected: {disk.IsProtected}");
                            disk.ProtectionStatus = disk.IsProtected ? "Protegido" : "Desprotegido";
                        }
                    }
                    else
                    {
                        disk.ProtectionStatus = "No Elegible";
                        disk.IsManageable = false; // Forzar a no administrable si no es elegible
                        disk.IsProtected = false; // Forzar a no protegido si no es elegible
                        SimpleLogger.LogService($"Drive {drive.Name} is not selectable (system drive or non-NTFS)");
                    }

                    disks.Add(disk);
                }
                catch (Exception ex)
                {
                    // Loggear errores pero continuar con otros discos
                    SimpleLogger.Error(LogCategory.Service, $"Error processing drive {drive.Name}", ex);
                }
            }

            SimpleLogger.LogService($"GetDisks completed. Total disks: {disks.Count}");
            return disks;
        }

        /// <summary>
        /// Verifica si un disco es administrable (Administradores y SYSTEM tienen Control Total)
        /// </summary>
        public bool IsDriveManageable(string drivePath)
        {
            try
            {
                SimpleLogger.LogService($"Checking if drive {drivePath} is manageable...");
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                // Traducir SIDs a nombres para comparación
                var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));

                bool adminsHasFullControl = false;
                bool systemHasFullControl = false;

                // Verificar cada regla de acceso
                foreach (FileSystemAccessRule rule in rules)
                {
                    // Verificar permisos de Administradores
                    if (rule.IdentityReference.Value.Equals(adminsAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        if ((rights & FileSystemRights.FullControl) == FileSystemRights.FullControl)
                        {
                            adminsHasFullControl = true;
                            SimpleLogger.LogService($"Administrators have Full Control on {drivePath}");
                        }
                    }

                    // Verificar permisos de SYSTEM
                    if (rule.IdentityReference.Value.Equals(systemAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        if ((rights & FileSystemRights.FullControl) == FileSystemRights.FullControl)
                        {
                            systemHasFullControl = true;
                            SimpleLogger.LogService($"SYSTEM has Full Control on {drivePath}");
                        }
                    }
                }

                // Un disco es administrable si ambos grupos tienen Control Total
                bool isManageable = adminsHasFullControl && systemHasFullControl;
                SimpleLogger.LogService($"Drive {drivePath} is manageable: {isManageable}");
                return isManageable;
            }
            catch (Exception ex)
            {
                SimpleLogger.Error(LogCategory.Service, $"Error checking manageability for {drivePath}", ex);
                return false; // En caso de error, asumir no administrable
            }
        }

        /// <summary>
        /// Verifica si un disco está protegido según la lógica definida:
        /// (SOLO se aplica a discos elegibles y administrables)
        /// 
        /// DISCO DESPROTEGIDO (NORMAL):
        /// - Grupo "Usuarios" tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
        /// - Grupo "Usuarios autenticados" tiene permisos de modificación/escritura
        /// 
        /// DISCO PROTEGIDO:
        /// - Grupo "Usuarios" NO tiene permisos establecidos
        /// - Grupo "Usuarios autenticados" solo tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
        /// </summary>
        private bool IsDriveProtected(string drivePath)
        {
            try
            {
                SimpleLogger.LogService($"Checking protection status for drive: {drivePath}");
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                // Traducir SIDs a nombres para comparación
                var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));

                // Estados iniciales - asumir desprotegido por defecto
                bool usersHasBasicPermissions = false;
                bool authUsersHasBasicPermissions = false;
                bool authUsersHasModifyWritePermissions = false;

                // Verificar cada regla de acceso
                foreach (FileSystemAccessRule rule in rules)
                {
                    // Verificar permisos de Usuarios (lectura básica)
                    if (rule.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        // Verificar si tiene permisos básicos de lectura
                        if ((rights & (FileSystemRights.ReadAndExecute |
                                      FileSystemRights.ListDirectory |
                                      FileSystemRights.Read)) != 0)
                        {
                            usersHasBasicPermissions = true;
                            SimpleLogger.LogService($"Users have basic permissions on {drivePath}");
                        }
                    }

                    // Verificar permisos de Usuarios autenticados (lectura básica y modificación/escritura)
                    if (rule.IdentityReference.Value.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        // Verificar si tiene permisos básicos de lectura
                        if ((rights & (FileSystemRights.ReadAndExecute |
                                      FileSystemRights.ListDirectory |
                                      FileSystemRights.Read)) != 0)
                        {
                            authUsersHasBasicPermissions = true;
                            SimpleLogger.LogService($"Authenticated Users have basic permissions on {drivePath}");
                        }
                        
                        // Verificar si tiene permisos de modificación o escritura
                        if ((rights & (FileSystemRights.Modify |
                                      FileSystemRights.Write)) != 0)
                        {
                            authUsersHasModifyWritePermissions = true;
                            SimpleLogger.LogService($"Authenticated Users have modify/write permissions on {drivePath}");
                        }
                    }
                }

                // LÓGICA EXACTA SEGÚN TU DEFINICIÓN:
                //
                // DISCO DESPROTEGIDO (NORMAL):
                // - Usuarios CON permisos básicos Y AuthUsers CON modificación/escritura
                //
                // DISCO PROTEGIDO:
                // - Usuarios SIN permisos básicos Y AuthUsers SIN modificación/escritura (solo lectura básica o sin permisos)
                bool isUnprotected = usersHasBasicPermissions && authUsersHasModifyWritePermissions;
                bool isProtected = !usersHasBasicPermissions && authUsersHasBasicPermissions && !authUsersHasModifyWritePermissions;
                
                // Si no tiene permisos de usuarios pero tampoco permisos básicos de auth users, 
                // también lo consideramos protegido (caso extremo)
                if (!usersHasBasicPermissions && !authUsersHasBasicPermissions)
                {
                    isProtected = true;
                    SimpleLogger.LogService($"Drive {drivePath} has no permissions for users or auth users, considered protected");
                }
                
                SimpleLogger.LogService($"Drive {drivePath} - Unprotected: {isUnprotected}, Protected: {isProtected}");
                return isProtected;
            }
            catch (Exception ex)
            {
                SimpleLogger.Error(LogCategory.Service, $"Error checking protection status for {drivePath}", ex);
                return false; // En caso de error, asumir desprotegido
            }
        }

        public async Task<bool> ProtectDriveAsync(string drivePath, IProgress<string> progress)
        {
            return await Task.Run(() =>
            {
                try
                {
                    progress?.Report("Iniciando proceso de protección...");

                    // Verificar permisos de administrador
                    if (!IsCurrentUserAdministrator())
                    {
                        progress?.Report("ERROR: Se requieren permisos de administrador");
                        SimpleLogger.Error(LogCategory.Service, "Administrator privileges required for protection");
                        return false;
                    }

                    var directoryInfo = new DirectoryInfo(drivePath);
                    var security = directoryInfo.GetAccessControl();

                    // Traducir SIDs a cuentas
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));

                    // QUITAR permisos específicos en lugar de usar Deny:
                    progress?.Report("Removiendo permisos de Usuarios...");
                    var usersBasicRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.RemoveAccessRule(usersBasicRule);
                    SimpleLogger.LogPermissionChange(drivePath, "Remove", "Usuarios", "ReadAndExecute/ListDirectory/Read", true);
                    progress?.Report("Permisos de Usuarios removidos");

                    progress?.Report("Removiendo permisos de modificación/escritura de Usuarios autenticados...");
                    var authUsersModifyWriteRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.RemoveAccessRule(authUsersModifyWriteRule);
                    SimpleLogger.LogPermissionChange(drivePath, "Remove", "Usuarios Autenticados", "Modify/Write", true);
                    progress?.Report("Permisos de modificación/escritura de Usuarios autenticados removidos");

                    // Asegurar que Admins y SYSTEM mantienen control total
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));

                    var adminsRule = new FileSystemAccessRule(adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(adminsRule);
                    SimpleLogger.LogPermissionChange(drivePath, "Set", "Administradores", "FullControl", true);

                    var systemRule = new FileSystemAccessRule(systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(systemRule);
                    SimpleLogger.LogPermissionChange(drivePath, "Set", "SYSTEM", "FullControl", true);

                    // Aplicar cambios
                    directoryInfo.SetAccessControl(security);
                    progress?.Report("Protección completada exitosamente");
                    SimpleLogger.LogService($"Protection completed successfully for drive: {drivePath}");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    SimpleLogger.Error(LogCategory.Service, $"Permission error protecting drive {drivePath}", authEx);
                    return false;
                }
                catch (Exception ex)
                {
                    progress?.Report($"Error: {ex.Message}");
                    SimpleLogger.Error(LogCategory.Service, $"Error protecting drive {drivePath}", ex);
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
                    progress?.Report("Iniciando proceso de desprotección...");

                    // Verificar permisos de administrador
                    if (!IsCurrentUserAdministrator())
                    {
                        progress?.Report("ERROR: Se requieren permisos de administrador");
                        SimpleLogger.Error(LogCategory.Service, "Administrator privileges required for unprotection");
                        return false;
                    }

                    var directoryInfo = new DirectoryInfo(drivePath);
                    var security = directoryInfo.GetAccessControl();

                    // Traducir SIDs a cuentas
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));

                    // RESTAURAR permisos específicos que se quitaron:
                    // Restaurar permisos básicos de lectura a Usuarios
                    progress?.Report("Restaurando permisos de Usuarios...");
                    var usersBasicRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(usersBasicRule);
                    SimpleLogger.LogPermissionChange(drivePath, "Set", "Usuarios", "ReadAndExecute/ListDirectory/Read", true);
                    progress?.Report("Permisos de Usuarios restaurados");

                    // Restaurar permisos de modificación/escritura a Usuarios autenticados
                    progress?.Report("Restaurando permisos de modificación/escritura a Usuarios autenticados...");
                    var authUsersModifyWriteRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(authUsersModifyWriteRule);
                    SimpleLogger.LogPermissionChange(drivePath, "Set", "Usuarios Autenticados", "Modify/Write", true);
                    progress?.Report("Permisos de modificación/escritura de Usuarios autenticados restaurados");

                    // Asegurar que Admins y SYSTEM mantienen control total
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));

                    var adminsRule = new FileSystemAccessRule(adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(adminsRule);
                    SimpleLogger.LogPermissionChange(drivePath, "Set", "Administradores", "FullControl", true);

                    var systemRule = new FileSystemAccessRule(systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(systemRule);
                    SimpleLogger.LogPermissionChange(drivePath, "Set", "SYSTEM", "FullControl", true);

                    // Aplicar cambios
                    directoryInfo.SetAccessControl(security);
                    progress?.Report("Desprotección completada exitosamente");
                    SimpleLogger.LogService($"Unprotection completed successfully for drive: {drivePath}");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    SimpleLogger.Error(LogCategory.Service, $"Permission error unprotecting drive {drivePath}", authEx);
                    return false;
                }
                catch (Exception ex)
                {
                    progress?.Report($"Error: {ex.Message}");
                    SimpleLogger.Error(LogCategory.Service, $"Error unprotecting drive {drivePath}", ex);
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
                SimpleLogger.LogService($"Current user is administrator: {isAdmin}");
                return isAdmin;
            }
            catch (Exception ex)
            {
                SimpleLogger.Error(LogCategory.Service, "Error checking administrator privileges", ex);
                return false;
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

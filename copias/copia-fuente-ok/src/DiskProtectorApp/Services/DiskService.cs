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

                    var drivePath = drive.Name;
                    bool isSystemDisk = string.Equals(drivePath, systemDrive, StringComparison.OrdinalIgnoreCase);
                    
                    var disk = new DiskInfo
                    {
                        Name = drive.Name,
                        VolumeName = drive.VolumeLabel ?? "Sin etiqueta",
                        TotalSize = drive.TotalSize,
                        FreeSpace = drive.AvailableFreeSpace,
                        IsSystemDisk = isSystemDisk,
                        IsEligible = !isSystemDisk, // El disco del sistema no es elegible
                        IsManageable = IsDriveManageable(drivePath) // Verificar si es administrable
                    };

                    // Establecer estado de protección (solo si es administrable)
                    if (disk.IsManageable && !isSystemDisk)
                    {
                        disk.IsProtected = IsDriveProtected(drivePath);
                    }
                    else
                    {
                        disk.IsProtected = false; // Valor por defecto si no es administrable
                    }
                    
                    // Actualizar estado de protección
                    if (isSystemDisk)
                    {
                        disk.VolumeName += " (Sistema)";
                        disk.ProtectionStatus = "No Elegible";
                        disk.IsSelected = false; // No permitir selección
                    }
                    else if (!disk.IsManageable)
                    {
                        disk.ProtectionStatus = "No Administrable";
                        disk.IsSelected = false; // No permitir selección
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
                    Debug.WriteLine($"Error al procesar disco {drive.Name}: {ex.Message}");
                }
            }

            return disks;
        }

        /// <summary>
        /// Verifica si un disco es administrable (Administradores y SYSTEM tienen Control Total)
        /// </summary>
        public bool IsDriveManageable(string drivePath)
        {
            try
            {
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
                        }
                    }
                }

                // Un disco es administrable si ambos grupos tienen Control Total
                return adminsHasFullControl && systemHasFullControl;
            }
            catch (Exception)
            {
                return false; // En caso de error, asumir no administrable
            }
        }

        /// <summary>
        /// Verifica si un disco está protegido según la lógica definida:
        /// (SOLO se aplica a discos administrables)
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
                        }
                    }

                    // Verificar permisos de Usuarios autenticados (lectura básica)
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
                        }
                        
                        // Verificar si tiene permisos de modificación o escritura
                        if ((rights & (FileSystemRights.Modify |
                                      FileSystemRights.Write)) != 0)
                        {
                            authUsersHasModifyWritePermissions = true;
                        }
                    }
                }

                // LÓGICA EXACTA SEGÚN TU DEFINICIÓN:
                //
                // DISCO DESPROTEGIDO (NORMAL):
                // - Usuarios CON permisos básicos Y AuthUsers CON modificación/escritura
                //
                // DISCO PROTEGIDO:
                // - Usuarios SIN permisos básicos O AuthUsers SIN modificación/escritura (solo lectura básica)
                bool isUnprotected = usersHasBasicPermissions && authUsersHasModifyWritePermissions;
                bool isProtected = !isUnprotected && authUsersHasBasicPermissions; // Protegido solo si tiene permisos básicos pero no de modificación
                return isProtected;
            }
            catch (Exception)
            {
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

                    progress?.Report("Removiendo permisos de modificación/escritura de Usuarios autenticados...");
                    var authUsersModifyWriteRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.RemoveAccessRule(authUsersModifyWriteRule);

                    // Asegurar que Admins y SYSTEM mantienen control total
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));

                    var adminsRule = new FileSystemAccessRule(adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(adminsRule);

                    var systemRule = new FileSystemAccessRule(systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(systemRule);

                    // Aplicar cambios
                    directoryInfo.SetAccessControl(security);
                    progress?.Report("Protección completada exitosamente");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    return false;
                }
                catch (Exception ex)
                {
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
                    progress?.Report("Iniciando proceso de desprotección...");

                    // Verificar permisos de administrador
                    if (!IsCurrentUserAdministrator())
                    {
                        progress?.Report("ERROR: Se requieren permisos de administrador");
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

                    // Restaurar permisos de modificación/escritura a Usuarios autenticados
                    progress?.Report("Restaurando permisos de modificación/escritura a Usuarios autenticados...");
                    var authUsersModifyWriteRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(authUsersModifyWriteRule);

                    // Asegurar que Admins y SYSTEM mantienen control total
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));

                    var adminsRule = new FileSystemAccessRule(adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(adminsRule);

                    var systemRule = new FileSystemAccessRule(systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(systemRule);

                    // Aplicar cambios
                    directoryInfo.SetAccessControl(security);
                    progress?.Report("Desprotección completada exitosamente");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    return false;
                }
                catch (Exception ex)
                {
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
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }
    }
}

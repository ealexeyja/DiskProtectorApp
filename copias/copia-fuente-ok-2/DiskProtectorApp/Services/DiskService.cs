using DiskProtectorApp.Logging;
using DiskProtectorApp.Models;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
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
            AppLogger.LogService("Starting GetDisks");
            var disks = new List<DiskInfo>();
            var systemDrive = Path.GetPathRoot(Environment.SystemDirectory);

            foreach (var drive in DriveInfo.GetDrives())
            {
                try
                {
                    AppLogger.LogService($"Processing drive: {drive.Name}");
                    
                    // Solo procesar discos fijos con sistema de archivos NTFS
                    if (drive.DriveType != DriveType.Fixed)
                    {
                        AppLogger.LogService($"Drive {drive.Name} is not fixed, marking as not selectable...");
                        var nonFixedDisk = new DiskInfo
                        {
                            DriveLetter = drive.Name,
                            VolumeName = drive.VolumeLabel ?? "Sin etiqueta",
                            TotalSize = FormatBytes(drive.TotalSize),
                            FreeSpace = FormatBytes(drive.AvailableFreeSpace),
                            IsSelectable = false, // No es seleccionable porque no es fijo
                            IsProtected = false, // No aplica
                            ProtectionStatus = "No Elegible",
                            IsSystemDisk = false,
                            IsManageable = false
                        };
                        disks.Add(nonFixedDisk);
                        continue;
                    }
                    
                    if (drive.DriveFormat != "NTFS")
                    {
                        AppLogger.LogService($"Drive {drive.Name} is not NTFS, marking as not selectable...");
                        var nonNtfsDisk = new DiskInfo
                        {
                            DriveLetter = drive.Name,
                            VolumeName = drive.VolumeLabel ?? "Sin etiqueta",
                            TotalSize = FormatBytes(drive.TotalSize),
                            FreeSpace = FormatBytes(drive.AvailableFreeSpace),
                            IsSelectable = false, // No es seleccionable porque no es NTFS
                            IsProtected = false, // No aplica
                            ProtectionStatus = "No Elegible",
                            IsSystemDisk = false,
                            IsManageable = false
                        };
                        disks.Add(nonNtfsDisk);
                        continue;
                    }

                    var drivePath = drive.Name;
                    bool isSystemDisk = string.Equals(drivePath, systemDrive, StringComparison.OrdinalIgnoreCase);
                    
                    AppLogger.LogService($"Drive {drive.Name} is NTFS. Is system drive: {isSystemDisk}");

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
                        AppLogger.LogService($"Drive {drive.Name} is manageable: {disk.IsManageable}");
                        
                        if (!disk.IsManageable)
                        {
                            disk.ProtectionStatus = "No Administrable";
                            disk.IsProtected = false; // No puede estar protegido si no es administrable
                        }
                        else
                        {
                            // Solo verificar estado de protección si es administrable
                            disk.IsProtected = IsDriveProtected(drivePath);
                            AppLogger.LogService($"Drive {drive.Name} is selectable and manageable. Protected: {disk.IsProtected}");
                            disk.ProtectionStatus = disk.IsProtected ? "Protegido" : "Desprotegido";
                        }
                    }
                    else
                    {
                        disk.ProtectionStatus = "No Elegible";
                        disk.IsManageable = false; // Forzar a no administrable si no es elegible
                        disk.IsProtected = false; // Forzar a no protegido si no es elegible
                        AppLogger.LogService($"Drive {drive.Name} is not selectable (system drive or non-NTFS)");
                    }

                    disks.Add(disk);
                }
                catch (Exception ex)
                {
                    // Loggear errores pero continuar con otros discos
                    AppLogger.Error("Service", $"Error processing drive {drive.Name}", ex);
                }
            }

            AppLogger.LogService($"GetDisks completed. Total disks: {disks.Count}");
            return disks;
        }

        /// <summary>
        /// Verifica si un disco es administrable (Administradores y SYSTEM tienen Control Total)
        /// </summary>
        public bool IsDriveManageable(string drivePath)
        {
            try
            {
                AppLogger.LogService($"Checking if drive {drivePath} is manageable...");
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
                            AppLogger.LogService($"Administrators have Full Control on {drivePath}");
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
                            AppLogger.LogService($"SYSTEM has Full Control on {drivePath}");
                        }
                    }
                }

                // Un disco es administrable si ambos grupos tienen Control Total
                bool isManageable = adminsHasFullControl && systemHasFullControl;
                AppLogger.LogService($"Drive {drivePath} is manageable: {isManageable}");
                return isManageable;
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"Error checking manageability for {drivePath}", ex);
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
                AppLogger.LogService($"Checking protection status for drive: {drivePath}");
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
                            AppLogger.LogService($"Users have basic permissions on {drivePath}");
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
                            AppLogger.LogService($"Authenticated Users have basic permissions on {drivePath}");
                        }
                        
                        // Verificar si tiene permisos de modificación o escritura
                        if ((rights & (FileSystemRights.Modify |
                                      FileSystemRights.Write)) != 0)
                        {
                            authUsersHasModifyWritePermissions = true;
                            AppLogger.LogService($"Authenticated Users have modify/write permissions on {drivePath}");
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
                    AppLogger.LogService($"Drive {drivePath} has no permissions for users or auth users, considered protected");
                }
                
                AppLogger.LogService($"Drive {drivePath} - Unprotected: {isUnprotected}, Protected: {isProtected}");
                return isProtected;
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"Error checking protection status for {drivePath}", ex);
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
                        AppLogger.Error("Service", "Administrator privileges required for protection");
                        return false;
                    }

                    var directoryInfo = new DirectoryInfo(drivePath);
                    var security = directoryInfo.GetAccessControl();

                    // Traducir SIDs a cuentas
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));

                    // --- PASO 1: Limpiar todas las reglas para "Usuarios" ---
                    progress?.Report("Limpiando reglas para Usuarios...");
                    
                    // Eliminar todas las reglas Allow para Usuarios
                    var usersAllowRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, usersAllowRule, out bool usersAllowModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios (Allow)", "Todas", usersAllowModified);

                    // Eliminar todas las reglas Deny para Usuarios
                    var usersDenyRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Deny);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, usersDenyRule, out bool usersDenyModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios (Deny)", "Todas", usersDenyModified);
                    
                    progress?.Report($"Reglas de Usuarios limpiadas: Allow={usersAllowModified}, Deny={usersDenyModified}");

                    // --- PASO 2: Limpiar todas las reglas para "Usuarios autenticados" ---
                    progress?.Report("Limpiando reglas para Usuarios autenticados...");
                    
                    // Eliminar todas las reglas Allow para Usuarios autenticados
                    var authUsersAllowRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, authUsersAllowRule, out bool authUsersAllowModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios Autenticados (Allow)", "Todas", authUsersAllowModified);

                    // Eliminar todas las reglas Deny para Usuarios autenticados
                    var authUsersDenyRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Deny);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, authUsersDenyRule, out bool authUsersDenyModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios Autenticados (Deny)", "Todas", authUsersDenyModified);
                    
                    progress?.Report($"Reglas de Usuarios autenticados limpiadas: Allow={authUsersAllowModified}, Deny={authUsersDenyModified}");

                    // --- PASO 3: Establecer permisos explícitos para "Usuarios autenticados" ---
                    progress?.Report("Estableciendo permisos básicos de lectura para Usuarios autenticados...");
                    
                    // Crear regla con permisos básicos de lectura
                    var authUsersReadRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    // Establecer estos permisos usando ModifyAccessRule con Set
                    bool authUsersReadSet = security.ModifyAccessRule(AccessControlModification.Set, authUsersReadRule, out bool authUsersReadModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "Usuarios Autenticados", "ReadAndExecute/ListDirectory/Read", authUsersReadSet && authUsersReadModified);
                    progress?.Report($"Permisos básicos de lectura establecidos para Usuarios autenticados: {authUsersReadSet && authUsersReadModified}");

                    // --- PASO 4: Asegurar permisos de administrador ---
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));

                    var adminsRule = new FileSystemAccessRule(adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.Set, adminsRule, out bool adminsModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "Administradores", "FullControl", adminsModified);

                    var systemRule = new FileSystemAccessRule(systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.Set, systemRule, out bool systemModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "SYSTEM", "FullControl", systemModified);

                    // Aplicar cambios
                    directoryInfo.SetAccessControl(security);
                    progress?.Report("Protección completada exitosamente");
                    AppLogger.LogService($"Protection completed successfully for drive: {drivePath}");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    AppLogger.Error("Service", $"Permission error protecting drive {drivePath}", authEx);
                    return false;
                }
                catch (Exception ex)
                {
                    progress?.Report($"Error: {ex.Message}");
                    AppLogger.Error("Service", $"Error protecting drive {drivePath}", ex);
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
                        AppLogger.Error("Service", "Administrator privileges required for unprotection");
                        return false;
                    }

                    var directoryInfo = new DirectoryInfo(drivePath);
                    var security = directoryInfo.GetAccessControl();

                    // Traducir SIDs a cuentas
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));

                    // --- PASO 1: Limpiar todas las reglas para "Usuarios" ---
                    progress?.Report("Limpiando reglas para Usuarios...");
                    
                    // Eliminar todas las reglas Allow para Usuarios
                    var usersAllowRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, usersAllowRule, out bool usersAllowModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios (Allow)", "Todas", usersAllowModified);

                    // Eliminar todas las reglas Deny para Usuarios
                    var usersDenyRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Deny);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, usersDenyRule, out bool usersDenyModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios (Deny)", "Todas", usersDenyModified);
                    
                    progress?.Report($"Reglas de Usuarios limpiadas: Allow={usersAllowModified}, Deny={usersDenyModified}");

                    // --- PASO 2: Limpiar todas las reglas para "Usuarios autenticados" ---
                    progress?.Report("Limpiando reglas para Usuarios autenticados...");
                    
                    // Eliminar todas las reglas Allow para Usuarios autenticados
                    var authUsersAllowRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, authUsersAllowRule, out bool authUsersAllowModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios Autenticados (Allow)", "Todas", authUsersAllowModified);

                    // Eliminar todas las reglas Deny para Usuarios autenticados
                    var authUsersDenyRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Deny);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, authUsersDenyRule, out bool authUsersDenyModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios Autenticados (Deny)", "Todas", authUsersDenyModified);
                    
                    progress?.Report($"Reglas de Usuarios autenticados limpiadas: Allow={authUsersAllowModified}, Deny={authUsersDenyModified}");

                    // --- PASO 3: Establecer permisos para "Usuarios" ---
                    progress?.Report("Restaurando permisos de Usuarios...");
                    
                    // Crear regla con permisos básicos de lectura para Usuarios
                    var usersReadRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    // Establecer estos permisos usando ModifyAccessRule con Set
                    bool usersReadSet = security.ModifyAccessRule(AccessControlModification.Set, usersReadRule, out bool usersReadModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "Usuarios", "ReadAndExecute/ListDirectory/Read", usersReadSet && usersReadModified);
                    progress?.Report($"Permisos básicos de lectura restaurados para Usuarios: {usersReadSet && usersReadModified}");

                    // --- PASO 4: Establecer permisos para "Usuarios autenticados" ---
                    progress?.Report("Restaurando permisos de modificación/escritura a Usuarios autenticados...");
                    
                    // Crear regla con permisos de modificación/escritura para Usuarios autenticados
                    var authUsersModifyWriteRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    // Establecer estos permisos usando ModifyAccessRule con Set
                    bool authUsersModifyWriteSet = security.ModifyAccessRule(AccessControlModification.Set, authUsersModifyWriteRule, out bool authUsersModifyWriteModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "Usuarios Autenticados", "Modify/Write", authUsersModifyWriteSet && authUsersModifyWriteModified);
                    progress?.Report($"Permisos de modificación/escritura restaurados para Usuarios autenticados: {authUsersModifyWriteSet && authUsersModifyWriteModified}");

                    // --- PASO 5: Asegurar permisos de administrador ---
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));

                    var adminsRule = new FileSystemAccessRule(adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.Set, adminsRule, out bool adminsModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "Administradores", "FullControl", adminsModified);

                    var systemRule = new FileSystemAccessRule(systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.Set, systemRule, out bool systemModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "SYSTEM", "FullControl", systemModified);

                    // Aplicar cambios
                    directoryInfo.SetAccessControl(security);
                    progress?.Report("Desprotección completada exitosamente");
                    AppLogger.LogService($"Unprotection completed successfully for drive: {drivePath}");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    AppLogger.Error("Service", $"Permission error unprotecting drive {drivePath}", authEx);
                    return false;
                }
                catch (Exception ex)
                {
                    progress?.Report($"Error: {ex.Message}");
                    AppLogger.Error("Service", $"Error unprotecting drive {drivePath}", ex);
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
                AppLogger.LogService($"Current user is administrator: {isAdmin}");
                return isAdmin;
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", "Error checking administrator privileges", ex);
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

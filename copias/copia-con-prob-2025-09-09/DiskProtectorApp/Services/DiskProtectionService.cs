using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Threading.Tasks;
using DiskProtectorApp.Models;
using Microsoft.Win32.SafeHandles;

namespace DiskProtectorApp.Services
{
    /// <summary>
    /// Servicio encargado de la protección y desprotección de unidades de disco.
    /// </summary>
    public class DiskProtectionService : IDisposable
    {
        #region Constantes de SIDs bien conocidos

        private static readonly SecurityIdentifier BUILTIN_USERS_SID = new SecurityIdentifier(WellKnownSidType.BuiltinUsersSid, null);
        private static readonly SecurityIdentifier AUTHENTICATED_USERS_SID = new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null);
        private static readonly SecurityIdentifier LOCAL_SYSTEM_SID = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);
        private static readonly SecurityIdentifier BUILTIN_ADMINISTRATORS_SID = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);

        #endregion

        #region Propiedades y campos

        private bool _disposed = false;

        #endregion

        #region Métodos públicos

        /// <summary>
        /// Verifica si el usuario actual tiene privilegios de administrador.
        /// </summary>
        public bool IsCurrentUserAdministrator()
        {
            try
            {
                AppLogger.LogService("[ADMIN_DEBUG] Verificando privilegios de administrador...");
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                bool isAdmin = principal.IsInRole(WindowsBuiltInRole.Administrator);
                AppLogger.LogService($"[ADMIN_DEBUG] El usuario actual es administrador: {isAdmin}");
                return isAdmin;
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", "Error verificando privilegios de administrador", ex);
                return false;
            }
        }

        /// <summary>
        /// Obtiene una lista de todas las unidades de disco disponibles en el sistema.
        /// Filtra el disco del sistema para evitar operaciones peligrosas.
        /// </summary>
        public List<DiskInfo> GetDisks()
        {
            var disks = new List<DiskInfo>();
            try
            {
                AppLogger.LogService("[DISK_DEBUG] Iniciando enumeración de unidades de disco...");
                var drives = DriveInfo.GetDrives();

                foreach (var drive in drives)
                {
                    try
                    {
                        // Solo procesar unidades de disco fijo
                        if (drive.DriveType != DriveType.Fixed)
                        {
                            AppLogger.LogService($"[DISK_DEBUG] Ignorando unidad {drive.Name} - Tipo: {drive.DriveType}");
                            continue;
                        }

                        // Verificar si es el disco del sistema
                        bool isSystemDisk = IsSystemDrive(drive.Name);

                        // Crear objeto DiskInfo
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
                            AppLogger.LogService($"[DISK_DEBUG] Verificando si la unidad {drive.Name} es administrable...");
                            disk.IsManageable = IsDriveManageable(drive.Name);

                            // Si es administrable, verificar estado de protección
                            if (disk.IsManageable)
                            {
                                AppLogger.LogService($"[DISK_DEBUG] Verificando estado de protección para la unidad {drive.Name}...");
                                disk.IsProtected = IsDriveProtected(drive.Name);
                            }
                        }

                        disks.Add(disk);
                        AppLogger.LogService($"[DISK_DEBUG] Unidad {drive.Name} procesada exitosamente - Seleccionable: {disk.IsSelectable}, Administrable: {disk.IsManageable}, Protegida: {disk.IsProtected}");
                    }
                    catch (Exception ex)
                    {
                        // Registrar errores pero continuar con otros discos
                        AppLogger.Error("Service", $"Error procesando la unidad {drive.Name}", ex);
                    }
                }

                AppLogger.LogService($"[DISK_DEBUG] GetDisks completado. Total de unidades: {disks.Count}");
                return disks;
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", "Error obteniendo lista de discos", ex);
                return disks;
            }
        }

        /// <summary>
        /// Verifica si un disco es administrable (Administradores y SYSTEM tienen Control Total)
        /// </summary>
        public bool IsDriveManageable(string drivePath)
        {
            try
            {
                AppLogger.LogService($"[MANAGE_DEBUG] Verificando si la unidad {drivePath} es administrable...");
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();

                // Obtener reglas de acceso
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                // Traducir SIDs a cuentas
                var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                var adminsAccount = (NTAccount)BUILTIN_ADMINISTRATORS_SID.Translate(typeof(NTAccount));

                bool systemHasFullControl = false;
                bool adminsHaveFullControl = false;

                // Verificar cada regla de acceso
                foreach (FileSystemAccessRule rule in rules)
                {
                    // Verificar permisos de SYSTEM
                    if (rule.IdentityReference.Value.Equals(systemAccount.Value, StringComparison.OrdinalIgnoreCase))
                    {
                        if ((rule.FileSystemRights & FileSystemRights.FullControl) == FileSystemRights.FullControl &&
                            rule.AccessControlType == AccessControlType.Allow)
                        {
                            systemHasFullControl = true;
                        }
                    }

                    // Verificar permisos de Administradores
                    if (rule.IdentityReference.Value.Equals(adminsAccount.Value, StringComparison.OrdinalIgnoreCase))
                    {
                        if ((rule.FileSystemRights & FileSystemRights.FullControl) == FileSystemRights.FullControl &&
                            rule.AccessControlType == AccessControlType.Allow)
                        {
                            adminsHaveFullControl = true;
                        }
                    }
                }

                bool isManageable = systemHasFullControl && adminsHaveFullControl;
                AppLogger.LogService($"[MANAGE_DEBUG] Unidad {drivePath} es administrable: {isManageable} - SYSTEM FullControl: {systemHasFullControl}, Admins FullControl: {adminsHaveFullControl}");
                return isManageable;
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"Error verificando administrabilidad para {drivePath}", ex);
                return false; // En caso de error, asumir no administrable
            }
        }

        /// <summary>
        /// Verifica si una unidad está protegida según la lógica de negocio definida.
        /// </summary>
        public bool IsDriveProtected(string drivePath)
        {
            try
            {
                AppLogger.LogService($"[PROTECT_DEBUG] Iniciando verificación de protección (lógica simplificada) para la unidad: {drivePath}");

                // 1. Extraer permisos en una estructura clara
                var permissions = ExtractDrivePermissions(drivePath);

                // 2. Traducir SIDs a nombres para comparación
                var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));

                // 3. Aplicar lógica de negocio simple sobre la estructura de datos
                bool usersHasAllowPermissions = permissions.Any(p =>
                    p.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                    p.AccessControlType == AccessControlType.Allow);

                bool usersHasDenyPermissions = permissions.Any(p =>
                    p.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                    p.AccessControlType == AccessControlType.Deny);

                bool authUsersHasOnlyReadOnlyPermissions = permissions
                    .Where(p => p.IdentityReference.Value.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                               p.AccessControlType == AccessControlType.Allow)
                    .All(p => (p.FileSystemRights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read)) == p.FileSystemRights);

                // Lógica de protección: Usuarios no tienen Allow, y Usuarios autenticados solo tienen RX
                bool isProtected = !usersHasAllowPermissions && authUsersHasOnlyReadOnlyPermissions;

                AppLogger.LogService($"[PROTECT_DEBUG] Resultados - Usuarios tiene Allow: {usersHasAllowPermissions}, Usuarios tiene Deny: {usersHasDenyPermissions}, Usuarios autentificados tiene solo RX: {authUsersHasOnlyReadOnlyPermissions}");
                AppLogger.LogService($"[PROTECT_DEBUG] La unidad {drivePath} está protegida: {isProtected}");

                return isProtected;
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"Error verificando estado de protección para {drivePath}", ex);
                return false; // En caso de error, asumir desprotegido
            }
        }

        /// <summary>
        /// Extrae una representación estructurada de los permisos de una unidad.
        /// </summary>
        /// <param name="drivePath">La ruta de la unidad (e.g., "T:\\")</param>
        /// <returns>Lista de entradas de permisos</returns>
        private List<DrivePermissionEntry> ExtractDrivePermissions(string drivePath)
        {
            var permissions = new List<DrivePermissionEntry>();

            try
            {
                AppLogger.LogService($"[EXTRACT_PERMS] Extrayendo permisos para la unidad: {drivePath}");
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                // Traducir SIDs a nombres para comparación
                var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));

                AppLogger.LogService($"[EXTRACT_PERMS] SIDs traducidos - Usuarios: {usersAccount?.Value}, Usuarios autentificados: {authUsersAccount?.Value}");

                // Verificar cada regla de acceso
                AppLogger.LogService($"[EXTRACT_PERMS] Analizando {rules.Count} reglas de acceso para {drivePath}");
                foreach (FileSystemAccessRule rule in rules)
                {
                    AppLogger.LogService($"[EXTRACT_PERMS] Regla - Identidad: {rule.IdentityReference.Value}, Tipo: {rule.AccessControlType}, Permisos: {rule.FileSystemRights}");

                    // Verificar permisos de Usuarios
                    if (rule.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase))
                    {
                        permissions.Add(new DrivePermissionEntry
                        {
                            IdentityReference = rule.IdentityReference,
                            AccessControlType = rule.AccessControlType,
                            FileSystemRights = rule.FileSystemRights
                        });
                    }

                    // Verificar permisos de Usuarios autenticados
                    if (rule.IdentityReference.Value.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase))
                    {
                        permissions.Add(new DrivePermissionEntry
                        {
                            IdentityReference = rule.IdentityReference,
                            AccessControlType = rule.AccessControlType,
                            FileSystemRights = rule.FileSystemRights
                        });
                    }
                }

                AppLogger.LogService($"[EXTRACT_PERMS] Extracción completada. Total de reglas relevantes: {permissions.Count}");
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"Error extrayendo permisos para {drivePath}", ex);
            }

            return permissions;
        }

        /// <summary>
        /// Protege una unidad de disco aplicando permisos NTFS específicos.
        /// </summary>
        public async Task<bool> ProtectDriveAsync(string drivePath, IProgress<string> progress)
        {
            return await Task.Run(() =>
            {
                try
                {
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Iniciando protección para la unidad: {drivePath}");
                    progress?.Report("Iniciando proceso de protección...");

                    // Verificar permisos de administrador
                    if (!IsCurrentUserAdministrator())
                    {
                        progress?.Report("ERROR: Se requieren permisos de administrador");
                        AppLogger.Error("Service", "Se requieren privilegios de administrador para la protección");
                        return false;
                    }

                    var directoryInfo = new DirectoryInfo(drivePath);
                    var security = directoryInfo.GetAccessControl();

                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Obtenido AccessControl para {drivePath}");

                    // Traducir SIDs a cuentas
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                    var adminsAccount = (NTAccount)BUILTIN_ADMINISTRATORS_SID.Translate(typeof(NTAccount));

                    // - PASO 1: Limpiar todas las reglas para "Usuarios" -
                    progress?.Report("Limpiando reglas para Usuarios...");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Iniciando Paso 1 para {drivePath}");

                    // Eliminar todas las reglas Allow para Usuarios
                    var usersAllowRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, usersAllowRule, out bool usersAllowModified);

                    // Eliminar todas las reglas Deny para Usuarios
                    var usersDenyRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Deny);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, usersDenyRule, out bool usersDenyModified);

                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios (Deny)", "Todas", usersDenyModified);
                    progress?.Report($"Reglas de Usuarios limpiadas: Allow={usersAllowModified}, Deny={usersDenyModified}");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Paso 1 completado para {drivePath}");

                    // - PASO 2: Limpiar todas las reglas para "Usuarios autenticados" -
                    progress?.Report("Limpiando reglas para Usuarios autenticados...");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Iniciando Paso 2 para {drivePath}");

                    // Eliminar todas las reglas Allow para Usuarios autenticados
                    var authUsersAllowRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, authUsersAllowRule, out bool authUsersAllowModified);

                    // Eliminar todas las reglas Deny para Usuarios autenticados
                    var authUsersDenyRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Deny);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, authUsersDenyRule, out bool authUsersDenyModified);

                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios Autenticados (Deny)", "Todas", authUsersDenyModified);
                    progress?.Report($"Reglas de Usuarios autenticados limpiadas: Allow={authUsersAllowModified}, Deny={authUsersDenyModified}");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Paso 2 completado para {drivePath}");

                    // - PASO 3: Establecer permisos básicos de lectura para "Usuarios autenticados" -
                    progress?.Report("Estableciendo permisos básicos de lectura para Usuarios autenticados...");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Iniciando Paso 3 para {drivePath}");

                    // Crear regla con permisos básicos de lectura EXACTOS
                    var authUsersReadRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);

                    // Establecer estos permisos usando ModifyAccessRule con Set
                    security.ModifyAccessRule(AccessControlModification.Set, authUsersReadRule, out bool authUsersReadModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "Usuarios Autenticados", "RX", authUsersReadModified);

                    progress?.Report($"Permisos de lectura establecidos para Usuarios autenticados: {authUsersReadModified}");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Paso 3 completado para {drivePath}");

                    // - PASO 4: Establecer permisos de Control Total para SYSTEM -
                    progress?.Report("Estableciendo permisos de Control Total para SYSTEM...");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Iniciando Paso 4 para {drivePath}");

                    var systemRule = new FileSystemAccessRule(systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.Set, systemRule, out bool systemModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "SYSTEM", "FullControl", systemModified);

                    // - PASO 5: Establecer permisos de Control Total para Administradores -
                    progress?.Report("Estableciendo permisos de Control Total para Administradores...");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Iniciando Paso 5 para {drivePath}");

                    var adminsRule = new FileSystemAccessRule(adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    bool adminsRuleSet = security.ModifyAccessRule(AccessControlModification.Set, adminsRule, out bool adminsRuleModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "Administradores", "FullControl", adminsRuleModified);

                    // Aplicar cambios
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] A punto de aplicar cambios de AccessControl para {drivePath}");
                    directoryInfo.SetAccessControl(security);
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Cambios de AccessControl aplicados para {drivePath}");

                    progress?.Report("Protección completada exitosamente");
                    AppLogger.LogService($"Protección completada exitosamente para la unidad: {drivePath}");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    AppLogger.Error("Service", $"Error de permisos protegiendo la unidad {drivePath}", authEx);
                    return false;
                }
                catch (Exception ex)
                {
                    progress?.Report($"Error: {ex.Message}");
                    AppLogger.Error("Service", $"Error protegiendo la unidad {drivePath}", ex);
                    return false;
                }
            });
        }

        /// <summary>
        /// Desprotege una unidad de disco restaurando permisos de modificación/escritura.
        /// </summary>
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
                        AppLogger.Error("Service", "Se requieren privilegios de administrador para la desprotección");
                        return false;
                    }

                    var directoryInfo = new DirectoryInfo(drivePath);
                    var security = directoryInfo.GetAccessControl();

                    // Traducir SIDs a cuentas
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                    var adminsAccount = (NTAccount)BUILTIN_ADMINISTRATORS_SID.Translate(typeof(NTAccount));

                    // - PASO 1: Limpiar todas las reglas para "Usuarios" -
                    progress?.Report("Limpiando reglas para Usuarios...");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 1 para {drivePath}");

                    // Eliminar todas las reglas Allow para Usuarios
                    var usersAllowRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, usersAllowRule, out bool usersAllowModified);

                    // Eliminar todas las reglas Deny para Usuarios
                    var usersDenyRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Deny);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, usersDenyRule, out bool usersDenyModified);

                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios (Deny)", "Todas", usersDenyModified);
                    progress?.Report($"Reglas de Usuarios limpiadas: Allow={usersAllowModified}, Deny={usersDenyModified}");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Paso 1 completado para {drivePath}");

                    // - PASO 2: Limpiar todas las reglas para "Usuarios autenticados" -
                    progress?.Report("Limpiando reglas para Usuarios autenticados...");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 2 para {drivePath}");

                    // Eliminar todas las reglas Allow para Usuarios autenticados
                    var authUsersAllowRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, authUsersAllowRule, out bool authUsersAllowModified);

                    // Eliminar todas las reglas Deny para Usuarios autenticados
                    var authUsersDenyRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.FullControl, // Irrelevante para RemoveAll
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Deny);
                    security.ModifyAccessRule(AccessControlModification.RemoveAll, authUsersDenyRule, out bool authUsersDenyModified);

                    AppLogger.LogPermissionChange(drivePath, "Modify.RemoveAll", "Usuarios Autenticados (Deny)", "Todas", authUsersDenyModified);
                    progress?.Report($"Reglas de Usuarios autenticados limpiadas: Allow={authUsersAllowModified}, Deny={authUsersDenyModified}");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Paso 2 completado para {drivePath}");

                    // - PASO 3: Establecer permisos de modificación/escritura para "Usuarios" -
                    progress?.Report("Estableciendo permisos de modificación/escritura para Usuarios...");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 3 para {drivePath}");

                    // Crear regla con permisos de modificación/escritura para Usuarios
                    var usersModifyWriteRule = new FileSystemAccessRule(usersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);

                    // Establecer estos permisos usando ModifyAccessRule con Set
                    security.ModifyAccessRule(AccessControlModification.Set, usersModifyWriteRule, out bool usersModifyWriteModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "Usuarios", "Modify|Write", usersModifyWriteModified);

                    progress?.Report($"Permisos de modificación/escritura establecidos para Usuarios: {usersModifyWriteModified}");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Paso 3 completado para {drivePath}");

                    // - PASO 4: Establecer permisos de modificación/escritura para "Usuarios autenticados" -
                    progress?.Report("Restaurando permisos de modificación/escritura a Usuarios autenticados...");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 4 para {drivePath}");

                    // Crear regla con permisos de modificación/escritura para Usuarios autenticados
                    var authUsersModifyWriteRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);

                    // Establecer estos permisos usando ModifyAccessRule con Set
                    security.ModifyAccessRule(AccessControlModification.Set, authUsersModifyWriteRule, out bool authUsersModifyWriteModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "Usuarios Autenticados", "Modify|Write", authUsersModifyWriteModified);

                    // - PASO 5: Establecer permisos de Control Total para SYSTEM -
                    progress?.Report("Estableciendo permisos de Control Total para SYSTEM...");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 5 para {drivePath}");

                    var systemRule = new FileSystemAccessRule(systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.Set, systemRule, out bool systemModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "SYSTEM", "FullControl", systemModified);

                    // - PASO 6: Establecer permisos de Control Total para Administradores -
                    progress?.Report("Estableciendo permisos de Control Total para Administradores...");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 6 para {drivePath}");

                    var adminsRule = new FileSystemAccessRule(adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    bool adminsRuleSet = security.ModifyAccessRule(AccessControlModification.Set, adminsRule, out bool adminsRuleModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "Administradores", "FullControl", adminsRuleModified);

                    // Aplicar cambios
                    AppLogger.LogService($"[UNPROTECT_DEBUG] A punto de aplicar cambios de AccessControl para {drivePath}");
                    directoryInfo.SetAccessControl(security);
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Cambios de AccessControl aplicados para {drivePath}");

                    progress?.Report("Desprotección completada exitosamente");
                    AppLogger.LogService($"Desprotección completada exitosamente para la unidad: {drivePath}");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    AppLogger.Error("Service", $"Error de permisos desprotegiendo la unidad {drivePath}", authEx);
                    return false;
                }
                catch (Exception ex)
                {
                    progress?.Report($"Error: {ex.Message}");
                    AppLogger.Error("Service", $"Error desprotegiendo la unidad {drivePath}", ex);
                    return false;
                }
            });
        }

        /// <summary>
        /// Hace que un disco sea administrable otorgando permisos de Control Total a SYSTEM y Administradores.
        /// </summary>
        /// <param name="drivePath">La ruta del disco (e.g., "T:\\")</param>
        /// <param name="progress">Progreso de la operación</param>
        /// <returns>True si la operación fue exitosa, false en caso contrario</returns>
        public async Task<bool> ManageDriveAsync(string drivePath, IProgress<string> progress)
        {
            return await Task.Run(() =>
            {
                try
                {
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando proceso de administración para la unidad: {drivePath}");
                    progress?.Report("Iniciando proceso de administración...");

                    // Verificar permisos de administrador
                    if (!IsCurrentUserAdministrator())
                    {
                        progress?.Report("ERROR: Se requieren permisos de administrador");
                        AppLogger.Error("Service", "Se requieren privilegios de administrador para administrar el disco");
                        return false;
                    }

                    var cleanDrivePath = drivePath.TrimEnd('\\');
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Ruta limpia para la unidad: {cleanDrivePath}");

                    // - PASO 0: Asegurar privilegios necesarios -
                    progress?.Report("Asegurando privilegios necesarios...");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 0 - Asegurar privilegios para {cleanDrivePath}");

                    using (var privilegeHelper = new PrivilegeHelper())
                    {
                        // Intentar habilitar privilegios de toma de posesión y restauración
                        bool takeOwnershipEnabled = privilegeHelper.EnablePrivilege("SeTakeOwnershipPrivilege");
                        bool restoreEnabled = privilegeHelper.EnablePrivilege("SeRestorePrivilege");

                        AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Privilegios habilitados - TakeOwnership: {takeOwnershipEnabled}, Restore: {restoreEnabled}");

                        // No retornamos false aquí, intentamos continuar con los privilegios que conseguimos
                    }

                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Paso 0 completado para {cleanDrivePath}");

                    // - PASO 1: Cambiar el propietario del directorio raíz a SYSTEM -
                    progress?.Report("Cambiando propietario del disco a SYSTEM...");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 1 - Cambiar propietario para {cleanDrivePath}");

                    if (!SetDriveOwner(cleanDrivePath, LOCAL_SYSTEM_SID))
                    {
                        AppLogger.Error("Service", $"[MANAGE_DRIVE_DEBUG] Error cambiando propietario del disco {cleanDrivePath} a SYSTEM");
                        progress?.Report("Error: No se pudo cambiar el propietario del disco a SYSTEM");
                        return false;
                    }

                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Paso 1 completado - Propietario cambiado a SYSTEM para {cleanDrivePath}");

                    // - PASO 2: Obtener el objeto DirectorySecurity actualizado -
                    progress?.Report("Obteniendo permisos actualizados del disco...");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 2 - Obtener permisos actualizados para {cleanDrivePath}");

                    var directoryInfo = new DirectoryInfo(cleanDrivePath);
                    var security = directoryInfo.GetAccessControl();

                    // Traducir SIDs a cuentas
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                    var adminsAccount = (NTAccount)BUILTIN_ADMINISTRATORS_SID.Translate(typeof(NTAccount));

                    // - PASO 3: Establecer permisos de Control Total para SYSTEM -
                    progress?.Report("Estableciendo permisos de Control Total para SYSTEM...");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 3 - Establecer permisos para SYSTEM en {cleanDrivePath}");

                    var systemRule = new FileSystemAccessRule(systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.ModifyAccessRule(AccessControlModification.Set, systemRule, out bool systemModified);
                    AppLogger.LogPermissionChange(cleanDrivePath, "Modify.Set", "SYSTEM", "FullControl", systemModified);

                    // - PASO 4: Establecer permisos de Control Total para Administradores -
                    progress?.Report("Estableciendo permisos de Control Total para Administradores...");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 4 - Establecer permisos para Administradores en {cleanDrivePath}");

                    var adminsRule = new FileSystemAccessRule(adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    bool adminsRuleSet = security.ModifyAccessRule(AccessControlModification.Set, adminsRule, out bool adminsRuleModified);
                    AppLogger.LogPermissionChange(cleanDrivePath, "Modify.Set", "Administradores", "FullControl", adminsRuleModified);

                    // Aplicar cambios
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] A punto de aplicar cambios de AccessControl para {cleanDrivePath}");
                    directoryInfo.SetAccessControl(security);
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Cambios de AccessControl aplicados para {cleanDrivePath}");

                    progress?.Report("Administración completada exitosamente");
                    AppLogger.LogService($"Administración completada exitosamente para la unidad: {cleanDrivePath}");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    AppLogger.Error("Service", $"Error de permisos administrando la unidad {drivePath}", authEx);
                    return false;
                }
                catch (Exception ex)
                {
                    progress?.Report($"Error: {ex.Message}");
                    AppLogger.Error("Service", $"Error administrando la unidad {drivePath}", ex);
                    return false;
                }
            });
        }

        #endregion

        #region Métodos auxiliares

        /// <summary>
        /// Cambia el propietario de un directorio usando P/Invoke.
        /// </summary>
        /// <param name="drivePath">La ruta del directorio</param>
        /// <param name="ownerSid">El SID del nuevo propietario</param>
        /// <returns>True si la operación fue exitosa, false en caso contrario</returns>
        private bool SetDriveOwner(string drivePath, SecurityIdentifier ownerSid)
        {
            try
            {
                AppLogger.LogService($"[SET_OWNER_DEBUG] Cambiando propietario de {drivePath} a {ownerSid.Value}");

                // Abrir el directorio con permisos para cambiar el propietario
                using (var directoryHandle = CreateFile(drivePath, GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, IntPtr.Zero))
                {
                    if (directoryHandle.IsInvalid)
                    {
                        int error = Marshal.GetLastWin32Error();
                        AppLogger.Error("Service", $"[SET_OWNER_DEBUG] Error abriendo el directorio {drivePath}. Código: {error}", new Win32Exception(error));
                        return false;
                    }

                    // Convertir SID a formato binario
                    byte[] sidBinary = new byte[ownerSid.BinaryLength];
                    ownerSid.GetBinaryForm(sidBinary, 0);

                    // Crear estructura SECURITY_DESCRIPTOR
                    var sd = new SECURITY_DESCRIPTOR
                    {
                        Revision = 1,
                        Control = SE_OWNER_DEFAULTED,
                        Owner = Marshal.AllocHGlobal(sidBinary.Length)
                    };

                    try
                    {
                        Marshal.Copy(sidBinary, 0, sd.Owner, sidBinary.Length);

                        // Aplicar el nuevo propietario
                        bool result = SetKernelObjectSecurity(directoryHandle.DangerousGetHandle(), OWNER_SECURITY_INFORMATION, ref sd);
                        if (!result)
                        {
                            int error = Marshal.GetLastWin32Error();
                            AppLogger.Error("Service", $"[SET_OWNER_DEBUG] Error estableciendo propietario para {drivePath}. Código: {error}", new Win32Exception(error));
                            return false;
                        }

                        AppLogger.LogService($"[SET_OWNER_DEBUG] Propietario cambiado exitosamente para {drivePath}");
                        return true;
                    }
                    finally
                    {
                        if (sd.Owner != IntPtr.Zero)
                            Marshal.FreeHGlobal(sd.Owner);
                    }
                }
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"[SET_OWNER_DEBUG] Excepción cambiando propietario para {drivePath}", ex);
                return false;
            }
        }

        /// <summary>
        /// Determina si una unidad es el disco del sistema.
        /// </summary>
        private bool IsSystemDrive(string driveLetter)
        {
            try
            {
                string systemDrive = Environment.GetEnvironmentVariable("SystemDrive");
                return string.Equals(driveLetter, systemDrive, StringComparison.OrdinalIgnoreCase);
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Formatea un número de bytes en una representación legible.
        /// </summary>
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

        #endregion

        #region P/Invoke para gestión de seguridad

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern SafeFileHandle CreateFile(
            string lpFileName,
            uint dwDesiredAccess,
            uint dwShareMode,
            IntPtr lpSecurityAttributes,
            uint dwCreationDisposition,
            uint dwFlagsAndAttributes,
            IntPtr hTemplateFile);

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool SetKernelObjectSecurity(
            IntPtr Handle,
            uint SecurityInformation,
            ref SECURITY_DESCRIPTOR SecurityDescriptor);

        // Constantes para CreateFile
        private const uint GENERIC_WRITE = 0x40000000;
        private const uint FILE_SHARE_READ = 0x00000001;
        private const uint FILE_SHARE_WRITE = 0x00000002;
        private const uint OPEN_EXISTING = 3;
        private const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;

        // Constantes para SetKernelObjectSecurity
        private const uint OWNER_SECURITY_INFORMATION = 0x00000001;

        // Constantes para SECURITY_DESCRIPTOR
        private const ushort SE_OWNER_DEFAULTED = 0x0001;

        [StructLayout(LayoutKind.Sequential)]
        private struct SECURITY_DESCRIPTOR
        {
            public byte Revision;
            public byte Sbz1;
            public ushort Control;
            public IntPtr Owner;
            public IntPtr Group;
            public IntPtr Sacl;
            public IntPtr Dacl;
        }

        #endregion

        #region IDisposable Support

        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (disposing)
                {
                    // TODO: dispose managed state (managed objects)
                }

                // TODO: free unmanaged resources (unmanaged objects) and override finalizer
                // TODO: set large fields to null
                _disposed = true;
            }
        }

        // TODO: override finalizer only if 'Dispose(bool disposing)' has code to free unmanaged resources
        ~DiskProtectionService()
        {
            // Do not change this code. Put cleanup code in 'Dispose(bool disposing)' method
            Dispose(disposing: false);
        }

        public void Dispose()
        {
            // Do not change this code. Put cleanup code in 'Dispose(bool disposing)' method
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }

        #endregion
    }

    /// <summary>
    /// Representa una entrada de permiso de una unidad de disco.
    /// </summary>
    public class DrivePermissionEntry
    {
        public IdentityReference IdentityReference { get; set; }
        public AccessControlType AccessControlType { get; set; }
        public FileSystemRights FileSystemRights { get; set; }
    }
}

using DiskProtectorApp.Logging;
using DiskProtectorApp.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Threading.Tasks;

namespace DiskProtectorApp.Services
{
    // Clase auxiliar para representar un permiso de forma clara
    public class DrivePermissionEntry
    {
        public string Identity { get; set; } // Nombre del usuario/grupo
        public AccessControlType AccessType { get; set; } // Allow o Deny
        public string Permissions { get; set; } // Representación legible de los permisos (e.g., "RX", "M", "F")
        public FileSystemRights RawRights { get; set; } // Valor numérico original para depuración
    }

    public class DiskService
    {
        // Constantes para los SIDs de grupos bien conocidos
        private static readonly SecurityIdentifier BUILTIN_USERS_SID = new SecurityIdentifier(WellKnownSidType.BuiltinUsersSid, null);
        private static readonly SecurityIdentifier AUTHENTICATED_USERS_SID = new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null);
        private static readonly SecurityIdentifier BUILTIN_ADMINS_SID = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        private static readonly SecurityIdentifier LOCAL_SYSTEM_SID = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);

        public List<DiskInfo> GetDisks()
        {
            AppLogger.LogService("[DISK_DEBUG] Iniciando GetDisks");
            var disks = new List<DiskInfo>();
            var systemDrive = Path.GetPathRoot(Environment.SystemDirectory);
            AppLogger.LogService($"[DISK_DEBUG] Disco del sistema es: {systemDrive}");

            foreach (var drive in DriveInfo.GetDrives())
            {
                try
                {
                    AppLogger.LogService($"[DISK_DEBUG] Procesando unidad: {drive.Name}");
                    
                    // Variables locales para evitar múltiples accesos
                    string driveName = drive.Name;
                    string volumeLabel = drive.VolumeLabel ?? "Sin etiqueta";
                    long totalSize = drive.TotalSize;
                    long availableFreeSpace = drive.AvailableFreeSpace;
                    string formattedTotalSize = FormatBytes(totalSize);
                    string formattedFreeSpace = FormatBytes(availableFreeSpace);
                    
                    // Verificar si es un disco fijo con sistema de archivos NTFS
                    if (drive.DriveType != DriveType.Fixed)
                    {
                        AppLogger.LogService($"[DISK_DEBUG] La unidad {driveName} no es fija, marcando como no seleccionable...");
                        disks.Add(new DiskInfo
                        {
                            DriveLetter = driveName,
                            VolumeName = volumeLabel,
                            TotalSize = formattedTotalSize,
                            FreeSpace = formattedFreeSpace,
                            IsSelectable = false,
                            IsProtected = false,
                            ProtectionStatus = "No Elegible",
                            IsSystemDisk = false,
                            IsManageable = false
                        });
                        continue;
                    }
                    
                    if (drive.DriveFormat != "NTFS")
                    {
                        AppLogger.LogService($"[DISK_DEBUG] La unidad {driveName} no es NTFS, marcando como no seleccionable...");
                        disks.Add(new DiskInfo
                        {
                            DriveLetter = driveName,
                            VolumeName = volumeLabel,
                            TotalSize = formattedTotalSize,
                            FreeSpace = formattedFreeSpace,
                            IsSelectable = false,
                            IsProtected = false,
                            ProtectionStatus = "No Elegible",
                            IsSystemDisk = false,
                            IsManageable = false
                        });
                        continue;
                    }

                    bool isSystemDisk = string.Equals(driveName, systemDrive, StringComparison.OrdinalIgnoreCase);
                    AppLogger.LogService($"[DISK_DEBUG] La unidad {driveName} es NTFS. Es disco del sistema: {isSystemDisk}");

                    var diskInfo = new DiskInfo
                    {
                        DriveLetter = driveName,
                        VolumeName = volumeLabel,
                        TotalSize = formattedTotalSize,
                        FreeSpace = formattedFreeSpace,
                        IsSystemDisk = isSystemDisk,
                        IsSelectable = !isSystemDisk,
                        IsProtected = false
                    };

                    // Establecer estado de protección y administrabilidad (solo si es seleccionable)
                    if (diskInfo.IsSelectable)
                    {
                        AppLogger.LogService($"[DISK_DEBUG] Verificando si la unidad {driveName} es administrable...");
                        diskInfo.IsManageable = IsDriveManageable(driveName);
                        AppLogger.LogService($"[DISK_DEBUG] La unidad {driveName} es administrable: {diskInfo.IsManageable}");
                        
                        if (!diskInfo.IsManageable)
                        {
                            diskInfo.ProtectionStatus = "No Administrable";
                            diskInfo.IsProtected = false;
                            AppLogger.LogService($"[DISK_DEBUG] La unidad {driveName} no es administrable, estableciendo IsProtected a false");
                        }
                        else
                        {
                            AppLogger.LogService($"[DISK_DEBUG] Verificando estado de protección para la unidad {driveName}...");
                            diskInfo.IsProtected = IsDriveProtected(driveName);
                            AppLogger.LogService($"[DISK_DEBUG] La unidad {driveName} es seleccionable y administrable. Protegida: {diskInfo.IsProtected}");
                            diskInfo.ProtectionStatus = diskInfo.IsProtected ? "Protegido" : "Desprotegido";
                        }
                    }
                    else
                    {
                        diskInfo.ProtectionStatus = "No Elegible";
                        diskInfo.IsManageable = false;
                        diskInfo.IsProtected = false;
                        AppLogger.LogService($"[DISK_DEBUG] La unidad {driveName} no es seleccionable (disco del sistema o no NTFS), estableciendo IsProtected a false");
                    }

                    disks.Add(diskInfo);
                }
                catch (Exception ex)
                {
                    AppLogger.Error("Service", $"Error procesando la unidad {drive.Name}", ex);
                }
            }

            AppLogger.LogService($"[DISK_DEBUG] GetDisks completado. Total de unidades: {disks.Count}");
            return disks;
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
                            AppLogger.LogService($"[MANAGE_DEBUG] Los administradores tienen Control Total en {drivePath}");
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
                            AppLogger.LogService($"[MANAGE_DEBUG] SYSTEM tiene Control Total en {drivePath}");
                        }
                    }
                }

                // Un disco es administrable si ambos grupos tienen Control Total
                bool isManageable = adminsHasFullControl && systemHasFullControl;
                AppLogger.LogService($"[MANAGE_DEBUG] La unidad {drivePath} es administrable: {isManageable}");
                return isManageable;
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"Error verificando administrabilidad para {drivePath}", ex);
                return false; // En caso de error, asumir no administrable
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
                    var identity = rule.IdentityReference.Value;
                    var accessType = rule.AccessControlType;
                    var rawRights = rule.FileSystemRights;

                    // Convertir FileSystemRights a una representación legible simple
                    string readablePermissions = ConvertFileSystemRightsToSimpleString(rawRights);

                    AppLogger.LogService($"[EXTRACT_PERMS] Regla analizada - Identidad: {identity}, Tipo: {accessType}, Permisos (raw): {rawRights} ({(long)rawRights}), Permisos (legible): {readablePermissions}");

                    // Solo nos interesan las reglas Allow para los grupos relevantes
                    if (accessType == AccessControlType.Allow &&
                        (identity.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase) ||
                         identity.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase)))
                    {
                        var entry = new DrivePermissionEntry
                        {
                            Identity = identity,
                            AccessType = accessType,
                            Permissions = readablePermissions,
                            RawRights = rawRights
                        };
                        permissions.Add(entry);
                        AppLogger.LogService($"[EXTRACT_PERMS] Permiso relevante agregado: {entry.Identity} - {entry.Permissions}");
                    }
                }
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"[EXTRACT_PERMS] Error extrayendo permisos para {drivePath}", ex);
                // Devolver lista vacía en caso de error
            }

            AppLogger.LogService($"[EXTRACT_PERMS] Extracción completada para {drivePath}. Total entradas relevantes: {permissions.Count}");
            return permissions;
        }

        /// <summary>
        /// Convierte FileSystemRights a una cadena legible simple (F, M, RX, etc.).
        /// </summary>
        private string ConvertFileSystemRightsToSimpleString(FileSystemRights rights)
        {
            // Orden de prioridad para la representación: F > M > W > RX > R
            if ((rights & FileSystemRights.FullControl) == FileSystemRights.FullControl)
                return "F"; // Full Control
            if ((rights & FileSystemRights.Modify) == FileSystemRights.Modify)
                return "M"; // Modify (incluye Write)
            if ((rights & FileSystemRights.Write) == FileSystemRights.Write)
                return "W"; // Write only
            if ((rights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory)) != 0)
                return "RX"; // Read & Execute/List Directory
            if ((rights & FileSystemRights.Read) == FileSystemRights.Read)
                return "R"; // Read only
            
            // Si no coincide con ninguno de los anteriores, devolver una representación genérica
            // (Esto puede pasar con combinaciones complejas o permisos especiales)
            return rights.ToString();
        }

        /// <summary>
        /// Verifica si un disco está protegido según la lógica definida:
        /// (SOLO se aplica a discos elegibles y administrables)
        /// 
        /// LÓGICA DE NEGOCIO SIMPLE:
        /// 
        /// DISCO PROTEGIDO:
        /// - Grupo "Usuarios" NO tiene permisos Allow.
        /// - Grupo "Usuarios autenticados" tiene SOLO permisos de lectura/ejecución (RX).
        /// 
        /// DISCO DESPROTEGIDO:
        /// - Grupo "Usuarios" tiene permisos Allow.
        /// - Grupo "Usuarios autenticados" tiene permisos de modificación/escritura (M, W, F).
        /// </summary>
        private bool IsDriveProtected(string drivePath)
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
                    p.Identity.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase) && 
                    p.AccessType == AccessControlType.Allow);

                var authUsersPermissions = permissions.Where(p => 
                    p.Identity.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase) && 
                    p.AccessType == AccessControlType.Allow).ToList();

                bool authUsersHasAnyPermissions = authUsersPermissions.Any();
                bool authUsersHasModifyWriteFullPermissions = authUsersPermissions.Any(p => 
                    p.Permissions == "M" || p.Permissions == "W" || p.Permissions == "F");
                
                // Un disco está protegido si Usuarios autenticados tiene SOLO RX y Usuarios no tiene permisos
                bool authUsersHasOnlyReadOnlyPermissions = authUsersHasAnyPermissions && 
                                                            !authUsersHasModifyWriteFullPermissions && 
                                                            authUsersPermissions.All(p => p.Permissions == "RX");

                bool isProtected = !usersHasAllowPermissions && authUsersHasOnlyReadOnlyPermissions;

                AppLogger.LogService($"[PROTECT_DEBUG] Resultados para {drivePath} - Usuarios tiene permisos Allow: {usersHasAllowPermissions}, " +
                                     $"Usuarios autentificados tiene permisos: {authUsersHasAnyPermissions}, " +
                                     $"Usuarios autentificados tiene M/W/F: {authUsersHasModifyWriteFullPermissions}, " +
                                     $"Usuarios autentificados tiene solo RX: {authUsersHasOnlyReadOnlyPermissions}");
                AppLogger.LogService($"[PROTECT_DEBUG] La unidad {drivePath} está protegida: {isProtected}");

                return isProtected;
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"[PROTECT_DEBUG] Error verificando estado de protección para {drivePath}", ex);
                return false; // En caso de error, asumir desprotegido
            }
        }


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
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                    
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] SIDs traducidos para {drivePath}. Usuarios: {usersAccount?.Value}, Usuarios autentificados: {authUsersAccount?.Value}");

                    // --- PASO 1: Limpiar todas las reglas para "Usuarios" ---
                    progress?.Report("Limpiando reglas para Usuarios...");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Iniciando Paso 1 para {drivePath}");
                    
                    // Método más robusto: obtener y eliminar específicamente
                    var allRules = security.GetAccessRules(true, true, typeof(NTAccount));
                    var rulesToRemove = new List<FileSystemAccessRule>();
                    foreach (FileSystemAccessRule rule in allRules)
                    {
                        if (rule.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase))
                        {
                            rulesToRemove.Add(rule);
                            AppLogger.LogService($"[PROTECT_OP_DEBUG] Encontrada regla de Usuarios para eliminar en {drivePath}: Tipo={rule.AccessControlType}, Permisos={rule.FileSystemRights}");
                        }
                    }
                    bool usersRulesRemoved = true;
                    foreach (var rule in rulesToRemove)
                    {
                        try
                        {
                            security.RemoveAccessRuleSpecific(rule);
                            AppLogger.LogPermissionChange(drivePath, "RemoveAccessRuleSpecific", "Usuarios", rule.FileSystemRights.ToString(), true);
                        }
                        catch (Exception removeEx)
                        {
                            AppLogger.Error("Service", $"[PROTECT_OP_DEBUG] Error eliminando regla específica para Usuarios en {drivePath}", removeEx);
                            usersRulesRemoved = false;
                        }
                    }
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Paso 1 completado para {drivePath}. Reglas de Usuarios eliminadas: {usersRulesRemoved}");

                    // --- PASO 2: Limpiar todas las reglas para "Usuarios autenticados" ---
                    progress?.Report("Limpiando reglas para Usuarios autenticados...");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Iniciando Paso 2 para {drivePath}");
                    
                    var allRules2 = security.GetAccessRules(true, true, typeof(NTAccount));
                    var authUsersRulesToRemove = new List<FileSystemAccessRule>();
                    foreach (FileSystemAccessRule rule in allRules2)
                    {
                        if (rule.IdentityReference.Value.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase))
                        {
                            authUsersRulesToRemove.Add(rule);
                            AppLogger.LogService($"[PROTECT_OP_DEBUG] Encontrada regla de Usuarios autentificados para eliminar en {drivePath}: Tipo={rule.AccessControlType}, Permisos={rule.FileSystemRights}");
                        }
                    }
                    bool authUsersRulesRemoved = true;
                    foreach (var rule in authUsersRulesToRemove)
                    {
                        try
                        {
                            security.RemoveAccessRuleSpecific(rule);
                            AppLogger.LogPermissionChange(drivePath, "RemoveAccessRuleSpecific", "Usuarios Autenticados", rule.FileSystemRights.ToString(), true);
                        }
                        catch (Exception removeEx)
                        {
                            AppLogger.Error("Service", $"[PROTECT_OP_DEBUG] Error eliminando regla específica para Usuarios autentificados en {drivePath}", removeEx);
                            authUsersRulesRemoved = false;
                        }
                    }
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Paso 2 completado para {drivePath}. Reglas de Usuarios autenticados eliminadas: {authUsersRulesRemoved}");

                    // --- PASO 3: Establecer permisos explícitos para "Usuarios autenticados" ---
                    progress?.Report("Estableciendo permisos básicos de lectura para Usuarios autenticados...");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Iniciando Paso 3 para {drivePath}");
                    
                    // Crear regla con permisos básicos de lectura EXACTOS
                    var authUsersReadRule = new FileSystemAccessRule(authUsersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    // Establecer estos permisos usando ModifyAccessRule con Set
                    bool authUsersReadSet = security.ModifyAccessRule(AccessControlModification.Set, authUsersReadRule, out bool authUsersReadModified);
                    AppLogger.LogPermissionChange(drivePath, "Modify.Set", "Usuarios Autenticados", "ReadAndExecute/ListDirectory/Read", authUsersReadSet && authUsersReadModified);
                    progress?.Report($"Permisos básicos de lectura establecidos para Usuarios autenticados: {authUsersReadSet && authUsersReadModified}");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Paso 3 completado para {drivePath}");

                    // --- PASO 4: Asegurar permisos de administrador ---
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Iniciando Paso 4 para {drivePath}");
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
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Paso 4 completado para {drivePath}");

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
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                    
                    AppLogger.LogService($"[UNPROTECT_DEBUG] SIDs traducidos para {drivePath}. Usuarios: {usersAccount?.Value}, Usuarios autentificados: {authUsersAccount?.Value}");

                    // --- PASO 1: Limpiar todas las reglas para "Usuarios" ---
                    progress?.Report("Limpiando reglas para Usuarios...");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 1 para {drivePath}");
                    
                    // Método más robusto: obtener y eliminar específicamente
                    var allRules = security.GetAccessRules(true, true, typeof(NTAccount));
                    var usersRulesToRemove = new List<FileSystemAccessRule>();
                    foreach (FileSystemAccessRule rule in allRules)
                    {
                        if (rule.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase))
                        {
                            usersRulesToRemove.Add(rule);
                            AppLogger.LogService($"[UNPROTECT_DEBUG] Encontrada regla de Usuarios para eliminar en {drivePath}: Tipo={rule.AccessControlType}, Permisos={rule.FileSystemRights}");
                        }
                    }
                    bool usersRulesRemoved = true;
                    foreach (var rule in usersRulesToRemove)
                    {
                        try
                        {
                            security.RemoveAccessRuleSpecific(rule);
                            AppLogger.LogPermissionChange(drivePath, "RemoveAccessRuleSpecific", "Usuarios", rule.FileSystemRights.ToString(), true);
                        }
                        catch (Exception removeEx)
                        {
                            AppLogger.Error("Service", $"[UNPROTECT_DEBUG] Error eliminando regla específica para Usuarios en {drivePath}", removeEx);
                            usersRulesRemoved = false;
                        }
                    }
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Paso 1 completado para {drivePath}. Reglas de Usuarios eliminadas: {usersRulesRemoved}");

                    // --- PASO 2: Limpiar todas las reglas para "Usuarios autenticados" ---
                    progress?.Report("Limpiando reglas para Usuarios autenticados...");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 2 para {drivePath}");
                    
                    var allRules2 = security.GetAccessRules(true, true, typeof(NTAccount));
                    var authUsersRulesToRemove = new List<FileSystemAccessRule>();
                    foreach (FileSystemAccessRule rule in allRules2)
                    {
                        if (rule.IdentityReference.Value.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase))
                        {
                            authUsersRulesToRemove.Add(rule);
                            AppLogger.LogService($"[UNPROTECT_DEBUG] Encontrada regla de Usuarios autentificados para eliminar en {drivePath}: Tipo={rule.AccessControlType}, Permisos={rule.FileSystemRights}");
                        }
                    }
                    bool authUsersRulesRemoved = true;
                    foreach (var rule in authUsersRulesToRemove)
                    {
                        try
                        {
                            security.RemoveAccessRuleSpecific(rule);
                            AppLogger.LogPermissionChange(drivePath, "RemoveAccessRuleSpecific", "Usuarios Autenticados", rule.FileSystemRights.ToString(), true);
                        }
                        catch (Exception removeEx)
                        {
                            AppLogger.Error("Service", $"[UNPROTECT_DEBUG] Error eliminando regla específica para Usuarios autentificados en {drivePath}", removeEx);
                            authUsersRulesRemoved = false;
                        }
                    }
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Paso 2 completado para {drivePath}. Reglas de Usuarios autenticados eliminadas: {authUsersRulesRemoved}");

                    // --- PASO 3: Establecer permisos para "Usuarios" ---
                    progress?.Report("Restaurando permisos de Usuarios...");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 3 para {drivePath}");
                    
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
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Paso 3 completado para {drivePath}");

                    // --- PASO 4: Establecer permisos para "Usuarios autenticados" ---
                    progress?.Report("Restaurando permisos de modificación/escritura a Usuarios autenticados...");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 4 para {drivePath}");
                    
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
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Paso 4 completado para {drivePath}");

                    // --- PASO 5: Asegurar permisos de administrador ---
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 5 para {drivePath}");
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
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Paso 5 completado para {drivePath}");

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

        private bool IsCurrentUserAdministrator()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                bool isAdmin = principal.IsInRole(WindowsBuiltInRole.Administrator);
                AppLogger.LogService($"Usuario actual es administrador: {isAdmin}");
                return isAdmin;
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", "Error verificando privilegios de administrador", ex);
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

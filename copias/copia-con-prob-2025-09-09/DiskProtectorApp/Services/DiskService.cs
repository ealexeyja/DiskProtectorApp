using DiskProtectorApp.Logging;
using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
using System.ComponentModel; // Para Win32Exception

namespace DiskProtectorApp.Services
{
    // Declaraciones P/Invoke para la funcionalidad SetOwner y ajuste de privilegios
    internal static class NativeMethods
    {
        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool GetFileSecurity(
            string lpFileName,
            uint RequestedInformation,
            IntPtr pSecurityDescriptor,
            uint nLength,
            out uint lpnLengthNeeded);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool SetFileSecurity(
            string lpFileName,
            uint SecurityInformation,
            IntPtr pSecurityDescriptor);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern uint GetSecurityDescriptorLength(IntPtr pSecurityDescriptor);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool InitializeSecurityDescriptor(
            IntPtr pSecurityDescriptor,
            uint dwRevision);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool SetSecurityDescriptorOwner(
            IntPtr pSecurityDescriptor,
            IntPtr pOwner,
            bool bOwnerDefaulted);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool IsValidSid(IntPtr pSid);

        [DllImport("kernel32.dll")]
        public static extern IntPtr LocalFree(IntPtr hMem);

        // Para ConvertStringSidToSid
        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool ConvertStringSidToSid(
            string StringSid,
            out IntPtr Sid);

        // Constantes de privilegios
        public const string SE_RESTORE_NAME = "SeRestorePrivilege";
        public const string SE_BACKUP_NAME = "SeBackupPrivilege";
        public const string SE_TAKE_OWNERSHIP_NAME = "SeTakeOwnershipPrivilege";

        // Derechos de acceso al token
        public const uint TOKEN_ADJUST_PRIVILEGES = 0x0020;
        public const uint TOKEN_QUERY = 0x0008;
        public const uint TOKEN_ALL_ACCESS = 0x000F01FF;

        // Atributos de privilegios
        public const uint SE_PRIVILEGE_ENABLED = 0x00000002;

        // Estructuras necesarias para AdjustTokenPrivileges
        [StructLayout(LayoutKind.Sequential)]
        public struct LUID
        {
            public uint LowPart;
            public int HighPart;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct LUID_AND_ATTRIBUTES
        {
            public LUID Luid;
            public uint Attributes;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct TOKEN_PRIVILEGES
        {
            public uint PrivilegeCount;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 1)]
            public LUID_AND_ATTRIBUTES[] Privileges;
        }

        // Llamadas P/Invoke para ajuste de privilegios
        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool OpenProcessToken(
            IntPtr ProcessHandle,
            uint DesiredAccess,
            out IntPtr TokenHandle);

        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool LookupPrivilegeValue(
            string lpSystemName,
            string lpName,
            out LUID lpLuid);

        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool AdjustTokenPrivileges(
            IntPtr TokenHandle,
            [MarshalAs(UnmanagedType.Bool)] bool DisableAllPrivileges,
            ref TOKEN_PRIVILEGES NewState,
            uint BufferLength,
            IntPtr PreviousState,
            IntPtr ReturnLength);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CloseHandle(IntPtr hObject);

        // Constantes para SetFileSecurity
        public const uint OWNER_SECURITY_INFORMATION = 0x00000001;
        public const uint DACL_SECURITY_INFORMATION = 0x00000004;
        public const uint GROUP_SECURITY_INFORMATION = 0x00000002;
        public const uint SACL_SECURITY_INFORMATION = 0x00000008;
        public const uint LABEL_SECURITY_INFORMATION = 0x00000010;
        public const uint ATTRIBUTE_SECURITY_INFORMATION = 0x00000020;
        public const uint SCOPE_SECURITY_INFORMATION = 0x00000040;
        public const uint PROCESS_TRUST_LABEL_SECURITY_INFORMATION = 0x00000080;
        public const uint ACCESS_FILTER_SECURITY_INFORMATION = 0x00000100;
        public const uint BACKUP_SECURITY_INFORMATION = 0x00010000;
        public const uint PROTECTED_DACL_SECURITY_INFORMATION = 0x80000000;
        public const uint PROTECTED_SACL_SECURITY_INFORMATION = 0x40000000;
        public const uint UNPROTECTED_DACL_SECURITY_INFORMATION = 0x20000000;
        public const uint UNPROTECTED_SACL_SECURITY_INFORMATION = 0x10000000;
        
        public const uint SECURITY_DESCRIPTOR_REVISION = 1;
        public const uint SECURITY_DESCRIPTOR_MIN_LENGTH = 20;
    }

    // Clase auxiliar para gestionar la habilitación/deshabilitación de privilegios
    public class PrivilegeHelper : IDisposable
    {
        private IntPtr _tokenHandle = IntPtr.Zero;
        private bool _disposed = false;

        public bool EnablePrivilege(string privilegeName)
        {
            try
            {
                if (_tokenHandle == IntPtr.Zero)
                {
                    if (!NativeMethods.OpenProcessToken(NativeMethods.GetCurrentProcess(),
                        NativeMethods.TOKEN_ADJUST_PRIVILEGES | NativeMethods.TOKEN_QUERY,
                        out _tokenHandle))
                    {
                        int error = Marshal.GetLastWin32Error();
                        AppLogger.Error("Service", $"[PRIVILEGE_HELPER] Error abriendo token de proceso para {privilegeName}. Código: {error}", new Win32Exception(error));
                        return false;
                    }
                }

                NativeMethods.LUID luid = new NativeMethods.LUID();
                if (!NativeMethods.LookupPrivilegeValue(null, privilegeName, out luid))
                {
                    int error = Marshal.GetLastWin32Error();
                    AppLogger.Error("Service", $"[PRIVILEGE_HELPER] Error buscando privilegio {privilegeName}. Código: {error}", new Win32Exception(error));
                    return false;
                }

                NativeMethods.TOKEN_PRIVILEGES tp = new NativeMethods.TOKEN_PRIVILEGES();
                tp.PrivilegeCount = 1;
                tp.Privileges = new NativeMethods.LUID_AND_ATTRIBUTES[1];
                tp.Privileges[0].Luid = luid;
                tp.Privileges[0].Attributes = NativeMethods.SE_PRIVILEGE_ENABLED;

                if (!NativeMethods.AdjustTokenPrivileges(_tokenHandle, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero))
                {
                    int error = Marshal.GetLastWin32Error();
                    AppLogger.Error("Service", $"[PRIVILEGE_HELPER] Error ajustando privilegios de token para {privilegeName}. Código: {error}", new Win32Exception(error));
                    return false;
                }

                AppLogger.LogService($"[PRIVILEGE_HELPER] Privilegio {privilegeName} habilitado exitosamente.");
                return true;
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"[PRIVILEGE_HELPER] Excepción habilitando privilegio {privilegeName}", ex);
                return false;
            }
        }

        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (_tokenHandle != IntPtr.Zero)
                {
                    NativeMethods.CloseHandle(_tokenHandle);
                    _tokenHandle = IntPtr.Zero;
                }
                _disposed = true;
            }
        }
    }

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
                    
                    // Solo procesar discos fijos con sistema de archivos NTFS
                    if (drive.DriveType != DriveType.Fixed)
                    {
                        AppLogger.LogService($"[DISK_DEBUG] La unidad {drive.Name} no es fija, marcando como no seleccionable...");
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
                        AppLogger.LogService($"[DISK_DEBUG] La unidad {drive.Name} no es NTFS, marcando como no seleccionable...");
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

                    bool isSystemDisk = string.Equals(drive.Name, systemDrive, StringComparison.OrdinalIgnoreCase);
                    AppLogger.LogService($"[DISK_DEBUG] La unidad {drive.Name} es NTFS. Es disco del sistema: {isSystemDisk}");

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
                        AppLogger.LogService($"[DISK_DEBUG] La unidad {drive.Name} es administrable: {disk.IsManageable}");
                        
                        if (!disk.IsManageable)
                        {
                            disk.ProtectionStatus = "No Administrable";
                            disk.IsProtected = false; // No puede estar protegido si no es administrable
                            AppLogger.LogService($"[DISK_DEBUG] La unidad {drive.Name} no es administrable, estableciendo IsProtected a false");
                        }
                        else
                        {
                            // Solo verificar estado de protección si es administrable
                            AppLogger.LogService($"[DISK_DEBUG] Verificando estado de protección para la unidad {drive.Name}...");
                            disk.IsProtected = IsDriveProtected(drive.Name);
                            AppLogger.LogService($"[DISK_DEBUG] La unidad {drive.Name} es seleccionable y administrable. Protegida: {disk.IsProtected}");
                            disk.ProtectionStatus = disk.IsProtected ? "Protegido" : "Desprotegido";
                        }
                    }
                    else
                    {
                        disk.ProtectionStatus = "No Elegible";
                        disk.IsManageable = false; // Forzar a no administrable si no es elegible
                        disk.IsProtected = false; // Forzar a no protegido si no es elegible
                        AppLogger.LogService($"[DISK_DEBUG] La unidad {drive.Name} no es seleccionable (disco del sistema o no NTFS), estableciendo IsProtected a false");
                    }

                    disks.Add(disk);
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
                    if (rule.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        // Convertir FileSystemRights a una representación legible simple
                        string readablePermissions = ConvertFileSystemRightsToSimpleString(rights);
                        permissions.Add(new DrivePermissionEntry
                        {
                            Identity = usersAccount.Value,
                            AccessType = AccessControlType.Allow,
                            Permissions = readablePermissions,
                            RawRights = rights
                        });
                        AppLogger.LogService($"[EXTRACT_PERMS] Encontrados permisos de Usuarios en {drivePath}: {readablePermissions}");
                    }

                    // Verificar permisos de Usuarios autenticados
                    if (rule.IdentityReference.Value.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        // Convertir FileSystemRights a una representación legible simple
                        string readablePermissions = ConvertFileSystemRightsToSimpleString(rights);
                        permissions.Add(new DrivePermissionEntry
                        {
                            Identity = authUsersAccount.Value,
                            AccessType = AccessControlType.Allow,
                            Permissions = readablePermissions,
                            RawRights = rights
                        });
                        AppLogger.LogService($"[EXTRACT_PERMS] Encontrados permisos de Usuarios autentificados en {drivePath}: {readablePermissions}");
                    }
                }
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"Error extrayendo permisos para {drivePath}", ex);
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
                return "F"; // Control Total
            if ((rights & FileSystemRights.Modify) == FileSystemRights.Modify)
                return "M"; // Modificar (incluye Escritura)
            if ((rights & FileSystemRights.Write) == FileSystemRights.Write)
                return "W"; // Solo Escritura
            if ((rights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory)) != 0)
                return "RX"; // Leer y Ejecutar/Mostrar contenido de carpeta
            if ((rights & FileSystemRights.Read) == FileSystemRights.Read)
                return "R"; // Solo Lectura
            
            // Si no coincide con ninguno de los anteriores, devolver una representación genérica
            // (Esto puede pasar con combinaciones complejas o permisos especiales)
            return rights.ToString();
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
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Paso 1 completado para {drivePath}");

                    // --- PASO 2: Limpiar todas las reglas para "Usuarios autenticados" ---
                    progress?.Report("Limpiando reglas para Usuarios autenticados...");
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Iniciando Paso 2 para {drivePath}");
                    
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
                    AppLogger.LogService($"[PROTECT_OP_DEBUG] Paso 2 completado para {drivePath}");

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
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Paso 1 completado para {drivePath}");

                    // --- PASO 2: Limpiar todas las reglas para "Usuarios autenticados" ---
                    progress?.Report("Limpiando reglas para Usuarios autenticados...");
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Iniciando Paso 2 para {drivePath}");
                    
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
                    AppLogger.LogService($"[UNPROTECT_DEBUG] Paso 2 completado para {drivePath}");

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

                    // --- PASO 0: Solicitar privilegios necesarios ---
                    progress?.Report("Solicitando privilegios especiales...");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 0 - Solicitar privilegios para {cleanDrivePath}");
                    
                    bool privilegesAcquired = false;
                    using (var privilegeHelper = new PrivilegeHelper())
                    {
                        // Intentar habilitar privilegios críticos para la operación
                        bool restorePriv = privilegeHelper.EnablePrivilege(NativeMethods.SE_RESTORE_NAME);
                        bool takeOwnershipPriv = privilegeHelper.EnablePrivilege(NativeMethods.SE_TAKE_OWNERSHIP_NAME);
                        bool backupPriv = privilegeHelper.EnablePrivilege(NativeMethods.SE_BACKUP_NAME);
                        
                        privilegesAcquired = restorePriv && takeOwnershipPriv && backupPriv;
                        
                        AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Paso 0 - Privilegios solicitados para {cleanDrivePath}. Restore: {restorePriv}, TakeOwnership: {takeOwnershipPriv}, Backup: {backupPriv}, TodosAdquiridos: {privilegesAcquired}");
                        
                        if (!privilegesAcquired)
                        {
                            AppLogger.Warn("Service", $"[MANAGE_DRIVE_DEBUG] Advertencia: No se pudieron adquirir todos los privilegios necesarios para {cleanDrivePath}, continuando con los disponibles...");
                            // No retornamos false aquí, intentamos continuar con los privilegios que conseguimos
                        }
                    }
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Paso 0 completado para {cleanDrivePath}");

                    // --- PASO 1: Cambiar el propietario del directorio raíz a SYSTEM ---
                    progress?.Report("Cambiando propietario del disco a SYSTEM...");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 1 - Cambiar propietario para {cleanDrivePath}");
                    
                    if (!SetDriveOwner(cleanDrivePath, LOCAL_SYSTEM_SID))
                    {
                        AppLogger.Error("Service", $"[MANAGE_DRIVE_DEBUG] Error cambiando propietario del disco {cleanDrivePath} a SYSTEM");
                        progress?.Report("Error: No se pudo cambiar el propietario del disco a SYSTEM");
                        return false;
                    }
                    
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Paso 1 completado - Propietario cambiado a SYSTEM para {cleanDrivePath}");

                    // --- PASO 2: Obtener el objeto DirectorySecurity actualizado ---
                    progress?.Report("Obteniendo permisos actualizados del disco...");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 2 - Obtener permisos actualizados para {cleanDrivePath}");
                    
                    var directoryInfo = new DirectoryInfo(cleanDrivePath);
                    var security = directoryInfo.GetAccessControl();
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Paso 2 completado - Permisos obtenidos para {cleanDrivePath}");

                    // --- PASO 3: Traducir SIDs a cuentas ---
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 3 - Traducir SIDs para {cleanDrivePath}");
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] SIDs traducidos para {cleanDrivePath}. Administradores: {adminsAccount?.Value}, SYSTEM: {systemAccount?.Value}");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Paso 3 completado para {cleanDrivePath}");

                    // --- PASO 4: Establecer permisos de Control Total para SYSTEM ---
                    progress?.Report("Estableciendo permisos de Control Total para SYSTEM...");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 4 - Establecer permisos para SYSTEM en {cleanDrivePath}");
                    
                    var systemRule = new FileSystemAccessRule(systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    bool systemRuleSet = security.ModifyAccessRule(AccessControlModification.Set, systemRule, out bool systemRuleModified);
                    AppLogger.LogPermissionChange(cleanDrivePath, "Modify.Set", "SYSTEM", "FullControl", systemRuleSet && systemRuleModified);
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Paso 4 completado para {cleanDrivePath}. SYSTEM Rule Set: {systemRuleSet}, Modified: {systemRuleModified}");

                    // --- PASO 5: Establecer permisos de Control Total para Administradores ---
                    progress?.Report("Estableciendo permisos de Control Total para Administradores...");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 5 - Establecer permisos para Administradores en {cleanDrivePath}");
                    
                    var adminsRule = new FileSystemAccessRule(adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    bool adminsRuleSet = security.ModifyAccessRule(AccessControlModification.Set, adminsRule, out bool adminsRuleModified);
                    AppLogger.LogPermissionChange(cleanDrivePath, "Modify.Set", "Administradores", "FullControl", adminsRuleSet && adminsRuleModified);
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Paso 5 completado para {cleanDrivePath}. Administradores Rule Set: {adminsRuleSet}, Modified: {adminsRuleModified}");

                    // --- PASO 6: Aplicar cambios ---
                    progress?.Report("Aplicando cambios de permisos...");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Iniciando Paso 6 - Aplicar cambios para {cleanDrivePath}");
                    directoryInfo.SetAccessControl(security);
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Paso 6 completado - Cambios aplicados para {cleanDrivePath}");

                    progress?.Report("Administración del disco completada exitosamente");
                    AppLogger.LogService($"[MANAGE_DRIVE_DEBUG] Administración completada exitosamente para la unidad: {drivePath}");
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
                
                // Convertir el SID a un puntero
                byte[] sidBinaryForm = new byte[ownerSid.BinaryLength];
                ownerSid.GetBinaryForm(sidBinaryForm, 0);
                
                // Crear un buffer para el SID
                IntPtr sidPtr = Marshal.AllocHGlobal(sidBinaryForm.Length);
                Marshal.Copy(sidBinaryForm, 0, sidPtr, sidBinaryForm.Length);
                
                // Crear un descriptor de seguridad
                IntPtr securityDescriptor = Marshal.AllocHGlobal(200); // Tamaño suficiente para un SD básico
                try
                {
                    // Inicializar el descriptor de seguridad
                    if (!NativeMethods.InitializeSecurityDescriptor(
                        securityDescriptor,
                        NativeMethods.SECURITY_DESCRIPTOR_REVISION))
                    {
                        int errorCode = Marshal.GetLastWin32Error();
                        AppLogger.Error("Service", $"[SET_OWNER_DEBUG] Error inicializando descriptor de seguridad para {drivePath}. Código: {errorCode}", new Win32Exception(errorCode));
                        return false;
                    }

                    // Establecer el propietario en el descriptor de seguridad
                    if (!NativeMethods.SetSecurityDescriptorOwner(
                        securityDescriptor,
                        sidPtr,
                        false)) // bOwnerDefaulted = false
                    {
                        int errorCode = Marshal.GetLastWin32Error();
                        AppLogger.Error("Service", $"[SET_OWNER_DEBUG] Error estableciendo propietario en descriptor de seguridad para {drivePath}. Código: {errorCode}", new Win32Exception(errorCode));
                        return false;
                    }

                    // Aplicar el descriptor de seguridad al directorio
                    if (!NativeMethods.SetFileSecurity(
                        drivePath,
                        NativeMethods.OWNER_SECURITY_INFORMATION,
                        securityDescriptor))
                    {
                        int errorCode = Marshal.GetLastWin32Error();
                        AppLogger.Error("Service", $"[SET_OWNER_DEBUG] Error aplicando descriptor de seguridad al directorio {drivePath}. Código: {errorCode}", new Win32Exception(errorCode));
                        return false;
                    }

                    AppLogger.LogService($"[SET_OWNER_DEBUG] Propietario cambiado exitosamente para {drivePath}");
                    return true;
                }
                finally
                {
                    // Liberar memoria no administrada
                    if (sidPtr != IntPtr.Zero)
                        Marshal.FreeHGlobal(sidPtr);
                    if (securityDescriptor != IntPtr.Zero)
                        Marshal.FreeHGlobal(securityDescriptor);
                }
            }
            catch (Exception ex)
            {
                AppLogger.Error("Service", $"[SET_OWNER_DEBUG] Excepción cambiando propietario de {drivePath}", ex);
                return false;
            }
        }

        private bool IsCurrentUserAdministrator()
        {
            try
            {
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

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

                    bool isSystemDisk = drive.Name.Equals(systemDrive, StringComparison.OrdinalIgnoreCase);
                    
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
                }
                catch (Exception ex)
                {
                    // Loggear errores pero continuar con otros discos
                    System.Diagnostics.Debug.WriteLine($"Error procesando disco {drive.Name}: {ex.Message}");
                    Console.WriteLine($"Error procesando disco {drive.Name}: {ex.Message}");
                }
            }

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
                        return true;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error determinando tipo de disco para {driveName}: {ex.Message}");
                Console.WriteLine($"Error determinando tipo de disco para {driveName}: {ex.Message}");
            }

            return false;
        }

        /// <summary>
        /// Detecta si un disco está protegido verificando si le han sido REMOVIDOS permisos específicos.
        /// Un disco protegido tiene permisos REMOVIDOS para Usuarios y/o Usuarios autenticados.
        /// </summary>
        private bool IsDriveProtected(string drivePath)
        {
            try
            {
                System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Verificando protección para: {drivePath}");
                Console.WriteLine($"[PERMISSIONS] Verificando protección para: {drivePath}");
                
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                // Buscar si hay reglas que indiquen que permisos fueron removidos
                // Para simplificar, asumiremos que un disco protegido es aquel que:
                // 1. No tiene permisos explícitos de lectura para Usuarios, O
                // 2. No tiene permisos explícitos de modificación para Usuarios autenticados
                
                bool hasUsersReadPermissions = false;
                bool hasAuthUsersModifyPermissions = false;
                
                System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Reglas encontradas: {rules.Count}");
                Console.WriteLine($"[PERMISSIONS] Reglas encontradas: {rules.Count}");

                foreach (FileSystemAccessRule rule in rules)
                {
                    System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Regla - Identity: {rule.IdentityReference.Value}, Type: {rule.AccessControlType}, Rights: {rule.FileSystemRights}");
                    Console.WriteLine($"[PERMISSIONS] Regla - Identity: {rule.IdentityReference.Value}, Type: {rule.AccessControlType}, Rights: {rule.FileSystemRights}");
                    
                    // Verificar permisos de Usuarios (lectura)
                    if ((rule.IdentityReference.Value.Equals("Usuarios", StringComparison.OrdinalIgnoreCase) ||
                         rule.IdentityReference.Value.Equals("Users", StringComparison.OrdinalIgnoreCase)) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        // Verificar si tiene permisos de lectura
                        if ((rule.FileSystemRights & FileSystemRights.Read) == FileSystemRights.Read ||
                            (rule.FileSystemRights & FileSystemRights.ReadAndExecute) == FileSystemRights.ReadAndExecute)
                        {
                            hasUsersReadPermissions = true;
                            System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Usuarios tiene permisos de lectura");
                            Console.WriteLine($"[PERMISSIONS] Usuarios tiene permisos de lectura");
                        }
                    }
                    
                    // Verificar permisos de Usuarios autenticados (modificación)
                    if ((rule.IdentityReference.Value.Equals("Usuarios autenticados", StringComparison.OrdinalIgnoreCase) ||
                         rule.IdentityReference.Value.Equals("Authenticated Users", StringComparison.OrdinalIgnoreCase)) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        // Verificar si tiene permisos de modificación
                        if ((rule.FileSystemRights & FileSystemRights.Modify) == FileSystemRights.Modify)
                        {
                            hasAuthUsersModifyPermissions = true;
                            System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Usuarios autenticados tiene permisos de modificación");
                            Console.WriteLine($"[PERMISSIONS] Usuarios autenticados tiene permisos de modificación");
                        }
                    }
                }

                // Un disco está protegido si NO tiene los permisos normales
                // Es decir, si le han sido removidos permisos de lectura a Usuarios
                // o permisos de modificación a Usuarios autenticados
                bool isProtected = !hasUsersReadPermissions || !hasAuthUsersModifyPermissions;
                System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Resultado: Protegido={isProtected} (Usuarios lectura={hasUsersReadPermissions}, AuthUsers modificación={hasAuthUsersModifyPermissions})");
                Console.WriteLine($"[PERMISSIONS] Resultado: Protegido={isProtected} (Usuarios lectura={hasUsersReadPermissions}, AuthUsers modificación={hasAuthUsersModifyPermissions})");
                
                return isProtected;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
                Console.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
                return false; // En caso de error, asumir que no está protegido
            }
        }

        public async Task<bool> ProtectDriveAsync(string drivePath, IProgress<string> progress)
        {
            return await Task.Run(() =>
            {
                try
                {
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Iniciando protección para: {drivePath}");
                    Console.WriteLine($"[PROTECT] Iniciando protección para: {drivePath}");
                    
                    progress?.Report("Iniciando proceso de protección...");
                    
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Directorio: {directoryInfo.FullName}");
                    Console.WriteLine($"[PROTECT] Directorio: {directoryInfo.FullName}");
                    
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Permisos obtenidos");
                    Console.WriteLine($"[PROTECT] Permisos obtenidos");
                    
                    // 1. Quitar permisos de lectura a Usuarios
                    progress?.Report("Quitando permisos de lectura a Usuarios...");
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Grupo Usuarios: {usersAccount.Value}");
                    Console.WriteLine($"[PROTECT] Grupo Usuarios: {usersAccount.Value}");
                    
                    // Crear una regla que quite específicamente permisos de lectura a Usuarios
                    var removeUsersReadRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.Read | FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Quitando permisos de lectura a {usersAccount.Value}");
                    Console.WriteLine($"[PROTECT] Quitando permisos de lectura a {usersAccount.Value}");
                    security.RemoveAccessRule(removeUsersReadRule);
                    
                    // 2. Quitar permisos de modificación a Usuarios autenticados
                    progress?.Report("Quitando permisos de modificación a Usuarios autenticados...");
                    var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Grupo Usuarios autenticados: {authUsersAccount.Value}");
                    Console.WriteLine($"[PROTECT] Grupo Usuarios autenticados: {authUsersAccount.Value}");
                    
                    // Crear una regla que quite específicamente permisos de modificación a Usuarios autenticados
                    var removeAuthUsersModifyRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.Modify, // Incluye escritura, eliminación, etc.
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Quitando permisos de modificación a {authUsersAccount.Value}");
                    Console.WriteLine($"[PROTECT] Quitando permisos de modificación a {authUsersAccount.Value}");
                    security.RemoveAccessRule(removeAuthUsersModifyRule);
                    
                    progress?.Report("Aplicando cambios de permisos...");
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Aplicando cambios de seguridad...");
                    Console.WriteLine($"[PROTECT] Aplicando cambios de seguridad...");
                    directoryInfo.SetAccessControl(security);
                    
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Protección completada exitosamente para {drivePath}");
                    Console.WriteLine($"[PROTECT] Protección completada exitosamente para {drivePath}");
                    progress?.Report("Protección completada exitosamente");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] ERROR DE PERMISOS CRÍTICO: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    Console.WriteLine($"[PROTECT] ERROR DE PERMISOS CRÍTICO: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Detalles del error: {authEx.StackTrace}");
                    Console.WriteLine($"[PROTECT] Detalles del error: {authEx.StackTrace}");
                    progress?.Report($"Error de permisos crítico: {authEx.Message}");
                    return false;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Error protegiendo disco {drivePath}: {ex.Message}");
                    Console.WriteLine($"[PROTECT] Error protegiendo disco {drivePath}: {ex.Message}");
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Detalles del error: {ex.StackTrace}");
                    Console.WriteLine($"[PROTECT] Detalles del error: {ex.StackTrace}");
                    progress?.Report($"Error general: {ex.Message}");
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
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Iniciando desprotección para: {drivePath}");
                    Console.WriteLine($"[UNPROTECT] Iniciando desprotección para: {drivePath}");
                    
                    progress?.Report("Iniciando proceso de desprotección...");
                    
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Directorio: {directoryInfo.FullName}");
                    Console.WriteLine($"[UNPROTECT] Directorio: {directoryInfo.FullName}");
                    
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Permisos obtenidos");
                    Console.WriteLine($"[UNPROTECT] Permisos obtenidos");
                    
                    // 1. Restaurar permisos de lectura a Usuarios
                    progress?.Report("Restaurando permisos de lectura a Usuarios...");
                    var usersAccount = (NTAccount)BUILTIN_USERS_SID.Translate(typeof(NTAccount));
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Grupo Usuarios: {usersAccount.Value}");
                    Console.WriteLine($"[UNPROTECT] Grupo Usuarios: {usersAccount.Value}");
                    
                    // Crear una regla que restaure permisos de lectura a Usuarios
                    var restoreUsersReadRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.Read | FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Restaurando permisos de lectura a {usersAccount.Value}");
                    Console.WriteLine($"[UNPROTECT] Restaurando permisos de lectura a {usersAccount.Value}");
                    security.SetAccessRule(restoreUsersReadRule);
                    
                    // 2. Restaurar permisos de modificación a Usuarios autenticados
                    progress?.Report("Restaurando permisos de modificación a Usuarios autenticados...");
                    var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Grupo Usuarios autenticados: {authUsersAccount.Value}");
                    Console.WriteLine($"[UNPROTECT] Grupo Usuarios autenticados: {authUsersAccount.Value}");
                    
                    // Crear una regla que restaure permisos de modificación a Usuarios autenticados
                    var restoreAuthUsersModifyRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.Modify, // Incluir escritura, eliminación, etc.
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Restaurando permisos de modificación a {authUsersAccount.Value}");
                    Console.WriteLine($"[UNPROTECT] Restaurando permisos de modificación a {authUsersAccount.Value}");
                    security.SetAccessRule(restoreAuthUsersModifyRule);
                    
                    progress?.Report("Aplicando cambios de permisos...");
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Aplicando cambios de seguridad...");
                    Console.WriteLine($"[UNPROTECT] Aplicando cambios de seguridad...");
                    directoryInfo.SetAccessControl(security);
                    
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Desprotección completada exitosamente para {drivePath}");
                    Console.WriteLine($"[UNPROTECT] Desprotección completada exitosamente para {drivePath}");
                    progress?.Report("Desprotección completada exitosamente");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] ERROR DE PERMISOS CRÍTICO: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    Console.WriteLine($"[UNPROTECT] ERROR DE PERMISOS CRÍTICO: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Detalles del error: {authEx.StackTrace}");
                    Console.WriteLine($"[UNPROTECT] Detalles del error: {authEx.StackTrace}");
                    progress?.Report($"Error de permisos crítico: {authEx.Message}");
                    return false;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Error desprotegiendo disco {drivePath}: {ex.Message}");
                    Console.WriteLine($"[UNPROTECT] Error desprotegiendo disco {drivePath}: {ex.Message}");
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Detalles del error: {ex.StackTrace}");
                    Console.WriteLine($"[UNPROTECT] Detalles del error: {ex.StackTrace}");
                    progress?.Report($"Error general: {ex.Message}");
                    return false;
                }
            });
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

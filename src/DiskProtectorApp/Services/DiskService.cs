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
        /// Detecta si un disco está protegido verificando si tiene permisos explícitos configurados
        /// según nuestro esquema de protección.
        /// </summary>
        private bool IsDriveProtected(string drivePath)
        {
            try
            {
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(IdentityReference));

                // Verificar si la herencia está desactivada
                if (!security.AreAccessRulesProtected)
                {
                    return false; // Si la herencia está activa, no está protegido por nosotros
                }

                bool hasSystemFullControl = false;
                bool hasAdminsFullControl = false;
                bool hasAuthenticatedUsersRead = false;
                bool hasUsersExplicit = false;

                foreach (FileSystemAccessRule rule in rules)
                {
                    // Intentar obtener el SID del IdentityReference
                    SecurityIdentifier sid = null;
                    if (rule.IdentityReference is SecurityIdentifier)
                    {
                        sid = (SecurityIdentifier)rule.IdentityReference;
                    }
                    else if (rule.IdentityReference is NTAccount)
                    {
                        try
                        {
                            sid = (SecurityIdentifier)((NTAccount)rule.IdentityReference).Translate(typeof(SecurityIdentifier));
                        }
                        catch (Exception)
                        {
                            // Si no se puede traducir, continuar
                            continue;
                        }
                    }

                    if (sid != null)
                    {
                        // Verificar permisos de SYSTEM
                        if (sid == LOCAL_SYSTEM_SID &&
                            rule.AccessControlType == AccessControlType.Allow &&
                            rule.FileSystemRights == FileSystemRights.FullControl)
                        {
                            hasSystemFullControl = true;
                        }

                        // Verificar permisos de Administradores
                        if (sid == BUILTIN_ADMINS_SID &&
                            rule.AccessControlType == AccessControlType.Allow &&
                            rule.FileSystemRights == FileSystemRights.FullControl)
                        {
                            hasAdminsFullControl = true;
                        }

                        // Verificar permisos de Usuarios autenticados (lectura)
                        if (sid == AUTHENTICATED_USERS_SID &&
                            rule.AccessControlType == AccessControlType.Allow &&
                            (rule.FileSystemRights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory)) == 
                            (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory))
                        {
                            hasAuthenticatedUsersRead = true;
                        }

                        // Verificar si hay permisos explícitos para Usuarios
                        if (sid == BUILTIN_USERS_SID)
                        {
                            hasUsersExplicit = true;
                        }
                    }
                }

                // Un disco está protegido si:
                // 1. Tiene herencia desactivada
                // 2. Tiene permisos explícitos para SYSTEM, Admins y Authenticated Users
                // 3. NO tiene permisos explícitos para Usuarios (o tiene solo lectura)
                return hasSystemFullControl && hasAdminsFullControl && hasAuthenticatedUsersRead && !hasUsersExplicit;
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
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    
                    progress?.Report("Desactivando herencia de permisos...");
                    // Desactivar la herencia pero mantener las reglas existentes como reglas explícitas
                    security.SetAccessRuleProtection(true, false); // true = disable inheritance, false = do not preserve inherited rules
                    
                    progress?.Report("Limpiando reglas de permisos existentes...");
                    // Limpiar todas las reglas existentes para tener control total
                    var allRules = security.GetAccessRules(true, true, typeof(IdentityReference));
                    var rulesToRemove = allRules.Cast<AuthorizationRule>().ToList();
                    foreach (FileSystemAccessRule rule in rulesToRemove)
                    {
                        security.RemoveAccessRule(rule);
                    }
                    
                    progress?.Report("Configurando permisos explícitos...");
                    
                    // 1. SYSTEM - Control Total
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                    var systemRule = new FileSystemAccessRule(
                        systemAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.AddAccessRule(systemRule);
                    progress?.Report($"Agregado Control Total para {systemAccount.Value}");
                    
                    // 2. Administradores - Control Total
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var adminRule = new FileSystemAccessRule(
                        adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.AddAccessRule(adminRule);
                    progress?.Report($"Agregado Control Total para {adminsAccount.Value}");
                    
                    // 3. Usuarios autenticados - Solo lectura y ejecución
                    var authUsersAccount = (NTAccount)AUTHENTICATED_USERS_SID.Translate(typeof(NTAccount));
                    var authUsersRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.AddAccessRule(authUsersRule);
                    progress?.Report($"Agregado Lectura/Ejecución para {authUsersAccount.Value}");
                    
                    // NOTA: NO agregamos permisos para el grupo "Usuarios"
                    // Esto significa que los usuarios estándar no tendrán permisos explícitos
                    // pero como también son "Usuarios autenticados", tendrán solo lectura
                    
                    progress?.Report("Aplicando cambios de permisos...");
                    directoryInfo.SetAccessControl(security);
                    
                    progress?.Report("Protección completada exitosamente");
                    return true;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error protegiendo disco {drivePath}: {ex.Message}");
                    Console.WriteLine($"Error protegiendo disco {drivePath}: {ex.Message}");
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
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    
                    progress?.Report("Reactivando herencia de permisos...");
                    // Reactivar la herencia de permisos (esto restaurará los permisos predeterminados)
                    security.SetAccessRuleProtection(false, false); // false = enable inheritance, false = do not preserve existing rules
                    
                    progress?.Report("Aplicando cambios de permisos...");
                    directoryInfo.SetAccessControl(security);
                    
                    progress?.Report("Desprotección completada exitosamente");
                    return true;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error desprotegiendo disco {drivePath}: {ex.Message}");
                    Console.WriteLine($"Error desprotegiendo disco {drivePath}: {ex.Message}");
                    progress?.Report($"Error: {ex.Message}");
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

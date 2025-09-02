#!/bin/bash

echo "=== Corrigiendo acceso de administradores ==="

# Actualizar el servicio de discos para protección correcta solo de usuarios estándar
cat > src/DiskProtectorApp/Services/DiskService.cs << 'SERVICESDISKEOF'
using DiskProtectorApp.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Management;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Threading.Tasks;

namespace DiskProtectorApp.Services
{
    public class DiskService
    {
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

        private bool IsDriveProtected(string drivePath)
        {
            try
            {
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                // Verificar si hay reglas que deniegan acceso a Usuarios
                foreach (FileSystemAccessRule rule in rules)
                {
                    // Verificar tanto Usuarios en español como en inglés
                    if ((rule.IdentityReference.Value.Equals("Usuarios", StringComparison.OrdinalIgnoreCase) ||
                         rule.IdentityReference.Value.Equals("Users", StringComparison.OrdinalIgnoreCase)) &&
                        rule.AccessControlType == AccessControlType.Deny &&
                        (rule.FileSystemRights & FileSystemRights.Modify) == FileSystemRights.Modify)
                    {
                        return true;
                    }
                }

                return false;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
                Console.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
                return false;
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
                    
                    progress?.Report("Verificando grupo de Usuarios...");
                    // Obtener el SID del grupo de Usuarios y traducirlo
                    var usersSid = new SecurityIdentifier(WellKnownSidType.BuiltinUsersSid, null);
                    var usersAccount = usersSid.Translate(typeof(NTAccount));
                    
                    progress?.Report($"Denegando permisos de modificación solo a {usersAccount.Value}...");
                    // Denegar SOLO permisos de modificación a Usuarios (lectura/ejecución permitida)
                    var denyRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.Modify, // Solo denegar modificar (incluye escritura, eliminación, etc.)
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Deny);
                    
                    security.AddAccessRule(denyRule);
                    
                    // Asegurar que los Administradores mantienen control total
                    var adminsSid = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
                    var adminsAccount = adminsSid.Translate(typeof(NTAccount));
                    progress?.Report($"Asegurando control total para {adminsAccount.Value}...");
                    
                    var adminRule = new FileSystemAccessRule(
                        adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    security.SetAccessRule(adminRule);
                    
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
                    var rules = security.GetAccessRules(true, true, typeof(NTAccount));
                    
                    progress?.Report("Buscando reglas de denegación para Usuarios...");
                    // Obtener el SID del grupo de Usuarios
                    var usersSid = new SecurityIdentifier(WellKnownSidType.BuiltinUsersSid, null);
                    var usersAccount = usersSid.Translate(typeof(NTAccount));
                    
                    var rulesToRemove = new List<FileSystemAccessRule>();
                    
                    foreach (FileSystemAccessRule rule in rules)
                    {
                        // Solo remover reglas que deniegan permisos de modificación a Usuarios
                        if (rule.IdentityReference.Value.Equals(usersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                            rule.AccessControlType == AccessControlType.Deny &&
                            (rule.FileSystemRights & FileSystemRights.Modify) == FileSystemRights.Modify)
                        {
                            rulesToRemove.Add(rule);
                        }
                    }
                    
                    progress?.Report($"Removiendo {rulesToRemove.Count} reglas de denegación...");
                    foreach (var rule in rulesToRemove)
                    {
                        security.RemoveAccessRule(rule);
                    }
                    
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
SERVICESDISKEOF

echo "✅ Protección corregida para solo afectar a usuarios estándar"
echo "   Cambios principales:"
echo "   - Protección aplicada solo al grupo 'Usuarios' (Users/BuiltInUsers)"
echo "   - Denegación específica de permisos de modificación (no lectura)"
echo "   - Garantizado control total para el grupo 'Administradores'"
echo "   - Soporte para nombres de grupo en español e inglés"
echo "   - Detección precisa de estado de protección"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/Services/DiskService.cs"
echo "2. git commit -m \"fix: Corregir protección para solo afectar usuarios estándar\""
echo "3. git push origin main"
echo ""
echo "Luego ejecuta './build-and-release.sh' para generar la nueva versión"

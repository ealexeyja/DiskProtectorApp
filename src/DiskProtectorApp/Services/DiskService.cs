using DiskProtectorApp.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Management;
using System.Security.AccessControl;
using System.Security.Principal;

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

                    var disk = new DiskInfo
                    {
                        DriveLetter = drive.Name,
                        VolumeName = drive.VolumeLabel ?? "Sin etiqueta",
                        TotalSize = FormatBytes(drive.TotalSize),
                        FreeSpace = $"{FormatBytes(drive.TotalFreeSpace)} ({(double)drive.TotalFreeSpace / drive.TotalSize * 100:F1}%)",
                        FileSystem = drive.DriveFormat,
                        DiskType = IsSSD(drive.Name) ? "SSD" : "HDD",
                        IsProtected = IsDriveProtected(drive.RootDirectory.FullName),
                        IsSelected = false
                    };

                    // Marcar el disco del sistema
                    if (drive.Name.Equals(systemDrive, StringComparison.OrdinalIgnoreCase))
                    {
                        disk.VolumeName += " (Sistema)";
                        disk.IsSelectable = false;
                        disk.ProtectionStatus = "No Elegible (disco de sistema)";
                    }

                    disks.Add(disk);
                }
                catch (Exception ex)
                {
                    // Loggear errores pero continuar con otros discos
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

                // Verificar si el usuario actual tiene acceso denegado
                var currentUser = WindowsIdentity.GetCurrent().Name;
                foreach (FileSystemAccessRule rule in rules)
                {
                    if (rule.IdentityReference.Value.Equals(currentUser, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Deny &&
                        (rule.FileSystemRights & FileSystemRights.FullControl) == FileSystemRights.FullControl)
                    {
                        return true;
                    }
                }

                return false;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
                return false;
            }
        }

        public bool ProtectDrive(string drivePath)
        {
            try
            {
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                
                // Denegar acceso al usuario actual
                var currentUser = WindowsIdentity.GetCurrent();
                var rule = new FileSystemAccessRule(
                    currentUser.Name,
                    FileSystemRights.FullControl,
                    InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                    PropagationFlags.None,
                    AccessControlType.Deny);
                
                security.AddAccessRule(rule);
                directoryInfo.SetAccessControl(security);
                
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error protegiendo disco {drivePath}: {ex.Message}");
                return false;
            }
        }

        public bool UnprotectDrive(string drivePath)
        {
            try
            {
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));
                
                var currentUser = WindowsIdentity.GetCurrent().Name;
                var rulesToRemove = new List<FileSystemAccessRule>();
                
                foreach (FileSystemAccessRule rule in rules)
                {
                    if (rule.IdentityReference.Value.Equals(currentUser, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Deny &&
                        (rule.FileSystemRights & FileSystemRights.FullControl) == FileSystemRights.FullControl)
                    {
                        rulesToRemove.Add(rule);
                    }
                }
                
                foreach (var rule in rulesToRemove)
                {
                    security.RemoveAccessRule(rule);
                }
                
                directoryInfo.SetAccessControl(security);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error desprotegiendo disco {drivePath}: {ex.Message}");
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

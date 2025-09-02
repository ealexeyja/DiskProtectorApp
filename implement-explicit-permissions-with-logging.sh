#!/bin/bash

echo "=== Implementando enfoque CORRECTO de permisos explícitos CON LOGGING ==="

# Actualizar el servicio de discos con el enfoque correcto y logging detallado
cat > src/DiskProtectorApp/Services/DiskService.cs << 'SERVICESDISKEOF'
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
        /// según nuestro esquema: herencia desactivada y permisos explícitos para SYSTEM/Admins/AuthUsers.
        /// </summary>
        private bool IsDriveProtected(string drivePath)
        {
            try
            {
                var directoryInfo = new DirectoryInfo(drivePath);
                var security = directoryInfo.GetAccessControl();
                var rules = security.GetAccessRules(true, true, typeof(NTAccount));

                // Registrar información de depuración
                System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Verificando protección para: {drivePath}");
                Console.WriteLine($"[PERMISSIONS] Verificando protección para: {drivePath}");
                
                // Verificar si la herencia está desactivada
                bool inheritanceProtected = security.AreAccessRulesProtected;
                System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Herencia protegida: {inheritanceProtected}");
                Console.WriteLine($"[PERMISSIONS] Herencia protegida: {inheritanceProtected}");
                
                if (!inheritanceProtected)
                {
                    System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Herencia NO está desactivada, no está protegido por nosotros");
                    Console.WriteLine($"[PERMISSIONS] Herencia NO está desactivada, no está protegido por nosotros");
                    return false; // Si la herencia está activa, no está protegido por nosotros
                }

                bool hasSystemFullControl = false;
                bool hasAdminsFullControl = false;
                bool hasAuthUsersReadExecute = false;

                foreach (FileSystemAccessRule rule in rules)
                {
                    System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Regla encontrada - Identity: {rule.IdentityReference.Value}, Type: {rule.AccessControlType}, Rights: {rule.FileSystemRights}");
                    Console.WriteLine($"[PERMISSIONS] Regla encontrada - Identity: {rule.IdentityReference.Value}, Type: {rule.AccessControlType}, Rights: {rule.FileSystemRights}");
                    
                    // Verificar permisos explícitos
                    if (rule.AccessControlType == AccessControlType.Allow)
                    {
                        // SYSTEM - Control Total
                        if ((rule.IdentityReference.Value.Equals("SYSTEM", StringComparison.OrdinalIgnoreCase) ||
                             rule.IdentityReference.Value.Equals("SISTEMA", StringComparison.OrdinalIgnoreCase)) &&
                            rule.FileSystemRights == FileSystemRights.FullControl)
                        {
                            hasSystemFullControl = true;
                            System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Encontrada regla SYSTEM FullControl");
                            Console.WriteLine($"[PERMISSIONS] Encontrada regla SYSTEM FullControl");
                        }

                        // Administradores - Control Total
                        if ((rule.IdentityReference.Value.Equals("Administradores", StringComparison.OrdinalIgnoreCase) ||
                             rule.IdentityReference.Value.Equals("Administrators", StringComparison.OrdinalIgnoreCase)) &&
                            rule.FileSystemRights == FileSystemRights.FullControl)
                        {
                            hasAdminsFullControl = true;
                            System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Encontrada regla Administradores FullControl");
                            Console.WriteLine($"[PERMISSIONS] Encontrada regla Administradores FullControl");
                        }

                        // Usuarios autenticados - Solo lectura/ejecución
                        if ((rule.IdentityReference.Value.Equals("Usuarios autenticados", StringComparison.OrdinalIgnoreCase) ||
                             rule.IdentityReference.Value.Equals("Authenticated Users", StringComparison.OrdinalIgnoreCase)) &&
                            (rule.FileSystemRights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory)) == 
                            (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory))
                        {
                            hasAuthUsersReadExecute = true;
                            System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Encontrada regla Usuarios autenticados Read/Execute");
                            Console.WriteLine($"[PERMISSIONS] Encontrada regla Usuarios autenticados Read/Execute");
                        }
                    }
                }

                bool isProtected = hasSystemFullControl && hasAdminsFullControl && hasAuthUsersReadExecute;
                System.Diagnostics.Debug.WriteLine($"[PERMISSIONS] Resultado detección: {isProtected} (SYSTEM: {hasSystemFullControl}, Admins: {hasAdminsFullControl}, AuthUsers: {hasAuthUsersReadExecute})");
                Console.WriteLine($"[PERMISSIONS] Resultado detección: {isProtected} (SYSTEM: {hasSystemFullControl}, Admins: {hasAdminsFullControl}, AuthUsers: {hasAuthUsersReadExecute})");
                
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
                    progress?.Report("Iniciando proceso de protección...");
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Iniciando protección para: {drivePath}");
                    Console.WriteLine($"[PROTECT] Iniciando protección para: {drivePath}");
                    
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    
                    progress?.Report("Verificando estado actual de herencia...");
                    bool wasInheritanceProtected = security.AreAccessRulesProtected;
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Estado actual de herencia protegida: {wasInheritanceProtected}");
                    Console.WriteLine($"[PROTECT] Estado actual de herencia protegida: {wasInheritanceProtected}");
                    
                    progress?.Report("Desactivando herencia de permisos...");
                    // Desactivar la herencia pero mantener las reglas existentes como reglas explícitas
                    security.SetAccessRuleProtection(true, false); // true = disable inheritance, false = do not preserve inherited rules
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Herencia desactivada");
                    Console.WriteLine($"[PROTECT] Herencia desactivada");
                    
                    progress?.Report("Configurando permisos explícitos...");
                    
                    // 1. SYSTEM - Control Total
                    var systemRule = new FileSystemAccessRule(
                        "SYSTEM",
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(systemRule);
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Agregada regla SYSTEM FullControl");
                    Console.WriteLine($"[PROTECT] Agregada regla SYSTEM FullControl");
                    progress?.Report("Agregado Control Total para SYSTEM");
                    
                    // 2. Administradores - Control Total
                    var adminRule = new FileSystemAccessRule(
                        "Administradores", // Usar nombre localizado
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(adminRule);
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Agregada regla Administradores FullControl");
                    Console.WriteLine($"[PROTECT] Agregada regla Administradores FullControl");
                    progress?.Report("Agregado Control Total para Administradores");
                    
                    // 3. Usuarios autenticados - Solo lectura y ejecución
                    var authUsersRule = new FileSystemAccessRule(
                        "Usuarios autenticados", // Usar nombre localizado
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(authUsersRule);
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Agregada regla Usuarios autenticados Read/Execute");
                    Console.WriteLine($"[PROTECT] Agregada regla Usuarios autenticados Read/Execute");
                    progress?.Report("Agregado Lectura/Ejecución para Usuarios autenticados");
                    
                    progress?.Report("Aplicando cambios de permisos...");
                    directoryInfo.SetAccessControl(security);
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Permisos aplicados exitosamente");
                    Console.WriteLine($"[PROTECT] Permisos aplicados exitosamente");
                    
                    progress?.Report("Protección completada exitosamente");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] ERROR DE PERMISOS: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    Console.WriteLine($"[PROTECT] ERROR DE PERMISOS: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    return false;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"[PROTECT] Error protegiendo disco {drivePath}: {ex.Message}");
                    Console.WriteLine($"[PROTECT] Error protegiendo disco {drivePath}: {ex.Message}");
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
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Iniciando desprotección para: {drivePath}");
                    Console.WriteLine($"[UNPROTECT] Iniciando desprotección para: {drivePath}");
                    
                    progress?.Report("Obteniendo información del disco...");
                    var directoryInfo = new DirectoryInfo(drivePath);
                    
                    progress?.Report("Obteniendo permisos actuales...");
                    var security = directoryInfo.GetAccessControl();
                    
                    progress?.Report("Reactivando herencia de permisos...");
                    // Reactivar la herencia de permisos (esto restaurará los permisos predeterminados)
                    security.SetAccessRuleProtection(false, false); // false = enable inheritance, false = do not preserve existing rules
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Herencia reactivada");
                    Console.WriteLine($"[UNPROTECT] Herencia reactivada");
                    
                    progress?.Report("Aplicando cambios de permisos...");
                    directoryInfo.SetAccessControl(security);
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Permisos aplicados exitosamente");
                    Console.WriteLine($"[UNPROTECT] Permisos aplicados exitosamente");
                    
                    progress?.Report("Desprotección completada exitosamente");
                    return true;
                }
                catch (UnauthorizedAccessException authEx)
                {
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] ERROR DE PERMISOS: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    Console.WriteLine($"[UNPROTECT] ERROR DE PERMISOS: No se puede modificar los permisos de {drivePath}: {authEx.Message}");
                    progress?.Report($"Error de permisos: {authEx.Message}");
                    return false;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"[UNPROTECT] Error desprotegiendo disco {drivePath}: {ex.Message}");
                    Console.WriteLine($"[UNPROTECT] Error desprotegiendo disco {drivePath}: {ex.Message}");
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

echo "✅ Enfoque CORRECTO de permisos explícitos implementado CON LOGGING DETALLADO"
echo "   Cambios principales:"
echo "   - Desactivar herencia en lugar de usar Deny"
echo "   - Establecer permisos explícitos para SYSTEM, Administradores y Usuarios autenticados"
echo "   - NO usar Deny para el grupo Usuarios"
echo "   - Detección basada en esquema de permisos explícitos + herencia desactivada"
echo "   - AGREGADO LOGGING DETALLADO en cada paso del proceso"
echo "   - Manejo específico de errores de permisos (UnauthorizedAccessException)"
echo "   - Garantizado acceso completo para administradores"
echo ""
echo "Logging implementado:"
echo "   - [PERMISSIONS] Para verificación de estado de protección"
echo "   - [PROTECT] Para proceso de protección"
echo "   - [UNPROTECT] Para proceso de desprotección"
echo "   - Registro de cada regla de permiso encontrada/aplicada"
echo "   - Registro de errores específicos (incluyendo UnauthorizedAccessException)"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/Services/DiskService.cs"
echo "2. git commit -m \"fix: Implementar enfoque correcto de permisos explícitos con logging\""
echo "3. git push origin main"
echo ""
echo "Luego ejecuta './build-and-release.sh' para generar la nueva versión"
echo ""
echo "Para diagnosticar problemas:"
echo "1. Ejecuta la aplicación y observa los logs en tiempo real"
echo "2. Revisa %APPDATA%\\DiskProtectorApp\\app-debug.log"
echo "3. Revisa %APPDATA%\\DiskProtectorApp\\operations.log"
echo "4. Busca mensajes específicos con prefijos [PERMISSIONS], [PROTECT], [UNPROTECT]"

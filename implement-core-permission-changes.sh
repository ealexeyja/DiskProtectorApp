#!/bin/bash

echo "=== Implementando cambios principales en la lógica de permisos ==="

# Actualizar el modelo de datos para mejor manejo de propiedades
cat > src/DiskProtectorApp/Models/DiskInfo.cs << 'MODELEOF'
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace DiskProtectorApp.Models
{
    public class DiskInfo : INotifyPropertyChanged
    {
        private bool _isSelected;
        private bool _isSelectable = true;
        private string? _driveLetter;
        private string? _volumeName;
        private string? _totalSize;
        private string? _freeSpace;
        private string? _fileSystem;
        private string? _diskType;
        private string? _protectionStatus;
        private bool _isProtected;
        private bool _isSystemDisk = false;

        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                if (_isSelectable && _isSelected != value)
                {
                    _isSelected = value;
                    OnPropertyChanged();
                }
            }
        }

        public bool IsSelectable
        {
            get => _isSelectable;
            set
            {
                _isSelectable = value;
                OnPropertyChanged();
                // Si no es seleccionable, deseleccionar
                if (!value && _isSelected)
                {
                    IsSelected = false;
                }
            }
        }

        public bool IsSystemDisk
        {
            get => _isSystemDisk;
            set
            {
                _isSystemDisk = value;
                OnPropertyChanged();
            }
        }

        public string? DriveLetter
        {
            get => _driveLetter;
            set
            {
                _driveLetter = value;
                OnPropertyChanged();
            }
        }

        public string? VolumeName
        {
            get => _volumeName;
            set
            {
                _volumeName = value;
                OnPropertyChanged();
            }
        }

        public string? TotalSize
        {
            get => _totalSize;
            set
            {
                _totalSize = value;
                OnPropertyChanged();
            }
        }

        public string? FreeSpace
        {
            get => _freeSpace;
            set
            {
                _freeSpace = value;
                OnPropertyChanged();
            }
        }

        public string? FileSystem
        {
            get => _fileSystem;
            set
            {
                _fileSystem = value;
                OnPropertyChanged();
            }
        }

        public string? DiskType
        {
            get => _diskType;
            set
            {
                _diskType = value;
                OnPropertyChanged();
            }
        }

        public string? ProtectionStatus
        {
            get => _protectionStatus;
            set
            {
                _protectionStatus = value;
                OnPropertyChanged();
            }
        }

        public bool IsProtected
        {
            get => _isProtected;
            set
            {
                _isProtected = value;
                ProtectionStatus = value ? "Protegido" : "Desprotegido";
                OnPropertyChanged();
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
MODELEOF

# Actualizar el servicio de discos con la lógica CORRECTA de permisos
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
            }

            return false;
        }

        /// <summary>
        /// Detecta si un disco está protegido según la definición EXACTA:
        /// 
        /// DISCO DESPROTEGIDO (NORMAL):
        /// - Grupo "Usuarios" tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
        /// - Grupo "Usuarios autenticados" tiene permisos de modificación/escritura
        /// - Grupo "Administradores" y "SYSTEM" tienen Control Total (siempre)
        /// 
        /// DISCO PROTEGIDO:
        /// - Grupo "Usuarios" NO tiene permisos establecidos
        /// - Grupo "Usuarios autenticados" solo tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
        /// - Grupo "Administradores" y "SYSTEM" mantienen Control Total (siempre)
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
                        if ((rights & (FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read)) != 0)
                        {
                            usersHasBasicPermissions = true;
                        }
                    }
                    
                    // Verificar permisos de Usuarios autenticados (modificación/escritura)
                    if (rule.IdentityReference.Value.Equals(authUsersAccount.Value, StringComparison.OrdinalIgnoreCase) &&
                        rule.AccessControlType == AccessControlType.Allow)
                    {
                        var rights = rule.FileSystemRights;
                        // Verificar si tiene permisos de modificación o escritura
                        if ((rights & (FileSystemRights.Modify | FileSystemRights.Write)) != 0)
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
                // - Usuarios SIN permisos básicos O AuthUsers SIN modificación/escritura
                //
                bool isUnprotected = usersHasBasicPermissions && authUsersHasModifyWritePermissions;
                bool isProtected = !isUnprotected;
                
                return isProtected;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error verificando protección de {drivePath}: {ex.Message}");
                return false;
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
                    
                    // QUITAR permisos específicos (NO usar Deny):
                    // QUITAR permisos básicos de lectura a Usuarios
                    var usersBasicRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    security.RemoveAccessRule(usersBasicRule);
                    
                    // QUITAR permisos de modificación/escritura a Usuarios autenticados
                    var authUsersModifyWriteRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    security.RemoveAccessRule(authUsersModifyWriteRule);
                    
                    // Asegurar que Admins y SYSTEM mantienen control total
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                    
                    var adminsRule = new FileSystemAccessRule(
                        adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(adminsRule);
                    
                    var systemRule = new FileSystemAccessRule(
                        systemAccount,
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
                    // RESTAURAR permisos básicos de lectura a Usuarios
                    var usersBasicRule = new FileSystemAccessRule(
                        usersAccount,
                        FileSystemRights.ReadAndExecute | FileSystemRights.ListDirectory | FileSystemRights.Read,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    security.SetAccessRule(usersBasicRule);
                    
                    // RESTAURAR permisos de modificación/escritura a Usuarios autenticados
                    var authUsersModifyWriteRule = new FileSystemAccessRule(
                        authUsersAccount,
                        FileSystemRights.Modify | FileSystemRights.Write,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    
                    security.SetAccessRule(authUsersModifyWriteRule);
                    
                    // Asegurar que Admins y SYSTEM mantienen control total
                    var adminsAccount = (NTAccount)BUILTIN_ADMINS_SID.Translate(typeof(NTAccount));
                    var systemAccount = (NTAccount)LOCAL_SYSTEM_SID.Translate(typeof(NTAccount));
                    
                    var adminsRule = new FileSystemAccessRule(
                        adminsAccount,
                        FileSystemRights.FullControl,
                        InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
                        PropagationFlags.None,
                        AccessControlType.Allow);
                    security.SetAccessRule(adminsRule);
                    
                    var systemRule = new FileSystemAccessRule(
                        systemAccount,
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
                bool isAdmin = principal.IsInRole(WindowsBuiltInRole.Administrator);
                return isAdmin;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error verificando permisos de administrador: {ex.Message}");
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
SERVICESDISKEOF

# Actualizar el ViewModel para corregir activación de botones
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'VIEWMODELEOF'
using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;

namespace DiskProtectorApp.ViewModels
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private readonly DiskService _diskService;
        private readonly OperationLogger _logger;
        private ObservableCollection<DiskInfo> _disks = new();
        private string _statusMessage = "Listo";
        private bool _isWorking;

        public ObservableCollection<DiskInfo> Disks
        {
            get => _disks;
            set
            {
                _disks = value ?? new ObservableCollection<DiskInfo>();
                OnPropertyChanged();
                UpdateCommandStates();
            }
        }

        public string StatusMessage
        {
            get => _statusMessage;
            set
            {
                _statusMessage = value ?? string.Empty;
                OnPropertyChanged();
            }
        }

        public bool IsWorking
        {
            get => _isWorking;
            set
            {
                _isWorking = value;
                OnPropertyChanged();
                UpdateCommandStates();
            }
        }

        public ICommand ProtectCommand { get; }
        public ICommand UnprotectCommand { get; }
        public ICommand RefreshCommand { get; }

        public MainViewModel()
        {
            _diskService = new DiskService();
            _logger = new OperationLogger();
            
            ProtectCommand = new RelayCommand(async (parameter) => await ExecuteProtectDisksAsync(), CanPerformProtectOperation);
            UnprotectCommand = new RelayCommand(async (parameter) => await ExecuteUnprotectDisksAsync(), CanPerformUnprotectOperation);
            RefreshCommand = new RelayCommand(ExecuteRefreshDisks);
            
            RefreshDisks();
        }

        private void UpdateCommandStates()
        {
            CommandManager.InvalidateRequerySuggested();
        }

        private bool CanPerformProtectOperation(object? parameter)
        {
            bool canProtect = !IsWorking && Disks.Any(d => d.IsSelected && d.IsSelectable && !d.IsProtected);
            return canProtect;
        }

        private bool CanPerformUnprotectOperation(object? parameter)
        {
            bool canUnprotect = !IsWorking && Disks.Any(d => d.IsSelected && d.IsSelectable && d.IsProtected);
            return canUnprotect;
        }

        private void ExecuteRefreshDisks(object? parameter)
        {
            RefreshDisks();
        }

        private void RefreshDisks()
        {
            IsWorking = true;
            StatusMessage = "Actualizando lista de discos...";
            
            var disks = _diskService.GetDisks();
            Disks.Clear();
            
            foreach (var disk in disks)
            {
                Disks.Add(disk);
            }
            
            StatusMessage = $"Se encontraron {disks.Count} discos";
            IsWorking = false;
            
            UpdateCommandStates();
        }

        private async Task ExecuteProtectDisksAsync()
        {
            var selectedDisks = Disks?.Where(d => d.IsSelected && d.IsSelectable && !d.IsProtected).ToList() ?? new List<DiskInfo>();
            if (!selectedDisks.Any()) return;

            IsWorking = true;
            StatusMessage = $"Protegiendo {selectedDisks.Count} disco(s)...";

            int successCount = 0;
            
            foreach (var disk in selectedDisks)
            {
                var progress = new Progress<string>(message => {
                    StatusMessage = message;
                });
                
                bool success = await _diskService.ProtectDriveAsync(disk.DriveLetter ?? "", progress);
                if (success)
                {
                    // ACTUALIZAR EL ESTADO INMEDIATAMENTE DESPUÉS DE LA OPERACIÓN
                    disk.IsProtected = true;
                    successCount++;
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", true);
                }
                else
                {
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                }
            }

            StatusMessage = $"Protegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // ACTUALIZAR INMEDIATAMENTE LOS ESTADOS DE LOS COMANDOS
            UpdateCommandStates();
        }

        private async Task ExecuteUnprotectDisksAsync()
        {
            var selectedDisks = Disks?.Where(d => d.IsSelected && d.IsSelectable && d.IsProtected).ToList() ?? new List<DiskInfo>();
            if (!selectedDisks.Any()) return;

            IsWorking = true;
            StatusMessage = $"Desprotegiendo {selectedDisks.Count} disco(s)...";

            int successCount = 0;
            foreach (var disk in selectedDisks)
            {
                var progress = new Progress<string>(message => {
                    StatusMessage = message;
                });
                
                bool success = await _diskService.UnprotectDriveAsync(disk.DriveLetter ?? "", progress);
                if (success)
                {
                    // ACTUALIZAR EL ESTADO INMEDIATAMENTE DESPUÉS DE LA OPERACIÓN
                    disk.IsProtected = false;
                    successCount++;
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", true);
                }
                else
                {
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                }
            }

            StatusMessage = $"Desprotegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // ACTUALIZAR INMEDIATAMENTE LOS ESTADOS DE LOS COMANDOS
            UpdateCommandStates();
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
VIEWMODELEOF

echo "✅ Cambios principales implementados en el proyecto"
echo "   Cambios realizados:"
echo "   - Corregida la estructura de archivos para .NET (todos en mismo directorio)"
echo "   - Actualizado DiskInfo.cs con mejor manejo de propiedades"
echo "   - Corregido DiskService.cs con lógica EXACTA de permisos:"
echo "     * Protegido: Usuarios SIN permisos básicos O AuthUsers SIN modificación/escritura"
echo "     * Desprotegido: Usuarios CON permisos básicos Y AuthUsers CON modificación/escritura"
echo "   - Mejorado MainViewModel.cs con activación correcta de botones"
echo "   - Asegurado que Admins/SYSTEM mantengan Control Total siempre"
echo "   - Implementado QUITAR/RESTAURAR permisos en lugar de usar Deny"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/Models/DiskInfo.cs"
echo "2. git add src/DiskProtectorApp/Services/DiskService.cs"
echo "3. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "4. git commit -m \"fix: Corregir lógica de permisos y activación de botones\""
echo "5. git push origin main"
echo ""
echo "Luego ejecuta './build-and-test.sh' para compilar y probar"

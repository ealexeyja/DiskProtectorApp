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
                System.Diagnostics.Debug.WriteLine($"[DISK MODEL] Setting IsSelected for {DriveLetter}: {value}");
                System.Console.WriteLine($"[DISK MODEL] Setting IsSelected for {DriveLetter}: {value}");
                
                if (_isSelectable && _isSelected != value)
                {
                    _isSelected = value;
                    System.Diagnostics.Debug.WriteLine($"[DISK MODEL] IsSelected CHANGED for {DriveLetter}: {value}");
                    System.Console.WriteLine($"[DISK MODEL] IsSelected CHANGED for {DriveLetter}: {value}");
                    OnPropertyChanged();
                }
                else
                {
                    System.Diagnostics.Debug.WriteLine($"[DISK MODEL] IsSelected NOT CHANGED for {DriveLetter}: old={_isSelected}, new={value}, selectable={_isSelectable}");
                    System.Console.WriteLine($"[DISK MODEL] IsSelected NOT CHANGED for {DriveLetter}: old={_isSelected}, new={value}, selectable={_isSelectable}");
                }
            }
        }

        public bool IsSelectable
        {
            get => _isSelectable;
            set
            {
                System.Diagnostics.Debug.WriteLine($"[DISK MODEL] Setting IsSelectable for {DriveLetter}: {value}");
                System.Console.WriteLine($"[DISK MODEL] Setting IsSelectable for {DriveLetter}: {value}");
                
                _isSelectable = value;
                OnPropertyChanged();
                
                // Si no es seleccionable, deseleccionar
                if (!value && _isSelected)
                {
                    System.Diagnostics.Debug.WriteLine($"[DISK MODEL] Deselecting non-selectable disk {DriveLetter}");
                    System.Console.WriteLine($"[DISK MODEL] Deselecting non-selectable disk {DriveLetter}");
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
                ProtectionStatus = value ? "Protegido" : (_isSystemDisk ? "No Elegible" : "Desprotegido");
                OnPropertyChanged();
                System.Diagnostics.Debug.WriteLine($"[DISK MODEL] IsProtected changed for {DriveLetter}: {value}");
                System.Console.WriteLine($"[DISK MODEL] IsProtected changed for {DriveLetter}: {value}");
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            System.Diagnostics.Debug.WriteLine($"[DISK MODEL] Property changed: {propertyName} on disk {DriveLetter}");
            System.Console.WriteLine($"[DISK MODEL] Property changed: {propertyName} on disk {DriveLetter}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}

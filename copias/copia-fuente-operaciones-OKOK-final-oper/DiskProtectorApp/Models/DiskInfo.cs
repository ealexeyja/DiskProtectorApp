using DiskProtectorApp.Logging;
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
        private string? _protectionStatus;
        private bool _isProtected;
        private bool _isManageable = true;
        private bool _isSystemDisk = false;

        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                if (_isSelectable && _isSelected != value)
                {
                    AppLogger.LogViewModel($"Disk {DriveLetter} IsSelected changed from {_isSelected} to {value}");
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
                if (_isSelectable != value)
                {
                    AppLogger.LogViewModel($"Disk {DriveLetter} IsSelectable changed from {_isSelectable} to {value}");
                    _isSelectable = value;
                    OnPropertyChanged();
                    // Si no es seleccionable, deseleccionar
                    if (!_isSelectable && _isSelected)
                    {
                        IsSelected = false;
                    }
                }
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
                if (_isProtected != value)
                {
                    AppLogger.LogViewModel($"Disk {DriveLetter} IsProtected changed from {_isProtected} to {value}");
                    _isProtected = value;
                    OnPropertyChanged();
                }
            }
        }

        public bool IsManageable
        {
            get => _isManageable;
            set
            {
                if (_isManageable != value)
                {
                    AppLogger.LogViewModel($"Disk {DriveLetter} IsManageable changed from {_isManageable} to {value}");
                    _isManageable = value;
                    OnPropertyChanged();
                }
            }
        }

        public bool IsSystemDisk
        {
            get => _isSystemDisk;
            set
            {
                if (_isSystemDisk != value)
                {
                    AppLogger.LogViewModel($"Disk {DriveLetter} IsSystemDisk changed from {_isSystemDisk} to {value}");
                    _isSystemDisk = value;
                    OnPropertyChanged();
                    // Si es disco del sistema, no es seleccionable
                    if (_isSystemDisk)
                    {
                        IsSelectable = false;
                    }
                }
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}

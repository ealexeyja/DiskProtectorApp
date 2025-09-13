using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace DiskProtectorApp.Models
{
    public class DiskInfo : INotifyPropertyChanged
    {
        private bool _isSelected;
        private string _driveLetter = string.Empty;
        private string _volumeName = string.Empty;
        private string _totalSize = string.Empty;
        private string _freeSpace = string.Empty;
        private bool _isProtected;
        private string _protectionStatus = "Desconocido";
        private bool _isManageable = true;
        private bool _isEligible = true;
        private bool _isSystemDisk = false;
        private bool _isSelectable = true;

        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                if (_isSelectable && _isSelected != value)
                {
                    _isSelected = value;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(IsSelectable)); // Notificar cambio en IsSelectable también
                }
            }
        }

        public string DriveLetter
        {
            get => _driveLetter;
            set
            {
                _driveLetter = value;
                OnPropertyChanged();
            }
        }

        public string VolumeName
        {
            get => _volumeName;
            set
            {
                _volumeName = value;
                OnPropertyChanged();
            }
        }

        public string TotalSize
        {
            get => _totalSize;
            set
            {
                _totalSize = value;
                OnPropertyChanged();
            }
        }

        public string FreeSpace
        {
            get => _freeSpace;
            set
            {
                _freeSpace = value;
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
                    _isProtected = value;
                    ProtectionStatus = value ? "Protegido" : "Desprotegido";
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(IsSelectable)); // Notificar cambio en IsSelectable también
                }
            }
        }

        public string ProtectionStatus
        {
            get => _protectionStatus;
            set
            {
                _protectionStatus = value;
                OnPropertyChanged();
            }
        }

        public bool IsManageable
        {
            get => _isManageable;
            set
            {
                if (_isManageable != value)
                {
                    _isManageable = value;
                    IsSelectable = value && _isEligible && !_isSystemDisk;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(IsSelectable)); // Notificar cambio en IsSelectable también
                }
            }
        }

        public bool IsEligible
        {
            get => _isEligible;
            set
            {
                if (_isEligible != value)
                {
                    _isEligible = value;
                    IsSelectable = value && _isManageable && !_isSystemDisk;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(IsSelectable)); // Notificar cambio en IsSelectable también
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
                    _isSystemDisk = value;
                    IsSelectable = !value && _isManageable && _isEligible;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(IsSelectable)); // Notificar cambio en IsSelectable también
                }
            }
        }

        public bool IsSelectable
        {
            get => _isSelectable;
            set
            {
                _isSelectable = value;
                if (!value)
                {
                    _isSelected = false;
                    OnPropertyChanged(nameof(IsSelected));
                }
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

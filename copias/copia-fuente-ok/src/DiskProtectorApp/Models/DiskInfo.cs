using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace DiskProtectorApp.Models
{
    public class DiskInfo : INotifyPropertyChanged
    {
        private string _name = string.Empty;
        private string _volumeName = string.Empty;
        private long _totalSize;
        private long _freeSpace;
        private bool _isSelected;
        private bool _isProtected;
        private string _protectionStatus = "Desconocido";
        private bool _isManageable = true;
        private bool _isEligible = true;
        private bool _isSystemDisk = false;
        private bool _isSelectable = true;

        public string Name
        {
            get => _name;
            set
            {
                _name = value;
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

        public long TotalSize
        {
            get => _totalSize;
            set
            {
                _totalSize = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(FormattedTotalSize));
                OnPropertyChanged(nameof(UsagePercentage));
            }
        }

        public long FreeSpace
        {
            get => _freeSpace;
            set
            {
                _freeSpace = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(FormattedFreeSpace));
                OnPropertyChanged(nameof(UsagePercentage));
            }
        }

        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                if (_isEligible && _isManageable && !_isSystemDisk)
                {
                    _isSelected = value;
                    OnPropertyChanged();
                }
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
                _isManageable = value;
                IsSelectable = value && _isEligible && !_isSystemDisk;
                OnPropertyChanged();
            }
        }

        public bool IsEligible
        {
            get => _isEligible;
            set
            {
                _isEligible = value;
                IsSelectable = value && _isManageable && !_isSystemDisk;
                OnPropertyChanged();
            }
        }

        public bool IsSystemDisk
        {
            get => _isSystemDisk;
            set
            {
                _isSystemDisk = value;
                IsSelectable = !value && _isManageable && _isEligible;
                OnPropertyChanged();
            }
        }

        public bool IsSelectable
        {
            get => _isSelectable;
            private set
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

        public string FormattedTotalSize => FormatBytes(TotalSize);
        public string FormattedFreeSpace => FormatBytes(FreeSpace);
        public double UsagePercentage => TotalSize > 0 ? ((double)(TotalSize - FreeSpace) / TotalSize) * 100 : 0;

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

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}

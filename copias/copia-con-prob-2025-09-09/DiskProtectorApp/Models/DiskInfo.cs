using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace DiskProtectorApp.Models
{
    public class DiskInfo : INotifyPropertyChanged
    {
        private bool _isSelected;
        private bool _isProtected;
        private bool _isManageable;

        public string DriveLetter { get; set; }
        public string VolumeName { get; set; }
        public string TotalSize { get; set; }
        public string FreeSpace { get; set; }
        public bool IsSystemDisk { get; set; }
        public bool IsSelectable { get; set; } // El disco del sistema no es seleccionable

        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                _isSelected = value;
                OnPropertyChanged();
            }
        }

        public bool IsProtected
        {
            get => _isProtected;
            set
            {
                _isProtected = value;
                OnPropertyChanged();
            }
        }

        public bool IsManageable
        {
            get => _isManageable;
            set
            {
                _isManageable = value;
                OnPropertyChanged();
            }
        }

        public event PropertyChangedEventHandler PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}

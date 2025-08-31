using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
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
                // Desuscribirse de los eventos de los discos anteriores
                if (_disks != null)
                {
                    foreach (var disk in _disks)
                    {
                        disk.PropertyChanged -= OnDiskPropertyChanged;
                    }
                }
                
                _disks = value;
                
                // Suscribirse a los eventos de los nuevos discos
                if (_disks != null)
                {
                    foreach (var disk in _disks)
                    {
                        disk.PropertyChanged += OnDiskPropertyChanged;
                    }
                }
                
                OnPropertyChanged();
                UpdateCommandStates();
            }
        }

        public string StatusMessage
        {
            get => _statusMessage;
            set
            {
                _statusMessage = value;
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
            
            ProtectCommand = new RelayCommand(ProtectSelectedDisks, CanPerformProtectOperation);
            UnprotectCommand = new RelayCommand(UnprotectSelectedDisks, CanPerformUnprotectOperation);
            RefreshCommand = new RelayCommand(ExecuteRefreshDisks);
            
            RefreshDisks();
        }

        private void OnDiskPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(DiskInfo.IsSelected) || 
                e.PropertyName == nameof(DiskInfo.IsProtected))
            {
                UpdateCommandStates();
            }
        }

        private void UpdateCommandStates()
        {
            // Forzar actualización de comandos
            var protectCommand = ProtectCommand as RelayCommand;
            var unprotectCommand = UnprotectCommand as RelayCommand;
            
            protectCommand?.RaiseCanExecuteChanged();
            unprotectCommand?.RaiseCanExecuteChanged();
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
            
            // Desuscribirse de los eventos de los discos anteriores
            foreach (var disk in _disks)
            {
                disk.PropertyChanged -= OnDiskPropertyChanged;
            }
            
            Disks.Clear();
            
            foreach (var disk in disks)
            {
                Disks.Add(disk);
                // Suscribirse al cambio de propiedad para actualizar comandos
                disk.PropertyChanged += OnDiskPropertyChanged;
            }
            
            StatusMessage = $"Se encontraron {disks.Count} discos";
            IsWorking = false;
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private bool CanPerformProtectOperation(object? parameter)
        {
            bool canProtect = !IsWorking && Disks.Any(d => d.IsSelected && d.IsSelectable && !d.IsProtected);
            System.Diagnostics.Debug.WriteLine($"CanProtect: {canProtect}, IsWorking: {IsWorking}, SelectedCount: {Disks.Count(d => d.IsSelected && d.IsSelectable && !d.IsProtected)}");
            return canProtect;
        }

        private bool CanPerformUnprotectOperation(object? parameter)
        {
            bool canUnprotect = !IsWorking && Disks.Any(d => d.IsSelected && d.IsSelectable && d.IsProtected);
            System.Diagnostics.Debug.WriteLine($"CanUnprotect: {canUnprotect}, IsWorking: {IsWorking}, SelectedCount: {Disks.Count(d => d.IsSelected && d.IsSelectable && d.IsProtected)}");
            return canUnprotect;
        }

        private void ProtectSelectedDisks(object? parameter)
        {
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable && !d.IsProtected).ToList();
            if (!selectedDisks.Any()) return;

            IsWorking = true;
            StatusMessage = $"Protegiendo {selectedDisks.Count} disco(s)...";

            int successCount = 0;
            
            foreach (var disk in selectedDisks)
            {
                bool success = _diskService.ProtectDrive(disk.DriveLetter ?? "");
                if (success)
                {
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
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private void UnprotectSelectedDisks(object? parameter)
        {
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable && d.IsProtected).ToList();
            if (!selectedDisks.Any()) return;

            IsWorking = true;
            StatusMessage = $"Desprotegiendo {selectedDisks.Count} disco(s)...";

            int successCount = 0;
            foreach (var disk in selectedDisks)
            {
                bool success = _diskService.UnprotectDrive(disk.DriveLetter ?? "");
                if (success)
                {
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
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}

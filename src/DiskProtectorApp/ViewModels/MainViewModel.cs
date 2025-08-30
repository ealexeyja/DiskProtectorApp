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
                _disks = value;
                OnPropertyChanged();
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
                // Notificar que los comandos pueden haber cambiado
                ((RelayCommand)ProtectCommand).RaiseCanExecuteChanged();
                ((RelayCommand)UnprotectCommand).RaiseCanExecuteChanged();
            }
        }

        public ICommand ProtectCommand { get; }
        public ICommand UnprotectCommand { get; }
        public ICommand RefreshCommand { get; }

        public MainViewModel()
        {
            _diskService = new DiskService();
            _logger = new OperationLogger();
            
            ProtectCommand = new RelayCommand(ProtectSelectedDisks, CanPerformOperation);
            UnprotectCommand = new RelayCommand(UnprotectSelectedDisks, CanPerformOperation);
            RefreshCommand = new RelayCommand(ExecuteRefreshDisks);
            
            RefreshDisks();
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
                // Suscribirse al cambio de propiedad para actualizar comandos
                disk.PropertyChanged += (sender, e) => {
                    if (e.PropertyName == nameof(DiskInfo.IsSelected))
                    {
                        ((RelayCommand)ProtectCommand).RaiseCanExecuteChanged();
                        ((RelayCommand)UnprotectCommand).RaiseCanExecuteChanged();
                    }
                };
            }
            
            StatusMessage = $"Se encontraron {disks.Count} discos";
            IsWorking = false;
            
            // Notificar que los comandos pueden haber cambiado
            ((RelayCommand)ProtectCommand).RaiseCanExecuteChanged();
            ((RelayCommand)UnprotectCommand).RaiseCanExecuteChanged();
        }

        private bool CanPerformOperation(object? parameter)
        {
            return !IsWorking && Disks.Any(d => d.IsSelected && d.IsSelectable);
        }

        private void ProtectSelectedDisks(object? parameter)
        {
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable).ToList();
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
            
            // Notificar que los comandos pueden haber cambiado
            ((RelayCommand)ProtectCommand).RaiseCanExecuteChanged();
            ((RelayCommand)UnprotectCommand).RaiseCanExecuteChanged();
        }

        private void UnprotectSelectedDisks(object? parameter)
        {
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable).ToList();
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
            
            // Notificar que los comandos pueden haber cambiado
            ((RelayCommand)ProtectCommand).RaiseCanExecuteChanged();
            ((RelayCommand)UnprotectCommand).RaiseCanExecuteChanged();
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}

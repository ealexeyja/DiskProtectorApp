using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using DiskProtectorApp.Views;
using System;
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
            
            ProtectCommand = new RelayCommand(async (parameter) => await ProtectSelectedDisksAsync(), CanAlwaysExecute);
            UnprotectCommand = new RelayCommand(async (parameter) => await UnprotectSelectedDisksAsync(), CanAlwaysExecute);
            RefreshCommand = new RelayCommand(ExecuteRefreshDisks);
            
            System.Diagnostics.Debug.WriteLine("MainViewModel initialized");
            RefreshDisks();
        }

        private void OnDiskPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(DiskInfo.IsSelected) || 
                e.PropertyName == nameof(DiskInfo.IsProtected))
            {
                var disk = sender as DiskInfo;
                System.Diagnostics.Debug.WriteLine($"Disk property changed: {disk?.DriveLetter} - {e.PropertyName}");
                
                // Usar Dispatcher para asegurar que la actualización ocurra en el hilo UI
                if (System.Windows.Application.Current?.Dispatcher != null)
                {
                    System.Windows.Application.Current.Dispatcher.Invoke(() => {
                        UpdateCommandStates();
                    });
                }
                else
                {
                    UpdateCommandStates();
                }
            }
        }

        private void UpdateCommandStates()
        {
            System.Diagnostics.Debug.WriteLine("Updating command states");
            
            // Forzar actualización de comandos
            CommandManager.InvalidateRequerySuggested();
        }

        private bool CanAlwaysExecute(object? parameter)
        {
            // Siempre retornar true para que los botones estén activos
            bool canExecute = !IsWorking;
            System.Diagnostics.Debug.WriteLine($"CanExecute check: IsWorking={IsWorking}, Result={canExecute}");
            return canExecute;
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

        private async Task ProtectSelectedDisksAsync()
        {
            // Obtener todos los discos seleccionados, independientemente de su estado
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable).ToList();
            if (!selectedDisks.Any()) return;

            System.Diagnostics.Debug.WriteLine($"Protecting {selectedDisks.Count} disks");
            
            IsWorking = true;
            StatusMessage = $"Protegiendo {selectedDisks.Count} disco(s)...";

            // Crear y mostrar ventana de progreso
            var progressDialog = new ProgressDialog();
            progressDialog.UpdateProgress("Protegiendo discos", $"Procesando 0 de {selectedDisks.Count} discos...");
            
            var mainWindow = Application.Current.MainWindow;
            if (mainWindow != null)
            {
                progressDialog.Owner = mainWindow;
            }
            
            progressDialog.Show();

            int successCount = 0;
            int currentDisk = 0;
            
            foreach (var disk in selectedDisks)
            {
                currentDisk++;
                progressDialog.UpdateProgress($"Protegiendo disco {disk.DriveLetter}", $"Procesando {currentDisk} de {selectedDisks.Count} discos...");
                
                var progress = new Progress<string>(message => {
                    progressDialog.UpdateProgress($"Protegiendo disco {disk.DriveLetter}", message);
                });
                
                bool success = await _diskService.ProtectDriveAsync(disk.DriveLetter ?? "", progress);
                if (success)
                {
                    disk.IsProtected = true;
                    successCount++;
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", true);
                    System.Diagnostics.Debug.WriteLine($"Successfully protected disk {disk.DriveLetter}");
                }
                else
                {
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                    System.Diagnostics.Debug.WriteLine($"Failed to protect disk {disk.DriveLetter}");
                }
            }

            progressDialog.Close();
            
            StatusMessage = $"Protegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // Mostrar mensaje de resultado
            string resultMessage = $"Protección completada.\n\nDiscos protegidos: {successCount}\nDiscos con error: {selectedDisks.Count - successCount}";
            MessageBox.Show(resultMessage, "Protección de discos", MessageBoxButton.OK, MessageBoxImage.Information);
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private async Task UnprotectSelectedDisksAsync()
        {
            // Obtener todos los discos seleccionados, independientemente de su estado
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable).ToList();
            if (!selectedDisks.Any()) return;

            System.Diagnostics.Debug.WriteLine($"Unprotecting {selectedDisks.Count} disks");
            
            IsWorking = true;
            StatusMessage = $"Desprotegiendo {selectedDisks.Count} disco(s)...";

            // Crear y mostrar ventana de progreso
            var progressDialog = new ProgressDialog();
            progressDialog.UpdateProgress("Desprotegiendo discos", $"Procesando 0 de {selectedDisks.Count} discos...");
            
            var mainWindow = Application.Current.MainWindow;
            if (mainWindow != null)
            {
                progressDialog.Owner = mainWindow;
            }
            
            progressDialog.Show();

            int successCount = 0;
            int currentDisk = 0;
            
            foreach (var disk in selectedDisks)
            {
                currentDisk++;
                progressDialog.UpdateProgress($"Desprotegiendo disco {disk.DriveLetter}", $"Procesando {currentDisk} de {selectedDisks.Count} discos...");
                
                var progress = new Progress<string>(message => {
                    progressDialog.UpdateProgress($"Desprotegiendo disco {disk.DriveLetter}", message);
                });
                
                bool success = await _diskService.UnprotectDriveAsync(disk.DriveLetter ?? "", progress);
                if (success)
                {
                    disk.IsProtected = false;
                    successCount++;
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", true);
                    System.Diagnostics.Debug.WriteLine($"Successfully unprotected disk {disk.DriveLetter}");
                }
                else
                {
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                    System.Diagnostics.Debug.WriteLine($"Failed to unprotect disk {disk.DriveLetter}");
                }
            }

            progressDialog.Close();
            
            StatusMessage = $"Desprotegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // Mostrar mensaje de resultado
            string resultMessage = $"Desprotección completada.\n\nDiscos desprotegidos: {successCount}\nDiscos con error: {selectedDisks.Count - successCount}";
            MessageBox.Show(resultMessage, "Desprotección de discos", MessageBoxButton.OK, MessageBoxImage.Information);
            
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

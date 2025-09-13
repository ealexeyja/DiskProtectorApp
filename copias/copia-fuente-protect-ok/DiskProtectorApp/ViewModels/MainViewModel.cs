using DiskProtectorApp.Logging;
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
        private ObservableCollection<DiskInfo> _disks = new();
        private string _statusMessage = "Listo";
        private bool _isWorking;
        private string _selectedDisksInfo = "No hay discos seleccionados";

        public ObservableCollection<DiskInfo> Disks
        {
            get => _disks;
            set
            {
                AppLogger.LogViewModel($"Setting Disks collection. New count: {value?.Count ?? 0}");
                
                // Desuscribirse de los eventos de los discos anteriores
                if (_disks != null)
                {
                    foreach (var disk in _disks)
                    {
                        disk.PropertyChanged -= OnDiskPropertyChanged;
                    }
                }
                
                _disks = value ?? new ObservableCollection<DiskInfo>();
                
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
                UpdateSelectedDisksInfo();
            }
        }

        public string StatusMessage
        {
            get => _statusMessage;
            set
            {
                if (_statusMessage != value)
                {
                    _statusMessage = value;
                    AppLogger.LogViewModel($"StatusMessage changed to: {value}");
                    OnPropertyChanged();
                }
            }
        }

        public string SelectedDisksInfo
        {
            get => _selectedDisksInfo;
            set
            {
                if (_selectedDisksInfo != value)
                {
                    _selectedDisksInfo = value;
                    AppLogger.LogViewModel($"SelectedDisksInfo changed to: {value}");
                    OnPropertyChanged();
                }
            }
        }

        public bool IsWorking
        {
            get => _isWorking;
            set
            {
                if (_isWorking != value)
                {
                    _isWorking = value;
                    AppLogger.LogViewModel($"IsWorking changed to: {value}");
                    OnPropertyChanged();
                    UpdateCommandStates();
                }
            }
        }

        public ICommand ProtectCommand { get; private set; }
        public ICommand UnprotectCommand { get; private set; }
        public ICommand RefreshCommand { get; private set; }
        public ICommand AdminManageCommand { get; private set; }
        public ICommand ExitCommand { get; private set; }

        public MainViewModel()
        {
            AppLogger.LogViewModel("MainViewModel constructor starting...");
            _diskService = new DiskService();
            
            // Inicializar comandos
            ProtectCommand = new RelayCommand(async (object? param) => await ExecuteProtectDisksAsync(), 
                                            (object? param) => CanExecuteProtect(param));
            UnprotectCommand = new RelayCommand(async (object? param) => await ExecuteUnprotectDisksAsync(), 
                                              (object? param) => CanExecuteUnprotect(param));
            RefreshCommand = new RelayCommand((object? param) => ExecuteRefreshDisks(param), 
                                            (object? param) => CanAlwaysExecute(param));
            AdminManageCommand = new RelayCommand((object? param) => ExecuteAdminManage(param), 
                                                (object? param) => CanExecuteAdminManage(param));
            ExitCommand = new RelayCommand((object? param) => ExecuteExit(param), 
                                         (object? param) => CanAlwaysExecute(param));

            AppLogger.LogViewModel("MainViewModel commands initialized");
            RefreshDisks();
            AppLogger.LogViewModel("MainViewModel constructor completed");
        }

        private void RefreshDisks()
        {
            try
            {
                AppLogger.LogViewModel("Starting RefreshDisks");
                IsWorking = true;
                StatusMessage = "Actualizando lista de discos...";
                
                var disks = _diskService.GetDisks();
                AppLogger.LogViewModel($"DiskService returned {disks.Count} disks");
                
                // Ordenar por letra de unidad ascendente
                var sortedDisks = disks.OrderBy(d => d.DriveLetter).ToList();
                
                Disks.Clear();
                foreach (var disk in sortedDisks)
                {
                    disk.PropertyChanged += OnDiskPropertyChanged;
                    Disks.Add(disk);
                }
                
                StatusMessage = $"Se encontraron {disks.Count} discos";
                AppLogger.LogViewModel($"RefreshDisks completed. Added {disks.Count} disks to collection");
                UpdateCommandStates(); // Actualizar estado de comandos después de refrescar
                UpdateSelectedDisksInfo();
            }
            catch (Exception ex)
            {
                StatusMessage = "Error al actualizar discos";
                AppLogger.Error("ViewModel", "Error al actualizar discos", ex);
            }
            finally
            {
                IsWorking = false;
            }
        }

        private async Task ExecuteProtectDisksAsync()
        {
            AppLogger.LogViewModel("ExecuteProtectDisksAsync started");
            // Solo discos seleccionables y actualmente desprotegidos
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable && !d.IsProtected).ToList();
            AppLogger.LogViewModel($"Found {selectedDisks.Count} disks eligible for protection");
            
            if (!selectedDisks.Any())
            {
                AppLogger.LogViewModel("No disks selected for protection");
                MessageBox.Show("No hay discos seleccionables seleccionados para proteger.", "Información", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var result = MessageBox.Show($"¿Está seguro que desea proteger {selectedDisks.Count} disco(s)?", "Confirmar protección", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (result != MessageBoxResult.Yes) return;

            IsWorking = true;
            StatusMessage = "Protegiendo discos...";
            UpdateCommandStates(); // Desactivar comandos durante la operación

            try
            {
                int successCount = 0;
                int totalCount = selectedDisks.Count;

                for (int i = 0; i < selectedDisks.Count; i++)
                {
                    var disk = selectedDisks[i];
                    var progress = new Progress<string>(message => 
                    {
                        StatusMessage = $"Protegiendo {disk.DriveLetter}: {message} ({i + 1}/{totalCount})";
                    });

                    bool success = await _diskService.ProtectDriveAsync(disk.DriveLetter ?? "", progress);
                    if (success)
                    {
                        successCount++;
                        disk.IsProtected = true;
                        AppLogger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", true);
                    }
                    else
                    {
                        AppLogger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                    }
                }
                
                StatusMessage = $"Protegidos {successCount} de {totalCount} discos seleccionados";
                AppLogger.LogViewModel($"Protection completed: {successCount}/{totalCount} disks protected");
                RefreshDisks(); // Actualizar estados
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error durante la protección: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                AppLogger.Error("ViewModel", "Error during protection", ex);
            }
            finally
            {
                IsWorking = false;
                StatusMessage = "Listo";
                UpdateCommandStates(); // Reactivar comandos
                UpdateSelectedDisksInfo();
            }
        }

        private async Task ExecuteUnprotectDisksAsync()
        {
            AppLogger.LogViewModel("ExecuteUnprotectDisksAsync started");
            // Solo discos seleccionables y actualmente protegidos
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable && d.IsProtected).ToList();
            AppLogger.LogViewModel($"Found {selectedDisks.Count} disks eligible for unprotection");
            
            if (!selectedDisks.Any())
            {
                AppLogger.LogViewModel("No disks selected for unprotection");
                MessageBox.Show("No hay discos seleccionables seleccionados para desproteger.", "Información", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var result = MessageBox.Show($"¿Está seguro que desea desproteger {selectedDisks.Count} disco(s)?", "Confirmar desprotección", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (result != MessageBoxResult.Yes) return;

            IsWorking = true;
            StatusMessage = "Desprotegiendo discos...";
            UpdateCommandStates(); // Desactivar comandos durante la operación

            try
            {
                int successCount = 0;
                int totalCount = selectedDisks.Count;

                for (int i = 0; i < selectedDisks.Count; i++)
                {
                    var disk = selectedDisks[i];
                    var progress = new Progress<string>(message => 
                    {
                        StatusMessage = $"Desprotegiendo {disk.DriveLetter}: {message} ({i + 1}/{totalCount})";
                    });

                    bool success = await _diskService.UnprotectDriveAsync(disk.DriveLetter ?? "", progress);
                    if (success)
                    {
                        successCount++;
                        disk.IsProtected = false;
                        AppLogger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", true);
                    }
                    else
                    {
                        AppLogger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                    }
                }
                
                StatusMessage = $"Desprotegidos {successCount} de {totalCount} discos seleccionados";
                AppLogger.LogViewModel($"Unprotection completed: {successCount}/{totalCount} disks unprotected");
                RefreshDisks(); // Actualizar estados
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error durante la desprotección: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                AppLogger.Error("ViewModel", "Error during unprotection", ex);
            }
            finally
            {
                IsWorking = false;
                StatusMessage = "Listo";
                UpdateCommandStates(); // Reactivar comandos
                UpdateSelectedDisksInfo();
            }
        }

        private void ExecuteAdminManage(object? parameter)
        {
            AppLogger.LogViewModel("ExecuteAdminManage started");
            MessageBox.Show("Funcionalidad de administración de discos no administrables.\n\nEsta función permitirá convertir discos no administrables en administrables.", "Administración de Discos", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void ExecuteRefreshDisks(object? parameter)
        {
            AppLogger.LogViewModel("ExecuteRefreshDisks called");
            RefreshDisks();
        }

        private void ExecuteExit(object? parameter)
        {
            AppLogger.LogViewModel("ExecuteExit called");
            if (IsWorking)
            {
                var result = MessageBox.Show("Hay operaciones en curso. ¿Está seguro que desea salir?", "Confirmar salida", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (result != MessageBoxResult.Yes) return;
            }

            Application.Current.Shutdown();
        }

        private bool CanExecuteProtect(object? parameter)
        {
            // Activar solo si hay discos seleccionados que sean seleccionables y actualmente desprotegidos
            bool canExecute = !IsWorking && 
                   Disks.Any(d => d.IsSelected && d.IsSelectable && !d.IsProtected);
            
            AppLogger.LogViewModel($"CanExecuteProtect: {canExecute} - IsWorking: {IsWorking} - SelectedCount: {Disks.Count(d => d.IsSelected && d.IsSelectable && !d.IsProtected)}");
            return canExecute;
        }

        private bool CanExecuteUnprotect(object? parameter)
        {
            // Activar solo si hay discos seleccionados que sean seleccionables y actualmente protegidos
            bool canExecute = !IsWorking && 
                   Disks.Any(d => d.IsSelected && d.IsSelectable && d.IsProtected);
            
            AppLogger.LogViewModel($"CanExecuteUnprotect: {canExecute} - IsWorking: {IsWorking} - SelectedCount: {Disks.Count(d => d.IsSelected && d.IsSelectable && d.IsProtected)}");
            return canExecute;
        }

        private bool CanExecuteAdminManage(object? parameter)
        {
            // Activar solo si hay discos seleccionados que no sean seleccionables
            bool canExecute = !IsWorking && 
                   Disks.Any(d => d.IsSelected && !d.IsSelectable);
            
            AppLogger.LogViewModel($"CanExecuteAdminManage: {canExecute} - IsWorking: {IsWorking} - SelectedCount: {Disks.Count(d => d.IsSelected && !d.IsSelectable)}");
            return canExecute;
        }

        private bool CanAlwaysExecute(object? parameter)
        {
            bool canExecute = !IsWorking;
            AppLogger.LogViewModel($"CanAlwaysExecute: {canExecute} - IsWorking: {IsWorking}");
            return canExecute;
        }

        private void OnDiskPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            // Registrar cambios importantes
            if (e.PropertyName == nameof(DiskInfo.IsSelected) ||
                e.PropertyName == nameof(DiskInfo.IsProtected) ||
                e.PropertyName == nameof(DiskInfo.IsSelectable) ||
                e.PropertyName == nameof(DiskInfo.IsManageable) ||
                e.PropertyName == nameof(DiskInfo.IsSystemDisk))
            {
                AppLogger.LogViewModel($"Disk property changed: {e.PropertyName} on disk {(sender is DiskInfo disk ? disk.DriveLetter : "unknown")}");
                UpdateCommandStates();
                UpdateSelectedDisksInfo();
            }
        }

        private void UpdateSelectedDisksInfo()
        {
            var selectedDisks = Disks.Where(d => d.IsSelected).ToList();
            if (!selectedDisks.Any())
            {
                SelectedDisksInfo = "No hay discos seleccionados";
            }
            else
            {
                var diskList = string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})"));
                SelectedDisksInfo = $"Seleccionados: {diskList}";
            }
            AppLogger.LogViewModel($"Updated SelectedDisksInfo: {SelectedDisksInfo}");
        }

        private void UpdateCommandStates()
        {
            AppLogger.LogViewModel("Updating command states");
            if (ProtectCommand is RelayCommand protectCommand)
                protectCommand.RaiseCanExecuteChanged();
            if (UnprotectCommand is RelayCommand unprotectCommand)
                unprotectCommand.RaiseCanExecuteChanged();
            if (RefreshCommand is RelayCommand refreshCommand)
                refreshCommand.RaiseCanExecuteChanged();
            if (AdminManageCommand is RelayCommand adminCommand)
                adminCommand.RaiseCanExecuteChanged();
            if (ExitCommand is RelayCommand exitCommand)
                exitCommand.RaiseCanExecuteChanged();
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}

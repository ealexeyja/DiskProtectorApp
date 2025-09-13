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

        public ICommand ProtectCommand { get; private set; }
        public ICommand UnprotectCommand { get; private set; }
        public ICommand RefreshCommand { get; private set; }
        public ICommand AdminManageCommand { get; private set; }
        public ICommand ExitCommand { get; private set; }

        public MainViewModel()
        {
            SimpleLogger.LogViewModel("MainViewModel constructor starting...");
            _diskService = new DiskService();
            
            // Inicializar comandos
            ProtectCommand = new RelayCommand(async (object? param) => await ExecuteProtectDisksAsync(), 
                                            (object? param) => CanExecuteProtect());
            UnprotectCommand = new RelayCommand(async (object? param) => await ExecuteUnprotectDisksAsync(), 
                                              (object? param) => CanExecuteUnprotect());
            RefreshCommand = new RelayCommand((object? param) => ExecuteRefreshDisks(), 
                                            (object? param) => CanAlwaysExecute());
            AdminManageCommand = new RelayCommand((object? param) => ExecuteAdminManage(), 
                                                (object? param) => CanExecuteAdminManage());
            ExitCommand = new RelayCommand((object? param) => ExecuteExit(), 
                                         (object? param) => CanAlwaysExecute());

            SimpleLogger.LogViewModel("MainViewModel commands initialized");
            RefreshDisks();
            SimpleLogger.LogViewModel("MainViewModel constructor completed");
        }

        private void RefreshDisks()
        {
            try
            {
                SimpleLogger.LogViewModel("Starting RefreshDisks");
                IsWorking = true;
                StatusMessage = "Actualizando lista de discos...";
                
                var disks = _diskService.GetDisks();
                SimpleLogger.LogViewModel($"DiskService returned {disks.Count} disks");
                
                // Ordenar por letra de unidad ascendente
                var sortedDisks = disks.OrderBy(d => d.DriveLetter).ToList();
                
                Disks.Clear();
                foreach (var disk in sortedDisks)
                {
                    Disks.Add(disk);
                }
                
                StatusMessage = $"Se encontraron {disks.Count} discos";
                SimpleLogger.LogViewModel($"RefreshDisks completed. Added {disks.Count} disks to collection");
                UpdateCommandStates(); // Actualizar estado de comandos después de refrescar
            }
            catch (Exception ex)
            {
                StatusMessage = "Error al actualizar discos";
                SimpleLogger.Error(LogCategory.ViewModel, "Error al actualizar discos", ex);
            }
            finally
            {
                IsWorking = false;
            }
        }

        private async Task ExecuteProtectDisksAsync()
        {
            SimpleLogger.LogViewModel("ExecuteProtectDisksAsync started");
            // Solo discos seleccionables y actualmente desprotegidos
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable && !d.IsProtected).ToList();
            SimpleLogger.LogViewModel($"Found {selectedDisks.Count} disks eligible for protection");
            
            if (!selectedDisks.Any())
            {
                SimpleLogger.LogViewModel("No disks selected for protection");
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
                        SimpleLogger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", true);
                    }
                    else
                    {
                        SimpleLogger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                    }
                }
                
                MessageBox.Show($"Protección completada: {successCount}/{totalCount} discos protegidos.", "Resultado", MessageBoxButton.OK, MessageBoxImage.Information);
                RefreshDisks(); // Actualizar estados
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error durante la protección: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                SimpleLogger.Error(LogCategory.ViewModel, "Error during protection", ex);
            }
            finally
            {
                IsWorking = false;
                StatusMessage = "Listo";
                UpdateCommandStates(); // Reactivar comandos
            }
        }

        private async Task ExecuteUnprotectDisksAsync()
        {
            SimpleLogger.LogViewModel("ExecuteUnprotectDisksAsync started");
            // Solo discos seleccionables y actualmente protegidos
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable && d.IsProtected).ToList();
            SimpleLogger.LogViewModel($"Found {selectedDisks.Count} disks eligible for unprotection");
            
            if (!selectedDisks.Any())
            {
                SimpleLogger.LogViewModel("No disks selected for unprotection");
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
                        SimpleLogger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", true);
                    }
                    else
                    {
                        SimpleLogger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                    }
                }
                
                MessageBox.Show($"Desprotección completada: {successCount}/{totalCount} discos desprotegidos.", "Resultado", MessageBoxButton.OK, MessageBoxImage.Information);
                RefreshDisks(); // Actualizar estados
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error durante la desprotección: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                SimpleLogger.Error(LogCategory.ViewModel, "Error during unprotection", ex);
            }
            finally
            {
                IsWorking = false;
                StatusMessage = "Listo";
                UpdateCommandStates(); // Reactivar comandos
            }
        }

        private void ExecuteAdminManage(object? parameter = null)
        {
            SimpleLogger.LogViewModel("ExecuteAdminManage started");
            MessageBox.Show("Funcionalidad de administración de discos no administrables.\n\nEsta función permitirá convertir discos no administrables en administrables.", "Administración de Discos", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void ExecuteRefreshDisks(object? parameter = null)
        {
            SimpleLogger.LogViewModel("ExecuteRefreshDisks called");
            RefreshDisks();
        }

        private void ExecuteExit(object? parameter = null)
        {
            SimpleLogger.LogViewModel("ExecuteExit called");
            if (IsWorking)
            {
                var result = MessageBox.Show("Hay operaciones en curso. ¿Está seguro que desea salir?", "Confirmar salida", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (result != MessageBoxResult.Yes) return;
            }

            Application.Current.Shutdown();
        }

        private bool CanExecuteProtect()
        {
            // Activar solo si hay discos seleccionados que sean seleccionables y actualmente desprotegidos
            bool canExecute = !IsWorking && 
                   Disks.Any(d => d.IsSelected && d.IsSelectable && !d.IsProtected);
            
            SimpleLogger.LogViewModel($"CanExecuteProtect: {canExecute} - IsWorking: {IsWorking} - SelectedCount: {Disks.Count(d => d.IsSelected && d.IsSelectable && !d.IsProtected)}");
            return canExecute;
        }

        private bool CanExecuteUnprotect()
        {
            // Activar solo si hay discos seleccionados que sean seleccionables y actualmente protegidos
            bool canExecute = !IsWorking && 
                   Disks.Any(d => d.IsSelected && d.IsSelectable && d.IsProtected);
            
            SimpleLogger.LogViewModel($"CanExecuteUnprotect: {canExecute} - IsWorking: {IsWorking} - SelectedCount: {Disks.Count(d => d.IsSelected && d.IsSelectable && d.IsProtected)}");
            return canExecute;
        }

        private bool CanExecuteAdminManage()
        {
            // Activar solo si hay discos seleccionados que no sean seleccionables
            bool canExecute = !IsWorking && 
                   Disks.Any(d => d.IsSelected && !d.IsSelectable);
            
            SimpleLogger.LogViewModel($"CanExecuteAdminManage: {canExecute} - IsWorking: {IsWorking} - SelectedCount: {Disks.Count(d => d.IsSelected && !d.IsSelectable)}");
            return canExecute;
        }

        private bool CanAlwaysExecute()
        {
            bool canExecute = !IsWorking;
            SimpleLogger.LogViewModel($"CanAlwaysExecute: {canExecute} - IsWorking: {IsWorking}");
            return canExecute;
        }

        private void UpdateCommandStates()
        {
            SimpleLogger.LogViewModel("Updating command states");
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

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
using DiskProtectorApp.Views; // Usar el OperationLogger original de MainWindow.xaml.cs

namespace DiskProtectorApp.ViewModels
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private readonly DiskService _diskService;
        private readonly OperationLogger _logger; // Logger original de Views
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
            _diskService = new DiskService();
            _logger = new OperationLogger(); // Logger original
            
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

            RefreshDisks();
        }

        private void RefreshDisks()
        {
            try
            {
                IsWorking = true;
                StatusMessage = "Actualizando lista de discos...";
                
                var disks = _diskService.GetDisks();
                
                // Ordenar por letra de unidad ascendente
                var sortedDisks = disks.OrderBy(d => d.Name).ToList();
                
                Disks.Clear();
                foreach (var disk in sortedDisks)
                {
                    disk.PropertyChanged += OnDiskPropertyChanged;
                    Disks.Add(disk);
                }
                
                StatusMessage = $"Se encontraron {disks.Count} discos";
            }
            catch (Exception ex)
            {
                StatusMessage = "Error al actualizar discos";
                _logger.Log($"Error al actualizar discos: {ex.Message}"); // Usar Log, no LogMessage
            }
            finally
            {
                IsWorking = false;
            }
        }

        private async Task ExecuteProtectDisksAsync()
        {
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsManageable && d.IsEligible && !d.IsProtected).ToList();
            
            if (!selectedDisks.Any())
            {
                MessageBox.Show("No hay discos elegibles seleccionados para proteger.", "Información", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var result = MessageBox.Show($"¿Está seguro que desea proteger {selectedDisks.Count} disco(s)?", "Confirmar protección", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (result != MessageBoxResult.Yes) return;

            IsWorking = true;
            StatusMessage = "Protegiendo discos...";

            try
            {
                var progressDialog = new ProgressDialog();
                progressDialog.Owner = Application.Current.MainWindow;
                progressDialog.Show();

                int successCount = 0;
                int totalCount = selectedDisks.Count;

                for (int i = 0; i < selectedDisks.Count; i++)
                {
                    var disk = selectedDisks[i];
                    var progress = new Progress<string>(message => 
                    {
                        progressDialog.UpdateProgress($"Protegiendo {disk.Name}", $"{message} ({i + 1}/{totalCount})");
                    });

                    bool success = await _diskService.ProtectDriveAsync(disk.Name, progress);
                    if (success)
                    {
                        successCount++;
                        disk.IsProtected = true;
                        _logger.Log($"Operación Proteger en {disk.Name}: Éxito"); // Usar Log, no LogMessage
                    }
                    else
                    {
                        _logger.Log($"Operación Proteger en {disk.Name}: Error al aplicar permisos"); // Usar Log, no LogMessage
                    }
                }

                progressDialog.Close();
                
                MessageBox.Show($"Protección completada: {successCount}/{totalCount} discos protegidos.", "Resultado", MessageBoxButton.OK, MessageBoxImage.Information);
                RefreshDisks(); // Actualizar estados
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error durante la protección: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                _logger.Log($"Error durante protección: {ex.Message}"); // Usar Log, no LogMessage
            }
            finally
            {
                IsWorking = false;
                StatusMessage = "Listo";
            }
        }

        private async Task ExecuteUnprotectDisksAsync()
        {
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsManageable && d.IsEligible && d.IsProtected).ToList();
            
            if (!selectedDisks.Any())
            {
                MessageBox.Show("No hay discos elegibles seleccionados para desproteger.", "Información", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var result = MessageBox.Show($"¿Está seguro que desea desproteger {selectedDisks.Count} disco(s)?", "Confirmar desprotección", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (result != MessageBoxResult.Yes) return;

            IsWorking = true;
            StatusMessage = "Desprotegiendo discos...";

            try
            {
                var progressDialog = new ProgressDialog();
                progressDialog.Owner = Application.Current.MainWindow;
                progressDialog.Show();

                int successCount = 0;
                int totalCount = selectedDisks.Count;

                for (int i = 0; i < selectedDisks.Count; i++)
                {
                    var disk = selectedDisks[i];
                    var progress = new Progress<string>(message => 
                    {
                        progressDialog.UpdateProgress($"Desprotegiendo {disk.Name}", $"{message} ({i + 1}/{totalCount})");
                    });

                    bool success = await _diskService.UnprotectDriveAsync(disk.Name, progress);
                    if (success)
                    {
                        successCount++;
                        disk.IsProtected = false;
                        _logger.Log($"Operación Desproteger en {disk.Name}: Éxito"); // Usar Log, no LogMessage
                    }
                    else
                    {
                        _logger.Log($"Operación Desproteger en {disk.Name}: Error al restaurar permisos"); // Usar Log, no LogMessage
                    }
                }

                progressDialog.Close();
                
                MessageBox.Show($"Desprotección completada: {successCount}/{totalCount} discos desprotegidos.", "Resultado", MessageBoxButton.OK, MessageBoxImage.Information);
                RefreshDisks(); // Actualizar estados
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error durante la desprotección: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                _logger.Log($"Error durante desprotección: {ex.Message}"); // Usar Log, no LogMessage
            }
            finally
            {
                IsWorking = false;
                StatusMessage = "Listo";
            }
        }

        private void ExecuteRefreshDisks(object? parameter = null)
        {
            RefreshDisks();
        }

        private void ExecuteAdminManage(object? parameter = null)
        {
            MessageBox.Show("Funcionalidad de administración de discos no administrables.\n\nEsta función permitirá convertir discos no administrables en administrables.", "Administración de Discos", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void ExecuteExit(object? parameter = null)
        {
            if (IsWorking)
            {
                var result = MessageBox.Show("Hay operaciones en curso. ¿Está seguro que desea salir?", "Confirmar salida", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (result != MessageBoxResult.Yes) return;
            }

            Application.Current.Shutdown();
        }

        private bool CanExecuteProtect()
        {
            return !IsWorking && 
                   Disks.Any(d => d.IsSelected && d.IsManageable && d.IsEligible && !d.IsProtected);
        }

        private bool CanExecuteUnprotect()
        {
            return !IsWorking && 
                   Disks.Any(d => d.IsSelected && d.IsManageable && d.IsEligible && d.IsProtected);
        }

        private bool CanExecuteAdminManage()
        {
            return !IsWorking && 
                   Disks.Any(d => !d.IsManageable);
        }

        private bool CanAlwaysExecute()
        {
            return !IsWorking;
        }

        private void OnDiskPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(DiskInfo.IsSelected) ||
                e.PropertyName == nameof(DiskInfo.IsProtected) ||
                e.PropertyName == nameof(DiskInfo.IsManageable))
            {
                UpdateCommandStates();
            }
        }

        private void UpdateCommandStates()
        {
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

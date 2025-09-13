using DiskProtectorApp.Logging;
using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;

namespace DiskProtectorApp.ViewModels
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private readonly DiskService _diskService;
        private ObservableCollection<DiskInfo> _disks;
        private ObservableCollection<DiskInfo> _selectedDisks;
        private string _statusMessage;
        private bool _isWorking;
        private string _selectedDisksInfo;

        // Comandos
        public RelayCommand ProtectCommand { get; private set; }
        public RelayCommand UnprotectCommand { get; private set; }
        public RelayCommand RefreshCommand { get; private set; }
        public RelayCommand ExitCommand { get; private set; }
        public RelayCommand ShowInfoCommand { get; private set; }
        
        // Comando para administrar discos no administrables (Nombre corregido para coincidir con XAML)
        public RelayCommand AdminManageCommand { get; private set; }

        public MainViewModel()
        {
            AppLogger.LogViewModel("Constructor de MainViewModel iniciando...");
            _diskService = new DiskService();
            _disks = new ObservableCollection<DiskInfo>();
            _selectedDisks = new ObservableCollection<DiskInfo>();

            // Inicializar comandos
            ProtectCommand = new RelayCommand(async (object _) => await ExecuteProtectDisks(), (object _) => CanExecuteProtect());
            UnprotectCommand = new RelayCommand(async (object _) => await ExecuteUnprotectDisks(), (object _) => CanExecuteUnprotect());
            RefreshCommand = new RelayCommand((object _) => ExecuteRefreshDisks(), (object _) => CanAlwaysExecute());
            ExitCommand = new RelayCommand((object _) => ExecuteExit(), (object _) => CanAlwaysExecute());
            ShowInfoCommand = new RelayCommand((object _) => ExecuteShowInfo(), (object _) => CanAlwaysExecute());
            
            // Comando para administrar discos no administrables (Nombre corregido)
            AdminManageCommand = new RelayCommand(async (object _) => await ExecuteAdminManage(), (object _) => CanExecuteAdminManage());

            // Suscribirse a eventos de cambio de propiedad para las colecciones
            _disks.CollectionChanged += (s, e) => OnPropertyChanged(nameof(Disks));
            _selectedDisks.CollectionChanged += (s, e) => 
            {
                UpdateSelectedDisksInfo();
                UpdateCommandStates(); // Actualizar estados cuando cambia la selección
            };

            AppLogger.LogViewModel("Comandos de MainViewModel inicializados");

            // Inicializar datos
            RefreshDisks();
            AppLogger.LogViewModel("Constructor de MainViewModel completado");
        }

        public ObservableCollection<DiskInfo> Disks
        {
            get { return _disks; }
            set { SetProperty(ref _disks, value); }
        }

        public ObservableCollection<DiskInfo> SelectedDisks
        {
            get { return _selectedDisks; }
            set 
            { 
                if (SetProperty(ref _selectedDisks, value))
                {
                    UpdateSelectedDisksInfo();
                    UpdateCommandStates(); // Asegurarse de actualizar estados al cambiar selección
                }
            }
        }

        public string StatusMessage
        {
            get { return _statusMessage; }
            set { SetProperty(ref _statusMessage, value); }
        }

        public bool IsWorking
        {
            get { return _isWorking; }
            set 
            { 
                if (SetProperty(ref _isWorking, value))
                {
                    UpdateCommandStates(); // Actualizar estados de comandos cuando cambia IsWorking
                }
            }
        }

        public string SelectedDisksInfo
        {
            get { return _selectedDisksInfo; }
            set { SetProperty(ref _selectedDisksInfo, value); }
        }

        // Métodos de ejecución de comandos
        private async Task ExecuteProtectDisks()
        {
            AppLogger.LogViewModel("Ejecución de ExecuteProtectDisks iniciada");
            
            // Solo discos seleccionables, administrables y actualmente desprotegidos
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable && d.IsManageable && !d.IsProtected).ToList();
            AppLogger.LogViewModel($"Se encontraron {selectedDisks.Count} discos elegibles para protección");

            if (!selectedDisks.Any())
            {
                AppLogger.LogViewModel("No hay discos seleccionados para protección");
                MessageBox.Show("No hay discos seleccionables y administrables seleccionados para proteger.", "Información", MessageBoxButton.OK, MessageBoxImage.Information);
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
                        disk.IsProtected = true; // Actualizar estado en el modelo
                        disk.ProtectionStatus = "Protegido";
                        AppLogger.LogViewModel($"Disco {disk.DriveLetter} protegido exitosamente");
                    }
                    else
                    {
                        AppLogger.LogViewModel($"Error al proteger el disco {disk.DriveLetter}");
                    }
                }

                StatusMessage = $"Protección completada: {successCount}/{totalCount} discos protegidos exitosamente.";
                MessageBox.Show($"Protección completada.\n{successCount} de {totalCount} discos fueron protegidos exitosamente.", "Resultado", MessageBoxButton.OK, MessageBoxImage.Information);
                
                // Refrescar la lista para asegurar que los estados sean coherentes
                RefreshDisks();
            }
            catch (Exception ex)
            {
                AppLogger.Error("ViewModel", "Error durante la protección de discos", ex);
                StatusMessage = "Error durante la protección de discos.";
                MessageBox.Show($"Ocurrió un error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                IsWorking = false;
                UpdateCommandStates(); // Reactivar comandos
            }
        }

        private async Task ExecuteUnprotectDisks()
        {
            AppLogger.LogViewModel("Ejecución de ExecuteUnprotectDisks iniciada");
            
            // Solo discos seleccionables, administrables y actualmente protegidos
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable && d.IsManageable && d.IsProtected).ToList();
            AppLogger.LogViewModel($"Se encontraron {selectedDisks.Count} discos elegibles para desprotección");

            if (!selectedDisks.Any())
            {
                AppLogger.LogViewModel("No hay discos seleccionados para desprotección");
                MessageBox.Show("No hay discos seleccionables y administrables seleccionados para desproteger.", "Información", MessageBoxButton.OK, MessageBoxImage.Information);
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
                        disk.IsProtected = false; // Actualizar estado en el modelo
                        disk.ProtectionStatus = "Desprotegido";
                        AppLogger.LogViewModel($"Disco {disk.DriveLetter} desprotegido exitosamente");
                    }
                    else
                    {
                        AppLogger.LogViewModel($"Error al desproteger el disco {disk.DriveLetter}");
                    }
                }

                StatusMessage = $"Desprotección completada: {successCount}/{totalCount} discos desprotegidos exitosamente.";
                MessageBox.Show($"Desprotección completada.\n{successCount} de {totalCount} discos fueron desprotegidos exitosamente.", "Resultado", MessageBoxButton.OK, MessageBoxImage.Information);
                
                // Refrescar la lista para asegurar que los estados sean coherentes
                RefreshDisks();
            }
            catch (Exception ex)
            {
                AppLogger.Error("ViewModel", "Error durante la desprotección de discos", ex);
                StatusMessage = "Error durante la desprotección de discos.";
                MessageBox.Show($"Ocurrió un error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                IsWorking = false;
                UpdateCommandStates(); // Reactivar comandos
            }
        }

        /// <summary>
        /// Ejecuta la operación de administración de discos no administrables.
        /// </summary>
        private async Task ExecuteAdminManage()
        {
            AppLogger.LogViewModel("Ejecución de ExecuteAdminManage iniciada");
            
            // Solo discos seleccionables y actualmente no administrables
            var selectedDisks = Disks.Where(d => d.IsSelected && d.IsSelectable && !d.IsManageable).ToList();
            AppLogger.LogViewModel($"Se encontraron {selectedDisks.Count} discos elegibles para administración");

            if (!selectedDisks.Any())
            {
                AppLogger.LogViewModel("No hay discos seleccionados para administración");
                MessageBox.Show("No hay discos seleccionables no administrables seleccionados para administrar.", "Información", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var result = MessageBox.Show($"¿Está seguro que desea administrar {selectedDisks.Count} disco(s)?\n" +
                                        "Esta operación otorgará permisos de Control Total a SYSTEM y Administradores.\n" +
                                        "¿Continuar?", "Confirmar administración", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (result != MessageBoxResult.Yes) return;

            IsWorking = true;
            StatusMessage = "Administrando discos...";
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
                        StatusMessage = $"Administrando {disk.DriveLetter}: {message} ({i + 1}/{totalCount})";
                    });

                    bool success = await _diskService.ManageDriveAsync(disk.DriveLetter ?? "", progress);
                    if (success)
                    {
                        successCount++;
                        disk.IsManageable = true; // Actualizar estado en el modelo
                        // El estado de protección debe verificarse nuevamente después de administrar
                        // Podríamos llamar a RefreshDisks() o simplemente dejar que el usuario lo haga
                        disk.ProtectionStatus = "Administrable"; // Estado temporal hasta refrescar
                        AppLogger.LogViewModel($"Disco {disk.DriveLetter} administrado exitosamente");
                    }
                    else
                    {
                        AppLogger.LogViewModel($"Error al administrar el disco {disk.DriveLetter}");
                    }
                }

                StatusMessage = $"Administración completada: {successCount}/{totalCount} discos administrados exitosamente.";
                MessageBox.Show($"Administración completada.\n{successCount} de {totalCount} discos fueron administrados exitosamente.\nSe recomienda refrescar la lista para actualizar los estados.", "Resultado", MessageBoxButton.OK, MessageBoxImage.Information);
                
                // Refrescar la lista para asegurar que los estados sean coherentes
                RefreshDisks();
            }
            catch (Exception ex)
            {
                AppLogger.Error("ViewModel", "Error durante la administración de discos", ex);
                StatusMessage = "Error durante la administración de discos.";
                MessageBox.Show($"Ocurrió un error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                IsWorking = false;
                UpdateCommandStates(); // Reactivar comandos
            }
        }

        private void ExecuteRefreshDisks()
        {
            AppLogger.LogViewModel("Ejecución de ExecuteRefreshDisks llamada");
            RefreshDisks();
        }

        private void ExecuteExit()
        {
            AppLogger.LogViewModel("Ejecución de ExecuteExit llamada");
            if (IsWorking)
            {
                var result = MessageBox.Show("Hay operaciones en curso. ¿Está seguro que desea salir?", "Confirmar salida", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (result != MessageBoxResult.Yes) return;
            }
            Application.Current.Shutdown();
        }

        private void ExecuteShowInfo()
        {
            AppLogger.LogViewModel("Ejecución de ExecuteShowInfo llamada");
            string infoMessage = "DiskProtectorApp v1.2.7\n\n" +
                                "Aplicación para proteger y desproteger discos NTFS.\n" +
                                "Permite controlar el acceso a discos mediante permisos NTFS.\n\n" +
                                "Desarrollada con .NET 8 y WPF.\n" +
                                "Utiliza icacls para la gestión avanzada de permisos.";
            MessageBox.Show(infoMessage, "Acerca de DiskProtectorApp", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        // Métodos CanExecute para comandos - LÓGICA CORREGIDA Y SIMPLIFICADA
        private bool CanExecuteProtect()
        {
            // Activar solo si:
            // 1. No hay operaciones en curso
            // 2. Hay al menos un disco seleccionado (IsSelected = True)
            // 3. Ese disco es Seleccionable (IsSelectable = True)
            // 4. Ese disco es Administrable (IsManageable = True) <- Prioridad 2
            // 5. Ese disco está actualmente Desprotegido (IsProtected = False) <- Prioridad 3
            
            bool canExecute = !IsWorking && 
                             Disks.Any(d => d.IsSelected && d.IsSelectable && d.IsManageable && !d.IsProtected);
                             
            AppLogger.LogViewModel($"CanExecuteProtect: {canExecute} - IsWorking: {IsWorking}, Cantidad de discos seleccionados, seleccionables, administrables y desprotegidos: {Disks.Count(d => d.IsSelected && d.IsSelectable && d.IsManageable && !d.IsProtected)}");
            return canExecute;
        }

        private bool CanExecuteUnprotect()
        {
            // Activar solo si:
            // 1. No hay operaciones en curso
            // 2. Hay al menos un disco seleccionado (IsSelected = True)
            // 3. Ese disco es Seleccionable (IsSelectable = True)
            // 4. Ese disco es Administrable (IsManageable = True) <- Prioridad 2
            // 5. Ese disco está actualmente Protegido (IsProtected = True) <- Prioridad 3
            
            bool canExecute = !IsWorking && 
                             Disks.Any(d => d.IsSelected && d.IsSelectable && d.IsManageable && d.IsProtected);
                             
            AppLogger.LogViewModel($"CanExecuteUnprotect: {canExecute} - IsWorking: {IsWorking}, Cantidad de discos seleccionados, seleccionables, administrables y protegidos: {Disks.Count(d => d.IsSelected && d.IsSelectable && d.IsManageable && d.IsProtected)}");
            return canExecute;
        }

        /// <summary>
        /// Determina si el comando de administración se puede ejecutar.
        /// </summary>
        private bool CanExecuteAdminManage()
        {
            // Activar solo si:
            // 1. No hay operaciones en curso
            // 2. Hay al menos un disco seleccionado (IsSelected = True)
            // 3. Ese disco es Seleccionable (IsSelectable = True)
            // 4. Ese disco NO es Administrable (IsManageable = False) <- Prioridad 1
            
            bool canExecute = !IsWorking && 
                             Disks.Any(d => d.IsSelected && d.IsSelectable && !d.IsManageable);
                             
            AppLogger.LogViewModel($"CanExecuteAdminManage: {canExecute} - IsWorking: {IsWorking}, Cantidad de discos seleccionados, seleccionables y no administrables: {Disks.Count(d => d.IsSelected && d.IsSelectable && !d.IsManageable)}");
            return canExecute;
        }

        private bool CanAlwaysExecute()
        {
            bool canExecute = !IsWorking;
            AppLogger.LogViewModel($"CanAlwaysExecute: {canExecute} - IsWorking: {IsWorking}");
            return canExecute;
        }

        // Métodos auxiliares
        private async void RefreshDisks()
        {
            AppLogger.LogViewModel("Iniciando RefreshDisks");
            IsWorking = true;
            StatusMessage = "Actualizando lista de discos...";
            UpdateCommandStates(); // Desactivar comandos durante la actualización

            try
            {
                var disks = await Task.Run(() => _diskService.GetDisks());
                AppLogger.LogViewModel($"GetDisks devolvió {disks.Count} discos");

                Disks.Clear();
                foreach (var disk in disks)
                {
                    // Suscribirse a cambios de propiedad del disco
                    disk.PropertyChanged += OnDiskPropertyChanged;
                    Disks.Add(disk);
                }

                StatusMessage = $"Lista actualizada: {disks.Count} discos encontrados.";
                AppLogger.LogViewModel($"Colección de discos actualizada con {Disks.Count} elementos");
            }
            catch (Exception ex)
            {
                AppLogger.Error("ViewModel", "Error al refrescar discos", ex);
                StatusMessage = "Error al actualizar la lista de discos.";
                MessageBox.Show($"Ocurrió un error al actualizar la lista de discos: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                IsWorking = false;
                UpdateCommandStates(); // Reactivar comandos
            }
        }

        private void OnDiskPropertyChanged(object sender, PropertyChangedEventArgs e)
        {
            // Si cambia alguna propiedad relevante de un disco, actualizar estados de comandos
            if (e.PropertyName == nameof(DiskInfo.IsProtected) || 
                e.PropertyName == nameof(DiskInfo.IsManageable) ||
                e.PropertyName == nameof(DiskInfo.IsSelectable) ||
                e.PropertyName == nameof(DiskInfo.IsSelected))
            {
                UpdateCommandStates();
            }
        }

        private void UpdateSelectedDisksInfo()
        {
            if (SelectedDisks == null || !SelectedDisks.Any())
            {
                SelectedDisksInfo = "No hay discos seleccionados";
            }
            else
            {
                var diskList = string.Join(", ", SelectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})"));
                SelectedDisksInfo = $"Seleccionados: {diskList}";
            }
            AppLogger.LogViewModel($"Información de discos seleccionados actualizada: {SelectedDisksInfo}");
        }

        private void UpdateCommandStates()
        {
            AppLogger.LogViewModel("Actualizando estados de comandos");
            ProtectCommand.RaiseCanExecuteChanged();
            UnprotectCommand.RaiseCanExecuteChanged();
            RefreshCommand.RaiseCanExecuteChanged();
            ExitCommand.RaiseCanExecuteChanged();
            ShowInfoCommand.RaiseCanExecuteChanged();
            
            // Actualizar estado del comando de administración (Nombre corregido)
            AdminManageCommand?.RaiseCanExecuteChanged();
            
            // Llamada explícita para asegurar que se registre el estado
            bool _ = CanExecuteAdminManage(); // Esto provocará que se registre el estado en los logs
        }

        // Implementación de INotifyPropertyChanged
        public event PropertyChangedEventHandler PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        protected bool SetProperty<T>(ref T field, T value, [System.Runtime.CompilerServices.CallerMemberName] string propertyName = null)
        {
            if (Equals(field, value)) return false;

            field = value;
            OnPropertyChanged(propertyName);
            return true;
        }
    }
}

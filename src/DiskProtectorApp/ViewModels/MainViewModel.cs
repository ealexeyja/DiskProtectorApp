using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
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
        private string _selectedDisksInfo = "Discos seleccionados: Ninguno";
        private string _diagnosticInfo = "";
        private bool _isWorking;

        public ObservableCollection<DiskInfo> Disks
        {
            get => _disks;
            set
            {
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Setting Disks collection. Old count: {_disks?.Count ?? 0}, New count: {value?.Count ?? 0}");
                Console.WriteLine($"[VIEWMODEL] Setting Disks collection. Old count: {_disks?.Count ?? 0}, New count: {value?.Count ?? 0}");
                
                // Desuscribirse de los eventos de los discos anteriores
                if (_disks != null)
                {
                    foreach (var disk in _disks)
                    {
                        disk.PropertyChanged -= OnDiskPropertyChanged;
                        System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Unsubscribed from disk {disk.DriveLetter}");
                        Console.WriteLine($"[VIEWMODEL] Unsubscribed from disk {disk.DriveLetter}");
                    }
                }
                
                _disks = value;
                
                // Suscribirse a los eventos de los nuevos discos
                if (_disks != null)
                {
                    foreach (var disk in _disks)
                    {
                        disk.PropertyChanged += OnDiskPropertyChanged;
                        System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Subscribed to disk {disk.DriveLetter}");
                        Console.WriteLine($"[VIEWMODEL] Subscribed to disk {disk.DriveLetter}");
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
                _statusMessage = value;
                OnPropertyChanged();
            }
        }

        public string SelectedDisksInfo
        {
            get => _selectedDisksInfo;
            set
            {
                _selectedDisksInfo = value;
                OnPropertyChanged();
            }
        }

        public string DiagnosticInfo
        {
            get => _diagnosticInfo;
            set
            {
                _diagnosticInfo = value;
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
            
            ProtectCommand = new RelayCommand(ExecuteProtectTest, CanAlwaysExecute);
            UnprotectCommand = new RelayCommand(ExecuteUnprotectTest, CanAlwaysExecute);
            RefreshCommand = new RelayCommand(ExecuteRefreshDisks);
            
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] MainViewModel initialized");
            Console.WriteLine("[VIEWMODEL] MainViewModel initialized");
            RefreshDisks();
        }

        private void OnDiskPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(DiskInfo.IsSelected) || 
                e.PropertyName == nameof(DiskInfo.IsProtected))
            {
                var disk = sender as DiskInfo;
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Disk property changed: {disk?.DriveLetter} - {e.PropertyName}");
                Console.WriteLine($"[VIEWMODEL] Disk property changed: {disk?.DriveLetter} - {e.PropertyName}");
                
                // Actualizar información de discos seleccionados cuando cambia IsSelected
                if (e.PropertyName == nameof(DiskInfo.IsSelected))
                {
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] IsSelected changed for {disk?.DriveLetter}, updating selected disks info");
                    Console.WriteLine($"[VIEWMODEL] IsSelected changed for {disk?.DriveLetter}, updating selected disks info");
                    UpdateSelectedDisksInfo();
                }
                
                // Actualizar estado de comandos
                UpdateCommandStates();
            }
        }

        public void ShowDiagnosticInfo()
        {
            if (_disks == null)
            {
                DiagnosticInfo = "No hay discos cargados";
                return;
            }
            
            var selectedDisks = _disks.Where(d => d.IsSelected).ToList();
            var diagnostic = $"Total discos: {_disks.Count}\n" +
                           $"Discos seleccionados: {selectedDisks.Count}\n" +
                           $"Estado de trabajo: {IsWorking}\n" +
                           $"Comandos activos: Protect={CanAlwaysExecute(null)}, Unprotect={CanAlwaysExecute(null)}";
            
            if (selectedDisks.Count > 0)
            {
                diagnostic += "\n\nDiscos seleccionados:\n";
                foreach (var disk in selectedDisks)
                {
                    diagnostic += $"  {disk.DriveLetter} ({disk.VolumeName}) - Selected: {disk.IsSelected}, Protected: {disk.IsProtected}\n";
                }
            }
            
            DiagnosticInfo = diagnostic;
            
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Diagnostic info: {diagnostic}");
            Console.WriteLine($"[VIEWMODEL] Diagnostic info: {diagnostic}");
        }

        private void UpdateSelectedDisksInfo()
        {
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] UpdateSelectedDisksInfo called. Disks count: {_disks?.Count ?? 0}");
            Console.WriteLine($"[VIEWMODEL] UpdateSelectedDisksInfo called. Disks count: {_disks?.Count ?? 0}");
            
            if (_disks == null)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
                System.Diagnostics.Debug.WriteLine("[VIEWMODEL] Disks is null, setting to 'Ninguno'");
                Console.WriteLine("[VIEWMODEL] Disks is null, setting to 'Ninguno'");
                return;
            }
            
            var selectedDisks = _disks.Where(d => d.IsSelected).ToList();
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Found {selectedDisks.Count} selected disks");
            Console.WriteLine($"[VIEWMODEL] Found {selectedDisks.Count} selected disks");
            
            if (selectedDisks.Count == 0)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
                System.Diagnostics.Debug.WriteLine("[VIEWMODEL] No disks selected, setting to 'Ninguno'");
                Console.WriteLine("[VIEWMODEL] No disks selected, setting to 'Ninguno'");
            }
            else
            {
                var diskList = string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})"));
                SelectedDisksInfo = $"Discos seleccionados ({selectedDisks.Count}): {diskList}";
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks: {diskList}");
                Console.WriteLine($"[VIEWMODEL] Selected disks: {diskList}");
            }
        }

        private void UpdateCommandStates()
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] Updating command states");
            Console.WriteLine("[VIEWMODEL] Updating command states");
            
            // Forzar actualización de comandos
            CommandManager.InvalidateRequerySuggested();
        }

        private bool CanAlwaysExecute(object? parameter)
        {
            // Siempre retornar true para que los botones estén activos (modo prueba)
            bool canExecute = !IsWorking;
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] CanAlwaysExecute: IsWorking={IsWorking}, Result={canExecute}");
            Console.WriteLine($"[VIEWMODEL] CanAlwaysExecute: IsWorking={IsWorking}, Result={canExecute}");
            return canExecute;
        }

        private void ExecuteRefreshDisks(object? parameter)
        {
            RefreshDisks();
        }

        private void RefreshDisks()
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] RefreshDisks called");
            Console.WriteLine("[VIEWMODEL] RefreshDisks called");
            
            IsWorking = true;
            StatusMessage = "Actualizando lista de discos...";
            
            var disks = _diskService.GetDisks();
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Got {disks.Count} disks from service");
            Console.WriteLine($"[VIEWMODEL] Got {disks.Count} disks from service");
            
            // Desuscribirse de los eventos de los discos anteriores
            if (_disks != null)
            {
                foreach (var disk in _disks)
                {
                    disk.PropertyChanged -= OnDiskPropertyChanged;
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Unsubscribed from old disk {disk.DriveLetter}");
                    Console.WriteLine($"[VIEWMODEL] Unsubscribed from old disk {disk.DriveLetter}");
                }
            }
            
            Disks.Clear();
            
            foreach (var disk in disks)
            {
                Disks.Add(disk);
                // Suscribirse al cambio de propiedad para actualizar comandos
                disk.PropertyChanged += OnDiskPropertyChanged;
                System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Added and subscribed to disk {disk.DriveLetter}");
                Console.WriteLine($"[VIEWMODEL] Added and subscribed to disk {disk.DriveLetter}");
            }
            
            StatusMessage = $"Se encontraron {disks.Count} discos";
            IsWorking = false;
            
            // Actualizar información de discos seleccionados
            UpdateSelectedDisksInfo();
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private void ExecuteProtectTest(object? parameter)
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] ExecuteProtectTest called");
            Console.WriteLine("[VIEWMODEL] ExecuteProtectTest called");
            
            var selectedDisks = _disks?.Where(d => d.IsSelected).ToList() ?? new List<DiskInfo>();
            string diskInfo = selectedDisks.Count > 0 ? 
                string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})")) : 
                "Ninguno";
            
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] PROTECT BUTTON CLICKED - Test function executed");
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks count: {selectedDisks.Count}");
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            Console.WriteLine($"[VIEWMODEL] PROTECT BUTTON CLICKED - Test function executed");
            Console.WriteLine($"[VIEWMODEL] Selected disks count: {selectedDisks.Count}");
            Console.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            _logger.LogOperation("TEST", "ProtectButton", true, $"Protect button clicked. Selected disks: {diskInfo}");
            
            // Mostrar mensaje de prueba con información de discos seleccionados
            string message = $"¡Botón de Protección presionado!\n\n" +
                           $"Esta es una versión de prueba para verificar el funcionamiento de los botones.\n\n" +
                           $"Discos seleccionados ({selectedDisks.Count}):\n{diskInfo}";
            
            MessageBox.Show(message, 
                          "Prueba de Botones", 
                          MessageBoxButton.OK, 
                          MessageBoxImage.Information);
            
            StatusMessage = $"Botón de Protección presionado (modo prueba) - {selectedDisks.Count} discos seleccionados";
        }

        private void ExecuteUnprotectTest(object? parameter)
        {
            System.Diagnostics.Debug.WriteLine("[VIEWMODEL] ExecuteUnprotectTest called");
            Console.WriteLine("[VIEWMODEL] ExecuteUnprotectTest called");
            
            var selectedDisks = _disks?.Where(d => d.IsSelected).ToList() ?? new List<DiskInfo>();
            string diskInfo = selectedDisks.Count > 0 ? 
                string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})")) : 
                "Ninguno";
            
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] UNPROTECT BUTTON CLICKED - Test function executed");
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks count: {selectedDisks.Count}");
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            Console.WriteLine($"[VIEWMODEL] UNPROTECT BUTTON CLICKED - Test function executed");
            Console.WriteLine($"[VIEWMODEL] Selected disks count: {selectedDisks.Count}");
            Console.WriteLine($"[VIEWMODEL] Selected disks: {diskInfo}");
            
            _logger.LogOperation("TEST", "UnprotectButton", true, $"Unprotect button clicked. Selected disks: {diskInfo}");
            
            // Mostrar mensaje de prueba con información de discos seleccionados
            string message = $"¡Botón de Desprotección presionado!\n\n" +
                           $"Esta es una versión de prueba para verificar el funcionamiento de los botones.\n\n" +
                           $"Discos seleccionados ({selectedDisks.Count}):\n{diskInfo}";
            
            MessageBox.Show(message, 
                          "Prueba de Botones", 
                          MessageBoxButton.OK, 
                          MessageBoxImage.Information);
            
            StatusMessage = $"Botón de Desprotección presionado (modo prueba) - {selectedDisks.Count} discos seleccionados";
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] OnPropertyChanged: {propertyName}");
            Console.WriteLine($"[VIEWMODEL] OnPropertyChanged: {propertyName}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}

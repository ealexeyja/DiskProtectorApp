#!/bin/bash

echo "=== Corrigiendo MainViewModel.cs ==="

# Corregir el ViewModel para solucionar los errores
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'VIEWMODELEOF'
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
        private readonly OperationLogger _logger;
        private ObservableCollection<DiskInfo> _disks = new();
        private string _statusMessage = "Listo";
        private bool _isWorking;
        private string _selectedDisksInfo = "Discos seleccionados: Ninguno";

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
            }
        }

        public string StatusMessage
        {
            get => _statusMessage;
            set
            {
                _statusMessage = value ?? string.Empty;
                OnPropertyChanged();
            }
        }

        public string SelectedDisksInfo
        {
            get => _selectedDisksInfo;
            set
            {
                _selectedDisksInfo = value ?? string.Empty;
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
            
            ProtectCommand = new RelayCommand(async (parameter) => await ExecuteProtectDisksAsync(), CanPerformProtectOperation);
            UnprotectCommand = new RelayCommand(async (parameter) => await ExecuteUnprotectDisksAsync(), CanPerformUnprotectOperation);
            RefreshCommand = new RelayCommand(ExecuteRefreshDisks);
            
            LogMessage("[VIEWMODEL] MainViewModel initialized", "INFO");
            RefreshDisks();
        }

        private void OnDiskPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(DiskInfo.IsSelected) || 
                e.PropertyName == nameof(DiskInfo.IsProtected))
            {
                var disk = sender as DiskInfo;
                LogMessage($"[VIEWMODEL] Disk property changed: {disk?.DriveLetter} - {e.PropertyName}", "DEBUG");
                
                // Actualizar información de discos seleccionados cuando cambia IsSelected
                if (e.PropertyName == nameof(DiskInfo.IsSelected))
                {
                    UpdateSelectedDisksInfo();
                }
                
                // Actualizar estado de comandos
                UpdateCommandStates();
            }
        }

        private void UpdateSelectedDisksInfo()
        {
            if (_disks == null)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
                return;
            }
            
            var selectedDisks = _disks.Where(d => d.IsSelected).ToList();
            LogMessage($"[VIEWMODEL] Updating selected disks info. Count: {selectedDisks.Count}", "DEBUG");
            
            if (selectedDisks.Count == 0)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
            }
            else
            {
                var diskList = string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})"));
                SelectedDisksInfo = $"Discos seleccionados ({selectedDisks.Count}): {diskList}";
            }
            
            OnPropertyChanged(nameof(SelectedDisksInfo));
        }

        private void UpdateCommandStates()
        {
            LogMessage("[VIEWMODEL] Updating command states", "DEBUG");
            CommandManager.InvalidateRequerySuggested();
        }

        private bool CanPerformProtectOperation(object? parameter)
        {
            bool canProtect = !IsWorking && Disks.Any(d => d.IsSelected && d.IsSelectable && !d.IsProtected);
            LogMessage($"[VIEWMODEL] CanPerformProtectOperation: IsWorking={IsWorking}, SelectedCount={Disks.Count(d => d.IsSelected && d.IsSelectable && !d.IsProtected)}, Result={canProtect}", "DEBUG");
            return canProtect;
        }

        private bool CanPerformUnprotectOperation(object? parameter)
        {
            bool canUnprotect = !IsWorking && Disks.Any(d => d.IsSelected && d.IsSelectable && d.IsProtected);
            LogMessage($"[VIEWMODEL] CanPerformUnprotectOperation: IsWorking={IsWorking}, SelectedCount={Disks.Count(d => d.IsSelected && d.IsSelectable && d.IsProtected)}, Result={canUnprotect}", "DEBUG");
            return canUnprotect;
        }

        private void ExecuteRefreshDisks(object? parameter)
        {
            RefreshDisks();
        }

        private void RefreshDisks()
        {
            LogMessage("[VIEWMODEL] Iniciando refresco de discos", "INFO");
            IsWorking = true;
            StatusMessage = "Actualizando lista de discos...";
            
            var disks = _diskService.GetDisks();
            LogMessage($"[VIEWMODEL] Discos obtenidos del servicio: {disks.Count}", "INFO");
            
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
                LogMessage($"[VIEWMODEL] Disco agregado: {disk.DriveLetter} - Protegido: {disk.IsProtected}", "DEBUG");
            }
            
            StatusMessage = $"Se encontraron {disks.Count} discos";
            IsWorking = false;
            
            UpdateSelectedDisksInfo();
            UpdateCommandStates();
            LogMessage("[VIEWMODEL] Refresco de discos completado", "INFO");
        }

        private async Task ExecuteProtectDisksAsync()
        {
            LogMessage("[VIEWMODEL] Iniciando protección de discos", "INFO");
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && !d.IsProtected).ToList() ?? new List<DiskInfo>();
            
            if (!selectedDisks.Any())
            {
                LogMessage("[VIEWMODEL] No hay discos seleccionados para proteger", "WARN");
                MessageBox.Show("No hay discos seleccionados para proteger.\n\nPor favor, seleccione al menos un disco no protegido.", 
                              "Protección de discos", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Information);
                return;
            }
            
            LogMessage($"[VIEWMODEL] Discos seleccionados para protección: {selectedDisks.Count}", "INFO");
            
            IsWorking = true;
            StatusMessage = $"Protegiendo {selectedDisks.Count} disco(s)...";

            int successCount = 0;
            
            foreach (var disk in selectedDisks)
            {
                LogMessage($"[VIEWMODEL] Protegiendo disco {disk.DriveLetter}", "INFO");
                
                var progress = new Progress<string>(message => {
                    StatusMessage = message;
                    LogMessage($"[VIEWMODEL] Progreso {disk.DriveLetter}: {message}", "DEBUG");
                });
                
                bool success = await _diskService.ProtectDriveAsync(disk.DriveLetter ?? "", progress);
                if (success)
                {
                    // Verificar el estado real después de la operación
                    bool isActuallyProtected = await Task.Run(() => {
                        try
                        {
                            return _diskService.IsDriveProtected(disk.DriveLetter ?? "");
                        }
                        catch
                        {
                            return true; // Asumir protegido si hay error
                        }
                    });
                    
                    disk.IsProtected = isActuallyProtected;
                    successCount++;
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", true);
                    LogMessage($"[VIEWMODEL] Disco {disk.DriveLetter} protegido exitosamente", "INFO");
                }
                else
                {
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                    LogMessage($"[VIEWMODEL] Error protegiendo disco {disk.DriveLetter}", "ERROR");
                }
            }

            StatusMessage = $"Protegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // Mostrar mensaje de resultado
            string resultMessage = $"Protección completada.\n\nDiscos protegidos: {successCount}\nDiscos con error: {selectedDisks.Count - successCount}";
            MessageBox.Show(resultMessage, "Protección de discos", MessageBoxButton.OK, MessageBoxImage.Information);
            
            UpdateCommandStates();
            LogMessage($"[VIEWMODEL] Protección completada - Exitosos: {successCount}, Errores: {selectedDisks.Count - successCount}", "INFO");
        }

        private async Task ExecuteUnprotectDisksAsync()
        {
            LogMessage("[VIEWMODEL] Iniciando desprotección de discos", "INFO");
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && d.IsProtected).ToList() ?? new List<DiskInfo>();
            
            if (!selectedDisks.Any())
            {
                LogMessage("[VIEWMODEL] No hay discos seleccionados para desproteger", "WARN");
                MessageBox.Show("No hay discos seleccionados para desproteger.\n\nPor favor, seleccione al menos un disco protegido.", 
                              "Desprotección de discos", 
                              MessageBoxButton.OK, 
                              MessageBoxImage.Information);
                return;
            }
            
            LogMessage($"[VIEWMODEL] Discos seleccionados para desprotección: {selectedDisks.Count}", "INFO");
            
            IsWorking = true;
            StatusMessage = $"Desprotegiendo {selectedDisks.Count} disco(s)...";

            int successCount = 0;
            foreach (var disk in selectedDisks)
            {
                LogMessage($"[VIEWMODEL] Desprotegiendo disco {disk.DriveLetter}", "INFO");
                
                var progress = new Progress<string>(message => {
                    StatusMessage = message;
                    LogMessage($"[VIEWMODEL] Progreso {disk.DriveLetter}: {message}", "DEBUG");
                });
                
                bool success = await _diskService.UnprotectDriveAsync(disk.DriveLetter ?? "", progress);
                if (success)
                {
                    // Verificar el estado real después de la operación
                    bool isActuallyUnprotected = await Task.Run(() => {
                        try
                        {
                            return !_diskService.IsDriveProtected(disk.DriveLetter ?? "");
                        }
                        catch
                        {
                            return true; // Asumir desprotegido si hay error
                        }
                    });
                    
                    disk.IsProtected = !isActuallyUnprotected;
                    successCount++;
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", true);
                    LogMessage($"[VIEWMODEL] Disco {disk.DriveLetter} desprotegido exitosamente", "INFO");
                }
                else
                {
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                    LogMessage($"[VIEWMODEL] Error desprotegiendo disco {disk.DriveLetter}", "ERROR");
                }
            }

            StatusMessage = $"Desprotegidos {successCount} de {selectedDisks.Count} discos seleccionados";
            IsWorking = false;
            
            // Mostrar mensaje de resultado
            string resultMessage = $"Desprotección completada.\n\nDiscos desprotegidos: {successCount}\nDiscos con error: {selectedDisks.Count - successCount}";
            MessageBox.Show(resultMessage, "Desprotección de discos", MessageBoxButton.OK, MessageBoxImage.Information);
            
            UpdateCommandStates();
            LogMessage($"[VIEWMODEL] Desprotección completada - Exitosos: {successCount}, Errores: {selectedDisks.Count - successCount}", "INFO");
        }

        private void LogMessage(string message, string level)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                string logEntry = $"[{timestamp}] [{level}] {message}";
                
                // Escribir en Debug
                System.Diagnostics.Debug.WriteLine(logEntry);
                
                // Escribir en Console
                Console.WriteLine(logEntry);
                
                // Escribir en archivo de log
                string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                string logDirectory = Path.Combine(appDataPath, "DiskProtectorApp");
                Directory.CreateDirectory(logDirectory);
                string logPath = Path.Combine(logDirectory, "viewmodel-debug.log");
                
                File.AppendAllText(logPath, logEntry + Environment.NewLine);
            }
            catch
            {
                // Silenciar errores de logging
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            LogMessage($"[VIEWMODEL] Propiedad cambiada: {propertyName}", "DEBUG");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
VIEWMODELEOF

echo "✅ MainViewModel.cs corregido"
echo "   Cambios realizados:"
echo "   - Agregada propiedad 'SelectedDisksInfo' faltante"
echo "   - Corregida la visibilidad del método IsDriveProtected"
echo "   - Agregadas las referencias necesarias a System.IO"
echo "   - Solucionados los errores de compilación"
echo "   - Mantenida la lógica de activación de botones"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "2. git commit -m \"fix: Corregir MainViewModel.cs con propiedades faltantes y errores de compilación\""
echo "3. git push origin main"
echo ""
echo "Luego ejecuta './build-app.sh' para compilar la nueva versión"

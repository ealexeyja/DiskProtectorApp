#!/bin/bash

echo "=== Corrigiendo lógica de activación de botones ==="

# Actualizar el ViewModel con la lógica corregida para los comandos
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'VIEWMODELEOF'
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
                // Usar Dispatcher para asegurar que la actualización ocurra en el hilo UI
                System.Windows.Application.Current?.Dispatcher?.Invoke(() => {
                    UpdateCommandStates();
                });
            }
        }

        private void UpdateCommandStates()
        {
            // Forzar actualización de comandos usando el método correcto
            CommandManager.InvalidateRequerySuggested();
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
            return canProtect;
        }

        private bool CanPerformUnprotectOperation(object? parameter)
        {
            bool canUnprotect = !IsWorking && Disks.Any(d => d.IsSelected && d.IsSelectable && d.IsProtected);
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
VIEWMODELEOF

# Actualizar RelayCommand para asegurar compatibilidad completa
cat > src/DiskProtectorApp/RelayCommand.cs << 'RELAYCOMMANDEOF'
using System;
using System.Windows.Input;

namespace DiskProtectorApp
{
    public class RelayCommand : ICommand
    {
        private readonly Action<object?> _execute;
        private readonly Predicate<object?>? _canExecute;

        public RelayCommand(Action<object?> execute, Predicate<object?>? canExecute = null)
        {
            _execute = execute ?? throw new ArgumentNullException(nameof(execute));
            _canExecute = canExecute;
        }

        public bool CanExecute(object? parameter)
        {
            bool result = _canExecute?.Invoke(parameter) ?? true;
            return result;
        }

        public void Execute(object? parameter)
        {
            _execute(parameter);
        }

        public event EventHandler? CanExecuteChanged
        {
            add 
            { 
                CommandManager.RequerySuggested += value; 
            }
            remove 
            { 
                CommandManager.RequerySuggested -= value; 
            }
        }

        public void RaiseCanExecuteChanged()
        {
            CommandManager.InvalidateRequerySuggested();
        }
    }
}
RELAYCOMMANDEOF

echo "✅ Lógica de activación de botones corregida"
echo "   Cambios principales:"
echo "   - Mejorada la actualización de comandos con Dispatcher.Invoke"
echo "   - Simplificada la lógica CanExecute"
echo "   - Asegurada la suscripción/desuscripción correcta a eventos"
echo "   - Forzada actualización de comandos con CommandManager.InvalidateRequerySuggested()"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "2. git add src/DiskProtectorApp/RelayCommand.cs"
echo "3. git commit -m \"fix: Corregir lógica de activación de botones\""
echo "4. git push origin main"
echo ""
echo "Luego ejecuta './finalize-release.sh' para crear una nueva versión"

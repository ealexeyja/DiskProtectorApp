#!/bin/bash

echo "=== Corrigiendo errores de compilación ==="

# Actualizar el ViewModel con las correcciones necesarias
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'VIEWMODELEOF'
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
            System.Diagnostics.Debug.WriteLine($"Updating selected disks info. Count: {selectedDisks.Count}");
            
            if (selectedDisks.Count == 0)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
            }
            else
            {
                var diskList = string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})"));
                SelectedDisksInfo = $"Discos seleccionados ({selectedDisks.Count}): {diskList}";
                System.Diagnostics.Debug.WriteLine($"Selected disks: {diskList}");
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
            // Siempre retornar true para que los botones estén activos (modo prueba)
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
            if (_disks != null)
            {
                foreach (var disk in _disks)
                {
                    disk.PropertyChanged -= OnDiskPropertyChanged;
                }
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
            
            // Actualizar información de discos seleccionados
            UpdateSelectedDisksInfo();
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private void ExecuteProtectTest(object? parameter)
        {
            var selectedDisks = _disks?.Where(d => d.IsSelected).ToList() ?? new List<DiskInfo>();
            string diskInfo = selectedDisks.Count > 0 ? 
                string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})")) : 
                "Ninguno";
            
            System.Diagnostics.Debug.WriteLine("PROTECT BUTTON CLICKED - Test function executed");
            System.Diagnostics.Debug.WriteLine($"Selected disks count: {selectedDisks.Count}");
            System.Diagnostics.Debug.WriteLine($"Selected disks: {diskInfo}");
            
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
            var selectedDisks = _disks?.Where(d => d.IsSelected).ToList() ?? new List<DiskInfo>();
            string diskInfo = selectedDisks.Count > 0 ? 
                string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})")) : 
                "Ninguno";
            
            System.Diagnostics.Debug.WriteLine("UNPROTECT BUTTON CLICKED - Test function executed");
            System.Diagnostics.Debug.WriteLine($"Selected disks count: {selectedDisks.Count}");
            System.Diagnostics.Debug.WriteLine($"Selected disks: {diskInfo}");
            
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
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
VIEWMODELEOF

echo "✅ Errores de compilación corregidos"
echo "   Cambios principales:"
echo "   - Agregada directiva using para System.Collections.Generic"
echo "   - Corregido uso de métodos LINQ (añadido paréntesis para invocar)"
echo "   - Mejorado manejo de null en listas"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "2. git commit -m \"fix: Corregir errores de compilación\""
echo "3. git push origin main"
echo ""
echo "Para compilar y generar el release:"
echo "./build-and-release.sh"

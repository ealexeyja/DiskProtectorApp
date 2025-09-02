#!/bin/bash

echo "=== Creando versión de prueba para botones ==="

# Actualizar el ViewModel con funciones de prueba simples
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'VIEWMODELEOF'
using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using System;
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

        private void ExecuteProtectTest(object? parameter)
        {
            System.Diagnostics.Debug.WriteLine("PROTECT BUTTON CLICKED - Test function executed");
            _logger.LogOperation("TEST", "ProtectButton", true, "Protect button clicked for testing");
            
            // Mostrar mensaje de prueba
            MessageBox.Show("¡Botón de Protección presionado!\n\nEsta es una versión de prueba para verificar el funcionamiento de los botones.", 
                          "Prueba de Botones", 
                          MessageBoxButton.OK, 
                          MessageBoxImage.Information);
            
            StatusMessage = "Botón de Protección presionado (modo prueba)";
        }

        private void ExecuteUnprotectTest(object? parameter)
        {
            System.Diagnostics.Debug.WriteLine("UNPROTECT BUTTON CLICKED - Test function executed");
            _logger.LogOperation("TEST", "UnprotectButton", true, "Unprotect button clicked for testing");
            
            // Mostrar mensaje de prueba
            MessageBox.Show("¡Botón de Desprotección presionado!\n\nEsta es una versión de prueba para verificar el funcionamiento de los botones.", 
                          "Prueba de Botones", 
                          MessageBoxButton.OK, 
                          MessageBoxImage.Information);
            
            StatusMessage = "Botón de Desprotección presionado (modo prueba)";
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
VIEWMODELEOF

echo "✅ Versión de prueba creada para verificar botones"
echo "   Cambios principales:"
echo "   - Funciones de prueba simples que muestran mensaje y registran en log"
echo "   - Eliminadas las funciones complejas de protección/desprotección"
echo "   - Mantenidos los logs de debug para diagnóstico"
echo ""
echo "Para compilar y generar el build:"
echo "1. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "2. git commit -m \"test: Versión de prueba para verificar botones\""
echo "3. git push origin main"
echo ""
echo "Para compilar y generar el release:"
echo "./build-and-release.sh"

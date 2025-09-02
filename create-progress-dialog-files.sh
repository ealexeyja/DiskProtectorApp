#!/bin/bash

echo "=== Creando archivos de diálogo de progreso ==="

# Crear el archivo XAML para el diálogo de progreso
mkdir -p src/DiskProtectorApp/Views

cat > src/DiskProtectorApp/Views/ProgressDialog.xaml << 'PROGRESSDIALOGXAMLEOF'
<controls:MetroWindow x:Class="DiskProtectorApp.Views.ProgressDialog"
                      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                      xmlns:controls="http://metro.mahapps.com/winfx/xaml/controls"
                      Title="Procesando..." 
                      Height="150" 
                      Width="400"
                      WindowStartupLocation="CenterOwner"
                      ResizeMode="NoResize"
                      ShowInTaskbar="False"
                      Topmost="True"
                      GlowBrush="{DynamicResource AccentColorBrush}">
    
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock x:Name="OperationText" 
                   Text="Procesando discos..." 
                   FontSize="14" 
                   Margin="0,0,0,10"
                   Grid.Row="0"/>
        
        <ProgressBar x:Name="ProgressBar" 
                     IsIndeterminate="True" 
                     Height="10" 
                     Margin="0,0,0,10"
                     Grid.Row="1"/>
        
        <TextBlock x:Name="ProgressText" 
                   Text="Iniciando..." 
                   FontSize="12" 
                   Foreground="{DynamicResource MahApps.Brushes.Gray3}"
                   Grid.Row="2"/>
    </Grid>
</controls:MetroWindow>
PROGRESSDIALOGXAMLEOF

# Crear el code-behind para el diálogo de progreso
cat > src/DiskProtectorApp/Views/ProgressDialog.xaml.cs << 'PROGRESSDIALOGCSHARPEOF'
using MahApps.Metro.Controls;
using System.Windows;

namespace DiskProtectorApp.Views
{
    public partial class ProgressDialog : MetroWindow
    {
        public ProgressDialog()
        {
            InitializeComponent();
        }

        public void UpdateProgress(string operation, string progress)
        {
            OperationText.Text = operation;
            ProgressText.Text = progress;
        }

        public void SetProgressIndeterminate(bool isIndeterminate)
        {
            ProgressBar.IsIndeterminate = isIndeterminate;
        }
    }
}
PROGRESSDIALOGCSHARPEOF

# Actualizar el MainViewModel para asegurar que tiene la referencia correcta
cat > src/DiskProtectorApp/ViewModels/MainViewModel.cs << 'MAINVIEWMODELEOF'
using DiskProtectorApp.Models;
using DiskProtectorApp.Services;
using DiskProtectorApp.Views;  // Asegurarse de que esta referencia exista
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
                
                _disks = value ?? new ObservableCollection<DiskInfo>(); // Corrección CS8601: Asegurar que nunca sea null
                
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

        public string DiagnosticInfo
        {
            get => _diagnosticInfo;
            set
            {
                _diagnosticInfo = value ?? string.Empty;
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
            
            ProtectCommand = new RelayCommand(async (parameter) => await ExecuteProtectDisksAsync(), CanAlwaysExecute);
            UnprotectCommand = new RelayCommand(async (parameter) => await ExecuteUnprotectDisksAsync(), CanAlwaysExecute);
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
                    UpdateSelectedDisksInfo();
                }
                
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

        private void UpdateSelectedDisksInfo()
        {
            if (_disks == null)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
                return;
            }
            
            var selectedDisks = _disks.Where(d => d.IsSelected).ToList();
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Updating selected disks info. Count: {selectedDisks.Count}");
            Console.WriteLine($"[VIEWMODEL] Updating selected disks info. Count: {selectedDisks.Count}");
            
            if (selectedDisks.Count == 0)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
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
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] CanExecute check: IsWorking={IsWorking}, Result={canExecute}");
            Console.WriteLine($"[VIEWMODEL] CanExecute check: IsWorking={IsWorking}, Result={canExecute}");
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
            
            // Actualizar información de discos seleccionados
            UpdateSelectedDisksInfo();
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private async Task ExecuteProtectDisksAsync()
        {
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && !d.IsProtected).ToList() ?? new List<DiskInfo>();
            if (!selectedDisks.Any()) return;

            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Protecting {selectedDisks.Count} disks");
            Console.WriteLine($"[VIEWMODEL] Protecting {selectedDisks.Count} disks");
            
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
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Successfully protected disk {disk.DriveLetter}");
                    Console.WriteLine($"[VIEWMODEL] Successfully protected disk {disk.DriveLetter}");
                }
                else
                {
                    _logger.LogOperation("Proteger", disk.DriveLetter ?? "Desconocido", false, "Error al aplicar permisos");
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Failed to protect disk {disk.DriveLetter}");
                    Console.WriteLine($"[VIEWMODEL] Failed to protect disk {disk.DriveLetter}");
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

        private async Task ExecuteUnprotectDisksAsync()
        {
            var selectedDisks = _disks?.Where(d => d.IsSelected && d.IsSelectable && d.IsProtected).ToList() ?? new List<DiskInfo>();
            if (!selectedDisks.Any()) return;

            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Unprotecting {selectedDisks.Count} disks");
            Console.WriteLine($"[VIEWMODEL] Unprotecting {selectedDisks.Count} disks");
            
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
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Successfully unprotected disk {disk.DriveLetter}");
                    Console.WriteLine($"[VIEWMODEL] Successfully unprotected disk {disk.DriveLetter}");
                }
                else
                {
                    _logger.LogOperation("Desproteger", disk.DriveLetter ?? "Desconocido", false, "Error al remover permisos");
                    System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] Failed to unprotect disk {disk.DriveLetter}");
                    Console.WriteLine($"[VIEWMODEL] Failed to unprotect disk {disk.DriveLetter}");
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
            System.Diagnostics.Debug.WriteLine($"[VIEWMODEL] OnPropertyChanged: {propertyName}");
            Console.WriteLine($"[VIEWMODEL] OnPropertyChanged: {propertyName}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
MAINVIEWMODELEOF

echo "✅ Archivos de diálogo de progreso creados y referencias corregidas"
echo "   Archivos creados:"
echo "   - src/DiskProtectorApp/Views/ProgressDialog.xaml"
echo "   - src/DiskProtectorApp/Views/ProgressDialog.xaml.cs"
echo "   - Referencia añadida en MainViewModel.cs"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/Views/ProgressDialog.xaml"
echo "2. git add src/DiskProtectorApp/Views/ProgressDialog.xaml.cs"
echo "3. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "4. git commit -m \"fix: Crear ProgressDialog y corregir referencias\""
echo "5. git push origin main"
echo ""
echo "Luego ejecuta './build-and-release.sh' para generar el release"

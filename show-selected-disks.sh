#!/bin/bash

echo "=== Actualizando para mostrar discos seleccionados ==="

# Actualizar el ViewModel para mostrar discos seleccionados
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
                
                // Actualizar información de discos seleccionados
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
            var selectedDisks = Disks.Where(d => d.IsSelected).ToList();
            if (selectedDisks.Count == 0)
            {
                SelectedDisksInfo = "Discos seleccionados: Ninguno";
            }
            else
            {
                var diskList = string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})"));
                SelectedDisksInfo = $"Discos seleccionados ({selectedDisks.Count}): {diskList}";
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
            
            // Actualizar información de discos seleccionados
            UpdateSelectedDisksInfo();
            
            // Actualizar estado de los comandos
            UpdateCommandStates();
        }

        private void ExecuteProtectTest(object? parameter)
        {
            var selectedDisks = Disks.Where(d => d.IsSelected).ToList();
            string diskInfo = selectedDisks.Count > 0 ? 
                string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})")) : 
                "Ninguno";
            
            System.Diagnostics.Debug.WriteLine("PROTECT BUTTON CLICKED - Test function executed");
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
            var selectedDisks = Disks.Where(d => d.IsSelected).ToList();
            string diskInfo = selectedDisks.Count > 0 ? 
                string.Join(", ", selectedDisks.Select(d => $"{d.DriveLetter} ({d.VolumeName})")) : 
                "Ninguno";
            
            System.Diagnostics.Debug.WriteLine("UNPROTECT BUTTON CLICKED - Test function executed");
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

# Actualizar MainWindow.xaml para mostrar la información de discos seleccionados
cat > src/DiskProtectorApp/Views/MainWindow.xaml << 'MAINWINDOWXAMLEOF'
<controls:MetroWindow x:Class="DiskProtectorApp.Views.MainWindow"
                      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                      xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
                      xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
                      xmlns:controls="http://metro.mahapps.com/winfx/xaml/controls"
                      xmlns:iconPacks="http://metro.mahapps.com/winfx/xaml/iconpacks"
                      mc:Ignorable="d"
                      Title="DiskProtectorApp v1.2.0" Height="650" Width="1000"
                      WindowStartupLocation="CenterScreen"
                      GlowBrush="{DynamicResource AccentColorBrush}"
                      BorderThickness="1"
                      BorderBrush="{DynamicResource AccentColorBrush}"
                      Background="{DynamicResource MahApps.Brushes.ThemeBackground}"
                      Foreground="{DynamicResource MahApps.Brushes.Text}">
    
    <controls:MetroWindow.RightWindowCommands>
        <controls:WindowCommands>
            <Button Content="Ayuda" Click="HelpButton_Click"/>
        </controls:WindowCommands>
    </controls:MetroWindow.RightWindowCommands>
    
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Barra de herramientas -->
        <ToolBarTray Grid.Row="0" Background="{DynamicResource MahApps.Brushes.Gray10}">
            <ToolBar Style="{DynamicResource MahApps.Styles.ToolBar}" Background="{DynamicResource MahApps.Brushes.Gray10}">
                <Button Command="{Binding RefreshCommand}" 
                        ToolTip="Actualizar lista de discos">
                    <StackPanel Orientation="Horizontal">
                        <iconPacks:PackIconMaterial Kind="Refresh" VerticalAlignment="Center"/>
                        <TextBlock Margin="5,0,0,0" Text="Actualizar" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                
                <Separator/>
                
                <Button Command="{Binding ProtectCommand}" 
                        ToolTip="Proteger discos seleccionados">
                    <StackPanel Orientation="Horizontal">
                        <iconPacks:PackIconMaterial Kind="ShieldLock" VerticalAlignment="Center"/>
                        <TextBlock Margin="5,0,0,0" Text="Proteger" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                
                <Button Command="{Binding UnprotectCommand}" 
                        ToolTip="Desproteger discos seleccionados">
                    <StackPanel Orientation="Horizontal">
                        <iconPacks:PackIconMaterial Kind="ShieldOff" VerticalAlignment="Center"/>
                        <TextBlock Margin="5,0,0,0" Text="Desproteger" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
            </ToolBar>
        </ToolBarTray>
        
        <!-- Información de discos seleccionados -->
        <Border Grid.Row="1" 
                Background="{DynamicResource MahApps.Brushes.Gray10}" 
                Padding="10,5" 
                BorderBrush="{DynamicResource MahApps.Brushes.Gray8}" 
                BorderThickness="0,0,0,1">
            <TextBlock Text="{Binding SelectedDisksInfo}" 
                       TextWrapping="Wrap" 
                       FontSize="12"
                       Foreground="{DynamicResource MahApps.Brushes.Text}"/>
        </Border>
        
        <!-- Lista de discos -->
        <DataGrid Grid.Row="2" 
                  ItemsSource="{Binding Disks}" 
                  AutoGenerateColumns="False"
                  CanUserAddRows="False"
                  CanUserDeleteRows="False"
                  CanUserReorderColumns="False"
                  CanUserResizeRows="False"
                  SelectionMode="Single"
                  GridLinesVisibility="Horizontal"
                  HeadersVisibility="Column"
                  IsReadOnly="True"
                  Margin="10">
            
            <DataGrid.Columns>
                <DataGridTemplateColumn Header="Seleccionar" Width="Auto">
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <CheckBox IsChecked="{Binding IsSelected, Mode=TwoWay}" 
                                      IsEnabled="{Binding IsSelectable}"
                                      HorizontalAlignment="Center" 
                                      VerticalAlignment="Center"/>
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
                
                <DataGridTextColumn Header="Letra" 
                                    Binding="{Binding DriveLetter}" 
                                    Width="Auto"/>
                
                <DataGridTextColumn Header="Nombre" 
                                    Binding="{Binding VolumeName}" 
                                    Width="*"/>
                
                <DataGridTextColumn Header="Capacidad" 
                                    Binding="{Binding TotalSize}" 
                                    Width="Auto"/>
                
                <DataGridTextColumn Header="Libre" 
                                    Binding="{Binding FreeSpace}" 
                                    Width="Auto"/>
                
                <DataGridTextColumn Header="Sistema" 
                                    Binding="{Binding FileSystem}" 
                                    Width="Auto"/>
                
                <DataGridTextColumn Header="Tipo" 
                                    Binding="{Binding DiskType}" 
                                    Width="Auto"/>
                
                <DataGridTemplateColumn Header="Estado" Width="Auto">
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <StackPanel Orientation="Horizontal">
                                <Ellipse Width="12" Height="12" Margin="0,0,5,0">
                                    <Ellipse.Style>
                                        <Style TargetType="Ellipse">
                                            <Setter Property="Fill" Value="#F44336"/>
                                            <Style.Triggers>
                                                <DataTrigger Binding="{Binding IsProtected}" Value="True">
                                                    <Setter Property="Fill" Value="#4CAF50"/>
                                                </DataTrigger>
                                                <DataTrigger Binding="{Binding IsSelectable}" Value="False">
                                                    <Setter Property="Fill" Value="#9E9E9E"/>
                                                </DataTrigger>
                                            </Style.Triggers>
                                        </Style>
                                    </Ellipse.Style>
                                </Ellipse>
                                <TextBlock Text="{Binding ProtectionStatus}" VerticalAlignment="Center">
                                    <TextBlock.Style>
                                        <Style TargetType="TextBlock">
                                            <Style.Triggers>
                                                <DataTrigger Binding="{Binding IsSelectable}" Value="False">
                                                    <Setter Property="Foreground" Value="#9E9E9E"/>
                                                </DataTrigger>
                                            </Style.Triggers>
                                        </Style>
                                    </TextBlock.Style>
                                </TextBlock>
                            </StackPanel>
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
            </DataGrid.Columns>
        </DataGrid>
        
        <!-- Barra de estado -->
        <StatusBar Grid.Row="3" Background="{DynamicResource MahApps.Brushes.Gray10}">
            <StatusBarItem>
                <StackPanel Orientation="Horizontal">
                    <controls:ProgressRing IsActive="{Binding IsWorking}" 
                                           Width="16" Height="16" 
                                           Margin="0,0,10,0"/>
                    <TextBlock Text="{Binding StatusMessage}" 
                               VerticalAlignment="Center"/>
                </StackPanel>
            </StatusBarItem>
        </StatusBar>
    </Grid>
</controls:MetroWindow>
MAINWINDOWXAMLEOF

echo "✅ Actualización completada para mostrar discos seleccionados"
echo "   Cambios principales:"
echo "   - Agregada propiedad SelectedDisksInfo en el ViewModel"
echo "   - Actualizada la interfaz para mostrar discos seleccionados"
echo "   - Mejorada la información en los mensajes de prueba"
echo "   - Agregada sección de información en la ventana principal"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/ViewModels/MainViewModel.cs"
echo "2. git add src/DiskProtectorApp/Views/MainWindow.xaml"
echo "3. git commit -m \"feat: Mostrar discos seleccionados en la interfaz\""
echo "4. git push origin main"
echo ""
echo "Para compilar y generar el release:"
echo "./build-and-release.sh"

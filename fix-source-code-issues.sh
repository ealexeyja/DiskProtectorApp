#!/bin/bash

echo "=== Corrigiendo problemas del código fuente ==="

# Crear estructura de recursos correcta
mkdir -p src/DiskProtectorApp/Resources

# Corregir el archivo de proyecto para referenciar correctamente los recursos
cat > src/DiskProtectorApp/DiskProtectorApp.csproj << 'PROJECTEOF'
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows</TargetFramework>
    <Nullable>enable</Nullable>
    <UseWPF>true</UseWPF>
    <ApplicationManifest>app.manifest</ApplicationManifest>
    <PlatformTarget>x64</PlatformTarget>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <SelfContained>false</SelfContained>
    <ApplicationIcon>Resources/app.ico</ApplicationIcon>
    
    <!-- Configuración de versionado completa -->
    <Version>1.2.6</Version>
    <AssemblyVersion>1.2.6.0</AssemblyVersion>
    <FileVersion>1.2.6.0</FileVersion>
    <InformationalVersion>1.2.6</InformationalVersion>
    
    <!-- Propiedades adicionales para el ejecutable -->
    <Product>DiskProtectorApp</Product>
    <AssemblyTitle>Disk Protector Application</AssemblyTitle>
    <AssemblyDescription>Aplicación para protección de discos mediante gestión de permisos NTFS</AssemblyDescription>
    <AssemblyCompany>Emigdio Alexey Jimenez Acosta</AssemblyCompany>
    <AssemblyCopyright>Copyright © Emigdio Alexey Jimenez Acosta 2024</AssemblyCopyright>
    <AssemblyTrademark></AssemblyTrademark>
    
    <!-- Habilitar targeting de Windows en Linux -->
    <EnableWindowsTargeting>true</EnableWindowsTargeting>
    <!-- Configuración adicional para mejor diagnóstico -->
    <DebugType>portable</DebugType>
    <DebugSymbols>true</DebugSymbols>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="MahApps.Metro" Version="2.4.10" />
    <PackageReference Include="MahApps.Metro.IconPacks" Version="4.11.0" />
    <PackageReference Include="ControlzEx" Version="5.0.2" />
    <PackageReference Include="Microsoft.Xaml.Behaviors.Wpf" Version="1.1.77" />
    <PackageReference Include="System.Management" Version="8.0.0" />
  </ItemGroup>

  <ItemGroup>
    <None Remove="Resources/app.ico" />
    <None Remove="Resources/shield-protected.png" />
    <None Remove="Resources/shield-unprotected.png" />
  </ItemGroup>

  <ItemGroup>
    <Resource Include="Resources/app.ico" />
    <Resource Include="Resources/shield-protected.png" />
    <Resource Include="Resources/shield-unprotected.png" />
  </ItemGroup>

</Project>
PROJECTEOF

# Corregir MainWindow.xaml para usar la ruta correcta del icono
cat > src/DiskProtectorApp/Views/MainWindow.xaml << 'MAINWINDOWXAMLEOF'
<controls:MetroWindow x:Class="DiskProtectorApp.Views.MainWindow"
                      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                      xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
                      xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
                      xmlns:controls="http://metro.mahapps.com/winfx/xaml/controls"
                      xmlns:iconPacks="http://metro.mahapps.com/winfx/xaml/iconpacks"
                      mc:Ignorable="d"
                      Title="DiskProtectorApp v1.2.6" Height="600" Width="1000"
                      WindowStartupLocation="CenterScreen"
                      GlowBrush="{DynamicResource AccentColorBrush}"
                      BorderThickness="1"
                      BorderBrush="{DynamicResource AccentColorBrush}"
                      Background="{DynamicResource MahApps.Brushes.ThemeBackground}"
                      Foreground="{DynamicResource MahApps.Brushes.Text}"
                      Icon="pack://application:,,,/DiskProtectorApp;component/Resources/app.ico">
    
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
                
                <Separator/>
                
                <Button Command="{Binding AdminManageCommand}" 
                        ToolTip="Administrar discos no seleccionables">
                    <StackPanel Orientation="Horizontal">
                        <iconPacks:PackIconMaterial Kind="ShieldAccount" VerticalAlignment="Center"/>
                        <TextBlock Margin="5,0,0,0" Text="Administrar" VerticalAlignment="Center"/>
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

# Corregir MainWindow.xaml.cs para manejar el botón de administración
cat > src/DiskProtectorApp/Views/MainWindow.xaml.cs << 'MAINWINDOWCSHARPEOF'
using DiskProtectorApp.ViewModels;
using MahApps.Metro.Controls;
using System;
using System.Diagnostics;
using System.IO;
using System.Windows;

namespace DiskProtectorApp.Views
{
    public partial class MainWindow : MetroWindow
    {
        private string logPath;

        public MainWindow()
        {
            InitializeComponent();
            
            // Configurar logging
            string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string logDirectory = Path.Combine(appDataPath, "DiskProtectorApp");
            Directory.CreateDirectory(logDirectory);
            logPath = Path.Combine(logDirectory, "app-debug.log");
            
            LogMessage("MainWindow constructor starting...");
            
            try
            {
                // Actualizar el título con la versión de la aplicación
                var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
                if (version != null)
                {
                    this.Title = $"DiskProtectorApp v{version.Major}.{version.Minor}.{version.Build}";
                }
                
                DataContext = new MainViewModel();
                LogMessage("MainWindow initialized successfully");
            }
            catch (Exception ex)
            {
                LogMessage($"Error initializing MainWindow: {ex}");
                MessageBox.Show($"Error al inicializar la ventana principal:\n{ex.Message}\n\n{ex.StackTrace}", 
                                "Error de inicialización", 
                                MessageBoxButton.OK, 
                                MessageBoxImage.Error);
            }
        }

        private void HelpButton_Click(object sender, RoutedEventArgs e)
        {
            var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
            string versionText = version != null ? $"v{version.Major}.{version.Minor}.{version.Build}" : "v1.2.6";
            
            var helpText = $@"INFORMACIÓN DEL DESARROLLADOR:
- Nombre: Emigdio Alexey Jimenez Acosta
- Email: ealexeyja@gmail.com
- Teléfono: +53 5586 0259

DESCRIPCIÓN:
Aplicación para protección de discos mediante gestión de permisos NTFS.

⚠️ REQUERIMIENTOS TÉCNICOS:

🔷 EJECUCIÓN COMO ADMINISTRADOR:
• La aplicación DEBE ejecutarse con privilegios de administrador
• Click derecho → ""Ejecutar como administrador""

🔷 RUNTIME NECESARIO:
• Microsoft .NET 8.0 Desktop Runtime x64
• Descargar desde: https://dotnet.microsoft.com/download/dotnet/8.0  

🔷 SISTEMA OPERATIVO:
• Windows 10/11 x64
• Sistema de archivos NTFS

INSTRUCCIONES DE USO:
1. Ejecutar DiskProtectorApp.exe como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Click en el botón correspondiente
4. Esperar confirmación de la operación

FUNCIONAMIENTO DE PERMISOS:
• DISCO DESPROTEGIDO (NORMAL):
  - Grupo "Usuarios" tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
  - Grupo "Usuarios autenticados" tiene permisos de modificación/escritura
  - Grupo "Administradores" y "SYSTEM" tienen Control Total (siempre)

• DISCO PROTEGIDO:
  - Grupo "Usuarios" NO tiene permisos establecidos
  - Grupo "Usuarios autenticados" solo tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
  - Grupo "Administradores" y "SYSTEM" mantienen Control Total (siempre)

REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\operations.log
• Se conservan los últimos 30 días de registros

LOGS DE DIAGNÓSTICO:
• Logs detallados en:
• %APPDATA%\DiskProtectorApp\app-debug.log
• Niveles: INFO, DEBUG, WARN, ERROR, VERBOSE

 Versión actual: v1.2.6";

            MessageBox.Show(helpText, "Ayuda de DiskProtectorApp", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void LogMessage(string message)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                string logEntry = $"[{timestamp}] {message}";
                
                // Escribir en Debug
                Debug.WriteLine(logEntry);
                
                // Escribir en Console
                Console.WriteLine(logEntry);
                
                // Escribir en archivo de log
                File.AppendAllText(logPath, logEntry + Environment.NewLine);
            }
            catch
            {
                // Silenciar errores de logging
            }
        }

        protected override void OnContentRendered(EventArgs e)
        {
            base.OnContentRendered(e);
            LogMessage("MainWindow content rendered");
        }
    }
}
MAINWINDOWCSHARPEOF

echo "✅ Problemas del código fuente corregidos"
echo "   Cambios principales:"
echo "   - Corregido error de recursos: 'views/resources/app.ico' → 'Resources/app.ico'"
echo "   - Actualizado el archivo .csproj con referencias correctas"
echo "   - Corregida la ruta del icono en MainWindow.xaml"
echo "   - Agregado botón 'Administrar' para discos no seleccionables"
echo "   - Mantenida la estructura correcta de .NET (todos los archivos en el mismo directorio)"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/DiskProtectorApp.csproj"
echo "2. git add src/DiskProtectorApp/Views/MainWindow.xaml"
echo "3. git add src/DiskProtectorApp/Views/MainWindow.xaml.cs"
echo "4. git commit -m \"fix: Corregir problemas de recursos y agregar botón Administrar\""
echo "5. git push origin main"

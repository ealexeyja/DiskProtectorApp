#!/bin/bash

# Crear una versión de diagnóstico de la aplicación con logging mejorado
cat > src/DiskProtectorApp/App.xaml.cs << 'APPCSHARPEOF'
using System;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Windows;

namespace DiskProtectorApp
{
    public partial class App : Application
    {
        private string logPath;

        protected override void OnStartup(StartupEventArgs e)
        {
            // Configurar logging
            string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string logDirectory = Path.Combine(appDataPath, "DiskProtectorApp");
            Directory.CreateDirectory(logDirectory);
            logPath = Path.Combine(logDirectory, "app-debug.log");
            
            LogMessage("Application starting...");
            
            try
            {
                // Verificar si se está ejecutando como administrador
                LogMessage("Checking administrator privileges...");
                if (!IsRunningAsAdministrator())
                {
                    LogMessage("Administrator privileges required - showing message");
                    MessageBox.Show("Esta aplicación requiere privilegios de administrador.\nPor favor, ejecútela como administrador.", 
                                    "Privilegios requeridos", 
                                    MessageBoxButton.OK, 
                                    MessageBoxImage.Warning);
                    Shutdown();
                    return;
                }

                LogMessage("Administrator privileges confirmed");
                base.OnStartup(e);
                LogMessage("Application startup completed");
            }
            catch (Exception ex)
            {
                LogMessage($"Error during startup: {ex}");
                MessageBox.Show($"Error al iniciar la aplicación:\n{ex.Message}", 
                                "Error de inicio", 
                                MessageBoxButton.OK, 
                                MessageBoxImage.Error);
                Shutdown();
            }
        }

        private bool IsRunningAsAdministrator()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch (Exception ex)
            {
                LogMessage($"Error checking admin privileges: {ex}");
                return false;
            }
        }

        private void LogMessage(string message)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
                string logEntry = $"[{timestamp}] {message}";
                File.AppendAllText(logPath, logEntry + Environment.NewLine);
            }
            catch
            {
                // Silenciar errores de logging
            }
        }
    }
}
APPCSHARPEOF

# Crear una versión de MainWindow más robusta con manejo de errores
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
                DataContext = new MainViewModel();
                LogMessage("MainWindow initialized successfully");
            }
            catch (Exception ex)
            {
                LogMessage($"Error initializing MainWindow: {ex}");
                MessageBox.Show($"Error al inicializar la ventana principal:\n{ex.Message}", 
                                "Error de inicialización", 
                                MessageBoxButton.OK, 
                                MessageBoxImage.Error);
            }
        }

        private void HelpButton_Click(object sender, RoutedEventArgs e)
        {
            var helpText = @"INFORMACIÓN DEL DESARROLLADOR:
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
1. Ejecutar la aplicación como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Click en el botón correspondiente
4. Esperar confirmación de la operación

📝 REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\operations.log
• Se conservan los últimos 30 días de registros";

            MessageBox.Show(helpText, "Ayuda de DiskProtectorApp", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void LogMessage(string message)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
                string logEntry = $"[{timestamp}] MainWindow: {message}";
                File.AppendAllText(logPath, logEntry + Environment.NewLine);
            }
            catch
            {
                // Silenciar errores de logging
            }
        }
    }
}
MAINWINDOWCSHARPEOF

# Actualizar el proyecto para incluir manejo de excepciones global
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
    <ApplicationIcon>Resources\app.ico</ApplicationIcon>
    <AssemblyVersion>1.0.2</AssemblyVersion>
    <FileVersion>1.0.2</FileVersion>
    <Version>1.0.2</Version>
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
    <None Remove="Resources\app.ico" />
    <None Remove="Resources\shield-protected.png" />
    <None Remove="Resources\shield-unprotected.png" />
  </ItemGroup>

  <ItemGroup>
    <Resource Include="Resources\app.ico" />
    <Resource Include="Resources\shield-protected.png" />
    <Resource Include="Resources\shield-unprotected.png" />
  </ItemGroup>

</Project>
PROJECTEOF

echo "Diagnóstico y correcciones aplicadas!"
echo "Cambios realizados:"
echo "1. Agregado logging detallado en App.xaml.cs"
echo "2. Mejorado manejo de errores en MainWindow.xaml.cs"
echo "3. Actualizada la versión a 1.0.2"
echo "4. Agregadas configuraciones de debug"
echo ""
echo "Para crear una nueva versión con diagnóstico:"
echo "1. git add src/DiskProtectorApp/App.xaml.cs"
echo "2. git add src/DiskProtectorApp/Views/MainWindow.xaml.cs"
echo "3. git add src/DiskProtectorApp/DiskProtectorApp.csproj"
echo "4. git commit -m \"fix: Agregar diagnóstico para cierre inmediato\""
echo "5. git push origin main"
echo "6. Crear nuevo tag:"
echo "   git tag -a v1.0.2 -m \"Release v1.0.2 con diagnóstico\""
echo "   git push origin v1.0.2"
echo ""
echo "Después de instalar la nueva versión en Windows:"
echo "1. Ejecuta la aplicación como administrador"
echo "2. Revisa el archivo de log en:"
echo "   %APPDATA%\\DiskProtectorApp\\app-debug.log"
echo "3. Este archivo te mostrará exactamente dónde falla la aplicación"

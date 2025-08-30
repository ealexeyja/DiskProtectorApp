#!/bin/bash

# Corregir App.xaml.cs para asegurar que la ventana principal se muestre
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
        private string? logPath;

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
                
                // Crear y mostrar la ventana principal
                LogMessage("Creating main window...");
                var mainWindow = new DiskProtectorApp.Views.MainWindow();
                LogMessage("Main window created successfully");
                
                // Mostrar la ventana
                mainWindow.Show();
                LogMessage("Main window shown");
                
                LogMessage("Application startup completed");
            }
            catch (Exception ex)
            {
                LogMessage($"Error during startup: {ex}");
                MessageBox.Show($"Error al iniciar la aplicación:\n{ex.Message}\n\n{ex.StackTrace}", 
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
                if (logPath != null)
                {
                    string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
                    string logEntry = $"[{timestamp}] {message}";
                    File.AppendAllText(logPath, logEntry + Environment.NewLine);
                }
            }
            catch
            {
                // Silenciar errores de logging
            }
        }
    }
}
APPCSHARPEOF

# Corregir App.xaml para no especificar StartupUri (ya que lo manejamos en código)
cat > src/DiskProtectorApp/App.xaml << 'APPXAMLEOF'
<Application x:Class="DiskProtectorApp.App"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:controls="http://metro.mahapps.com/winfx/xaml/controls">
    <Application.Resources>
        <ResourceDictionary>
            <ResourceDictionary.MergedDictionaries>
                <!-- MahApps.Metro resource dictionaries -->
                <ResourceDictionary Source="pack://application:,,,/MahApps.Metro;component/Styles/Controls.xaml" />
                <ResourceDictionary Source="pack://application:,,,/MahApps.Metro;component/Styles/Fonts.xaml" />
                <ResourceDictionary Source="pack://application:,,,/MahApps.Metro;component/Styles/Themes/Dark.Orange.xaml" />
                
                <!-- IconPacks -->
                <ResourceDictionary Source="pack://application:,,,/MahApps.Metro.IconPacks;component/Themes/IconPacks.xaml" />
            </ResourceDictionary.MergedDictionaries>
        </ResourceDictionary>
    </Application.Resources>
</Application>
APPXAMLEOF

# Actualizar MainWindow.xaml.cs con mejor manejo de errores
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
                MessageBox.Show($"Error al inicializar la ventana principal:\n{ex.Message}\n\n{ex.StackTrace}", 
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

        protected override void OnContentRendered(EventArgs e)
        {
            base.OnContentRendered(e);
            LogMessage("MainWindow content rendered");
        }
    }
}
MAINWINDOWCSHARPEOF

echo "Correcciones aplicadas para mostrar la ventana principal!"
echo "Cambios realizados:"
echo "1. Eliminado StartupUri de App.xaml"
echo "2. Creación explícita y muestra de MainWindow en App.xaml.cs"
echo "3. Agregado manejo de errores con stack trace"
echo "4. Logging mejorado en MainWindow"
echo ""
echo "Para crear una nueva versión con la corrección:"
echo "1. git add src/DiskProtectorApp/App.xaml.cs"
echo "2. git add src/DiskProtectorApp/App.xaml"
echo "3. git add src/DiskProtectorApp/Views/MainWindow.xaml.cs"
echo "4. git commit -m \"fix: Corregir muestra de ventana principal\""
echo "5. git push origin main"
echo "6. Crear nuevo tag:"
echo "   git tag -a v1.0.4 -m \"Release v1.0.4 - Corrección de ventana principal\""
echo "   git push origin v1.0.4"

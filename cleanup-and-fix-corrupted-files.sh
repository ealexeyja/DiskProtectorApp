#!/bin/bash

echo "=== Limpiando y corrigiendo archivos corruptos ==="

# Limpiar archivos con nombres corruptos
echo "🧹 Limpiando archivos con nombres corruptos..."
find . -name "*\.sh*" -type f | grep -v "\.sh$" | while read file; do
    echo "Eliminando archivo corrupto: $file"
    rm -f "$file"
done

# Limpiar el archivo MainWindow.xaml.cs corrupto
echo "🗑️ Limpiando MainWindow.xaml.cs corrupto..."
> src/DiskProtectorApp/Views/MainWindow.xaml.cs

# Crear MainWindow.xaml.cs limpio y funcional
cat > src/DiskProtectorApp/Views/MainWindow.xaml.cs << 'MAINWINDOWCSHARPEOF'
using DiskProtectorApp.ViewModels;
using MahApps.Metro.Controls;
using System;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
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

⚠️ REQUISITOS TÉCNICOS:

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
• Se conservan los últimos 30 días de registros

LOGS DE DIAGNÓSTICO:
• Logs detallados en:
• %APPDATA%\DiskProtectorApp\app-debug.log
• Niveles: INFO, DEBUG, WARN, ERROR, VERBOSE

 Versión actual: {versionText}";

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

echo "✅ MainWindow.xaml.cs corregido y limpiado"

# Limpiar y corregir el archivo ProgressDialog.xaml.cs
echo "🗑️ Limpiando ProgressDialog.xaml.cs corrupto..."
> src/DiskProtectorApp/Views/ProgressDialog.xaml.cs

# Crear ProgressDialog.xaml.cs limpio y funcional
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

echo "✅ ProgressDialog.xaml.cs corregido y limpiado"

# Limpiar y corregir el archivo App.xaml.cs
echo "🗑️ Limpiando App.xaml.cs corrupto..."
> src/DiskProtectorApp/App.xaml.cs

# Crear App.xaml.cs limpio y funcional
cat > src/DiskProtectorApp/App.xaml.cs << 'APPXAMLEOF'
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
                LogMessage("MainWindow constructor starting...");
                
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
                bool isAdmin = principal.IsInRole(WindowsBuiltInRole.Administrator);
                LogMessage($"User is administrator: {isAdmin}");
                return isAdmin;
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
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                string logEntry = $"[{timestamp}] {message}";
                
                // Escribir en Debug
                Debug.WriteLine(logEntry);
                
                // Escribir en Console
                Console.WriteLine(logEntry);
                
                // Escribir en archivo de log
                if (logPath != null)
                {
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
APPXAMLEOF

echo "✅ App.xaml.cs corregido y limpiado"

echo ""
echo "✅ ¡Limpieza y corrección de archivos corruptos completada!"
echo "   Archivos corregidos:"
echo "   - src/DiskProtectorApp/Views/MainWindow.xaml.cs"
echo "   - src/DiskProtectorApp/Views/ProgressDialog.xaml.cs"
echo "   - src/DiskProtectorApp/App.xaml.cs"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/Views/MainWindow.xaml.cs"
echo "2. git add src/DiskProtectorApp/Views/ProgressDialog.xaml.cs"
echo "3. git add src/DiskProtectorApp/App.xaml.cs"
echo "4. git commit -m \"fix: Limpiar y corregir archivos corruptos\""
echo "5. git push origin main"
echo ""
echo "Luego ejecuta './build-app.sh' para compilar la aplicación corregida"

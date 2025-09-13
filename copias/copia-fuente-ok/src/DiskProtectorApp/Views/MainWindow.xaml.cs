using DiskProtectorApp.ViewModels;
using MahApps.Metro.Controls;
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows;

namespace DiskProtectorApp.Views
{
    public partial class MainWindow : MetroWindow
    {
        private MainViewModel? _viewModel;
        private OperationLogger? _logger;

        public MainWindow()
        {
            InitializeComponent();
            
            // Verificar si se está ejecutando como administrador
            if (!IsRunningAsAdministrator())
            {
                MessageBox.Show(
                    "Esta aplicación requiere privilegios de administrador para funcionar correctamente.\n\n" +
                    "Por favor, ejecute la aplicación como administrador:\n" +
                    "1. Haga clic derecho sobre el ejecutable\n" +
                    "2. Seleccione 'Ejecutar como administrador'",
                    "Requiere privilegios de administrador",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
                
                Application.Current.Shutdown();
                return;
            }

            _logger = new OperationLogger();
            _viewModel = new MainViewModel();
            DataContext = _viewModel;
            
            _logger.Log("Aplicación iniciada");
        }

        private bool IsRunningAsAdministrator()
        {
            try
            {
                var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
                var principal = new System.Security.Principal.WindowsPrincipal(identity);
                return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }

        private void HelpButton_Click(object sender, RoutedEventArgs e)
        {
            string versionText = Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "1.2.6";
            
            string helpText = $@"
AUTOR:
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

        protected override void OnClosed(EventArgs e)
        {
            _logger?.Log("Aplicación cerrada");
            base.OnClosed(e);
        }
    }

    public class OperationLogger
    {
        private readonly string _logPath;

        public OperationLogger()
        {
            try
            {
                string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                string logDirectory = Path.Combine(appDataPath, "DiskProtectorApp");
                Directory.CreateDirectory(logDirectory);
                _logPath = Path.Combine(logDirectory, "app-debug.log");
            }
            catch
            {
                _logPath = Path.Combine(Path.GetTempPath(), "DiskProtectorApp-debug.log");
            }
        }

        public void Log(string message)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
                string logEntry = $"[{timestamp}] {message}";
                
                // Escribir en Debug
                Debug.WriteLine(logEntry);
                
                // Escribir en Console
                Console.WriteLine(logEntry);
                
                // Escribir en archivo de log
                File.AppendAllText(_logPath, logEntry + Environment.NewLine);
            }
            catch
            {
                // Silenciar errores de logging
            }
        }
    }
}

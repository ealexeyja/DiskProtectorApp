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
                var version = Assembly.GetExecutingAssembly().GetName().Version;
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
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            string versionText = version != null ? $"v{version.Major}.{version.Minor}.{version.Build}" : "v1.0.9";
            
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
1. Ejecutar la aplicación como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Click en el botón correspondiente
4. Esperar confirmación de la operación

📝 REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\operations.log
• Se conservan los últimos 30 días de registros

 Versión actual: {versionText}";

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

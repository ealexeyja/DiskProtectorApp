using DiskProtectorApp.Logging;
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
        public MainWindow()
        {
            AppLogger.LogUI("MainWindow constructor starting...");
            
            try
            {
                AppLogger.LogUI("Initializing component...");
                InitializeComponent();
                AppLogger.LogUI("Component initialized successfully");
                
                // Actualizar el título con la versión de la aplicación
                var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
                if (version != null)
                {
                    this.Title = $"DiskProtectorApp v{version.Major}.{version.Minor}.{version.Build}";
                    AppLogger.LogUI($"Window title set to: {this.Title}");
                }
                
                AppLogger.LogUI("Creating MainViewModel...");
                var viewModel = new MainViewModel();
                AppLogger.LogUI("MainViewModel created successfully");
                
                DataContext = viewModel;
                AppLogger.LogUI("DataContext set successfully");
                AppLogger.LogUI("MainWindow initialized successfully");
            }
            catch (Exception ex)
            {
                AppLogger.Fatal("UI", "Error initializing MainWindow", ex);
                MessageBox.Show($"Error crítico al inicializar la ventana principal:\n{ex.Message}\n\nDetalles:\n{ex}\n\nLa aplicación se cerrará.",
                              "Error de inicialización",
                              MessageBoxButton.OK,
                              MessageBoxImage.Error);
                
                // Intentar cerrar la aplicación si estamos en el contexto correcto
                try 
                {
                    Application.Current?.Shutdown();
                }
                catch { /* Ignorar errores al intentar cerrar */ }
            }
        }

        private void HelpButton_Click(object sender, RoutedEventArgs e)
        {
            AppLogger.LogUI("Help button clicked");
            
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
• %APPDATA%\DiskProtectorApp\Logs\operation.log
• Se conservan los últimos registros

LOGS DE DIAGNÓSTICO:
• Logs detallados en:
• %APPDATA%\DiskProtectorApp\Logs\
• Categorías: UI, ViewModel, Service, Operation, Permission
• Niveles: DEBUG, INFO, WARN, ERROR, FATAL

Versión actual: {versionText}";

            MessageBox.Show(helpText, "Ayuda de DiskProtectorApp", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        protected override void OnContentRendered(EventArgs e)
        {
            base.OnContentRendered(e);
            AppLogger.LogUI("MainWindow content rendered");
        }
    }
}

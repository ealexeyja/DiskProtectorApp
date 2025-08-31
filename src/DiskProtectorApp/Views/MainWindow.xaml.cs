using DiskProtectorApp.ViewModels;
using MahApps.Metro.Controls;
using System;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Windows;
using System.Windows.Controls;

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
                LogMessage($"Error during startup: {ex}");
                MessageBox.Show($"Error al iniciar la aplicación:\n{ex.Message}\n\n{ex.StackTrace}", 
                                "Error de inicio", 
                                MessageBoxButton.OK, 
                                MessageBoxImage.Error);
                Shutdown();
            }
        }

        private void HelpButton_Click(object sender, RoutedEventArgs e)
        {
            var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
            string versionText = version != null ? $"v{version.Major}.{version.Minor}.{version.Build}" : "v1.2.0";
            
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
                string logEntry = $"[{timestamp}] {message}";
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
        
        // Handler para diagnóstico de checkboxes
        private void CheckBox_Click(object sender, RoutedEventArgs e)
        {
            var checkBox = sender as CheckBox;
            if (checkBox?.DataContext is Models.DiskInfo disk)
            {
                LogMessage($"[UI] CheckBox clicked for disk {disk.DriveLetter}. IsChecked: {checkBox.IsChecked}");
                Debug.WriteLine($"[UI] CheckBox clicked for disk {disk.DriveLetter}. IsChecked: {checkBox.IsChecked}");
                Console.WriteLine($"[UI] CheckBox clicked for disk {disk.DriveLetter}. IsChecked: {checkBox.IsChecked}");
                
                // FORZAR LA ACTUALIZACIÓN DEL MODELO: Establecer explícitamente la propiedad IsSelected
                // Esto asegura que el setter del modelo se ejecute incluso si el binding TwoWay falla
                bool newValue = checkBox.IsChecked ?? false;
                if (disk.IsSelected != newValue)
                {
                    LogMessage($"[UI] Forcing IsSelected update for {disk.DriveLetter} to {newValue}");
                    Debug.WriteLine($"[UI] Forcing IsSelected update for {disk.DriveLetter} to {newValue}");
                    Console.WriteLine($"[UI] Forcing IsSelected update for {disk.DriveLetter} to {newValue}");
                    disk.IsSelected = newValue; // Esto activará el setter del modelo y OnPropertyChanged
                }
                else
                {
                     LogMessage($"[UI] IsSelected for {disk.DriveLetter} already {newValue}, no update needed");
                     Debug.WriteLine($"[UI] IsSelected for {disk.DriveLetter} already {newValue}, no update needed");
                     Console.WriteLine($"[UI] IsSelected for {disk.DriveLetter} already {newValue}, no update needed");
                }
            }
            else
            {
                LogMessage($"[UI] CheckBox clicked but DataContext is not DiskInfo. Type: {checkBox?.DataContext?.GetType().ToString() ?? "null"}");
                Debug.WriteLine($"[UI] CheckBox clicked but DataContext is not DiskInfo. Type: {checkBox?.DataContext?.GetType().ToString() ?? "null"}");
                Console.WriteLine($"[UI] CheckBox clicked but DataContext is not DiskInfo. Type: {checkBox?.DataContext?.GetType().ToString() ?? "null"}");
            }
        }
        
        // Handler para botón de diagnóstico CORREGIDO
        private void DiagnosticButton_Click(object sender, RoutedEventArgs e)
        {
            if (DataContext is ViewModels.MainViewModel viewModel)
            {
                // Verificar si el método existe usando reflexión o simplemente llamarlo si sabemos que existe
                try
                {
                    // Usar reflexión para verificar si el método existe
                    var methodInfo = viewModel.GetType().GetMethod("ShowDiagnosticInfo");
                    if (methodInfo != null)
                    {
                        methodInfo.Invoke(viewModel, null);
                    }
                    else
                    {
                        // Si el método no existe, mostrar un mensaje alternativo
                        MessageBox.Show("Función de diagnóstico no disponible en esta versión.", 
                                      "Diagnóstico", 
                                      MessageBoxButton.OK, 
                                      MessageBoxImage.Information);
                    }
                }
                catch (Exception ex)
                {
                    LogMessage($"[UI] Error calling ShowDiagnosticInfo: {ex.Message}");
                    Debug.WriteLine($"[UI] Error calling ShowDiagnosticInfo: {ex.Message}");
                    Console.WriteLine($"[UI] Error calling ShowDiagnosticInfo: {ex.Message}");
                    
                    // Mostrar mensaje alternativo en caso de error
                    MessageBox.Show("Error al ejecutar diagnóstico.\n\n" + ex.Message, 
                                  "Error de Diagnóstico", 
                                  MessageBoxButton.OK, 
                                  MessageBoxImage.Warning);
                }
            }
        }
        
        private void Shutdown()
        {
            Application.Current.Shutdown();
        }
    }
}

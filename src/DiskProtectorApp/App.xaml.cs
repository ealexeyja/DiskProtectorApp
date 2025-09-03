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

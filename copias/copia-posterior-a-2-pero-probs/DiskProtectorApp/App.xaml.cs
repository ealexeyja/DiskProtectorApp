using DiskProtectorApp.Logging.Categories;
using System;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Windows;

namespace DiskProtectorApp
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            AppLogger.Log("Application starting...");
            
            try
            {
                // Verificar si se está ejecutando como administrador
                AppLogger.Log("Checking administrator privileges...");
                if (!IsRunningAsAdministrator())
                {
                    AppLogger.LogWarning("Administrator privileges required - showing message");
                    MessageBox.Show("Esta aplicación requiere privilegios de administrador.\nPor favor, ejecute la aplicación como administrador.",
                                  "Privilegios requeridos",
                                  MessageBoxButton.OK,
                                  MessageBoxImage.Warning);
                    
                    Shutdown();
                    return;
                }
                
                base.OnStartup(e);
                AppLogger.Log("Application started successfully");
            }
            catch (Exception ex)
            {
                AppLogger.LogError("Error during application startup", ex);
                MessageBox.Show($"Error al iniciar la aplicación:\n{ex.Message}\n{ex.StackTrace}",
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
                AppLogger.Log($"Current user is administrator: {isAdmin}");
                return isAdmin;
            }
            catch (Exception ex)
            {
                AppLogger.LogError("Error checking administrator privileges", ex);
                return false;
            }
        }
    }
}

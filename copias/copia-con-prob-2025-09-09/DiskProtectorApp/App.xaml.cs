using System;
using System.Security.Principal;
using System.Windows;
using DiskProtectorApp.Services;

namespace DiskProtectorApp
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            AppLogger.Info("App", "Application starting...");

            try
            {
                // Verificar si se está ejecutando como administrador
                AppLogger.Info("App", "Checking administrator privileges...");
                if (!IsRunningAsAdministrator())
                {
                    AppLogger.Warn("App", "Administrator privileges required - showing message");
                    MessageBox.Show("Esta aplicación requiere privilegios de administrador.\nPor favor, ejecútela como administrador.",
                        "Privilegios requeridos",
                        MessageBoxButton.OK,
                        MessageBoxImage.Warning);

                    Shutdown();
                    return;
                }

                AppLogger.Info("App", "Administrator privileges confirmed.");
                base.OnStartup(e);
            }
            catch (Exception ex)
            {
                AppLogger.Error("App", "Critical error during application startup", ex);
                MessageBox.Show($"Error crítico al iniciar la aplicación:\n{ex.Message}\nDetalles:\n{ex}\nLa aplicación se cerrará.",
                    "Error de inicio crítico",
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
                AppLogger.Info("App", $"User is administrator: {isAdmin}");
                return isAdmin;
            }
            catch (Exception ex)
            {
                AppLogger.Error("App", "Error checking admin privileges", ex);
                return false;
            }
        }
    }
}

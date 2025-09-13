using DiskProtectorApp.Logging;
using DiskProtectorApp.Views;
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
            AppLogger.Info("App", "Aplicación iniciando...");
            
            try
            {
                // Verificar si se está ejecutando como administrador
                AppLogger.Info("App", "Verificando privilegios de administrador...");
                if (!IsRunningAsAdministrator())
                {
                    AppLogger.Warn("App", "Se requieren privilegios de administrador - mostrando mensaje");
                    // Reemplazar MessageBox.Show con ventana personalizada
                    var messageResult = MessageBoxWindow.ShowDialog("Esta aplicación requiere privilegios de administrador.\nPor favor, ejecútela como administrador.",
                                  "Privilegios requeridos",
                                  MessageBoxButton.OK,
                                  null);
                    
                    Shutdown();
                    return;
                }
                
                AppLogger.Info("App", "Privilegios de administrador confirmados");
                
                // Crear y mostrar la ventana principal
                AppLogger.Info("App", "Creando ventana principal...");
                base.OnStartup(e);
                
                var mainWindow = new DiskProtectorApp.Views.MainWindow();
                AppLogger.Info("App", "Instancia de MainWindow creada");
                
                // Mostrar la ventana
                mainWindow.Show();
                AppLogger.Info("App", "Ventana principal mostrada");
                AppLogger.Info("App", "Inicio de aplicación completado");
            }
            catch (Exception ex)
            {
                AppLogger.Fatal("App", "Excepción no controlada durante el inicio de la aplicación", ex);
                // Reemplazar MessageBox.Show con ventana personalizada
                var messageResult = MessageBoxWindow.ShowDialog($"Error crítico al iniciar la aplicación:\n{ex.Message}\n\nDetalles:\n{ex}\n\nLa aplicación se cerrará.",
                              "Error de inicio crítico",
                              MessageBoxButton.OK,
                              null);
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
                AppLogger.Info("App", $"El usuario es administrador: {isAdmin}");
                return isAdmin;
            }
            catch (Exception ex)
            {
                AppLogger.Error("App", "Error verificando privilegios de administrador", ex);
                return false;
            }
        }
    }
}

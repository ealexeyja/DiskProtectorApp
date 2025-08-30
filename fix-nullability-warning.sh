#!/bin/bash

# Corregir la advertencia CS8618 en App.xaml.cs
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
                base.OnStartup(e);
                LogMessage("Application startup completed");
            }
            catch (Exception ex)
            {
                LogMessage($"Error during startup: {ex}");
                MessageBox.Show($"Error al iniciar la aplicación:\n{ex.Message}", 
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

echo "Advertencia de nullability corregida!"
echo "El campo logPath ahora es nullable (?) y se verifica antes de usarlo"
echo ""
echo "Para aplicar el cambio:"
echo "1. git add src/DiskProtectorApp/App.xaml.cs"
echo "2. git commit -m \"fix: Corregir advertencia CS8618 de nullability\""
echo "3. git push origin main"

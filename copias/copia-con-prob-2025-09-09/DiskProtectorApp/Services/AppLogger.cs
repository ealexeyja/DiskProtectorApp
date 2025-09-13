using System;
using System.IO;
using System.Reflection;

namespace DiskProtectorApp.Services
{
    /// <summary>
    /// Servicio de registro de logs para la aplicación.
    /// </summary>
    public static class AppLogger
    {
        private static readonly string LogFilePath;
        private static readonly object LockObject = new object();

        static AppLogger()
        {
            try
            {
                // Crear directorio de logs en %APPDATA%\DiskProtectorApp
                string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                string logDirectory = Path.Combine(appDataPath, "DiskProtectorApp");
                Directory.CreateDirectory(logDirectory);

                // Ruta del archivo de log
                LogFilePath = Path.Combine(logDirectory, "operations.log");

                // Registrar inicio de la aplicación
                Info("Logger", "Logging service initialized.");
            }
            catch (Exception ex)
            {
                // Si no se puede crear el archivo de log, mostrar mensaje en consola
                System.Console.WriteLine($"Error initializing logger: {ex.Message}");
            }
        }

        #region Métodos de registro por nivel

        public static void Debug(string category, string message)
        {
            Log("DEBUG", category, message);
        }

        public static void Info(string category, string message)
        {
            Log("INFO", category, message);
        }

        public static void Warn(string category, string message)
        {
            Log("WARN", category, message);
        }

        public static void Error(string category, string message, Exception ex = null)
        {
            string fullMessage = ex != null ? $"{message} Exception: {ex}" : message;
            Log("ERROR", category, fullMessage);
        }

        public static void Fatal(string category, string message)
        {
            Log("FATAL", category, message);
        }

        #endregion

        #region Métodos específicos para funcionalidades

        public static void LogUI(string message)
        {
            Info("UI", message);
        }

        public static void LogViewModel(string message)
        {
            Info("ViewModel", message);
        }

        public static void LogService(string message)
        {
            Info("Service", message);
        }

        public static void LogPermissionChange(string drivePath, string operation, string account, string permission, bool success)
        {
            Info("Permission", $"Drive: {drivePath}, Operation: {operation}, Account: {account}, Permission: {permission}, Success: {success}");
        }

        #endregion

        #region Método privado principal de registro

        private static void Log(string level, string category, string message)
        {
            try
            {
                lock (LockObject)
                {
                    string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                    string logEntry = $"[{timestamp}] [{level}] [{category}] {message}{Environment.NewLine}";

                    // Escribir en archivo
                    File.AppendAllText(LogFilePath, logEntry);
                }
            }
            catch
            {
                // Silenciar errores de logging para no interrumpir la aplicación
            }
        }

        #endregion
    }
}

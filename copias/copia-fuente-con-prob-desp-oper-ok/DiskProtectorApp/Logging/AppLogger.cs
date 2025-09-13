using System;
using System.IO;

namespace DiskProtectorApp.Logging
{
    public static class AppLogger
    {
        private static readonly string LogDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "DiskProtectorApp", "Logs");
        private static readonly object _lock = new object();

        static AppLogger()
        {
            try
            {
                if (!Directory.Exists(LogDirectory))
                {
                    Directory.CreateDirectory(LogDirectory);
                }
            }
            catch (Exception ex)
            {
                // No se puede crear el directorio de logs, continuar sin registrar
            }
        }

        public static void LogService(string message)
        {
            Log("Service", message);
        }

        public static void LogViewModel(string message)
        {
            Log("ViewModel", message);
        }

        public static void LogUI(string message)
        {
            Log("UI", message);
        }

        public static void LogPermissionChange(string drivePath, string operation, string group, string permission, bool success)
        {
            Log("Permission", $"Disco: {drivePath}| Operación: {operation}| Grupo: {group}| Permiso: {permission}| Éxito: {success}");
        }

        public static void LogOperation(string operation, string drivePath, bool success)
        {
            Log("Operation", $"Operación: {operation}| Disco: {drivePath}| Éxito: {success}");
        }

        public static void Error(string category, string message, Exception ex)
        {
            Log(category, $"ERROR: {message} - {ex.GetType().Name}: {ex.Message}\n{ex.StackTrace}");
        }

        public static void Warn(string category, string message)
        {
            Log(category, $"ADVERTENCIA: {message}");
        }

        private static void Log(string category, string message)
        {
            lock (_lock)
            {
                try
                {
                    string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                    string logMessage = $"[{timestamp}] [INFO] [{category}] {message}{Environment.NewLine}";
                    string logFilePath = Path.Combine(LogDirectory, $"{category.ToLower()}.log");
                    File.AppendAllText(logFilePath, logMessage);
                }
                catch (Exception)
                {
                    // Ignorar errores de registro
                }
            }
        }
    }
}

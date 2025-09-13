using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

namespace DiskProtectorApp.Logging.Categories
{
    public static class PermissionLogger
    {
        private static readonly string LogDirectory;
        private static readonly object LockObject = new object();

        static PermissionLogger()
        {
            try
            {
                string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                LogDirectory = Path.Combine(appDataPath, "DiskProtectorApp", "Logs");
                Directory.CreateDirectory(LogDirectory);
            }
            catch
            {
                // Fallback to temp directory if AppData is not accessible
                LogDirectory = Path.Combine(Path.GetTempPath(), "DiskProtectorApp", "Logs");
                Directory.CreateDirectory(LogDirectory);
            }
        }

        public static void Log(string message, Exception? ex = null)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                string logEntry = $"[{timestamp}] [Permission] {message}";

                if (ex != null)
                {
                    logEntry += $"\nException: {ex}\nStack Trace: {ex.StackTrace}";
                }

                // Log to Debug output
                Debug.WriteLine(logEntry);

                // Log to Console
                Console.WriteLine(logEntry);

                // Log to file
                string logFilePath = Path.Combine(LogDirectory, "permission.log");

                lock (LockObject)
                {
                    File.AppendAllText(logFilePath, logEntry + Environment.NewLine);
                }
            }
            catch
            {
                // Silently ignore logging errors to prevent cascading failures
            }
        }

        public static void LogError(string message, Exception? ex = null)
        {
            Log($"ERROR: {message}", ex);
        }

        public static void LogWarning(string message)
        {
            Log($"WARN: {message}");
        }

        public static void LogInfo(string message)
        {
            Log($"INFO: {message}");
        }

        public static void LogDebug(string message)
        {
            Log($"DEBUG: {message}");
        }

        public static void LogPermissionChange(string drive, string action, string group, string permission, bool success)
        {
            string message = $"Drive: {drive} | Action: {action} | Group: {group} | Permission: {permission} | Success: {success}";
            Log(message);
        }
    }
}

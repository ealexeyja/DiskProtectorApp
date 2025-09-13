using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

namespace DiskProtectorApp.Logging
{
    public static class SimpleLogger
    {
        private static readonly string LogDirectory;
        private static readonly object LockObject = new object();

        static SimpleLogger()
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

        public static void Log(LogCategory category, LogLevel level, string message, Exception? ex = null)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                string logEntry = $"[{timestamp}] [{level}] [{category}] {message}";

                if (ex != null)
                {
                    logEntry += $"\nException: {ex}\nStack Trace: {ex.StackTrace}";
                }

                // Log to Debug output
                Debug.WriteLine(logEntry);

                // Log to Console
                Console.WriteLine(logEntry);

                // Log to file with category-specific log file
                string logFileName = $"{category.ToString().ToLower()}.log";
                string logFilePath = Path.Combine(LogDirectory, logFileName);

                // Add date to the log entry for file
                string fileLogEntry = logEntry;

                lock (LockObject)
                {
                    File.AppendAllText(logFilePath, fileLogEntry + Environment.NewLine);
                    
                    // Limit log file size (approx 5MB)
                    FileInfo fileInfo = new FileInfo(logFilePath);
                    if (fileInfo.Length > 5 * 1024 * 1024)
                    {
                        string backupPath = logFilePath + ".old";
                        if (File.Exists(backupPath))
                            File.Delete(backupPath);
                        File.Move(logFilePath, backupPath);
                    }
                }
            }
            catch
            {
                // Silently ignore logging errors to prevent cascading failures
            }
        }

        public static void Debug(LogCategory category, string message)
        {
            Log(category, LogLevel.DEBUG, message);
        }

        public static void Info(LogCategory category, string message)
        {
            Log(category, LogLevel.INFO, message);
        }

        public static void Warn(LogCategory category, string message)
        {
            Log(category, LogLevel.WARN, message);
        }

        public static void Error(LogCategory category, string message, Exception? ex = null)
        {
            Log(category, LogLevel.ERROR, message, ex);
        }

        public static void Fatal(LogCategory category, string message, Exception? ex = null)
        {
            Log(category, LogLevel.FATAL, message, ex);
        }

        // Specialized loggers for different components
        public static void LogApp(string message, LogLevel level = LogLevel.INFO)
        {
            Log(LogCategory.App, level, message);
        }

        public static void LogUI(string message, LogLevel level = LogLevel.INFO)
        {
            Log(LogCategory.UI, level, message);
        }

        public static void LogViewModel(string message, LogLevel level = LogLevel.INFO)
        {
            Log(LogCategory.ViewModel, level, message);
        }

        public static void LogService(string message, LogLevel level = LogLevel.INFO)
        {
            Log(LogCategory.Service, level, message);
        }

        public static void LogOperation(string operation, string target, bool success, string details = "")
        {
            string message = $"Operation: {operation} | Target: {target} | Success: {success}";
            if (!string.IsNullOrEmpty(details))
            {
                message += $" | Details: {details}";
            }
            Log(success ? LogLevel.INFO : LogLevel.WARN, LogCategory.Operation, message);
        }

        public static void LogPermissionChange(string drive, string action, string group, string permission, bool success)
        {
            string message = $"Drive: {drive} | Action: {action} | Group: {group} | Permission: {permission} | Success: {success}";
            Log(success ? LogLevel.INFO : LogLevel.ERROR, LogCategory.Permission, message);
        }
    }
}

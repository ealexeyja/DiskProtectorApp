using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

namespace DiskProtectorApp.Logging
{
    public enum LogLevel
    {
        DEBUG,
        INFO,
        WARN,
        ERROR,
        FATAL
    }

    public static class AppLogger
    {
        private static readonly string LogDirectory;
        private static readonly object LockObject = new object();

        static AppLogger()
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

        public static void Log(LogLevel level, string category, string message, Exception? ex = null)
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
                System.Diagnostics.Debug.WriteLine(logEntry);

                // Log to Console
                Console.WriteLine(logEntry);

                // Log to file with category-specific log file
                string logFileName = $"{category.ToLower()}.log";
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

        public static void DebugLog(string category, string message)
        {
            Log(LogLevel.DEBUG, category, message);
        }

        public static void Info(string category, string message)
        {
            Log(LogLevel.INFO, category, message);
        }

        public static void Warn(string category, string message)
        {
            Log(LogLevel.WARN, category, message);
        }

        public static void Error(string category, string message, Exception? ex = null)
        {
            Log(LogLevel.ERROR, category, message, ex);
        }

        public static void Fatal(string category, string message, Exception? ex = null)
        {
            Log(LogLevel.FATAL, category, message, ex);
        }

        // Specialized loggers for different components
        public static void LogUI(string message, LogLevel level = LogLevel.INFO)
        {
            Log(level, "UI", message);
        }

        public static void LogService(string message, LogLevel level = LogLevel.INFO)
        {
            Log(level, "Service", message);
        }

        public static void LogViewModel(string message, LogLevel level = LogLevel.INFO)
        {
            Log(level, "ViewModel", message);
        }

        public static void LogOperation(string operation, string target, bool success, string details = "")
        {
            string message = $"Operation: {operation} | Target: {target} | Success: {success}";
            if (!string.IsNullOrEmpty(details))
            {
                message += $" | Details: {details}";
            }
            Log(success ? LogLevel.INFO : LogLevel.WARN, "Operation", message);
        }

        public static void LogPermissionChange(string drive, string action, string group, string permission, bool success)
        {
            string message = $"Drive: {drive} | Action: {action} | Group: {group} | Permission: {permission} | Success: {success}";
            Log(success ? LogLevel.INFO : LogLevel.ERROR, "Permission", message);
        }
    }
}

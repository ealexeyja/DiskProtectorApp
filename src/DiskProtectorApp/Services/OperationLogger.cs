using System;
using System.IO;

namespace DiskProtectorApp.Services
{
    public class OperationLogger
    {
        private readonly string logFilePath;
        
        public OperationLogger()
        {
            string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string logDirectory = Path.Combine(appDataPath, "DiskProtectorApp");
            Directory.CreateDirectory(logDirectory);
            logFilePath = Path.Combine(logDirectory, "operations.log");
        }
        
        public void LogOperation(string action, string disk, bool success, string details = "")
        {
            string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
            string result = success ? "Éxito" : "Fallo";
            
            string logEntry = $"[{timestamp}] | Acción: {action} | Disco: {disk} | Resultado: {result} | Detalles: {details}";
            
            // Rotación de logs (mantener 30 días)
            if (File.Exists(logFilePath) && 
                (DateTime.Now - File.GetCreationTime(logFilePath)).TotalDays > 30)
            {
                File.Delete(logFilePath);
            }
            
            File.AppendAllText(logFilePath, logEntry + Environment.NewLine);
        }
    }
}

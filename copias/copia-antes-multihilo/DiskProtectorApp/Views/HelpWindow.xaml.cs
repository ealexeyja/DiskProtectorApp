using MahApps.Metro.Controls;
using System.Diagnostics;
using System.Reflection;
using System.Windows;
using System.Windows.Documents;

namespace DiskProtectorApp.Views
{
    public partial class HelpWindow : MetroWindow
    {
        public HelpWindow()
        {
            InitializeComponent();
            
            // Actualizar el texto de la versión con la versión real de la aplicación
            var version = Assembly.GetExecutingAssembly().GetName().Version;
            string versionText = version != null ? $"v{version.Major}.{version.Minor}.{version.Build}" : "v1.2.6";
            VersionText.Text = $"Versión actual: {versionText}";
        }

        private void CloseButton_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }

        private void EmailLink_Click(object sender, RoutedEventArgs e)
        {
            // Abrir cliente de correo con la dirección especificada
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "mailto:ealexeyja@gmail.com",
                    UseShellExecute = true
                });
            }
            catch
            {
                // En caso de error, mostrar un mensaje
                MessageBox.Show("No se pudo abrir el cliente de correo. La dirección es: ealexeyja@gmail.com", 
                              "Información", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void DotNetLink_Click(object sender, RoutedEventArgs e)
        {
            // Abrir navegador con la URL especificada
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "https://dotnet.microsoft.com/download/dotnet/8.0",
                    UseShellExecute = true
                });
            }
            catch
            {
                // En caso de error, mostrar un mensaje
                MessageBox.Show("No se pudo abrir el navegador. La URL es: https://dotnet.microsoft.com/download/dotnet/8.0", 
                              "Información", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }
    }
}

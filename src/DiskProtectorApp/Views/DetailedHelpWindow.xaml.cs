using MahApps.Metro.Controls;
using System.Diagnostics;
using System.Windows;
using System.Windows.Documents;
using System.Windows.Navigation;

namespace DiskProtectorApp.Views
{
    public partial class DetailedHelpWindow : MetroWindow
    {
        public DetailedHelpWindow()
        {
            InitializeComponent();
        }

        private void CloseButton_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }

        private void Hyperlink_RequestNavigate(object sender, RequestNavigateEventArgs e)
        {
            // Abrir el URI en el navegador o cliente de correo predeterminado
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = e.Uri.AbsoluteUri,
                    UseShellExecute = true
                });
            }
            catch
            {
                // En caso de error, mostrar un mensaje
                MessageBox.Show($"No se pudo abrir el enlace. La dirección es: {e.Uri.AbsoluteUri}", 
                              "Información", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }
    }
}

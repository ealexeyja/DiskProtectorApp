using DiskProtectorApp.Logging;
using DiskProtectorApp.ViewModels;
using MahApps.Metro.Controls;
using System;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Windows;

namespace DiskProtectorApp.Views
{
    public partial class MainWindow : MahApps.Metro.Controls.MetroWindow
    {
        public MainWindow()
        {
            AppLogger.LogUI("MainWindow constructor starting...");
            try
            {
                AppLogger.LogUI("Initializing component...");
                InitializeComponent();
                AppLogger.LogUI("Component initialized successfully");

                // Actualizar el título con la versión de la aplicación
                var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
                if (version != null)
                {
                    this.Title = $"DiskProtectorApp v{version.Major}.{version.Minor}.{version.Build}";
                    AppLogger.LogUI($"Window title set to: {this.Title}");
                }

                AppLogger.LogUI("Creating MainViewModel...");
                var viewModel = new MainViewModel();
                AppLogger.LogUI("MainViewModel created successfully");
                DataContext = viewModel;
                AppLogger.LogUI("DataContext set successfully");

                AppLogger.LogUI("MainWindow initialized successfully");
            }
            catch (Exception ex)
            {
                AppLogger.Error("UI", "Error initializing MainWindow", ex);
                MessageBox.Show($"Error inicializando la ventana principal: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void OnHelpClick(object sender, RoutedEventArgs e)
        {
            AppLogger.LogUI("OnHelpClick called");
            try
            {
                var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
                var versionText = version != null ? $"v{version.Major}.{version.Minor}.{version.Build}" : "Desconocida";

                string helpText = $"DiskProtectorApp {versionText}\n\n" +
                                 "Aplicación para proteger y desproteger unidades de disco duro contra modificaciones del contenido.\n\n" +
                                 "Cómo usar:\n" +
                                 "- Seleccione uno o más discos de la lista.\n" +
                                 "- Haga clic en 'Proteger' para restringir el acceso a solo lectura.\n" +
                                 "- Haga clic en 'Desproteger' para restaurar el acceso completo.\n" +
                                 "- Haga clic en 'Administrar' para hacer que un disco no administrable sea administrable.\n\n" +
                                 "Estados de los discos:\n" +
                                 "- Gris: No Elegible (No NTFS o Disco del sistema)\n" +
                                 "- Naranja: No Administrable (No se pueden cambiar permisos)\n" +
                                 "- Rojo: Desprotegido (Acceso completo)\n" +
                                 "- Verde: Protegido (Solo lectura)\n\n" +
                                 "Categorías: UI, ViewModel, Service, Operation, Permission\n" +
                                 "Niveles: DEBUG, INFO, WARN, ERROR, FATAL\n" +
                                 $"Versión actual: {versionText}";

                MessageBox.Show(helpText, "Ayuda de DiskProtectorApp", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                AppLogger.Error("UI", "Error showing help", ex);
                MessageBox.Show($"Ocurrió un error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        protected override void OnContentRendered(EventArgs e)
        {
            base.OnContentRendered(e);
            AppLogger.LogUI("MainWindow content rendered");
        }
    }
}

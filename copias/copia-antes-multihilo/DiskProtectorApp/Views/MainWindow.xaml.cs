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
    public partial class MainWindow : MetroWindow
    {
        public MainWindow()
        {
            AppLogger.LogUI("Constructor de MainWindow iniciando...");
            
            try
            {
                AppLogger.LogUI("Inicializando componente...");
                InitializeComponent();
                AppLogger.LogUI("Componente inicializado exitosamente");
                
                // Actualizar el título con la versión de la aplicación
                var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
                if (version != null)
                {
                    this.Title = $"DiskProtectorApp v{version.Major}.{version.Minor}.{version.Build}";
                    AppLogger.LogUI($"Título de ventana establecido a: {this.Title}");
                }
                
                AppLogger.LogUI("Creando MainViewModel...");
                var viewModel = new MainViewModel();
                AppLogger.LogUI("MainViewModel creado exitosamente");
                
                DataContext = viewModel;
                AppLogger.LogUI("DataContext establecido exitosamente");
                AppLogger.LogUI("MainWindow inicializada exitosamente");
            }
            catch (Exception ex)
            {
                AppLogger.Fatal("UI", "Error inicializando MainWindow", ex);
                MessageBox.Show($"Error crítico al inicializar la ventana principal:\n{ex.Message}\n\nDetalles:\n{ex}\n\nLa aplicación se cerrará.",
                              "Error de inicialización",
                              MessageBoxButton.OK,
                              MessageBoxImage.Error);
                
                // Intentar cerrar la aplicación si estamos en el contexto correcto
                try 
                {
                    Application.Current?.Shutdown();
                }
                catch { /* Ignorar errores al intentar cerrar */ }
            }
        }

        private void HelpButton_Click(object sender, RoutedEventArgs e)
        {
            AppLogger.LogUI("Botón de ayuda clickeado");
            
            // Crear y mostrar la ventana de ayuda personalizada
            var helpWindow = new HelpWindow();
            helpWindow.Owner = this;
            helpWindow.ShowDialog();
        }

        protected override void OnContentRendered(EventArgs e)
        {
            base.OnContentRendered(e);
            AppLogger.LogUI("Contenido de MainWindow renderizado");
        }
    }
}

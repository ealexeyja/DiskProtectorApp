using System;
using System.Windows;
using DiskProtectorApp.Services;
using DiskProtectorApp.ViewModels;

namespace DiskProtectorApp.Views
{
    public partial class MainWindow
    {
        public MainWindow()
        {
            AppLogger.LogUI("Initializing MainWindow...");
            InitializeComponent();
            AppLogger.LogUI("MainWindow initialized successfully");

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
        }

        protected override void OnContentRendered(EventArgs e)
        {
            base.OnContentRendered(e);
            AppLogger.LogUI("MainWindow content rendered");
        }
    }
}

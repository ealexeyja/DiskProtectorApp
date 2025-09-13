using DiskProtectorApp.Models;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace DiskProtectorApp.Controls
{
    /// <summary>
    /// Interaction logic for DiskStatusIndicator.xaml
    /// </summary>
    public partial class DiskStatusIndicator : UserControl
    {
        public static readonly DependencyProperty DiskProperty =
            DependencyProperty.Register("Disk", typeof(DiskInfo), typeof(DiskStatusIndicator), 
                new PropertyMetadata(null, OnDiskChanged));

        public DiskInfo Disk
        {
            get { return (DiskInfo)GetValue(DiskProperty); }
            set { SetValue(DiskProperty, value); }
        }

        public DiskStatusIndicator()
        {
            InitializeComponent();
        }

        private static void OnDiskChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            var control = (DiskStatusIndicator)d;
            control.UpdateStatus();
            
            // Suscribirse a los cambios de propiedad del disco
            if (e.OldValue is DiskInfo oldDisk)
            {
                oldDisk.PropertyChanged -= control.OnDiskPropertyChanged;
            }
            
            if (e.NewValue is DiskInfo newDisk)
            {
                newDisk.PropertyChanged += control.OnDiskPropertyChanged;
            }
        }

        private void OnDiskPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
        {
            // Actualizar el estado cuando cambian propiedades relevantes
            if (e.PropertyName == nameof(DiskInfo.IsSelectable) ||
                e.PropertyName == nameof(DiskInfo.IsManageable) ||
                e.PropertyName == nameof(DiskInfo.IsProtected))
            {
                Dispatcher.Invoke(() => UpdateStatus());
            }
        }

        private void UpdateStatus()
        {
            if (Disk == null)
            {
                StatusEllipse.Fill = new SolidColorBrush(Colors.Gray);
                return;
            }

            // Lógica de colores:
            // Gris: No Elegible (IsSelectable = False)
            // Naranja: No Administrable (IsSelectable = True y IsManageable = False)
            // Rojo: Desprotegido (IsSelectable = True, IsManageable = True y IsProtected = False)
            // Verde: Protegido (IsSelectable = True, IsManageable = True y IsProtected = True)
            
            if (!Disk.IsSelectable)
            {
                StatusEllipse.Fill = new SolidColorBrush(Colors.Gray);
            }
            else if (!Disk.IsManageable)
            {
                StatusEllipse.Fill = new SolidColorBrush(Colors.Orange);
            }
            else if (!Disk.IsProtected)
            {
                StatusEllipse.Fill = new SolidColorBrush(Colors.Red);
            }
            else
            {
                StatusEllipse.Fill = new SolidColorBrush(Colors.Green);
            }
        }
    }
}

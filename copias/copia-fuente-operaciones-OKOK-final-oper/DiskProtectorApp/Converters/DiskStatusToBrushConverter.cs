using DiskProtectorApp.Models;
using System;
using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;

namespace DiskProtectorApp.Converters
{
    /// <summary>
    /// Convierte el estado de un disco a un Brush de color según las reglas definidas:
    /// - Gris: No Elegible (IsSelectable = False)
    /// - Naranja: No Administrable (IsSelectable = True y IsManageable = False)
    /// - Rojo: Desprotegido (IsSelectable = True, IsManageable = True y IsProtected = False)
    /// - Verde: Protegido (IsSelectable = True, IsManageable = True y IsProtected = True)
    /// </summary>
    public class DiskStatusToBrushConverter : IValueConverter
    {
        // Colores personalizados definidos por el usuario
        private static readonly Color ProtectedColor = Color.FromRgb(61, 90, 59);    // Verde forestal oscuro #3D5A3B
        private static readonly Color UnprotectedColor = Color.FromRgb(109, 44, 44);  // Rojo oscuro sobrio #6D2C2C
        private static readonly Color NotManageableColor = Color.FromRgb(255, 152, 0); // Naranja suave #FF9800
        private static readonly Color NotEligibleColor = Color.FromRgb(158, 158, 158); // Gris suave #9E9E9E
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            if (value is DiskInfo disk)
            {
                // Gris para No Elegible (No NTFS o Sistema)
                if (!disk.IsSelectable)
                {
                    return new SolidColorBrush(NotEligibleColor);
                }
                
                // Naranja para No Administrable
                if (!disk.IsManageable)
                {
                    return new SolidColorBrush(NotManageableColor);
                }
                
                // Rojo para Desprotegido
                if (!disk.IsProtected)
                {
                    return new SolidColorBrush(UnprotectedColor);
                }
                
                // Verde para Protegido
                return new SolidColorBrush(ProtectedColor);
            }
            
            // Color por defecto si no se puede determinar el estado
            return new SolidColorBrush(NotEligibleColor);
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}

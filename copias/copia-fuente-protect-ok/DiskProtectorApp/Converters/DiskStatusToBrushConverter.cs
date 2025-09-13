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
        // Colores más suaves y acordes con el tema oscuro
        private static readonly Color ProtectedColor = Color.FromRgb(76, 175, 80);    // Verde suave #4CAF50
        private static readonly Color UnprotectedColor = Color.FromRgb(244, 67, 54);  // Rojo suave #F44336
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

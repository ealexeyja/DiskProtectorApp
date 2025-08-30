#!/bin/bash

# Crear directorio de recursos si no existe
mkdir -p src/DiskProtectorApp/Resources

echo "Opciones para convertir los íconos SVG a formatos utilizables:"

echo ""
echo "OPCIÓN 1: Usar herramientas online"
echo "================================="
echo "1. Ve a https://convertio.co/svg-png/ o https://cloudconvert.com/svg-to-png"
echo "2. Sube los archivos SVG:"
echo "   - src/DiskProtectorApp/Resources/app-icon.svg → app.ico (256x256)"
echo "   - src/DiskProtectorApp/Resources/shield-protected.svg → shield-protected.png (32x32)"
echo "   - src/DiskProtectorApp/Resources/shield-unprotected.svg → shield-unprotected.png (32x32)"
echo "3. Descarga los archivos convertidos"

echo ""
echo "OPCIÓN 2: Usar npm packages (si tienes Node.js)"
echo "=============================================="
echo "npm install -g svgexport"
echo "svgexport src/DiskProtectorApp/Resources/app-icon.svg src/DiskProtectorApp/Resources/app.png 256:"
echo "svgexport src/DiskProtectorApp/Resources/shield-protected.svg src/DiskProtectorApp/Resources/shield-protected.png 32:"
echo "svgexport src/DiskProtectorApp/Resources/shield-unprotected.svg src/DiskProtectorApp/Resources/shield-unprotected.png 32:"

echo ""
echo "OPCIÓN 3: Usar ImageMagick si ya está instalado"
echo "==============================================="
echo "Comprueba si ImageMagick está disponible:"
echo "convert --version"
echo ""
echo "Si está disponible, usa:"
echo "convert -density 300 -background transparent src/DiskProtectorApp/Resources/app-icon.svg src/DiskProtectorApp/Resources/app.ico"
echo "convert -density 300 -background transparent src/DiskProtectorApp/Resources/shield-protected.svg src/DiskProtectorApp/Resources/shield-protected.png"
echo "convert -density 300 -background transparent src/DiskProtectorApp/Resources/shield-unprotected.svg src/DiskProtectorApp/Resources/shield-unprotected.png"

echo ""
echo "OPCIÓN 4: Descargar íconos pre-hechos"
echo "===================================="
echo "Puedes descargar íconos gratuitos de sitios como:"
echo "- https://icons8.com/icons"
echo "- https://fluenticons.co/"
echo "- https://feathericons.com/"
echo "Busca: 'shield', 'hard drive', 'lock'"

echo ""
echo "Una vez que tengas los archivos convertidos, colócalos en:"
echo "src/DiskProtectorApp/Resources/"
echo ""
echo "Nombres requeridos:"
echo "- app.ico (ícono de la aplicación)"
echo "- shield-protected.png (ícono protegido)"
echo "- shield-unprotected.png (ícono desprotegido)"

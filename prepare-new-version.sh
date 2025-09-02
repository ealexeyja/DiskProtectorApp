#!/bin/bash

echo "=== Preparando nueva versión ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.2.6"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Parsear la versión
VERSION_PARTS=(${CURRENT_VERSION//./ })
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Incrementar el número de parche
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"

echo "📈 Nueva versión: v$NEW_VERSION"

# Actualizar el archivo .csproj
sed -i "s/<Version>$CURRENT_VERSION<\/Version>/<Version>$NEW_VERSION<\/Version>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
sed -i "s/<AssemblyVersion>$CURRENT_VERSION.0<\/AssemblyVersion>/<AssemblyVersion>$NEW_VERSION.0<\/AssemblyVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
sed -i "s/<FileVersion>$CURRENT_VERSION.0<\/FileVersion>/<FileVersion>$NEW_VERSION.0<\/FileVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
sed -i "s/<InformationalVersion>$CURRENT_VERSION<\/InformationalVersion>/<InformationalVersion>$NEW_VERSION<\/InformationalVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj

# Actualizar el título en MainWindow.xaml
sed -i "s/Title=\"DiskProtectorApp v$CURRENT_VERSION\"/Title=\"DiskProtectorApp v$NEW_VERSION\"/g" src/DiskProtectorApp/Views/MainWindow.xaml

echo ""
echo "✅ Versión actualizada de v$CURRENT_VERSION a v$NEW_VERSION"
echo "   Archivos actualizados:"
echo "   - src/DiskProtectorApp/DiskProtectorApp.csproj"
echo "   - src/DiskProtectorApp/Views/MainWindow.xaml"

#!/bin/bash

echo "=== Preparando nueva versión de DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto. Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.1.0"
fi

echo "🔢 Versión actual: v$CURRENT_VERSION"

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

echo "✅ Versión actualizada de v$CURRENT_VERSION a v$NEW_VERSION"

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-test ./publish-v$NEW_VERSION ./DiskProtectorApp-organized ./DiskProtectorApp-final

# Restaurar dependencias
echo "📥 Restaurando dependencias..."
if ! dotnet restore src/DiskProtectorApp/DiskProtectorApp.csproj; then
    echo "❌ Error al restaurar dependencias"
    exit 1
fi

# Compilar el proyecto
echo "🔨 Compilando el proyecto..."
if ! dotnet build src/DiskProtectorApp/DiskProtectorApp.csproj --configuration Release --no-restore; then
    echo "❌ Error al compilar el proyecto"
    exit 1
fi

# Publicar la aplicación para prueba
echo "🚀 Publicando la aplicación para prueba..."
if ! dotnet publish src/DiskProtectorApp/DiskProtectorApp.csproj \
    -c Release \
    -r win-x64 \
    --self-contained false \
    -o ./publish-test; then
    echo "❌ Error al publicar la aplicación"
    exit 1
fi

# Verificar que la publicación se generó correctamente
if [ ! -f "./publish-test/DiskProtectorApp.exe" ]; then
    echo "❌ Error: No se encontró el ejecutable publicado"
    exit 1
fi

echo ""
echo "✅ ¡Preparación completada exitosamente!"
echo "   Nueva versión: v$NEW_VERSION"
echo "   Carpeta de prueba: publish-test/"
echo ""
echo "📊 Información del ejecutable:"
ls -lh ./publish-test/DiskProtectorApp.exe
echo ""
echo "🔍 Siguientes pasos:"
echo "   1. Probar la aplicación en un entorno Windows"
echo "   2. Si todo funciona correctamente, ejecutar './finalize-release.sh'"
echo "   3. Crear el tag y push para activar GitHub Actions"

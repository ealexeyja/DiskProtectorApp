#!/bin/bash

echo "=== DiskProtectorApp Build and Release Script ==="
echo "Iniciando proceso de compilación y empaquetado..."

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto. Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión del proyecto
VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$VERSION" ]; then
    VERSION="1.0.9"
fi

echo "📦 Versión detectada: v$VERSION"

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-v$VERSION

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

# Publicar la aplicación
echo "🚀 Publicando la aplicación para Windows x64..."
if ! dotnet publish src/DiskProtectorApp/DiskProtectorApp.csproj \
    -c Release \
    -r win-x64 \
    --self-contained false \
    -o ./publish-v$VERSION; then
    echo "❌ Error al publicar la aplicación"
    exit 1
fi

# Verificar que la publicación se generó correctamente
if [ ! -f "./publish-v$VERSION/DiskProtectorApp.exe" ]; then
    echo "❌ Error: No se encontró el ejecutable publicado"
    exit 1
fi

# Crear archivo comprimido
echo "📦 Creando archivo comprimido..."
if ! tar -czf DiskProtectorApp-v$VERSION.tar.gz -C ./publish-v$VERSION .; then
    echo "❌ Error al crear el archivo comprimido"
    exit 1
fi

echo ""
echo "✅ ¡Compilación y empaquetado completados exitosamente!"
echo "   Versión: v$VERSION"
echo "   Archivos generados:"
echo "   - Carpeta: publish-v$VERSION/"
echo "   - Archivo: DiskProtectorApp-v$VERSION.tar.gz"
echo ""
echo "📊 Información del ejecutable:"
ls -lh ./publish-v$VERSION/DiskProtectorApp.exe
echo ""
echo "Para crear un nuevo release en GitHub:"
echo "1. git add ."
echo "2. git commit -m \"release: v$VERSION - Compilación y empaquetado\""
echo "3. git push origin main"
echo "4. git tag -a v$VERSION -m \"Release v$VERSION\""
echo "5. git push origin v$VERSION"
echo ""
echo "🎉 Proceso completado. ¡Listo para distribuir!"

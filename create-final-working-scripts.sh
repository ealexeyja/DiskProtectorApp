#!/bin/bash

echo "=== Creando scripts finales y funcionales ==="

# Limpiar todos los archivos con nombres corruptos
echo "🧹 Limpiando archivos con nombres corruptos..."
rm -f ./fix-all-permission-issues.shsues.sh
rm -f ./check-current-structure.sh
rm -f ./compile-app.sh
rm -f ./package-app.sh
rm -f ./publish-to-github.sh
rm -f ./release-workflow.sh
rm -f ./build-app.sh
rm -f ./create-*.sh
rm -f ./fix-*.sh
rm -f ./update-*.sh
rm -f ./organize-*.sh
rm -f ./reorganize-*.sh
rm -f ./verify-*.sh
rm -f ./clean-*.sh
rm -f ./test-*.sh
rm -f ./release-*.sh
rm -f ./publish-*.sh
rm -f ./finalize-*.sh
rm -f ./prepare-*.sh
rm -f ./diagnose-*.sh
rm -f ./extract-*.sh
rm -f ./essential-*.sh

# Crear script final de compilación
cat > build-final.sh << 'BUILDFINALEOF'
#!/bin/bash

echo "=== Compilando DiskProtectorApp versión final ==="

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

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-final ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz

# Restaurar dependencias
echo "📥 Restaurando dependencias..."
if ! dotnet restore src/DiskProtectorApp/DiskProtectorApp.csproj; then
    echo "❌ Error al restaurar dependencias"
    exit 1
fi

# Compilar el proyecto
echo "�� Compilando el proyecto..."
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
echo "✅ ¡Compilación completada exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Carpeta de prueba: publish-test/"
echo ""
echo "📊 Información del ejecutable:"
ls -lh ./publish-test/DiskProtectorApp.exe

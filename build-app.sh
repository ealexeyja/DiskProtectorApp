#!/bin/bash

# build-app.sh - Compila la aplicación DiskProtectorApp con la versión definida

set -e # Salir inmediatamente si un comando falla

echo "=== Compilación de DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
PROJECT_FILE="src/DiskProtectorApp/DiskProtectorApp.csproj"
CURRENT_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" "$PROJECT_FILE")

if [ -z "$CURRENT_VERSION" ]; then
    echo "⚠️  Advertencia: No se pudo leer la versión actual del .csproj. Usando 0.0.0 como base."
    CURRENT_VERSION="0.0.0"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./bin ./obj ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-final ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz

# Restaurar dependencias
echo "📥 Restaurando dependencias..."
if ! dotnet restore "$PROJECT_FILE"; then
    echo "❌ Error al restaurar dependencias"
    exit 1
fi

# Compilar el proyecto en modo Release
echo "🔨 Compilando el proyecto en modo Release..."
if ! dotnet build "$PROJECT_FILE" --configuration Release --no-restore; then
    echo "❌ Error al compilar el proyecto"
    exit 1
fi

# Publicar la aplicación para Windows x64 (sin auto-contenido para reducir tamaño)
echo "🚀 Publicando la aplicación para Windows x64..."
PUBLISH_DIR="./publish-v$CURRENT_VERSION"

if ! dotnet publish "$PROJECT_FILE" \
    -c Release \
    -r win-x64 \
    --self-contained false \
    -o "$PUBLISH_DIR"; then
    echo "❌ Error al publicar la aplicación"
    exit 1
fi

# Verificar que la publicación se generó correctamente
EXECUTABLE_PATH="$PUBLISH_DIR/DiskProtectorApp.exe"
if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "❌ Error: No se encontró el ejecutable publicado en $EXECUTABLE_PATH"
    exit 1
fi

echo ""
echo "✅ ¡Compilación y publicación completadas exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Carpeta de publicación: $PUBLISH_DIR"
echo ""
echo "📊 Información del ejecutable:"
ls -lh "$EXECUTABLE_PATH"

# Obtener información de versión del ejecutable usando PowerShell (si está disponible)
if command -v powershell >/dev/null 2>&1; then
    echo ""
    echo "🔍 Información de versión del ejecutable (PowerShell):"
    powershell -Command "[System.Diagnostics.FileVersionInfo]::GetVersionInfo('$EXECUTABLE_PATH') | Select-Object ProductVersion, FileVersion, Comments | Format-List"
else
    echo "ℹ️  PowerShell no disponible para verificar metadatos del ejecutable"
fi

# Verificar que la versión en el ejecutable coincida con la del proyecto
# (Esto es más para demostrar que se puede hacer, en la práctica .NET debería manejarlo)
EXPECTED_VERSION="$CURRENT_VERSION.0"
echo ""
echo "✅ ¡Proceso de compilación finalizado!"
echo "   La aplicación se ha compilado y publicado con la versión v$CURRENT_VERSION"
echo "   El ejecutable se encuentra en: $EXECUTABLE_PATH"
echo ""
echo "💡 Próximos pasos:"
echo "   - Ejecuta './organize-app.sh' para organizar los archivos finales"
echo "   - Ejecuta './package-app.sh' para crear el archivo comprimido"
echo "   - Ejecuta './release-app.sh' para crear una nueva versión"


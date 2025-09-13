#!/bin/bash

# package-app.sh - Empaqueta la aplicación en un archivo comprimido

set -e # Salir inmediatamente si un comando falla

echo "=== Empaquetando DiskProtectorApp ==="

# Verificar que existe la carpeta final
if [ ! -d "./DiskProtectorApp-final" ]; then
    echo "❌ Error: No se encontró la carpeta final (DiskProtectorApp-final)."
    echo "   Ejecuta './organize-app.sh' primero"
    exit 1
fi

# Obtener la versión actual
CURRENT_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" src/DiskProtectorApp/DiskProtectorApp.csproj)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="0.0.0"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Crear archivo comprimido final
ARCHIVE_NAME="DiskProtectorApp-v$CURRENT_VERSION-portable.tar.gz"
echo "📦 Creando archivo comprimido: $ARCHIVE_NAME..."

# Usar tar para crear el archivo comprimido
tar -czf "$ARCHIVE_NAME" -C ./DiskProtectorApp-final .

echo ""
echo "✅ ¡Empaquetado completado exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Archivo comprimido: $ARCHIVE_NAME"
echo ""
echo "📊 Tamaño del archivo comprimido:"
ls -lh "$ARCHIVE_NAME"

# Opcional: Crear también un archivo ZIP
if command -v zip >/dev/null 2>&1; then
    ZIP_NAME="DiskProtectorApp-v$CURRENT_VERSION-portable.zip"
    echo "📦 Creando archivo ZIP adicional: $ZIP_NAME..."
    (cd ./DiskProtectorApp-final && zip -r "../$ZIP_NAME" .)
    echo "✅ Archivo ZIP creado: $ZIP_NAME"
    echo "📊 Tamaño del archivo ZIP:"
    ls -lh "$ZIP_NAME"
fi


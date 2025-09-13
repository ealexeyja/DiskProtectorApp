#!/bin/bash

# package-app.sh - Empaqueta la aplicación en archivos comprimidos

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

# Crear archivo comprimido final TAR.GZ
ARCHIVE_NAME="DiskProtectorApp-v$CURRENT_VERSION-portable.tar.gz"
echo "📦 Creando archivo comprimido TAR.GZ: $ARCHIVE_NAME..."

# Usar tar para crear el archivo comprimido
tar -czf "$ARCHIVE_NAME" -C ./DiskProtectorApp-final .

echo ""
echo "✅ ¡Empaquetado TAR.GZ completado exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Archivo comprimido: $ARCHIVE_NAME"
echo ""
echo "📊 Tamaño del archivo comprimido TAR.GZ:"
ls -lh "$ARCHIVE_NAME"

# Crear archivo comprimido ZIP adicional
ZIP_NAME="DiskProtectorApp-v$CURRENT_VERSION-portable.zip"
echo "📦 Creando archivo comprimido ZIP adicional: $ZIP_NAME..."

# Verificar si zip está disponible
if command -v zip >/dev/null 2>&1; then
    # Usar zip para crear el archivo comprimido
    (cd ./DiskProtectorApp-final && zip -r "../$ZIP_NAME" .)
    echo ""
    echo "✅ ¡Empaquetado ZIP completado exitosamente!"
    echo "   Versión: v$CURRENT_VERSION"
    echo "   Archivo comprimido: $ZIP_NAME"
    echo ""
    echo "📊 Tamaño del archivo comprimido ZIP:"
    ls -lh "$ZIP_NAME"
else
    echo "⚠️  Advertencia: No se encontró el comando 'zip'."
    echo "   Para crear el archivo ZIP, instala 'zip':"
    echo "   - Ubuntu/Debian: sudo apt install zip"
    echo "   - CentOS/RHEL: sudo yum install zip"
    echo "   - Fedora: sudo dnf install zip"
    echo ""
    echo "💡 El empaquetado continuará sin el archivo ZIP."
fi

# Verificar que ambos archivos existen (si es posible)
if [ -f "$ARCHIVE_NAME" ]; then
    echo "✅ Archivo TAR.GZ verificado: $ARCHIVE_NAME"
else
    echo "❌ Error: No se pudo crear el archivo TAR.GZ"
    exit 1
fi

if [ -f "$ZIP_NAME" ]; then
    echo "✅ Archivo ZIP verificado: $ZIP_NAME"
else
    echo "⚠️  Archivo ZIP no creado (puede ser porque 'zip' no está instalado)"
fi

echo ""
echo "🎉 ¡Empaquetado completado exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Archivos generados:"
echo "   - $ARCHIVE_NAME"
if [ -f "$ZIP_NAME" ]; then
    echo "   - $ZIP_NAME"
fi


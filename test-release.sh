#!/bin/bash

echo "=== Verificando release de DiskProtectorApp ==="

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

echo "🔍 Verificando versión: v$CURRENT_VERSION"

# Verificar estructura de archivos
echo ""
echo "📂 Verificando estructura de archivos..."

if [ ! -d "./DiskProtectorApp-final" ]; then
    echo "❌ No se encontró la carpeta DiskProtectorApp-final"
    exit 1
fi

if [ ! -f "./DiskProtectorApp-final/DiskProtectorApp.exe" ]; then
    echo "❌ No se encontró el ejecutable principal"
    exit 1
fi

if [ ! -d "./DiskProtectorApp-final/libs" ]; then
    echo "❌ No se encontró la carpeta libs"
    exit 1
fi

if [ ! -d "./DiskProtectorApp-final/locales" ]; then
    echo "❌ No se encontró la carpeta locales"
    exit 1
fi

if [ ! -d "./DiskProtectorApp-final/config" ]; then
    echo "❌ No se encontró la carpeta config"
    exit 1
fi

echo "✅ Estructura de archivos verificada correctamente"

# Verificar archivo comprimido
echo ""
echo "📦 Verificando archivo comprimido..."

if [ ! -f "./DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "❌ No se encontró el archivo comprimido DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
    exit 1
fi

echo "✅ Archivo comprimido verificado correctamente"

# Verificar contenido del archivo comprimido
echo ""
echo "📋 Verificando contenido del archivo comprimido..."
tar -tzf ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz > /tmp/tar_contents.txt

REQUIRED_FILES=(
    "DiskProtectorApp.exe"
    "libs/"
    "locales/"
    "config/"
    "README.txt"
)

MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    if ! grep -q "$file" /tmp/tar_contents.txt; then
        echo "❌ Archivo requerido no encontrado en el tar.gz: $file"
        MISSING_FILES=1
    fi
done

if [ $MISSING_FILES -eq 0 ]; then
    echo "✅ Todos los archivos requeridos están presentes en el tar.gz"
else
    echo "❌ Algunos archivos requeridos faltan en el tar.gz"
    exit 1
fi

# Verificar GitHub
echo ""
echo "🌐 Verificando estado de GitHub..."

# Verificar si hay cambios sin commitear
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Hay cambios sin commitear"
else
    echo "✅ No hay cambios pendientes"
fi

# Verificar tags locales
echo ""
echo "🏷️  Tags locales:"
git tag --sort=-version:refname | head -5

# Verificar tags remotos
echo ""
echo "☁️  Tags remotos:"
git ls-remote --tags origin | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | sort -V | tail -5

echo ""
echo "✅ ¡Verificación completada exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Todos los archivos están correctamente generados"
echo ""
echo "📋 Siguientes pasos:"
echo "   1. git add ."
echo "   2. git commit -m \"release: v$CURRENT_VERSION - Nueva versión\""
echo "   3. git push origin main"
echo "   4. git tag -a v$CURRENT_VERSION -m \"Release v$CURRENT_VERSION\""
echo "   5. git push origin v$CURRENT_VERSION"

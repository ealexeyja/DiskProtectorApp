#!/bin/bash

# publish-to-github.sh - Publica una nueva versión en GitHub

set -e # Salir inmediatamente si un comando falla

echo "=== Publicación en GitHub de DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" src/DiskProtectorApp/DiskProtectorApp.csproj)
if [ -z "$CURRENT_VERSION" ]; then
    echo "⚠️  Advertencia: No se pudo leer la versión actual del .csproj. Usando 0.0.0 como base."
    CURRENT_VERSION="0.0.0"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Verificar que existe el archivo comprimido
ARCHIVE_NAME="DiskProtectorApp-v$CURRENT_VERSION-portable.tar.gz"
ZIP_NAME="DiskProtectorApp-v$CURRENT_VERSION-portable.zip"
INSTALLER_NAME="DiskProtectorApp-v$CURRENT_VERSION-installer.msi"
BOOTSTRAPPER_NAME="DiskProtectorApp-v$CURRENT_VERSION-bootstrapper.exe"

if [ ! -f "$ARCHIVE_NAME" ]; then
    echo "❌ Error: No se encontró el archivo comprimido ($ARCHIVE_NAME)."
    echo "   Ejecuta './release-app.sh' primero para generar los archivos."
    exit 1
fi

echo "🔍 Verificando archivos para publicar..."
FILES_TO_PUBLISH=()

if [ -f "$ARCHIVE_NAME" ]; then
    FILES_TO_PUBLISH+=("$ARCHIVE_NAME")
    echo "✅ Archivo TAR.GZ encontrado: $ARCHIVE_NAME"
fi

if [ -f "$ZIP_NAME" ]; then
    FILES_TO_PUBLISH+=("$ZIP_NAME")
    echo "✅ Archivo ZIP encontrado: $ZIP_NAME"
fi

if [ -f "$INSTALLER_NAME" ]; then
    FILES_TO_PUBLISH+=("$INSTALLER_NAME")
    echo "✅ Instalador MSI encontrado: $INSTALLER_NAME"
fi

if [ -f "$BOOTSTRAPPER_NAME" ]; then
    FILES_TO_PUBLISH+=("$BOOTSTRAPPER_NAME")
    echo "✅ Bootstrapper EXE encontrado: $BOOTSTRAPPER_NAME"
fi

if [ ${#FILES_TO_PUBLISH[@]} -eq 0 ]; then
    echo "❌ Error: No se encontraron archivos para publicar."
    exit 1
fi

# Verificar que git está disponible
if ! command -v git &> /dev/null; then
    echo "❌ Error: Git no está instalado o no está en el PATH."
    exit 1
fi

# Verificar que estamos en un repositorio git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: No estás en un repositorio Git."
    exit 1
fi

# Verificar si hay cambios sin commitear
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Hay cambios sin commitear:"
    git status --porcelain
    echo ""
    read -p "❓ ¿Deseas continuar y commitear automáticamente estos cambios? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo "📥 Agregando todos los cambios..."
        git add .
        
        echo "📝 Creando commit..."
        git commit -m "release: v$CURRENT_VERSION - Nueva versión"
    else
        echo "⚠️  Operación cancelada. Commitea los cambios manualmente antes de publicar."
        exit 0
    fi
else
    echo "✅ No hay cambios pendientes en el working directory."
fi

# Preguntar si desea publicar en GitHub
echo ""
echo "☁️  ¿Deseas publicar la versión v$CURRENT_VERSION en GitHub? (s/n)"
read -p "   Esta acción incluye push al remoto, crear tag y subir el tag: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "⚠️  Publicación en GitHub cancelada."
    exit 0
fi

# Subir cambios a GitHub
echo "🚀 Subiendo cambios a GitHub..."
if ! git push origin main; then
    echo "❌ Error al subir cambios a GitHub"
    exit 1
fi

# Crear tag local
echo "🏷️  Creando tag v$CURRENT_VERSION..."
git tag -a "v$CURRENT_VERSION" -m "Release v$CURRENT_VERSION"

# Subir tag a GitHub
echo "📤 Subiendo tag a GitHub..."
if ! git push origin "v$CURRENT_VERSION"; then
    echo "❌ Error al subir el tag a GitHub"
    exit 1
fi

echo ""
echo "✅ ¡Publicación en GitHub iniciada exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Tag: v$CURRENT_VERSION"
echo ""
echo "📊 El workflow de GitHub Actions se ejecutará automáticamente"
echo "   al crear el tag v$CURRENT_VERSION"
echo ""
echo "💡 Para monitorear el progreso:"
echo "   1. Ve a https://github.com/$(git remote get-url origin | sed 's/.*:\/\/github.com\///' | sed 's/\.git$//')/actions"
echo "   2. Busca el workflow CI/CD Pipeline"
echo "   3. Verifica que se esté ejecutando"
echo ""
echo "📦 Archivos que se publicarán como assets del release:"
for file in "${FILES_TO_PUBLISH[@]}"; do
    echo "   - $file"
done

# Notificar que los archivos se adjuntarán automáticamente al release por GitHub Actions
echo ""
echo "ℹ️  Nota: Los archivos se adjuntarán automáticamente al release"
echo "   por el workflow de GitHub Actions cuando se cree el tag."


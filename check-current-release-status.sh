#!/bin/bash

echo "=== Verificando estado actual del release de DiskProtectorApp ==="

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

echo "🔍 Versión actual en el proyecto: v$CURRENT_VERSION"

echo ""
echo "📂 Verificando carpetas generadas..."

# Verificar cada posible carpeta de salida
FOLDERS_FOUND=0

if [ -d "./publish-test" ]; then
    echo "✅ Carpeta de prueba encontrada: publish-test/"
    ls -la ./publish-test/DiskProtectorApp.exe 2>/dev/null && echo "   - Ejecutable presente" || echo "   - Ejecutable NO encontrado"
    FOLDERS_FOUND=1
fi

if [ -d "./publish-v$CURRENT_VERSION" ]; then
    echo "✅ Carpeta de publicación encontrada: publish-v$CURRENT_VERSION/"
    ls -la ./publish-v$CURRENT_VERSION/DiskProtectorApp.exe 2>/dev/null && echo "   - Ejecutable presente" || echo "   - Ejecutable NO encontrado"
    FOLDERS_FOUND=1
fi

if [ -d "./DiskProtectorApp-final" ]; then
    echo "✅ Carpeta final encontrada: DiskProtectorApp-final/"
    ls -la ./DiskProtectorApp-final/DiskProtectorApp.exe 2>/dev/null && echo "   - Ejecutable presente" || echo "   - Ejecutable NO encontrado"
    FOLDERS_FOUND=1
fi

if [ -d "./DiskProtectorApp-organized" ]; then
    echo "✅ Carpeta organizada encontrada: DiskProtectorApp-organized/"
    ls -la ./DiskProtectorApp-organized/DiskProtectorApp.exe 2>/dev/null && echo "   - Ejecutable presente" || echo "   - Ejecutable NO encontrado"
    FOLDERS_FOUND=1
fi

if [ $FOLDERS_FOUND -eq 0 ]; then
    echo "⚠️  No se encontraron carpetas de salida. Debes ejecutar './prepare-new-release.sh' primero."
fi

echo ""
echo "📦 Verificando archivos comprimidos..."

if [ -f "./DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "✅ Archivo comprimido encontrado: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
    echo "   Tamaño: $(ls -lh ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz | awk '{print $5}')"
else
    echo "⚠️  Archivo comprimido NO encontrado: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
fi

echo ""
echo "🏷️  Verificando tags..."

echo "Tags locales:"
git tag --sort=-version:refname | grep "v.*\..*\..*" | head -5

echo ""
echo "☁️  Verificando tags remotos:"
git ls-remote --tags origin 2>/dev/null | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | sort -V | tail -5

echo ""
echo "🔍 Estado de Git:"
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Hay cambios sin commitear:"
    git status --porcelain
else
    echo "✅ No hay cambios pendientes"
fi

echo ""
echo "�� Resumen:"
echo "   - Versión actual: v$CURRENT_VERSION"
echo "   - Carpetas encontradas: $FOLDERS_FOUND"
if [ -f "./DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "   - Archivo comprimido: ✅ Presente"
else
    echo "   - Archivo comprimido: ❌ No encontrado"
fi

if [ $FOLDERS_FOUND -eq 0 ]; then
    echo ""
    echo "💡 Recomendación:"
    echo "   Ejecuta './prepare-new-release.sh' para generar las carpetas de salida"
elif [ ! -f "./DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo ""
    echo "💡 Recomendación:"
    echo "   Ejecuta './finalize-release.sh' para crear el archivo comprimido"
else
    echo ""
    echo "💡 Recomendación:"
    echo "   Todo parece estar en orden. Puedes proceder con la publicación en GitHub:"
    echo "   1. git add ."
    echo "   2. git commit -m \"release: v$CURRENT_VERSION - Nueva versión\""
    echo "   3. git push origin main"
    echo "   4. git tag -a v$CURRENT_VERSION -m \"Release v$CURRENT_VERSION\""
    echo "   5. git push origin v$CURRENT_VERSION"
fi

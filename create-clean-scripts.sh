#!/bin/bash

echo "=== Creando scripts limpios y funcionales ==="

# Limpiar archivos con nombres corruptos
echo "🧹 Limpiando archivos con nombres corruptos..."
rm -f ./create-missing-scripts.shipts.sh
rm -f ./verify-app-structure.sh
rm -f ./clean-and-restart.sh
rm -f ./prepare-new-release.sh
rm -f ./build-and-test.sh
rm -f ./finalize-release.sh
rm -f ./publish-release.sh
rm -f ./test-release.sh
rm -f ./release-workflow-complete.sh
rm -f ./fix-*.sh
rm -f ./update-*.sh
rm -f ./organize-*.sh
rm -f ./reorganize-*.sh

# Crear script para verificar estructura de la aplicación
cat > verify-structure.sh << 'VERIFYSTRUCTUREEOF'
#!/bin/bash

echo "=== Verificando estructura de la aplicación ==="

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

# Verificar estructura de carpetas existentes
echo ""
echo "📂 Verificando estructura de carpetas existentes..."
echo "============================================="

FOLDERS_FOUND=0
if [ -d "DiskProtectorApp-final" ]; then
    echo "✅ Carpeta DiskProtectorApp-final encontrada"
    FOLDERS_FOUND=$((FOLDERS_FOUND + 1))
    echo "   Contenido:"
    ls -la DiskProtectorApp-final/ | head -10
fi

if [ -d "publish-test" ]; then
    echo "✅ Carpeta publish-test encontrada"
    FOLDERS_FOUND=$((FOLDERS_FOUND + 1))
    echo "   Contenido:"
    ls -la publish-test/ | head -10
fi

if [ -d "publish-v$CURRENT_VERSION" ]; then
    echo "✅ Carpeta publish-v$CURRENT_VERSION encontrada"
    FOLDERS_FOUND=$((FOLDERS_FOUND + 1))
    echo "   Contenido:"
    ls -la publish-v$CURRENT_VERSION/ | head -10
fi

echo ""
echo "📊 Total carpetas encontradas: $FOLDERS_FOUND"

# Verificar archivos comprimidos
echo ""
echo "📦 Verificando archivos comprimidos..."
echo "==================================="

if [ -f "DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "✅ Archivo comprimido encontrado: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
    echo "   Tamaño: $(ls -lh DiskProtectorApp-v$CURRENT_VERSION.tar.gz | awk '{print $5}')"
else
    echo "⚠️  Archivo comprimido NO encontrado: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
fi

# Verificar contenido del archivo comprimido si existe
if [ -f "DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo ""
    echo "📋 Contenido del archivo comprimido:"
    echo "=================================="
    tar -tzf ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz | head -20
    echo "   ... ($(tar -tzf ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz | wc -l) archivos en total)"
fi

# Verificar estado de Git
echo ""
echo "🔍 Verificando estado de Git..."
echo "============================"

if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Hay cambios sin commitear:"
    git status --porcelain
else
    echo "✅ No hay cambios pendientes"
fi

echo ""
echo "🏷️  Tags locales:"
git tag --sort=-version:refname | head -5

echo ""
echo "☁️  Tags remotos:"
git ls-remote --tags origin 2>/dev/null | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | sort -V | tail -5

echo ""
echo "✅ Verificación completada"
echo ""
echo "💡 Siguientes pasos recomendados:"
if [ $FOLDERS_FOUND -eq 0 ]; then
    echo "   1. Ejecutar './build-app.sh' para generar la estructura"
elif [ ! -f "DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "   1. Ejecutar './package-app.sh' para crear el archivo comprimido"
else
    echo "   1. La estructura parece completa y correcta"
    echo "   2. Puedes proceder con la publicación en GitHub:"
    echo "      git add ."
    echo "      git commit -m \"release: v$CURRENT_VERSION - Nueva versión\""
    echo "      git push origin main"
    echo "      git tag -a v$CURRENT_VERSION -m \"Release v$CURRENT_VERSION\""
    echo "      git push origin v$CURRENT_VERSION"
fi

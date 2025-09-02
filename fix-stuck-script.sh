#!/bin/bash

echo "=== Corrigiendo script detenido ==="

# Crear script para verificar la estructura actual y corregir problemas
cat > verify-and-fix-structure.sh << 'VERIFYFIXEOF'
#!/bin/bash

echo "=== Verificando y corrigiendo estructura de la aplicación ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto. Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

echo "✅ Directorio correcto verificado"

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
    echo "   1. Ejecutar './prepare-new-release.sh' para generar la estructura"
elif [ ! -f "DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "   1. Ejecutar './finalize-release.sh' para crear el archivo comprimido"
else
    echo "   1. La estructura parece completa y correcta"
    echo "   2. Puedes proceder con la publicación en GitHub:"
    echo "      git add ."
    echo "      git commit -m \"release: v$CURRENT_VERSION - Nueva versión\""
    echo "      git push origin main"
    echo "      git tag -a v$CURRENT_VERSION -m \"Release v$CURRENT_VERSION\""
    echo "      git push origin v$CURRENT_VERSION"
fi

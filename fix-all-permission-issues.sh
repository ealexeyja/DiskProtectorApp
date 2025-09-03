#!/bin/bash

echo "=== Corrigiendo todos los problemas de permisos ==="

# Limpiar archivos con nombres corruptos
echo "🧹 Limpiando archivos con nombres corruptos..."
rm -f ./implement-correct-permission-logic.shogic.sh
rm -f ./implement-correct-permission-logic.sh
rm -f ./update-build-scripts.sh
rm -f ./test-release-corrected.sh
rm -f ./fix-permission-logic-final.sh
rm -f ./fix-button-activation-issue.sh
rm -f ./fix-compilation-errors.sh
rm -f ./fix-nullability-warnings.sh
rm -f ./fix-github-actions-windows.sh
rm -f ./fix-release-structure.sh
rm -f ./organize-app-structure.sh
rm -f ./reorganize-app-structure.sh
rm -f ./fix-naming-issue.sh
rm -f ./fix-stuck-script.sh

# Crear script para verificar estructura actual
cat > check-current-structure.sh << 'CHECKSTRUCTUREEOF'
#!/bin/bash

echo "=== Verificando estructura actual ==="

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
echo "📂 Verificando estructura de carpetas..."
echo "===================================="

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

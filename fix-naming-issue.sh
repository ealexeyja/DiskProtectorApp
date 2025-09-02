#!/bin/bash

echo "=== Corrigiendo problema de nombres de archivo ==="

# Limpiar archivos con nombres corruptos
echo "🧹 Limpiando archivos con nombres corruptos..."
rm -f ./fix-stuck-script.shript.shpiar
rm -f ./verify-and-fix-structure.sh
rm -f ./clean-and-restart.sh

# Crear script de verificación simple y limpio
cat > check-app-status.sh << 'CHECKEOF'
#!/bin/bash

echo "=== Verificando estado actual de la aplicación ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

echo "✅ Directorio correcto verificado"

# Obtener la versión actual
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.2.6"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Verificar estructura de carpetas
echo ""
echo "📂 Verificando estructura de carpetas..."
echo "===================================="

FOLDERS=0
if [ -d "publish-test" ]; then
    echo "✅ publish-test/ encontrada"
    FOLDERS=$((FOLDERS + 1))
fi

if [ -d "publish-v$CURRENT_VERSION" ]; then
    echo "✅ publish-v$CURRENT_VERSION/ encontrada"
    FOLDERS=$((FOLDERS + 1))
fi

if [ -d "DiskProtectorApp-final" ]; then
    echo "✅ DiskProtectorApp-final/ encontrada"
    FOLDERS=$((FOLDERS + 1))
fi

echo "📊 Total carpetas encontradas: $FOLDERS"

# Verificar archivos comprimidos
echo ""
echo "📦 Verificando archivos comprimidos..."
echo "==================================="

if [ -f "DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "✅ DiskProtectorApp-v$CURRENT_VERSION.tar.gz encontrado"
    echo "   Tamaño: $(ls -lh DiskProtectorApp-v$CURRENT_VERSION.tar.gz | awk '{print $5}')"
else
    echo "⚠️  DiskProtectorApp-v$CURRENT_VERSION.tar.gz NO encontrado"
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
echo "✅ Verificación completada"

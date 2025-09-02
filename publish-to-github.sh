#!/bin/bash

echo "=== Publicando en GitHub ==="

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

# Verificar que existe el archivo comprimido
if [ ! -f "./DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "❌ Error: No se encontró el archivo comprimido."
    echo "   Ejecuta './create-compressed-archive.sh' primero"
    exit 1
fi

# Commitear cambios
echo "📥 Agregando todos los cambios..."
git add .

echo "📝 Creando commit..."
git commit -m "release: v$CURRENT_VERSION - Nueva versión"

echo "🚀 Subiendo cambios a GitHub..."
if ! git push origin main; then
    echo "❌ Error al subir cambios a GitHub"
    exit 1
fi

# Crear tag
echo "🏷️  Creando tag v$CURRENT_VERSION..."
git tag -a "v$CURRENT_VERSION" -m "Release v$CURRENT_VERSION"

echo "📤 Subiendo tag a GitHub..."
if ! git push origin "v$CURRENT_VERSION"; then
    echo "❌ Error al subir el tag a GitHub"
    exit 1
fi

echo ""
echo "✅ ¡Publicación en GitHub completada exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Tag: v$CURRENT_VERSION"
echo ""
echo "📊 El workflow de GitHub Actions se ejecutará automáticamente"
echo "   al crear el tag v$CURRENT_VERSION"
echo ""
echo "💡 Para monitorear el progreso:"
echo "   1. Ve a https://github.com/tu-usuario/DiskProtectorApp/actions"
echo "   2. Busca el workflow CI/CD Pipeline"
echo "   3. Verifica que se esté ejecutando"

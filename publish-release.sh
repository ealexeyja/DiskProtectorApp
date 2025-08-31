#!/bin/bash

echo "=== Publicando nueva versión de DiskProtectorApp ==="

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

echo "📦 Versión a publicar: v$CURRENT_VERSION"

# Verificar si hay cambios sin commitear
if ! git diff-index --quiet HEAD --; then
    echo "🔍 Cambios detectados, procediendo con la publicación..."
else
    echo "✅ No hay cambios pendientes"
fi

echo ""
echo "🚀 Ejecutando pasos de publicación..."
echo "==================================="

# Paso 1: git add .
echo "1️⃣ Agregando todos los archivos..."
git add .

# Paso 2: git commit
echo "2️⃣ Creando commit..."
git commit -m "release: v$CURRENT_VERSION - Nueva versión"

# Paso 3: git push origin main
echo "3️⃣ Subiendo cambios a GitHub..."
git push origin main

# Paso 4: git tag
echo "4️⃣ Creando tag v$CURRENT_VERSION..."
git tag -a v$CURRENT_VERSION -m "Release v$CURRENT_VERSION"

# Paso 5: git push tag
echo "5️⃣ Subiendo tag a GitHub..."
git push origin v$CURRENT_VERSION

echo ""
echo "🎉 ¡Publicación completada exitosamente!"
echo "   Versión publicada: v$CURRENT_VERSION"
echo ""
echo "📊 Siguientes pasos:"
echo "   - El workflow de GitHub Actions se ejecutará automáticamente"
echo "   - Puedes monitorear el progreso en la sección Actions de tu repositorio"
echo "   - Una vez completado, el release estará disponible en la sección Releases"
echo ""
echo "🔗 Enlaces útiles:"
echo "   GitHub Actions: https://github.com/tu-usuario/DiskProtectorApp/actions"
echo "   GitHub Releases: https://github.com/tu-usuario/DiskProtectorApp/releases"

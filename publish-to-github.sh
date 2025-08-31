#!/bin/bash

echo "=== Publicando nueva versión en GitHub ==="

# Obtener la versión actual
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
echo "📦 Versión a publicar: v$CURRENT_VERSION"

# Verificar que existe el archivo comprimido
if [ ! -f "./DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "❌ Error: No se encontró el archivo comprimido."
    echo "   Ejecuta './build-and-release.sh' primero"
    exit 1
fi

echo "🚀 Publicando en GitHub..."
echo "========================"

# Asegurarse de que todos los cambios están commiteados
echo "1️⃣ Agregando todos los archivos..."
git add .

echo "2️⃣ Creando commit..."
git commit -m "release: v$CURRENT_VERSION - Nueva versión"

echo "3️⃣ Subiendo cambios a GitHub..."
git push origin main

echo "4️⃣ Creando tag v$CURRENT_VERSION..."
git tag -a v$CURRENT_VERSION -m "Release v$CURRENT_VERSION"

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

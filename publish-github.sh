#!/bin/bash

echo "=== DiskProtectorApp GitHub Publish Script ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto. Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.0.0"
fi

echo "📦 Versión a publicar: v$CURRENT_VERSION"

# Verificar si ya existe la carpeta de publicación
if [ ! -d "./publish-v$CURRENT_VERSION" ]; then
    echo "❌ Error: No se encontró la carpeta de publicación. Ejecuta primero el script de compilación."
    exit 1
fi

# Verificar que el ejecutable existe
if [ ! -f "./publish-v$CURRENT_VERSION/DiskProtectorApp.exe" ]; then
    echo "❌ Error: No se encontró el ejecutable. Ejecuta primero el script de compilación."
    exit 1
fi

# Crear archivo comprimido si no existe
if [ ! -f "DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "📦 Creando archivo comprimido..."
    if ! tar -czf DiskProtectorApp-v$CURRENT_VERSION.tar.gz -C ./publish-v$CURRENT_VERSION .; then
        echo "❌ Error al crear el archivo comprimido"
        exit 1
    fi
    echo "✅ Archivo comprimido creado: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
fi

# Verificar si el tag ya existe
if git rev-parse "v$CURRENT_VERSION" >/dev/null 2>&1; then
    echo "⚠️  El tag v$CURRENT_VERSION ya existe en el repositorio"
else
    echo "🏷️  Creando tag v$CURRENT_VERSION..."
    git tag -a "v$CURRENT_VERSION" -m "Release v$CURRENT_VERSION"
    echo "✅ Tag v$CURRENT_VERSION creado"
fi

echo ""
echo "📋 Instrucciones para publicar en GitHub:"
echo "1. git add ."
echo "2. git commit -m \"release: v$CURRENT_VERSION - Compilación y empaquetado\""
echo "3. git push origin main"
echo "4. git push origin v$CURRENT_VERSION"
echo ""
echo "📝 Para crear el release manualmente en GitHub:"
echo "   - Ve a la sección Releases en tu repositorio"
echo "   - Crea un nuevo release con el tag v$CURRENT_VERSION"
echo "   - Adjunta el archivo DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
echo "   - Agrega notas de versión descriptivas"
echo ""
echo "🎉 ¡Listo para publicar!"

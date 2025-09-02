#!/bin/bash

echo "=== Publicando aplicación ==="

# Obtener versión
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
echo "📦 Versión: v$CURRENT_VERSION"

# Verificar archivo comprimido
if [ ! -f "./DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "❌ Error: No se encontró el archivo comprimido"
    exit 1
fi

# Commitear cambios
git add .
git commit -m "release: v$CURRENT_VERSION"

# Push a main
git push origin main

# Crear y subir tag
git tag -a "v$CURRENT_VERSION" -m "Release v$CURRENT_VERSION"
git push origin "v$CURRENT_VERSION"

echo "✅ Publicación completada"
echo "   Tag: v$CURRENT_VERSION"

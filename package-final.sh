#!/bin/bash

echo "=== Empaquetando versión final ==="

# Verificar que existe la carpeta final
if [ ! -d "./DiskProtectorApp-final" ]; then
    echo "❌ Error: No se encontró la carpeta final."
    echo "   Ejecuta './organize-final.sh' primero"
    exit 1
fi

# Obtener la versión actual
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.2.7"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Crear archivo comprimido final
echo "📦 Creando archivo comprimido final..."
tar -czf DiskProtectorApp-v$CURRENT_VERSION.tar.gz -C ./DiskProtectorApp-final .

echo ""
echo "✅ ¡Empaquetado completado exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Archivo comprimido: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
echo ""
echo "📊 Tamaño del archivo comprimido:"
ls -lh DiskProtectorApp-v$CURRENT_VERSION.tar.gz

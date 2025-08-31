#!/bin/bash

echo "=== Creando archivo comprimido final ==="

# Verificar que existe la carpeta final
if [ ! -d "DiskProtectorApp-final" ]; then
    echo "❌ Error: No se encontró la carpeta DiskProtectorApp-final"
    echo "   Ejecuta './reorganize-app-structure.sh' primero"
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.1.0"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Crear archivo comprimido final
echo "📦 Creando archivo comprimido: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
tar -czf DiskProtectorApp-v$CURRENT_VERSION.tar.gz -C ./DiskProtectorApp-final .

# Verificar que el archivo se creó correctamente
if [ -f "./DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "✅ Archivo comprimido creado exitosamente!"
    echo ""
    echo "📊 Información del archivo:"
    ls -lh ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz
    echo ""
    echo "📁 Contenido del archivo (primeros 20 archivos):"
    tar -tzf ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz | head -20
    echo ""
    echo "💾 Para descargar el archivo:"
    echo "   - En Codespaces: Haz clic derecho en el archivo y selecciona 'Download'"
    echo "   - En terminal: scp usuario@servidor:/ruta/DiskProtectorApp-v$CURRENT_VERSION.tar.gz ."
else
    echo "❌ Error: No se pudo crear el archivo comprimido"
    exit 1
fi

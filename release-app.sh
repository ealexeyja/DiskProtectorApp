#!/bin/bash

# release-app.sh - Proceso completo de release de DiskProtectorApp

set -e # Salir inmediatamente si un comando falla

echo "=== Proceso completo de release de DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" src/DiskProtectorApp/DiskProtectorApp.csproj)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="0.0.0"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Preguntar si desea incrementar la versión
echo ""
echo "🔢 ¿Deseas incrementar la versión automáticamente? (s/n)"
read -r incrementar
if [[ "$incrementar" =~ ^[Ss]$ ]]; then
    # Usar el script de actualización de versión
    if [ -f "./update-version.sh" ]; then
        echo "📈 Incrementando versión automáticamente..."
        ./update-version.sh -i
        
        # Volver a obtener la nueva versión
        CURRENT_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" src/DiskProtectorApp/DiskProtectorApp.csproj)
        echo "📦 Nueva versión: v$CURRENT_VERSION"
    else
        echo "❌ No se encontró el script update-version.sh"
        exit 1
    fi
fi

# Limpiar compilaciones anteriores
echo ""
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-final ./DiskProtectorApp-v$CURRENT_VERSION*.tar.gz ./DiskProtectorApp-v$CURRENT_VERSION*.zip

# Ejecutar proceso completo
echo ""
echo "🔨 Iniciando proceso de compilación..."
if [ -f "./build-app.sh" ]; then
    ./build-app.sh
else
    echo "❌ No se encontró el script build-app.sh"
    exit 1
fi

echo ""
echo "📂 Iniciando proceso de organización..."
if [ -f "./organize-app.sh" ]; then
    ./organize-app.sh
else
    echo "❌ No se encontró el script organize-app.sh"
    exit 1
fi

echo ""
echo "📦 Iniciando proceso de empaquetado..."
if [ -f "./package-app.sh" ]; then
    ./package-app.sh
else
    echo "❌ No se encontró el script package-app.sh"
    exit 1
fi

echo ""
echo "🎉 ¡Proceso de release completado exitosamente!"
echo "   Versión final: v$CURRENT_VERSION"
echo ""
echo "�� Archivos generados:"
echo "   - Carpeta organizada: DiskProtectorApp-final/"
echo "   - Carpeta de publicación: publish-v$CURRENT_VERSION/"
echo "   - Archivo comprimido TAR.GZ: DiskProtectorApp-v$CURRENT_VERSION-portable.tar.gz"
if [ -f "DiskProtectorApp-v$CURRENT_VERSION-portable.zip" ]; then
    echo "   - Archivo comprimido ZIP: DiskProtectorApp-v$CURRENT_VERSION-portable.zip"
fi
echo ""
echo "📊 Tamaño de los archivos generados:"
ls -lh DiskProtectorApp-v$CURRENT_VERSION*

echo ""
echo "�� Siguientes pasos:"
echo "   1. Para publicar en GitHub:"
echo "      - git add ."
echo "      - git commit -m \"release: v$CURRENT_VERSION\""
echo "      - git push origin main"
echo "      - git tag -a \"v$CURRENT_VERSION\" -m \"Release v$CURRENT_VERSION\""
echo "      - git push origin \"v$CURRENT_VERSION\""
echo ""
echo "   2. Crear un nuevo release en GitHub con los archivos generados"


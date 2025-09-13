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
echo "�� ¿Deseas publicar esta versión en GitHub ahora? (s/n)"
read -p "   Esta acción incluye crear commit (si hay cambios), tag y subir a GitHub: " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    if [ -f "./publish-to-github.sh" ]; then
        ./publish-to-github.sh
    else
        echo "❌ No se encontró el script publish-to-github.sh"
        echo "   Puedes ejecutarlo manualmente después con: ./publish-to-github.sh"
    fi
else
    echo "💡 Puedes publicar en GitHub más tarde ejecutando: ./publish-to-github.sh"
fi

echo ""
echo "🎉 ¡Proceso de release completado exitosamente!"
echo "   Versión final: v$CURRENT_VERSION"


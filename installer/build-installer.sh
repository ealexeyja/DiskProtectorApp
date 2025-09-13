#!/bin/bash

# build-installer.sh - Script para construir el instalador de DiskProtectorApp en Linux

set -e # Salir inmediatamente si un comando falla

echo "=== Construyendo instalador de DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" src/DiskProtectorApp/DiskProtectorApp.csproj)
if [ -z "$CURRENT_VERSION" ]; then
    echo "⚠️  Advertencia: No se pudo leer la versión actual del .csproj. Usando 0.0.0 como base."
    CURRENT_VERSION="0.0.0"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Verificar que existe la carpeta de publicación
PUBLISH_DIR="publish-v$CURRENT_VERSION"
if [ ! -d "$PUBLISH_DIR" ]; then
    echo "❌ Error: No se encontró la carpeta de publicación ($PUBLISH_DIR)."
    echo "   Ejecuta './release-app.sh' primero para generar los archivos."
    exit 1
fi

# Verificar que existe WiX Toolset (en Linux necesitamos wine o herramientas alternativas)
# Para este ejemplo, asumiremos que se usará en un entorno Windows o con wine
echo "🔧 Verificando herramientas de instalación..."
if ! command -v candle.exe >/dev/null 2>&1 && ! command -v wine >/dev/null 2>&1; then
    echo "⚠️  Advertencia: No se encontró WiX Toolset ni wine."
    echo "   Para construir el instalador en Linux, necesitas:"
    echo "   1. Instalar wine: sudo apt install wine"
    echo "   2. Descargar e instalar WiX Toolset en wine"
    echo "   3. Asegurarte de que candle.exe y light.exe estén en el PATH"
    echo ""
    echo "💡 Alternativa: Construye el instalador en un entorno Windows"
    exit 1
fi

# Verificar que existe el archivo .wxs
if [ ! -f "installer/DiskProtectorApp.wxs" ]; then
    echo "❌ Error: No se encontró el archivo installer/DiskProtectorApp.wxs."
    exit 1
fi

# Establecer la variable de entorno para la versión
export APP_VERSION="$CURRENT_VERSION"

# Compilar el instalador usando wine (si está disponible)
echo "🔨 Compilando instalador con WiX..."
if command -v wine >/dev/null 2>&1; then
    # Usar wine para ejecutar WiX
    wine candle.exe -arch x64 -dAPP_VERSION="$CURRENT_VERSION" -out installer/DiskProtectorApp.wixobj installer/DiskProtectorApp.wxs
    if [ $? -ne 0 ]; then
        echo "❌ Error al compilar el instalador con wine"
        exit 1
    fi

    # Enlazar el instalador usando wine
    wine light.exe -out installer/DiskProtectorApp-v$CURRENT_VERSION-installer.msi installer/DiskProtectorApp.wixobj
    if [ $? -ne 0 ]; then
        echo "❌ Error al enlazar el instalador con wine"
        exit 1
    fi
else
    # Intentar ejecutar directamente (si las herramientas están en el PATH)
    candle.exe -arch x64 -dAPP_VERSION="$CURRENT_VERSION" -out installer/DiskProtectorApp.wixobj installer/DiskProtectorApp.wxs
    if [ $? -ne 0 ]; then
        echo "❌ Error al compilar el instalador"
        exit 1
    fi

    light.exe -out installer/DiskProtectorApp-v$CURRENT_VERSION-installer.msi installer/DiskProtectorApp.wixobj
    if [ $? -ne 0 ]; then
        echo "❌ Error al enlazar el instalador"
        exit 1
    fi
fi

echo ""
echo "✅ ¡Instalador construido exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Archivo: installer/DiskProtectorApp-v$CURRENT_VERSION-installer.msi"
echo ""
echo "📊 Tamaño del instalador:"
ls -lh installer/DiskProtectorApp-v$CURRENT_VERSION-installer.msi

# Copiar el instalador a la carpeta final para incluirlo en el release
if [ -f "DiskProtectorApp-final" ]; then
    echo "📂 Copiando instalador a la carpeta final..."
    cp installer/DiskProtectorApp-v$CURRENT_VERSION-installer.msi DiskProtectorApp-final/
    echo "✅ Instalador copiado a DiskProtectorApp-final/"
fi


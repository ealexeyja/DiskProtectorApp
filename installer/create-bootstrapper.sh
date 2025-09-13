#!/bin/bash

# create-bootstrapper.sh - Script para crear un instalador con requisitos previos (bootstrapper) en Linux

set -e # Salir inmediatamente si un comando falla

echo "=== Creando bootstrapper de DiskProtectorApp ==="

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" src/DiskProtectorApp/DiskProtectorApp.csproj)
if [ -z "$CURRENT_VERSION" ]; then
    echo "⚠️  Advertencia: No se pudo leer la versión actual del .csproj. Usando 0.0.0 como base."
    CURRENT_VERSION="0.0.0"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Verificar que existe el instalador MSI
INSTALLER_FILE="installer/DiskProtectorApp-v$CURRENT_VERSION-installer.msi"
if [ ! -f "$INSTALLER_FILE" ]; then
    echo "❌ Error: No se encontró el instalador MSI ($INSTALLER_FILE)."
    echo "   Ejecuta './installer/build-installer.sh' primero."
    exit 1
fi

# Verificar que existe WiX Toolset (en Linux necesitamos wine o herramientas alternativas)
echo "🔧 Verificando herramientas de bootstrapper..."
if ! command -v torch.exe >/dev/null 2>&1 && ! command -v wine >/dev/null 2>&1; then
    echo "⚠️  Advertencia: No se encontró WiX Toolset ni wine."
    echo "   Para crear el bootstrapper en Linux, necesitas:"
    echo "   1. Instalar wine: sudo apt install wine"
    echo "   2. Descargar e instalar WiX Toolset en wine"
    echo "   3. Asegurarte de que torch.exe esté en el PATH"
    echo ""
    echo "💡 Alternativa: Crea el bootstrapper en un entorno Windows"
    exit 1
fi

# Crear archivo de configuración del bootstrapper
echo "📝 Creando archivo de configuración..."
cat > installer/Bootstrapper.wxs << BOOTSTRAPPER_EOF
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi"
     xmlns:bal="http://schemas.microsoft.com/wix/BalExtension">
  <Bundle Name="DiskProtectorApp Bootstrapper v$CURRENT_VERSION"
          Version="$CURRENT_VERSION"
          Manufacturer="Emigdio Alexey Jimenez Acosta"
          UpgradeCode="87654321-4321-4321-4321-210987654321">
    <BootstrapperApplicationRef Id="WixStandardBootstrapperApplication.RtfLicense">
      <bal:WixStandardBootstrapperApplication
          LicenseFile="installer/license.rtf"
          Theme="hyperlinkLargeLicense" />
    </BootstrapperApplicationRef>
    <Chain>
      <!-- Requisitos previos -->
      <PackageGroupRef Id="NetFx80DesktopRedist"/>
      <!-- Aplicación principal -->
      <MsiPackage SourceFile="$INSTALLER_FILE"
                  DisplayName="DiskProtectorApp"/>
    </Chain>
  </Bundle>
</Wix>
BOOTSTRAPPER_EOF

# Compilar y enlazar el bootstrapper usando wine (si está disponible)
echo "🔨 Compilando y enlazando bootstrapper..."
if command -v wine >/dev/null 2>&1; then
    # Usar wine para ejecutar WiX
    wine candle.exe -ext WixBalExtension -out installer/Bootstrapper.wixobj installer/Bootstrapper.wxs
    if [ $? -ne 0 ]; then
        echo "❌ Error al compilar el bootstrapper con wine"
        exit 1
    fi

    # Enlazar el bootstrapper usando wine
    wine light.exe -ext WixBalExtension -out installer/DiskProtectorApp-v$CURRENT_VERSION-bootstrapper.exe installer/Bootstrapper.wixobj
    if [ $? -ne 0 ]; then
        echo "❌ Error al enlazar el bootstrapper con wine"
        exit 1
    fi
else
    # Intentar ejecutar directamente (si las herramientas están en el PATH)
    candle.exe -ext WixBalExtension -out installer/Bootstrapper.wixobj installer/Bootstrapper.wxs
    if [ $? -ne 0 ]; then
        echo "❌ Error al compilar el bootstrapper"
        exit 1
    fi

    light.exe -ext WixBalExtension -out installer/DiskProtectorApp-v$CURRENT_VERSION-bootstrapper.exe installer/Bootstrapper.wixobj
    if [ $? -ne 0 ]; then
        echo "❌ Error al enlazar el bootstrapper"
        exit 1
    fi
fi

echo ""
echo "✅ ¡Bootstrapper creado exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Archivo: installer/DiskProtectorApp-v$CURRENT_VERSION-bootstrapper.exe"
echo ""
echo "📊 Tamaño del bootstrapper:"
ls -lh installer/DiskProtectorApp-v$CURRENT_VERSION-bootstrapper.exe

# Copiar el bootstrapper a la carpeta final para incluirlo en el release
if [ -f "DiskProtectorApp-final" ]; then
    echo "📂 Copiando bootstrapper a la carpeta final..."
    cp installer/DiskProtectorApp-v$CURRENT_VERSION-bootstrapper.exe DiskProtectorApp-final/
    echo "✅ Bootstrapper copiado a DiskProtectorApp-final/"
fi


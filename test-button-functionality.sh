#!/bin/bash

echo "=== Creando versión de prueba para verificar botones ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    exit 1
fi

# Obtener la versión actual
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)

# Compilar y publicar versión de prueba
echo "🔨 Compilando versión de prueba..."
dotnet build src/DiskProtectorApp/DiskProtectorApp.csproj --configuration Release

echo "🚀 Publicando versión de prueba..."
rm -rf ./publish-button-test
dotnet publish src/DiskProtectorApp/DiskProtectorApp.csproj \
    -c Release \
    -r win-x64 \
    --self-contained false \
    -o ./publish-button-test

echo "✅ Versión de prueba creada en publish-button-test/"
echo ""
echo "📋 Instrucciones para probar:"
echo "1. Copia la carpeta 'publish-button-test' a un entorno Windows"
echo "2. Ejecuta 'DiskProtectorApp.exe' como Administrador"
echo "3. Verifica que los botones se activen al seleccionar discos"
echo "4. Prueba las funciones de Proteger/Desproteger"
echo ""
echo "💡 Si los botones aún no funcionan, revisa el log de la aplicación:"
echo "   El log se encuentra en: %APPDATA%\\DiskProtectorApp\\app-debug.log"

#!/bin/bash

echo "=== Empaquetando aplicación ==="

# Verificar que existe la compilación
if [ ! -d "./publish-test" ]; then
    echo "❌ Error: No se encontró la carpeta de publicación"
    exit 1
fi

# Obtener versión
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
echo "📦 Versión: v$CURRENT_VERSION"

# Crear estructura final (todos los archivos en el mismo directorio para .NET)
mkdir -p ./DiskProtectorApp-final

# Copiar todos los archivos (estructura plana requerida por .NET)
cp -r ./publish-test/* ./DiskProtectorApp-final/

# Eliminar recursos alemanes si existen
if [ -d "./DiskProtectorApp-final/de" ]; then
    rm -rf ./DiskProtectorApp-final/de
fi

# Crear README
cat > ./DiskProtectorApp-final/README.txt << 'READMEEOF'
DiskProtectorApp v1.2.6
========================

ESTRUCTURA CORRECTA PARA .NET:
Todos los archivos (.exe, .dll, recursos) en el mismo directorio

REQUISITOS:
- Windows 10/11 x64
- .NET 8.0 Desktop Runtime x64
- Ejecutar como Administrador

INSTRUCCIONES:
1. Ejecutar DiskProtectorApp.exe como Administrador
2. Seleccionar discos a proteger/desproteger
3. Usar botones correspondientes
READMEEOF

# Actualizar versión en README
sed -i "s/DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/DiskProtectorApp v$CURRENT_VERSION/g" ./DiskProtectorApp-final/README.txt

# Crear archivo comprimido
tar -czf DiskProtectorApp-v$CURRENT_VERSION.tar.gz -C ./DiskProtectorApp-final .

echo "✅ Empaquetado completado"
echo "   Archivo: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"

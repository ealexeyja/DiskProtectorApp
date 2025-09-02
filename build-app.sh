#!/bin/bash

echo "=== Construyendo aplicación ==="

# Verificar estructura del proyecto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto"
    exit 1
fi

# Obtener versión
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
echo "📦 Versión: v$CURRENT_VERSION"

# Limpiar compilaciones anteriores
rm -rf ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-final ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz

# Restaurar y construir
dotnet restore src/DiskProtectorApp/DiskProtectorApp.csproj
dotnet build src/DiskProtectorApp/DiskProtectorApp.csproj --configuration Release --no-restore
dotnet publish src/DiskProtectorApp/DiskProtectorApp.csproj -c Release -r win-x64 --self-contained false -o ./publish-test

echo "✅ Construcción completada"

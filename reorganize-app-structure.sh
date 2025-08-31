#!/bin/bash

echo "=== Reorganizando estructura de la aplicación para .NET ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto. Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.1.0"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-organized ./DiskProtectorApp-final

# Restaurar dependencias
echo "📥 Restaurando dependencias..."
if ! dotnet restore src/DiskProtectorApp/DiskProtectorApp.csproj; then
    echo "❌ Error al restaurar dependencias"
    exit 1
fi

# Compilar el proyecto
echo "🔨 Compilando el proyecto..."
if ! dotnet build src/DiskProtectorApp/DiskProtectorApp.csproj --configuration Release --no-restore; then
    echo "❌ Error al compilar el proyecto"
    exit 1
fi

# Publicar la aplicación
echo "🚀 Publicando la aplicación para Windows x64..."
if ! dotnet publish src/DiskProtectorApp/DiskProtectorApp.csproj \
    -c Release \
    -r win-x64 \
    --self-contained false \
    -o ./publish-v$CURRENT_VERSION; then
    echo "❌ Error al publicar la aplicación"
    exit 1
fi

# Verificar que la publicación se generó correctamente
if [ ! -f "./publish-v$CURRENT_VERSION/DiskProtectorApp.exe" ]; then
    echo "❌ Error: No se encontró el ejecutable publicado"
    exit 1
fi

echo ""
echo "✅ ¡Publicación completada exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Carpeta de publicación: publish-v$CURRENT_VERSION/"
echo ""
echo "📊 Información del ejecutable:"
ls -lh ./publish-v$CURRENT_VERSION/DiskProtectorApp.exe

# Crear la estructura final correcta para .NET (todos los archivos en la misma carpeta)
echo ""
echo "📂 Creando estructura final correcta para .NET..."

# Crear carpeta final
mkdir -p ./DiskProtectorApp-final

# Copiar todos los archivos a la carpeta final (estructura plana requerida por .NET)
cp -r ./publish-v$CURRENT_VERSION/* ./DiskProtectorApp-final/

# Eliminar recursos alemanes si existen
if [ -d "./DiskProtectorApp-final/de" ]; then
    rm -rf ./DiskProtectorApp-final/de
    echo "🗑️ Recursos en alemán eliminados"
fi

# Crear archivo readme con instrucciones
cat > ./DiskProtectorApp-final/README.txt << 'READMEEOF'
DiskProtectorApp v1.1.0
========================

Estructura de archivos (todos en el mismo directorio):
├── DiskProtectorApp.exe     # Ejecutable principal
├── *.dll                    # Librerías y dependencias
├── en/                      # Recursos localizados (inglés)
│   └── [archivos de recursos]
├── es/                      # Recursos localizados (español)
│   └── [archivos de recursos]
├── *.json                   # Archivos de configuración
└── *.config                 # Archivos de configuración

Requisitos del sistema:
- Windows 10/11 x64
- .NET 8.0 Desktop Runtime
- Ejecutar como Administrador

Instrucciones:
1. Ejecutar DiskProtectorApp.exe como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Usar los botones de Proteger/Desproteger
READMEEOF

# Actualizar la versión en el README
sed -i "s/DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/DiskProtectorApp v$CURRENT_VERSION/g" ./DiskProtectorApp-final/README.txt

echo ""
echo "✅ Estructura final creada en ./DiskProtectorApp-final/"
echo "📁 Contenido de la carpeta:"
ls -la ./DiskProtectorApp-final/ | head -20

echo ""
echo "💡 Nota importante:"
echo "   Esta estructura plana es la correcta para aplicaciones .NET"
echo "   Las DLLs deben estar en el mismo directorio que el ejecutable"

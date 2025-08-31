#!/bin/bash

echo "=== DiskProtectorApp Final Publish Script ==="

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

echo "📦 Versión a publicar: v$CURRENT_VERSION"

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-v$CURRENT_VERSION ./DiskProtectorApp-final

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

# Organizar la estructura final
echo ""
echo "📂 Organizando estructura final..."

# Crear estructura organizada
mkdir -p ./DiskProtectorApp-final/{libs,locales,config}

# Copiar el ejecutable principal
cp ./publish-v$CURRENT_VERSION/DiskProtectorApp.exe ./DiskProtectorApp-final/

# Mover DLLs a la carpeta libs
mv ./publish-v$CURRENT_VERSION/*.dll ./DiskProtectorApp-final/libs/ 2>/dev/null || echo "No se encontraron DLLs adicionales"

# Mover recursos localizados a la carpeta locales (solo inglés y español)
if [ -d "./publish-v$CURRENT_VERSION/en" ]; then
    mv ./publish-v$CURRENT_VERSION/en ./DiskProtectorApp-final/locales/
    echo "✅ Recursos en inglés movidos"
fi

if [ -d "./publish-v$CURRENT_VERSION/es" ]; then
    mv ./publish-v$CURRENT_VERSION/es ./DiskProtectorApp-final/locales/
    echo "✅ Recursos en español movidos"
fi

# Eliminar carpeta de alemán si existe
if [ -d "./publish-v$CURRENT_VERSION/de" ]; then
    rm -rf ./publish-v$CURRENT_VERSION/de
    echo "🗑️ Recursos en alemán eliminados"
fi

# Copiar archivos de configuración
cp ./publish-v$CURRENT_VERSION/*.json ./DiskProtectorApp-final/config/ 2>/dev/null || echo "No se encontraron archivos JSON"
cp ./publish-v$CURRENT_VERSION/*.config ./DiskProtectorApp-final/config/ 2>/dev/null || echo "No se encontraron archivos de configuración"

# Crear archivo readme con instrucciones
cat > ./DiskProtectorApp-final/README.txt << 'READMEEOF'
DiskProtectorApp v1.1.0
========================

Estructura de archivos:
├── DiskProtectorApp.exe     # Ejecutable principal
├── libs/                    # Librerías y dependencias
├── locales/                 # Recursos localizados
│   ├── en/                  # Inglés
│   └── es/                  # Español
└── config/                  # Archivos de configuración

Requisitos del sistema:
- Windows 10/11 x64
- .NET 8.0 Desktop Runtime
- Ejecutar como Administrador

Instrucciones:
1. Ejecutar DiskProtectorApp.exe como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Usar los botones de Proteger/Desproteger
READMEEOF

echo ""
echo "✅ Estructura final organizada en ./DiskProtectorApp-final/"
echo "📁 Estructura final:"
find ./DiskProtectorApp-final/ -type d | sort

# Crear archivo comprimido final
echo ""
echo "📦 Creando archivo comprimido final..."
tar -czf DiskProtectorApp-v$CURRENT_VERSION.tar.gz -C ./DiskProtectorApp-final .

echo ""
echo "✅ ¡Versión v$CURRENT_VERSION creada exitosamente!"
echo "   Archivos generados:"
echo "   - Carpeta organizada: DiskProtectorApp-final/"
echo "   - Archivo comprimido: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
echo ""
echo "📊 Tamaño del archivo comprimido:"
ls -lh DiskProtectorApp-v$CURRENT_VERSION.tar.gz

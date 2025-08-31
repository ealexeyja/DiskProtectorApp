#!/bin/bash

echo "=== DiskProtectorApp Build Release v1.1.0 ==="
echo "Iniciando proceso de compilación y empaquetado para la versión 1.1.0"

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto. Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Establecer la versión a 1.1.0
NEW_VERSION="1.1.0"

echo "📦 Configurando versión: v$NEW_VERSION"

# Actualizar el archivo .csproj a la versión 1.1.0
sed -i "s/<Version>[0-9]*\.[0-9]*\.[0-9]*<\/Version>/<Version>$NEW_VERSION<\/Version>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
sed -i "s/<AssemblyVersion>[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*<\/AssemblyVersion>/<AssemblyVersion>$NEW_VERSION.0<\/AssemblyVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
sed -i "s/<FileVersion>[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*<\/FileVersion>/<FileVersion>$NEW_VERSION.0<\/FileVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
sed -i "s/<InformationalVersion>[0-9]*\.[0-9]*\.[0-9]*<\/InformationalVersion>/<InformationalVersion>$NEW_VERSION<\/InformationalVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj

# Actualizar el título en MainWindow.xaml
sed -i "s/Title=\"DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*\"/Title=\"DiskProtectorApp v$NEW_VERSION\"/g" src/DiskProtectorApp/Views/MainWindow.xaml

echo "✅ Versión actualizada a v$NEW_VERSION"

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-v$NEW_VERSION ./DiskProtectorApp-final

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
    -o ./publish-v$NEW_VERSION; then
    echo "❌ Error al publicar la aplicación"
    exit 1
fi

# Verificar que la publicación se generó correctamente
if [ ! -f "./publish-v$NEW_VERSION/DiskProtectorApp.exe" ]; then
    echo "❌ Error: No se encontró el ejecutable publicado"
    exit 1
fi

echo ""
echo "✅ ¡Publicación completada exitosamente!"
echo "   Versión: v$NEW_VERSION"
echo "   Carpeta de publicación: publish-v$NEW_VERSION/"
echo ""
echo "📊 Información del ejecutable:"
ls -lh ./publish-v$NEW_VERSION/DiskProtectorApp.exe

# Organizar la estructura final
echo ""
echo "📂 Organizando estructura final..."

# Crear estructura organizada
mkdir -p ./DiskProtectorApp-final/{libs,locales,config}

# Copiar el ejecutable principal
cp ./publish-v$NEW_VERSION/DiskProtectorApp.exe ./DiskProtectorApp-final/

# Mover DLLs a la carpeta libs
mv ./publish-v$NEW_VERSION/*.dll ./DiskProtectorApp-final/libs/ 2>/dev/null || echo "No se encontraron DLLs adicionales"

# Mover recursos localizados a la carpeta locales (solo inglés y español)
if [ -d "./publish-v$NEW_VERSION/en" ]; then
    mv ./publish-v$NEW_VERSION/en ./DiskProtectorApp-final/locales/
    echo "✅ Recursos en inglés movidos"
fi

if [ -d "./publish-v$NEW_VERSION/es" ]; then
    mv ./publish-v$NEW_VERSION/es ./DiskProtectorApp-final/locales/
    echo "✅ Recursos en español movidos"
fi

# Eliminar carpeta de alemán si existe
if [ -d "./publish-v$NEW_VERSION/de" ]; then
    rm -rf ./publish-v$NEW_VERSION/de
    echo "🗑️ Recursos en alemán eliminados"
fi

# Copiar archivos de configuración
cp ./publish-v$NEW_VERSION/*.json ./DiskProtectorApp-final/config/ 2>/dev/null || echo "No se encontraron archivos JSON"
cp ./publish-v$NEW_VERSION/*.config ./DiskProtectorApp-final/config/ 2>/dev/null || echo "No se encontraron archivos de configuración"

echo ""
echo "✅ Estructura final organizada en ./DiskProtectorApp-final/"
echo "📁 Estructura final:"
find ./DiskProtectorApp-final/ -type d | sort

# Crear archivo comprimido final
echo ""
echo "📦 Creando archivo comprimido final..."
tar -czf DiskProtectorApp-v$NEW_VERSION.tar.gz -C ./DiskProtectorApp-final .

echo ""
echo "✅ ¡Versión v$NEW_VERSION creada exitosamente!"
echo "   Archivos generados:"
echo "   - Carpeta organizada: DiskProtectorApp-final/"
echo "   - Archivo comprimido: DiskProtectorApp-v$NEW_VERSION.tar.gz"
echo ""
echo "📊 Tamaño del archivo comprimido:"
ls -lh DiskProtectorApp-v$NEW_VERSION.tar.gz

echo ""
echo "📋 Para publicar en GitHub:"
echo "1. git add ."
echo "2. git commit -m \"release: v$NEW_VERSION - Versión estable con mejoras\""
echo "3. git push origin main"
echo "4. git tag -a v$NEW_VERSION -m \"Release v$NEW_VERSION\""
echo "5. git push origin v$NEW_VERSION"
echo ""
echo "🎉 ¡Proceso completado!"

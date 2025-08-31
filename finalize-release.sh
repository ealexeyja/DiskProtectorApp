#!/bin/bash

echo "=== Finalizando release de DiskProtectorApp ==="

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

# Verificar que existe la carpeta de publicación de prueba
if [ ! -d "./publish-test" ]; then
    echo "❌ Error: No se encontró la carpeta de publicación de prueba."
    echo "   Ejecuta primero './prepare-new-release.sh'"
    exit 1
fi

# Renombrar la carpeta de prueba a la versión final
mv ./publish-test ./publish-v$CURRENT_VERSION
echo "✅ Carpeta renombrada a publish-v$CURRENT_VERSION"

# Organizar la estructura final
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

# Actualizar la versión en el README
sed -i "s/DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/DiskProtectorApp v$CURRENT_VERSION/g" ./DiskProtectorApp-final/README.txt

echo ""
echo "✅ Estructura final organizada en ./DiskProtectorApp-final/"

# Crear archivo comprimido final
echo "📦 Creando archivo comprimido final..."
tar -czf DiskProtectorApp-v$CURRENT_VERSION.tar.gz -C ./DiskProtectorApp-final .

echo ""
echo "✅ ¡Versión v$CURRENT_VERSION finalizada exitosamente!"
echo "   Archivos generados:"
echo "   - Carpeta organizada: DiskProtectorApp-final/"
echo "   - Carpeta de publicación: publish-v$CURRENT_VERSION/"
echo "   - Archivo comprimido: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
echo ""
echo "📊 Tamaño del archivo comprimido:"
ls -lh DiskProtectorApp-v$CURRENT_VERSION.tar.gz
echo ""
echo "📋 Para publicar en GitHub:"
echo "1. git add ."
echo "2. git commit -m \"release: v$CURRENT_VERSION - Nueva versión\""
echo "3. git push origin main"
echo "4. git tag -a v$CURRENT_VERSION -m \"Release v$CURRENT_VERSION\""
echo "5. git push origin v$CURRENT_VERSION"
echo ""
echo "💡 El workflow de GitHub Actions se ejecutará automáticamente"
echo "   al crear el tag v$CURRENT_VERSION"

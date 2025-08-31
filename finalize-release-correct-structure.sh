#!/bin/bash

echo "=== Finalizando release con estructura correcta ==="

# Verificar que existe la carpeta de publicación
if [ ! -d "./publish-test" ]; then
    echo "❌ Error: No se encontró la carpeta de prueba."
    echo "   Ejecuta primero el proceso de compilación"
    exit 1
fi

# Obtener la versión actual
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
echo "📦 Versión actual: v$CURRENT_VERSION"

# Renombrar la carpeta de prueba a la versión final
mv ./publish-test ./publish-v$CURRENT_VERSION
echo "✅ Carpeta renombrada a publish-v$CURRENT_VERSION"

# Crear la estructura final correcta (todos los archivos en el mismo directorio)
echo "📂 Creando estructura final correcta para .NET..."
mkdir -p ./DiskProtectorApp-final

# Copiar todos los archivos a la carpeta final (estructura plana requerida por .NET)
cp -r ./publish-v$CURRENT_VERSION/* ./DiskProtectorApp-final/

# Eliminar recursos alemanes si existen
if [ -d "./DiskProtectorApp-final/de" ]; then
    rm -rf ./DiskProtectorApp-final/de
    echo "🗑️ Recursos en alemán eliminados"
fi

# Verificar que NO existan las carpetas problemáticas
if [ -d "./DiskProtectorApp-final/libs" ] || [ -d "./DiskProtectorApp-final/config" ] || [ -d "./DiskProtectorApp-final/locales" ]; then
    echo "❌ Estructura incorrecta detectada. Eliminando carpetas innecesarias..."
    rm -rf ./DiskProtectorApp-final/libs ./DiskProtectorApp-final/config ./DiskProtectorApp-final/locales 2>/dev/null || true
    echo "✅ Carpetas innecesarias eliminadas"
fi

# Crear archivo readme con instrucciones
cat > ./DiskProtectorApp-final/README.txt << 'READMEEOF'
DiskProtectorApp v1.2.0
========================

Estructura de archivos correcta para .NET (todos en el mismo directorio):
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

# Verificar la estructura
echo "🔍 Verificando estructura final..."
if ./verify-release-structure.sh; then
    echo "✅ Estructura verificada correctamente"
else
    echo "❌ Error en la verificación de estructura"
    exit 1
fi

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

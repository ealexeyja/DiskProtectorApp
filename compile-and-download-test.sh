#!/bin/bash

echo "=== Compilando y preparando versión de prueba ==="

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
rm -rf ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-test

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

# Publicar la aplicación para prueba
echo "🚀 Publicando la aplicación para prueba..."
if ! dotnet publish src/DiskProtectorApp/DiskProtectorApp.csproj \
    -c Release \
    -r win-x64 \
    --self-contained false \
    -o ./publish-test; then
    echo "❌ Error al publicar la aplicación"
    exit 1
fi

# Verificar que la publicación se generó correctamente
if [ ! -f "./publish-test/DiskProtectorApp.exe" ]; then
    echo "❌ Error: No se encontró el ejecutable publicado"
    exit 1
fi

echo ""
echo "✅ ¡Publicación para prueba completada exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Carpeta de publicación: publish-test/"
echo ""
echo "📊 Información del ejecutable:"
ls -lh ./publish-test/DiskProtectorApp.exe

# Crear la estructura de prueba CORRECTA (todos los archivos en el mismo directorio para .NET)
echo "📂 Creando estructura de prueba CORRECTA para .NET..."
mkdir -p ./DiskProtectorApp-test

# Copiar todos los archivos a la carpeta de prueba (estructura plana requerida por .NET)
cp -r ./publish-test/* ./DiskProtectorApp-test/

# Eliminar recursos alemanes si existen
if [ -d "./DiskProtectorApp-test/de" ]; then
    rm -rf ./DiskProtectorApp-test/de
    echo "🗑️ Recursos en alemán eliminados"
fi

# Crear archivo readme con instrucciones de prueba
cat > ./DiskProtectorApp-test/README-TEST.txt << 'READMEEOF'
DiskProtectorApp v$CURRENT_VERSION - Versión de Prueba
=====================================================

ESTRUCTURA DE ARCHIVOS CORRECTA PARA .NET:
Todos los archivos (.exe, .dll, recursos) en el mismo directorio

├── DiskProtectorApp.exe     # Ejecutable principal
├── *.dll                    # Librerías y dependencias
├── en/                      # Recursos localizados (inglés)
│   └── [archivos de recursos]
├── es/                      # Recursos localizados (español)
│   └── [archivos de recursos]
├── *.json                   # Archivos de configuración
└── *.config                 # Archivos de configuración

REQUISITOS DEL SISTEMA:
- Windows 10/11 x64
- Microsoft .NET 8.0 Desktop Runtime x64
- Ejecutar como Administrador

INSTRUCCIONES DE PRUEBA:
1. Ejecutar DiskProtectorApp.exe como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Click en el botón correspondiente
4. Esperar confirmación de la operación
5. Verificar que los botones se activen/desactiven correctamente
6. Verificar que el estado de los discos se actualice después de cada operación

REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\app-debug.log
• %APPDATA%\DiskProtectorApp\operations.log
• Se conservan los últimos 30 días de registros

FUNCIONAMIENTO ESPERADO:
• Botones de Proteger/Desproteger se activan/desactivan según selección
• Estado de los discos se actualiza automáticamente después de operaciones
• Administradores mantienen control total en todo momento
• Usuarios estándar pierden/ganan permisos según operación

 Versión de prueba: v$CURRENT_VERSION
READMEEOF

# Actualizar la versión en el README de prueba
sed -i "s/DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/DiskProtectorApp v$CURRENT_VERSION/g" ./DiskProtectorApp-test/README-TEST.txt
sed -i "s/Versión de prueba: v[0-9]*\.[0-9]*\.[0-9]*/Versión de prueba: v$CURRENT_VERSION/g" ./DiskProtectorApp-test/README-TEST.txt

# Crear archivo comprimido de prueba
echo "📦 Creando archivo comprimido de prueba..."
tar -czf DiskProtectorApp-test-v$CURRENT_VERSION.tar.gz -C ./DiskProtectorApp-test .

echo ""
echo "✅ ¡Versión de prueba v$CURRENT_VERSION creada exitosamente!"
echo "   Archivos generados:"
echo "   - Carpeta de prueba: DiskProtectorApp-test/"
echo "   - Carpeta de publicación: publish-test/"
echo "   - Archivo comprimido: DiskProtectorApp-test-v$CURRENT_VERSION.tar.gz"
echo ""
echo "📊 Tamaño del archivo comprimido:"
ls -lh DiskProtectorApp-test-v$CURRENT_VERSION.tar.gz

echo ""
echo "📥 Para descargar el archivo de prueba:"
echo "   En Codespaces: Haz clic derecho en 'DiskProtectorApp-test-v$CURRENT_VERSION.tar.gz' y selecciona 'Download'"
echo "   En terminal: scp usuario@servidor:/ruta/DiskProtectorApp-test-v$CURRENT_VERSION.tar.gz ."
echo ""
echo "🧪 Instrucciones de prueba:"
echo "   1. Extraer el archivo en un entorno Windows"
echo "   2. Ejecutar 'DiskProtectorApp.exe' como Administrador"
echo "   3. Verificar funcionamiento de botones y actualización de estado"
echo "   4. Revisar logs en %APPDATA%\\DiskProtectorApp\\"
echo "   5. Reportar cualquier problema encontrado"

#!/bin/bash

echo "=== Continuando con el flujo de desarrollo ==="

# 1. Verificar que los cambios se aplicaron correctamente
echo "🔍 Verificando cambios aplicados..."
if [ -f "src/DiskProtectorApp/Services/DiskService.cs" ]; then
    echo "✅ Servicio de discos actualizado"
    ls -la src/DiskProtectorApp/Services/DiskService.cs
else
    echo "❌ Servicio de discos NO encontrado"
    exit 1
fi

# 2. Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-test ./publish-v* ./DiskProtectorApp-final ./DiskProtectorApp-organized

# 3. Restaurar dependencias
echo "📥 Restaurando dependencias..."
if ! dotnet restore src/DiskProtectorApp/DiskProtectorApp.csproj; then
    echo "❌ Error al restaurar dependencias"
    exit 1
fi

# 4. Compilar el proyecto
echo "🔨 Compilando el proyecto..."
if ! dotnet build src/DiskProtectorApp/DiskProtectorApp.csproj --configuration Release --no-restore; then
    echo "❌ Error al compilar el proyecto"
    exit 1
fi

# 5. Publicar para prueba
echo "🚀 Publicando para prueba..."
if ! dotnet publish src/DiskProtectorApp/DiskProtectorApp.csproj \
    -c Release \
    -r win-x64 \
    --self-contained false \
    -o ./publish-test; then
    echo "❌ Error al publicar para prueba"
    exit 1
fi

# 6. Verificar que la publicación se generó correctamente
if [ ! -f "./publish-test/DiskProtectorApp.exe" ]; then
    echo "❌ Error: No se encontró el ejecutable publicado"
    exit 1
fi

echo ""
echo "✅ ¡Compilación y publicación para prueba completadas!"
echo "   Carpeta de prueba: publish-test/"
echo "   Ejecutable: publish-test/DiskProtectorApp.exe"
echo ""
echo "📊 Información del ejecutable:"
ls -lh ./publish-test/DiskProtectorApp.exe

# 7. Crear estructura final correcta (todos los archivos en el mismo directorio para .NET)
echo "📂 Creando estructura final correcta para .NET..."
mkdir -p ./DiskProtectorApp-final

# Copiar todos los archivos a la carpeta final (estructura plana requerida por .NET)
cp -r ./publish-test/* ./DiskProtectorApp-final/

# Eliminar recursos alemanes si existen
if [ -d "./DiskProtectorApp-final/de" ]; then
    rm -rf ./DiskProtectorApp-final/de
    echo "🗑️ Recursos en alemán eliminados"
fi

# Crear archivo readme con instrucciones
cat > ./DiskProtectorApp-final/README.txt << 'READMEEOF'
DiskProtectorApp v1.1.0
========================

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

INSTRUCCIONES DE USO:
1. Ejecutar DiskProtectorApp.exe como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Click en el botón correspondiente
4. Esperar confirmación de la operación

FUNCIONAMIENTO DE PERMISOS:
• Desprotegido: Usuarios con permisos básicos, AuthUsers con permisos de modificación
• Protegido: Usuarios sin permisos, AuthUsers solo con permisos básicos
• Administradores y SYSTEM siempre mantienen Control Total

REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\operations.log
• Se conservan los últimos 30 días de registros
READMEEOF

# Actualizar la versión en el README
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.1.0"
fi
sed -i "s/DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/DiskProtectorApp v$CURRENT_VERSION/g" ./DiskProtectorApp-final/README.txt

echo ""
echo "✅ Estructura final creada en ./DiskProtectorApp-final/"
echo "   Contenido:"
ls -la ./DiskProtectorApp-final/

# 8. Crear archivo comprimido para distribución
echo "📦 Creando archivo comprimido para distribución..."
tar -czf DiskProtectorApp-v$CURRENT_VERSION-test.tar.gz -C ./DiskProtectorApp-final .

echo ""
echo "✅ ¡Archivo comprimido creado!"
echo "   Archivo: DiskProtectorApp-v$CURRENT_VERSION-test.tar.gz"
echo "   Tamaño:"
ls -lh DiskProtectorApp-v$CURRENT_VERSION-test.tar.gz

echo ""
echo "📋 Para probar la aplicación:"
echo "1. Descargar DiskProtectorApp-v$CURRENT_VERSION-test.tar.gz"
echo "2. Extraer en un entorno Windows"
echo "3. Ejecutar DiskProtectorApp.exe como Administrador"
echo "4. Verificar funcionamiento de protección/desprotección"
echo "5. Revisar logs en %APPDATA%\\DiskProtectorApp\\"

echo ""
echo "🔧 Para crear una versión oficial:"
echo "1. ./finalize-release.sh"
echo "2. ./publish-release.sh"
echo "3. git tag -a v$CURRENT_VERSION -m \"Release v$CURRENT_VERSION\""
echo "4. git push origin v$CURRENT_VERSION"

echo ""
echo "📝 Notas importantes:"
echo "• La aplicación DEBE ejecutarse como Administrador"
echo "• Todos los archivos deben estar en el mismo directorio"
echo "• Los permisos se manejan quitando/restaurando (no Deny)"
echo "• Administradores mantienen control total siempre"
echo "• SYSTEM mantiene control total siempre"

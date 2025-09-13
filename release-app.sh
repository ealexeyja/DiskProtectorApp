#!/bin/bash

# release-app.sh - Proceso completo de release de DiskProtectorApp

set -e # Salir inmediatamente si un comando falla

echo "=== Proceso completo de release de DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" src/DiskProtectorApp/DiskProtectorApp.csproj)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="0.0.0"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Preguntar si desea incrementar la versión
echo ""
echo "🔢 ¿Deseas incrementar la versión automáticamente? (s/n)"
read -r incrementar
if [[ "$incrementar" =~ ^[Ss]$ ]]; then
    # Usar el script de actualización de versión
    if [ -f "./update-version.sh" ]; then
        echo "📈 Incrementando versión automáticamente..."
        ./update-version.sh -i
        
        # Volver a obtener la nueva versión
        CURRENT_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" src/DiskProtectorApp/DiskProtectorApp.csproj)
        echo "📦 Nueva versión: v$CURRENT_VERSION"
    else
        echo "❌ No se encontró el script update-version.sh"
        exit 1
    fi
fi

# Limpiar compilaciones anteriores
echo ""
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-final ./DiskProtectorApp-v$CURRENT_VERSION*.tar.gz ./DiskProtectorApp-v$CURRENT_VERSION*.zip

# Restaurar dependencias
echo ""
echo "📥 Restaurando dependencias..."
if ! dotnet restore src/DiskProtectorApp/DiskProtectorApp.csproj; then
    echo "❌ Error al restaurar dependencias"
    exit 1
fi

# Compilar el proyecto
echo ""
echo "🔨 Compilando el proyecto..."
if ! dotnet build src/DiskProtectorApp/DiskProtectorApp.csproj --configuration Release --no-restore; then
    echo "❌ Error al compilar el proyecto"
    exit 1
fi

# Publicar la aplicación
echo ""
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

# Crear la estructura FINAL CORRECTA (todos los archivos en el mismo directorio para .NET)
echo ""
echo "📂 Creando estructura FINAL CORRECTA para .NET..."
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
DiskProtectorApp v1.2.7
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

INSTRUCCIONES:
1. Ejecutar DiskProtectorApp.exe como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Click en el botón correspondiente
4. Esperar confirmación de la operación

FUNCIONAMIENTO DE PERMISOS:
• DISCO DESPROTEGIDO (NORMAL):
  - Grupo "Usuarios" tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
  - Grupo "Usuarios autenticados" tiene permisos de modificación/escritura (M, W, F)
  - Grupo "Administradores" y "SYSTEM" tienen Control Total (siempre)

• DISCO PROTEGIDO:
  - Grupo "Usuarios" NO tiene permisos establecidos
  - Grupo "Usuarios autenticados" solo tiene permisos básicos de lectura/ejecución (RX)
  - Grupo "Administradores" y "SYSTEM" mantienen Control Total (siempre)

REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\Logs\operation.log
• Se conservan los últimos registros por 30 días

LOGS DE DIAGNÓSTICO:
• Logs detallados en:
• %APPDATA%\DiskProtectorApp\Logs\
• Categorías: UI, ViewModel, Service, Operation, Permission
• Niveles: DEBUG, INFO, WARN, ERROR, FATAL

 Versión actual: v1.2.7
READMEEOF

# Actualizar la versión en el README
sed -i "s/DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/DiskProtectorApp v$CURRENT_VERSION/g" ./DiskProtectorApp-final/README.txt

# Crear archivo comprimido final TAR.GZ
echo ""
echo "📦 Creando archivo comprimido TAR.GZ final..."
tar -czf DiskProtectorApp-v$CURRENT_VERSION-portable.tar.gz -C ./DiskProtectorApp-final .

# Crear archivo comprimido ZIP adicional
ZIP_NAME="DiskProtectorApp-v$CURRENT_VERSION-portable.zip"
echo "📦 Creando archivo comprimido ZIP adicional..."
if command -v zip >/dev/null 2>&1; then
    (cd ./DiskProtectorApp-final && zip -r "../$ZIP_NAME" .)
    echo "✅ ¡Archivo ZIP creado exitosamente!"
else
    echo "⚠️  No se encontró el comando 'zip'. Para crear el archivo ZIP, instala 'zip'."
    echo "   El proceso continuará sin el archivo ZIP."
fi

echo ""
echo "✅ ¡Release completado exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Archivos generados:"
echo "   - Carpeta organizada: DiskProtectorApp-final/"
echo "   - Carpeta de publicación: publish-v$CURRENT_VERSION/"
echo "   - Archivo comprimido TAR.GZ: DiskProtectorApp-v$CURRENT_VERSION-portable.tar.gz"
if [ -f "$ZIP_NAME" ]; then
    echo "   - Archivo comprimido ZIP: $ZIP_NAME"
fi
echo ""
echo "📊 Tamaño de los archivos generados:"
ls -lh DiskProtectorApp-v$CURRENT_VERSION-portable.tar.gz
if [ -f "$ZIP_NAME" ]; then
    ls -lh "$ZIP_NAME"
fi

# Preguntar si desea publicar en GitHub
echo ""
echo "☁️  ¿Deseas publicar en GitHub? (s/n)"
read -r publicar_github
if [[ "$publicar_github" =~ ^[Ss]$ ]]; then
    echo "📥 Agregando todos los cambios..."
    git add .
    
    echo "📝 Creando commit..."
    git commit -m "release: v$CURRENT_VERSION - Nueva versión"
    
    echo "🚀 Subiendo cambios a GitHub..."
    if ! git push origin main; then
        echo "❌ Error al subir cambios a GitHub"
        exit 1
    fi
    
    echo "🏷️  Creando tag v$CURRENT_VERSION..."
    git tag -a "v$CURRENT_VERSION" -m "Release v$CURRENT_VERSION"
    
    echo "📤 Subiendo tag a GitHub..."
    if ! git push origin "v$CURRENT_VERSION"; then
        echo "❌ Error al subir el tag a GitHub"
        exit 1
    fi
    
    echo ""
    echo "✅ ¡Publicación en GitHub completada exitosamente!"
    echo "   Versión: v$CURRENT_VERSION"
    echo "   Tag: v$CURRENT_VERSION"
    echo ""
    echo "📊 El workflow de GitHub Actions se ejecutará automáticamente"
    echo "   al crear el tag v$CURRENT_VERSION"
    echo ""
    echo "💡 Para monitorear el progreso:"
    echo "   1. Ve a https://github.com/tu-usuario/DiskProtectorApp/actions  "
    echo "   2. Busca el workflow CI/CD Pipeline"
    echo "   3. Verifica que se esté ejecutando"
fi

echo ""
echo "🎉 ¡Proceso de release completado exitosamente!"
echo "   Versión final: v$CURRENT_VERSION"


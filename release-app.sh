#!/bin/bash

echo "=== Proceso completo de release de DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.2.6"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Preguntar si desea incrementar la versión
echo ""
echo "🔢 ¿Deseas incrementar la versión? (s/n)"
read -r incrementar
if [[ "$incrementar" =~ ^[Ss]$ ]]; then
    # Parsear la versión
    VERSION_PARTS=(${CURRENT_VERSION//./ })
    MAJOR=${VERSION_PARTS[0]}
    MINOR=${VERSION_PARTS[1]}
    PATCH=${VERSION_PARTS[2]}
    
    # Incrementar el número de parche
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
    
    echo "📈 Nueva versión: v$NEW_VERSION"
    
    # Actualizar el archivo .csproj
    sed -i "s/<Version>$CURRENT_VERSION<\/Version>/<Version>$NEW_VERSION<\/Version>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
    sed -i "s/<AssemblyVersion>$CURRENT_VERSION.0<\/AssemblyVersion>/<AssemblyVersion>$NEW_VERSION.0<\/AssemblyVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
    sed -i "s/<FileVersion>$CURRENT_VERSION.0<\/FileVersion>/<FileVersion>$NEW_VERSION.0<\/FileVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
    sed -i "s/<InformationalVersion>$CURRENT_VERSION<\/InformationalVersion>/<InformationalVersion>$NEW_VERSION<\/InformationalVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
    
    # Actualizar el título en MainWindow.xaml
    sed -i "s/Title=\"DiskProtectorApp v$CURRENT_VERSION\"/Title=\"DiskProtectorApp v$NEW_VERSION\"/g" src/DiskProtectorApp/Views/MainWindow.xaml
    
    CURRENT_VERSION=$NEW_VERSION
    echo "✅ Versión actualizada a v$CURRENT_VERSION"
fi

# Limpiar compilaciones anteriores
echo ""
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-final ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz

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
DiskProtectorApp v1.2.6
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
  - Grupo "Usuarios autenticados" tiene permisos de modificación/escritura
  - Grupo "Administradores" y "SYSTEM" tienen Control Total (siempre)

• DISCO PROTEGIDO:
  - Grupo "Usuarios" NO tiene permisos establecidos
  - Grupo "Usuarios autenticados" solo tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
  - Grupo "Administradores" y "SYSTEM" mantienen Control Total (siempre)

REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\operations.log
• Se conservan los últimos 30 días de registros

LOGS DE DIAGNÓSTICO:
• Logs detallados en:
• %APPDATA%\DiskProtectorApp\app-debug.log
• Niveles: INFO, DEBUG, WARN, ERROR, VERBOSE

 Versión actual: v1.2.6
READMEEOF

# Actualizar la versión en el README
sed -i "s/DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/DiskProtectorApp v$CURRENT_VERSION/g" ./DiskProtectorApp-final/README.txt

# Crear archivo comprimido final
echo ""
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
    echo "   1. Ve a https://github.com/tu-usuario/DiskProtectorApp/actions"
    echo "   2. Busca el workflow CI/CD Pipeline"
    echo "   3. Verifica que se esté ejecutando"
fi

echo ""
echo "🎉 ¡Proceso de release completado exitosamente!"
echo "   Versión final: v$CURRENT_VERSION"

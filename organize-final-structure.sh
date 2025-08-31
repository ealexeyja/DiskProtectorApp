#!/bin/bash

echo "=== Organizando estructura final de la aplicación ==="

# Verificar que existe la carpeta de publicación
if [ ! -d "./publish-v1.1.0" ]; then
    echo "❌ Error: No se encontró la carpeta de publicación. Ejecuta primero la compilación."
    exit 1
fi

# Crear estructura organizada
mkdir -p ./DiskProtectorApp-organized/{libs,locales,config}

echo "📁 Estructura creada:"
echo "   DiskProtectorApp-organized/"
echo "   ├── DiskProtectorApp.exe (ejecutable principal)"
echo "   ├── libs/               (librerías y dependencias)"
echo "   ├── locales/            (recursos localizados)"
echo "   │   ├── en/             (inglés)"
echo "   │   └── es/             (español)"
echo "   └── config/             (archivos de configuración)"
echo ""

# Copiar el ejecutable principal
if [ -f "./publish-v1.1.0/DiskProtectorApp.exe" ]; then
    cp ./publish-v1.1.0/DiskProtectorApp.exe ./DiskProtectorApp-organized/
    echo "✅ Ejecutable copiado"
else
    echo "⚠️  No se encontró el ejecutable principal"
fi

# Mover DLLs a la carpeta libs
if ls ./publish-v1.1.0/*.dll 1> /dev/null 2>&1; then
    mv ./publish-v1.1.0/*.dll ./DiskProtectorApp-organized/libs/ 2>/dev/null
    echo "✅ DLLs movidas a libs/"
else
    echo "⚠️  No se encontraron DLLs"
fi

# Mover recursos localizados a la carpeta locales (solo inglés y español)
echo "🌍 Procesando recursos localizados..."

# Mover carpeta de inglés si existe
if [ -d "./publish-v1.1.0/en" ]; then
    mv ./publish-v1.1.0/en ./DiskProtectorApp-organized/locales/
    echo "✅ Recursos en inglés movidos"
fi

# Mover carpeta de español si existe
if [ -d "./publish-v1.1.0/es" ]; then
    mv ./publish-v1.1.0/es ./DiskProtectorApp-organized/locales/
    echo "✅ Recursos en español movidos"
fi

# Eliminar carpeta de alemán si existe
if [ -d "./publish-v1.1.0/de" ]; then
    rm -rf ./publish-v1.1.0/de
    echo "🗑️  Recursos en alemán eliminados"
fi

# Copiar archivos de configuración
if ls ./publish-v1.1.0/*.json 1> /dev/null 2>&1; then
    mv ./publish-v1.1.0/*.json ./DiskProtectorApp-organized/config/ 2>/dev/null
    echo "✅ Archivos JSON movidos a config/"
fi

if ls ./publish-v1.1.0/*.config 1> /dev/null 2>&1; then
    mv ./publish-v1.1.0/*.config ./DiskProtectorApp-organized/config/ 2>/dev/null
    echo "✅ Archivos de configuración movidos a config/"
fi

# Crear archivo readme con instrucciones
cat > ./DiskProtectorApp-organized/README.txt << 'READMEEOF'
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
echo "✅ Estructura final organizada en ./DiskProtectorApp-organized/"
echo "📊 Contenido final:"
ls -la ./DiskProtectorApp-organized/
echo ""
echo "📁 Detalle de estructura:"
find ./DiskProtectorApp-organized/ -type d | sort

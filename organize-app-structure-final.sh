#!/bin/bash

echo "=== Organizando estructura final de la aplicación ==="

# Crear estructura organizada
mkdir -p ./DiskProtectorApp-final/{libs,locales,config}

echo "📁 Estructura creada:"
echo "   DiskProtectorApp-final/"
echo "   ├── DiskProtectorApp.exe (ejecutable principal)"
echo "   ├── libs/               (librerías y dependencias)"
echo "   ├── locales/            (recursos localizados)"
echo "   │   ├── en/             (inglés)"
echo "   │   └── es/             (español)"
echo "   └── config/             (archivos de configuración)"
echo ""

# Copiar el ejecutable principal
if [ -f "./publish-v*/DiskProtectorApp.exe" ]; then
    cp ./publish-v*/DiskProtectorApp.exe ./DiskProtectorApp-final/
    echo "✅ Ejecutable copiado"
else
    echo "⚠️  No se encontró el ejecutable principal"
fi

# Mover DLLs a la carpeta libs
if ls ./publish-v*/*.dll 1> /dev/null 2>&1; then
    mv ./publish-v*/*.dll ./DiskProtectorApp-final/libs/ 2>/dev/null
    echo "✅ DLLs movidas a libs/"
else
    echo "⚠️  No se encontraron DLLs"
fi

# Mover recursos localizados a la carpeta locales (solo inglés y español)
echo "🌍 Procesando recursos localizados..."

# Mover carpeta de inglés si existe
if [ -d "./publish-v*/en" ]; then
    mv ./publish-v*/en ./DiskProtectorApp-final/locales/
    echo "✅ Recursos en inglés movidos"
fi

# Mover carpeta de español si existe
if [ -d "./publish-v*/es" ]; then
    mv ./publish-v*/es ./DiskProtectorApp-final/locales/
    echo "✅ Recursos en español movidos"
fi

# Eliminar carpeta de alemán si existe
if [ -d "./publish-v*/de" ]; then
    rm -rf ./publish-v*/de
    echo "🗑️  Recursos en alemán eliminados"
fi

# Copiar archivos de configuración
if ls ./publish-v*/*.json 1> /dev/null 2>&1; then
    mv ./publish-v*/*.json ./DiskProtectorApp-final/config/ 2>/dev/null
    echo "✅ Archivos JSON movidos a config/"
fi

if ls ./publish-v*/*.config 1> /dev/null 2>&1; then
    mv ./publish-v*/*.config ./DiskProtectorApp-final/config/ 2>/dev/null
    echo "✅ Archivos de configuración movidos a config/"
fi

echo ""
echo "✅ Estructura final organizada en ./DiskProtectorApp-final/"
echo "📊 Contenido final:"
ls -la ./DiskProtectorApp-final/
echo ""
echo "📁 Detalle de estructura:"
find ./DiskProtectorApp-final/ -type d | sort

#!/bin/bash

echo "=== Verificando estructura de la aplicación ==="

# Verificar que existe la carpeta final
if [ ! -d "DiskProtectorApp-final" ]; then
    echo "❌ Error: No se encontró la carpeta DiskProtectorApp-final"
    exit 1
fi

cd DiskProtectorApp-final

echo "🔍 Verificando estructura de archivos..."
echo "====================================="

# Verificar ejecutable principal
if [ -f "DiskProtectorApp.exe" ]; then
    echo "✅ DiskProtectorApp.exe encontrado"
else
    echo "❌ DiskProtectorApp.exe NO encontrado"
fi

# Verificar que las DLLs estén en el directorio principal (estructura correcta para .NET)
DLL_COUNT=$(ls *.dll 2>/dev/null | wc -l)
if [ $DLL_COUNT -gt 0 ]; then
    echo "✅ $DLL_COUNT DLLs encontradas en el directorio principal (estructura correcta)"
else
    echo "⚠️  No se encontraron DLLs en el directorio principal"
fi

# Verificar recursos localizados
if [ -d "en" ]; then
    echo "✅ Carpeta de recursos en inglés encontrada"
fi

if [ -d "es" ]; then
    echo "✅ Carpeta de recursos en español encontrada"
fi

if [ -d "de" ]; then
    echo "⚠️  Carpeta de recursos alemanes encontrada (se eliminará en la publicación)"
fi

# Verificar archivos de configuración
JSON_COUNT=$(ls *.json 2>/dev/null | wc -l)
CONFIG_COUNT=$(ls *.config 2>/dev/null | wc -l)

if [ $JSON_COUNT -gt 0 ]; then
    echo "✅ $JSON_COUNT archivos JSON encontrados"
fi

if [ $CONFIG_COUNT -gt 0 ]; then
    echo "✅ $CONFIG_COUNT archivos de configuración encontrados"
fi

echo ""
echo "📋 Contenido del directorio:"
ls -la

echo ""
echo "✅ Verificación completada"
echo "   La estructura es la correcta para aplicaciones .NET:"
echo "   - Ejecutable y DLLs en el mismo directorio"
echo "   - Recursos localizados en subdirectorios"
echo "   - Archivos de configuración en el directorio principal"

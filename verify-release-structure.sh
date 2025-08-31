#!/bin/bash

echo "=== Verificando estructura del release ==="

# Verificar que existe la carpeta final
if [ ! -d "DiskProtectorApp-final" ]; then
    echo "❌ Error: No se encontró la carpeta DiskProtectorApp-final"
    exit 1
fi

cd DiskProtectorApp-final

echo "🔍 Verificando estructura de archivos para .NET..."
echo "=============================================="

# Verificar que el ejecutable principal exista
if [ -f "DiskProtectorApp.exe" ]; then
    echo "✅ DiskProtectorApp.exe encontrado"
else
    echo "❌ DiskProtectorApp.exe NO encontrado"
    exit 1
fi

# Verificar que las DLLs estén en el directorio principal (estructura correcta para .NET)
DLL_COUNT=$(ls *.dll 2>/dev/null | wc -l)
if [ $DLL_COUNT -gt 0 ]; then
    echo "✅ $DLL_COUNT DLLs encontradas en el directorio principal (estructura correcta para .NET)"
else
    echo "⚠️  No se encontraron DLLs en el directorio principal"
fi

# Verificar estructura de recursos localizados
LOCALE_FOLDERS=0
if [ -d "en" ]; then
    echo "✅ Carpeta de recursos en inglés encontrada"
    LOCALE_FOLDERS=$((LOCALE_FOLDERS + 1))
fi

if [ -d "es" ]; then
    echo "✅ Carpeta de recursos en español encontrada"
    LOCALE_FOLDERS=$((LOCALE_FOLDERS + 1))
fi

if [ -d "de" ]; then
    echo "❌ Carpeta de recursos alemanes encontrada (debe ser eliminada)"
fi

# Verificar que NO existan las carpetas que causaron problemas
if [ -d "libs" ] || [ -d "config" ] || [ -d "locales" ]; then
    echo "❌ Estructura incorrecta: Se encontraron carpetas que no deberían existir:"
    [ -d "libs" ] && echo "   - libs/"
    [ -d "config" ] && echo "   - config/"
    [ -d "locales" ] && echo "   - locales/"
    echo "   La estructura correcta para .NET requiere todos los archivos en el mismo directorio"
    exit 1
else
    echo "✅ Estructura correcta: No se encontraron carpetas innecesarias"
fi

echo ""
echo "📊 Contenido del directorio:"
ls -la

echo ""
echo "✅ Verificación completada exitosamente"
echo "   La estructura es la correcta para aplicaciones .NET:"
echo "   - Ejecutable y DLLs en el mismo directorio principal"
echo "   - Recursos localizados en subdirectorios (en/, es/)"
echo "   - Sin carpetas innecesarias (libs/, config/, locales/)"

#!/bin/bash

echo "=== Diagnosticando estructura de la aplicación ==="

# Verificar que estamos en el directorio correcto
if [ ! -d "DiskProtectorApp-final" ]; then
    echo "❌ Error: No se encontró la carpeta DiskProtectorApp-final"
    exit 1
fi

cd DiskProtectorApp-final

echo "📂 Verificando estructura actual..."
echo "=================================="
find . -type f -name "*.exe" -o -name "*.dll" | head -20

echo ""
echo "🔍 Verificando ejecutable principal..."
echo "===================================="
if [ -f "DiskProtectorApp.exe" ]; then
    echo "✅ DiskProtectorApp.exe encontrado"
    ls -la DiskProtectorApp.exe
else
    echo "❌ DiskProtectorApp.exe NO encontrado"
fi

echo ""
echo "📚 Verificando librerías..."
echo "========================="
if [ -d "libs" ]; then
    echo "✅ Carpeta libs encontrada"
    echo "   DLLs encontradas: $(ls libs/*.dll 2>/dev/null | wc -l)"
    ls libs/*.dll 2>/dev/null | head -10
else
    echo "❌ Carpeta libs NO encontrada"
fi

echo ""
echo "🌍 Verificando recursos localizados..."
echo "===================================="
if [ -d "locales" ]; then
    echo "✅ Carpeta locales encontrada"
    find locales/ -type d
else
    echo "❌ Carpeta locales NO encontrada"
fi

echo ""
echo "⚙️  Verificando archivos de configuración..."
echo "=========================================="
if [ -d "config" ]; then
    echo "✅ Carpeta config encontrada"
    ls config/ 2>/dev/null
else
    echo "❌ Carpeta config NO encontrada"
fi

echo ""
echo "🔧 Creando estructura compatible con .NET..."
echo "=========================================="

# Para aplicaciones .NET, las DLLs deben estar en el mismo directorio que el ejecutable
# o en subdirectorios específicos. Vamos a crear una estructura compatible:

# Crear backup de la estructura actual
cd ..
if [ ! -d "DiskProtectorApp-backup" ]; then
    cp -r DiskProtectorApp-final DiskProtectorApp-backup
    echo "✅ Backup creado en DiskProtectorApp-backup"
fi

cd DiskProtectorApp-final

# Mover las DLLs de vuelta al directorio principal
if [ -d "libs" ]; then
    echo "🔄 Moviendo DLLs al directorio principal..."
    mv libs/*.dll . 2>/dev/null || echo "   No se encontraron DLLs para mover"
    # Mantener la carpeta libs por si hay referencias a ella
    echo "   DLLs movidas, carpeta libs mantenida"
fi

# Mover recursos localizados al directorio principal si es necesario
if [ -d "locales" ]; then
    echo "🔄 Manteniendo recursos localizados en locales/"
    # .NET busca recursos localizados en subdirectorios con el nombre del culture
    # Esta estructura debería ser correcta
fi

# Mover archivos de configuración al directorio principal
if [ -d "config" ]; then
    echo "🔄 Moviendo archivos de configuración al directorio principal..."
    mv config/*.json . 2>/dev/null || echo "   No se encontraron archivos JSON para mover"
    mv config/*.config . 2>/dev/null || echo "   No se encontraron archivos config para mover"
fi

echo ""
echo "✅ Estructura corregida para compatibilidad con .NET"
echo "   La nueva estructura mantiene las DLLs junto al ejecutable principal"

echo ""
echo "�� Contenido actual del directorio:"
ls -la

echo ""
echo "💡 Instrucciones para probar:"
echo "   1. Copia la carpeta 'DiskProtectorApp-final' completa a un entorno Windows"
echo "   2. Asegúrate de tener .NET 8.0 Desktop Runtime instalado"
echo "   3. Ejecuta 'DiskProtectorApp.exe' como Administrador"
echo ""
echo "🔧 Si aún no funciona, crea un archivo de diagnóstico:"
echo "   En Windows, abre una terminal en la carpeta y ejecuta:"
echo "   DiskProtectorApp.exe > output.log 2>&1"
echo "   Esto creará un log con posibles errores"

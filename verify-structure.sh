#!/bin/bash

echo "=== Verificando estructura del proyecto ==="

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

echo ""
echo "🔍 Verificando estructura del proyecto..."
echo "===================================="

# Verificar carpetas principales
echo "📁 Carpetas principales:"
if [ -d "src/DiskProtectorApp" ]; then
    echo "✅ src/DiskProtectorApp/"
else
    echo "❌ src/DiskProtectorApp/"
fi

if [ -d "src/DiskProtectorApp/Services" ]; then
    echo "✅ src/DiskProtectorApp/Services/"
else
    echo "❌ src/DiskProtectorApp/Services/"
fi

if [ -d "src/DiskProtectorApp/ViewModels" ]; then
    echo "✅ src/DiskProtectorApp/ViewModels/"
else
    echo "❌ src/DiskProtectorApp/ViewModels/"
fi

if [ -d "src/DiskProtectorApp/Views" ]; then
    echo "✅ src/DiskProtectorApp/Views/"
else
    echo "❌ src/DiskProtectorApp/Views/"
fi

if [ -d "src/DiskProtectorApp/Models" ]; then
    echo "✅ src/DiskProtectorApp/Models/"
else
    echo "❌ src/DiskProtectorApp/Models/"
fi

echo ""
echo "📄 Archivos principales:"
if [ -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "✅ src/DiskProtectorApp/DiskProtectorApp.csproj"
else
    echo "❌ src/DiskProtectorApp/DiskProtectorApp.csproj"
fi

if [ -f "src/DiskProtectorApp/Views/MainWindow.xaml" ]; then
    echo "✅ src/DiskProtectorApp/Views/MainWindow.xaml"
else
    echo "❌ src/DiskProtectorApp/Views/MainWindow.xaml"
fi

echo ""
echo "📊 Versión en el archivo de proyecto:"
grep -A 5 -B 5 "<Version>" src/DiskProtectorApp/DiskProtectorApp.csproj

echo ""
echo "📋 Scripts disponibles:"
ls -la *.sh | grep -v "total "

echo ""
echo "✅ Verificación completada"

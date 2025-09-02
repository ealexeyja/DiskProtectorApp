#!/bin/bash

echo "=== Corrigiendo referencia de namespace ==="

# Verificar la estructura de carpetas
echo "🔍 Verificando estructura de proyecto..."
if [ ! -d "src/DiskProtectorApp/ViewModels" ]; then
    echo "❌ Error: No se encontró la carpeta ViewModels"
    exit 1
fi

if [ ! -f "src/DiskProtectorApp/ViewModels/MainViewModel.cs" ]; then
    echo "❌ Error: No se encontró MainViewModel.cs"
    echo "   Archivos encontrados en ViewModels:"
    ls -la src/DiskProtectorApp/ViewModels/ 2>/dev/null || echo "   No se puede listar el contenido"
    exit 1
fi

# Corregir la referencia de namespace en MainWindow.xaml.cs
echo "🔧 Corrigiendo referencia de namespace en MainWindow.xaml.cs..."

# Verificar el contenido actual
echo "📄 Contenido actual de MainWindow.xaml.cs (línea 1):"
head -1 src/DiskProtectorApp/Views/MainWindow.xaml.cs

# Corregir la referencia de namespace
sed -i '1s/using DiskProtectorApp\.ViewModels;/using DiskProtectorApp.ViewModels;/' src/DiskProtectorApp/Views/MainWindow.xaml.cs

echo "✅ Referencia de namespace corregida"
echo "📄 Nuevo contenido de MainWindow.xaml.cs (línea 1):"
head -1 src/DiskProtectorApp/Views/MainWindow.xaml.cs

# Verificar que el namespace esté correctamente definido en MainViewModel.cs
echo "🔍 Verificando namespace en MainViewModel.cs..."
head -5 src/DiskProtectorApp/ViewModels/MainViewModel.cs | grep "namespace"

echo ""
echo "🔄 Volviendo a intentar la compilación..."
echo "======================================"

# Intentar compilar nuevamente
if ./build-app.sh; then
    echo "✅ ¡Compilación exitosa después de corregir la referencia!"
else
    echo "❌ La compilación aún falla. Verificando estructura completa..."
    
    # Mostrar estructura del proyecto
    echo "📁 Estructura del proyecto:"
    find src/DiskProtectorApp -name "*.cs" | sort
    
    # Verificar referencias en el archivo .csproj
    echo ""
    echo "📄 Verificando referencias en .csproj..."
    grep -A 10 -B 5 "ViewModels" src/DiskProtectorApp/DiskProtectorApp.csproj
    
    echo ""
    echo "💡 Posibles soluciones:"
    echo "1. Verificar que la carpeta ViewModels exista y tenga MainViewModel.cs"
    echo "2. Revisar que las referencias en DiskProtectorApp.csproj sean correctas"
    echo "3. Asegurarse de que los namespaces coincidan en todos los archivos"
fi

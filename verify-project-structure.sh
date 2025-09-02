#!/bin/bash

echo "=== Verificando estructura completa del proyecto ==="

# Verificar estructura de carpetas
echo "📁 Verificando estructura de carpetas..."
echo "===================================="

if [ ! -d "src/DiskProtectorApp" ]; then
    echo "❌ Error: No se encontró la carpeta principal del proyecto"
    exit 1
fi

echo "✅ Carpeta principal encontrada: src/DiskProtectorApp/"

# Verificar carpetas esenciales
ESSENTIAL_FOLDERS=("Services" "ViewModels" "Views" "Models")
for folder in "${ESSENTIAL_FOLDERS[@]}"; do
    if [ -d "src/DiskProtectorApp/$folder" ]; then
        echo "✅ Carpeta encontrada: src/DiskProtectorApp/$folder/"
        ls -la "src/DiskProtectorApp/$folder/" | head -10
    else
        echo "❌ Carpeta NO encontrada: src/DiskProtectorApp/$folder/"
    fi
done

# Verificar archivos esenciales
echo ""
echo "📄 Verificando archivos esenciales..."
echo "================================="

ESSENTIAL_FILES=(
    "src/DiskProtectorApp/DiskProtectorApp.csproj"
    "src/DiskProtectorApp/Services/DiskService.cs"
    "src/DiskProtectorApp/ViewModels/MainViewModel.cs"
    "src/DiskProtectorApp/Views/MainWindow.xaml"
    "src/DiskProtectorApp/Views/MainWindow.xaml.cs"
    "src/DiskProtectorApp/Models/DiskInfo.cs"
)

for file in "${ESSENTIAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ Archivo encontrado: $file"
    else
        echo "❌ Archivo NO encontrado: $file"
    fi
done

# Verificar contenido de MainViewModel.cs
echo ""
echo "🔍 Verificando contenido de MainViewModel.cs..."
echo "=========================================="

if [ -f "src/DiskProtectorApp/ViewModels/MainViewModel.cs" ]; then
    echo "📄 Primeras 30 líneas de MainViewModel.cs:"
    head -30 src/DiskProtectorApp/ViewModels/MainViewModel.cs
    
    echo ""
    echo "🔧 Verificando referencias using..."
    grep "^using" src/DiskProtectorApp/ViewModels/MainViewModel.cs
    
    echo ""
    echo "🔧 Verificando declaración de DiskService..."
    grep -A 5 -B 5 "private readonly DiskService" src/DiskProtectorApp/ViewModels/MainViewModel.cs
fi

# Verificar contenido de DiskService.cs
echo ""
echo "🔍 Verificando contenido de DiskService.cs..."
echo "========================================"

if [ -f "src/DiskProtectorApp/Services/DiskService.cs" ]; then
    echo "📄 Primeras 20 líneas de DiskService.cs:"
    head -20 src/DiskProtectorApp/Services/DiskService.cs
    
    echo ""
    echo "🔧 Verificando namespace..."
    grep "namespace" src/DiskProtectorApp/Services/DiskService.cs | head -1
fi

# Verificar referencias en .csproj
echo ""
echo "📄 Verificando referencias en .csproj..."
echo "==================================="

if [ -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "🔧 Contenido del .csproj:"
    cat src/DiskProtectorApp/DiskProtectorApp.csproj
    
    echo ""
    echo "🔧 Verificando versión del proyecto:"
    grep "<Version>" src/DiskProtectorApp/DiskProtectorApp.csproj
fi

echo ""
echo "✅ Verificación de estructura completada"
echo ""
echo "💡 Si hay errores de compilación:"
echo "   1. Verifica que las referencias using sean correctas"
echo "   2. Asegúrate de que los namespaces coincidan"
echo "   3. Confirma que las clases estén correctamente definidas"
echo "   4. Revisa que el .csproj incluya todas las carpetas"

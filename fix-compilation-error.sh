#!/bin/bash

echo "=== Corrigiendo error de compilación ==="

# Verificar que existe el archivo MainViewModel.cs
if [ ! -f "src/DiskProtectorApp/ViewModels/MainViewModel.cs" ]; then
    echo "❌ Error: No se encontró MainViewModel.cs"
    exit 1
fi

# Verificar que existe el archivo DiskService.cs
if [ ! -f "src/DiskProtectorApp/Services/DiskService.cs" ]; then
    echo "❌ Error: No se encontró DiskService.cs"
    exit 1
fi

# Verificar las referencias using en MainViewModel.cs
echo "🔍 Verificando referencias using en MainViewModel.cs..."
grep "^using" src/DiskProtectorApp/ViewModels/MainViewModel.cs

# Agregar la referencia correcta si no existe
if ! grep -q "using DiskProtectorApp.Services;" src/DiskProtectorApp/ViewModels/MainViewModel.cs; then
    echo "🔧 Agregando referencia a DiskProtectorApp.Services..."
    
    # Insertar la referencia using después de las otras referencias using
    sed -i '/using System.Windows.Input;/a using DiskProtectorApp.Services;' src/DiskProtectorApp/ViewModels/MainViewModel.cs
    
    echo "✅ Referencia a DiskProtectorApp.Services agregada"
else
    echo "✅ Referencia a DiskProtectorApp.Services ya existe"
fi

# Verificar el namespace en DiskService.cs
echo "🔍 Verificando namespace en DiskService.cs..."
head -5 src/DiskProtectorApp/Services/DiskService.cs | grep "namespace"

# Verificar el namespace en MainViewModel.cs
echo "🔍 Verificando namespace en MainViewModel.cs..."
head -5 src/DiskProtectorApp/ViewModels/MainViewModel.cs | grep "namespace"

echo ""
echo "🔄 Volviendo a intentar la compilación..."
echo "======================================"

# Intentar compilar nuevamente
if ./build-app.sh; then
    echo "✅ ¡Compilación exitosa después de corregir las referencias!"
else
    echo "❌ La compilación aún falla. Verificando estructura completa..."
    
    # Mostrar estructura del proyecto
    echo "📁 Estructura del proyecto:"
    find src/DiskProtectorApp -name "*.cs" | sort
    
    # Verificar referencias en el archivo .csproj
    echo ""
    echo "📄 Verificando referencias en .csproj..."
    grep -A 10 -B 5 "Services\|ViewModels" src/DiskProtectorApp/DiskProtectorApp.csproj
    
    echo ""
    echo "💡 Posibles soluciones:"
    echo "1. Verificar que la carpeta Services exista y tenga DiskService.cs"
    echo "2. Verificar que la carpeta ViewModels exista y tenga MainViewModel.cs"
    echo "3. Revisar que las referencias en DiskProtectorApp.csproj sean correctas"
    echo "4. Asegurarse de que los namespaces coincidan en todos los archivos"
fi

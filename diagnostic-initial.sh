#!/bin/bash

echo "=== Diagnóstico inicial del proyecto ==="

# Verificar estructura del proyecto
echo "🔍 Verificando estructura del proyecto..."
echo "===================================="

if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

echo "✅ Archivo de proyecto encontrado"

# Obtener la versión actual
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.2.7"
fi

echo "�� Versión actual: v$CURRENT_VERSION"

# Verificar carpetas esenciales
echo ""
echo "📂 Verificando carpetas esenciales..."
echo "================================"

ESSENTIAL_FOLDERS=("src/DiskProtectorApp/Services" "src/DiskProtectorApp/ViewModels" "src/DiskProtectorApp/Views" "src/DiskProtectorApp/Models")
for folder in "${ESSENTIAL_FOLDERS[@]}"; do
    if [ -d "$folder" ]; then
        echo "✅ Carpeta encontrada: $folder"
    else
        echo "❌ Carpeta NO encontrada: $folder"
    fi
done

# Verificar archivos esenciales
echo ""
echo "📄 Verificando archivos esenciales..."
echo "==============================="

ESSENTIAL_FILES=(
    "src/DiskProtectorApp/DiskProtectorApp.csproj"
    "src/DiskProtectorApp/App.xaml"
    "src/DiskProtectorApp/App.xaml.cs"
    "src/DiskProtectorApp/app.manifest"
    "src/DiskProtectorApp/RelayCommand.cs"
    "src/DiskProtectorApp/Controls/DiskStatusIndicator.xaml"
    "src/DiskProtectorApp/Controls/DiskStatusIndicator.xaml.cs"
    "src/DiskProtectorApp/Converters/DiskStatusToBrushConverter.cs"
    "src/DiskProtectorApp/Logging/AppLogger.cs"
    "src/DiskProtectorApp/Models/DiskInfo.cs"
    "src/DiskProtectorApp/Resources/app.ico"
    "src/DiskProtectorApp/Services/DiskService.cs"
    "src/DiskProtectorApp/ViewModels/MainViewModel.cs"
    "src/DiskProtectorApp/Views/MainWindow.xaml"
    "src/DiskProtectorApp/Views/MainWindow.xaml.cs"
    "src/DiskProtectorApp/Views/ProgressDialog.xaml"
    "src/DiskProtectorApp/Views/ProgressDialog.xaml.cs"
)

for file in "${ESSENTIAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ Archivo encontrado: $file"
    else
        echo "❌ Archivo NO encontrado: $file"
    fi
done

# Verificar estado de Git
echo ""
echo "🔍 Verificando estado de Git..."
echo "============================"

if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Hay cambios sin commitear:"
    git status --porcelain
else
    echo "✅ No hay cambios pendientes"
fi

echo ""
echo "🏷️  Tags locales:"
git tag --sort=-version:refname | head -5

echo ""
echo "☁️  Tags remotos:"
git ls-remote --tags origin 2>/dev/null | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | sort -V | tail -5

echo ""
echo "✅ Diagnóstico inicial completado"
echo "   Versión: v$CURRENT_VERSION"
echo "   Estado: Listo para proceder"

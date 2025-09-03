#!/bin/bash

echo "=== Corrigiendo versión a 1.2.8 en todos los archivos ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

echo "📦 Actualizando versión a v1.2.8 en todos los archivos..."

# 1. Actualizar el archivo .csproj con la nueva versión
echo "📝 Actualizando src/DiskProtectorApp/DiskProtectorApp.csproj..."
sed -i 's/<Version>[0-9]*\.[0-9]*\.[0-9]*<\/Version>/<Version>1.2.8<\/Version>/g' src/DiskProtectorApp/DiskProtectorApp.csproj
sed -i 's/<AssemblyVersion>[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*<\/AssemblyVersion>/<AssemblyVersion>1.2.8.0<\/AssemblyVersion>/g' src/DiskProtectorApp/DiskProtectorApp.csproj
sed -i 's/<FileVersion>[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*<\/FileVersion>/<FileVersion>1.2.8.0<\/FileVersion>/g' src/DiskProtectorApp/DiskProtectorApp.csproj
sed -i 's/<InformationalVersion>[0-9]*\.[0-9]*\.[0-9]*<\/InformationalVersion>/<InformationalVersion>1.2.8<\/InformationalVersion>/g' src/DiskProtectorApp/DiskProtectorApp.csproj

# 2. Actualizar el título en MainWindow.xaml
echo "📝 Actualizando src/DiskProtectorApp/Views/MainWindow.xaml..."
sed -i 's/Title="DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*"/Title="DiskProtectorApp v1.2.8"/g' src/DiskProtectorApp/Views/MainWindow.xaml

# 3. Actualizar AssemblyInfo si existe
if [ -f "src/DiskProtectorApp/Properties/AssemblyInfo.cs" ]; then
    echo "📝 Actualizando src/DiskProtectorApp/Properties/AssemblyInfo.cs..."
    sed -i 's/AssemblyVersion("[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")/AssemblyVersion("1.2.8.0")/g' src/DiskProtectorApp/Properties/AssemblyInfo.cs
    sed -i 's/AssemblyFileVersion("[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")/AssemblyFileVersion("1.2.8.0")/g' src/DiskProtectorApp/Properties/AssemblyInfo.cs
    sed -i 's/AssemblyInformationalVersion("[0-9]*\.[0-9]*\.[0-9]*")/AssemblyInformationalVersion("1.2.8")/g' src/DiskProtectorApp/Properties/AssemblyInfo.cs
fi

# 4. Actualizar README.md
echo "📝 Actualizando README.md..."
if [ -f "README.md" ]; then
    sed -i 's/DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/DiskProtectorApp v1.2.8/g' README.md
    sed -i 's/# DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/# DiskProtectorApp v1.2.8/g' README.md
fi

# 5. Verificar que los cambios se aplicaron correctamente
echo ""
echo "🔍 Verificando cambios aplicados..."

# Verificar versión en .csproj
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ "$CURRENT_VERSION" = "1.2.8" ]; then
    echo "✅ Versión en .csproj actualizada correctamente: v$CURRENT_VERSION"
else
    echo "❌ Error: Versión en .csproj no actualizada correctamente: v$CURRENT_VERSION"
fi

# Verificar título en MainWindow.xaml
MAINWINDOW_TITLE=$(grep -o 'Title="DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*"' src/DiskProtectorApp/Views/MainWindow.xaml | cut -d'"' -f2)
if [ "$MAINWINDOW_TITLE" = "DiskProtectorApp v1.2.8" ]; then
    echo "✅ Título en MainWindow.xaml actualizado correctamente: $MAINWINDOW_TITLE"
else
    echo "❌ Error: Título en MainWindow.xaml no actualizado correctamente: $MAINWINDOW_TITLE"
fi

# Verificar README.md
if [ -f "README.md" ]; then
    README_VERSION=$(grep -o '# DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*' README.md | cut -d' ' -f3)
    if [ "$README_VERSION" = "v1.2.8" ]; then
        echo "✅ Versión en README.md actualizada correctamente: $README_VERSION"
    else
        echo "❌ Error: Versión en README.md no actualizada correctamente: $README_VERSION"
    fi
fi

echo ""
echo "✅ ¡Versión v1.2.8 actualizada en todos los archivos!"
echo "   Cambios aplicados:"
echo "   - src/DiskProtectorApp/DiskProtectorApp.csproj: v1.2.8"
echo "   - src/DiskProtectorApp/Views/MainWindow.xaml: v1.2.8"
echo "   - README.md: v1.2.8"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/DiskProtectorApp.csproj"
echo "2. git add src/DiskProtectorApp/Views/MainWindow.xaml"
echo "3. git add README.md"
echo "4. git commit -m \"release: v1.2.8 - Actualización de versión\""
echo "5. git push origin main"
echo ""
echo "Luego ejecuta './build-app.sh' para compilar la nueva versión"

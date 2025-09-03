#!/bin/bash

echo "=== Corrigiendo inconsistencias de versión ==="

# Verificar versión actual en el proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
echo "🔍 Versión actual en .csproj: v$CURRENT_VERSION"

# Si no hay versión, establecer v1.2.7
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.2.7"
    echo "🔧 Estableciendo versión a v$CURRENT_VERSION"
    
    # Actualizar el archivo .csproj
    sed -i "s/<Version>[^<]*<\/Version>/<Version>$CURRENT_VERSION<\/Version>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
    sed -i "s/<AssemblyVersion>[^<]*<\/AssemblyVersion>/<AssemblyVersion>$CURRENT_VERSION.0<\/AssemblyVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
    sed -i "s/<FileVersion>[^<]*<\/FileVersion>/<FileVersion>$CURRENT_VERSION.0<\/FileVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
    sed -i "s/<InformationalVersion>[^<]*<\/InformationalVersion>/<InformationalVersion>$CURRENT_VERSION<\/InformationalVersion>/g" src/DiskProtectorApp/DiskProtectorApp.csproj
fi

# Actualizar MainWindow.xaml con la versión correcta
sed -i "s/Title=\"DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*\"/Title=\"DiskProtectorApp v$CURRENT_VERSION\"/g" src/DiskProtectorApp/Views/MainWindow.xaml

# Actualizar todos los README con la versión correcta
find . -name "README*" -type f | while read file; do
    sed -i "s/DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/DiskProtectorApp v$CURRENT_VERSION/g" "$file"
done

echo "✅ Versión corregida a v$CURRENT_VERSION en todos los archivos"
echo ""
echo "📄 Archivos actualizados:"
echo "   - src/DiskProtectorApp/DiskProtectorApp.csproj"
echo "   - src/DiskProtectorApp/Views/MainWindow.xaml"
echo "   - Todos los archivos README encontrados"

# Verificar estructura de archivos
echo ""
echo "📂 Verificando estructura de archivos..."
echo "===================================="

if [ -d "DiskProtectorApp-final" ]; then
    echo "✅ Carpeta DiskProtectorApp-final encontrada"
    echo "   Contenido:"
    ls -la DiskProtectorApp-final/ | head -10
else
    echo "❌ Carpeta DiskProtectorApp-final NO encontrada"
fi

if [ -d "publish-test" ]; then
    echo "✅ Carpeta publish-test encontrada"
    echo "   Contenido:"
    ls -la publish-test/ | head -10
else
    echo "❌ Carpeta publish-test NO encontrada"
fi

# Verificar versión en los archivos generados
echo ""
echo "🔍 Verificando versión en archivos generados..."
echo "=========================================="

# Buscar archivos con información de versión
grep -r "v[0-9]*\.[0-9]*\.[0-9]*" src/DiskProtectorApp/ --include="*.cs" --include="*.xaml" --include="*.csproj" | head -5

echo ""
echo "📦 Versión actual confirmada: v$CURRENT_VERSION"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/DiskProtectorApp.csproj"
echo "2. git add src/DiskProtectorApp/Views/MainWindow.xaml"
echo "3. git add README.md"
echo "4. git commit -m \"fix: Corregir inconsistencias de versión v$CURRENT_VERSION\""
echo "5. git push origin main"

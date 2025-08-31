#!/bin/bash

echo "=== Verificando release de DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto. Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.1.0"
fi

echo "🔍 Verificando versión: v$CURRENT_VERSION"

# Verificar si existe alguna carpeta de salida
echo ""
echo "📂 Buscando carpetas de salida..."

# Buscar la carpeta correcta (puede ser cualquiera de estas)
POSSIBLE_FOLDERS=("DiskProtectorApp-final" "DiskProtectorApp-organized" "publish-v$CURRENT_VERSION")
FOUND_FOLDER=""

for folder in "${POSSIBLE_FOLDERS[@]}"; do
    if [ -d "./$folder" ]; then
        FOUND_FOLDER="$folder"
        echo "✅ Carpeta encontrada: $folder"
        break
    fi
done

# Si no encontramos ninguna carpeta, intentar con publish-test
if [ -z "$FOUND_FOLDER" ] && [ -d "./publish-test" ]; then
    FOUND_FOLDER="publish-test"
    echo "✅ Carpeta encontrada: publish-test (carpeta de prueba)"
fi

if [ -z "$FOUND_FOLDER" ]; then
    echo "❌ No se encontró ninguna carpeta de salida."
    echo "   Ejecuta './prepare-new-release.sh' primero para generar las carpetas."
    exit 1
fi

echo ""
echo "📋 Verificando contenido de $FOUND_FOLDER..."

REQUIRED_ITEMS=(
    "DiskProtectorApp.exe"
)

MISSING_ITEMS=0
for item in "${REQUIRED_ITEMS[@]}"; do
    if [ ! -f "./$FOUND_FOLDER/$item" ]; then
        echo "❌ Archivo requerido no encontrado: $item"
        MISSING_ITEMS=1
    else
        echo "✅ Archivo encontrado: $item"
    fi
done

# Verificar estructura de carpetas si es la versión final
if [[ "$FOUND_FOLDER" == "DiskProtectorApp-final" || "$FOUND_FOLDER" == "DiskProtectorApp-organized" ]]; then
    OPTIONAL_FOLDERS=("libs" "locales" "config")
    for folder in "${OPTIONAL_FOLDERS[@]}"; do
        if [ -d "./$FOUND_FOLDER/$folder" ]; then
            echo "✅ Carpeta encontrada: $folder"
        else
            echo "⚠️  Carpeta opcional no encontrada: $folder"
        fi
    done
fi

if [ $MISSING_ITEMS -ne 0 ]; then
    echo "❌ Algunos archivos requeridos faltan."
    exit 1
fi

echo "✅ Estructura de archivos verificada correctamente"

# Verificar archivo comprimido
echo ""
echo "📦 Verificando archivo comprimido..."

if [ -f "./DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "✅ Archivo comprimido encontrado: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
    echo "   Tamaño: $(ls -lh ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz | awk '{print $5}')"
    
    # Verificar contenido del archivo comprimido
    echo "📋 Verificando contenido del archivo comprimido..."
    if tar -tzf ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz > /tmp/tar_contents.txt 2>/dev/null; then
        if grep -q "DiskProtectorApp.exe" /tmp/tar_contents.txt; then
            echo "✅ Ejecutable encontrado en el tar.gz"
        else
            echo "❌ Ejecutable NO encontrado en el tar.gz"
        fi
    else
        echo "❌ No se pudo leer el contenido del archivo comprimido"
    fi
else
    echo "⚠️  Archivo comprimido NO encontrado: DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
    echo "   Esto es normal si aún no ejecutaste './finalize-release.sh'"
fi

echo ""
echo "✅ ¡Verificación completada!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Carpeta de salida: $FOUND_FOLDER"
if [ -f "./DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "   Archivo comprimido: ✅ Presente"
else
    echo "   Archivo comprimido: ❌ No encontrado (ejecuta './finalize-release.sh')"
fi
echo ""
echo "💡 Siguientes pasos:"
if [ ! -f "./DiskProtectorApp-v$CURRENT_VERSION.tar.gz" ]; then
    echo "   1. Ejecuta './finalize-release.sh' para crear el archivo comprimido"
else
    echo "   1. git add ."
    echo "   2. git commit -m \"release: v$CURRENT_VERSION - Nueva versión\""
    echo "   3. git push origin main"
    echo "   4. git tag -a v$CURRENT_VERSION -m \"Release v$CURRENT_VERSION\""
    echo "   5. git push origin v$CURRENT_VERSION"
fi

#!/bin/bash

echo "=== Workflow completo de release para DiskProtectorApp ==="

echo ""
echo "🔧 PASO 1: Actualizar a .NET 8.0"
echo "=============================="
if ! ./update-to-dotnet-8-final.sh; then
    echo "❌ Error al actualizar a .NET 8.0"
    exit 1
fi

echo ""
echo "🔨 PASO 2: Compilar y probar"
echo "=========================="
if ! ./build-and-test-final.sh; then
    echo "❌ Error en la compilación o prueba"
    exit 1
fi

echo ""
echo "📦 PASO 3: Finalizar release"
echo "=========================="
if ! ./finalize-release-final.sh; then
    echo "❌ Error al finalizar el release"
    exit 1
fi

echo ""
echo "🚀 PASO 4: Publicar en GitHub"
echo "============================"
echo "¿Deseas publicar la nueva versión en GitHub? (s/n)"
read -r respuesta
if [[ "$respuesta" =~ ^[Ss]$ ]]; then
    if ! ./publish-release-final.sh; then
        echo "❌ Error al publicar en GitHub"
        exit 1
    fi
else
    echo "⚠️ Publicación en GitHub omitida"
    echo "   Puedes ejecutar './publish-release-final.sh' manualmente más tarde"
fi

echo ""
echo "🎉 ¡Workflow completado exitosamente!"
echo "   Versión actualizada a .NET 8.0"
echo "   Nueva versión disponible para distribución"

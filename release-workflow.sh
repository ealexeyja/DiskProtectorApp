#!/bin/bash

echo "=== Workflow completo de release para DiskProtectorApp ==="

echo ""
echo "🔢 PASO 1: Incrementar versión"
echo "============================"
if ! ./increment-version.sh; then
    echo "❌ Error al incrementar la versión"
    exit 1
fi

echo ""
echo "🔨 PASO 2: Compilar y generar release"
echo "=================================="
if ! ./build-and-release.sh; then
    echo "❌ Error en la compilación o generación del release"
    exit 1
fi

echo ""
echo "🚀 PASO 3: Publicar en GitHub"
echo "============================"
echo "¿Deseas publicar la nueva versión en GitHub? (s/n)"
read -r respuesta
if [[ "$respuesta" =~ ^[Ss]$ ]]; then
    if ! ./publish-to-github.sh; then
        echo "❌ Error al publicar en GitHub"
        exit 1
    fi
else
    echo "⚠️ Publicación en GitHub omitida"
    echo "   Puedes ejecutar './publish-to-github.sh' manualmente más tarde"
fi

echo ""
echo "🎉 ¡Workflow completado exitosamente!"
echo "   Nueva versión disponible para distribución"

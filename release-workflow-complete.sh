#!/bin/bash

echo "=== Workflow completo de release para DiskProtectorApp ==="

echo ""
echo "🚀 PASO 1: Preparar nueva versión"
echo "================================"
if ! ./prepare-new-release.sh; then
    echo "❌ Error en la preparación de la nueva versión"
    exit 1
fi

echo ""
echo "🔍 PASO 2: Verificar release"
echo "=========================="
if ! ./test-release.sh; then
    echo "❌ Error en la verificación del release"
    exit 1
fi

echo ""
echo "📦 PASO 3: Finalizar release"
echo "=========================="
if ! ./finalize-release.sh; then
    echo "❌ Error en la finalización del release"
    exit 1
fi

echo ""
echo "🎉 ¡Workflow completado exitosamente!"
echo "   Sigue las instrucciones del último paso para publicar en GitHub"

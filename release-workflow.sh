#!/bin/bash

echo "=== DiskProtectorApp Release Workflow ==="
echo "Este script ejecutará todo el proceso de release en orden"

# Paso 1: Incrementar versión
echo ""
echo "🚀 PASO 1: Incrementar versión"
echo "=========================="
if ! ./increment-version.sh; then
    echo "❌ Error en el incremento de versión"
    exit 1
fi

# Paso 2: Compilar aplicación
echo ""
echo "🔨 PASO 2: Compilar aplicación"
echo "============================"
if ! ./build-app.sh; then
    echo "❌ Error en la compilación"
    exit 1
fi

# Paso 3: Preparar publicación
echo ""
echo "📦 PASO 3: Preparar publicación en GitHub"
echo "========================================"
if ! ./publish-github.sh; then
    echo "❌ Error en la preparación de publicación"
    exit 1
fi

echo ""
echo "✅ ¡Workflow completado exitosamente!"
echo "   Sigue las instrucciones del último paso para publicar en GitHub"

#!/bin/bash

echo "=== DiskProtectorApp Release Workflow ==="
echo "Este script ejecutará todo el proceso de release en orden"

# Paso 1: Compilar y probar
echo ""
echo "🚀 PASO 1: Compilar y probar"
echo "=========================="
if ! ./build-and-test.sh; then
    echo "❌ Error en la compilación o prueba"
    exit 1
fi

echo ""
echo "✅ Compilación y prueba completadas"
echo "🔍 ¿Deseas continuar con el proceso de release? (s/n)"
read -r respuesta
if [[ ! "$respuesta" =~ ^[Ss]$ ]]; then
    echo "⚠️  Proceso detenido. Puedes ejecutar './release-workflow.sh' cuando estés listo."
    exit 0
fi

# Paso 2: Incrementar versión
echo ""
echo "🔢 PASO 2: Incrementar versión"
echo "============================"
if ! ./increment-version.sh; then
    echo "❌ Error al incrementar la versión"
    exit 1
fi

# Paso 3: Publicar versión final
echo ""
echo "📦 PASO 3: Publicar versión final"
echo "==============================="
if ! ./publish-final.sh; then
    echo "❌ Error en la publicación final"
    exit 1
fi

# Paso 4: Preparar instrucciones para GitHub
echo ""
echo "🏷️  PASO 4: Preparar publicación en GitHub"
echo "========================================"

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)

echo ""
echo "📋 Instrucciones para publicar en GitHub:"
echo "1. git add ."
echo "2. git commit -m \"release: v$CURRENT_VERSION - Nueva versión\""
echo "3. git push origin main"
echo "4. git tag -a v$CURRENT_VERSION -m \"Release v$CURRENT_VERSION\""
echo "5. git push origin v$CURRENT_VERSION"
echo ""
echo "📝 Para crear el release manualmente en GitHub:"
echo "   - Ve a la sección Releases en tu repositorio"
echo "   - Crea un nuevo release con el tag v$CURRENT_VERSION"
echo "   - Adjunta el archivo DiskProtectorApp-v$CURRENT_VERSION.tar.gz"
echo "   - Agrega notas de versión descriptivas"
echo ""
echo "🎉 ¡Workflow completado exitosamente!"
echo "   Versión publicada: v$CURRENT_VERSION"

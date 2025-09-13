#!/bin/bash

echo "=== Workflow completo de compilación y empaquetado ==="

# Paso 1: Diagnóstico inicial
echo ""
echo "🔍 PASO 1: Diagnóstico inicial"
echo "============================"
if ! ./diagnostic-initial.sh; then
    echo "❌ Error en el diagnóstico inicial"
    exit 1
fi

echo ""
echo "✅ Diagnóstico inicial completado"
echo "🔍 ¿Deseas continuar con la compilación? (s/n)"
read -r respuesta
if [[ ! "$respuesta" =~ ^[Ss]$ ]]; then
    echo "⚠️  Proceso detenido. Puedes ejecutar './workflow-complete.sh' cuando estés listo."
    exit 0
fi

# Paso 2: Compilación básica
echo ""
echo "🔨 PASO 2: Compilación básica"
echo "============================"
if ! ./build-basic.sh; then
    echo "❌ Error en la compilación básica"
    exit 1
fi

echo ""
echo "✅ Compilación básica completada"
echo "🔍 ¿Deseas continuar con la publicación? (s/n)"
read -r respuesta2
if [[ ! "$respuesta2" =~ ^[Ss]$ ]]; then
    echo "⚠️  Proceso detenido. Puedes ejecutar './workflow-complete.sh' cuando estés listo."
    exit 0
fi

# Paso 3: Publicación
echo ""
echo "🚀 PASO 3: Publicación"
echo "===================="
if ! ./publish-app.sh; then
    echo "❌ Error en la publicación"
    exit 1
fi

echo ""
echo "✅ Publicación completada"
echo "🔍 ¿Deseas continuar con la organización? (s/n)"
read -r respuesta3
if [[ ! "$respuesta3" =~ ^[Ss]$ ]]; then
    echo "⚠️  Proceso detenido. Puedes ejecutar './workflow-complete.sh' cuando estés listo."
    exit 0
fi

# Paso 4: Organización final
echo ""
echo "📂 PASO 4: Organización final"
echo "=========================="
if ! ./organize-final.sh; then
    echo "❌ Error en la organización final"
    exit 1
fi

echo ""
echo "✅ Organización final completada"
echo "🔍 ¿Deseas continuar con el empaquetado? (s/n)"
read -r respuesta4
if [[ ! "$respuesta4" =~ ^[Ss]$ ]]; then
    echo "⚠️  Proceso detenido. Puedes ejecutar './workflow-complete.sh' cuando estés listo."
    exit 0
fi

# Paso 5: Empaquetado final
echo ""
echo "📦 PASO 5: Empaquetado final"
echo "=========================="
if ! ./package-final.sh; then
    echo "❌ Error en el empaquetado final"
    exit 1
fi

echo ""
echo "🎉 ¡Workflow completado exitosamente!"
echo "   Versión actual: v1.2.7"
echo "   Archivos generados:"
echo "   - Carpeta organizada: DiskProtectorApp-final/"
echo "   - Carpeta de publicación: publish-test/"
echo "   - Archivo comprimido: DiskProtectorApp-v1.2.7.tar.gz"
echo ""
echo "📊 Tamaño del archivo comprimido:"
ls -lh DiskProtectorApp-v1.2.7.tar.gz

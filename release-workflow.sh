#!/bin/bash

echo "=== Workflow completo de release ==="

echo ""
echo "🚀 PASO 1: Compilar aplicación"
echo "============================"
if ! ./build-app.sh; then
    echo "❌ Error en la compilación"
    exit 1
fi

echo ""
echo "✅ Compilación completada"
echo "�� ¿Deseas continuar con el empaquetado? (s/n)"
read -r respuesta
if [[ ! "$respuesta" =~ ^[Ss]$ ]]; then
    echo "⚠️  Proceso detenido. Puedes ejecutar './release-workflow.sh' cuando estés listo."
    exit 0
fi

echo ""
echo "📦 PASO 2: Empaquetar aplicación"
echo "=============================="
if ! ./package-app.sh; then
    echo "❌ Error en el empaquetado"
    exit 1
fi

echo ""
echo "✅ Empaquetado completado"
echo "🔍 ¿Deseas continuar con la publicación? (s/n)"
read -r respuesta2
if [[ ! "$respuesta2" =~ ^[Ss]$ ]]; then
    echo "⚠️  Proceso detenido. Puedes ejecutar './release-workflow.sh' cuando estés listo."
    exit 0
fi

echo ""
echo "☁️  PASO 3: Publicar en GitHub"
echo "============================"
if ! ./publish-app.sh; then
    echo "❌ Error en la publicación"
    exit 1
fi

echo ""
echo "🎉 ¡Workflow completado exitosamente!"
echo "   Versión actual: v1.2.6"
echo "   Siguiente paso: Crear tag en GitHub para activar workflow de Actions"
echo ""
echo "💡 El workflow de GitHub Actions se ejecutará automáticamente"
echo "   al crear el tag v1.2.6"

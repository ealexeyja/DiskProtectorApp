#!/bin/bash

echo "=== Workflow completo de release ==="

# Ejecutar cada paso
echo "1️⃣ Construyendo aplicación..."
if ! ./build-app.sh; then
    echo "❌ Error en construcción"
    exit 1
fi

echo "2️⃣ Empaquetando aplicación..."
if ! ./package-app.sh; then
    echo "❌ Error en empaquetado"
    exit 1
fi

echo "3️⃣ Publicando aplicación..."
if ! ./publish-app.sh; then
    echo "❌ Error en publicación"
    exit 1
fi

echo "🎉 ¡Workflow completado!"

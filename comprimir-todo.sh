#!/bin/bash

# Nombre del archivo comprimido (puedes cambiarlo)
NOMBRE_ARCHIVO="workspace.tar.gz"

# Directorio actual (raíz del workspace)
WORKSPACE="."

# Comprimir todo el contenido del workspace en un tar.gz
tar -czf "$NOMBRE_ARCHIVO" -C "$WORKSPACE" .

echo "✅ Workspace comprimido como: $NOMBRE_ARCHIVO"
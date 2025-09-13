#!/bin/bash

# update-version.sh - Actualiza la versión del proyecto y archivos relacionados

set -e # Salir inmediatamente si un comando falla

echo "=== Actualizador de Versión de DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión ACTUAL desde el .csproj
PROJECT_FILE="src/DiskProtectorApp/DiskProtectorApp.csproj"
CURRENT_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" "$PROJECT_FILE")

if [ -z "$CURRENT_VERSION" ]; then
    echo "⚠️  Advertencia: No se pudo leer la versión actual del .csproj. Usando 0.0.0 como base."
    CURRENT_VERSION="0.0.0"
fi

echo "📦 Versión actual detectada: v$CURRENT_VERSION"

# --- Opciones de nueva versión ---
NEW_VERSION=""
AUTO_INCREMENT=false

# Parsear argumentos
while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--version)
      NEW_VERSION="$2"
      shift # past argument
      shift # past value
      ;;
    -i|--increment)
      AUTO_INCREMENT=true
      shift # past argument
      ;;
    -*|--*)
      echo "Opción desconocida $1"
      exit 1
      ;;
    *)
      echo "Argumento posicional no esperado $1"
      exit 1
      ;;
  esac
done

# --- Determinar la nueva versión ---
if [ "$AUTO_INCREMENT" = true ]; then
    echo "📈 Incrementando automáticamente el número de parche..."
    # Parsear la versión actual
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
elif [ -n "$NEW_VERSION" ]; then
    echo "🔢 Estableciendo versión específica: v$NEW_VERSION"
else
    echo "❓ ¿Qué tipo de actualización deseas?"
    echo "   1) Auto-incrementar parche (v$CURRENT_VERSION -> v$MAJOR.$MINOR.$((PATCH+1)))"
    echo "   2) Especificar versión manualmente"
    read -p "   Selecciona una opción (1 o 2): " choice

    case $choice in
        1)
            IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
            NEW_PATCH=$((PATCH + 1))
            NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
            echo "📈 Versión auto-incrementada a: v$NEW_VERSION"
            ;;
        2)
            read -p "   Ingresa la nueva versión (formato X.Y.Z): " NEW_VERSION
            if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "❌ Formato de versión inválido. Usa X.Y.Z (e.g., 1.2.8)"
                exit 1
            fi
            echo "🔢 Versión establecida a: v$NEW_VERSION"
            ;;
        *)
            echo "❌ Opción no válida."
            exit 1
            ;;
    esac
fi

# Confirmar antes de proceder
echo ""
echo "🔄 ¿Actualizar de v$CURRENT_VERSION a v$NEW_VERSION?"
read -p "   ¿Continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "⚠️  Operación cancelada."
    exit 0
fi

# --- Actualizar el archivo .csproj ---
echo "✏️  Actualizando $PROJECT_FILE..."
sed -i.bak "s|<Version>$CURRENT_VERSION</Version>|<Version>$NEW_VERSION</Version>|g" "$PROJECT_FILE"
sed -i.bak "s|<AssemblyVersion>$CURRENT_VERSION.0</AssemblyVersion>|<AssemblyVersion>$NEW_VERSION.0</AssemblyVersion>|g" "$PROJECT_FILE"
sed -i.bak "s|<FileVersion>$CURRENT_VERSION.0</FileVersion>|<FileVersion>$NEW_VERSION.0</FileVersion>|g" "$PROJECT_FILE"
sed -i.bak "s|<InformationalVersion>$CURRENT_VERSION</InformationalVersion>|<InformationalVersion>$NEW_VERSION</InformationalVersion>|g" "$PROJECT_FILE"

# Limpiar archivos de respaldo temporales
rm -f "$PROJECT_FILE".bak

echo "✅ Archivo de proyecto actualizado."

# --- Actualizar MainWindow.xaml ---
MAIN_WINDOW_FILE="src/DiskProtectorApp/Views/MainWindow.xaml"
if [ -f "$MAIN_WINDOW_FILE" ]; then
    echo "✏️  Actualizando título en $MAIN_WINDOW_FILE..."
    # Usar sed para reemplazar cualquier versión en el título
    sed -i.bak "s|Title=\"DiskProtectorApp v[^\"]*\"|Title=\"DiskProtectorApp v$NEW_VERSION\"|g" "$MAIN_WINDOW_FILE"
    rm -f "$MAIN_WINDOW_FILE".bak
    echo "✅ Título de ventana principal actualizado."
else
    echo "⚠️  No se encontró $MAIN_WINDOW_FILE para actualizar."
fi

# --- Actualizar DetailedHelpWindow.xaml ---
DETAILED_HELP_FILE="src/DiskProtectorApp/Views/DetailedHelpWindow.xaml"
if [ -f "$DETAILED_HELP_FILE" ]; then
    echo "✏️  Actualizando versión en $DETAILED_HELP_FILE..."
    # Usar sed para reemplazar cualquier versión en el texto
    sed -i.bak "s|DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*|DiskProtectorApp v$NEW_VERSION|g" "$DETAILED_HELP_FILE"
    rm -f "$DETAILED_HELP_FILE".bak
    echo "✅ Ventana de ayuda detallada actualizada."
else
    echo "⚠️  No se encontró $DETAILED_HELP_FILE para actualizar."
fi

# --- Actualizar README.md (opcional) ---
README_FILE="README.md"
if [ -f "$README_FILE" ]; then
    echo "✏️  Actualizando versión en $README_FILE..."
    sed -i.bak "s|DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*|DiskProtectorApp v$NEW_VERSION|g" "$README_FILE"
    rm -f "$README_FILE".bak
    echo "✅ README.md actualizado."
else
    echo "ℹ️  No se encontró $README_FILE para actualizar."
fi

# --- Confirmar ---
echo ""
echo "🎉 ¡Versión actualizada exitosamente!"
echo "   Versión anterior: v$CURRENT_VERSION"
echo "   Nueva versión:     v$NEW_VERSION"
echo ""
echo "📄 Archivos modificados:"
echo "   - $PROJECT_FILE"
echo "   - $MAIN_WINDOW_FILE (si existía)"
echo "   - $DETAILED_HELP_FILE (si existía)"
echo "   - $README_FILE (si existía)"

# Nota sobre compilación
echo ""
echo "💡 Nota: La nueva versión se reflejará en el ejecutable al compilar."
echo "         Asegúrate de ejecutar el script de compilación después."


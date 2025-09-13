#!/bin/bash

# organize-app.sh - Organiza los archivos publicados en la estructura final

set -e # Salir inmediatamente si un comando falla

echo "=== Organizando estructura final de DiskProtectorApp ==="

# Verificar que existe la carpeta de publicación
CURRENT_VERSION=$(grep -oPm1 "(?<=<Version>)[^<]+" src/DiskProtectorApp/DiskProtectorApp.csproj)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="0.0.0"
fi

PUBLISH_DIR="./publish-v$CURRENT_VERSION"
FINAL_DIR="./DiskProtectorApp-final"

if [ ! -d "$PUBLISH_DIR" ]; then
    echo "❌ Error: No se encontró la carpeta de publicación ($PUBLISH_DIR)."
    echo "   Ejecuta './build-app.sh' primero"
    exit 1
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Crear estructura final
echo "📂 Creando estructura final en $FINAL_DIR..."
rm -rf "$FINAL_DIR"
mkdir -p "$FINAL_DIR"

# Copiar todos los archivos a la carpeta final
echo "📋 Copiando archivos a la estructura final..."
cp -r "$PUBLISH_DIR"/* "$FINAL_DIR/"

# Eliminar recursos alemanes si existen (opcional)
if [ -d "$FINAL_DIR/de" ]; then
    echo "🗑️  Eliminando recursos en alemán..."
    rm -rf "$FINAL_DIR/de"
fi

# Crear archivo README.txt con instrucciones
echo "📄 Creando archivo README.txt..."
cat > "$FINAL_DIR/README.txt" << 'READMEEOF'
DiskProtectorApp v1.2.7
========================

ESTRUCTURA DE ARCHIVOS:
Todos los archivos (.exe, .dll, recursos) en el mismo directorio

├── DiskProtectorApp.exe     # Ejecutable principal
├── *.dll                    # Librerías y dependencias
├── en/                      # Recursos localizados (inglés)
│   └── [archivos de recursos]
├── es/                      # Recursos localizados (español)
│   └── [archivos de recursos]
├── *.json                   # Archivos de configuración
└── *.config                 # Archivos de configuración

REQUISITOS DEL SISTEMA:
- Windows 10/11 x64
- Microsoft .NET 8.0 Desktop Runtime x64
  Descargar desde: https://dotnet.microsoft.com/download/dotnet/8.0
- Ejecutar como Administrador

INSTRUCCIONES:
1. Ejecutar DiskProtectorApp.exe como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Click en el botón correspondiente
4. Esperar confirmación de la operación

FUNCIONAMIENTO DE PERMISOS:
• DISCO DESPROTEGIDO (NORMAL):
  - Grupo "Usuarios" tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
  - Grupo "Usuarios autenticados" tiene permisos de modificación/escritura
  - Grupo "Administradores" y "SYSTEM" tienen Control Total (siempre)

• DISCO PROTEGIDO:
  - Grupo "Usuarios" NO tiene permisos establecidos
  - Grupo "Usuarios autenticados" solo tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura
  - Grupo "Administradores" y "SYSTEM" mantienen Control Total (siempre)

REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\Logs\operation.log
• Se conservan los últimos 30 días de registros

LOGS DE DIAGNÓSTICO:
• Logs detallados en:
• %APPDATA%\DiskProtectorApp\Logs\
• Categorías: UI, ViewModel, Service, Operation, Permission
• Niveles: DEBUG, INFO, WARN, ERROR, FATAL

 Versión actual: v1.2.7
READMEEOF

# Actualizar la versión en el README
sed -i "s/DiskProtectorApp v[0-9]*\.[0-9]*\.[0-9]*/DiskProtectorApp v$CURRENT_VERSION/g" "$FINAL_DIR/README.txt"

echo ""
echo "✅ ¡Estructura final organizada exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Carpeta organizada: $FINAL_DIR/"
echo ""
echo "📊 Contenido de la carpeta final:"
ls -la "$FINAL_DIR/" | head -20


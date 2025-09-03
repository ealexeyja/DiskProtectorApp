#!/bin/bash

echo "=== Corrigiendo nombres de scripts ==="

# Limpiar archivos con nombres corruptos
echo "�� Limpiando archivos con nombres corruptos..."
rm -f ./create-clean-scripts.shipts.sh
rm -f ./verify-structure.sh
rm -f ./clean-restart.sh
rm -f ./prepare-new-release.sh
rm -f ./build-and-test.sh
rm -f ./finalize-release.sh
rm -f ./publish-to-github.sh
rm -f ./release-workflow.sh
rm -f ./reorganize-app-structure.sh
rm -f ./fix-button-activation-issue.sh
rm -f ./fix-permission-logic-final.sh
rm -f ./fix-compilation-errors-final.sh
rm -f ./fix-nullability-warnings.sh
rm -f ./fix-github-release-permissions.sh
rm -f ./fix-critical-permission-issues.sh
rm -f ./fix-system-volume-info-handling.sh
rm -f ./fix-user-based-protection.sh
rm -f ./fix-administrator-access.sh
rm -f ./fix-release-structure.sh
rm -f ./fix-naming-issue.sh
rm -f ./fix-stuck-script.sh
rm -f ./fix-scripts-structure.sh
rm -f ./implement-exact-permission-logic.sh
rm -f ./implement-correct-permissions-logic.sh
rm -f ./implement-disk-protection-functionality.sh
rm -f ./continue-development-workflow.sh
rm -f ./comprehensive-correction.sh
rm -f ./fix-app-structure-and-permissions.sh
rm -f ./diagnose-app-structure.sh
rm -f ./create-final-release-archive.sh
rm -f ./fix-button-activation-and-logging.sh
rm -f ./fix-compilation-errors.sh
rm -f ./fix-nullability-issues.sh
rm -f ./fix-release-issues.sh
rm -f ./fix-windows-targeting.sh
rm -f ./fix-iconpacks-reference.sh
rm -f ./fix-missing-resources.sh
rm -f ./fix-icon-resource-error.sh
rm -f ./fix-checkbox-binding-synchronization.sh
rm -f ./fix-checkbox-binding.sh
rm -f ./fix-main-window-display.sh
rm -f ./fix-nullability-warning.sh
rm -f ./fix-xaml-conversion-error.sh
rm -f ./fix-github-actions-windows.sh
rm -f ./fix-github-release-permissions.sh
rm -f ./fix-github-workflow-structure.sh
rm -f ./fix-iconpacks-namespace.sh
rm -f ./fix-icon-resource-error.sh
rm -f ./fix-missing-method-error.sh
rm -f ./fix-nullability-warnings.sh
rm -f ./fix-protection-detection-logic.sh
rm -f ./fix-protection-logic-final.sh
rm -f ./fix-relay-command-nullability.sh
rm -f ./fix-system-volume-info-handling.sh
rm -f ./fix-user-based-protection.sh
rm -f ./implement-correct-permission-approach.sh
rm -f ./implement-exact-manual-approach.sh
rm -f ./implement-explicit-permissions-with-logging.sh
rm -f ./make-buttons-always-active.sh
rm -f ./organize-app-structure-final.sh
rm -f ./organize-files.sh
rm -f ./organize-final-structure.sh
rm -f ./prepare-new-release.sh
rm -f ./publish-final.sh
rm -f ./publish-github.sh
rm -f ./publish-release-final.sh
rm -f ./release-workflow-complete.sh
rm -f ./release-workflow.sh
rm -f ./reorganize-app-structure.sh
rm -f ./restore-full-functionality.sh
rm -f ./setup-github-actions.sh
rm -f ./show-selected-disks.sh
rm -f ./test-button-functionality.sh
rm -f ./test-release-corrected.sh
rm -f ./test-release.sh
rm -f ./update-project-for-languages.sh
rm -f ./update-release-workflow.sh
rm -f ./update-to-dotnet-8-final.sh
rm -f ./update-version-display.sh
rm -f ./verify-app-structure.sh
rm -f ./verify-release-structure.sh

echo "✅ Limpieza de archivos corruptos completada"

# Crear solo los scripts esenciales con nombres limpios
cat > build-app.sh << 'BUILDEOF'
#!/bin/bash

echo "=== Compilando DiskProtectorApp ==="

# Verificar que estamos en el directorio correcto
if [ ! -f "src/DiskProtectorApp/DiskProtectorApp.csproj" ]; then
    echo "❌ Error: No se encontró el archivo de proyecto."
    echo "   Asegúrate de ejecutar este script desde la raíz del repositorio."
    exit 1
fi

# Obtener la versión actual del proyecto
CURRENT_VERSION=$(grep -o '<Version>[^<]*' src/DiskProtectorApp/DiskProtectorApp.csproj | cut -d'>' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.2.6"
fi

echo "📦 Versión actual: v$CURRENT_VERSION"

# Limpiar compilaciones anteriores
echo "🧹 Limpiando compilaciones anteriores..."
rm -rf ./publish ./publish-test ./publish-v$CURRENT_VERSION ./DiskProtectorApp-final ./DiskProtectorApp-v$CURRENT_VERSION.tar.gz

# Restaurar dependencias
echo "📥 Restaurando dependencias..."
if ! dotnet restore src/DiskProtectorApp/DiskProtectorApp.csproj; then
    echo "❌ Error al restaurar dependencias"
    exit 1
fi

# Compilar el proyecto
echo "🔨 Compilando el proyecto..."
if ! dotnet build src/DiskProtectorApp/DiskProtectorApp.csproj --configuration Release --no-restore; then
    echo "❌ Error al compilar el proyecto"
    exit 1
fi

# Publicar la aplicación
echo "🚀 Publicando la aplicación para Windows x64..."
if ! dotnet publish src/DiskProtectorApp/DiskProtectorApp.csproj \
    -c Release \
    -r win-x64 \
    --self-contained false \
    -o ./publish-test; then
    echo "❌ Error al publicar la aplicación"
    exit 1
fi

# Verificar que la publicación se generó correctamente
if [ ! -f "./publish-test/DiskProtectorApp.exe" ]; then
    echo "❌ Error: No se encontró el ejecutable publicado"
    exit 1
fi

echo ""
echo "✅ ¡Compilación completada exitosamente!"
echo "   Versión: v$CURRENT_VERSION"
echo "   Carpeta de prueba: publish-test/"
echo ""
echo "📊 Información del ejecutable:"
ls -lh ./publish-test/DiskProtectorApp.exe

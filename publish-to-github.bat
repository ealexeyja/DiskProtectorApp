@echo off
REM publish-to-github.bat - Publica una nueva versión en GitHub

echo === Publicación en GitHub de DiskProtectorApp ===

REM Verificar que existe la carpeta de proyecto
if not exist "src\DiskProtectorApp\DiskProtectorApp.csproj" (
    echo ❌ Error: No se encontró el archivo de proyecto.
    echo    Asegúrate de ejecutar este script desde la raíz del repositorio.
    pause
    exit /b 1
)

REM Obtener la versión actual del proyecto usando PowerShell
for /f "tokens=*" %%a in ('powershell -command "(Select-Xml -Path \"src\DiskProtectorApp\DiskProtectorApp.csproj\" -XPath \"//Version\").Node.InnerXml"') do set "VERSION=%%a"
if "%VERSION%"=="" (
    echo ⚠️  Advertencia: No se pudo leer la versión actual del .csproj. Usando 2.3.0 como base.
    set VERSION=2.3.0
)

echo 📦 Versión actual: v%VERSION%

REM Verificar que existe el archivo comprimido
set ARCHIVE_NAME=DiskProtectorApp-v%VERSION%-portable.tar.gz
set ZIP_NAME=DiskProtectorApp-v%VERSION%-portable.zip
set INSTALLER_NAME=DiskProtectorApp-v%VERSION%-installer.msi
set BOOTSTRAPPER_NAME=DiskProtectorApp-v%VERSION%-bootstrapper.exe

if not exist "%ARCHIVE_NAME%" (
    echo ❌ Error: No se encontró el archivo comprimido (%ARCHIVE_NAME%).
    echo    Ejecuta 'release-app.bat' primero para generar los archivos.
    pause
    exit /b 1
)

echo 🔍 Verificando archivos para publicar...
set FILES_TO_PUBLISH=

if exist "%ARCHIVE_NAME%" (
    set FILES_TO_PUBLISH=%FILES_TO_PUBLISH% "%ARCHIVE_NAME%"
    echo ✅ Archivo TAR.GZ encontrado: %ARCHIVE_NAME%
)

if exist "%ZIP_NAME%" (
    set FILES_TO_PUBLISH=%FILES_TO_PUBLISH% "%ZIP_NAME%"
    echo ✅ Archivo ZIP encontrado: %ZIP_NAME%
)

if exist "%INSTALLER_NAME%" (
    set FILES_TO_PUBLISH=%FILES_TO_PUBLISH% "%INSTALLER_NAME%"
    echo ✅ Instalador MSI encontrado: %INSTALLER_NAME%
)

if exist "%BOOTSTRAPPER_NAME%" (
    set FILES_TO_PUBLISH=%FILES_TO_PUBLISH% "%BOOTSTRAPPER_NAME%"
    echo ✅ Bootstrapper EXE encontrado: %BOOTSTRAPPER_NAME%
)

if "%FILES_TO_PUBLISH%"=="" (
    echo ❌ Error: No se encontraron archivos para publicar.
    pause
    exit /b 1
)

REM Verificar que git está disponible
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Error: Git no está instalado o no está en el PATH.
    pause
    exit /b 1
)

REM Verificar que estamos en un repositorio git
git rev-parse --git-dir >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Error: No estás en un repositorio Git.
    pause
    exit /b 1
)

REM Verificar si hay cambios sin commitear
git diff-index --quiet HEAD -- >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️  Hay cambios sin commitear:
    git status --porcelain
    echo ""
    set /p REPLY="❓ ¿Deseas continuar y commitear automáticamente estos cambios? (s/n): "
    if /i not "%REPLY%"=="s" (
        echo ⚠️  Operación cancelada. Commitea los cambios manualmente antes de publicar.
        pause
        exit /b 0
    )
    
    echo 📥 Agregando todos los cambios...
    git add .
    
    echo 📝 Creando commit...
    git commit -m "release: v%VERSION% - Nueva versión"
)

echo ✅ No hay cambios pendientes en el working directory.

REM Preguntar si desea publicar en GitHub
echo ""
echo ☁️  ¿Deseas publicar la versión v%VERSION% en GitHub? (s/n)
set /p REPLY="   Esta acción incluye push al remoto, crear tag y subir el tag: "
if /i not "%REPLY%"=="s" (
    echo ⚠️  Publicación en GitHub cancelada.
    pause
    exit /b 0
)

REM Subir cambios a GitHub
echo 🚀 Subiendo cambios a GitHub...
git push origin main
if %errorlevel% neq 0 (
    echo ❌ Error al subir cambios a GitHub
    pause
    exit /b 1
)

REM Crear tag local
echo 🏷️  Creando tag v%VERSION%...
git tag -a "v%VERSION%" -m "Release v%VERSION%"

REM Subir tag a GitHub
echo 📤 Subiendo tag a GitHub...
git push origin "v%VERSION%"
if %errorlevel% neq 0 (
    echo ❌ Error al subir el tag a GitHub
    pause
    exit /b 1
)

echo ""
echo ✅ ¡Publicación en GitHub iniciada exitosamente!
echo    Versión: v%VERSION%
echo    Tag: v%VERSION%
echo ""
echo 📊 El workflow de GitHub Actions se ejecutará automáticamente
echo    al crear el tag v%VERSION%
echo ""
echo 💡 Para monitorear el progreso:
echo    1. Ve a https://github.com/%USERNAME%/DiskProtectorApp/actions  
echo    2. Busca el workflow CI/CD Pipeline
echo    3. Verifica que se esté ejecutando
echo ""
echo 📦 Archivos que se publicarán como assets del release:
for %%f in (%FILES_TO_PUBLISH%) do (
    echo    - %%f
)

REM Notificar que los archivos se adjuntarán automáticamente al release por GitHub Actions
echo ""
echo ℹ️  Nota: Los archivos se adjuntarán automáticamente al release
echo    por el workflow de GitHub Actions cuando se cree el tag.

pause
@echo off
REM build-installer.bat - Script para construir el instalador de DiskProtectorApp en Windows

echo === Construyendo instalador de DiskProtectorApp ===

REM Verificar que existe la carpeta de proyecto
if not exist "..\src\DiskProtectorApp\DiskProtectorApp.csproj" (
    echo ❌ Error: No se encontró el archivo de proyecto.
    echo    Asegúrate de ejecutar este script desde la carpeta installer.
    pause
    exit /b 1
)

REM Obtener la versión actual del proyecto usando PowerShell
for /f "tokens=*" %%a in ('powershell -command "(Select-Xml -Path \"..\src\DiskProtectorApp\DiskProtectorApp.csproj\" -XPath \"//Version\").Node.InnerXml"') do set "VERSION=%%a"
if "%VERSION%"=="" (
    echo ⚠️  Advertencia: No se pudo leer la versión actual del .csproj. Usando 2.3.0 como base.
    set VERSION=2.3.0
)

echo 📦 Versión actual: v%VERSION%

REM Verificar que existe la carpeta de publicación
if not exist "..\publish-v%VERSION%" (
    echo ❌ Error: No se encontró la carpeta de publicación (..\publish-v%VERSION%).
    echo    Ejecuta '..\release-app.bat' primero para generar los archivos.
    pause
    exit /b 1
)

REM Verificar que existe WiX Toolset
echo 🔍 Verificando herramientas de instalación...
where wix.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Error: No se encontró WiX Toolset.
    echo    Por favor, instala WiX Toolset desde https://wixtoolset.org/
    pause
    exit /b 1
)

REM Verificar que existe el archivo .wxs
if not exist "DiskProtectorApp.wxs" (
    echo ❌ Error: No se encontró el archivo DiskProtectorApp.wxs.
    pause
    exit /b 1
)

REM Establecer la variable de entorno para la versión
set APP_VERSION=%VERSION%

REM Compilar el instalador usando WiX 6.0
echo 🔨 Compilando instalador con WiX 6.0...
wix build -arch x64 -dAPP_VERSION="%VERSION%" -ext WixToolset.UI.WixUI -ext WixToolset.Util.wixext -o DiskProtectorApp-v%VERSION%-installer.msi DiskProtectorApp.wxs
if %errorlevel% neq 0 (
    echo ❌ Error al compilar el instalador con WiX 6.0
    pause
    exit /b 1
)

echo ""
echo ✅ ¡Instalador construido exitosamente!
echo    Versión: v%VERSION%
echo    Archivo: DiskProtectorApp-v%VERSION%-installer.msi
echo ""
echo 📊 Tamaño del instalador:
dir DiskProtectorApp-v%VERSION%-installer.msi

REM Copiar el instalador a la carpeta final para incluirlo en el release
if exist "..\DiskProtectorApp-final" (
    echo 📂 Copiando instalador a la carpeta final...
    copy DiskProtectorApp-v%VERSION%-installer.msi "..\DiskProtectorApp-final\"
    echo ✅ Instalador copiado a ..\DiskProtectorApp-final\
)

pause
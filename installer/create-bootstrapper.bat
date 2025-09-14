@echo off
REM create-bootstrapper.bat - Script para crear un instalador con requisitos previos (bootstrapper) en Windows

echo === Creando bootstrapper de DiskProtectorApp ===

REM Obtener la versión actual del proyecto usando PowerShell
for /f "tokens=*" %%a in ('powershell -command "(Select-Xml -Path \"..\src\DiskProtectorApp\DiskProtectorApp.csproj\" -XPath \"//Version\").Node.InnerXml"') do set "VERSION=%%a"
if "%VERSION%"=="" (
    echo ⚠️  Advertencia: No se pudo leer la versión actual del .csproj. Usando 2.3.0 como base.
    set VERSION=2.3.0
)

echo 📦 Versión actual: v%VERSION%

REM Verificar que existe el instalador MSI
if not exist "DiskProtectorApp-v%VERSION%-installer.msi" (
    echo ❌ Error: No se encontró el instalador MSI.
    echo    Ejecuta 'build-installer.bat' primero.
    pause
    exit /b 1
)

REM Verificar que existe WiX Toolset
echo 🔍 Verificando herramientas de bootstrapper...
where torch.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Error: No se encontró WiX Toolset.
    echo    Por favor, instala WiX Toolset desde https://wixtoolset.org/
    pause
    exit /b 1
)

REM Crear archivo de configuración del bootstrapper
echo 📝 Creando archivo de configuración...
(
echo ^<?xml version="1.0" encoding="UTF-8"?^>
echo ^<Wix xmlns="http://wixtoolset.org/schemas/v4/wi"
echo      xmlns:bal="http://wixtoolset.org/schemas/v4/wi/bal"^>
echo   ^<Bundle Name="DiskProtectorApp Bootstrapper v%VERSION%"
echo           Version="%VERSION%"
echo           Manufacturer="Emigdio Alexey Jimenez Acosta"
echo           UpgradeCode="87654321-4321-4321-4321-210987654321"^>
echo     ^<BootstrapperApplication bal:MyTheme="default" /^>
echo     ^<Chain^>
echo       ^<!-- Requisitos previos --^>
echo       ^<PackageGroupRef Id="NetFx80DesktopRedist"/^>
echo       ^<!-- Aplicación principal --^>
echo       ^<MsiPackage SourceFile="DiskProtectorApp-v%VERSION%-installer.msi"
echo                   DisplayName="DiskProtectorApp"/^>
echo     ^</Chain^>
echo   ^</Bundle^>
echo ^</Wix^>
) > Bootstrapper.wxs

REM Compilar y enlazar el bootstrapper usando WiX 6.0
echo 🔨 Compilando y enlazando bootstrapper...
wix build -ext WixToolset.UI.WixUI -ext WixToolset.Util.wixext -ext WixToolset.Bal.wixext -o DiskProtectorApp-v%VERSION%-bootstrapper.exe Bootstrapper.wxs
if %errorlevel% neq 0 (
    echo ❌ Error al compilar y enlazar el bootstrapper con WiX 6.0
    pause
    exit /b 1
)

echo ""
echo ✅ ¡Bootstrapper creado exitosamente!
echo    Versión: v%VERSION%
echo    Archivo: DiskProtectorApp-v%VERSION%-bootstrapper.exe
echo ""
echo 📊 Tamaño del bootstrapper:
dir DiskProtectorApp-v%VERSION%-bootstrapper.exe

REM Copiar el bootstrapper a la carpeta final para incluirlo en el release
if exist "..\DiskProtectorApp-final" (
    echo 📂 Copiando bootstrapper a la carpeta final...
    copy DiskProtectorApp-v%VERSION%-bootstrapper.exe "..\DiskProtectorApp-final\"
    echo ✅ Bootstrapper copiado a ..\DiskProtectorApp-final\
)

pause
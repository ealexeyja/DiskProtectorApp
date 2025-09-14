@echo off
REM release-app.bat - Proceso completo de release de DiskProtectorApp

echo === Proceso completo de release de DiskProtectorApp ===

REM Verificar que estamos en el directorio correcto
if not exist "src\DiskProtectorApp\DiskProtectorApp.csproj" (
    echo ❌ Error: No se encontró el archivo de proyecto.
    echo    Asegúrate de ejecutar este script desde la raíz del repositorio.
    pause
    exit /b 1
)

REM Obtener la versión actual del proyecto usando PowerShell para evitar problemas con findstr
for /f "tokens=*" %%a in ('powershell -command "(Select-Xml -Path \"src\DiskProtectorApp\DiskProtectorApp.csproj\" -XPath \"//Version\").Node.InnerXml"') do set "VERSION=%%a"
if "%VERSION%"=="" (
    echo ⚠️  Advertencia: No se pudo leer la versión actual del .csproj. Usando 2.3.0 como base.
    set VERSION=2.3.0
)

echo 📦 Versión actual: v%VERSION%

REM Preguntar si desea incrementar la versión
echo.
echo 🔢 ¿Deseas incrementar la versión automáticamente? (s/n)
set /p incrementar=
if /i "%incrementar%"=="s" (
    REM Usar el script de actualización de versión
    if exist "update-version.bat" (
        echo 📈 Incrementando versión automáticamente...
        call update-version.bat -i
        
        REM Volver a obtener la nueva versión usando PowerShell
        for /f "tokens=*" %%a in ('powershell -command "(Select-Xml -Path \"src\DiskProtectorApp\DiskProtectorApp.csproj\" -XPath \"//Version\").Node.InnerXml"') do set "VERSION=%%a"
        if "%VERSION%"=="" (
            echo ⚠️  Advertencia: No se pudo leer la nueva versión del .csproj. Usando 2.3.0 como base.
            set VERSION=2.3.0
        )
        echo 📦 Nueva versión: v%VERSION%
    ) else (
        echo ❌ No se encontró el script update-version.bat
        pause
        exit /b 1
    )
)

REM Limpiar compilaciones anteriores
echo.
echo 🧹 Limpiando compilaciones anteriores...
rd /s /q publish publish-test publish-v%VERSION% DiskProtectorApp-final >nul 2>&1
del /q DiskProtectorApp-v%VERSION%*.tar.gz DiskProtectorApp-v%VERSION%*.zip >nul 2>&1

REM Restaurar dependencias
echo.
echo 📥 Restaurando dependencias...
dotnet restore src\DiskProtectorApp\DiskProtectorApp.csproj
if %errorlevel% neq 0 (
    echo ❌ Error al restaurar dependencias
    pause
    exit /b 1
)

REM Compilar el proyecto
echo.
echo 🔨 Compilando el proyecto...
dotnet build src\DiskProtectorApp\DiskProtectorApp.csproj --configuration Release --no-restore
if %errorlevel% neq 0 (
    echo ❌ Error al compilar el proyecto
    pause
    exit /b 1
)

REM Publicar la aplicación
echo.
echo 🚀 Publicando la aplicación para Windows x64...
dotnet publish src\DiskProtectorApp\DiskProtectorApp.csproj ^
    -c Release ^
    -r win-x64 ^
    --self-contained false ^
    -o publish-v%VERSION%
if %errorlevel% neq 0 (
    echo ❌ Error al publicar la aplicación
    pause
    exit /b 1
)

REM Verificar que la publicación se generó correctamente
if not exist "publish-v%VERSION%\DiskProtectorApp.exe" (
    echo ❌ Error: No se encontró el ejecutable publicado
    pause
    exit /b 1
)

echo.
echo ✅ ¡Publicación completada exitosamente!
echo    Versión: v%VERSION%
echo    Carpeta de publicación: publish-v%VERSION%\
echo.
echo 📊 Información del ejecutable:
dir publish-v%VERSION%\DiskProtectorApp.exe

REM Crear estructura final correcta (todos los archivos en el mismo directorio para .NET)
echo.
echo 📂 Creando estructura final correcta para .NET...
mkdir DiskProtectorApp-final >nul 2>&1

REM Copiar todos los archivos a la carpeta final (estructura plana requerida por .NET)
xcopy publish-v%VERSION%\* DiskProtectorApp-final\ /E /I /Y >nul

REM Eliminar recursos alemanes si existen
if exist "DiskProtectorApp-final\de" (
    rd /s /q DiskProtectorApp-final\de
    echo 🗑️ Recursos en alemán eliminados
)

REM Crear archivo readme con instrucciones usando un enfoque más compatible
echo.
echo 📝 Creando archivo readme con instrucciones...
echo DiskProtectorApp v%VERSION% > DiskProtectorApp-final\README.txt
echo ======================== >> DiskProtectorApp-final\README.txt
echo. >> DiskProtectorApp-final\README.txt
echo ESTRUCTURA DE ARCHIVOS CORRECTA PARA .NET: >> DiskProtectorApp-final\README.txt
echo Todos los archivos ^(.exe, .dll, recursos^) en el mismo directorio >> DiskProtectorApp-final\README.txt
echo. >> DiskProtectorApp-final\README.txt
echo ├── DiskProtectorApp.exe     # Ejecutable principal >> DiskProtectorApp-final\README.txt
echo ├── *.dll                    # Librerías y dependencias >> DiskProtectorApp-final\README.txt
echo ├── en/                      # Recursos localizados ^(inglés^) >> DiskProtectorApp-final\README.txt
echo │   └── ^[archivos de recursos^] >> DiskProtectorApp-final\README.txt
echo ├── es/                      # Recursos localizados ^(español^) >> DiskProtectorApp-final\README.txt
echo │   └── ^[archivos de recursos^] >> DiskProtectorApp-final\README.txt
echo ├── *.json                   # Archivos de configuración >> DiskProtectorApp-final\README.txt
echo └── *.config                 # Archivos de configuración >> DiskProtectorApp-final\README.txt
echo. >> DiskProtectorApp-final\README.txt
echo REQUISITOS DEL SISTEMA: >> DiskProtectorApp-final\README.txt
echo - Windows 10/11 x64 >> DiskProtectorApp-final\README.txt
echo - Microsoft .NET 8.0 Desktop Runtime x64 >> DiskProtectorApp-final\README.txt
echo - Ejecutar como Administrador >> DiskProtectorApp-final\README.txt
echo. >> DiskProtectorApp-final\README.txt
echo INSTRUCCIONES: >> DiskProtectorApp-final\README.txt
echo 1. Ejecutar DiskProtectorApp.exe como Administrador >> DiskProtectorApp-final\README.txt
echo 2. Seleccionar los discos a proteger/desproteger >> DiskProtectorApp-final\README.txt
echo 3. Click en el botón correspondiente >> DiskProtectorApp-final\README.txt
echo 4. Esperar confirmación de la operación >> DiskProtectorApp-final\README.txt
echo. >> DiskProtectorApp-final\README.txt
echo FUNCIONAMIENTO DE PERMISOS: >> DiskProtectorApp-final\README.txt
echo • DISCO DESPROTEGIDO ^(NORMAL^): >> DiskProtectorApp-final\README.txt
echo   - Grupo "Usuarios" tiene permisos básicos: Lectura y ejecución, Mostrar contenido de carpeta, Lectura >> DiskProtectorApp-final\README.txt
echo   - Grupo "Usuarios autenticados" tiene permisos de modificación/escritura ^(M, W, F^) >> DiskProtectorApp-final\README.txt
echo   - Grupo "Administradores" y "SYSTEM" tienen Control Total ^(siempre^) >> DiskProtectorApp-final\README.txt
echo. >> DiskProtectorApp-final\README.txt
echo • DISCO PROTEGIDO: >> DiskProtectorApp-final\README.txt
echo   - Grupo "Usuarios" NO tiene permisos establecidos >> DiskProtectorApp-final\README.txt
echo   - Grupo "Usuarios autenticados" solo tiene permisos básicos de lectura/ejecución ^(RX^) >> DiskProtectorApp-final\README.txt
echo   - Grupo "Administradores" y "SYSTEM" mantienen Control Total ^(siempre^) >> DiskProtectorApp-final\README.txt
echo. >> DiskProtectorApp-final\README.txt
echo REGISTRO DE OPERACIONES: >> DiskProtectorApp-final\README.txt
echo • Todas las operaciones se registran en: >> DiskProtectorApp-final\README.txt
echo • %%APPDATA%%\DiskProtectorApp\Logs\operation.log >> DiskProtectorApp-final\README.txt
echo • Se conservan los últimos registros por 30 días >> DiskProtectorApp-final\README.txt
echo. >> DiskProtectorApp-final\README.txt
echo LOGS DE DIAGNÓSTICO: >> DiskProtectorApp-final\README.txt
echo • Logs detallados en: >> DiskProtectorApp-final\README.txt
echo • %%APPDATA%%\DiskProtectorApp\Logs\ >> DiskProtectorApp-final\README.txt
echo • Categorías: UI, ViewModel, Service, Operation, Permission >> DiskProtectorApp-final\README.txt
echo • Niveles: DEBUG, INFO, WARN, ERROR, FATAL >> DiskProtectorApp-final\README.txt
echo. >> DiskProtectorApp-final\README.txt
echo  Versión actual: v%VERSION% >> DiskProtectorApp-final\README.txt

echo.
echo ✅ ¡Estructura final organizada exitosamente!
echo    Versión: v%VERSION%
echo    Carpeta organizada: DiskProtectorApp-final/
echo.
echo 📊 Contenido de la carpeta final:
dir DiskProtectorApp-final\ | findstr /v /c:"<DIR>" | findstr /v "bytes"

REM Crear archivo comprimido final
echo.
echo 📦 Creando archivo comprimido final...

REM Crear archivo TAR.GZ
echo 📦 Creando archivo TAR.GZ...
tar -czf DiskProtectorApp-v%VERSION%-portable.tar.gz -C DiskProtectorApp-final .

REM Crear archivo ZIP si está disponible
echo 📦 Creando archivo ZIP...
if exist "%SystemRoot%\System32\zip.exe" (
    pushd DiskProtectorApp-final
    zip -r ..\DiskProtectorApp-v%VERSION%-portable.zip *
    popd
    echo ✅ Archivo ZIP creado exitosamente
) else (
    echo ⚠️  No se encontró el comando 'zip'. Para crear el archivo ZIP, instala 'zip':
    echo    - Descargar desde: http://gnuwin32.sourceforge.net/packages/zip.htm
    echo    - O usar PowerShell: Compress-Archive -Path DiskProtectorApp-final\* -DestinationPath DiskProtectorApp-v%VERSION%-portable.zip
    Compress-Archive -Path DiskProtectorApp-final\* -DestinationPath DiskProtectorApp-v%VERSION%-portable.zip
)

echo.
echo ✅ ¡Empaquetado completado exitosamente!
echo    Versión: v%VERSION%
echo    Archivo comprimido TAR.GZ: DiskProtectorApp-v%VERSION%-portable.tar.gz
if exist "DiskProtectorApp-v%VERSION%-portable.zip" (
    echo    Archivo comprimido ZIP: DiskProtectorApp-v%VERSION%-portable.zip
)
echo.
echo 📊 Tamaño de los archivos comprimidos:
dir DiskProtectorApp-v%VERSION%-portable.* | findstr /v /c:"<DIR>" | findstr /v "bytes"

echo.
echo 🌐 ¿Deseas publicar esta versión en GitHub ahora? (s/n)
set /p publicar_github=
if /i "%publicar_github%"=="s" (
    echo 📥 Agregando todos los cambios...
    git add .
    
    echo 📝 Creando commit...
    git commit -m "release: v%VERSION% - Nueva versión"
    
    echo 🚀 Subiendo cambios a GitHub...
    git push origin main
    if %errorlevel% neq 0 (
        echo ❌ Error al subir cambios a GitHub
        pause
        exit /b 1
    )
    
    echo 🏷️  Creando tag v%VERSION%...
    git tag -a "v%VERSION%" -m "Release v%VERSION%"
    
    echo 📤 Subiendo tag a GitHub...
    git push origin "v%VERSION%"
    if %errorlevel% neq 0 (
        echo ❌ Error al subir el tag a GitHub
        pause
        exit /b 1
    )
    
    echo.
    echo ✅ ¡Publicación en GitHub completada exitosamente!
    echo    Versión: v%VERSION%
    echo    Tag: v%VERSION%
    echo.
    echo 📊 El workflow de GitHub Actions se ejecutará automáticamente
    echo    al crear el tag v%VERSION%
    echo.
    echo 💡 Para monitorear el progreso:
    echo    1. Ve a https://github.com/%USERNAME%/DiskProtectorApp/actions  
    echo    2. Busca el workflow CI/CD Pipeline
    echo    3. Verifica que se esté ejecutando
)

echo.
echo 🎉 ¡Proceso de release completado exitosamente!
echo    Versión final: v%VERSION%
pause
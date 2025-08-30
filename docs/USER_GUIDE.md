# Guía de Usuario - DiskProtectorApp

## Descripción
DiskProtectorApp es una aplicación que permite proteger y desproteger discos duros en Windows mediante la gestión de permisos NTFS. La aplicación proporciona una interfaz intuitiva para administrar el acceso a los discos.

## Requisitos del Sistema
- Windows 10/11 x64
- Sistema de archivos NTFS
- Microsoft .NET 6.0 Desktop Runtime x64

## Instalación
1. Descargue el archivo `.tar.gz` de la última versión desde la sección de Releases
2. Extraiga el contenido del archivo
3. Ejecute `DiskProtectorApp.exe` como administrador

## Uso de la Aplicación

### Ejecución
1. Haga clic derecho en `DiskProtectorApp.exe`
2. Seleccione "Ejecutar como administrador"

### Interfaz Principal
- **Barra de herramientas**: Contiene botones para actualizar, proteger y desproteger discos
- **Lista de discos**: Muestra información detallada de cada disco
- **Barra de estado**: Muestra mensajes de operación y progreso

### Funcionalidades

#### Proteger Discos
1. Seleccione uno o más discos marcando las casillas correspondientes
2. Haga clic en el botón "Proteger"
3. Los discos seleccionados se protegerán y se mostrarán con estado "Protegido" (verde)

#### Desproteger Discos
1. Seleccione uno o más discos protegidos
2. Haga clic en el botón "Desproteger"
3. Los discos seleccionados se desprotegerán y se mostrarán con estado "Desprotegido" (rojo)

#### Actualizar Lista
- Haga clic en el botón "Actualizar" para refrescar la lista de discos

## Registro de Operaciones
Todas las operaciones de protección y desprotección se registran en:
`%APPDATA%\DiskProtectorApp\operations.log`

Los registros se mantienen por 30 días antes de ser rotados.

## Notas Importantes
- El disco del sistema no puede ser protegido por seguridad
- La aplicación requiere ejecutarse como administrador para funcionar correctamente
- Los cambios en los permisos NTFS son permanentes hasta que se reviertan

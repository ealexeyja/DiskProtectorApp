# DiskProtectorApp

![.NET](https://img.shields.io/badge/.NET-8.0-blue)
![Platform](https://img.shields.io/badge/Platform-Windows-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## Descripción

DiskProtectorApp es una aplicación de escritorio para Windows desarrollada en .NET 8 y WPF que permite proteger y desproteger unidades de disco duro contra modificaciones del contenido mediante la gestión avanzada de permisos NTFS.

La aplicación ofrece una interfaz intuitiva para controlar el acceso a discos, permitiendo restringir o conceder permisos de lectura, escritura y ejecución a diferentes grupos de usuarios de Windows.

## Características Principales

- **Protección de Discos**: Restringe el acceso de escritura/modificación a discos seleccionados
- **Desprotección de Discos**: Restaura el acceso normal de escritura/modificación a discos protegidos
- **Administración de Discos**: Concede permisos de administración a discos no administrables
- **Interfaz Moderna**: Diseño oscuro con controles personalizados usando MahApps.Metro
- **Procesamiento Paralelo**: Procesa múltiples discos simultáneamente para mayor eficiencia
- **Ventanas de Progreso**: Muestra el estado detallado de las operaciones en tiempo real
- **Registro Detallado**: Mantiene logs completos de todas las operaciones realizadas

## Requisitos del Sistema

### Sistema Operativo
- Windows 10/11 x64
- Sistema de archivos NTFS

### Runtime Necesario
- Microsoft .NET 8.0 Desktop Runtime x64
- Descargar desde: https://dotnet.microsoft.com/download/dotnet/8.0

### Permisos
- La aplicación DEBE ejecutarse con privilegios de administrador

## Instalación

1. Descargue el archivo `.tar.gz` de la última versión desde la sección de Releases
2. Extraiga el contenido del archivo en una carpeta de su elección
3. Ejecute `DiskProtectorApp.exe` como administrador

## Uso de la Aplicación

### Ejecución
1. Haga clic derecho en `DiskProtectorApp.exe`
2. Seleccione "Ejecutar como administrador"

### Interfaz Principal
- **Barra de herramientas**: Contiene botones para actualizar, proteger, desproteger y administrar discos
- **Lista de discos**: Muestra información detallada de cada disco disponible
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

#### Administrar Discos
1. Seleccione uno o más discos no administrables
2. Haga clic en el botón "Administrar"
3. La aplicación otorgará permisos de Control Total a SYSTEM y Administradores

#### Actualizar Lista
- Haga clic en el botón "Actualizar" para refrescar la lista de discos

## Lógica de Protección

La aplicación implementa una lógica de protección basada en permisos NTFS:

**DISCO PROTEGIDO:**
- Grupo "Usuarios" NO tiene permisos Allow
- Grupo "Usuarios autenticados" tiene SOLO permisos de lectura/ejecución (RX)

**DISCO DESPROTEGIDO:**
- Grupo "Usuarios" tiene permisos Allow
- Grupo "Usuarios autenticados" tiene permisos de modificación/escritura (M, W, F)

## Registro de Operaciones

Todas las operaciones se registran en:
- `%APPDATA%\DiskProtectorApp\Logs\operation.log`
- Se conservan los últimos registros por 30 días

## Logs de Diagnóstico

Los logs detallados se almacenan en:
- `%APPDATA%\DiskProtectorApp\Logs\`
- Categorías: UI, ViewModel, Service, Operation, Permission
- Niveles: DEBUG, INFO, WARN, ERROR, FATAL

## Desarrollo

### Tecnologías Utilizadas
- .NET 8
- WPF (Windows Presentation Foundation)
- MahApps.Metro para la interfaz moderna
- Patrón MVVM (Model-View-ViewModel)

### Autor
- **Nombre**: Emigdio Alexey Jimenez Acosta
- **Email**: ealexeyja@gmail.com
- **Teléfono**: +53 5586 0259

## Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.

---

**DiskProtectorApp v2.3.0** - Aplicación para protección de discos mediante gestión de permisos NTFS.

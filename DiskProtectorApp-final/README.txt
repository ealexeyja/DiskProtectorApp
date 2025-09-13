DiskProtectorApp v2.3.0
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

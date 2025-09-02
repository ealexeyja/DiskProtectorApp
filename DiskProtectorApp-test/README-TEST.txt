DiskProtectorApp v$CURRENT_VERSION - Versión de Prueba
=====================================================

ESTRUCTURA DE ARCHIVOS CORRECTA PARA .NET:
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
- Ejecutar como Administrador

INSTRUCCIONES DE PRUEBA:
1. Ejecutar DiskProtectorApp.exe como Administrador
2. Seleccionar los discos a proteger/desproteger
3. Click en el botón correspondiente
4. Esperar confirmación de la operación
5. Verificar que los botones se activen/desactiven correctamente
6. Verificar que el estado de los discos se actualice después de cada operación

REGISTRO DE OPERACIONES:
• Todas las operaciones se registran en:
• %APPDATA%\DiskProtectorApp\app-debug.log
• %APPDATA%\DiskProtectorApp\operations.log
• Se conservan los últimos 30 días de registros

FUNCIONAMIENTO ESPERADO:
• Botones de Proteger/Desproteger se activan/desactivan según selección
• Estado de los discos se actualiza automáticamente después de operaciones
• Administradores mantienen control total en todo momento
• Usuarios estándar pierden/ganan permisos según operación

 Versión de prueba: v$CURRENT_VERSION

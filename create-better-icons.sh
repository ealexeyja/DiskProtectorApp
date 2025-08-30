#!/bin/bash

# Crear directorio de recursos si no existe
mkdir -p src/DiskProtectorApp/Resources

# Crear un icono SVG de disco duro más realista en 3D
cat > src/DiskProtectorApp/Resources/disk-icon.svg << 'SVGDISKEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <!-- Sombra -->
  <ellipse cx="50" cy="85" rx="35" ry="5" fill="#222" opacity="0.3"/>
  
  <!-- Cuerpo principal del disco duro (efecto 3D) -->
  <rect x="15" y="25" width="70" height="50" rx="3" ry="3" fill="#4a4a4a"/>
  
  <!-- Bisel superior -->
  <path d="M15,25 L85,25 L85,30 L15,30 Z" fill="#5a5a5a"/>
  
  <!-- Bisel inferior -->
  <path d="M15,70 L85,70 L85,75 L15,75 Z" fill="#3a3a3a"/>
  
  <!-- Etiqueta del disco -->
  <rect x="20" y="30" width="60" height="15" rx="2" ry="2" fill="#666"/>
  
  <!-- Líneas de la etiqueta -->
  <line x1="25" y1="35" x2="55" y2="35" stroke="#ddd" stroke-width="1"/>
  <line x1="25" y1="39" x2="50" y2="39" stroke="#ddd" stroke-width="1"/>
  <line x1="25" y1="43" x2="45" y2="43" stroke="#ddd" stroke-width="1"/>
  
  <!-- Agujeros del disco -->
  <circle cx="75" cy="35" r="2" fill="#333"/>
  <circle cx="75" cy="42" r="2" fill="#333"/>
  <circle cx="75" cy="49" r="2" fill="#333"/>
  
  <!-- Parte superior del disco (efecto 3D) -->
  <rect x="10" y="20" width="80" height="8" rx="2" ry="2" fill="#555"/>
  
  <!-- Conector superior -->
  <rect x="45" y="12" width="10" height="8" fill="#333"/>
  
  <!-- Línea divisoria -->
  <line x1="15" y1="55" x2="85" y2="55" stroke="#333" stroke-width="1"/>
  
  <!-- Detalles internos -->
  <circle cx="50" cy="62" r="6" fill="#333"/>
  <circle cx="50" cy="62" r="3" fill="#555"/>
  
  <!-- Efecto de brillo -->
  <ellipse cx="30" cy="35" rx="8" ry="3" fill="#fff" opacity="0.2"/>
</svg>
SVGDISKEOF

# Crear ícono protegido (verde) con disco duro
cat > src/DiskProtectorApp/Resources/shield-protected.svg << 'SVGSHIELDEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <!-- Escudo verde con efecto 3D -->
  <path d="M50,15 L85,30 L85,55 C85,75 70,85 50,90 C30,85 15,75 15,55 L15,30 Z" fill="#4CAF50" stroke="#2E7D32" stroke-width="2"/>
  
  <!-- Reflejo del escudo -->
  <path d="M50,15 L75,27 L75,50 C75,65 65,75 50,80 C35,75 25,65 25,50 L25,27 Z" fill="#66BB6A" opacity="0.3"/>
  
  <!-- Check mark -->
  <path d="M35,50 L45,60 L65,40" fill="none" stroke="white" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
  
  <!-- Disco duro pequeño en el centro -->
  <rect x="35" y="30" width="30" height="20" rx="2" fill="#4a4a4a"/>
  <rect x="37" y="32" width="26" height="5" fill="#666"/>
  <circle cx="60" cy="35" r="1" fill="#333"/>
  <circle cx="60" cy="38" r="1" fill="#333"/>
</svg>
SVGSHIELDEOF

# Crear ícono desprotegido (rojo) con disco duro
cat > src/DiskProtectorApp/Resources/shield-unprotected.svg << 'SVGSHIELDUNEOFF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <!-- Escudo rojo con efecto 3D -->
  <path d="M50,15 L85,30 L85,55 C85,75 70,85 50,90 C30,85 15,75 15,55 L15,30 Z" fill="#F44336" stroke="#D32F2F" stroke-width="2"/>
  
  <!-- Reflejo del escudo -->
  <path d="M50,15 L75,27 L75,50 C75,65 65,75 50,80 C35,75 25,65 25,50 L25,27 Z" fill="#EF5350" opacity="0.3"/>
  
  <!-- Línea diagonal (X) -->
  <line x1="35" y1="35" x2="65" y2="65" stroke="white" stroke-width="5" stroke-linecap="round"/>
  <line x1="65" y1="35" x2="35" y2="65" stroke="white" stroke-width="5" stroke-linecap="round"/>
  
  <!-- Disco duro pequeño en el centro -->
  <rect x="35" y="30" width="30" height="20" rx="2" fill="#4a4a4a"/>
  <rect x="37" y="32" width="26" height="5" fill="#666"/>
  <circle cx="60" cy="35" r="1" fill="#333"/>
  <circle cx="60" cy="38" r="1" fill="#333"/>
</svg>
SVGSHIELDUNEOFF

echo "Íconos mejorados creados exitosamente!"
echo "Se han creado los siguientes archivos:"
echo "- src/DiskProtectorApp/Resources/disk-icon.svg (disco duro 3D)"
echo "- src/DiskProtectorApp/Resources/shield-protected.svg (escudo verde con disco)"
echo "- src/DiskProtectorApp/Resources/shield-unprotected.svg (escudo rojo con disco)"
echo ""
echo "Para convertir los SVG a formatos utilizables por la aplicación:"
echo "1. Instala las herramientas necesarias:"
echo "   sudo apt-get install inkscape imagemagick"
echo ""
echo "2. Convierte los archivos:"
echo "   inkscape -w 256 -h 256 src/DiskProtectorApp/Resources/disk-icon.svg -o src/DiskProtectorApp/Resources/app.png"
echo "   convert src/DiskProtectorApp/Resources/app.png src/DiskProtectorApp/Resources/app.ico"
echo "   inkscape -w 32 -h 32 src/DiskProtectorApp/Resources/shield-protected.svg -o src/DiskProtectorApp/Resources/shield-protected.png"
echo "   inkscape -w 32 -h 32 src/DiskProtectorApp/Resources/shield-unprotected.svg -o src/DiskProtectorApp/Resources/shield-unprotected.png"
echo ""
echo "3. Limpia los archivos temporales:"
echo "   rm src/DiskProtectorApp/Resources/app.png"

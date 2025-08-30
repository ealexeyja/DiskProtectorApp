#!/bin/bash

# Crear directorio de recursos si no existe
mkdir -p src/DiskProtectorApp/Resources

# Crear un icono SVG sencillo de disco duro
cat > src/DiskProtectorApp/Resources/disk-icon.svg << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <!-- Cuerpo del disco duro -->
  <rect x="10" y="20" width="80" height="60" rx="5" ry="5" fill="#4a4a4a" stroke="#333" stroke-width="2"/>
  
  <!-- Etiqueta del disco -->
  <rect x="15" y="25" width="70" height="20" rx="3" ry="3" fill="#666"/>
  
  <!-- Líneas de la etiqueta -->
  <line x1="20" y1="30" x2="50" y2="30" stroke="#ddd" stroke-width="1"/>
  <line x1="20" y1="35" x2="45" y2="35" stroke="#ddd" stroke-width="1"/>
  <line x1="20" y1="40" x2="40" y2="40" stroke="#ddd" stroke-width="1"/>
  
  <!-- Agujeros del disco -->
  <circle cx="80" cy="30" r="3" fill="#333"/>
  <circle cx="80" cy="40" r="3" fill="#333"/>
  <circle cx="80" cy="50" r="3" fill="#333"/>
  
  <!-- Parte superior del disco -->
  <rect x="5" y="15" width="90" height="10" rx="2" ry="2" fill="#555" stroke="#333" stroke-width="1"/>
  
  <!-- Conector -->
  <rect x="40" y="5" width="20" height="10" fill="#333"/>
  
  <!-- Línea divisoria -->
  <line x1="10" y1="50" x2="90" y2="50" stroke="#333" stroke-width="1"/>
  
  <!-- Detalles internos -->
  <circle cx="50" cy="65" r="8" fill="#333"/>
  <circle cx="50" cy="65" r="5" fill="#555"/>
</svg>
SVGEOF

# Crear ícono protegido (verde)
cat > src/DiskProtectorApp/Resources/shield-protected.svg << 'SVGSHEILDEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <!-- Escudo verde -->
  <path d="M50,10 L80,25 L80,50 C80,70 65,85 50,90 C35,85 20,70 20,50 L20,25 Z" fill="#4CAF50" stroke="#2E7D32" stroke-width="2"/>
  
  <!-- Check mark -->
  <path d="M35,50 L45,60 L65,40" fill="none" stroke="white" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
  
  <!-- Disco duro pequeño en el centro -->
  <rect x="35" y="35" width="30" height="20" rx="2" fill="#4a4a4a"/>
  <rect x="37" y="37" width="26" height="5" fill="#666"/>
</svg>
SVGEOF

# Crear ícono desprotegido (rojo)
cat > src/DiskProtectorApp/Resources/shield-unprotected.svg << 'SVGSHIELDUNEOFF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <!-- Escudo rojo con línea diagonal -->
  <path d="M50,10 L80,25 L80,50 C80,70 65,85 50,90 C35,85 20,70 20,50 L20,25 Z" fill="#F44336" stroke="#D32F2F" stroke-width="2"/>
  
  <!-- Línea diagonal (X) -->
  <line x1="35" y1="35" x2="65" y2="65" stroke="white" stroke-width="5" stroke-linecap="round"/>
  <line x1="65" y1="35" x2="35" y2="65" stroke="white" stroke-width="5" stroke-linecap="round"/>
  
  <!-- Disco duro pequeño en el centro -->
  <rect x="35" y="35" width="30" height="20" rx="2" fill="#4a4a4a"/>
  <rect x="37" y="37" width="26" height="5" fill="#666"/>
</svg>
SVGSHIELDUNEOFF

# Actualizar el archivo del proyecto para incluir los recursos
cat > src/DiskProtectorApp/DiskProtectorApp.csproj << 'PROJECTEOF'
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows</TargetFramework>
    <Nullable>enable</Nullable>
    <UseWPF>true</UseWPF>
    <ApplicationManifest>app.manifest</ApplicationManifest>
    <PlatformTarget>x64</PlatformTarget>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <SelfContained>false</SelfContained>
    <ApplicationIcon>Resources\app.ico</ApplicationIcon>
    <AssemblyVersion>1.0.0</AssemblyVersion>
    <FileVersion>1.0.0</FileVersion>
    <Version>1.0.0</Version>
    <!-- Habilitar targeting de Windows en Linux -->
    <EnableWindowsTargeting>true</EnableWindowsTargeting>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="MahApps.Metro" Version="2.4.10" />
    <PackageReference Include="MahApps.Metro.IconPacks" Version="4.11.0" />
    <PackageReference Include="ControlzEx" Version="5.0.2" />
    <PackageReference Include="Microsoft.Xaml.Behaviors.Wpf" Version="1.1.77" />
    <PackageReference Include="System.Management" Version="8.0.0" />
  </ItemGroup>

  <ItemGroup>
    <None Remove="Resources\app.ico" />
    <None Remove="Resources\shield-protected.png" />
    <None Remove="Resources\shield-unprotected.png" />
  </ItemGroup>

  <ItemGroup>
    <Resource Include="Resources\app.ico" />
    <Resource Include="Resources\shield-protected.png" />
    <Resource Include="Resources\shield-unprotected.png" />
  </ItemGroup>

</Project>
PROJECTEOF

echo "Recursos gráficos creados exitosamente!"
echo "Se han creado los siguientes archivos:"
echo "- src/DiskProtectorApp/Resources/disk-icon.svg"
echo "- src/DiskProtectorApp/Resources/shield-protected.svg"
echo "- src/DiskProtectorApp/Resources/shield-unprotected.svg"
echo ""
echo "Para convertir los SVG a formatos utilizables por la aplicación, necesitas:"
echo "1. Convertir disk-icon.svg a app.ico (ícono de aplicación)"
echo "2. Convertir los archivos SVG a PNG"
echo ""
echo "Puedes usar herramientas online o comandos como:"
echo "- convert (de ImageMagick): convert -density 300 -background transparent disk-icon.svg app.ico"
echo "- Inkscape: inkscape -w 256 -h 256 disk-icon.svg -o app.png && convert app.png app.ico"

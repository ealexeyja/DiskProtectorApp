#!/bin/bash

# Crear directorio de recursos si no existe
mkdir -p src/DiskProtectorApp/Resources

# Crear un icono SVG de escudo profesional con efecto 3D
cat > src/DiskProtectorApp/Resources/app-icon.svg << 'SVGSHIELDEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <!-- Sombra -->
  <ellipse cx="50" cy="90" rx="30" ry="5" fill="#222" opacity="0.3"/>
  
  <!-- Escudo principal con efecto 3D -->
  <path d="M50,10 L85,25 L85,50 C85,70 70,85 50,90 C30,85 15,70 15,50 L15,25 Z" fill="#FF5722" stroke="#E64A19" stroke-width="2"/>
  
  <!-- Reflejo del escudo para efecto 3D -->
  <path d="M50,15 L75,27 L75,50 C75,65 65,78 50,82 C35,78 25,65 25,50 L25,27 Z" fill="#FF9800" opacity="0.4"/>
  
  <!-- Borde interior del escudo -->
  <path d="M50,20 L78,32 L78,50 C78,67 67,80 50,84 C33,80 22,67 22,50 L22,32 Z" fill="none" stroke="#FFF" stroke-width="1" opacity="0.7"/>
  
  <!-- Círculo central con candado -->
  <circle cx="50" cy="50" r="15" fill="#333" stroke="#222" stroke-width="1"/>
  
  <!-- Cuerpo del candado -->
  <rect x="45" y="45" width="10" height="8" rx="1" ry="1" fill="#FFD54F"/>
  
  <!-- Arco del candado -->
  <path d="M45,45 
           A5,5 0 1,1 55,45 
           L53,42 
           A3,3 0 1,0 47,42 
           Z" fill="#FFD54F"/>
  
  <!-- Detalle del candado -->
  <circle cx="50" cy="49" r="1" fill="#333"/>
  
  <!-- Líneas decorativas en el escudo -->
  <line x1="35" y1="30" x2="65" y2="30" stroke="#FFF" stroke-width="1" opacity="0.5"/>
  <line x1="30" y1="35" x2="70" y2="35" stroke="#FFF" stroke-width="1" opacity="0.3"/>
  <line x1="25" y1="40" x2="75" y2="40" stroke="#FFF" stroke-width="1" opacity="0.2"/>
</svg>
SVGSHIELDEOF

# Crear ícono protegido (verde) con check
cat > src/DiskProtectorApp/Resources/shield-protected.svg << 'SVGSHIELDEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <!-- Escudo verde con efecto 3D -->
  <path d="M50,15 L85,30 L85,55 C85,75 70,85 50,90 C30,85 15,75 15,55 L15,30 Z" fill="#4CAF50" stroke="#2E7D32" stroke-width="2"/>
  
  <!-- Reflejo del escudo -->
  <path d="M50,15 L75,27 L75,50 C75,65 65,75 50,80 C35,75 25,65 25,50 L25,27 Z" fill="#66BB6A" opacity="0.3"/>
  
  <!-- Check mark grande -->
  <path d="M30,50 L45,65 L70,35" fill="none" stroke="white" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
  
  <!-- Borde interior -->
  <path d="M50,20 L78,32 L78,55 C78,72 67,82 50,86 C33,82 22,72 22,55 L22,32 Z" fill="none" stroke="#FFF" stroke-width="1" opacity="0.5"/>
</svg>
SVGSHIELDEOF

# Crear ícono desprotegido (rojo) con X
cat > src/DiskProtectorApp/Resources/shield-unprotected.svg << 'SVGSHIELDUNEOFF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <!-- Escudo rojo con efecto 3D -->
  <path d="M50,15 L85,30 L85,55 C85,75 70,85 50,90 C30,85 15,75 15,55 L15,30 Z" fill="#F44336" stroke="#D32F2F" stroke-width="2"/>
  
  <!-- Reflejo del escudo -->
  <path d="M50,15 L75,27 L75,50 C75,65 65,75 50,80 C35,75 25,65 25,50 L25,27 Z" fill="#EF5350" opacity="0.3"/>
  
  <!-- Línea diagonal (X) gruesa -->
  <line x1="30" y1="35" x2="70" y2="65" stroke="white" stroke-width="8" stroke-linecap="round"/>
  <line x1="70" y1="35" x2="30" y2="65" stroke="white" stroke-width="8" stroke-linecap="round"/>
  
  <!-- Borde interior -->
  <path d="M50,20 L78,32 L78,55 C78,72 67,82 50,86 C33,82 22,72 22,55 L22,32 Z" fill="none" stroke="#FFF" stroke-width="1" opacity="0.5"/>
</svg>
SVGSHIELDUNEOFF

# Actualizar el archivo del proyecto para usar el nuevo icono
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

echo "Íconos de escudo creados exitosamente!"
echo "Se han creado los siguientes archivos:"
echo "- src/DiskProtectorApp/Resources/app-icon.svg (escudo naranja con candado)"
echo "- src/DiskProtectorApp/Resources/shield-protected.svg (escudo verde con check)"
echo "- src/DiskProtectorApp/Resources/shield-unprotected.svg (escudo rojo con X)"
echo ""
echo "Para convertir los SVG a formatos utilizables por la aplicación:"
echo "1. Instala las herramientas necesarias:"
echo "   sudo apt-get install inkscape imagemagick"
echo ""
echo "2. Convierte los archivos:"
echo "   inkscape -w 256 -h 256 src/DiskProtectorApp/Resources/app-icon.svg -o src/DiskProtectorApp/Resources/app.png"
echo "   convert src/DiskProtectorApp/Resources/app.png src/DiskProtectorApp/Resources/app.ico"
echo "   inkscape -w 32 -h 32 src/DiskProtectorApp/Resources/shield-protected.svg -o src/DiskProtectorApp/Resources/shield-protected.png"
echo "   inkscape -w 32 -h 32 src/DiskProtectorApp/Resources/shield-unprotected.svg -o src/DiskProtectorApp/Resources/shield-unprotected.png"
echo ""
echo "3. Limpia los archivos temporales:"
echo "   rm src/DiskProtectorApp/Resources/app.png"

#!/bin/bash

# Actualizar el archivo del proyecto para controlar idiomas
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
    
    <!-- Configuración de versionado completa -->
    <Version>1.0.9</Version>
    <AssemblyVersion>1.0.9.0</AssemblyVersion>
    <FileVersion>1.0.9.0</FileVersion>
    <InformationalVersion>1.0.9</InformationalVersion>
    
    <!-- Propiedades adicionales para el ejecutable -->
    <Product>DiskProtectorApp</Product>
    <AssemblyTitle>Disk Protector Application</AssemblyTitle>
    <AssemblyDescription>Aplicación para protección de discos mediante gestión de permisos NTFS</AssemblyDescription>
    <AssemblyCompany>Emigdio Alexey Jimenez Acosta</AssemblyCompany>
    <AssemblyCopyright>Copyright © Emigdio Alexey Jimenez Acosta 2024</AssemblyCopyright>
    <AssemblyTrademark></AssemblyTrademark>
    
    <!-- Controlar idiomas de recursos satélite -->
    <SatelliteResourceLanguages>en;es</SatelliteResourceLanguages>
    <GenerateSatelliteAssembliesForCoreLibraries>false</GenerateSatelliteAssembliesForCoreLibraries>
    
    <!-- Habilitar targeting de Windows en Linux -->
    <EnableWindowsTargeting>true</EnableWindowsTargeting>
    <!-- Configuración adicional para mejor diagnóstico -->
    <DebugType>portable</DebugType>
    <DebugSymbols>true</DebugSymbols>
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

echo "✅ Proyecto actualizado para incluir solo inglés y español"
echo "   Configuración aplicada:"
echo "   - <SatelliteResourceLanguages>en;es</SatelliteResourceLanguages>"
echo "   - <GenerateSatelliteAssembliesForCoreLibraries>false</GenerateSatelliteAssembliesForCoreLibraries>"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/DiskProtectorApp.csproj"
echo "2. git commit -m \"feat: Configurar solo idiomas en/es y organizar salida\""
echo "3. git push origin main"

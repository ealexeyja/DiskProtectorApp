#!/bin/bash

# Actualizar el archivo del proyecto para mejorar la configuración de versionado
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
    <Version>1.0.3</Version>
    <AssemblyVersion>1.0.3.0</AssemblyVersion>
    <FileVersion>1.0.3.0</FileVersion>
    <InformationalVersion>1.0.3</InformationalVersion>
    
    <!-- Propiedades adicionales para el ejecutable -->
    <Product>DiskProtectorApp</Product>
    <AssemblyTitle>Disk Protector Application</AssemblyTitle>
    <AssemblyDescription>Aplicación para protección de discos mediante gestión de permisos NTFS</AssemblyDescription>
    <AssemblyCompany>Emigdio Alexey Jimenez Acosta</AssemblyCompany>
    <AssemblyCopyright>Copyright © Emigdio Alexey Jimenez Acosta 2024</AssemblyCopyright>
    <AssemblyTrademark></AssemblyTrademark>
    
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

# Actualizar global.json a la última versión estable de .NET 8
cat > global.json << 'GLOBALJSONEOF'
{
  "sdk": {
    "version": "8.0.400",
    "rollForward": "latestFeature"
  }
}
GLOBALJSONEOF

echo "Preparación para release v1.0.3 completada!"
echo "Cambios realizados:"
echo "1. Actualizada la versión a 1.0.3 en todos los campos"
echo "2. Agregadas propiedades completas de ensamblado"
echo "3. Mantenida la configuración de debugging para diagnóstico"
echo "4. Actualizado global.json a .NET 8.0.400"
echo ""
echo "Para crear la release v1.0.3:"
echo "1. git add src/DiskProtectorApp/DiskProtectorApp.csproj global.json"
echo "2. git commit -m \"feat: Preparar release v1.0.3 con versionado mejorado\""
echo "3. git push origin main"
echo "4. git tag -a v1.0.3 -m \"Release v1.0.3 - Versionado mejorado\""
echo "5. git push origin v1.0.3"
echo ""
echo "Después de que el pipeline se ejecute:"
echo "- El ejecutable tendrá la versión 1.0.3.0 en sus propiedades"
echo "- Se mostrará correctamente en el Administrador de Tareas"
echo "- La información de versión será visible en Propiedades del archivo"

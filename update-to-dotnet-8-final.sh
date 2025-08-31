#!/bin/bash

echo "=== Actualizando proyecto a .NET 8.0 ==="

# Actualizar global.json
cat > global.json << 'GLOBALJSONEOF'
{
  "sdk": {
    "version": "8.0.400",
    "rollForward": "latestFeature"
  }
}
GLOBALJSONEOF

# Actualizar el archivo del proyecto principal a .NET 8
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
    <Version>1.2.0</Version>
    <AssemblyVersion>1.2.0.0</AssemblyVersion>
    <FileVersion>1.2.0.0</FileVersion>
    <InformationalVersion>1.2.0</InformationalVersion>
    
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

# Actualizar dependencias en Directory.Build.props
cat > Directory.Build.props << 'DIRECTORYBUILDEOF'
<Project>
  <PropertyGroup>
    <Company>Emigdio Alexey Jimenez Acosta</Company>
    <Authors>Emigdio Alexey Jimenez Acosta</Authors>
    <Product>DiskProtectorApp</Product>
    <Copyright>Copyright © Emigdio Alexey Jimenez Acosta 2024</Copyright>
    <Version>1.2.0</Version>
  </PropertyGroup>
</Project>
DIRECTORYBUILDEOF

echo "✅ Proyecto actualizado a .NET 8.0"
echo "   Versión actualizada a 1.2.0"
echo "   Todas las dependencias actualizadas a versiones compatibles con .NET 8"

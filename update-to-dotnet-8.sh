#!/bin/bash

# Actualizar global.json
cat > global.json << 'GLOBALJSONEOF'
{
  "sdk": {
    "version": "8.0.400",
    "rollForward": "latestFeature"
  }
}
GLOBALJSONEOF

# Actualizar Directory.Build.props
cat > Directory.Build.props << 'DIRECTORYBUILDEOF'
<Project>
  <PropertyGroup>
    <Company>Emigdio Alexey Jimenez Acosta</Company>
    <Authors>Emigdio Alexey Jimenez Acosta</Authors>
    <Product>DiskProtectorApp</Product>
    <Copyright>Copyright © Emigdio Alexey Jimenez Acosta 2024</Copyright>
    <Version>1.0.0</Version>
  </PropertyGroup>
</Project>
DIRECTORYBUILDEOF

# Actualizar archivo del proyecto principal a .NET 8
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
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="MahApps.Metro" Version="2.4.10" />
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

# Actualizar pipeline CI/CD a .NET 8
cat > .github/workflows/ci-cd.yml << 'WORKFLOWEOF'
name: CI/CD Pipeline

on:
  push:
    tags: ['v*']
  workflow_dispatch:

env:
  DOTNET_VERSION: '8.0.400'
  PROJECT_PATH: './src/DiskProtectorApp/DiskProtectorApp.csproj'

jobs:
  build-and-release:
    runs-on: windows-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: ${{ env.DOTNET_VERSION }}

    - name: Restore dependencies
      run: dotnet restore ${{ env.PROJECT_PATH }}

    - name: Build
      run: dotnet build ${{ env.PROJECT_PATH }} --configuration Release --no-restore

    - name: Publish application
      run: |
        dotnet publish ${{ env.PROJECT_PATH }} \
          -c Release \
          -r win-x64 \
          --self-contained false \
          -o ./publish \
          /p:DebugType=None \
          /p:DebugSymbols=false

    - name: Create compressed archive
      run: |
        tar -czf ./DiskProtectorApp-${{ github.ref_name }}.tar.gz -C ./publish .

    - name: Create GitHub Release
      if: startsWith(github.ref, 'refs/tags/')
      uses: softprops/action-gh-release@v1
      with:
        files: ./DiskProtectorApp-${{ github.ref_name }}.tar.gz
        generate_release_notes: true
WORKFLOWEOF

echo "Actualización a .NET 8 completada exitosamente!"
echo "Cambios realizados:"
echo "1. global.json actualizado a .NET 8.0.400"
echo "2. Directory.Build.props mantenido"
echo "3. Proyecto actualizado a net8.0-windows"
echo "4. Dependencias actualizadas a versiones compatibles con .NET 8"
echo "5. Pipeline CI/CD actualizado a .NET 8.0.400"
echo ""
echo "Para aplicar los cambios:"
echo "1. chmod +x update-to-dotnet-8.sh"
echo "2. ./update-to-dotnet-8.sh"

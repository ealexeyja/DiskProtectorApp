#!/bin/bash

echo "=== Configurando GitHub Actions Workflow ==="

# Verificar si ya existe un workflow
if [ -f ".github/workflows/ci-cd.yml" ]; then
    echo "⚠️  Ya existe un workflow en .github/workflows/ci-cd.yml"
    echo "📊 Contenido actual:"
    cat .github/workflows/ci-cd.yml
    echo ""
    echo "❓ ¿Deseas actualizarlo? (s/n)"
    read -r respuesta
    if [[ ! "$respuesta" =~ ^[Ss]$ ]]; then
        echo "💡 Para ejecutar manualmente el workflow existente:"
        echo "   1. Ve a tu repositorio en GitHub"
        echo "   2. Navega a Actions"
        echo "   3. Selecciona el workflow y haz clic en 'Run workflow'"
        exit 0
    fi
fi

# Crear o actualizar el workflow de GitHub Actions
mkdir -p .github/workflows

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
        dotnet publish ${{ env.PROJECT_PATH }} -c Release -r win-x64 --self-contained false -o ./publish /p:DebugType=None /p:DebugSymbols=false

    - name: Organize files
      run: |
        mkdir -p ./DiskProtectorApp-release/{libs,locales,config}
        cp ./publish/DiskProtectorApp.exe ./DiskProtectorApp-release/
        mv ./publish/*.dll ./DiskProtectorApp-release/libs/ 2>/dev/null || echo "No DLLs found"
        if (Test-Path "./publish/en") { mv ./publish/en ./DiskProtectorApp-release/locales/ }
        if (Test-Path "./publish/es") { mv ./publish/es ./DiskProtectorApp-release/locales/ }
        if (Test-Path "./publish/de") { Remove-Item -Recurse -Force ./publish/de }
        cp ./publish/*.json ./DiskProtectorApp-release/config/ 2>/dev/null || echo "No JSON files found"
        cp ./publish/*.config ./DiskProtectorApp-release/config/ 2>/dev/null || echo "No config files found"

    - name: Create compressed archive
      run: |
        tar -czf ./DiskProtectorApp-${{ github.ref_name }}.tar.gz -C ./DiskProtectorApp-release .

    - name: Create GitHub Release
      if: startsWith(github.ref, 'refs/tags/')
      uses: softprops/action-gh-release@v1
      with:
        files: ./DiskProtectorApp-${{ github.ref_name }}.tar.gz
        generate_release_notes: true
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
WORKFLOWEOF

echo "✅ Workflow de GitHub Actions creado/actualizado en .github/workflows/ci-cd.yml"

# Verificar si hay tags recientes que podrían activar el workflow
echo ""
echo "🔍 Verificando tags recientes:"
git tag --sort=-version:refname | head -5

echo ""
echo "📋 Para activar el workflow en GitHub:"
echo "1. git add .github/workflows/ci-cd.yml"
echo "2. git commit -m \"ci: Configurar workflow de GitHub Actions\""
echo "3. git push origin main"
echo "4. Para crear un nuevo release:"
echo "   git tag -a v1.1.1 -m \"Release v1.1.1\""  # Ajusta la versión según corresponda
echo "   git push origin v1.1.1"
echo ""
echo "💡 Alternativamente, puedes ejecutar el workflow manualmente:"
echo "   1. Ve a tu repositorio en GitHub"
echo "   2. Navega a Actions"
echo "   3. Selecciona 'CI/CD Pipeline'"
echo "   4. Haz clic en 'Run workflow'"

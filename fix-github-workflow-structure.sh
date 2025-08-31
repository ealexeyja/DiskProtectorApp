#!/bin/bash

echo "=== Corrigiendo estructura del workflow de GitHub Actions ==="

# Actualizar el workflow de GitHub Actions para usar la estructura correcta de .NET
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
    permissions:
      contents: write
      packages: write
    
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

    - name: Clean up German resources
      run: |
        if (Test-Path "./publish/de") {
          Remove-Item -Path "./publish/de" -Recurse -Force
          echo "Removed German resources"
        }

    - name: Create compressed archive
      run: |
        tar -czf ./DiskProtectorApp-${{ github.ref_name }}.tar.gz -C ./publish .

    - name: Create GitHub Release
      if: startsWith(github.ref, 'refs/tags/')
      uses: softprops/action-gh-release@v1
      with:
        files: ./DiskProtectorApp-${{ github.ref_name }}.tar.gz
        generate_release_notes: true
        draft: false
        prerelease: false
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
WORKFLOWEOF

echo "✅ Workflow de GitHub Actions corregido"
echo "   Cambios principales:"
echo "   - Simplificada la estructura de archivos"
echo "   - Se mantiene la estructura plana correcta para .NET"
echo "   - Eliminación automática de recursos alemanes"
echo "   - Permisos adecuados para crear releases"

echo ""
echo "Para aplicar los cambios:"
echo "1. git add .github/workflows/ci-cd.yml"
echo "2. git commit -m \"fix: Corregir estructura de archivos en workflow\""
echo "3. git push origin main"

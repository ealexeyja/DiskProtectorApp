#!/bin/bash

# Corregir el pipeline CI/CD con el comando dotnet publish correctamente formateado
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

echo "Pipeline corregido exitosamente!"
echo "Los cambios principales son:"
echo "1. Comando dotnet publish en una sola línea correctamente formateado"
echo "2. Uso de barras simples en lugar de barras invertidas"
echo "3. Mantenimiento de todas las funcionalidades originales"
echo ""
echo "Para aplicar los cambios y volver a intentar el release:"
echo "1. git add .github/workflows/ci-cd.yml"
echo "2. git commit -m \"fix: Corregir formato del comando dotnet publish en pipeline\""
echo "3. git push origin main"
echo "4. Crear un nuevo tag para disparar el pipeline:"
echo "   git tag -a v1.0.1 -m \"Release v1.0.1 con pipeline corregido\""
echo "   git push origin v1.0.1"

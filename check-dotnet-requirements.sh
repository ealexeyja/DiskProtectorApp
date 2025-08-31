#!/bin/bash

echo "=== Verificando requisitos de .NET ==="

# Verificar si .NET está instalado
echo "🔍 Verificando instalación de .NET..."
if command -v dotnet &> /dev/null; then
    echo "✅ .NET CLI encontrado"
    dotnet --version
    echo ""
    echo "📦 Runtimes instalados:"
    dotnet --list-runtimes
    echo ""
    echo "🛠️  SDKs instalados:"
    dotnet --list-sdks
else
    echo "❌ .NET CLI no encontrado"
    echo "   Debes instalar .NET 8.0 Desktop Runtime"
    echo "   Descarga desde: https://dotnet.microsoft.com/download/dotnet/8.0"
fi

echo ""
echo "💡 Para usuarios de Windows:"
echo "   1. Descarga e instala .NET 8.0 Desktop Runtime x64"
echo "   2. URL: https://dotnet.microsoft.com/download/dotnet/8.0"
echo "   3. Busca 'Run desktop apps' en la sección de Windows"

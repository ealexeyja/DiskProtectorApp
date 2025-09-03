#!/bin/bash

echo "=== Extrayendo estructura completa del proyecto ==="

# Crear directorio para los archivos extraídos
mkdir -p project-extraction

# 1. Generar árbol de directorios y archivos
echo "📂 Generando árbol de directorios y archivos..."
find . -type f -not -path "./project-extraction/*" -not -path "./.git/*" | sort > project-extraction/file-list.txt

# 2. Generar estructura detallada con tamaños
echo "📊 Generando estructura detallada con tamaños..."
ls -laR . > project-extraction/detailed-structure.txt 2>/dev/null || find . -type f -exec ls -la {} \; > project-extraction/detailed-structure.txt

# 3. Extraer contenido de archivos importantes
echo "📄 Extrayendo contenido de archivos importantes..."

# Extraer contenido de archivos .csproj
find . -name "*.csproj" -not -path "./project-extraction/*" | while read file; do
    echo "=== Contenido de $file ===" >> project-extraction/project-files-content.txt
    cat "$file" >> project-extraction/project-files-content.txt
    echo -e "\n\n" >> project-extraction/project-files-content.txt
done

# Extraer contenido de archivos .xaml
find . -name "*.xaml" -not -path "./project-extraction/*" | while read file; do
    echo "=== Contenido de $file ===" >> project-extraction/xaml-files-content.txt
    cat "$file" >> project-extraction/xaml-files-content.txt
    echo -e "\n\n" >> project-extraction/xaml-files-content.txt
done

# Extraer contenido de archivos .cs principales
find . -name "*.cs" -not -path "./project-extraction/*" | while read file; do
    echo "=== Contenido de $file ===" >> project-extraction/cs-files-content.txt
    cat "$file" >> project-extraction/cs-files-content.txt
    echo -e "\n\n" >> project-extraction/cs-files-content.txt
done

# 4. Generar resumen de la estructura
echo "📋 Generando resumen de la estructura..."
cat > project-extraction/structure-summary.txt << 'SUMMARYEOF'
=== ESTRUCTURA DEL PROYECTO DISKPROTECTORAPP ===

RESUMEN GENERAL:
$(find . -type d -not -path "./project-extraction/*" -not -path "./.git/*" | wc -l) directorios
$(find . -type f -not -path "./project-extraction/*" -not -path "./.git/*" | wc -l) archivos

CARPETAS PRINCIPALES:
$(find . -maxdepth 3 -type d -not -path "./project-extraction/*" -not -path "./.git/*" | grep -E "(src|Services|ViewModels|Views|Models)" | sort)

ARCHIVOS IMPORTANTES:
$(find . -name "*.csproj" -not -path "./project-extraction/*" | sort)
$(find . -name "*.xaml" -not -path "./project-extraction/*" | sort)
$(find . -name "*.cs" -not -path "./project-extraction/*" | grep -E "(Main|DiskService|ViewModel)" | sort)

ARCHIVOS DE CONFIGURACIÓN:
$(find . -name "*.json" -not -path "./project-extraction/*" | sort)
$(find . -name "*.config" -not -path "./project-extraction/*" | sort)
$(find . -name "*.manifest" -not -path "./project-extraction/*" | sort)

RECURSOS:
$(find . -name "*.ico" -not -path "./project-extraction/*" | sort)
$(find . -name "*.png" -not -path "./project-extraction/*" | sort)

SCRIPTS:
$(find . -name "*.sh" -not -path "./project-extraction/*" | sort)
SUMMARYEOF

# Completar el resumen con información real
echo "=== ESTRUCTURA DEL PROYECTO DISKPROTECTORAPP ===" > project-extraction/temp-summary.txt
echo "" >> project-extraction/temp-summary.txt
echo "RESUMEN GENERAL:" >> project-extraction/temp-summary.txt
echo "$(find . -type d -not -path "./project-extraction/*" -not -path "./.git/*" | wc -l) directorios" >> project-extraction/temp-summary.txt
echo "$(find . -type f -not -path "./project-extraction/*" -not -path "./.git/*" | wc -l) archivos" >> project-extraction/temp-summary.txt
echo "" >> project-extraction/temp-summary.txt
echo "CARPETAS PRINCIPALES:" >> project-extraction/temp-summary.txt
find . -maxdepth 3 -type d -not -path "./project-extraction/*" -not -path "./.git/*" | grep -E "(src|Services|ViewModels|Views|Models)" | sort >> project-extraction/temp-summary.txt
echo "" >> project-extraction/temp-summary.txt
echo "ARCHIVOS IMPORTANTES:" >> project-extraction/temp-summary.txt
find . -name "*.csproj" -not -path "./project-extraction/*" | sort >> project-extraction/temp-summary.txt
find . -name "*.xaml" -not -path "./project-extraction/*" | sort >> project-extraction/temp-summary.txt
find . -name "*.cs" -not -path "./project-extraction/*" | grep -E "(Main|DiskService|ViewModel)" | sort >> project-extraction/temp-summary.txt
echo "" >> project-extraction/temp-summary.txt
echo "ARCHIVOS DE CONFIGURACIÓN:" >> project-extraction/temp-summary.txt
find . -name "*.json" -not -path "./project-extraction/*" | sort >> project-extraction/temp-summary.txt
find . -name "*.config" -not -path "./project-extraction/*" | sort >> project-extraction/temp-summary.txt
find . -name "*.manifest" -not -path "./project-extraction/*" | sort >> project-extraction/temp-summary.txt
echo "" >> project-extraction/temp-summary.txt
echo "RECURSOS:" >> project-extraction/temp-summary.txt
find . -name "*.ico" -not -path "./project-extraction/*" | sort >> project-extraction/temp-summary.txt
find . -name "*.png" -not -path "./project-extraction/*" | sort >> project-extraction/temp-summary.txt
echo "" >> project-extraction/temp-summary.txt
echo "SCRIPTS:" >> project-extraction/temp-summary.txt
find . -name "*.sh" -not -path "./project-extraction/*" | sort >> project-extraction/temp-summary.txt

mv project-extraction/temp-summary.txt project-extraction/structure-summary.txt

# 5. Crear archivo comprimido con toda la extracción
echo "📦 Creando archivo comprimido con toda la extracción..."
tar -czf project-extraction-complete.tar.gz -C ./project-extraction .

echo ""
echo "✅ ¡Extracción completada exitosamente!"
echo "   Archivos generados en project-extraction/:"
echo "   - file-list.txt: Lista completa de archivos"
echo "   - detailed-structure.txt: Estructura detallada con tamaños"
echo "   - project-files-content.txt: Contenido de archivos .csproj"
echo "   - xaml-files-content.txt: Contenido de archivos .xaml"
echo "   - cs-files-content.txt: Contenido de archivos .cs"
echo "   - structure-summary.txt: Resumen de la estructura"
echo "   - project-extraction-complete.tar.gz: Archivo comprimido completo"
echo ""
echo "📊 Información del archivo comprimido:"
ls -lh project-extraction-complete.tar.gz
echo ""
echo "💡 Para descargar el archivo:"
echo "   - En Codespaces: Haz clic derecho en 'project-extraction-complete.tar.gz' y selecciona 'Download'"
echo "   - En terminal: scp usuario@servidor:/ruta/project-extraction-complete.tar.gz ."
echo ""
echo "📋 Contenido del archivo comprimido:"
tar -tzf project-extraction-complete.tar.gz | head -20
echo "   ... ($(tar -tzf project-extraction-complete.tar.gz | wc -l) archivos en total)"

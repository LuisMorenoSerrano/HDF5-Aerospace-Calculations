#!/bin/bash
# =============================================================================
# Script para configurar VS Code para desarrollo Fortran + HDF5
# =============================================================================

echo "🔧 Configurando VS Code para Fortran + HDF5..."

# Verificar que estamos en el directorio correcto
if [ ! -f "src/hdf5_utils.f90" ]; then
    echo "❌ ERROR: Este script debe ejecutarse desde el directorio raíz del proyecto"
    exit 1
fi

# Crear directorio build si no existe
mkdir -p build

# Compilar módulo hdf5_utils para generar .mod
echo "📦 Compilando módulo hdf5_utils..."
gfortran -O3 -Wall -I/usr/include/hdf5/serial -J./build -c src/hdf5_utils.f90 -o build/hdf5_utils.o

if [ $? -eq 0 ]; then
    echo "✅ Módulo hdf5_utils compilado correctamente"
else
    echo "❌ Error compilando módulo hdf5_utils"
    exit 1
fi

# Verificar ubicación de hdf5.mod
HDF5_MOD_PATH=""
for path in /usr/include/hdf5/serial /usr/local/include /opt/hdf5/include; do
    if [ -f "$path/hdf5.mod" ]; then
        HDF5_MOD_PATH="$path"
        break
    fi
done

if [ -z "$HDF5_MOD_PATH" ]; then
    echo "⚠️  ADVERTENCIA: No se encontró hdf5.mod en ubicaciones estándar"
    echo "   VS Code puede mostrar errores de 'use hdf5'"
else
    echo "✅ HDF5 module encontrado en: $HDF5_MOD_PATH"
fi

# Verificar que los archivos de configuración existen
if [ -f ".vscode/settings.json" ]; then
    echo "✅ Configuración VS Code encontrada"
else
    echo "⚠️  No se encontró configuración de VS Code"
fi

if [ -f ".fortlsrc" ]; then
    echo "✅ Configuración fortls encontrada"
else
    echo "⚠️  No se encontró configuración fortls"
fi

# Mostrar información para VS Code
echo ""
echo "📋 INFORMACIÓN PARA VS CODE:"
echo "================================"
echo "• Módulos Fortran en: ./build/"
echo "• HDF5 includes en: $HDF5_MOD_PATH"
echo "• Archivos fuente en: ./src/"
echo ""
echo "🚀 PASOS SIGUIENTES:"
echo "1. Reinicia VS Code para que tome la nueva configuración"
echo "2. Instala la extensión 'Modern Fortran' si no está instalada"
echo "3. Instala 'fortls' si no está instalado: pip install fortls"
echo "4. Los errores de 'use' deberían desaparecer"
echo ""
echo "🔧 Si sigues viendo errores:"
echo "• Presiona Ctrl+Shift+P y ejecuta 'Fortran: Restart Language Server'"
echo "• Verifica que fortls esté instalado: fortls --version"

# Verificar fortls
if command -v fortls &> /dev/null; then
    FORTLS_VERSION=$(fortls --version 2>/dev/null || echo "unknown")
    echo "✅ fortls instalado: $FORTLS_VERSION"
else
    echo "⚠️  fortls no instalado. Instala con: pip install fortls"
fi

echo ""
echo "✨ Configuración completada!"
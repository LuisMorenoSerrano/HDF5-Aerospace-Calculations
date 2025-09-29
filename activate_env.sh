#!/bin/bash
# =============================================================================
# Script de activación del entorno HDF5-Aerospace
# Uso: source activate_env.sh
# =============================================================================

# Verificar que estamos en el directorio correcto
if [ ! -f "src/hdf5_utils.f90" ]; then
    echo "❌ Error: Ejecuta este script desde el directorio raíz del proyecto"
    echo "   Directorio actual: $(pwd)"
    echo "   Esperado: .../HDF5_Tests/"
    return 1 2>/dev/null || exit 1
fi

# Cargar configuración del entorno
if [ -f ".envrc" ]; then
    source .envrc
    echo "✅ Configuración del proyecto cargada"
else
    echo "⚠️  Archivo .envrc no encontrado, configuración básica..."

    # Activación básica solo del entorno Python
    if [ -d "/home/lmoreno/.virtualenvs/general" ]; then
        source /home/lmoreno/.virtualenvs/general/bin/activate
        echo "🐍 Entorno virtual 'general' activado"
    fi
fi

# Mostrar estado
echo ""
echo "📋 ESTADO DEL ENTORNO:"
echo "   Directorio: $(basename $(pwd))"
echo "   Python: $(which python)"
echo "   Virtual Env: $VIRTUAL_ENV"
echo "   HDF5: $(pkg-config --modversion hdf5 2>/dev/null || echo 'detectar manualmente')"
echo ""
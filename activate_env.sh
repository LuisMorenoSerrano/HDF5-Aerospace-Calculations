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

    # Intentar activación con virtualenvwrapper (workon)
    if declare -f workon >/dev/null 2>&1; then
        # workon está disponible como función
        workon general 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "🐍 Entorno virtual 'general' activado con workon"
        else
            echo "⚠️  workon general falló, intentando activación directa..."
            if [ -d "/home/lmoreno/.virtualenvs/general" ]; then
                source /home/lmoreno/.virtualenvs/general/bin/activate
                echo "🐍 Entorno virtual 'general' activado directamente"
            fi
        fi
    else
        # Fallback: activación directa sin virtualenvwrapper
        echo "ℹ️  workon no disponible, usando activación directa..."
        if [ -d "/home/lmoreno/.virtualenvs/general" ]; then
            source /home/lmoreno/.virtualenvs/general/bin/activate
            echo "🐍 Entorno virtual 'general' activado directamente"
        else
            echo "❌ No se pudo activar entorno 'general'"
        fi
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
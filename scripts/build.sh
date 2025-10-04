#!/bin/bash
# =============================================================================
# Script de Compilación para Proyecto HDF5 Aeroespacial
# =============================================================================

set -e  # Salir en cualquier error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=============================================="
echo -e "    COMPILADOR PROYECTO HDF5 AEROESPACIAL"
echo -e "==============================================${NC}"

# Verificar dependencias
echo -e "${YELLOW}📦 Verificando dependencias...${NC}"

# Verificar gfortran
if ! command -v gfortran &> /dev/null; then
    echo -e "${RED}❌ ERROR: gfortran no encontrado${NC}"
    echo "Instala con: sudo apt-get install gfortran"
    exit 1
fi

# Verificar HDF5
if ! pkg-config --exists hdf5-fortran 2>/dev/null; then
    echo -e "${YELLOW}⚠️  HDF5-Fortran no encontrado via pkg-config${NC}"
    echo -e "${YELLOW}   Intentando encontrar manualmente...${NC}"

    # Buscar librerías HDF5
    HDF5_FOUND=false
    for path in /usr/lib/x86_64-linux-gnu /usr/local/lib /opt/hdf5/lib; do
        if [ -f "$path/libhdf5_fortran.so" ] || [ -f "$path/libhdf5_fortran.a" ]; then
            HDF5_FOUND=true
            HDF5_LIB_PATH="$path"
            break
        fi
    done

    # Buscar includes
    for path in /usr/include/hdf5/serial /usr/include /usr/local/include /opt/hdf5/include; do
        if [ -f "$path/hdf5.mod" ] || [ -f "$path/H5fortran_types.mod" ]; then
            HDF5_INC_PATH="$path"
            break
        fi
    done

    if [ "$HDF5_FOUND" = false ]; then
        echo -e "${RED}❌ ERROR: HDF5-Fortran no encontrado${NC}"
        echo "Instala con: sudo apt-get install libhdf5-dev libhdf5-fortran-102"
        echo "O en sistemas más nuevos: sudo apt-get install libhdf5-fortran-dev"
        exit 1
    fi
else
    echo -e "${GREEN}✅ HDF5-Fortran encontrado${NC}"
    HDF5_CFLAGS=$(pkg-config --cflags hdf5-fortran)
    HDF5_LIBS=$(pkg-config --libs hdf5-fortran)
fi

# Configurar flags de compilación
FFLAGS="-O3 -ffast-math -march=native -Wall -Wextra -std=f2008"
DEBUG_FLAGS="-g -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow"

# Detectar flags HDF5
if [ -n "$HDF5_CFLAGS" ]; then
    HDF5_FLAGS="$HDF5_CFLAGS $HDF5_LIBS"
else
    # Configuración manual para Ubuntu/Debian
    HDF5_FLAGS="-I/usr/include/hdf5/serial -lhdf5_serial_fortran -lhdf5_serial"
fi

echo -e "${GREEN}✅ Dependencias verificadas${NC}"

# Crear directorio build
echo -e "${YELLOW}📁 Creando directorios...${NC}"
mkdir -p build
mkdir -p results

# Función de compilación
compile_program() {
    local src_file=$1
    local exe_name=$2
    local description=$3

    echo -e "${BLUE}🔨 Compilando $description...${NC}"
    echo "   Origen: $src_file"
    echo "   Ejecutable: build/$exe_name"

    # Compilar módulos necesarios
    if [ ! -f "build/hdf5_utils.mod" ]; then
        echo "   📚 Compilando módulo hdf5_utils..."
        gfortran $FFLAGS $HDF5_FLAGS -J build -c src/hdf5_utils.f90 -o build/hdf5_utils.o
    fi

    if [ ! -f "build/config_reader.mod" ]; then
        echo "   📚 Compilando módulo config_reader..."
        gfortran $FFLAGS -J build -c src/config_reader.f90 -o build/config_reader.o
    fi

    # Compilar programa principal
    OBJECTS="build/hdf5_utils.o"
    if [ -f "build/config_reader.o" ]; then
        OBJECTS="$OBJECTS build/config_reader.o"
    fi

    gfortran $FFLAGS $HDF5_FLAGS -J build -I build \
        $OBJECTS src/$src_file -o build/$exe_name

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✅ Compilación exitosa${NC}"
    else
        echo -e "${RED}   ❌ Error en compilación${NC}"
        exit 1
    fi
}

# Compilar programas
echo -e "${YELLOW}🏗️  Compilando programas...${NC}"

compile_program "matrix_generator.f90" "matrix_generator" "Generador de Matrices"
compile_program "data_analyzer.f90" "data_analyzer" "Analizador de Datos"

# Hacer ejecutables los binarios
chmod +x build/*

# Verificar Python y dependencias
echo -e "${YELLOW}🐍 Verificando entorno Python...${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ ERROR: python3 no encontrado${NC}"
    exit 1
fi

# Verificar paquetes Python
python3 -c "import numpy, h5py, matplotlib, scipy" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Paquetes Python verificados${NC}"
else
    echo -e "${YELLOW}⚠️  Instalando paquetes Python...${NC}"
    pip3 install numpy h5py matplotlib scipy seaborn
fi

echo -e "${GREEN}=============================================="
echo -e "            COMPILACIÓN EXITOSA"
echo -e "==============================================${NC}"

echo -e "${BLUE}📋 Ejecutables creados:${NC}"
echo "   • build/matrix_generator  - Genera matrices aeroespaciales"
echo "   • build/data_analyzer     - Analiza datos HDF5"
echo "   • python/visualize_results.py - Visualización Python"

echo -e "${BLUE}🚀 Comandos de ejecución:${NC}"
echo "   1. ./build/matrix_generator"
echo "   2. ./build/data_analyzer"
echo "   3. python3 python/visualize_results.py"
echo "      o python3 python/visualize_results.py --modal"

echo -e "${BLUE}📊 Archivos de salida:${NC}"
echo "   • results/structural_matrices.h5 - Datos HDF5"
echo "   • results/*.png - Gráficos de análisis"

echo -e "${GREEN}✨ Todo listo para cálculos masivos!${NC}"
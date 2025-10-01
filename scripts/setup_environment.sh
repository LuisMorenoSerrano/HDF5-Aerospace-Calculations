#!/bin/bash
# =============================================================================
# Script de Configuración del Entorno - Proyecto HDF5 Aeroespacial
# =============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=============================================="
echo -e "   CONFIGURACIÓN ENTORNO HDF5 AEROESPACIAL"
echo -e "==============================================${NC}"

# Detectar distribución Linux
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION=$VERSION_ID
else
    OS="Unknown"
fi

echo -e "${YELLOW}Sistema detectado: $OS${NC}"

# Función para instalar en Ubuntu/Debian
install_ubuntu_debian() {
    echo -e "${YELLOW}📦 Instalando dependencias Ubuntu/Debian...${NC}"

    sudo apt-get update

    # Compiladores y herramientas
    sudo apt-get install -y build-essential gfortran pkg-config

    # HDF5 (intentar diferentes versiones)
    if sudo apt-get install -y libhdf5-dev libhdf5-fortran-dev; then
        echo -e "${GREEN}✅ HDF5 instalado (versión nueva)${NC}"
    elif sudo apt-get install -y libhdf5-dev libhdf5-fortran-102; then
        echo -e "${GREEN}✅ HDF5 instalado (versión clásica)${NC}"
    else
        echo -e "${RED}❌ Error instalando HDF5${NC}"
        return 1
    fi

    # Python y pip
    sudo apt-get install -y python3 python3-pip python3-dev

    # Paquetes Python científicos
    pip3 install --user numpy scipy matplotlib h5py seaborn pandas
}

# Función para instalar en CentOS/RHEL/Fedora
install_redhat() {
    echo -e "${YELLOW}📦 Instalando dependencias RedHat/CentOS/Fedora...${NC}"

    if command -v dnf &> /dev/null; then
        PKG_MANAGER="sudo dnf install -y"
    else
        PKG_MANAGER="sudo yum install -y"
    fi

    $PKG_MANAGER gcc-gfortran pkgconfig hdf5-devel python3 python3-pip

    # En CentOS/RHEL puede necesitar EPEL
    if [[ "$OS" =~ "CentOS" ]] || [[ "$OS" =~ "Red Hat" ]]; then
        sudo yum install -y epel-release
    fi

    pip3 install --user numpy scipy matplotlib h5py seaborn pandas
}

# Función para instalar en Arch Linux
install_arch() {
    echo -e "${YELLOW}📦 Instalando dependencias Arch Linux...${NC}"

    sudo pacman -Sy gcc-fortran hdf5 python python-pip
    pip3 install --user numpy scipy matplotlib h5py seaborn pandas
}

# Instalación según la distribución
case "$OS" in
    *"Ubuntu"*|*"Debian"*)
        install_ubuntu_debian
        ;;
    *"CentOS"*|*"Red Hat"*|*"Fedora"*)
        install_redhat
        ;;
    *"Arch"*)
        install_arch
        ;;
    *)
        echo -e "${YELLOW}⚠️  Distribución no reconocida. Instalación manual:${NC}"
        echo "1. Instalar: gfortran, pkg-config"
        echo "2. Instalar: HDF5 development libraries"
        echo "3. Instalar: python3, pip3"
        echo "4. pip3 install numpy scipy matplotlib h5py seaborn"
        ;;
esac

# Verificar instalación
echo -e "${YELLOW}🔍 Verificando instalación...${NC}"

# Verificar gfortran
if command -v gfortran &> /dev/null; then
    GFORTRAN_VERSION=$(gfortran --version | head -1)
    echo -e "${GREEN}✅ gfortran: $GFORTRAN_VERSION${NC}"
else
    echo -e "${RED}❌ gfortran no encontrado${NC}"
    exit 1
fi

# Verificar HDF5
if pkg-config --exists hdf5-fortran; then
    HDF5_VERSION=$(pkg-config --modversion hdf5-fortran 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ HDF5-Fortran: $HDF5_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  HDF5-Fortran no encontrado via pkg-config${NC}"
    # Verificar manualmente
    if [ -f /usr/lib/x86_64-linux-gnu/libhdf5_fortran.so ] || [ -f /usr/local/lib/libhdf5_fortran.so ]; then
        echo -e "${GREEN}✅ HDF5-Fortran encontrado manualmente${NC}"
    else
        echo -e "${RED}❌ HDF5-Fortran no encontrado${NC}"
        exit 1
    fi
fi

# Verificar Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✅ Python: $PYTHON_VERSION${NC}"
else
    echo -e "${RED}❌ Python3 no encontrado${NC}"
    exit 1
fi

# Verificar paquetes Python
echo -e "${YELLOW}🐍 Verificando paquetes Python...${NC}"

PYTHON_PACKAGES=("numpy" "scipy" "matplotlib" "h5py" "seaborn")
for package in "${PYTHON_PACKAGES[@]}"; do
    if python3 -c "import $package" 2>/dev/null; then
        VERSION=$(python3 -c "import $package; print($package.__version__)" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}   ✅ $package: $VERSION${NC}"
    else
        echo -e "${RED}   ❌ $package no encontrado${NC}"
        echo -e "${YELLOW}   Instalando $package...${NC}"
        pip3 install --user $package
    fi
done

# Configurar variables de entorno
echo -e "${YELLOW}⚙️  Configurando variables de entorno...${NC}"

# Crear archivo de configuración local
cat > .env << EOF
# Configuración para proyecto HDF5 aeroespacial
export HDF5_ROOT=/usr
export HDF5_FORTRAN_LIBS="-lhdf5_fortran -lhdf5"
export PYTHONPATH=\$PYTHONPATH:$(pwd)/python
EOF

echo -e "${GREEN}✅ Archivo .env creado${NC}"

# Crear script de activación
cat > activate_env.sh << 'EOF'
#!/bin/bash
# Script para activar entorno del proyecto
if [ -f .env ]; then
    source .env
    echo "✅ Entorno activado"
    echo "Para compilar: ./scripts/build.sh o make all"
else
    echo "❌ Archivo .env no encontrado"
fi
EOF

chmod +x activate_env.sh

# Test rápido de compilación
echo -e "${YELLOW}🧪 Test rápido de compilación...${NC}"

# Crear programa de test mínimo
mkdir -p test_build
cat > test_build/test_hdf5.f90 << 'EOF'
program test_hdf5
    use hdf5
    implicit none

    integer :: error

    write(*,*) 'Inicializando HDF5...'
    call h5open_f(error)

    if (error == 0) then
        write(*,*) '✅ HDF5 funciona correctamente'
        call h5close_f(error)
    else
        write(*,*) '❌ Error en HDF5'
        stop 1
    endif
end program test_hdf5
EOF

# Compilar test
if pkg-config --exists hdf5-fortran; then
    HDF5_FLAGS=$(pkg-config --cflags --libs hdf5-fortran)
else
    HDF5_FLAGS="-lhdf5_fortran -lhdf5"
fi

if gfortran -o test_build/test_hdf5 test_build/test_hdf5.f90 $HDF5_FLAGS 2>/dev/null; then
    echo -e "${GREEN}✅ Compilación de test exitosa${NC}"

    # Ejecutar test
    if ./test_build/test_hdf5; then
        echo -e "${GREEN}✅ Test de HDF5 exitoso${NC}"
    else
        echo -e "${RED}❌ Error ejecutando test HDF5${NC}"
    fi
else
    echo -e "${RED}❌ Error en compilación de test${NC}"
    echo "Flags usados: $HDF5_FLAGS"
fi

# Limpiar test
rm -rf test_build

echo -e "${GREEN}=============================================="
echo -e "         CONFIGURACIÓN COMPLETADA"
echo -e "==============================================${NC}"

echo -e "${BLUE}📋 Resumen de la instalación:${NC}"
echo "   • Compilador Fortran: $(which gfortran)"
echo "   • HDF5: Instalado"
echo "   • Python: $(which python3)"
echo "   • Paquetes Python: Instalados"

echo -e "${BLUE}🚀 Próximos pasos:${NC}"
echo "   1. git checkout openmp       # Usar rama optimizada (recomendado)"
echo "   2. source activate_env.sh    # Activar entorno"
echo "   3. ./scripts/build.sh        # Compilar proyecto"
echo "   4. make test                 # Ejecutar test completo (~28s)"

echo -e "${YELLOW}💡 Nota: OpenMP incluido por defecto en gfortran moderno${NC}"
echo -e "${GREEN}✨ ¡Listo para cálculos masivos aeroespaciales con paralelización!${NC}"
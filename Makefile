# =============================================================================
# Makefile para Proyecto HDF5 Aeroespacial
# =============================================================================

# Configuración del compilador
FC = gfortran
FFLAGS = -O3 -ffast-math -march=native -Wall -Wextra -std=f2008
DEBUG_FLAGS = -g -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow

# Detectar HDF5 (usando versión serial de Ubuntu)
HDF5_CFLAGS := -I/usr/include/hdf5/serial
HDF5_LIBS := -L/usr/lib/x86_64-linux-gnu -lhdf5_serial_fortran -lhdf5_serial

# Directorios
SRCDIR = src
BUILDDIR = build
MODDIR = $(BUILDDIR)
PYTHONDIR = python
RESULTSDIR = results

# Archivos fuente
SOURCES = hdf5_utils.f90 matrix_generator.f90 data_analyzer.f90 data_analyzer_efficient.f90
OBJECTS = $(patsubst %.f90,$(BUILDDIR)/%.o,$(SOURCES))
MODULES = $(BUILDDIR)/hdf5_utils.mod

# Ejecutables
EXECUTABLES = $(BUILDDIR)/matrix_generator $(BUILDDIR)/data_analyzer $(BUILDDIR)/data_analyzer_efficient

# Regla por defecto
.PHONY: all clean debug install test help

all: directories $(EXECUTABLES)
	@echo "✅ Compilación completa"
	@echo "Ejecuta: make test"

# Crear directorios
directories:
	@mkdir -p $(BUILDDIR) $(RESULTSDIR)

# Compilar módulo HDF5_utils
$(BUILDDIR)/hdf5_utils.o $(BUILDDIR)/hdf5_utils.mod: $(SRCDIR)/hdf5_utils.f90 | directories
	@echo "🔨 Compilando módulo hdf5_utils..."
	$(FC) $(FFLAGS) $(HDF5_CFLAGS) -J$(MODDIR) -c $< -o $@

# Compilar generador de matrices
$(BUILDDIR)/matrix_generator: $(SRCDIR)/matrix_generator.f90 $(BUILDDIR)/hdf5_utils.o | directories
	@echo "🔨 Compilando matrix_generator..."
	$(FC) $(FFLAGS) $(HDF5_CFLAGS) -I$(MODDIR) -J$(MODDIR) \
		$(BUILDDIR)/hdf5_utils.o $< -o $@ $(HDF5_LIBS)

# Compilar analizador de datos
$(BUILDDIR)/data_analyzer: $(SRCDIR)/data_analyzer.f90 $(BUILDDIR)/hdf5_utils.o | directories
	@echo "🔨 Compilando data_analyzer..."
	$(FC) $(FFLAGS) $(HDF5_CFLAGS) -I$(MODDIR) -J$(MODDIR) \
		$(BUILDDIR)/hdf5_utils.o $< -o $@ $(HDF5_LIBS)

# Compilar analizador de datos eficiente
$(BUILDDIR)/data_analyzer_efficient: $(SRCDIR)/data_analyzer_efficient.f90 $(BUILDDIR)/hdf5_utils.o | directories
	@echo "🔨 Compilando data_analyzer_efficient..."
	$(FC) $(FFLAGS) $(HDF5_CFLAGS) -I$(MODDIR) -J$(MODDIR) \
		$(BUILDDIR)/hdf5_utils.o $< -o $@ $(HDF5_LIBS)

# Compilación con debug
debug: FFLAGS += $(DEBUG_FLAGS)
debug: all

# Instalar dependencias Python
install:
	@echo "📦 Instalando dependencias Python..."
	pip3 install --user numpy h5py matplotlib scipy seaborn
	@chmod +x $(PYTHONDIR)/visualize_results.py

# Ejecutar test completo
test: all install
	@echo "🧪 Ejecutando test completo..."
	@echo "1️⃣  Generando matrices..."
	./$(BUILDDIR)/matrix_generator
	@echo "2️⃣  Analizando datos..."
	./$(BUILDDIR)/data_analyzer
	@echo "3️⃣  Generando visualizaciones..."
	python3 $(PYTHONDIR)/visualize_results.py
	@echo "✅ Test completado. Ver archivos en $(RESULTSDIR)/"

# Test rápido sin visualización
test-quick: all
	@echo "⚡ Test rápido..."
	./$(BUILDDIR)/matrix_generator
	./$(BUILDDIR)/data_analyzer_efficient

# Benchmark de rendimiento
benchmark: all
	@echo "📊 Ejecutando benchmark..."
	@echo "Midiendo tiempo de generación..."
	time ./$(BUILDDIR)/matrix_generator
	@echo "Midiendo tiempo de análisis..."
	time ./$(BUILDDIR)/data_analyzer
	@ls -lah $(RESULTSDIR)/structural_matrices.h5

# Limpiar archivos compilados
clean:
	@echo "🧹 Limpiando archivos compilados..."
	rm -rf $(BUILDDIR)/*
	rm -f $(RESULTSDIR)/*.h5

# Limpiar todo (incluyendo resultados)
clean-all: clean
	@echo "🧹 Limpiando todos los resultados..."
	rm -f $(RESULTSDIR)/*.png

# Verificar dependencias
check-deps:
	@echo "🔍 Verificando dependencias..."
	@which gfortran > /dev/null && echo "✅ gfortran encontrado" || echo "❌ gfortran no encontrado"
	@pkg-config --exists hdf5-fortran && echo "✅ HDF5-Fortran encontrado" || echo "⚠️  HDF5-Fortran no encontrado via pkg-config"
	@which python3 > /dev/null && echo "✅ python3 encontrado" || echo "❌ python3 no encontrado"
	@python3 -c "import numpy, h5py, matplotlib" 2>/dev/null && echo "✅ Paquetes Python OK" || echo "⚠️  Instala paquetes Python"

# Ayuda
help:
	@echo "🚀 MAKEFILE PROYECTO HDF5 AEROESPACIAL"
	@echo "========================================"
	@echo ""
	@echo "Objetivos disponibles:"
	@echo "  all          - Compilar todos los programas"
	@echo "  debug        - Compilar con flags de debug"
	@echo "  install      - Instalar dependencias Python"
	@echo "  test         - Ejecutar test completo con visualización"
	@echo "  test-quick   - Test rápido sin visualización"
	@echo "  benchmark    - Medir rendimiento"
	@echo "  clean        - Limpiar archivos compilados"
	@echo "  clean-all    - Limpiar todo (incluyendo resultados)"
	@echo "  check-deps   - Verificar dependencias"
	@echo "  help         - Mostrar esta ayuda"
	@echo ""
	@echo "Ejemplo de uso:"
	@echo "  make all && make test"
	@echo ""
	@echo "Para matrices más grandes, edita los parámetros en src/matrix_generator.f90"

# Mostrar información del sistema
info:
	@echo "ℹ️  INFORMACIÓN DEL SISTEMA"
	@echo "=========================="
	@echo "Compilador: $(FC) $(shell $(FC) --version | head -1)"
	@echo "Flags: $(FFLAGS)"
	@echo "HDF5 CFLAGS: $(HDF5_CFLAGS)"
	@echo "HDF5 LIBS: $(HDF5_LIBS)"
	@echo "Directorio build: $(BUILDDIR)"
	@echo "Directorio resultados: $(RESULTSDIR)"
#!/bin/bash
# =============================================================================
# Script de configuración del entorno OpenMP + HDF5 optimizado para NVMe
# =============================================================================

# Configuración OpenMP optimizada
export OMP_NUM_THREADS=16
export OMP_SCHEDULE=dynamic
export OMP_PROC_BIND=false

# Desactivar verbose OpenMP (para producción)
unset OMP_DISPLAY_ENV

echo "🚀 ENTORNO OPTIMIZADO CONFIGURADO:"
echo "================================="
echo "OpenMP threads: $OMP_NUM_THREADS"
echo "Scheduling: $OMP_SCHEDULE"
echo "Sistema: $(nproc) núcleos disponibles"
echo "Memoria: $(free -h | grep Mem | awk '{print $7}') disponible"
echo ""
echo "Configuración HDF5:"
echo "- Sin compresión (máximo rendimiento)"
echo "- Chunks 2048x2048 (optimizado NVMe)"
echo "- Matrices hasta 6000 nodos (36k DOF)"
echo ""
echo "Comandos disponibles:"
echo "  make openmp     - Compilar versión OpenMP"
echo "  make benchmark  - Comparar OpenMP vs serial"
echo "  ./build/matrix_generator_omp - Ejecutar optimizado"
echo ""
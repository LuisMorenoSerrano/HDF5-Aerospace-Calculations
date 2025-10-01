#!/bin/bash
# =============================================================================
# Benchmark OpenMP Performance - Comparación Serial vs Paralelo
# =============================================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variable para calcular speedup
BASELINE_TIME=""

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}   BENCHMARK OPENMP vs SERIAL - HDF5 AEROSPACE CALCULATIONS${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Verificar que los ejecutables existan
if [ ! -f "build/matrix_generator" ] || [ ! -f "build/matrix_generator_omp" ]; then
    echo -e "${RED}❌ ERROR: Ejecutables no encontrados. Ejecuta 'make all && make openmp'${NC}"
    exit 1
fi

# Verificar que bc esté instalado para cálculos
if ! command -v bc &> /dev/null; then
    echo -e "${YELLOW}⚠️  Instalando bc para cálculos de speedup...${NC}"
    sudo apt-get update && sudo apt-get install -y bc
fi

# Función para ejecutar benchmark
run_benchmark() {
    local config_file=$1
    local threads=$2
    local description=$3
    
    echo -e "${YELLOW}🔹 $description${NC}"
    echo -e "   Config: $config_file"
    echo -e "   Threads: $threads"
    
    # Modificar configuración de threads
    sed -i "s/num_threads = .*/num_threads = $threads/" "$config_file"
    
    # Ejecutar modo benchmark (sin I/O) y capturar tiempo
    echo -n "   Ejecutando... "
    local result=$(./build/matrix_generator_omp --benchmark 2>&1 | grep "Tiempo total generación" | grep -o "[0-9.]*")
    echo -e "${GREEN}${result}s${NC}"
    
    # Calcular speedup si es el primer resultado
    if [ "$threads" -eq 1 ]; then
        BASELINE_TIME=$result
    else
        local speedup=$(echo "scale=2; $BASELINE_TIME / $result" | bc -l)
        echo -e "   ${BLUE}Speedup: ${speedup}x${NC}"
    fi
    
    return 0
}

# Benchmark con diferentes configuraciones
echo -e "${YELLOW}📊 BENCHMARK MATRIZ PEQUEÑA (6k DOF)${NC}"
echo "=================================="

run_benchmark "config/benchmark_params.conf" 1 "Serial (1 thread)"
run_benchmark "config/benchmark_params.conf" 2 "OpenMP (2 threads)"
run_benchmark "config/benchmark_params.conf" 4 "OpenMP (4 threads)"

echo ""
echo -e "${YELLOW}📊 BENCHMARK MATRIZ MEDIANA (30k DOF)${NC}"
echo "=================================="

# Cambiar a configuración más grande
sed -i "s/n_nodes = .*/n_nodes = 5000/" config/benchmark_params.conf

# Reset baseline time for new configuration
BASELINE_TIME=""

run_benchmark "config/benchmark_params.conf" 1 "Serial (1 thread)"
run_benchmark "config/benchmark_params.conf" 2 "OpenMP (2 threads)"
run_benchmark "config/benchmark_params.conf" 4 "OpenMP (4 threads)"

# Restaurar configuración original
sed -i "s/n_nodes = .*/n_nodes = 1000/" config/benchmark_params.conf

echo ""
echo -e "${GREEN}✅ Benchmark completado${NC}"
echo -e "${BLUE}💡 Nota: Los tiempos mostrados son solo de generación de matrices (sin I/O)${NC}"
echo -e "${BLUE}💡 Speedup calculado respecto al caso serial (1 thread)${NC}"
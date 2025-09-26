# Copilot Instructions - HDF5 Aeroespacial

## Arquitectura del Proyecto

Este es un proyecto de **cálculos masivos aeroespaciales** usando **Fortran + HDF5** para:
- Análisis estructural de elementos finitos (matrices de rigidez/masa grandes)
- Almacenamiento eficiente de datos con compresión HDF5
- Visualización con Python/matplotlib

### Componentes Principales

1. **`src/hdf5_utils.f90`** - Módulo base con utilidades HDF5 optimizadas
2. **`src/matrix_generator.f90`** - Generador de matrices estructurales aeroespaciales
3. **`src/data_analyzer.f90`** - Analizador de datos HDF5 y cálculos post-proceso
4. **`python/visualize_results.py`** - Visualización avanzada con análisis modal
5. **`scripts/build.sh`** - Sistema de compilación con detección automática HDF5

## Convenciones Específicas del Proyecto

### Fortran
- **Módulos**: Usar `use hdf5_utils` para todas las operaciones HDF5
- **Precisión**: Siempre `real(8)` para cálculos científicos
- **Arrays**: Usar `allocatable` para matrices grandes, liberar memoria explícitamente
- **HDF5**: Siempre usar compresión `gzip` nivel 6, chunks optimizados para acceso

### Estructura de Datos HDF5
```
/matrices/stiffness     # Matriz de rigidez [N_DOF x N_DOF]
/matrices/mass          # Matriz de masa [N_DOF x N_DOF]
/vectors/force          # Vector fuerzas [N_DOF]
/results/displacement   # Resultados [N_DOF]
```

### Python
- **Importar siempre**: `numpy`, `h5py`, `matplotlib`, `scipy`
- **Matrices grandes**: Usar subsampling para visualización (>2000x2000)
- **Análisis modal**: `scipy.sparse.linalg.eigsh` para problemas generalizados

## Workflows Críticos

### Compilación
```bash
# Método recomendado
make check-deps && make all && make test

# O alternativo
./scripts/setup_environment.sh  # Solo primera vez
./scripts/build.sh
```

### Flujo de Cálculo Típico
1. **Generar matrices**: `./build/matrix_generator` → `results/structural_matrices.h5`
2. **Analizar**: `./build/data_analyzer` → estadísticas en consola
3. **Visualizar**: `python3 python/visualize_results.py --modal`

### Parámetros Aeroespaciales Típicos
- **Nodos FEM**: 10,000-100,000 (6 DOF/nodo = 60k-600k DOF)
- **Materiales**: Aluminio (E=70GPa, ρ=2700kg/m³), Titanio, Composites
- **Frecuencias**: 10-500 Hz típico para estructuras aeroespaciales
- **Desplazamientos**: Límite ~10mm para análisis lineal

## Patrones de Integración

### Manejo de Memoria Fortran
```fortran
! SIEMPRE verificar allocación/deallocación
allocate(matrix(n,n), stat=ierr)
if (ierr /= 0) stop 'Error allocation'
! ... usar matriz ...
deallocate(matrix)
```

### Escritura HDF5 Eficiente
```fortran
! Usar siempre el patrón del módulo hdf5_utils:
call write_matrix_real8(file_id, '/path/dataset', matrix)
! Automáticamente aplica: compresión, chunking, error handling
```

### Análisis de Rendimiento
- **Timing**: Usar `cpu_time()` para medir generación vs I/O
- **Memoria**: Matrices >1GB requieren procesamiento por bloques
- **I/O**: HDF5 comprimido ~3-5x más pequeño que binario raw

## Dependencias y Troubleshooting

### Instalación HDF5
- **Ubuntu**: `libhdf5-fortran-dev` (nuevo) o `libhdf5-fortran-102` (viejo)
- **Detección**: `pkg-config --exists hdf5-fortran`
- **Manual**: Buscar en `/usr/lib/x86_64-linux-gnu/libhdf5_fortran.*`

### Errores Comunes
1. **"Cannot open module hdf5.mod"**: Instalar `libhdf5-fortran-dev`
2. **Matrices muy grandes**: Aumentar memoria swap o usar procesamiento por bloques
3. **"No such file results/"**: Crear con `mkdir -p results`

## Testing y Validación

### Test Rápido
```bash
make test-quick  # Sin visualización (~30 seg)
```

### Test Completo
```bash
make test       # Con análisis modal y gráficos (~2 min)
```

### Benchmark
```bash
make benchmark  # Medir rendimiento + estadísticas archivo HDF5
```

Modificar parámetros en `src/matrix_generator.f90` líneas 8-10 para matrices más grandes.
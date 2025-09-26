# 🚀 HDF5 Aerospace Massive Calculations

![Fortran](https://img.shields.io/badge/Fortran-2008-734f96?style=flat-square&logo=fortran)
![HDF5](https://img.shields.io/badge/HDF5-1.10+-blue?style=flat-square)
![Python](https://img.shields.io/badge/Python-3.8+-3776ab?style=flat-square&logo=python)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-Linux-orange?style=flat-square&logo=linux)

> **High-performance Fortran + HDF5 framework for massive aerospace structural calculations with intelligent memory management and visualization**

Este proyecto demuestra el uso eficiente de HDF5 con Fortran para cálculos masivos en ingeniería aeroespacial, incluyendo:

- 🏗️ **Análisis estructural**: Matrices de rigidez/masa para elementos finitos (hasta 600k DOF)
- 💾 **Almacenamiento eficiente**: HDF5 con compresión (3-5x reducción de tamaño)
- 📊 **Visualización avanzada**: Python con análisis modal y gráficos técnicos
- 🚀 **Rendimiento optimizado**: Chunking, compresión y procesamiento paralelo

## 🏛️ Estructura del Proyecto

```text
├── src/                       # 💻 Código fuente Fortran
│   ├── hdf5_utils.f90         # 🔧 Módulo utilitarios HDF5
│   ├── matrix_generator.f90   # 🏗️ Generador matrices estructurales
│   └── data_analyzer.f90      # 📈 Analizador post-proceso
├── python/                    # 🐍 Scripts Python
│   ├── visualize_results.py   # 📊 Visualización avanzada
│   └── create_test_hdf5.py    # 🧪 Generador datos de prueba
├── scripts/                   # ⚙️ Automatización
│   ├── build.sh               # 🔨 Compilación automática
│   └── setup_environment.sh   # 📦 Configuración entorno
├── data/                      # 📁 Datos entrada/ejemplos
├── results/                   # 💾 Archivos HDF5 generados
└── build/                     # 🏗️ Archivos compilados
```

## 🚀 Inicio Rápido

### Configuración Automática

```bash
# Configurar entorno (solo primera vez)
./scripts/setup_environment.sh

# Activar entorno
source activate_env.sh

# Compilar todo
make all
```

### Test Completo

```bash
# Ejecutar ejemplo completo (~2 min)
make test

# O paso a paso:
./build/matrix_generator          # Generar matrices (30s)
./build/data_analyzer            # Analizar datos (10s)
python3 python/visualize_results.py --modal  # Visualizar (60s)
```

## 📊 Casos de Uso Aeroespaciales

### 1. Análisis Estructural FEM

- **Matrices**: Rigidez y masa para fuselaje/alas (10k-100k nodos)
- **Materiales**: Aluminio, titanio, composites
- **Solver**: Análisis modal, respuesta estática/dinámica

### 2. Optimización Multidisciplinar

- **Datos**: Múltiples configuraciones/iteraciones
- **Compresión**: HDF5 reduce 70-80% el almacenamiento
- **Paralelización**: Procesamiento distribuido de casos

### 3. Post-procesado Avanzado

- **Visualización**: Formas modales, distribuciones tensión/desplazamiento
- **Análisis**: Frecuencias naturales, factores seguridad
- **Reportes**: Automáticos con métricas aeroespaciales

## ⚙️ Configuración Avanzada

### Matrices Grandes

Editar `src/matrix_generator.f90`:

```fortran
integer, parameter :: n_nodes = 50000     ! Hasta 300k DOF
integer, parameter :: bandwidth = 100     ! Mayor acoplamiento
```

### Optimización HDF5

- **Chunking**: Automático según tamaño matriz
- **Compresión**: gzip nivel 6 (balance velocidad/tamaño)
- **Parallel I/O**: Preparado para MPI (futuro)

### Python Científico

```bash
# Paquetes adicionales
pip3 install --user vtk pyvista plotly dash
```

## 🔧 Troubleshooting

| Error | Solución |
|-------|----------|
| `Cannot open module hdf5.mod` | `sudo apt install libhdf5-fortran-dev` |
| `Memoria insuficiente` | Reducir `n_nodes` o aumentar swap |
| `results/ no existe` | `mkdir -p results` |
| `Python imports fallan` | `pip3 install numpy h5py matplotlib scipy` |

## 📈 Rendimiento

### Benchmarks Típicos (Intel i7, 16GB RAM)

- **Matrices 60k DOF**: Generación ~30s, I/O ~5s
- **Análisis modal**: 10 modos en ~15s
- **Compresión HDF5**: 70-80% reducción vs raw binary
- **Memoria pico**: ~8GB para matrices 100k DOF

### Escalabilidad

- ✅ **Hasta 100k nodos** (600k DOF): Funcional en workstation típica
- ⚠️ **Más de 200k nodos**: Requiere HPC o procesamiento por bloques
- 🚀 **Paralelización**: MPI-ready para clusters (implementación futura)

---

**🎯 Optimizado para**: Análisis estructural, CFD post-proceso, optimización multiobjetivo aeroespacial

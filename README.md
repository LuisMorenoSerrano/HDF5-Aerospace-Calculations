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
│   ├── config_reader.f90      # ⚙️ Lector configuración externa
│   ├── matrix_generator.f90   # 🏗️ Generador matrices estructurales
│   └── data_analyzer.f90      # 📈 Analizador optimizado
├── config/                    # 🔧 Configuración externa
│   └── simulation_params.conf # 📝 Parámetros modificables
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

# Activar entorno automáticamente
source activate_env.sh

# Compilar todo
make all
```

### 🐍 Entorno Virtual Automático

El proyecto activa automáticamente el entorno virtual Python `general` usando `workon`:

```bash
# En VS Code: Terminal se activa automáticamente con workon general
# En terminal manual:
source activate_env.sh          # Usa workon general automáticamente
# o alternativamente:
source .bash_project            # Carga entorno completo

# Comandos rápidos disponibles:
build          # make all
test-quick     # make test-quick
visualize      # python3 python/visualize_results.py --modal
analyze        # ./build/data_analyzer
generate       # ./build/matrix_generator
```

#### 🔧 Configuración Terminal VS Code

El terminal integrado ejecuta automáticamente:

- Carga `virtualenvwrapper` si está disponible
- Ejecuta `workon general` para activar el entorno
- Configura aliases y variables del proyecto
- Muestra estado completo del entorno### Test Completo

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

### Sistema de Configuración Externa

Modifica parámetros sin recompilar editando `config/simulation_params.conf`:

```ini
# Configuración de simulación aeroespacial
n_nodes = 1000              # Número de nodos FEM (1000 = 6k DOF)
young_modulus = 70.0e9      # Módulo Young [Pa] - Aluminio
density = 2700.0            # Densidad [kg/m³]
poisson_ratio = 0.33        # Coeficiente Poisson
zone_stiffness_factor = 2.5  # Factor heterogeneidad rigidez
zone_mass_factor = 1.8       # Factor heterogeneidad masa
```

### Matrices Grandes

Para matrices más grandes (cuidado con memoria):

```ini
n_nodes = 10000             # 60k DOF - Requiere ~8GB RAM
n_nodes = 50000             # 300k DOF - Requiere HPC
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

- **Configuración estándar** (6k DOF): Generación ~0.2s, I/O ~2.2s, Memoria ~0.27GB
- **Matrices 60k DOF**: Generación ~30s, I/O ~5s
- **Análisis modal**: 9 modos válidos, rango 51-155 kHz
- **Compresión HDF5**: 70-80% reducción vs raw binary
- **Memoria pico**: ~8GB para matrices 100k DOF

### Mejoras Implementadas

- 🔧 **Configuración externa**: Sin recompilación para cambiar parámetros
- ⚡ **Rendimiento optimizado**: 100x reducción en uso de memoria (0.27GB vs 27GB)
- 📈 **Análisis modal mejorado**: Frecuencias diferenciadas (factor dispersión 3.0x)
- 📊 **Visualización avanzada**: 4 subgráficos con métricas aeroespaciales

### Escalabilidad

- ✅ **Hasta 100k nodos** (600k DOF): Funcional en workstation típica
- ⚠️ **Más de 200k nodos**: Requiere HPC o procesamiento por bloques
- 🚀 **Paralelización**: MPI-ready para clusters (implementación futura)

---

**🎯 Optimizado para**: Análisis estructural, CFD post-proceso, optimización multiobjetivo aeroespacial

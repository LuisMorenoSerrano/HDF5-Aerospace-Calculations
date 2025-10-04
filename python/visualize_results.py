#!/usr/bin/env python3
"""
Visualizador de Datos HDF5 Aeroespaciales
Análisis y visualización de matrices y resultados de simulaciones estructurales
"""
import os
import argparse
from typing import Optional, Dict, Any

import numpy as np
import matplotlib.pyplot as plt

try:
    import seaborn as sns
    HAS_SEABORN = True
except ImportError:
    HAS_SEABORN = False
    print("ADVERTENCIA: seaborn no disponible. Usando matplotlib básico.")

try:
    import h5py
except ImportError:
    print("ERROR: h5py no está instalado. Instala con: pip install h5py")
    exit(1)

try:
    from scipy.sparse import csr_matrix
    from scipy.sparse.linalg import eigsh
except ImportError:
    print("ADVERTENCIA: scipy no está instalado. Análisis modal deshabilitado.")
    print("Instala con: pip install scipy")
    csr_matrix = None
    eigsh = None

# Configuración de estilo
if HAS_SEABORN:
    plt.style.use('seaborn-v0_8-darkgrid')
    sns.set_palette("husl")
else:
    plt.style.use('ggplot')

def load_dataset_with_subsampling(
    hdf5_file: h5py.File,
    dataset_path: str,
    max_size: int,
    is_vector: bool = False
) -> Optional[np.ndarray]:
    """Helper para cargar datasets con submuestreo automático"""
    if dataset_path not in hdf5_file:
        return None

    dataset = hdf5_file[dataset_path]
    if not isinstance(dataset, h5py.Dataset):
        print(f"   ⚠️ ERROR: {dataset_path} no es un dataset válido")
        return None

    n = dataset.shape[0]
    if n > max_size:
        step = n // max_size
        if is_vector:
            print(f"   📉 Submuestreando {dataset_path}: {n} → {max_size} (paso={step})")
            return dataset[::step]  # type: ignore
        else:
            print(f"   📉 Submuestreando {dataset_path}: {n}x{n} → "
                  f"{max_size}x{max_size} (paso={step})")
            return dataset[::step, ::step]  # type: ignore
    else:
        return dataset[:]  # type: ignore

def load_hdf5_data(filename: str, max_size: int = 5000) -> Optional[Dict[str, Any]]:
    """Cargar datos desde el archivo HDF5 con submuestreo automático para matrices grandes"""
    print(f"📁 Cargando datos desde: {filename}")

    if not os.path.exists(filename):
        print(f"❌ ERROR: El archivo {filename} no existe")
        print("   Ejecuta primero: ./build/matrix_generator")
        return None

    data = {}
    try:
        with h5py.File(filename, 'r') as f:
            print("📊 Datasets encontrados:")

            # Listar todos los datasets recursivamente
            def print_structure(name, obj):
                if isinstance(obj, h5py.Dataset):
                    print(f"   {name}: {obj.shape} {obj.dtype}")
            f.visititems(print_structure)

            # Cargar matrices con submuestreo inteligente
            stiffness = load_dataset_with_subsampling(
                f, '/matrices/stiffness', max_size, is_vector=False
            )
            if stiffness is not None:
                data['stiffness'] = stiffness
                print(f"   ✅ Matriz de rigidez cargada: {data['stiffness'].shape}")

            mass = load_dataset_with_subsampling(f, '/matrices/mass', max_size, is_vector=False)
            if mass is not None:
                data['mass'] = mass
                print(f"   ✅ Matriz de masa cargada: {data['mass'].shape}")

            force = load_dataset_with_subsampling(f, '/vectors/force', max_size, is_vector=True)
            if force is not None:
                data['force'] = force
                print(f"   ✅ Vector de fuerzas: {data['force'].shape}")

            displacement = load_dataset_with_subsampling(
                f, '/results/displacement', max_size, is_vector=True
            )
            if displacement is not None:
                data['displacement'] = displacement
                print(f"   ✅ Desplazamientos: {data['displacement'].shape}")

    except (OSError, KeyError, ValueError) as e:
        print(f"❌ Error leyendo HDF5: {e}")
        return None

    return data

def plot_matrix_structure(matrix: np.ndarray, title: str, subplot_pos: int, fig) -> None:
    """Visualizar estructura de sparsity de una matriz (optimizado para memoria)"""
    ax = fig.add_subplot(subplot_pos)

    # Protección extrema de memoria - máximo 300x300 para visualización
    n = matrix.shape[0]
    if n > 300:
        step = max(1, n // 200)  # Máximo 200x200 para visualización segura
        matrix_plot = matrix[::step, ::step]
        print(f"   🔍 Submuestreo para visualización: {n}x{n} → {matrix_plot.shape}")
    else:
        matrix_plot = matrix

    # Crear máscara de elementos no-cero (adaptativo según el tipo de matriz)
    abs_matrix = np.abs(matrix_plot)
    if np.any(abs_matrix > 0):
        # Para matrices diagonales o con pocos elementos, usar umbral muy bajo
        max_val = np.max(abs_matrix)
        if 'masa' in title.lower() or 'mass' in title.lower():
            threshold = max_val * 1e-10  # Umbral muy bajo para matrices de masa
        else:
            threshold = np.percentile(abs_matrix[abs_matrix > 0], 5)  # Percentil más bajo
    else:
        threshold = 0
    nonzero_mask = abs_matrix > threshold

    # Información de diagnóstico
    n_nonzero = np.sum(nonzero_mask)
    max_val = np.max(abs_matrix) if np.any(abs_matrix > 0) else 0
    print(f"   🔍 {title}: {n_nonzero} elementos visibles, valor máx: {max_val:.2e}")

    # Visualizar
    ax.imshow(nonzero_mask, cmap='Blues', aspect='equal', origin='upper')
    sparsity = 100 * (1 - n_nonzero / nonzero_mask.size)
    ax.set_title(f'{title}\nSparsity: {sparsity:.1f}% ({n_nonzero} elementos)')
    ax.set_xlabel('Columna')
    ax.set_ylabel('Fila')

    # Información básica (sin cálculos pesados)
    ax.text(0.02, 0.98, f'Tamaño: {matrix.shape[0]}×{matrix.shape[1]}',
            transform=ax.transAxes, verticalalignment='top',
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))

def estimate_bandwidth(matrix):
    """Estimar ancho de banda de la matriz"""
    n = matrix.shape[0]
    max_band = 0

    # Comprobar solo las primeras 100 filas para eficiencia
    for i in range(min(100, n)):
        row = matrix[i, :]
        nonzeros = np.where(np.abs(row) > np.max(np.abs(row)) * 1e-10)[0]
        if len(nonzeros) > 0:
            band = np.max(nonzeros) - np.min(nonzeros) + 1
            max_band = max(max_band, band)

    return min(max_band, n)

def modal_analysis(stiffness, mass):
    """Análisis de valores propios mejorado (modal analysis)"""
    print("🔍 Realizando análisis modal avanzado...")

    # Estrategia inteligente para matrices grandes
    n = stiffness.shape[0]
    print(f"   📊 Tamaño matriz original: {n}×{n}")

    if n > 2000:
        # Selección estratificada: cada 12 DOF (2 nodos completos)
        # Esto mantiene la estructura física del problema
        step = max(12, n // 1500)  # Mantener ~1500 DOF máximo
        idx = np.arange(0, n, step)
        print(f"   🎯 Submuestreo estratificado: cada {step} DOF → {len(idx)} DOF")
        K = stiffness[np.ix_(idx, idx)]
        M = mass[np.ix_(idx, idx)]
    elif n > 1000:
        # Para tamaños medios, usar más DOF
        idx = slice(0, min(1000, n))
        K = stiffness[idx, idx]
        M = mass[idx, idx]
    else:
        K = stiffness
        M = mass

    try:
        # Regularización para evitar singularidad
        reg_factor = 1e-12 * np.max(np.diag(K))
        K_reg = K + reg_factor * np.eye(K.shape[0])

        # Verificar disponibilidad de SciPy
        if csr_matrix is None or eigsh is None:
            print("   ⚠️  SciPy no disponible. Instala con: pip install scipy")
            return None, None

        # Convertir a sparse para eficiencia
        K_sparse = csr_matrix(K_reg)
        M_sparse = csr_matrix(M)

        # Calcular más modos para mejor separación
        k_modes = min(12, K.shape[0] - 2)
        print(f"   🧮 Calculando {k_modes} modos propios...")

        eigenvals, eigenvecs = eigsh(K_sparse, k=k_modes, M=M_sparse, which='SM', sigma=0.0,
                                     maxiter=1000)  # Filtrar valores propios válidos (positivos)
        valid_idx = eigenvals > 0
        eigenvals = eigenvals[valid_idx]
        eigenvecs = eigenvecs[:, valid_idx]

        frequencies = np.sqrt(eigenvals) / (2 * np.pi)

        # Ordenar por frecuencia
        sort_idx = np.argsort(frequencies)
        frequencies = frequencies[sort_idx]
        eigenvecs = eigenvecs[:, sort_idx]

        print(f"   ✅ {len(frequencies)} modos válidos encontrados")

        # Crear figura mejorada con 3 subplots
        plt.figure(figsize=(16, 10))

        # 1. Frecuencias naturales con escala logarítmica si hay gran dispersión
        ax1 = plt.subplot(2, 2, 1)
        bar_objects = ax1.bar(range(1, len(frequencies)+1), frequencies,
                      color='lightcoral', edgecolor='darkred', alpha=0.7)

        # Añadir valores encima de las barras
        for bar_obj, freq in zip(bar_objects, frequencies):
            height = bar_obj.get_height()
            ax1.text(bar_obj.get_x() + bar_obj.get_width()/2., height,
                    f'{freq:.1f}', ha='center', va='bottom', fontsize=9)

        ax1.set_xlabel('Modo')
        ax1.set_ylabel('Frecuencia (Hz)')
        ax1.set_title(f'Frecuencias Naturales ({len(frequencies)} modos)')
        ax1.grid(True, alpha=0.3)

        # Usar escala log si hay gran dispersión
        if len(frequencies) > 1 and frequencies[-1] / frequencies[0] > 10:
            ax1.set_yscale('log')
            ax1.set_ylabel('Frecuencia (Hz) - Escala Log')

        # 2. Diferencias entre frecuencias consecutivas
        ax2 = plt.subplot(2, 2, 2)
        if len(frequencies) > 1:
            freq_diffs = np.diff(frequencies)
            ax2.bar(range(1, len(freq_diffs)+1), freq_diffs,
                   color='lightblue', edgecolor='navy', alpha=0.7)
            ax2.set_xlabel('Entre Modos')
            ax2.set_ylabel('Diferencia Freq. (Hz)')
            ax2.set_title('Separación entre Modos')
            ax2.grid(True, alpha=0.3)

            # Mostrar estadísticas
            mean_diff = float(np.mean(freq_diffs))
            ax2.axhline(mean_diff, color='red', linestyle='--',
                       label=f'Media: {mean_diff:.2f} Hz')
            ax2.legend()        # 3. Formas modales principales (primeros 4 modos)
        ax3 = plt.subplot(2, 2, 3)
        colors = ['red', 'blue', 'green', 'orange', 'purple', 'brown']
        for i in range(min(4, eigenvecs.shape[1])):
            # Normalizar forma modal
            mode_shape = eigenvecs[:, i]
            mode_shape = mode_shape / np.max(np.abs(mode_shape))

            ax3.plot(mode_shape, label=f'Modo {i+1} ({frequencies[i]:.1f} Hz)',
                    color=colors[i % len(colors)], linewidth=2, alpha=0.8)

        ax3.set_xlabel('DOF')
        ax3.set_ylabel('Amplitud Modal Normalizada')
        ax3.set_title('Formas Modales Principales')
        ax3.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
        ax3.grid(True, alpha=0.3)

        # 4. Participación modal (energía por modo)
        ax4 = plt.subplot(2, 2, 4)
        modal_masses = np.zeros(len(frequencies))
        for i in range(len(frequencies)):
            phi = eigenvecs[:, i]
            modal_masses[i] = phi.T @ M @ phi

        # Normalizar participación
        participation = modal_masses / np.sum(modal_masses) * 100

        ax4.bar(range(1, len(participation)+1), participation,
               color='lightgreen', edgecolor='darkgreen', alpha=0.7)
        ax4.set_xlabel('Modo')
        ax4.set_ylabel('Participación Modal (%)')
        ax4.set_title('Participación de Masa Modal')
        ax4.grid(True, alpha=0.3)

        plt.tight_layout()
        plt.savefig('results/modal_analysis.png', dpi=300, bbox_inches='tight')
        print("   ✅ Análisis modal guardado en: results/modal_analysis.png")

        # Resumen detallado
        print("\n📈 RESUMEN ANÁLISIS MODAL:")
        print(f"   🔢 Modos calculados: {len(frequencies)}")
        print(f"   📊 Rango frecuencias: {frequencies[0]:.2f} - {frequencies[-1]:.2f} Hz")
        if len(frequencies) > 1:
            print(f"   📏 Separación promedio: {np.mean(np.diff(frequencies)):.2f} Hz")
            print(f"   📈 Factor dispersión: {frequencies[-1]/frequencies[0]:.1f}x")

        print("\n🎵 Frecuencias por modo:")
        for i, freq in enumerate(frequencies):
            participation_pct = participation[i] if i < len(participation) else 0
            print(f"   Modo {i+1:2d}: {freq:7.2f} Hz  (Participación: {participation_pct:5.1f}%)")

        return frequencies, eigenvecs

    except (ImportError, ValueError, RuntimeError) as e:
        print(f"⚠️  Error en análisis modal: {e}")
        return None, None

def plot_response_analysis(force, displacement):
    """Análisis de la respuesta estructural"""
    _, axes = plt.subplots(2, 2, figsize=(14, 10))

    n_nodes = len(force) // 6  # Asumiendo 6 DOF por nodo
    node_positions = np.arange(n_nodes)

    # Reorganizar por componentes (X, Y, Z, RX, RY, RZ)
    disp_x = displacement[0::6][:n_nodes]
    disp_y = displacement[1::6][:n_nodes] if len(displacement) > 1 else np.zeros_like(disp_x)
    disp_z = displacement[2::6][:n_nodes] if len(displacement) > 2 else np.zeros_like(disp_x)

    force_x = force[0::6][:n_nodes]
    force_y = force[1::6][:n_nodes] if len(force) > 1 else np.zeros_like(force_x)

    # Desplazamientos por componente
    axes[0,0].plot(node_positions, disp_x * 1000, 'r-', label='X', linewidth=2)
    if len(displacement) > 1:
        axes[0,0].plot(node_positions, disp_y * 1000, 'g-', label='Y', linewidth=2)
    if len(displacement) > 2:
        axes[0,0].plot(node_positions, disp_z * 1000, 'b-', label='Z', linewidth=2)
    axes[0,0].set_xlabel('Nodo')
    axes[0,0].set_ylabel('Desplazamiento (mm)')
    axes[0,0].set_title('Desplazamientos por Componente')
    axes[0,0].legend()
    axes[0,0].grid(True, alpha=0.3)

    # Magnitud del desplazamiento
    disp_magnitude = np.sqrt(disp_x**2 + disp_y**2 + disp_z**2)
    axes[0,1].plot(node_positions, disp_magnitude * 1000, 'purple', linewidth=2)
    axes[0,1].set_xlabel('Nodo')
    axes[0,1].set_ylabel('|Desplazamiento| (mm)')
    axes[0,1].set_title('Magnitud del Desplazamiento')
    axes[0,1].grid(True, alpha=0.3)

    # Fuerzas aplicadas
    axes[1,0].plot(node_positions, force_x / 1000, 'orange', linewidth=2, label='Fx')
    if len(force) > 1:
        axes[1,0].plot(node_positions, force_y / 1000, 'brown', linewidth=2, label='Fy')
    axes[1,0].set_xlabel('Nodo')
    axes[1,0].set_ylabel('Fuerza (kN)')
    axes[1,0].set_title('Fuerzas Aplicadas')
    axes[1,0].legend()
    axes[1,0].grid(True, alpha=0.3)

    # Histograma de desplazamientos
    axes[1,1].hist(disp_magnitude * 1000, bins=50, color='lightblue', edgecolor='black', alpha=0.7)
    axes[1,1].axvline(np.mean(disp_magnitude) * 1000, color='red', linestyle='--',
                      label=f'Media: {np.mean(disp_magnitude)*1000:.3f} mm')
    axes[1,1].axvline(np.max(disp_magnitude) * 1000, color='orange', linestyle='--',
                      label=f'Máximo: {np.max(disp_magnitude)*1000:.3f} mm')
    axes[1,1].set_xlabel('Desplazamiento (mm)')
    axes[1,1].set_ylabel('Frecuencia')
    axes[1,1].set_title('Distribución de Desplazamientos')
    axes[1,1].legend()
    axes[1,1].grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('results/response_analysis.png', dpi=300, bbox_inches='tight')
    print("   ✅ Análisis de respuesta guardado en: results/response_analysis.png")

def generate_report(data):
    """Generar reporte técnico"""
    print("\n📋 REPORTE TÉCNICO AEROESPACIAL")
    print("=" * 50)

    if 'stiffness' in data:
        K = data['stiffness']
        print("🔧 MATRIZ DE RIGIDEZ:")
        print(f"   Dimensiones: {K.shape}")
        print(f"   Valores diagonal: {np.min(np.diag(K)):.2e} - {np.max(np.diag(K)):.2e}")
        print(f"   Número condición aprox: {np.max(np.diag(K))/np.min(np.diag(K)):.2e}")
        print(f"   Sparsity: {100*(1-np.count_nonzero(K)/K.size):.1f}%")

    if 'mass' in data:
        M = data['mass']
        print("\n⚖️  MATRIZ DE MASA:")
        print(f"   Dimensiones: {M.shape}")
        print(f"   Masa total: {np.sum(np.diag(M)):.2f} kg")
        print(f"   Masa por DOF: {np.mean(np.diag(M)):.4f} kg")

    if 'force' in data and 'displacement' in data:
        F = data['force']
        U = data['displacement']
        print("\n🏗️  RESPUESTA ESTRUCTURAL:")

    if 'mass' in data:
        M = data['mass']
        print("\n⚖️  MATRIZ DE MASA:")
        print(f"   Dimensiones: {M.shape}")
        print(f"   Masa total: {np.sum(np.diag(M)):.2f} kg")
        print(f"   Masa por DOF: {np.mean(np.diag(M)):.4f} kg")

    if 'force' in data and 'displacement' in data:
        F = data['force']
        U = data['displacement']
        print("\n🏗️  RESPUESTA ESTRUCTURAL:")
        print(f"   Fuerza total: {np.sum(np.abs(F)):.2e} N")
        print(f"   Desplazamiento máximo: {np.max(np.abs(U))*1000:.4f} mm")
        print(f"   Desplazamiento RMS: {np.sqrt(np.mean(U**2))*1000:.4f} mm")

        # Energía de deformación
        if 'stiffness' in data:
            energy = 0.5 * np.dot(U, np.dot(K, U))
            print(f"   Energía deformación: {energy:.2e} J")

        # Verificar límites
        max_disp_mm = np.max(np.abs(U)) * 1000
        if max_disp_mm > 10:
            print(f"   ⚠️  ADVERTENCIA: Desplazamiento {max_disp_mm:.2f} mm > 10 mm")
        else:
            print("   ✅ OK: Desplazamientos dentro de límites aceptables")

def main():
    """Función principal"""
    parser = argparse.ArgumentParser(description='Visualizador de datos HDF5 aeroespaciales')
    parser.add_argument('--file', '-f', default='results/structural_matrices.h5',
                        help='Archivo HDF5 a analizar')
    parser.add_argument('--modal', '-m', action='store_true',
                        help='Realizar análisis modal')
    parser.add_argument('--no-plots', action='store_true',
                        help='No generar gráficos')
    parser.add_argument('--max-size', type=int, default=2000,
                        help='Tamaño máximo de matriz para submuestreo (default: 2000)')
    parser.add_argument('--quick', action='store_true',
                        help='Modo rápido: submuestreo agresivo para matrices grandes')

    args = parser.parse_args()

    # Ajustar parámetros según el modo
    if args.quick:
        max_size = min(1000, args.max_size)
        print("🚀 Modo rápido activado: submuestreo agresivo")
    else:
        max_size = args.max_size

    print("🚀 VISUALIZADOR DE DATOS AEROESPACIALES")
    print("=" * 50)

    # Crear directorio de resultados si no existe
    os.makedirs('results', exist_ok=True)

    # Cargar datos
    data = load_hdf5_data(args.file, max_size=max_size)
    if data is None:
        return

    # Generar reporte
    generate_report(data)

    if not args.no_plots:
        print("\n📊 Generando visualizaciones...")

        # Verificar memoria disponible (estimación conservadora)
        total_elements = sum(arr.size for arr in data.values() if hasattr(arr, 'size'))
        memory_mb = total_elements * 8 / (1024*1024)  # 8 bytes por float64
        print(f"   💾 Memoria estimada en uso: {memory_mb:.1f} MB")

        if memory_mb > 500:  # Más de 500MB, usar modo ultra conservador
            print("   ⚠️  Modo ultra-conservador activado para visualización")

        # Análisis de respuesta
        if 'force' in data and 'displacement' in data:
            plot_response_analysis(data['force'], data['displacement'])

        # Estructura de matrices
        if 'stiffness' in data or 'mass' in data:
            fig = plt.figure(figsize=(14, 6))

            if 'stiffness' in data:
                plot_matrix_structure(data['stiffness'], 'Matriz de Rigidez', 121, fig)

            if 'mass' in data:
                plot_matrix_structure(data['mass'], 'Matriz de Masa', 122, fig)

            plt.tight_layout()
            plt.savefig('results/matrix_structure.png', dpi=300, bbox_inches='tight')
            print("   ✅ Estructura de matrices guardada en: results/matrix_structure.png")

        # Análisis modal
        if args.modal and 'stiffness' in data and 'mass' in data:
            if eigsh is not None:
                modal_analysis(data['stiffness'], data['mass'])
            else:
                print("   ⚠️  Análisis modal omitido (scipy no disponible)")

        print("\n✨ Visualización completada. Archivos guardados en: results/")

        if not args.no_plots:
            print("   Para ver gráficos: ls -la results/*.png")


if __name__ == "__main__":
    main()

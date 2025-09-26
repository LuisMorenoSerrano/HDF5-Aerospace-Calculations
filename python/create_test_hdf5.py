#!/usr/bin/env python3
"""
Generador de archivo HDF5 de prueba para testing de visualización
Crea matrices grandes simuladas sin consumir memoria masiva
"""
import os
import numpy as np
import h5py

def create_test_hdf5(filename, size=60000):
    """Crear archivo HDF5 de prueba con datos simulados grandes"""
    print(f"📦 Creando archivo HDF5 de prueba: {filename}")
    print(f"   Tamaño simulado: {size}x{size} ({size*size*8/(1024**3):.1f} GB)")

    # Crear directorio si no existe
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    with h5py.File(filename, 'w') as f:
        # Crear grupos
        matrices_group = f.create_group('matrices')
        vectors_group = f.create_group('vectors')
        results_group = f.create_group('results')

        print("   🔨 Generando matriz de rigidez simulada...")
        # Crear matriz de rigidez sparse simulada
        stiff_dataset = matrices_group.create_dataset(
            'stiffness',
            shape=(size, size),
            dtype=np.float64,
            compression='gzip',
            compression_opts=6,
            chunks=(min(1000, size//10), min(1000, size//10))
        )

        # Llenar por bloques para evitar memoria masiva
        block_size = 1000
        for i in range(0, size, block_size):
            end_i = min(i + block_size, size)
            for j in range(0, size, block_size):
                end_j = min(j + block_size, size)

                # Generar bloque con patrón banda
                block = np.zeros((end_i - i, end_j - j))
                if abs(i - j) < block_size * 2:  # Solo llenar cerca de la diagonal
                    # Diagonal
                    if i == j:
                        np.fill_diagonal(block,
                                         7e10 * (1.0 + 0.1 * np.sin(np.arange(i, end_i) / 1000.0)))
                    # Bandas cercanas
                    elif abs(i - j) <= block_size:
                        for bi in range(block.shape[0]):
                            for bj in range(block.shape[1]):
                                if abs((i + bi) - (j + bj)) <= 50:  # bandwidth = 50
                                    dist = abs((i + bi) - (j + bj))
                                    block[bi, bj] = -7e10 * np.exp(-dist/10.0) * 0.3

                stiff_dataset[i:end_i, j:end_j] = block

        print("   ⚖️ Generando matriz de masa simulada...")
        # Crear matriz de masa diagonal
        mass_dataset = matrices_group.create_dataset(
            'mass',
            shape=(size, size),
            dtype=np.float64,
            compression='gzip',
            compression_opts=6,
            chunks=(min(1000, size//10), min(1000, size//10))
        )

        # Llenar matriz de masa (diagonal)
        for i in range(0, size, block_size):
            end_i = min(i + block_size, size)
            block = np.zeros((end_i - i, size))
            np.fill_diagonal(block[:, i:end_i], 0.054)  # kg por DOF
            mass_dataset[i:end_i, :] = block

        print("   🔧 Generando vectores simulados...")
        # Vector de fuerzas
        force = np.random.normal(0, 1000, size)  # Fuerzas aleatorias ±1000N
        vectors_group.create_dataset('force', data=force, compression='gzip', compression_opts=6)

        # Vector de desplazamientos
        displacement = np.random.normal(0, 1e-6, size)  # Desplazamientos pequeños
        results_group.create_dataset('displacement', data=displacement, compression='gzip',
                                     compression_opts=6)

        print("   📋 Añadiendo metadatos...")
        # Metadatos
        f.attrs['description'] = 'Archivo de prueba para visualización aeroespacial'
        f.attrs['size'] = size
        f.attrs['n_dof'] = size
        f.attrs['created_by'] = 'create_test_hdf5.py'

    print(f"   ✅ Archivo creado: {filename}")

    # Mostrar tamaño real del archivo
    file_size_mb = os.path.getsize(filename) / (1024**2)
    compression_ratio = size*size*8/(1024**2)/file_size_mb
    print(f"   📦 Tamaño real archivo: {file_size_mb:.1f} MB "
          f"(compresión ~{compression_ratio:.1f}x)")

def create_small_test_hdf5(filename, size=5000):
    """Crear archivo HDF5 pequeño para pruebas rápidas"""
    print(f"📦 Creando archivo HDF5 pequeño: {filename}")

    os.makedirs(os.path.dirname(filename), exist_ok=True)

    with h5py.File(filename, 'w') as f:
        matrices_group = f.create_group('matrices')
        vectors_group = f.create_group('vectors')
        results_group = f.create_group('results')

        # Matrices pequeñas completas
        K = np.random.rand(size, size) * 1e10
        K = (K + K.T) / 2  # Simétrica
        np.fill_diagonal(K, np.diag(K) + 7e10)  # Diagonal dominante

        M = np.eye(size) * 0.054  # Masa diagonal

        force = np.random.normal(0, 1000, size)
        displacement = np.random.normal(0, 1e-6, size)

        matrices_group.create_dataset('stiffness', data=K, compression='gzip', compression_opts=6)
        matrices_group.create_dataset('mass', data=M, compression='gzip', compression_opts=6)
        vectors_group.create_dataset('force', data=force, compression='gzip', compression_opts=6)
        results_group.create_dataset('displacement', data=displacement, compression='gzip',
                                     compression_opts=6)

        f.attrs['description'] = 'Archivo pequeño de prueba'
        f.attrs['size'] = size

    file_size_mb = os.path.getsize(filename) / (1024**2)
    print(f"   ✅ Archivo pequeño creado: {file_size_mb:.1f} MB")

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='Crear archivos HDF5 de prueba')
    parser.add_argument('--size', type=int, default=60000, help='Tamaño de matriz (default: 60000)')
    parser.add_argument('--small', action='store_true', help='Crear archivo pequeño (5000x5000)')
    parser.add_argument('--output', default='results/test_matrices.h5', help='Archivo de salida')

    args = parser.parse_args()

    if args.small:
        create_small_test_hdf5(args.output, 5000)
    else:
        create_test_hdf5(args.output, args.size)

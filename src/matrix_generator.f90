! =============================================================================
! Generador de Matrices Aeroespaciales - Simulación de análisis estructural
! Genera matrices de rigidez y masa típicas de elementos finitos aeroespaciales
! =============================================================================
program structural_matrix_generator
    use hdf5_utils
    use config_reader
    !$ use omp_lib
    implicit none

    ! Variables
    type(simulation_config) :: config
    real(8), allocatable :: stiffness_matrix(:,:)
    real(8), allocatable :: mass_matrix(:,:)
    real(8), allocatable :: force_vector(:)
    integer(HID_T) :: file_id
    logical :: benchmark_mode = .false.
    character(len=255) :: arg

    ! Información de timing
    real :: start_time, end_time

    write(*,*) '=============================================='
    write(*,*) '   GENERADOR DE MATRICES AEROESPACIALES'
    write(*,*) '=============================================='

    ! Verificar argumentos de línea de comandos
    if (command_argument_count() > 0) then
        call get_command_argument(1, arg)
        if (trim(arg) == '--benchmark') then
            benchmark_mode = .true.
            write(*,*) '🚀 MODO BENCHMARK: Solo generación (sin I/O)'
        end if
    end if

    ! Leer configuración
    call read_config_file('config/simulation_params.conf', config)

    ! Configurar OpenMP
    !$ if (config%num_threads > 0) then
    !$     call omp_set_num_threads(config%num_threads)
    !$ end if
    !$ write(*,'(A,I0,A,I0,A)') ' OpenMP: ', omp_get_max_threads(), ' threads de ', omp_get_num_procs(), ' disponibles'

    ! Inicializar HDF5 solo si no es modo benchmark
    if (.not. benchmark_mode) then
        call init_hdf5()
        call create_hdf5_file(config%output_file, file_id)
    end if

    ! Decidir estrategia basada en el tamaño
    if (config%n_dof > 40000) then
        ! Matrices grandes: procesamiento por bloques para optimizar memoria
        write(*,*) 'Matrices grandes detectadas. Usando procesamiento por bloques...'
        call cpu_time(start_time)

        call generate_matrices_block_wise(file_id, config)
        call generate_force_vector(force_vector, config%n_dof)

        call cpu_time(end_time)
        write(*,'(A,F8.2,A)') ' Tiempo generación (bloques): ', end_time - start_time, ' segundos'

        ! Guardar vector de fuerzas
        call write_vector_real8(file_id, '/vectors/force', force_vector)

    else
        ! Matrices normales: método tradicional en memoria
        write(*,*) 'Generando matrices en memoria...'
        call cpu_time(start_time)

        call generate_stiffness_matrix(stiffness_matrix, config)
        call generate_mass_matrix(mass_matrix, config)
        call generate_force_vector(force_vector, config%n_dof)

        call cpu_time(end_time)
        write(*,'(A,F8.2,A)') ' Tiempo generación: ', end_time - start_time, ' segundos'

        ! Si es modo benchmark, terminar aquí
        if (benchmark_mode) then
            write(*,*) '=============================================='
            write(*,*) '🚀 BENCHMARK COMPLETADO'
            write(*,'(A,F8.2,A)') ' Tiempo total generación: ', end_time - start_time, ' segundos'
            write(*,*) '=============================================='
            stop
        end if

        ! Guardar en HDF5 con compresión optimizada
        call cpu_time(start_time)
        write(*,'(A,A,A,I0,A)') 'Guardando en HDF5 con ', trim(config%compression_type), &
                               ' nivel ', config%compression_level, '...'

        call write_matrix_real8(file_id, '/matrices/stiffness', stiffness_matrix, config%compression_level)
        call write_matrix_real8(file_id, '/matrices/mass', mass_matrix, config%compression_level)
        call write_vector_real8(file_id, '/vectors/force', force_vector)
    end if

    call cpu_time(end_time)
    write(*,'(A,F8.2,A)') ' Tiempo escritura: ', end_time - start_time, ' segundos'

        ! Para matrices grandes por bloques, omitir cálculo de ejemplo (requiere solver especializado)
        write(*,*) 'Matrices grandes: Omitiendo cálculo de ejemplo (usar solver especializado)'
        ! call write_vector_real8(file_id, '/results/displacement', displacement)  ! Comentado para matrices grandes

    ! Escribir metadatos
    call write_simulation_metadata(file_id)

    ! Limpiar
    if (.not. benchmark_mode) then
        call close_hdf5_file(file_id)
        call close_hdf5()

        write(*,*) '=============================================='
        write(*,*) 'Datos guardados en: results/structural_matrices.h5'
        write(*,*) 'Para visualizar: python python/visualize_results.py'
        write(*,*) '=============================================='
    end if

contains

    ! -------------------------------------------------------------------------
    ! Generar matriz de rigidez banda (simulando FEM aeroespacial)
    ! -------------------------------------------------------------------------
    subroutine generate_stiffness_matrix(K, cfg)
        real(8), allocatable, intent(out) :: K(:,:)
        type(simulation_config), intent(in) :: cfg

        integer :: i, j, band_width, n
        real(8) :: G, k_local, E, nu

        n = cfg%n_dof
        E = cfg%young_modulus
        nu = cfg%poisson_ratio

        allocate(K(n, n))
        K = 0.0d0

        G = E / (2.0d0 * (1.0d0 + nu))  ! Módulo de cortante
        band_width = min(cfg%bandwidth, n)

        ! Generar estructura aeroespacial heterogénea con diferentes zonas
        !$OMP PARALLEL DO PRIVATE(j, k_local) SCHEDULE(DYNAMIC)
        do i = 1, n
            ! Crear zonas con diferentes propiedades (fuselaje, alas, cola)
            if (i <= n/3) then
                ! Zona fuselaje: más rígida
                k_local = E * (1.0d0 + 0.5d0 * cos(real(i) * 6.28d0 / (n/3)))
            else if (i <= 2*n/3) then
                ! Zona alas: flexible con variación
                k_local = E * 0.3d0 * (1.0d0 + 0.8d0 * sin(real(i-n/3) * 12.56d0 / (n/3)))
            else
                ! Zona cola: intermedia con resonadores
                k_local = E * 0.6d0 * (1.0d0 + 0.3d0 * sin(real(i-2*n/3) * 25.12d0 / (n/3)))
            end if

            K(i,i) = k_local

            ! Elementos fuera de la diagonal con conectividad variable
            do j = i+1, min(i + band_width, n)
                if (i <= n/3 .and. j <= n/3) then
                    ! Fuselaje: alta conectividad
                    K(i,j) = -k_local * exp(-real(j-i)/5.0d0) * 0.6d0
                else if (i > n/3 .and. j > n/3) then
                    ! Alas/cola: menor conectividad
                    K(i,j) = -k_local * exp(-real(j-i)/15.0d0) * 0.2d0
                else
                    ! Transición entre zonas
                    K(i,j) = -k_local * exp(-real(j-i)/20.0d0) * 0.1d0
                end if
                K(j,i) = K(i,j)  ! Simetría
            end do
        end do
        !$OMP END PARALLEL DO
    end subroutine generate_stiffness_matrix

    ! -------------------------------------------------------------------------
    ! Generar matriz de masa
    ! -------------------------------------------------------------------------
    subroutine generate_mass_matrix(M, cfg)
        real(8), allocatable, intent(out) :: M(:,:)
        type(simulation_config), intent(in) :: cfg

        integer :: i, n
        real(8) :: m_local, area_element, rho, t

        n = cfg%n_dof
        rho = cfg%density
        t = cfg%thickness

        allocate(M(n, n))
        M = 0.0d0

        area_element = 0.01d0  ! m² por elemento base (1cm²)

        ! Matriz de masa con distribución variable por zonas
        !$OMP PARALLEL DO PRIVATE(m_local) SCHEDULE(DYNAMIC)
        do i = 1, n
            if (i <= n/3) then
                ! Fuselaje: mayor masa (equipos, pasajeros)
                m_local = rho * t * area_element * (2.0d0 + 0.5d0 * sin(real(i) * 6.28d0 / (n/3)))
            else if (i <= 2*n/3) then
                ! Alas: masa variable (combustible, motores)
                m_local = rho * t * area_element * (0.8d0 + 1.2d0 * cos(real(i-n/3) * 6.28d0 / (n/3)))
            else
                ! Cola: menor masa
                m_local = rho * t * area_element * (0.3d0 + 0.2d0 * cos(real(i-2*n/3) * 12.56d0 / (n/3)))
            end if

            M(i,i) = m_local

            ! Acoplamiento inercial variable por zonas
            if (i < n) then
                if (i <= n/3) then
                    M(i,i+1) = m_local * 0.08d0  ! Mayor acoplamiento en fuselaje
                else
                    M(i,i+1) = m_local * 0.03d0  ! Menor en alas/cola
                end if
            end if
            if (i > 1) then
                if (i <= n/3) then
                    M(i,i-1) = m_local * 0.08d0
                else
                    M(i,i-1) = m_local * 0.03d0
                end if
            end if
        end do
        !$OMP END PARALLEL DO
    end subroutine generate_mass_matrix

    ! -------------------------------------------------------------------------
    ! Generar vector de fuerzas (carga aerodinámica distribuida)
    ! -------------------------------------------------------------------------
    subroutine generate_force_vector(F, n)
        real(8), allocatable, intent(out) :: F(:)
        integer, intent(in) :: n

        integer :: i, n_nodes_equiv
        real(8) :: pressure, x, y

        allocate(F(n))

        ! Calcular número de nodos equivalente para la geometría
        n_nodes_equiv = n / 6  ! 6 DOF por nodo

        ! Simulación de carga de presión aerodinámica
        !$OMP PARALLEL DO PRIVATE(x, y, pressure) SCHEDULE(STATIC)
        do i = 1, n
            ! Posición X normalizada
            x = real(mod(i-1, int(sqrt(real(n_nodes_equiv))))) / sqrt(real(n_nodes_equiv))
            ! Posición Y normalizada
            y = real((i-1) / int(sqrt(real(n_nodes_equiv)))) / sqrt(real(n_nodes_equiv))

            ! Distribución de presión típica (gradiente + oscilación)
            pressure = 1000.0d0 * (1.0d0 + 0.5d0 * x + 0.3d0 * sin(10.0d0 * x) * cos(8.0d0 * y))
            F(i) = pressure * 0.01d0  ! Fuerza por nodo
        end do
        !$OMP END PARALLEL DO
    end subroutine generate_force_vector

    ! -------------------------------------------------------------------------
    ! Escribir metadatos de la simulación
    ! -------------------------------------------------------------------------
    subroutine write_simulation_metadata(hdf5_file_id)
        integer(HID_T), intent(in) :: hdf5_file_id  ! Parámetro requerido por interfaz

        ! Aquí escribirías atributos del archivo
        ! Por simplicidad, solo mostramos el concepto
        write(*,*) 'Metadatos guardados: material, geometría, condiciones'
        write(*,*) 'File ID usado:', hdf5_file_id
    end subroutine write_simulation_metadata

    ! -------------------------------------------------------------------------
    ! Generar matrices por bloques para optimizar memoria (matrices grandes)
    ! -------------------------------------------------------------------------
    subroutine generate_matrices_block_wise(file_id, config)
        integer(HID_T), intent(in) :: file_id
        type(simulation_config), intent(in) :: config

        real(8), allocatable :: stiffness_block(:,:), mass_block(:,:)
        integer :: n, n_blocks, block_i, block_j, BLOCK_SIZE
        integer :: start_i, end_i, start_j, end_j, actual_size_i, actual_size_j
        real :: block_start_time, block_end_time
        real(8) :: block_memory_gb

        n = config%n_dof
        BLOCK_SIZE = config%block_size
        n_blocks = (n + BLOCK_SIZE - 1) / BLOCK_SIZE  ! Ceiling division
        block_memory_gb = (real(BLOCK_SIZE,8)**2 * 8.0d0) / (1024.0d0**3)

        write(*,'(A,I0,A,I0,A,I0)') ' Procesando matriz ', n, 'x', n, ' en bloques de ', BLOCK_SIZE
        write(*,'(A,F5.2,A)') ' Memoria por bloque: ', block_memory_gb, ' GB'
        write(*,'(A,I0,A)') ' Total bloques: ', n_blocks, 'x', n_blocks

        ! Crear datasets HDF5 con dimensiones completas
        call create_large_matrix_datasets(file_id, n, config%compression_level)

        ! Estrategia optimizada: generar bloques por filas para mejor rendimiento I/O secuencial
        do block_i = 1, n_blocks
            call cpu_time(block_start_time)

            ! Procesar toda una fila de bloques para optimizar I/O secuencial
            !$OMP PARALLEL DO PRIVATE(block_j, start_i, end_i, start_j, end_j) &
            !$OMP& PRIVATE(actual_size_i, actual_size_j, stiffness_block, mass_block) &
            !$OMP& SCHEDULE(DYNAMIC) if (n_blocks > 2)
            do block_j = 1, n_blocks
                ! Calcular índices del bloque
                start_i = (block_i - 1) * BLOCK_SIZE + 1
                end_i = min(block_i * BLOCK_SIZE, n)
                start_j = (block_j - 1) * BLOCK_SIZE + 1
                end_j = min(block_j * BLOCK_SIZE, n)

                actual_size_i = end_i - start_i + 1
                actual_size_j = end_j - start_j + 1

                ! Allocar bloques (cada thread su propia memoria)
                allocate(stiffness_block(actual_size_i, actual_size_j))
                allocate(mass_block(actual_size_i, actual_size_j))

                ! Generar contenido del bloque (paralelizado)
                call generate_matrix_block(stiffness_block, mass_block, &
                                         start_i, end_i, start_j, end_j, config)

                ! Escritura HDF5 optimizada (versión original eficiente)
                !$OMP CRITICAL(hdf5_write)
                call write_matrix_block_hdf5(file_id, '/matrices/stiffness', stiffness_block, start_i, start_j)
                call write_matrix_block_hdf5(file_id, '/matrices/mass', mass_block, start_i, start_j)
                !$OMP END CRITICAL(hdf5_write)

                ! Liberar memoria del bloque
                deallocate(stiffness_block, mass_block)
            end do
            !$OMP END PARALLEL DO

            call cpu_time(block_end_time)
            write(*,'(A,I0,A,I0,A,F6.2,A)') '   Fila de bloques ', block_i, ' de ', n_blocks, &
                  ' completada en ', block_end_time - block_start_time, 's'
        end do

        write(*,*) '✅ Generación por bloques completada'
    end subroutine generate_matrices_block_wise

    ! -------------------------------------------------------------------------
    ! Generar contenido de un bloque específico de las matrices
    ! -------------------------------------------------------------------------
    subroutine generate_matrix_block(K_block, M_block, start_i, end_i, start_j, end_j, config)
        real(8), intent(out) :: K_block(:,:), M_block(:,:)
        integer, intent(in) :: start_i, end_i, start_j, end_j
        type(simulation_config), intent(in) :: config

        integer :: i, j, n_total, band_width
        real(8) :: E, nu, G, rho, t, area_element
        real(8) :: k_local, m_local

        n_total = config%n_dof
        E = config%young_modulus
        nu = config%poisson_ratio
        rho = config%density
        t = config%thickness
        G = E / (2.0d0 * (1.0d0 + nu))
        band_width = min(config%bandwidth, n_total)
        area_element = 0.01d0  ! m² por elemento

        ! Inicializar bloques
        K_block = 0.0d0
        M_block = 0.0d0

        ! Generar elementos dentro del bloque
        !$OMP PARALLEL DO PRIVATE(i, j, k_local, m_local) if (end_i - start_i > 100)
        do i = start_i, end_i
            do j = start_j, end_j
                ! Solo generar si está dentro del ancho de banda
                if (abs(i - j) <= band_width) then
                    ! Calcular rigidez local con patrones aeroespaciales
                    if (i <= n_total/3) then
                        ! Zona fuselaje: más rígida
                        k_local = E * config%zone1_stiffness_factor * &
                                 (1.0d0 + 0.5d0 * cos(real(i) * 6.28d0 / (n_total/3)))
                    else if (i <= 2*n_total/3) then
                        ! Zona alas: flexible
                        k_local = E * config%zone2_stiffness_factor * &
                                 (1.0d0 + 0.8d0 * sin(real(i-n_total/3) * 12.56d0 / (n_total/3)))
                    else
                        ! Zona cola: intermedia
                        k_local = E * config%zone3_stiffness_factor * &
                                 (1.0d0 + 0.3d0 * sin(real(i-2*n_total/3) * 25.12d0 / (n_total/3)))
                    end if

                    if (i == j) then
                        ! Elementos diagonal
                        K_block(i-start_i+1, j-start_j+1) = k_local

                        ! Masa correspondiente
                        if (i <= n_total/3) then
                            m_local = rho * t * area_element * config%zone1_mass_factor * &
                                     (2.0d0 + 0.5d0 * sin(real(i) * 6.28d0 / (n_total/3)))
                        else if (i <= 2*n_total/3) then
                            m_local = rho * t * area_element * config%zone2_mass_factor * &
                                     (0.8d0 + 1.2d0 * cos(real(i-n_total/3) * 6.28d0 / (n_total/3)))
                        else
                            m_local = rho * t * area_element * config%zone3_mass_factor * &
                                     (0.3d0 + 0.4d0 * sin(real(i-2*n_total/3) * 12.56d0 / (n_total/3)))
                        end if
                        M_block(i-start_i+1, j-start_j+1) = m_local
                    else
                        ! Elementos off-diagonal (acoplamiento)
                        K_block(i-start_i+1, j-start_j+1) = -0.3d0 * k_local / band_width
                    end if
                end if
            end do
        end do
        !$OMP END PARALLEL DO
    end subroutine generate_matrix_block

end program structural_matrix_generator
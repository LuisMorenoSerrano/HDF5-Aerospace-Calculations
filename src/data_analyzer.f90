! =============================================================================
! Analizador de Datos HDF5 - Lectura y análisis de resultados aeroespaciales
! =============================================================================
program hdf5_data_analyzer
    use hdf5_utils
    implicit none

    ! Variables
    real(8), allocatable :: stiffness_matrix(:,:)
    real(8), allocatable :: mass_matrix(:,:)
    real(8), allocatable :: force_vector(:)
    real(8), allocatable :: displacement(:)
    integer(HID_T) :: file_id

    ! Análisis
    real(8) :: max_displacement, rms_displacement, total_energy
    real(8) :: condition_number_approx, max_force
    integer :: n_dof

    write(*,*) '=============================================='
    write(*,*) '    ANALIZADOR DE DATOS AEROESPACIALES'
    write(*,*) '=============================================='

    ! Inicializar HDF5 y abrir archivo
    call init_hdf5()
    call open_hdf5_file('results/structural_matrices.h5', file_id)

    write(*,*) 'Leyendo datos desde HDF5...'

    ! Leer matrices y vectores
    call read_matrix_real8(file_id, '/matrices/stiffness', stiffness_matrix)
    call read_matrix_real8(file_id, '/matrices/mass', mass_matrix)
    call read_vector_real8(file_id, '/vectors/force', force_vector)
    call read_vector_real8(file_id, '/results/displacement', displacement)

    n_dof = size(force_vector)

    write(*,*) 'Datos leídos correctamente.'
    write(*,*) 'Dimensiones:'
    write(*,'(A,I0)') '  DOF: ', n_dof
    write(*,'(A,I0,A,I0)') '  Matriz rigidez: ', size(stiffness_matrix,1), ' x ', size(stiffness_matrix,2)
    write(*,'(A,I0,A,I0)') '  Matriz masa: ', size(mass_matrix,1), ' x ', size(mass_matrix,2)

    ! Realizar análisis
    call analyze_structural_response()
    call analyze_matrix_properties()
    call perform_modal_analysis_approximation()

    ! Limpiar
    call close_hdf5_file(file_id)
    call close_hdf5()

    write(*,*) '=============================================='
    write(*,*) 'Análisis completado.'
    write(*,*) '=============================================='

contains

    ! -------------------------------------------------------------------------
    ! Analizar respuesta estructural
    ! -------------------------------------------------------------------------
    subroutine analyze_structural_response()
        write(*,*)
        write(*,*) '--- ANÁLISIS DE RESPUESTA ESTRUCTURAL ---'

        max_displacement = maxval(abs(displacement))
        rms_displacement = sqrt(sum(displacement**2) / real(n_dof))
        max_force = maxval(abs(force_vector))

        ! Energía de deformación aproximada: U = 0.5 * u^T * K * u
        total_energy = 0.5d0 * dot_product_matrix(displacement, stiffness_matrix, displacement)

        write(*,'(A,ES12.4,A)') 'Desplazamiento máximo: ', max_displacement, ' m'
        write(*,'(A,ES12.4,A)') 'Desplazamiento RMS:    ', rms_displacement, ' m'
        write(*,'(A,ES12.4,A)') 'Fuerza máxima:         ', max_force, ' N'
        write(*,'(A,ES12.4,A)') 'Energía deformación:   ', total_energy, ' J'

        ! Verificar límites aeroespaciales
        if (max_displacement > 0.01d0) then
            write(*,*) 'ADVERTENCIA: Desplazamiento excede 1cm (límite típico)'
        else
            write(*,*) 'OK: Desplazamientos dentro de límites aceptables'
        endif
    end subroutine analyze_structural_response

    ! -------------------------------------------------------------------------
    ! Analizar propiedades de las matrices
    ! -------------------------------------------------------------------------
    subroutine analyze_matrix_properties()
        real(8) :: k_min, k_max, m_min, m_max
        real(8) :: sparsity_k, sparsity_m
        integer :: nnz_k, nnz_m, i, j

        write(*,*)
        write(*,*) '--- PROPIEDADES DE LAS MATRICES ---'

        ! Valores extremos en la diagonal
        k_min = minval([(stiffness_matrix(i,i), i=1,n_dof)])
        k_max = maxval([(stiffness_matrix(i,i), i=1,n_dof)])
        m_min = minval([(mass_matrix(i,i), i=1,n_dof)])
        m_max = maxval([(mass_matrix(i,i), i=1,n_dof)])

        write(*,'(A,ES12.4,A,ES12.4)') 'Rigidez diagonal: ', k_min, ' - ', k_max
        write(*,'(A,ES12.4,A,ES12.4)') 'Masa diagonal:    ', m_min, ' - ', m_max

        ! Número de condición aproximado
        condition_number_approx = k_max / k_min
        write(*,'(A,ES12.4)') 'Número condición aprox: ', condition_number_approx

        if (condition_number_approx > 1.0e12) then
            write(*,*) 'ADVERTENCIA: Matriz mal condicionada'
        endif

        ! Sparsity (elementos no-cero)
        nnz_k = 0
        nnz_m = 0
        do i = 1, min(n_dof, 1000)  ! Muestra para matrices grandes
            do j = 1, min(n_dof, 1000)
                if (abs(stiffness_matrix(i,j)) > 1.0e-14) nnz_k = nnz_k + 1
                if (abs(mass_matrix(i,j)) > 1.0e-14) nnz_m = nnz_m + 1
            end do
        end do

        sparsity_k = 100.0d0 * (1.0d0 - real(nnz_k) / real(min(n_dof,1000)**2))
        sparsity_m = 100.0d0 * (1.0d0 - real(nnz_m) / real(min(n_dof,1000)**2))

        write(*,'(A,F6.2,A)') 'Sparsity rigidez: ', sparsity_k, '%'
        write(*,'(A,F6.2,A)') 'Sparsity masa:    ', sparsity_m, '%'
    end subroutine analyze_matrix_properties

    ! -------------------------------------------------------------------------
    ! Análisis modal aproximado (primeras frecuencias)
    ! -------------------------------------------------------------------------
    subroutine perform_modal_analysis_approximation()
        real(8) :: omega_1, omega_2, freq_1, freq_2
        integer :: i

        write(*,*)
        write(*,*) '--- ANÁLISIS MODAL APROXIMADO ---'

        ! Frecuencias aproximadas usando Rayleigh quotient en algunos puntos
        omega_1 = 0.0d0
        omega_2 = 0.0d0

        do i = 1, min(n_dof, 10)
            if (mass_matrix(i,i) > 1.0e-14) then
                omega_1 = max(omega_1, sqrt(stiffness_matrix(i,i) / mass_matrix(i,i)))
            endif
        end do

        ! Segunda frecuencia (estimación)
        do i = 1, min(n_dof, 10)
            if (mass_matrix(i,i) > 1.0e-14 .and. i > 1) then
                omega_2 = max(omega_2, sqrt((stiffness_matrix(i,i) + stiffness_matrix(i-1,i-1)) / &
                                           (mass_matrix(i,i) + mass_matrix(i-1,i-1))))
            endif
        end do

        freq_1 = omega_1 / (2.0d0 * 3.14159265359d0)
        freq_2 = omega_2 / (2.0d0 * 3.14159265359d0)

        write(*,'(A,F10.2,A)') 'Frecuencia fundamental aprox: ', freq_1, ' Hz'
        write(*,'(A,F10.2,A)') 'Segunda frecuencia aprox:     ', freq_2, ' Hz'

        ! Comentarios aeroespaciales
        if (freq_1 < 10.0d0) then
            write(*,*) 'NOTA: Frecuencia baja, verificar rigidez estructural'
        elseif (freq_1 > 1000.0d0) then
            write(*,*) 'NOTA: Frecuencia alta, estructura rígida'
        else
            write(*,*) 'OK: Frecuencias en rango típico aeroespacial'
        endif
    end subroutine perform_modal_analysis_approximation

    ! -------------------------------------------------------------------------
    ! Producto matriz-vector optimizado para dot product u^T * K * u
    ! -------------------------------------------------------------------------
    function dot_product_matrix(u, K, v) result(product)
        real(8), intent(in) :: u(:), K(:,:), v(:)
        real(8) :: product
        real(8), allocatable :: Kv(:)
        integer :: n, i

        n = size(u)
        allocate(Kv(n))

        ! Kv = K * v
        do i = 1, n
            Kv(i) = dot_product(K(i,:), v)
        end do

        ! u^T * Kv
        product = dot_product(u, Kv)

        deallocate(Kv)
    end function dot_product_matrix

end program hdf5_data_analyzer
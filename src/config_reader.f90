! =============================================================================
! Módulo Config Reader - Lector de parámetros de configuración
! Lee archivos de configuración en formato clave = valor
! =============================================================================
module config_reader
    implicit none

    private
    public :: read_config_file, simulation_config

    ! Tipo para almacenar la configuración
    type :: simulation_config
        ! Parámetros de malla
        integer :: n_nodes = 1000
        integer :: dof_per_node = 6
        integer :: bandwidth = 30

        ! Propiedades del material
        real(8) :: young_modulus = 70.0e9
        real(8) :: poisson_ratio = 0.33
        real(8) :: density = 2700.0
        real(8) :: thickness = 0.002

        ! Factores de zona
        real(8) :: zone1_stiffness_factor = 1.0
        real(8) :: zone1_mass_factor = 2.0
        real(8) :: zone2_stiffness_factor = 0.3
        real(8) :: zone2_mass_factor = 0.8
        real(8) :: zone3_stiffness_factor = 0.6
        real(8) :: zone3_mass_factor = 0.3

        ! Configuración de salida
        character(len=200) :: output_file = "results/structural_matrices.h5"
        integer :: compression_level = 6
        character(len=20) :: compression_type = "gzip"  ! "gzip", "blosc", "lz4"

        ! Configuración de procesamiento
        integer :: num_threads = 1         ! Para compatibilidad (no usado en main)
        integer :: block_size = 8000       ! Tamaño de bloque para matrices grandes

        ! Propiedades calculadas
        integer :: n_dof = 0
    end type simulation_config

contains

    ! -------------------------------------------------------------------------
    ! Leer archivo de configuración
    ! -------------------------------------------------------------------------
    subroutine read_config_file(filename, config)
        character(len=*), intent(in) :: filename
        type(simulation_config), intent(out) :: config

        integer :: unit, ios
        character(len=200) :: line, key, value
        integer :: eq_pos

        ! Valores por defecto
        config = simulation_config()

        open(newunit=unit, file=filename, status='old', iostat=ios)
        if (ios /= 0) then
            write(*,*) '⚠️  No se puede abrir ', trim(filename), '. Usando valores por defecto.'
            config%n_dof = config%n_nodes * config%dof_per_node
            return
        end if

        write(*,*) '📖 Leyendo configuración: ', trim(filename)

        do
            read(unit, '(A)', iostat=ios) line
            if (ios /= 0) exit

            ! Ignorar comentarios y líneas vacías
            line = adjustl(line)
            if (len_trim(line) == 0 .or. line(1:1) == '#') cycle

            ! Buscar '='
            eq_pos = index(line, '=')
            if (eq_pos == 0) cycle

            key = trim(adjustl(line(1:eq_pos-1)))
            value = trim(adjustl(line(eq_pos+1:)))

            ! Eliminar comentarios al final de línea (después de #)
            if (index(value, '#') > 0) then
                value = trim(value(1:index(value, '#')-1))
            end if

            ! Procesar parámetros
            call process_parameter(key, value, config)
        end do

        close(unit)

        ! Calcular DOF total
        config%n_dof = config%n_nodes * config%dof_per_node

        ! Mostrar configuración leída
        call print_config(config)

    end subroutine read_config_file

    ! -------------------------------------------------------------------------
    ! Procesar un parámetro individual
    ! -------------------------------------------------------------------------
    subroutine process_parameter(key, value, config)
        character(len=*), intent(in) :: key, value
        type(simulation_config), intent(inout) :: config

        select case (trim(key))
        case ('n_nodes')
            read(value, *) config%n_nodes
        case ('dof_per_node')
            read(value, *) config%dof_per_node
        case ('bandwidth')
            read(value, *) config%bandwidth
        case ('young_modulus')
            read(value, *) config%young_modulus
        case ('poisson_ratio')
            read(value, *) config%poisson_ratio
        case ('density')
            read(value, *) config%density
        case ('thickness')
            read(value, *) config%thickness
        case ('zone1_stiffness_factor')
            read(value, *) config%zone1_stiffness_factor
        case ('zone1_mass_factor')
            read(value, *) config%zone1_mass_factor
        case ('zone2_stiffness_factor')
            read(value, *) config%zone2_stiffness_factor
        case ('zone2_mass_factor')
            read(value, *) config%zone2_mass_factor
        case ('zone3_stiffness_factor')
            read(value, *) config%zone3_stiffness_factor
        case ('zone3_mass_factor')
            read(value, *) config%zone3_mass_factor
        case ('output_file')
            ! Remover comillas si existen
            if (value(1:1) == '"' .and. value(len_trim(value):len_trim(value)) == '"') then
                config%output_file = trim(value(2:len_trim(value)-1))
            else
                config%output_file = trim(value)
            end if
        case ('compression_level')
            read(value, *) config%compression_level
        case ('compression_type')
            config%compression_type = trim(value)
        case ('num_threads')
            read(value, *) config%num_threads  ! Para compatibilidad
        case ('block_size')
            read(value, *) config%block_size
        end select
    end subroutine process_parameter

    ! -------------------------------------------------------------------------
    ! Mostrar configuración actual
    ! -------------------------------------------------------------------------
    subroutine print_config(config)
        type(simulation_config), intent(in) :: config

        write(*,'(A60)')            '============================================================'
        write(*,'(A60)')            '                    CONFIGURACIÓN CARGADA                   '
        write(*,'(A60)')            '============================================================'
        write(*,'(A,T17,A)')        'Archivo salida:', trim(config%output_file)
        write(*,'(A,T17,I8)')       'Nodos:',          config%n_nodes
        write(*,'(A,T17,I8)')       'DOF por nodo:',   config%dof_per_node
        write(*,'(A,T17,I8)')       'DOF totales:',    config%n_dof
        write(*,'(A,T17,I8)')       'Ancho de banda:', config%bandwidth
        write(*,'(A,T23,ES12.4,A)') 'Módulo Young:',   config%young_modulus, ' Pa'
        write(*,'(A,T23,ES11.4,A)') 'Densidad:',       config%density, ' kg/m³'
        write(*,'(A,T17,I8)')       'Threads:',        config%num_threads
        write(*,'(A,T18,F10.2,A)')  'Memoria aprox:',  (real(config%n_dof,8)**2 * 8.0d0) / (1024.0d0**3), ' GB'
        write(*,'(A60)')            '============================================================'
    end subroutine print_config

end module config_reader
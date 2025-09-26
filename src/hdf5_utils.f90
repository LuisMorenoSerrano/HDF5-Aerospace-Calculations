! =============================================================================
! Módulo HDF5_Utils - Utilidades para manejo eficiente de HDF5
! Autor: Generado por AI para cálculos aeroespaciales masivos
! =============================================================================
module hdf5_utils
    use hdf5  ! fortls: ignore-line
    implicit none

    private
    public :: init_hdf5, close_hdf5, create_hdf5_file, open_hdf5_file, close_hdf5_file
    public :: write_matrix_real8, read_matrix_real8, write_vector_real8, read_vector_real8
    public :: create_group_if_needed
    ! Re-exportar tipos de HDF5
    public :: HID_T, HSIZE_T

    ! Tipos de datos para metadatos
    type, public :: simulation_metadata
        character(len=100) :: case_name
        character(len=50) :: analysis_type
        integer :: n_elements
        integer :: n_nodes
        real(8) :: time_step
        real(8) :: total_time
        character(len=20) :: date_created
    end type simulation_metadata

contains

    ! -------------------------------------------------------------------------
    ! Inicializar HDF5
    ! -------------------------------------------------------------------------
    subroutine init_hdf5()
        integer :: error
        call h5open_f(error)
        if (error /= 0) then
            write(*,*) 'ERROR: No se pudo inicializar HDF5'
            stop
        endif
    end subroutine init_hdf5

    ! -------------------------------------------------------------------------
    ! Cerrar HDF5
    ! -------------------------------------------------------------------------
    subroutine close_hdf5()
        integer :: error
        call h5close_f(error)
    end subroutine close_hdf5

    ! -------------------------------------------------------------------------
    ! Crear archivo HDF5
    ! -------------------------------------------------------------------------
    subroutine create_hdf5_file(filename, file_id)
        character(len=*), intent(in) :: filename
        integer(HID_T), intent(out) :: file_id
        integer :: error

        call h5fcreate_f(filename, H5F_ACC_TRUNC_F, file_id, error)
        if (error /= 0) then
            write(*,*) 'ERROR: No se pudo crear el archivo ', trim(filename)
            stop
        endif
    end subroutine create_hdf5_file

    ! -------------------------------------------------------------------------
    ! Abrir archivo HDF5 existente
    ! -------------------------------------------------------------------------
    subroutine open_hdf5_file(filename, file_id)
        character(len=*), intent(in) :: filename
        integer(HID_T), intent(out) :: file_id
        integer :: error

        call h5fopen_f(filename, H5F_ACC_RDONLY_F, file_id, error)
        if (error /= 0) then
            write(*,*) 'ERROR: No se pudo abrir el archivo ', trim(filename)
            stop
        endif
    end subroutine open_hdf5_file

    ! -------------------------------------------------------------------------
    ! Cerrar archivo HDF5
    ! -------------------------------------------------------------------------
    subroutine close_hdf5_file(file_id)
        integer(HID_T), intent(in) :: file_id
        integer :: error
        call h5fclose_f(file_id, error)
    end subroutine close_hdf5_file

    ! -------------------------------------------------------------------------
    ! Crear grupo si no existe
    ! -------------------------------------------------------------------------
    subroutine create_group_if_needed(file_id, group_path)
        integer(HID_T), intent(in) :: file_id
        character(len=*), intent(in) :: group_path

        integer(HID_T) :: group_id
        integer :: error
        logical :: exists

        ! Verificar si el grupo existe
        call h5lexists_f(file_id, group_path, exists, error)

        if (.not. exists) then
            ! Crear el grupo
            call h5gcreate_f(file_id, group_path, group_id, error)
            call h5gclose_f(group_id, error)
        endif
    end subroutine create_group_if_needed

    ! -------------------------------------------------------------------------
    ! Escribir matriz real(8) con compresión
    ! -------------------------------------------------------------------------
    subroutine write_matrix_real8(file_id, dataset_name, matrix)
        integer(HID_T), intent(in) :: file_id
        character(len=*), intent(in) :: dataset_name
        real(8), intent(in) :: matrix(:,:)

        integer(HID_T) :: dset_id, dspace_id, plist_id
        integer(HSIZE_T) :: dims(2), chunk_dims(2)
        integer :: error
        integer :: slash_pos
        character(len=256) :: group_path

        dims = shape(matrix)

        ! Crear grupo padre si es necesario
        slash_pos = index(dataset_name, '/', back=.true.)
        if (slash_pos > 1) then
            group_path = dataset_name(1:slash_pos-1)
            call create_group_if_needed(file_id, group_path)
        endif

        ! Crear dataspace
        call h5screate_simple_f(2, dims, dspace_id, error)

        ! Configurar compresión (chunking + gzip)
        call h5pcreate_f(H5P_DATASET_CREATE_F, plist_id, error)
        chunk_dims = min(dims, [1000_HSIZE_T, 1000_HSIZE_T])  ! Chunks óptimos
        call h5pset_chunk_f(plist_id, 2, chunk_dims, error)
        call h5pset_deflate_f(plist_id, 6, error)  ! Compresión nivel 6

        ! Crear dataset
        call h5dcreate_f(file_id, dataset_name, H5T_NATIVE_DOUBLE, dspace_id, &
                        dset_id, error, plist_id)

        ! Escribir datos
        call h5dwrite_f(dset_id, H5T_NATIVE_DOUBLE, matrix, dims, error)

        ! Limpiar
        call h5pclose_f(plist_id, error)
        call h5dclose_f(dset_id, error)
        call h5sclose_f(dspace_id, error)
    end subroutine write_matrix_real8

    ! -------------------------------------------------------------------------
    ! Leer matriz real(8)
    ! -------------------------------------------------------------------------
    subroutine read_matrix_real8(file_id, dataset_name, matrix)
        integer(HID_T), intent(in) :: file_id
        character(len=*), intent(in) :: dataset_name
        real(8), allocatable, intent(out) :: matrix(:,:)

        integer(HID_T) :: dset_id, dspace_id
        integer(HSIZE_T) :: dims(2), maxdims(2)
        integer :: error

        ! Abrir dataset
        call h5dopen_f(file_id, dataset_name, dset_id, error)

        ! Obtener dataspace y dimensiones
        call h5dget_space_f(dset_id, dspace_id, error)
        call h5sget_simple_extent_dims_f(dspace_id, dims, maxdims, error)

        ! Allocar matriz
        allocate(matrix(dims(1), dims(2)))

        ! Leer datos
        call h5dread_f(dset_id, H5T_NATIVE_DOUBLE, matrix, dims, error)

        ! Limpiar
        call h5sclose_f(dspace_id, error)
        call h5dclose_f(dset_id, error)
    end subroutine read_matrix_real8

    ! -------------------------------------------------------------------------
    ! Escribir vector real(8)
    ! -------------------------------------------------------------------------
    subroutine write_vector_real8(file_id, dataset_name, vector)
        integer(HID_T), intent(in) :: file_id
        character(len=*), intent(in) :: dataset_name
        real(8), intent(in) :: vector(:)

        integer(HID_T) :: dset_id, dspace_id, plist_id
        integer(HSIZE_T) :: dims(1), chunk_dims(1)
        integer :: error, rank = 1
        integer :: slash_pos
        character(len=256) :: group_path

        dims(1) = size(vector)

        ! Crear grupo padre si es necesario
        slash_pos = index(dataset_name, '/', back=.true.)
        if (slash_pos > 1) then
            group_path = dataset_name(1:slash_pos-1)
            call create_group_if_needed(file_id, group_path)
        endif

        ! Crear dataspace
        call h5screate_simple_f(rank, dims, dspace_id, error)

        ! Configurar compresión
        call h5pcreate_f(H5P_DATASET_CREATE_F, plist_id, error)
        chunk_dims(1) = min(dims(1), 10000_HSIZE_T)
        call h5pset_chunk_f(plist_id, rank, chunk_dims, error)
        call h5pset_deflate_f(plist_id, 6, error)

        ! Crear dataset y escribir
        call h5dcreate_f(file_id, dataset_name, H5T_NATIVE_DOUBLE, dspace_id, &
                        dset_id, error, plist_id)
        call h5dwrite_f(dset_id, H5T_NATIVE_DOUBLE, vector, dims, error)

        ! Limpiar
        call h5pclose_f(plist_id, error)
        call h5dclose_f(dset_id, error)
        call h5sclose_f(dspace_id, error)
    end subroutine write_vector_real8

    ! -------------------------------------------------------------------------
    ! Leer vector real(8)
    ! -------------------------------------------------------------------------
    subroutine read_vector_real8(file_id, dataset_name, vector)
        integer(HID_T), intent(in) :: file_id
        character(len=*), intent(in) :: dataset_name
        real(8), allocatable, intent(out) :: vector(:)

        integer(HID_T) :: dset_id, dspace_id
        integer(HSIZE_T) :: dims(1), maxdims(1)
        integer :: error

        call h5dopen_f(file_id, dataset_name, dset_id, error)
        call h5dget_space_f(dset_id, dspace_id, error)
        call h5sget_simple_extent_dims_f(dspace_id, dims, maxdims, error)

        allocate(vector(dims(1)))
        call h5dread_f(dset_id, H5T_NATIVE_DOUBLE, vector, dims, error)

        call h5sclose_f(dspace_id, error)
        call h5dclose_f(dset_id, error)
    end subroutine read_vector_real8

end module hdf5_utils
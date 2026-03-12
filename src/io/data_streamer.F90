! Copyright (c) 2020-2025, The Neko Authors
! All rights reserved.
!
! Redistribution and use in source and binary forms, with or without
! modification, are permitted provided that the following conditions
! are met:
!
!   * Redistributions of source code must retain the above copyright
!     notice, this list of conditions and the following disclaimer.
!
!   * Redistributions in binary form must reproduce the above
!     copyright notice, this list of conditions and the following
!     disclaimer in the documentation and/or other materials provided
!     with the distribution.
!
!   * Neither the name of the authors nor the names of its
!     contributors may be used to endorse or promote products derived
!     from this software without specific prior written permission.
!
! THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
! "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
! LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
! FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
! COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
! INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
! BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
! LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
! CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
! LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
! ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
! POSSIBILITY OF SUCH DAMAGE.
!
!> Implements type data_streamer_t.
module data_streamer
  use num_types, only: rp, c_rp
  use field, only: field_t
  use coefs, only: coef_t
  use utils, only: neko_warning
  use comm, only : NEKO_COMM
  use mpi_f08, only : MPI_COMM
  use, intrinsic :: iso_c_binding
  implicit none
  private

  !> Provides access to data streaming by interfacing with c++
  !! ADIOS2 subroutines.
  !! @details
  !! Adios2 is an API that allows for easy coupling of codes
  !! through data streaming and gives the posibility to perform
  !! other IO operations such as data compression, etc.
  !! This type wraps and interfaces the needed calls to allow
  !! the use of the c++ routines that ultimately expose the data
  !! from neko to any executable that counts with a proper reader.
  type, public :: data_streamer_t
     !> Define if the execution is asyncrhonous
     integer :: if_asynch
     !> global element numbers
     integer, allocatable :: lglel(:)
     integer :: id
     integer :: n_vars = 0
     integer :: n_arrays = 0
     character(len=256) :: var_names(20)
     character(len=256) :: array_names(20)

   contains
     !> Constructor
     procedure, pass(this) :: init => data_streamer_init
     !> Destructor
     procedure, pass(this) :: free => data_streamer_free
     !> Add a variable (for the moment just an int number)
     procedure, pass(this) :: add_variable => data_streamer_add_variable
     !> Stream data
     procedure, pass(this) :: stream => data_streamer_stream
     !> Stream back the data
     procedure, pass(this) :: recieve => data_streamer_recieve

  end type data_streamer_t

contains

  !> Constructor
  !! Wraps the adios2 set-up.
  !! @param coef Type that contains geometrical information
  !! on the case.
  !! @param if_asynch Controls whether the asyncrhonous executions
  !! is to be enabled.
  subroutine data_streamer_init(this, id, name, timeout_seconds)
    class(data_streamer_t), intent(inout) :: this 
    integer, intent(in) :: id
    character(len=*), intent(in), optional :: name
    integer, intent(in), optional :: timeout_seconds
    character(len=256) :: io_name
    integer :: timeout

    this%id = id

    if (present(name)) then
        io_name = name
    else
        write(io_name, '(A,I0)') 'globalArray', id
    end if

    if (present(timeout_seconds)) then
        timeout = timeout_seconds
    else
        timeout = 300
    end if

#ifdef HAVE_ADIOS2
    call fortran_adios2_initialize(NEKO_COMM, io_name, id, timeout)
#else
    call neko_warning('Is not being built with ADIOS2 support.')
    call neko_warning('Not able to use stream/compression functionality')
#endif


  end subroutine data_streamer_init

  subroutine data_streamer_add_variable(this, var_name)
    class(data_streamer_t), intent(inout) :: this
    character(len=*), intent(in) :: var_name

#ifdef HAVE_ADIOS2

    this%n_vars = this%n_vars + 1
    this%var_names(this%n_vars) = var_name

    call fortran_adios2_add_variable(var_name)
#else
    call neko_warning('Is not being built with ADIOS2 support.')
    call neko_warning('Not able to use stream/compression functionality')
#endif
  end subroutine data_streamer_add_variable

  !> Destructor
  !! wraps the adios2 finalize routine. Closes insitu writer
  subroutine data_streamer_free(this)
    class(data_streamer_t), intent(inout) :: this

#ifdef HAVE_ADIOS2
    call fortran_adios2_finalize()
#else
    call neko_warning('Is not being built with ADIOS2 support.')
    call neko_warning('Not able to use stream/compression functionality')
#endif

  end subroutine data_streamer_free

  !> streamer
  !! @param fld array of shape field%x
  subroutine data_streamer_stream(this, fld)
    class(data_streamer_t), intent(inout) :: this
    real(kind=rp), dimension(:,:,:,:), intent(inout) :: fld

#ifdef HAVE_ADIOS2
    call fortran_adios2_stream(fld)
#else
    call neko_warning('Is not being built with ADIOS2 support.')
    call neko_warning('Not able to use stream/compression functionality')
#endif

  end subroutine data_streamer_stream

  !> reciever
  !! @param fld array of shape field%x
  subroutine data_streamer_recieve(this, fld)
    class(data_streamer_t), intent(inout) :: this
    real(kind=rp), dimension(:,:,:,:), intent(inout) :: fld

#ifdef HAVE_ADIOS2
    call fortran_adios2_recieve(fld)
#else
    call neko_warning('Is not being built with ADIOS2 support.')
    call neko_warning('Not able to use stream/compression functionality')
#endif

  end subroutine data_streamer_recieve


#ifdef HAVE_ADIOS2


  subroutine fortran_adios2_initialize(comm, io_name, id, timeout_seconds)
    use, intrinsic :: iso_c_binding, only: c_char, c_null_char, c_int
    use mpi_f08, only: MPI_COMM
    implicit none

    type(MPI_COMM), intent(in) :: comm
    character(len=*), intent(in) :: io_name
    integer, intent(in) :: id
    integer, intent(in) :: timeout_seconds

    character(kind=c_char, len=:), allocatable :: io_name_c
    integer(c_int) :: id_c
    integer(c_int) :: timeout_c

    interface
      subroutine c_adios2_initialize(comm, io_name, id, timeout_seconds) &
            bind(C, name="adios2_initialize_")
        use, intrinsic :: iso_c_binding, only: c_char, c_int
        implicit none
        type(*) :: comm
        character(kind=c_char), intent(in) :: io_name(*)
        integer(c_int), intent(in) :: id
        integer(c_int), intent(in) :: timeout_seconds
      end subroutine c_adios2_initialize
    end interface

    ! Convert to plain interoperable values
    io_name_c = trim(io_name)//c_null_char
    id_c = id
    timeout_c = timeout_seconds

    call c_adios2_initialize(comm, io_name_c, id_c, timeout_c)

  end subroutine fortran_adios2_initialize


  subroutine fortran_adios2_add_variable(var_name)
    use, intrinsic :: iso_c_binding, only: c_char, c_null_char
    implicit none

    character(len=*), intent(in) :: var_name
    character(kind=c_char, len=:), allocatable :: var_name_c

    interface
      subroutine c_adios2_add_variable(var_name) &
            bind(C, name="adios2_add_variable_")
        use, intrinsic :: iso_c_binding, only: c_char
        implicit none
        character(kind=c_char), intent(in) :: var_name(*)
      end subroutine c_adios2_add_variable
    end interface

    ! Convert to plain interoperable values
    var_name_c = trim(var_name)//c_null_char

    call c_adios2_add_variable(var_name_c)

  end subroutine fortran_adios2_add_variable

  !> Interface to adios2_finalize in c++.
  !! closes any writer openned at initialization time
  subroutine fortran_adios2_finalize()
    use, intrinsic :: ISO_C_BINDING
    implicit none

    interface
       !> C-definition is: void adios2_finalize_()
       subroutine c_adios2_finalize() bind(C,name="adios2_finalize_")
         use, intrinsic :: ISO_C_BINDING
         implicit none
       end subroutine c_adios2_finalize
    end interface

    call c_adios2_finalize()
  end subroutine fortran_adios2_finalize

  !> Interface to adios2_stream in c++.
  !! @details This routine communicates the data to a global array that
  !! is accessed by a data processor. The operations do not write to disk.
  !! data is communicated with mpi.
  !! @param fld array of shape field%x
  subroutine fortran_adios2_stream(fld)
    use, intrinsic :: ISO_C_BINDING
    implicit none
    real(kind=rp), dimension(:,:,:,:), intent(inout) :: fld

    interface
       !> C-definition is: void adios2_stream_(const double *fld)
       subroutine c_adios2_stream(fld) &
                                  bind(C,name="adios2_stream_")
         use, intrinsic :: ISO_C_BINDING
         import c_rp
         implicit none
         real(kind=c_rp), intent(INOUT) :: fld(*)
       end subroutine c_adios2_stream
    end interface

    call c_adios2_stream(fld)
  end subroutine fortran_adios2_stream

  !> Interface to adios2_recieve in ci++.
  !! @details This routine communicates the data to a global array that
  !! is accessed by a data processor. The operations do not write to disk.
  !! data is communicated with mpi.
  !! @param fld array of shape field%x
  subroutine fortran_adios2_recieve(fld)
    use, intrinsic :: ISO_C_BINDING
    implicit none
    real(kind=rp), dimension(:,:,:,:), intent(inout) :: fld

    interface
       !> C-definition is: void adios2_stream_(const double *fld)
       subroutine c_adios2_recieve(fld) &
                                  bind(C,name="adios2_recieve_")
         use, intrinsic :: ISO_C_BINDING
         import c_rp
         implicit none
         real(kind=c_rp), intent(INOUT) :: fld(*)
       end subroutine c_adios2_recieve
    end interface

    call c_adios2_recieve(fld)
  end subroutine fortran_adios2_recieve

#endif

end module data_streamer

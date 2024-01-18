module drag_torque
  use field, only: field_t
  use coefs, only: coef_t
  use mesh
  use facet_zone
  use comm
  use math
  use space, only: space_t
  use num_types, only: rp
  use operators
  implicit none
  private
  !> Some functions to calculatye the lift/drag and torque
  !! Calculation can be done on a zone, a facet, or a point
  !! Currently everything is CPU only
  public :: drag_torque_zone, drag_torque_facet, drag_torque_pt

contains
  !> Calculate drag and torque over a zone.
  !! @param dgtq, the computed drag and torque
  !! @param tstep, the time step
  !! @param zone, the zone which we compute the drag and toqure over
  !! @param center, the point around which we calculate the torque
  !! @param s11-s23, the strain rate tensor
  !! @param p, the pressure
  !! @param coef, coefficents
  !! @param visc, the viscosity
  subroutine drag_torque_zone(dgtq, tstep, zone, center, s11, s22, s33, s12, s13, s23,&
                              p, coef, visc)
    integer, intent(in) :: tstep
    type(facet_zone_t) :: zone
    type(coef_t), intent(inout) :: coef
    real(kind=rp), intent(inout) :: s11(coef%Xh%lx,coef%Xh%lx,coef%Xh%lz,coef%msh%nelv)
    real(kind=rp), intent(inout) :: s22(coef%Xh%lx,coef%Xh%lx,coef%Xh%lz,coef%msh%nelv)
    real(kind=rp), intent(inout) :: s33(coef%Xh%lx,coef%Xh%lx,coef%Xh%lz,coef%msh%nelv)
    real(kind=rp), intent(inout) :: s12(coef%Xh%lx,coef%Xh%lx,coef%Xh%lz,coef%msh%nelv)
    real(kind=rp), intent(inout) :: s13(coef%Xh%lx,coef%Xh%lx,coef%Xh%lz,coef%msh%nelv)
    real(kind=rp), intent(inout) :: s23(coef%Xh%lx,coef%Xh%lx,coef%Xh%lz,coef%msh%nelv)
    type(field_t), intent(inout) :: p
    real(kind=rp), intent(in) :: visc, center(3)
    real(kind=rp) :: dgtq(3,4)
    real(kind=rp) :: dragpx = 0.0_rp ! pressure 
    real(kind=rp) :: dragpy = 0.0_rp
    real(kind=rp) :: dragpz = 0.0_rp
    real(kind=rp) :: dragvx = 0.0_rp ! viscous
    real(kind=rp) :: dragvy = 0.0_rp
    real(kind=rp) :: dragvz = 0.0_rp
    real(kind=rp) :: torqpx = 0.0_rp ! pressure 
    real(kind=rp) :: torqpy = 0.0_rp
    real(kind=rp) :: torqpz = 0.0_rp
    real(kind=rp) :: torqvx = 0.0_rp ! viscous
    real(kind=rp) :: torqvy = 0.0_rp
    real(kind=rp) :: torqvz = 0.0_rp
    real(kind=rp) :: dragx, dragy, dragz
    real(kind=rp) :: torqx, torqy, torqz
    integer :: ie, ifc, mem, ierr
    dragx = 0.0
    dragy = 0.0
    dragz = 0.0

!
!     Fill up viscous array w/ default
!
      dragpx = 0.0
      dragpy = 0.0
      dragpz = 0.0
      dragvx = 0.0
      dragvy = 0.0
      dragvz = 0.0
      do mem  = 1,zone%size
         ie   = zone%facet_el(mem)%x(2)
         ifc   = zone%facet_el(mem)%x(1)
         call drag_torque_facet(dgtq,coef%dof%x,coef%dof%y,coef%dof%z,&
                                center,&
                                s11, s22, s33, s12, s13, s23,&
                                p%x,visc,ifc,ie, coef, coef%Xh)

         dragpx = dragpx + dgtq(1,1)  ! pressure 
         dragpy = dragpy + dgtq(2,1)
         dragpz = dragpz + dgtq(3,1)

         dragvx = dragvx + dgtq(1,2)  ! viscous
         dragvy = dragvy + dgtq(2,2)
         dragvz = dragvz + dgtq(3,2)

         torqpx = torqpx + dgtq(1,3)  ! pressure 
         torqpy = torqpy + dgtq(2,3)
         torqpz = torqpz + dgtq(3,3)

         torqvx = torqvx + dgtq(1,4)  ! viscous
         torqvy = torqvy + dgtq(2,4)
         torqvz = torqvz + dgtq(3,4)
      enddo
!
!     Sum contributions from all processors
!
      call MPI_Allreduce(MPI_IN_PLACE,dragpx, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)
      call MPI_Allreduce(MPI_IN_PLACE,dragpy, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)
      call MPI_Allreduce(MPI_IN_PLACE,dragpz, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)
      call MPI_Allreduce(MPI_IN_PLACE,dragvx, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)
      call MPI_Allreduce(MPI_IN_PLACE,dragvy, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)
      call MPI_Allreduce(MPI_IN_PLACE,dragvz, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)
      !Torque
      call MPI_Allreduce(MPI_IN_PLACE,torqpx, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)
      call MPI_Allreduce(MPI_IN_PLACE,torqpy, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)
      call MPI_Allreduce(MPI_IN_PLACE,torqpz, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)
      call MPI_Allreduce(MPI_IN_PLACE,torqvx, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)
      call MPI_Allreduce(MPI_IN_PLACE,torqvy, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)
      call MPI_Allreduce(MPI_IN_PLACE,torqvz, 1, &
         MPI_REAL_PRECISION, MPI_SUM, NEKO_COMM, ierr)

      dgtq(1,1) = dragpx  ! pressure 
      dgtq(2,1) = dragpy
      dgtq(3,1) = dragpz
               
      dgtq(1,2) = dragvx  ! viscous
      dgtq(2,2) = dragvy
      dgtq(3,2) = dragvz
               
      dgtq(1,3) = torqpx  ! pressure 
      dgtq(2,3) = torqpy
      dgtq(3,3) = torqpz
               
      dgtq(1,4) = torqvx  ! viscous
      dgtq(2,4) = torqvy
      dgtq(3,4) = torqvz

  end subroutine drag_torque_zone

  !> Calculate drag and torque over a facet.
  !! @param dgtq, the computed drag and torque
  !! @param tstep, the time step
  !! @param xm0, the x coords
  !! @param ym0, the y coords
  !! @param zm0, the z coords
  !! @param center, the point around which we calculate the torque
  !! @param s11-s23, the strain rate tensor
  !! @param p, the pressure
  !! @param coef, coefficents
  !! @param visc, the viscosity
  subroutine drag_torque_facet(dgtq,xm0,ym0,zm0, center,&
                               s11, s22, s33, s12, s13, s23,&
                               pm1,visc,f,e, coef, Xh)
    type(coef_t) :: coef 
    type(space_t) :: Xh
    real(kind=rp) :: dgtq(3,4), dgtq_i(3,4), center(3)
    real(kind=rp) :: xm0 (Xh%lx,xh%ly,Xh%lz,coef%msh%nelv)
    real(kind=rp) :: ym0 (Xh%lx,xh%ly,Xh%lz,coef%msh%nelv)
    real(kind=rp) :: zm0 (Xh%lx,xh%ly,Xh%lz,coef%msh%nelv)
    real(kind=rp) :: s11 (Xh%lx,xh%ly,Xh%lz,coef%msh%nelv)
    real(kind=rp) :: s22 (Xh%lx,xh%ly,Xh%lz,coef%msh%nelv)
    real(kind=rp) :: s33 (Xh%lx,xh%ly,Xh%lz,coef%msh%nelv)
    real(kind=rp) :: s12 (Xh%lx,xh%ly,Xh%lz,coef%msh%nelv)
    real(kind=rp) :: s13 (Xh%lx,xh%ly,Xh%lz,coef%msh%nelv)
    real(kind=rp) :: s23 (Xh%lx,xh%ly,Xh%lz,coef%msh%nelv)
    real(kind=rp) :: pm1 (Xh%lx,xh%ly,Xh%lz,coef%msh%nelv)
    real(kind=rp) :: visc
    integer :: f,e,pf,l, k, i, j1, j2
    real(kind=rp) ::    n1,n2,n3, j, a, r1, r2, r3, v
    integer :: skpdat(6,6), NX, NY, NZ
    integer :: js1   
    integer :: jf1   
    integer :: jskip1
    integer :: js2   
    integer :: jf2   
    integer :: jskip2
    real(kind=rp) :: s11_, s21_, s31_, s12_, s22_, s32_, s13_, s23_, s33_


    NX = Xh%lx
    NY = Xh%ly
    NZ = Xh%lz
    SKPDAT(1,1)=1
    SKPDAT(2,1)=NX*(NY-1)+1
    SKPDAT(3,1)=NX
    SKPDAT(4,1)=1
    SKPDAT(5,1)=NY*(NZ-1)+1
    SKPDAT(6,1)=NY

    SKPDAT(1,2)=1             + (NX-1)
    SKPDAT(2,2)=NX*(NY-1)+1   + (NX-1)
    SKPDAT(3,2)=NX
    SKPDAT(4,2)=1
    SKPDAT(5,2)=NY*(NZ-1)+1
    SKPDAT(6,2)=NY

    SKPDAT(1,3)=1
    SKPDAT(2,3)=NX
    SKPDAT(3,3)=1
    SKPDAT(4,3)=1
    SKPDAT(5,3)=NY*(NZ-1)+1
    SKPDAT(6,3)=NY

    SKPDAT(1,4)=1           + NX*(NY-1)
    SKPDAT(2,4)=NX          + NX*(NY-1)
    SKPDAT(3,4)=1
    SKPDAT(4,4)=1
    SKPDAT(5,4)=NY*(NZ-1)+1
    SKPDAT(6,4)=NY

    SKPDAT(1,5)=1
    SKPDAT(2,5)=NX
    SKPDAT(3,5)=1
    SKPDAT(4,5)=1
    SKPDAT(5,5)=NY
    SKPDAT(6,5)=1

    SKPDAT(1,6)=1           + NX*NY*(NZ-1)
    SKPDAT(2,6)=NX          + NX*NY*(NZ-1)
    SKPDAT(3,6)=1
    SKPDAT(4,6)=1
    SKPDAT(5,6)=NY
    SKPDAT(6,6)=1
    pf = f
    js1    = skpdat(1,pf)
    jf1    = skpdat(2,pf)
    jskip1 = skpdat(3,pf)
    js2    = skpdat(4,pf)
    jf2    = skpdat(5,pf)
    jskip2 = skpdat(6,pf)
    call rzero(dgtq,12)
    i = 0
    a = 0
    do j2=js2,jf2,jskip2
       do j1=js1,jf1,jskip1
         i = i+1
         n1 = coef%nx(i,1,f,e)*coef%area(i,1,f,e)
         n2 = coef%ny(i,1,f,e)*coef%area(i,1,f,e)
         n3 = coef%nz(i,1,f,e)*coef%area(i,1,f,e)
         a  = a +          coef%area(i,1,f,e)
         v  = visc
         s11_ = s11(j1,j2,1,e)
         s12_ = s12(j1,j2,1,e)
         s22_ = s22(j1,j2,1,e)
         s13_ = s13(j1,j2,1,e)
         s23_ = s23(j1,j2,1,e)
         s33_ = s33(j1,j2,1,e)
         call drag_torque_pt(dgtq_i,xm0(j1,j2,1,e), ym0(j1,j2,1,e),zm0(j1,j2,1,e), center,&
                             s11_, s22_, s33_, s12_, s13_, s23_,&
                             pm1(j1,j2,1,e), n1, n2, n3, v)
         dgtq = dgtq + dgtq_i
       end do
    end do
  end subroutine drag_torque_facet

  !> Calculate drag and torque from one point
  !! @param dgtq, the computed drag and torque
  !! @param xm0, the x coord
  !! @param ym0, the y coord
  !! @param zm0, the z coord
  !! @param center, the point around which we calculate the torque
  !! @param s11-s23, the strain rate tensor
  !! @param p, the pressure
  !! @param n1, normal vector x
  !! @param n2, normal vector y
  !! @param n3, normal vector z
  !! @param v, the viscosity
  subroutine drag_torque_pt(dgtq,x,y,z, center, s11, s22, s33, s12, s13, s23,&
                            p,n1, n2, n3,v)
    real(kind=rp), intent(inout) :: dgtq(3,4)
    real(kind=rp), intent(in) :: x 
    real(kind=rp), intent(in) :: y
    real(kind=rp), intent(in) :: z
    real(kind=rp), intent(in) :: p
    real(kind=rp), intent(in) :: v
    real(kind=rp), intent(in) :: n1, n2, n3, center(3)
    real(kind=rp), intent(in) :: s11, s12, s22, s13, s23, s33
    real(kind=rp) ::  s21, s31, s32, r1, r2, r3 
    call rzero(dgtq,12)
    s21 = s12
    s32 = s23
    s31 = s13
    !pressure drag
    dgtq(1,1) = p*n1  
    dgtq(2,1) = p*n2
    dgtq(3,1) = p*n3
    ! viscous drag
    dgtq(1,2) = -v*(s11*n1 + s12*n2 + s13*n3)
    dgtq(2,2) = -v*(s21*n1 + s22*n2 + s23*n3)
    dgtq(3,2) = -v*(s31*n1 + s32*n2 + s33*n3)
    r1 = x-center(1)
    r2 = y-center(2)
    r3 = z-center(3)
    !pressure torque
    dgtq(1,3) = (r2*dgtq(3,1)-r3*dgtq(2,1)) 
    dgtq(2,3) = (r3*dgtq(1,1)-r1*dgtq(3,1))
    dgtq(3,3) = (r1*dgtq(2,1)-r2*dgtq(1,1))
    !viscous torque
    dgtq(1,4) = (r2*dgtq(3,2)-r3*dgtq(2,2))
    dgtq(2,4) = (r3*dgtq(1,2)-r1*dgtq(3,2)) 
    dgtq(3,4) = (r1*dgtq(2,2)-r2*dgtq(1,2))
  end subroutine drag_torque_pt

end module drag_torque

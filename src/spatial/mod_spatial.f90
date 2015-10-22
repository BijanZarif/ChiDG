module mod_spatial
#include <messenger.h>
    use mod_kinds,          only: rk,ik
    use mod_constants,      only: NFACES, DIAG
    use type_chidg_data,    only: chidg_data_t
    use type_timer,         only: timer_t

    implicit none


contains

    subroutine update_space(data,timing,info)
        implicit none
        type(chidg_data_t), intent(inout)   :: data
        real(rk),           optional        :: timing
        integer(ik),        optional        :: info

        type(timer_t)               :: timer
        integer(ik)                 :: nelem, nflux, ndonors
        integer(ik)                 :: idom, ielem, iface, iblk, idonor, iflux, i, ibc
        logical                     :: skip = .false.
        logical                     :: interior_face         = .false.
        logical                     :: chimera_face          = .false.
        logical                     :: compute_face_interior = .false.
        logical                     :: compute_face_chimera  = .false.


        !
        ! Start timer on spatial discretization update
        !
        call timer%start()


            !------------------------------------------------------------------------------------------
            !                                      Interior Scheme
            !------------------------------------------------------------------------------------------

            !
            ! Loop through given element and neighbors and compute the corresponding linearization
            !
            ! CHIMERA, XI_MIN, XI_MAX, ETA_MIN, ETA_MAX, ZETA_MIN, ZETA_MAX, DIAG
            !
            do iblk = 0,7           ! (0 = linearization of chimera blocks, 1-6 = linearization of interior neighbor blocks, 7 = linearization of Q- block


                !
                ! Loop through local domains
                !
                do idom = 1,data%ndomains
                    associate ( mesh => data%mesh(idom), sdata => data%sdata, eqnset => data%eqnset(idom)%item, prop => data%eqnset(idom)%item%prop, chimera => data%mesh(idom)%chimera)

                    nelem = mesh%nelem

                    !
                    ! Loop through elements in the current domain
                    !
                    do ielem = 1,nelem


                        !
                        ! If the block direction is DIAG, then we want to compute all valid faces with neighbors.
                        ! If the block direction is not DIAG, then we only want to compute faces in the block direction
                        ! if it has a neighbor element.
                        !
                        if (iblk /= DIAG  .and. iblk /= 0) then
                            ! Check if there is an element to linearize against in the iblk direction. If not, cycle
                            if (mesh%faces(ielem,iblk)%ineighbor == 0) then
                                skip = .true.
                            else
                                skip = .false.
                            end if
                        else
                            skip = .false.  ! Don't skip DIAG, or Chimera blocks(iblk = 0)
                        end if




                        !-----------------------------------------------------------------------------------------
                        if ( .not. skip) then
                            !
                            ! Faces loop. For the current element, compute the contributions from boundary integrals
                            !
                            do iface = 1,NFACES

                                associate ( face => mesh%faces(ielem,iface) )

                                !
                                ! Only call the following routines for interior faces -- ftype == 0
                                ! Furthermore, only call the routines if we are computing derivatives for the neighbor of
                                ! iface or for the current element(DIAG). This saves a lot of unnecessary compute_boundary calls.
                                !
                                interior_face = ( mesh%faces(ielem,iface)%ftype == 0 )
                                chimera_face  = ( mesh%faces(ielem,iface)%ftype == 2 )
                                compute_face_interior = ( interior_face .and. (iblk == iface .or. iblk == DIAG) )
                                compute_face_chimera  = ( chimera_face  .and. (iblk == 0     .or. iblk == DIAG) )

                                if ( compute_face_interior .or. compute_face_chimera ) then



                                    !
                                    ! If Chimera face, how many donor elements are there that need the linearization computed
                                    !
                                    !if ( chimera_face ) then
                                    !    ichimera_recv = face%ichimera_recv
                                    !    ndonors       = chimera%recv(ichimera_recv)
                                    !else
                                        ndonors = 1
                                    !end if


                                    !
                                    ! Test ndonors > 0
                                    !
                                    if (ndonors == 0) call signal(FATAL,'update_residual: no available donors for boundary calculation')



                                    !
                                    ! Call all boundary advective flux components
                                    !
                                    if (allocated(eqnset%boundary_advective_flux)) then
                                        nflux = size(eqnset%boundary_advective_flux)
                                        do iflux = 1,nflux

                                            !
                                            ! Compute boundary flux once for each donor. For interior faces ndonors == 1. For Chimera faces ndonors is potentially > 1.
                                            !
                                            do idonor = 1,ndonors
                                                call eqnset%boundary_advective_flux(iflux)%flux%compute(data%mesh,data%sdata,prop,idom,ielem,iface,iblk,idonor)
                                            end do

                                        end do
                                    end if

                                end if



                                end associate

                            end do  ! faces loop
                            



                            !
                            ! Call all volume advective flux components
                            !

                            ! only need to compute volume_advective_flux for linearization of interior block
                            if (iblk == DIAG) then
                                if (allocated(eqnset%volume_advective_flux)) then
                                    nflux = size(eqnset%volume_advective_flux)
                                    do iflux = 1,nflux

                                        call eqnset%volume_advective_flux(iflux)%flux%compute(data%mesh,data%sdata,prop,idom,ielem,iblk)

                                    end do
                                end if
                            end if



                        end if ! skip
                        !-----------------------------------------------------------------------------------------

                    end do  ! ielem

                    end associate
                end do  ! idom

            end do  ! iblk






            !------------------------------------------------------------------------------------------
            !                                      Boundary Scheme
            !------------------------------------------------------------------------------------------

            !
            ! Boundary conditions
            !
            ! For boundary conditions, the linearization only depends on Q-, which is the solution vector
            ! for the interior element. So, we only need to compute derivatives for the interior element (DIAG)
            iblk = 7    !> DIAG
            do idom = 1,data%ndomains
                call data%bcset(idom)%apply(data%mesh,data%sdata,data%eqnset(idom)%item%prop,idom,iblk)
            end do








            call timer%stop()
            call timer%report('Spatial Discretization Time')
            if (present(timing)) then
                timing = timer%elapsed()
            end if


    end subroutine




























end module mod_spatial

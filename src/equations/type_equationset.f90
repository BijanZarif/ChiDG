module type_equationset
#include <messenger.h>
    use mod_kinds,                  only: rk,ik
    use type_equation,              only: equation_t
    use type_properties,            only: properties_t
    use type_boundary_flux_wrapper, only: boundary_flux_wrapper_t
    use type_volume_flux_wrapper,   only: volume_flux_wrapper_t
    use atype_volume_flux,          only: volume_flux_t
    use atype_boundary_flux,        only: boundary_flux_t
    implicit none
    private



    !> Abstract equation-set type. Can be extended to implement a concrete equation set.
    !!   - Contains name and number of equations.
    !!   - Contains properties type with equations and material(ex. fluid) properties and definitions
    !!   - Contains arrays of flux components
    !!
    !!   @author Nathan A. Wukie
    !!
    !-------------------------------------------------------------------------------------------------
    type, public, abstract :: equationset_t
        character(100)              :: name     ! TODO: change this to allocatable
        integer(ik)                 :: neqns

        ! Equation set properties
        class(properties_t), allocatable    :: prop


        ! Array of boundary flux functions
        ! TODO: Extend for diffusive fluxes
        type(boundary_flux_wrapper_t),  allocatable   :: boundary_advective_flux(:)
        !type(boundary_flux_wrapper_t),  allocatable   :: boundary_diffusive_flux(:)
        type(volume_flux_wrapper_t),    allocatable   :: volume_advective_flux(:)
        !type(volume_flux_wrapper_t),    allocatable   :: volume_diffusive_flux(:) 

        ! Array of volume source functions
        ! TODO: Extend for source functions
        !type(source_wrapper_t),         allocatable   :: volume_source(:)


    contains
        procedure(self_interface),     deferred  :: init


        procedure   :: add_properties
        procedure   :: add_equation
        procedure   :: add_volume_advective_flux
        procedure   :: add_boundary_advective_flux

    end type equationset_t
    !**************************************************************************************************







    !> Interface definitions
    abstract interface
        subroutine self_interface(self)
            import equationset_t
            class(equationset_t), intent(inout) :: self
        end subroutine
    end interface


contains




    !> Add equationset%properties component
    !!
    !!   @author Nathan A. Wukie
    !!
    !!   @param[in]  prop    properties_t class to be added
    !!
    !---------------------------------------------------------------------------------------------------------------------------
    subroutine add_properties(self,prop)
        class(equationset_t),   intent(inout)   :: self
        class(properties_t),    intent(in)      :: prop
    
        integer(ik)     :: ierr

        if (allocated(self%prop)) then
            !
            ! If self%prop is already allocated, that is strange since only one is allowed per eqnset. Warn it is being replaced.
            !
            call chidg_signal(WARN,"equationset%add_properties: properties component was already allocated. Replacing current definition with incoming component.")

            !
            ! Deallocate current component.
            !
            deallocate(self%prop)

        end if


        !
        ! Allocate properties component
        !
        allocate(self%prop, source=prop, stat=ierr)
        if (ierr /= 0) call AllocationError


    end subroutine add_properties
    !*****************************************************************************************************************************

















    !> Procedure to adding equations to the equation set properties
    !!
    !!   @author Nathan A. Wukie
    !!
    !!   @param[in]  varstring   String defining the variable associated with the equation being added
    !!   @param[in]  varindex    The index of the equation in the given set. 
    !!
    !-----------------------------------------------------------------------------------------------------------------------------
    subroutine add_equation(self,varstring,varindex)
        class(equationset_t),   intent(inout)  :: self
        character(*),           intent(in)     :: varstring
        integer(ik),            intent(in)     :: varindex

        type(equation_t), allocatable    :: temp(:)
        integer(ik) :: ieq, ierr



        ! Check that properties storage has been allocated
        if (.not. allocated(self%prop)) call chidg_signal(FATAL,"Properties storage has not yet been allocated in the Equation Set. This must be done before adding equations since they are stored in the properties component")




        !
        ! If there are already equations allocated, reallocate and add new equation
        !
        if (allocated(self%prop%eqns)) then
            !
            ! Allocate temp eqn array with one extra slot for new eqn
            !
            allocate(temp(size(self%prop%eqns) + 1), stat=ierr)
            if (ierr /= 0) call AllocationError

            !
            ! Copy current eqns to first temp slots
            !
            do ieq = 1,size(self%prop%eqns)
                temp(ieq) = self%prop%eqns(ieq)
            end do


            !
            ! Add new eqn to last slot
            !
            temp(size(temp))%name = varstring
            temp(size(temp))%ind  = varindex


            !
            ! Store temp equation array to equation properties
            !
            self%prop%eqns = temp

        !
        ! If there are no equations allocated, allocate one slot and set data
        !
        else
            !
            ! Allocate equation
            !
            allocate(self%prop%eqns(1), stat=ierr)
            if (ierr /= 0) call AllocationError

            self%prop%eqns(1)%name = varstring
            self%prop%eqns(1)%ind  = varindex

        end if



        !
        ! Resize neqns
        !
        self%neqns = size(self%prop%eqns)

    end subroutine
    !*****************************************************************************************************************************















    !> Add components to volume_advective_flux array
    !!
    !!   @author Nathan A. Wukie
    !!
    !!   @param[in]  flux    Volume advective flux component to be added
    !!
    !-----------------------------------------------------------------------------------------------------------------------------
    subroutine add_volume_advective_flux(self,flux)
        class(equationset_t),   intent(inout)   :: self
        class(volume_flux_t),   intent(in)      :: flux
    
        class(volume_flux_wrapper_t), allocatable   :: temp(:)
        integer(ik)     :: ierr, iflux

        if (allocated(self%volume_advective_flux)) then

            !
            ! Allocate temporary flux array with one additional slot
            !
            allocate(temp(size(self%volume_advective_flux) + 1), stat=ierr)
            if (ierr /= 0) call AllocationError

            !
            ! Copy current flux components to temp array
            !
            do iflux = 1,size(self%volume_advective_flux)
                allocate(temp(iflux)%flux,source=self%volume_advective_flux(iflux)%flux, stat=ierr)
                if (ierr /= 0) call AllocationError
            end do


            !
            ! Add new flux to last slot
            !
            allocate(temp(size(temp))%flux, source=flux, stat=ierr)
            if (ierr /= 0) call AllocationError

            !
            ! Copy temp array back to equationset
            !
            self%volume_advective_flux = temp

        else
            !
            ! Allocate one slot
            !
            allocate(self%volume_advective_flux(1), stat=ierr)
            if (ierr /= 0) call AllocationError

            !
            ! Allocate flux component from source
            !
            allocate(self%volume_advective_flux(1)%flux, source=flux, stat=ierr)
            if (ierr /= 0) call AllocationError

        end if



    end subroutine add_volume_advective_flux
    !*****************************************************************************************************************************













    !> Add components to boundary_advective_flux array
    !!
    !!   @author Nathan A. Wukie
    !!
    !!   @param[in]  flux    Boundary advective flux type to be added
    !!
    !-----------------------------------------------------------------------------------------------------------------------------
    subroutine add_boundary_advective_flux(self,flux)
        class(equationset_t),   intent(inout)   :: self
        class(boundary_flux_t), intent(in)      :: flux
    
        class(boundary_flux_wrapper_t), allocatable   :: temp(:)
        integer(ik)     :: ierr, iflux

        if (allocated(self%boundary_advective_flux)) then

            !
            ! Allocate temporary flux array with one additional slot
            !
            allocate(temp(size(self%boundary_advective_flux) + 1), stat=ierr)
            if (ierr /= 0) call AllocationError


            !
            ! Copy current flux components to temp array
            !
            do iflux = 1,size(self%boundary_advective_flux)
                allocate(temp(iflux)%flux,source=self%boundary_advective_flux(iflux)%flux, stat=ierr)
                if (ierr /= 0) call AllocationError
            end do


            !
            ! Add new flux to last slot
            !
            allocate(temp(size(temp))%flux, source=flux, stat=ierr)
            if (ierr /= 0) call AllocationError

            !
            ! Copy temp array back to equationset
            !
            self%boundary_advective_flux = temp

        else

            !
            ! Allocate new slot
            !
            allocate(self%boundary_advective_flux(1), stat=ierr)
            if (ierr /= 0) call AllocationError


            !
            ! Allocate flux in new wrapper slot
            !
            allocate(self%boundary_advective_flux(1)%flux, source=flux, stat=ierr)
            if (ierr /= 0) call AllocationError

        end if



    end subroutine add_boundary_advective_flux
    !*****************************************************************************************************************************
























end module type_equationset

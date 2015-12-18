module type_blockvector
#include <messenger.h>
    use mod_kinds,          only: rk,ik
    use mod_constants,      only: DIAG, ZERO, TWO
    use type_mesh,          only: mesh_t
    use type_densevector
    use DNAD_D
    implicit none


    !> Data type for storing the matrix of dense blocks which hold the linearization for an algorithm
    !!
    !!  @author Nathan A. Wukie
    !!
    !!
    !-----------------------------------------------------------------------------------------------
    type, public :: blockvector_t
        !integer(ik)                     :: nelem_xi, nelem_eta, nelem_zeta, nelem

        !> localblocks (nelem x 7)
        !!
        !!            densevector_t
        !!
        !!  elem #1:        vec #1
        !!  elem #2:        vec #2
        !!  elem #3:        vec #3
        !!    .
        !!    .
        type(densevector_t), allocatable :: lvecs(:)                    !< Local element vectors
        integer(ik),         allocatable :: ldata(:,:)                  !< Local block data     (nvars, nterms)


    contains
        !> Initializers
        generic,   public   :: init => init_vector      !< Initialize local vector
        procedure, private  :: init_vector

        procedure, public   :: distribute               !< Given a full-vector representation, distribute it to the denseblock format
        procedure, public   :: build                    !< Assemble a full-vector representation of the blockvector_t format
        procedure, public   :: clear                    !< Zero all vector storage elements
        
        procedure, public   :: norm
        procedure, public   :: nentries
        procedure, public   :: dump


        procedure, public   :: P                        !< Return a coarsened vector


        final :: destructor
    end type blockvector_t











    !-----------------      OPERATORS       --------------------------


    public operator (*)
    interface operator (*)
        module procedure mult_real_bv   ! real * blockvector
        module procedure mult_bv_real   ! blockvector * real
    end interface



    public operator (/)
    interface operator (/)
        module procedure div_real_bv    ! real / blockvector
        module procedure div_bv_real    ! blockvector / real
    end interface


    public operator (-)
    interface operator (-)
        module procedure sub_bv_bv      ! blockvector - blockvector
    end interface


    public operator (+)
    interface operator (+)
        module procedure add_bv_bv     ! blockvector + blockvector
    end interface












    private
contains



    !> Subroutine for initializing blockvector storage
    !!
    !!  @author Nathan A. Wukie
    !!
    !!  @param[in]  mesh    mesh_t instance containing initialized elements and faces
    !!
    !-----------------------------------------------------------
    subroutine init_vector(self,mesh)
        class(blockvector_t), intent(inout), target  :: self
        class(mesh_t),        intent(in)             :: mesh

        integer(ik)                     :: nelem, nblk, ierr, ielem, iblk, size1d, parent, nterms, neqns
        logical                         :: new_elements
        type(densevector_t), pointer    :: temp(:)

        nelem = mesh%nelem  ! Number of elements in the local block

        !self%nelem_xi   = mesh%nelem_xi
        !self%nelem_eta  = mesh%nelem_eta
        !self%nelem_zeta = mesh%nelem_zeta
        !self%nelem      = mesh%nelem


        !
        ! ALLOCATE SIZE FOR 'lvecs'
        ! If vector was already allocated, deallocate and then reallocate vector size
        ! Reallocation would take place if the number of elements were changed
        !
        if (allocated(self%lvecs)) then
            !
            ! If the size is already allocated, check if the number of elements has changed.
            ! If so (new_elements), then reallocate matrix size.
            ! If not, do nothing
            !
            new_elements = (mesh%nelem /= size(self%lvecs))
            if (new_elements) then
                deallocate(self%lvecs, self%ldata)
                allocate(self%lvecs(nelem), self%ldata(nelem,2), stat=ierr)
            end if

        else
            allocate(self%lvecs(nelem), self%ldata(nelem,2), stat=ierr)

        end if
        if (ierr /= 0) call AllocationError




        !
        ! Loop through elements and call initialization for densevectors
        !
        do ielem = 1,mesh%nelem
            parent = mesh%elems(ielem)%ielem
            nterms = mesh%elems(ielem)%nterms_s
            neqns  = mesh%elems(ielem)%neqns

            ! Call densevector initialization routine
            call self%lvecs(ielem)%init(nterms,neqns,parent)

            ! Store data about number of equations and number of terms in solution expansion
            self%ldata(ielem,1) = mesh%elems(ielem)%neqns
            self%ldata(ielem,2) = mesh%elems(ielem)%nterms_s
        end do




    end subroutine














    !> Build a full-vector representation of the blockvector format
    !!
    !!  @author Nathan A. Wukie
    !!
    !!  @param[inout]   fullvec     Allocatable array for building the full-vector representation
    !-----------------------------------------------------------------------
    subroutine build(self,fullvec)
        class(blockvector_t),   intent(inout)   :: self
        real(rk), allocatable,  intent(inout)   :: fullvec(:)

        integer(ik) :: fpos, ndof, nvars, nterms, ielem, fstart, fend, ierr, ndof_l


        !
        ! Compute total entries in the vector
        !
        ndof = 0
        do ielem = 1,size(self%lvecs)


            nvars  = self%ldata(ielem,1)
            nterms = self%ldata(ielem,2)

            ndof = ndof + nvars*nterms
        end do


        !
        ! Allocate full-vector storage
        !
        if (allocated(fullvec)) then
            deallocate(fullvec)
            allocate(fullvec(ndof), stat=ierr)
        else
            allocate(fullvec(ndof), stat=ierr)
        end if
        if (ierr /= 0) call AllocationError




        fstart = 1    ! position in the full-vector
        do ielem = 1,size(self%lvecs)
            nvars = self%ldata(ielem,1)
            nterms = self%ldata(ielem,2)
            ndof_l = nvars * nterms     ! element local number of dof's

            fend = fstart + (ndof_l-1)

            ! Copy block vector to full-vector
            fullvec(fstart:fend) = self%lvecs(ielem)%vec 

            fstart = fend + 1
        end do

    end subroutine build













    !> Given a full-vector, distribute it's values to the blockvector format, 
    !! assuming contiguously stored data for each element.
    !!
    !!  @author Nathan A. Wukie
    !!
    !!  @param[in]  fullvec     Full-vector
    !------------------------------------------------------------------------
    subroutine distribute(self,fullvec)
        class(blockvector_t),    intent(inout)   :: self
        real(rk),                intent(in)      :: fullvec(:) 

        integer(ik)     :: ndof, ielem, nvars, nterms, fstart, fend, ndof_l

        !
        ! Compute total entries allocated in the blockvector container. 
        !
        ndof = 0
        do ielem = 1,size(self%lvecs)
            nvars  = self%ldata(ielem,1)
            nterms = self%ldata(ielem,2)
            
            ndof = ndof  +  (nvars * nterms)
        end do

        !
        ! Test that the number of dof's match between the full and block format's
        !
        if (ndof /= size(fullvec) ) call chidg_signal(FATAL,"blockvector_t%distribute: Storage sizes of full-vector and block-vector are not equal.")



        !
        ! Loop through elements and store data from full-vector
        !
        fstart = 1
        do ielem = 1,size(self%lvecs)
            ! Get number of entries for current block
            nvars  = self%ldata(ielem,1)
            nterms = self%ldata(ielem,2)
            ndof_l = nvars * nterms

            fend = fstart + (ndof_l-1)


            !& DEBUG
            if (fend > size(fullvec) ) call chidg_signal(FATAL,"blockvector%distribute: array bounds exceeded")


            self%lvecs(ielem)%vec = fullvec(fstart:fend)

            fstart = fend + 1
        end do




    end subroutine distribute







    !> Zero all vector storage elements in blockvector%lvecs
    !!
    !!  @author Nathan A. Wukie
    !!
    !!
    !----------------------------------------------------------
    subroutine clear(self)
        class(blockvector_t),   intent(inout)   :: self

        integer(ik) :: iblk


        do iblk = 1,size(self%lvecs)
            call self%lvecs(iblk)%clear()
        end do


    end subroutine clear














    !> Compute the L2-norm of the vector
    !!
    !!  @author Nathan A. Wukie
    !!
    !!
    !----------------------------------------------------------------------
    function norm(self) result(res)
        class(blockvector_t),   intent(inout)   :: self

        real(rk)    :: res
        integer(ik) :: ielem



        res = ZERO
        !
        ! Loop through block vectors and compute contribution to vector L2-Norm
        !
        do ielem = 1,size(self%lvecs)


            ! Square vector values and sum
            res = res + sum( self%lvecs(ielem)%vec ** TWO )

        end do


        !
        ! Take the square root of the result
        !
        res = sqrt(res)

    end function












    !> Compute number of entries in the block vector
    !!
    !!  @author Nathan A. Wukie
    !!
    !!
    !---------------------------------------------------------------------
    function nentries(self) result(res)
        class(blockvector_t),   intent(in)  :: self

        integer(ik) :: res, ielem

        res = ZERO
        !
        ! Loop through block vectors and compute contribution to number of entries
        !
        do ielem = 1,size(self%lvecs)

            res = res + self%lvecs(ielem)%nentries()

        end do

    end function nentries








    !> Return a coarsened vector
    !!
    !!  @author Nathan A. Wukie
    !!
    !!
    !!
    !!
    !----------------------------------------------------------------------
    function P(self,level) result(newVector)
        class(blockvector_t),       intent(in)  :: self
        integer(ik),                intent(in)  :: level

        type(blockvector_t) :: newVector

        integer(ik)         :: nterms_new, nterms_orig
        integer(ik)         :: neqns, ielem, nelem, dparent, eparent
        integer(ik)         :: irow_new_start, irow_new_end, irow_orig_start, irow_orig_end
        integer(ik)         :: ieqn, ierr

        real(rk), allocatable   :: temp(:)


        !
        ! Compute number of terms in coarsening
        !
        nterms_new = (level+1)**3


        !
        ! Copy ldata
        !
        newVector%ldata = self%ldata

        
        !
        ! Reset nterms to coarse set
        !
        newVector%ldata(:,2) = nterms_new


        !
        ! Allocate lvecs
        !
        nelem = size(self%lvecs)
        allocate(newVector%lvecs(nelem), stat=ierr)
        if (ierr /= 0) call AllocationError





        !
        ! Element-wise, copy necessary data for lvecs
        !
        do ielem = 1,nelem

            !
            ! Get parent element data
            !
            eparent = self%lvecs(ielem)%parent()

            !
            ! Get number of equations and number of terms for coarse expansion.
            !
            neqns = newVector%ldata(ielem,1)


            !
            ! Initialize coarse vector
            !
            call newVector%lvecs(ielem)%init(nterms_new,neqns,eparent)


            !
            ! Get full resolution
            !
            nterms_orig = self%ldata(ielem,2)


            !
            ! Copy subvector data to coarse vector
            !
            do ieqn = 1,neqns

                if ( nterms_new < nterms_orig ) then
                    !
                    ! Get sub-vector indices from original resolution
                    !
                    irow_orig_start = 1 + (ieqn-1)*nterms_orig
                    irow_orig_end   = irow_orig_start + (nterms_new - 1)

                    !
                    ! Get new-vector indices
                    !
                    irow_new_start  = 1 + (ieqn-1)*nterms_new
                    irow_new_end    = irow_new_start + (nterms_new - 1)

                elseif ( nterms_new > nterms_orig ) then
                    !
                    ! Get sub-vector indices from original resolution
                    !
                    irow_orig_start = 1 + (ieqn-1)*nterms_orig
                    irow_orig_end   = irow_orig_start + (nterms_orig - 1)

                    !
                    ! Get new-vector indices
                    !
                    irow_new_start  = 1 + (ieqn-1)*nterms_new
                    irow_new_end    = irow_new_start + (nterms_orig - 1)

                end if


                !
                ! Fill new vector
                !
                !if (allocated(temp)) deallocate(temp)

                !allocate(temp(nterms_new))
                !temp = 0._rk

            
                !temp(1:nterms_new) = self%lvecs(ielem)%vec(irow_orig_start:irow_orig_end)


                
                !
                ! Copy full-resolution sub-vector to coarse vector location
                !
                newVector%lvecs(ielem)%vec(irow_new_start:irow_new_end) = &
                     self%lvecs(ielem)%vec(irow_orig_start:irow_orig_end)

                !coarseVector%lvecs(ielem)%vec(irow_coarse_start:irow_new_end) = temp

            end do ! ieqn



        end do ! ielem


    end function P


















    subroutine dump(self)
        class(blockvector_t),   intent(in)  :: self
        integer(ik) :: ielem, ientry

        do ielem = 1,size(self%lvecs)
            print*, ielem
            do ientry = 1,size(self%lvecs(ielem)%vec)
                print*, self%lvecs(ielem)%vec(ientry)
            end do
        end do

    end subroutine
















    !------------------------------------------------------------------------
    !
    !                       OPERATOR IMPLEMENTATIONS
    !
    !------------------------------------------------------------------------


    !> Multiply real * blockvector
    !!
    !------------------------------------------------------------------------
    function mult_real_bv(left,right) result(res)
        real(rk),               intent(in)  :: left
        type(blockvector_t),    intent(in)  :: right

        type(blockvector_t), target     :: res

        !res%nelem_xi   = right%nelem_xi
        !res%nelem_eta  = right%nelem_eta
        !res%nelem_zeta = right%nelem_zeta
        !res%nelem      = right%nelem


        res%ldata = right%ldata

        res%lvecs = left * right%lvecs

    end function




    !> Multiply blockvector * real
    !!
    !------------------------------------------------------------------------
    function mult_bv_real(left,right) result(res)
        type(blockvector_t),    intent(in)  :: left
        real(rk),               intent(in)  :: right

        type(blockvector_t), target     :: res


        !res%nelem_xi   = left%nelem_xi
        !res%nelem_eta  = left%nelem_eta
        !res%nelem_zeta = left%nelem_zeta
        !res%nelem      = left%nelem


        res%ldata = left%ldata

        res%lvecs = left%lvecs * right

    end function





    !> Divide real / blockvector
    !!
    !------------------------------------------------------------------------
    function div_real_bv(left,right) result(res)
        real(rk),               intent(in)  :: left
        type(blockvector_t),    intent(in)  :: right

        type(blockvector_t), target     :: res


        !res%nelem_xi   = right%nelem_xi
        !res%nelem_eta  = right%nelem_eta
        !res%nelem_zeta = right%nelem_zeta
        !res%nelem      = right%nelem


        res%ldata = right%ldata

        res%lvecs = left / right%lvecs

    end function




    !> Divide blockvector / real
    !!
    !------------------------------------------------------------------------
    function div_bv_real(left,right) result(res)
        type(blockvector_t),    intent(in)  :: left
        real(rk),               intent(in)  :: right

        type(blockvector_t), target     :: res


        !res%nelem_xi   = left%nelem_xi
        !res%nelem_eta  = left%nelem_eta
        !res%nelem_zeta = left%nelem_zeta
        !res%nelem      = left%nelem


        res%ldata = left%ldata

        res%lvecs = left%lvecs / right

    end function






    !> Add blockvector + blockvector
    !!
    !------------------------------------------------------------------------
    function add_bv_bv(left,right) result(res)
        type(blockvector_t),  intent(in)  :: left
        type(blockvector_t),  intent(in)  :: right

        type(blockvector_t), target     :: res


        !res%nelem_xi   = right%nelem_xi
        !res%nelem_eta  = right%nelem_eta
        !res%nelem_zeta = right%nelem_zeta
        !res%nelem      = right%nelem
!
        res%ldata = right%ldata

        res%lvecs = left%lvecs + right%lvecs

    end function





    !> Add blockvector - blockvector
    !!
    !------------------------------------------------------------------------
    function sub_bv_bv(left,right) result(res)
        type(blockvector_t),  intent(in)  :: left
        type(blockvector_t),  intent(in)  :: right

        type(blockvector_t), target     :: res


        !res%nelem_xi   = right%nelem_xi
        !res%nelem_eta  = right%nelem_eta
        !res%nelem_zeta = right%nelem_zeta
        !res%nelem      = right%nelem

        res%ldata = right%ldata

        res%lvecs = left%lvecs - right%lvecs

    end function





    subroutine destructor(self)
        type(blockvector_t), intent(inout) :: self

    end subroutine

end module type_blockvector

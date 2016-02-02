module fcn_gaussian
#include <messenger.h>
    use mod_kinds,      only: rk,ik
    use mod_constants,  only: ZERO, ONE, TWO, THREE, FIVE
    use type_point,     only: point_t
    use type_function,  only: function_t
    implicit none
    private





    !>  Gaussian function.
    !!
    !!  Three 1D Gaussian functions are computed; one for each dimension. They are multiplied
    !!  together to create a 3D version of the function.
    !!
    !!  \f$  f_x(t,\vec{x}) = a e^{- \frac{(x-b_x)^2}{2c^2} }    \\
    !!       f_y(t,\vec{x}) = a e^{- \frac{(y-b_y)^2}{2c^2} }    \\
    !!       f_z(t,\vec{x}) = a e^{- \frac{(z-b_z)^2}{2c^2} }    \\
    !!       f(t,\vec{x}) = f_x * f_y * f_z                      \f$
    !!
    !!  Function parameters:
    !!
    !!  \f$ a   -   \text{Amplitude of the distribution}   \\
    !!      b_i -   \text{Offset in coordinate 'i'}        \\
    !!      c   -   \text{Width of the distribution}   \f$
    !!
    !!  @author Nathan A. Wukie
    !!  @date   2/1/2016
    !!
    !-------------------------------------------------------------------------------------
    type, extends(function_t), public :: gaussian_f
        private


        ! constants in the gaussian function
        !
        ! f(x) = a exp(- (x-b)**2 / 2c**2)
        !

        real(rk)    :: a = ONE
        real(rk)    :: b_x = ZERO
        real(rk)    :: b_y = ZERO
        real(rk)    :: b_z = ZERO

        !real(rk)    :: c = THREE
        real(rk)    :: c = ONE

    contains

        procedure   :: order
        procedure   :: calc
        procedure   :: set

    end type gaussian_f
    !*************************************************************************************



contains

    subroutine set(self,valstring,val)
        class(gaussian_f),  intent(inout)   :: self
        character(*),       intent(in)      :: valstring
        real(rk),           intent(in)      :: val


        select case (valstring)
            case('a','A')
                self%a = val
            case('b_x','bx','BX','B_X')
                self%b_x = val
            case('b_y','by','BY','B_Y')
                self%b_y = val
            case('b_z','bz','BZ','B_Z')
                self%b_z = val
            case('c','C')
                self%c = val
            case default
                call chidg_signal(FATAL,'gaussian_f%set: Invalid option string')
        end select


    end subroutine


    function order(self)
        class(gaussian_f), intent(in)   :: self
        integer(ik)                     :: order

        order = 3

    end function



    elemental function calc(self,pt)
        class(gaussian_f),  intent(in)  :: self
        type(point_t),      intent(in)  :: pt
        real(rk)                        :: calc

        real(rk)    :: x,   y,   z, &
                       v_x, v_y, v_z

        x = pt%c1_
        y = pt%c2_
        z = pt%c3_

        v_x = self%a * exp( - ((x - self%b_x)**TWO) / (TWO * self%c**TWO))
        v_y = self%a * exp( - ((y - self%b_y)**TWO) / (TWO * self%c**TWO))
        v_z = self%a * exp( - ((z - self%b_z)**TWO) / (TWO * self%c**TWO))


        calc = v_x * v_y * v_z

    end function


end module fcn_gaussian

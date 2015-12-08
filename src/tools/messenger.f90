module messenger
    use mod_kinds,      only: rk,ik
    use mod_constants,  only: IO_DESTINATION
    implicit none


    character(len=:), allocatable   :: line                     ! Line that gets assembled and written
    character(len=2), parameter     :: default_delimiter = ''   ! Delimiter of line parameters
    character(len=:), allocatable   :: current_delimiter        ! Delimiter of line parameters
    integer                         :: unit                     ! Unit of log file
    integer                         :: max_msg_length = 300     ! Maximum width of message line



contains

    !> Log initialization
    !!
    !!  @author Nathan A. Wukie
    !!
    !!--------------------------------------------------------------------
    subroutine log_init()

        !
        ! Open file
        !
        open(newunit=unit, file='chidg.log')


    end subroutine
    !---------------------------------------------------------------------




    !> Log finalization
    !!
    !!  @author Nathan A. Wukie
    !!
    !!--------------------------------------------------------------------
    subroutine log_finalize()

        !
        ! Close file
        !
        close(unit)

    end subroutine
    !---------------------------------------------------------------------







    !> Message routine for handling warnings and errors.
    !! Reports file name, line number, and warn/error message
    !!
    !! 'level' controls the action.
    !! - Warn            :: 1
    !! - Non-fatal error :: 2
    !! - Fatal error     :: 3
    !!
    !!  @author Nathan A. Wukie
    !!
    !!
    !--------------------------------------------------------------------------------
    subroutine message(pathname,linenum,sig,msg,info_one, info_two)
        character(*), intent(in)            :: pathname
        integer(ik),  intent(in)            :: linenum
        integer(ik),  intent(in)            :: sig
        character(*), intent(in)            :: msg
        class(*),     intent(in), target, optional  :: info_one
        class(*),     intent(in), target, optional  :: info_two

        integer                         :: iaux, pathstart
        character(len=:), allocatable   :: subpath, temppath
        class(*), pointer               :: auxdata => null()
        character(100)                  :: warnstr, errstr, killstr, genstr, starstr, linechar, dashstr, blankstr
        logical                         :: print_info_one = .false.
        logical                         :: print_info_two = .false.


        warnstr =  '*********************************  Warning  *********************************'
        errstr  =  '*****************************  Non-fatal error  *****************************'
        killstr =  '*******************************  Fatal error  *******************************'
        starstr =  '*****************************************************************************'
        dashstr =  '-----------------------------------------------------------------------------'
        blankstr = '               '


        !
        ! Chop off unimportant beginning of file path
        !
        temppath = pathname
        pathstart = index(temppath, '/ChiDG/')
        subpath = temppath(pathstart:len(pathname))


        !
        ! Assemble general file and line number string
        !
        write(linechar, '(i10)') linenum
        genstr = trim(subpath) // ' at ' // adjustl(trim(linechar))


        !
        ! Print message header
        !
        call write_line(blankstr)
        call write_line(trim(dashstr))




        !
        ! Select signal message
        !
        select case (sig)
            case (0)    ! Normal message -- Code continues
                call write_line(trim(msg))

            case (1)    ! Warning message -- Code continues
                call write_line(trim(warnstr))
                call write_line(trim(genstr))
                call write_line(blankstr)
                call write_line('Message:')
                call write_line(trim(msg))

            case (2)    ! Non-Fatal Error -- Code continues
                call write_line(trim(errstr))
                call write_line(trim(genstr))
                call write_line(blankstr)
                call write_line('Message:')
                call write_line(trim(msg))

            case (3)    ! Fatal Error -- Code terminates
                call write_line(trim(killstr))
                call write_line(trim(genstr))
                call write_line(blankstr)
                call write_line('Message:')
                call write_line(trim(msg))

            case default
                print*, "Messenger:message -- message code not recognized"
                stop
        end select
        call write_line(blankstr)



        !
        ! Loop through auxiliary variables. If present, try to print.
        !
        do iaux = 1,2

            print_info_one = ( present(info_one) .and. (iaux == 1) )
            print_info_two = ( present(info_two) .and. (iaux == 2) )

            if ( print_info_one ) auxdata => info_one
            if ( print_info_two ) auxdata => info_two

            !
            ! auxdata pointer is used to point to current auxiliary data variable and then go through the available IO types
            !
            if ( associated(auxdata) ) then
                call write_line('Case specific info:')

                select type(auxdata)
                    type is(integer)
                        call write_line(auxdata)

                    type is(integer(8))
                        call write_line(auxdata)

                    type is(real)
                        call write_line(auxdata)

                    type is(real(8))
                        call write_line(auxdata)

                    class default
                        print*, '', "Data type not implemented for I/O in messege.f90"
                end select

            end if ! present(info_one)


            !
            ! Disassociate pointer
            !
            auxdata => null()

        end do ! iaux



        !
        ! Print message footer
        !
        call write_line(blankstr)
        call write_line(dashstr)



        !
        ! Select signal action
        !
        select case (sig)
            case (3)    ! Fatal Error -- Code terminates
                !stop
                error stop

            case default

        end select



    end subroutine message
    !----------------------------------------------------------------------------------------------------------







    !> This subroutine handles line-by-line IO and it's target. For example, whether it is written 
    !! to stdio or to a file.
    !!
    !!  @author Nathan A. Wukie
    !!
    !!
    !!
    !----------------------------------------------------------------------------------------------------------
    subroutine write_line(a,b,c,d,e,f,g,h,delimiter)
        class(*),           intent(in), target, optional        :: a
        class(*),           intent(in), target, optional        :: b
        class(*),           intent(in), target, optional        :: c
        class(*),           intent(in), target, optional        :: d
        class(*),           intent(in), target, optional        :: e
        class(*),           intent(in), target, optional        :: f
        class(*),           intent(in), target, optional        :: g
        class(*),           intent(in), target, optional        :: h
        character(len=*),   intent(in),         optional        :: delimiter

        class(*), pointer               :: auxdata => null()
        character(len=:), allocatable   :: delim_str

        integer :: iaux, ielem
        logical :: print_info_one, print_info_two, print_info_three, print_info_four, print_info_five
        logical :: print_info_six, print_info_seven, print_info_eight

        
        !
        ! Loop through variables and compose line to write
        !
        do iaux = 1,8

            print_info_one   = ( present(a) .and. (iaux == 1) )
            print_info_two   = ( present(b) .and. (iaux == 2) )
            print_info_three = ( present(c) .and. (iaux == 3) )
            print_info_four  = ( present(d) .and. (iaux == 4) )
            print_info_five  = ( present(e) .and. (iaux == 5) )
            print_info_six   = ( present(f) .and. (iaux == 6) )
            print_info_seven = ( present(g) .and. (iaux == 7) )
            print_info_eight = ( present(h) .and. (iaux == 8) )

            if ( print_info_one   )  auxdata => a
            if ( print_info_two   )  auxdata => b
            if ( print_info_three )  auxdata => c
            if ( print_info_four  )  auxdata => d
            if ( print_info_five  )  auxdata => e
            if ( print_info_six   )  auxdata => f
            if ( print_info_seven )  auxdata => g
            if ( print_info_eight )  auxdata => h



            if ( associated(auxdata) ) then

                    !
                    ! Add data to line
                    !
                    call add_to_line(auxdata,delimiter)

            end if



            !
            ! Unassociate pointer
            !
            auxdata => null()


        end do



        !
        ! Write line
        !
        call send_line()



    end subroutine write_line
    !-----------------------------------------------------------------------------------------------------------








    !> Adds data to the module 'line' character string
    !!
    !!  @author Nathan A. Wukie
    !!
    !!
    !!
    !!
    !---------------------------------------------------------------------------------------
    subroutine add_to_line(linedata,delimiter)
        class(*),       intent(in)              :: linedata
        character(*),   intent(in), optional    :: delimiter

        character(100)                  :: temp
        character(len=:), allocatable   :: delim_str

        !
        ! Initialize temp
        !
        temp = ''


        !
        ! Select delimiter
        !
        if (  present(delimiter) ) then
            current_delimiter = delimiter
        else
            current_delimiter = default_delimiter
        end if


        !
        ! Add to line. Since variable is polymorphic, we have to test for each type and handle
        ! appropriately.
        !
        select type(linedata)

            type is(character(len=*))
                line = line//linedata//current_delimiter

            type is(integer)
                write(temp, '(I10.0)') linedata
                line = line//trim(temp)//current_delimiter

            type is(integer(8))
                write(temp, '(I10.0)') linedata
                line = line//trim(temp)//current_delimiter

            type is(real)
                if (linedata > 0.1) then
                    write(temp, '(F24.14)') linedata
                else
                    write(temp, '(E24.14)') linedata
                end if
                line = line//trim(temp)//current_delimiter

            type is(real(8))
                if (linedata > 0.1) then
                    write(temp, '(F24.14)') linedata
                else
                    write(temp, '(E24.14)') linedata
                end if
                line = line//trim(temp)//current_delimiter

            class default
                print*, 'Error: no IO rule for provided data in add_to_line'
                stop
        end select


    end subroutine
    !---------------------------------------------------------------------------------------









    !> Handles action for the current line
    !!
    !!  @author Nathan A. Wukie
    !!
    !!
    !!
    !!
    !----------------------------------------------------------------------------------------
    subroutine send_line()
        integer :: delimiter_size
        integer :: line_size
        integer :: line_trim
        integer :: lstart, lend, section

        character(len=:), allocatable :: writeline
        integer                       :: section_length

        !
        ! Get line section length
        !
        if ( len(line) > max_msg_length ) then
            section_length = max_msg_length
        else
            section_length = len(line)
        end if


        !
        ! Get line/delimiter sizes
        !
        delimiter_size = len(current_delimiter)
        line_size      = len(line)
        line_trim      = line_size - delimiter_size



        !
        ! Remove trailing delimiter
        !
        line = line(1:line_trim)



        !
        ! Handle line IO
        !
        writeline = line
        section = 1
        lend    = -1
        do while ( lend /= len(line) ) 
            lstart = 1 + ((section-1) * section_length)
            lend   = (section) * section_length

            !
            ! Dont go out-of-bounds
            !
            if (lstart > len(line) ) then
                exit
            end if

            if (lend > len(line)) then
                lend = len(line)
            end if


            !
            ! Get line for writing
            !
            writeline = line(lstart:lend)


            !
            ! Write to destination
            !
            if ( IO_DESTINATION == 'screen' ) then
                print*, writeline

            else if ( IO_DESTINATION == 'file' ) then
                write(unit,*) writeline

            else if ( IO_DESTINATION == 'both' ) then
                print*, writeline
                write(unit,*) writeline

            else
                print*, "Error: value for IO_DESTINATION is invalid. Valid selections are 'screen', 'file', 'both'."

            end if

            section = section + 1
        end do ! len(line) > max_msg_length


        !
        ! Clear line
        !
        line = ''



    end subroutine send_line
    !----------------------------------------------------------------------------------------





































end module messenger

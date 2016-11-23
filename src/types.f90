module types

  type model_type
    character(len=200) :: name
    character(len=200) :: file
    integer :: index
    integer :: ncontacts
    double precision :: gscore
    double precision :: similarity
    double precision :: dgscore
    logical, allocatable :: constraint(:)
  end type model_type

end module types 

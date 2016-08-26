!
! Gscore calculator
!
! Program compactlog
!
! This program compacts the output of many multiple lovoalign
! runs into a single file with the data of GDT and TM-scores
! for all pairs, so that the G scores can be computed faster
! without having to read all the align logs again.
!
! L. Martinez
! Institute of Chemistry - University of Campinas
! Aug 25, 2016
! http://leandro.iqm.unicamp.br
!

program compactlog

  use types
  use file_operations
  implicit none
  integer :: i1, i2, i, j, model_index, imodel
  integer :: narg, ioerr, nmodels, nlogs, ilog
  double precision :: dummy, tmscore_read, gdt_read
  double precision, allocatable :: gdt(:,:), tmscore(:,:)
  character(len=200) :: pdb_list, align_list, align_log, gdt_log, tm_log
  character(len=200) :: record, file1, file2, format
  logical :: error
  type(model_type), allocatable :: model(:)

  narg = iargc()
  if ( narg /= 4 ) then
    write(*,*) ' ERROR: Run with: ./compactlog [pdb list] [align list] [gdt output] [tmscore output]  '
    stop
  end if

  ! Read PDB file list from comand line

  call getarg(1,pdb_list)

  ! Read align log file list from command line

  call getarg(2,align_list)

  ! Read gdt and tmscore cutoffs, create files

  call getarg(3,gdt_log)
  open(10,file=gdt_log,status='new',action='write',iostat=ioerr)
  if ( ioerr /= 0 ) then
    write(*,*) ' ERROR: Trying to create file: ', trim(adjustl(gdt_log))
    write(*,*) '        but file already exists, or some other access problem. '
    stop
  end if
  close(10)
  call getarg(4,tm_log)
  open(10,file=tm_log,status='new',action='write',iostat=ioerr)
  if ( ioerr /= 0 ) then
    write(*,*) ' ERROR: Trying to create file: ', trim(adjustl(tm_log))
    write(*,*) '        but file already exists, or some other access problem. '
    stop
  end if
  close(10)

  ! Print the input options

  write(*,"(a)") "#" 
  write(*,"(a)") "# Gscore calculator " 
  write(*,"(a)") "#" 
  write(*,"(a)") "# COMPACTLOG: Align log file conversion to compact form " 
  write(*,"(a)") "#" 
  write(*,"(a)") "# L. Martinez - Institute of Chemistry, University of Campinas" 
  write(*,"(a)") "# http://leandro.iqm.unicamp.br" 
  write(*,"(a)") "#" 
  write(*,"(a)") "# Reference:" 
  write(*,"(a)") "# L. Martinez, A. Ferrari, F. C. Gozzo," 
  write(*,"(a)") "# A model evaluation score for ... 2016" 
  write(*,"(a)") "#" 
  write(*,"(a,a)") "# List of alignment files: ", trim(adjustl(align_list)) 
  write(*,"(a)") "#" 
  write(*,"(a,a)") "# Will create compact log for GDTs: ", trim(adjustl(gdt_log))
  write(*,"(a,a)") "# Will create compact log for TM-scores: ", trim(adjustl(tm_log))
  write(*,"(a)") "#" 


  !
  ! Count the number of models in the PDB list
  !

  open(10,file=pdb_list,status='old',action='read',iostat=ioerr)
  if ( ioerr /= 0 ) then
    write(*,*) ' ERROR: Could not open file: ', trim(adjustl(pdb_list))
    stop
  end if
  nmodels = 0
  do
    read(10,"(a200)",iostat=ioerr) record
    if ( ioerr /= 0 ) exit
    if ( comment(record) ) cycle 
    nmodels = nmodels + 1
  end do

  write(*,"(a,i10)") '# Number of PDB files in list: ', nmodels
  allocate(gdt(nmodels,nmodels),tmscore(nmodels,nmodels),model(nmodels))
  rewind(10)

  !
  ! Assign an index to each model name
  !

  write(*,"(a)") "# Reading list of model files ... "
  imodel = 0
  do
    read(10,"(a200)",iostat=ioerr) file1
    if ( ioerr /= 0 ) exit
    if ( comment(file1) ) cycle
    imodel = imodel + 1
    model(imodel)%name = basename(file1)
  end do
  close(10)

  !
  ! Sort model names according to string comparisons
  !

  write(*,"(a)") "# Sorting models by file name ... "
  do i = 1, nmodels-1
    call progress(i,1,nmodels)
    j = i + 1
    do while( model(j-1)%name > model(j)%name )
      file1 = model(j-1)%name
      model(j-1)%name = model(j)%name
      model(j)%name = file1
      j = j - 1
      if ( j == 1 ) exit
    end do
  end do
  call progress(nmodels,1,nmodels)
  
  ! Count the number of lovoalign log files

  open(10,file=align_list,status='old',action='read',iostat=ioerr)
  if ( ioerr /= 0 ) then
    write(*,*) ' ERROR: Could not open file: ', trim(adjustl(align_list))
    stop
  end if
  nlogs = 0
  do
    read(10,"(a200)",iostat=ioerr) align_log
    if ( ioerr /= 0 ) exit
    if ( comment(align_log) ) cycle 
    nlogs = nlogs + 1
  end do
  rewind(10)
  write(*,"(a,i10)") '# Number of lovoalign log files in list: ', nlogs
  write(*,"(a)") "#" 

  !
  ! Now, reading all alignment log files and annotating the scores
  ! of the alignment of each pair
  !
  write(*,"(a)") "# Reading all alignment files ... this can take a while. "
  ilog = 0
  do
    call progress(ilog,1,nlogs)
    read(10,"(a200)",iostat=ioerr) align_log
    if ( ioerr /= 0 ) exit
    if ( comment(align_log) ) cycle
    open(20,file=align_log,status='old',action='read',iostat=ioerr)
    if ( ioerr /= 0 ) then
      write(*,*) ' ERROR: Could not open alignment log file: ', trim(adjustl(align_log))
      write(*,*) '        Listed in: ', trim(adjustl(align_list))
      stop
    end if
    do
      read(20,"(a200)",iostat=ioerr) record
      if ( ioerr /= 0 ) exit
      if ( comment(record) ) cycle
      read(record,*,iostat=ioerr) file1, file2, tmscore_read, (dummy,i=1,4), gdt_read
      if ( ioerr /= 0 ) then
        write(*,*) ' ERROR: Could not read data in alignment log file: ', trim(adjustl(align_log))
        write(*,*) '        Content: ', trim(adjustl(record))
        stop
      end if
      file1 = basename(file1)
      i1 = model_index(file1,model,nmodels,error)
      if ( error ) cycle
      file2 = basename(file2)
      i2 = model_index(file2,model,nmodels,error)
      if ( error ) cycle
      if ( i2 > i1 ) then
        tmscore(i1,i2) = tmscore_read
        gdt(i1,i2) = gdt_read
      else
        tmscore(i2,i1) = tmscore_read
        gdt(i2,i1) = gdt_read
      end if
    end do
    close(20)
    ilog = ilog + 1
  end do
  close(10)

  ! Create output files

  write(*,"(a)") "#"
  write(*,"(a)") "# Writing output files ... "

  ! Write titles to compact log files

  write(10,*) ' This a compact lovoalign alignment file, with GDT scores '
  write(10,*) ' Alignment files obtained from ', trim(adjustl(align_list))
  write(20,*) ' This a compact lovoalign alignment file, with TM-scores '
  write(20,*) ' Alignment files obtained from ', trim(adjustl(align_list))

  ! Write list of models to output files

  open(10,file=gdt_log,action='write',iostat=ioerr)
  open(20,file=tm_log,action='write',iostat=ioerr)
  write(10,*) nmodels
  write(20,*) nmodels
  do imodel = 1, nmodels
    write(10,*) imodel, trim(adjustl(model(imodel)%name))
    write(20,*) imodel, trim(adjustl(model(imodel)%name))
  end do

  ! Write scores to files

  write(format,*) nmodels
  format = "("//trim(adjustl(format))//"(tr1,f8.3))"
  do imodel = 1, nmodels - 1
    write(10,format) (gdt(imodel,i),i=imodel+1,nmodels)
    write(20,format) (tmscore(imodel,i),i=imodel+1,nmodels)
  end do
  close(10)
  close(20)

  write(*,"(a)") "#"
  write(*,"(a)") '# Finished. '

end program compactlog





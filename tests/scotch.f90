program check_scotch_fortran
#ifdef USE_PTSCOTCH
  use mpi
#endif
  implicit none
#ifdef USE_PTSCOTCH
  include 'ptscotchf.h'
  double precision :: graph(SCOTCH_DGRAPHDIM)
  integer :: provided, mpierr
#else
  include 'scotchf.h'
  double precision :: graph(SCOTCH_GRAPHDIM)
#endif
  integer :: ierr
#ifndef USE_PTSCOTCH
  if (SCOTCH_NUMSIZE /= 4) error stop 'SCOTCH_Num must be 32 bits'
#endif
#ifdef USE_PTSCOTCH
  call MPI_Init_thread(MPI_THREAD_MULTIPLE,provided,mpierr)
  if (provided < MPI_THREAD_MULTIPLE) call MPI_Abort(MPI_COMM_WORLD,1,mpierr)
  call scotchfdgraphinit(graph,MPI_COMM_WORLD,ierr)
#else
  call scotchfgraphinit(graph,ierr)
#endif
  if (ierr /= 0) error stop 'Scotch Fortran graph initialization failed'
#ifdef USE_PTSCOTCH
  call scotchfdgraphexit(graph)
  call MPI_Finalize(mpierr)
#else
  call scotchfgraphexit(graph)
#endif
  print *, 'PASS: Scotch Fortran interface'
end program

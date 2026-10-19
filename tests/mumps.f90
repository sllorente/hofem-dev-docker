program check_mumps
  use mpi
  implicit none
  include 'dmumps_struc.h'
  type(DMUMPS_STRUC) :: solver
  integer :: ierr, provided, rank
  integer :: rows(3) = [1, 2, 3], columns(3) = [1, 2, 3]
  double precision :: values(3) = [2d0, 3d0, 4d0], rhs(3) = [2d0, 6d0, 12d0]
  call MPI_Init_thread(MPI_THREAD_MULTIPLE, provided, ierr)
  if (provided < MPI_THREAD_MULTIPLE) call MPI_Abort(MPI_COMM_WORLD, 1, ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
  solver%COMM = MPI_COMM_WORLD
  solver%PAR = 1
  solver%SYM = 0
  solver%JOB = -1
  call DMUMPS(solver)
  if (solver%INFOG(1) /= 0) call MPI_Abort(MPI_COMM_WORLD, 1, ierr)
  solver%ICNTL(1:3) = -1
  solver%ICNTL(4) = 0
  if (rank == 0) then
    solver%N = 3
    solver%NNZ = 3
    allocate(solver%IRN(3), solver%JCN(3), solver%A(3), solver%RHS(3))
    solver%IRN = rows
    solver%JCN = columns
    solver%A = values
    solver%RHS = rhs
  end if
  solver%JOB = 6
  call DMUMPS(solver)
  if (solver%INFOG(1) /= 0) call MPI_Abort(MPI_COMM_WORLD, 1, ierr)
  if (rank == 0) then
    if (maxval(abs(solver%RHS - [1d0, 2d0, 3d0])) > 1d-10) call MPI_Abort(MPI_COMM_WORLD, 1, ierr)
    deallocate(solver%IRN, solver%JCN, solver%A, solver%RHS)
    print *, 'PASS: MUMPS Fortran interface'
  end if
  solver%JOB = -2
  call DMUMPS(solver)
  call MPI_Finalize(ierr)
end program

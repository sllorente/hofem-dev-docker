program check_arpack
#ifdef USE_PARPACK
  use mpi
#endif
  implicit none
  integer, parameter :: global_n=48, nev=3, ncv=12, lworkl=ncv*(ncv+8)
  integer :: n, rank, ranks, ierr, ido, info, i, iparam(11), ipntr(11)
  double precision :: tol, sigma, expected
  double precision, allocatable :: resid(:), v(:,:), workd(:)
  double precision :: workl(lworkl), d(nev), z(global_n,nev)
  logical :: select(ncv)
  rank=0
  ranks=1
#ifdef USE_PARPACK
  call MPI_Init(ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD,rank,ierr)
  call MPI_Comm_size(MPI_COMM_WORLD,ranks,ierr)
  if (ranks /= 2) call fail('PARPACK test requires two MPI ranks')
#endif
  n=global_n/ranks
  allocate(resid(n),v(n,ncv),workd(3*n))
  ido=0
  info=0
  tol=1.0d-10
  iparam=0
  ipntr=0
  iparam(1)=1
  iparam(3)=1000
  iparam(7)=1
  do
#ifdef USE_PARPACK
    call pdsaupd(MPI_COMM_WORLD,ido,'I',n,'LA',nev,tol,resid,ncv,v,n,iparam,ipntr,workd,workl,lworkl,info)
#else
    call dsaupd(ido,'I',n,'LA',nev,tol,resid,ncv,v,n,iparam,ipntr,workd,workl,lworkl,info)
#endif
    if (ido == -1 .or. ido == 1) then
      do i=1,n
        workd(ipntr(2)+i-1)=dble(rank*n+i)*workd(ipntr(1)+i-1)
      end do
    else if (ido == 2) then
      workd(ipntr(2):ipntr(2)+n-1)=workd(ipntr(1):ipntr(1)+n-1)
    else
      exit
    end if
  end do
  if (info /= 0 .or. iparam(5) /= nev) call fail('eigensolver did not converge')
  sigma=0.0d0
#ifdef USE_PARPACK
  call pdseupd(MPI_COMM_WORLD,.true.,'A',select,d,z,global_n,sigma,'I',n,'LA',nev,tol, &
               resid,ncv,v,n,iparam,ipntr,workd,workl,lworkl,info)
#else
  call dseupd(.true.,'A',select,d,z,global_n,sigma,'I',n,'LA',nev,tol, &
              resid,ncv,v,n,iparam,ipntr,workd,workl,lworkl,info)
#endif
  if (info /= 0) call fail('eigenvalue extraction failed')
  do i=1,nev
    expected=dble(global_n-nev+i)
    if (abs(d(i)-expected)>1.0d-7) call fail('incorrect eigenvalue')
  end do
  if (rank == 0) print *, 'PASS: eigenvalues',d
#ifdef USE_PARPACK
  call MPI_Finalize(ierr)
#endif
contains
  subroutine fail(message)
    character(*), intent(in) :: message
    print *, message
#ifdef USE_PARPACK
    call MPI_Abort(MPI_COMM_WORLD,1,ierr)
#endif
    stop 1
  end subroutine
end program

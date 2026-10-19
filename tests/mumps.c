#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mpi.h>
#if ARITH == 1
#include <smumps_c.h>
typedef SMUMPS_STRUC_C Solver;
typedef float Scalar;
#define SOLVE smumps_c
#elif ARITH == 2
#include <dmumps_c.h>
typedef DMUMPS_STRUC_C Solver;
typedef double Scalar;
#define SOLVE dmumps_c
#elif ARITH == 3
#include <cmumps_c.h>
typedef CMUMPS_STRUC_C Solver;
typedef mumps_complex Scalar;
#define SOLVE cmumps_c
#else
#include <zmumps_c.h>
typedef ZMUMPS_STRUC_C Solver;
typedef mumps_double_complex Scalar;
#define SOLVE zmumps_c
#endif

static Scalar scalar(double x) {
#if ARITH >= 3
    Scalar value = {x, 0.0};
    return value;
#else
    return x;
#endif
}

static void check(int ok, const char *message) {
    if (!ok) { fprintf(stderr, "FAIL: %s\n", message); MPI_Abort(MPI_COMM_WORLD, 1); }
}

int main(int argc, char **argv) {
    int provided, rank, ranks;
    MPI_Init_thread(&argc, &argv, MPI_THREAD_MULTIPLE, &provided);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &ranks);
    check(provided >= MPI_THREAD_MULTIPLE, "MPI thread support");
    check(sizeof(MUMPS_INT) == 4, "32-bit integer ABI");
    const int n = 128, nnz = 3*n-2;
    MUMPS_INT rows[nnz], columns[nnz];
    Scalar entries[nnz], rhs[n];
    /* Sequential Scotch, METIS, PORD; distributed PT-Scotch and ParMETIS. */
    const int analysis[] = {1, 1, 1, 2, 2};
    const int ordering[] = {3, 5, 4, 1, 2};
    int modes = argc > 1 ? atoi(argv[1]) : 5;
    int first = modes < 0 ? 2 : 0;
    if (modes < 0) modes = 3;
    for (int mode = first; mode < modes; ++mode) {
        Solver id;
        memset(&id, 0, sizeof id);
        id.comm_fortran = MPI_Comm_c2f(MPI_COMM_WORLD);
        id.par = 1; id.sym = 0; id.job = -1;
        SOLVE(&id);
        check(id.infog[0] == 0, "initialization");
        check(strcmp(id.version_number, MUMPS_VERSION) == 0, "runtime/header version");
        for (int j = 0; j < 3; ++j) id.icntl[j] = -1;
        id.icntl[3] = 0;
        id.icntl[27] = analysis[mode];
        if (analysis[mode] == 1) id.icntl[6] = ordering[mode];
        else id.icntl[28] = ordering[mode];
        if (rank == 0) {
            int k = 0;
            for (int i = 0; i < n; ++i) {
                rows[k] = columns[k] = i+1; entries[k++] = scalar(4.0);
                if (i > 0) { rows[k]=i+1; columns[k]=i; entries[k++]=scalar(-1.0); }
                if (i+1 < n) { rows[k]=i+1; columns[k]=i+2; entries[k++]=scalar(-1.0); }
                rhs[i] = scalar(i == 0 || i == n-1 ? 3.0 : 2.0);
            }
            id.n=n; id.nnz=nnz; id.irn=rows; id.jcn=columns; id.a=entries; id.rhs=rhs;
        }
        id.job = 6;
        SOLVE(&id);
        if (id.infog[0] != 0) fprintf(stderr,"INFOG(1,2)=%d,%d mode=%d\n",id.infog[0],id.infog[1],mode);
        check(id.infog[0] == 0, "analysis/factorization/solve");
        if (rank == 0) {
            check(id.infog[31] == analysis[mode], "requested analysis actually selected");
            check(id.infog[6] == ordering[mode], "requested ordering actually selected");
            for (int i = 0; i < n; ++i) {
#if ARITH >= 3
                double error = fabs(rhs[i].r-1.0) + fabs(rhs[i].i);
#else
                double error = fabs(rhs[i]-1.0);
#endif
                check(error < (ARITH == 1 || ARITH == 3 ? 1e-4 : 1e-10), "solution accuracy");
            }
            printf("PASS: MUMPS %s arithmetic=%d analysis=%d ordering=%d ranks=%d\n",
                   MUMPS_VERSION, ARITH, analysis[mode], ordering[mode], ranks);
        }
        id.job = -2; SOLVE(&id);
        check(id.infog[0] == 0, "finalization");
    }
    MPI_Finalize();
    return 0;
}

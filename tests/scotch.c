#include <stdint.h>
#include <stdio.h>
#include <scotch.h>
#ifdef USE_PTSCOTCH
#include <mpi.h>
#include <ptscotch.h>
#endif
#include <stdlib.h>

static void require(int ok, const char *message) {
    if (!ok) {
        fprintf(stderr,"%s\n",message);
#ifdef USE_PTSCOTCH
        MPI_Abort(MPI_COMM_WORLD,1);
#endif
        exit(1);
    }
}
int main(int argc, char **argv) {
    int rank=0, ranks=1, major, release, patch;
#ifdef USE_PTSCOTCH
    int provided=0;
    MPI_Init_thread(&argc,&argv,MPI_THREAD_MULTIPLE,&provided);
    require(provided>=MPI_THREAD_MULTIPLE,"MPI_THREAD_MULTIPLE is unavailable");
    MPI_Comm_rank(MPI_COMM_WORLD,&rank);
    MPI_Comm_size(MPI_COMM_WORLD,&ranks);
    require(ranks==2,"PT-Scotch test requires two MPI ranks");
#else
    (void)argc; (void)argv;
#endif
    require(sizeof(SCOTCH_Num)==4,"SCOTCH_Num must be 32 bits");
    SCOTCH_version(&major,&release,&patch);
    require(major==SCOTCH_VERSION && release==SCOTCH_RELEASE && patch==SCOTCH_PATCHLEVEL,
            "Scotch runtime and header versions differ");
#ifdef REQUIRE_THREADS
    SCOTCH_Context context;
    require(SCOTCH_contextInit(&context)==0,"thread context initialization failed");
    require(SCOTCH_contextThreadSpawn(&context,2,NULL)==0,"two-thread context creation failed");
    SCOTCH_contextExit(&context);
#endif
    enum { global_n=64 };
    int n=global_n/ranks;
    SCOTCH_Num xadj[global_n+1], adjncy[2*global_n], part[global_n], perm[global_n], iperm[global_n];
    SCOTCH_Num k=0;
    for(int i=0;i<n;i++) {
        int g=rank*n+i;
        xadj[i]=k;
        if(g>0) adjncy[k++]=g-1;
        if(g+1<global_n) adjncy[k++]=g+1;
    }
    xadj[n]=k;
    SCOTCH_Strat strategy;
    require(SCOTCH_stratInit(&strategy)==0,"strategy initialization failed");
#ifdef USE_PTSCOTCH
    SCOTCH_Dgraph graph;
    require(SCOTCH_dgraphInit(&graph,MPI_COMM_WORLD)==0,"distributed graph initialization failed");
    require(SCOTCH_dgraphBuild(&graph,0,n,n,xadj,NULL,NULL,NULL,k,k,adjncy,NULL,NULL)==0,
            "distributed graph build failed");
    require(SCOTCH_dgraphCheck(&graph)==0,"distributed graph is invalid");
    require(SCOTCH_dgraphPart(&graph,2,&strategy,part)==0,"distributed partition failed");
    SCOTCH_Num allpart[global_n];
    MPI_Allgather(part,n,MPI_INT,allpart,n,MPI_INT,MPI_COMM_WORLD);
    for(int i=0;i<global_n;i++) part[i]=allpart[i];
    SCOTCH_stratExit(&strategy);
    require(SCOTCH_stratInit(&strategy)==0,"ordering strategy initialization failed");
    SCOTCH_Dordering ordering;
    require(SCOTCH_dgraphOrderInit(&graph,&ordering)==0,"distributed ordering initialization failed");
    require(SCOTCH_dgraphOrderCompute(&graph,&ordering,&strategy)==0,"distributed ordering failed");
    require(SCOTCH_dgraphOrderPerm(&graph,&ordering,iperm)==0,"distributed permutation failed");
    MPI_Allgather(iperm,n,MPI_INT,perm,n,MPI_INT,MPI_COMM_WORLD);
    SCOTCH_dgraphOrderExit(&graph,&ordering);
    SCOTCH_dgraphExit(&graph);
#else
    SCOTCH_Graph graph;
    require(SCOTCH_graphInit(&graph)==0,"graph initialization failed");
    require(SCOTCH_graphBuild(&graph,0,n,xadj,NULL,NULL,NULL,k,adjncy,NULL)==0,"graph build failed");
    require(SCOTCH_graphCheck(&graph)==0,"graph is invalid");
    require(SCOTCH_graphPart(&graph,2,&strategy,part)==0,"partition failed");
    SCOTCH_stratExit(&strategy);
    require(SCOTCH_stratInit(&strategy)==0,"ordering strategy initialization failed");
    require(SCOTCH_graphOrder(&graph,&strategy,perm,iperm,NULL,NULL,NULL)==0,"ordering failed");
    for(int i=0;i<n;i++) {
        require(perm[i]>=0 && perm[i]<n,"permutation index is invalid");
        require(iperm[perm[i]]==i,"ordering inverse is incorrect");
    }
    SCOTCH_graphExit(&graph);
#endif
    int counts[2]={0,0}, seen[global_n]={0}, cut=0;
    for(int i=0;i<global_n;i++) {
        require(part[i]>=0 && part[i]<2,"partition index is invalid");
        counts[part[i]]++;
        if(i>0 && part[i]!=part[i-1]) cut++;
        require(perm[i]>=0 && perm[i]<global_n,"global ordering index is invalid");
        require(!seen[perm[i]],"ordering is not a permutation");
        seen[perm[i]]=1;
    }
    require(counts[0]>=global_n/3 && counts[1]>=global_n/3 && cut>0,"partition is unbalanced");
    SCOTCH_stratExit(&strategy);
    if(rank==0) printf("PASS: %s %d.%d.%d, balanced partition, ordering, ranks=%d\n",
#ifdef USE_PTSCOTCH
        "PT-Scotch (MPI_THREAD_MULTIPLE)",
#else
        "Scotch",
#endif
        major,release,patch,ranks);
#ifdef USE_PTSCOTCH
    MPI_Finalize();
#endif
    return 0;
}

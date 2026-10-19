#include <parmetis.h>
#include <stdio.h>
#include <stdlib.h>

static void require(int condition, const char *message, MPI_Comm comm) {
    if (!condition) {
        fprintf(stderr,"%s\n",message);
        MPI_Abort(comm,1);
    }
}
int main(int argc, char **argv) {
    MPI_Init(&argc,&argv);
    MPI_Comm comm=MPI_COMM_WORLD;
    int rank, ranks;
    MPI_Comm_rank(comm,&rank);
    MPI_Comm_size(comm,&ranks);
    require(ranks==2,"ParMETIS test requires two MPI ranks",comm);
    require(sizeof(idx_t)==4 && sizeof(real_t)==4,"ParMETIS requires the selected 32/32 ABI",comm);
    enum { local_n=32, global_n=64 };
    idx_t vtxdist[]={0,local_n,global_n}, xadj[local_n+1], adjncy[2*local_n];
    idx_t part[local_n], allpart[global_n], order[local_n], allorder[global_n];
    idx_t wgtflag=0, numflag=0, ncon=1, nparts=2, edgecut=-1, sizes[4];
    idx_t options[]={1,0,42,0};
    real_t tpwgts[]={(real_t)0.5,(real_t)0.5}, ubvec[]={(real_t)1.1};
    idx_t k=0;
    for(idx_t i=0;i<local_n;i++) {
        idx_t global=rank*local_n+i;
        xadj[i]=k;
        if(global>0) adjncy[k++]=global-1;
        if(global+1<global_n) adjncy[k++]=global+1;
    }
    xadj[local_n]=k;
    int result=ParMETIS_V3_PartKway(vtxdist,xadj,adjncy,NULL,NULL,&wgtflag,&numflag,
                  &ncon,&nparts,tpwgts,ubvec,options,&edgecut,part,&comm);
    require(result==METIS_OK,"distributed graph partition failed",comm);
    MPI_Allgather(part,local_n,MPI_INT,allpart,local_n,MPI_INT,comm);
    int counts[2]={0,0}, cut=0;
    for(int i=0;i<global_n;i++) {
        require(allpart[i]>=0 && allpart[i]<2,"partition index is invalid",comm);
        counts[allpart[i]]++;
        if(i>0 && allpart[i]!=allpart[i-1]) cut++;
    }
    require(counts[0]>=global_n/3 && counts[1]>=global_n/3,"partition is unbalanced",comm);
    require(cut>0 && edgecut==cut,"reported global edge cut is incorrect",comm);
    options[0]=0;
    result=ParMETIS_V3_NodeND(vtxdist,xadj,adjncy,&numflag,options,order,sizes,&comm);
    require(result==METIS_OK,"distributed nested dissection failed",comm);
    MPI_Allgather(order,local_n,MPI_INT,allorder,local_n,MPI_INT,comm);
    int seen[global_n]={0};
    for(int i=0;i<global_n;i++) {
        require(allorder[i]>=0 && allorder[i]<global_n,"ordering index is invalid",comm);
        require(!seen[allorder[i]],"ordering is not a global permutation",comm);
        seen[allorder[i]]=1;
    }
    if(rank==0) printf("PASS: ParMETIS %d.%d.%d, two MPI ranks, balanced partition, edge cut=%d, global ordering\n",
        PARMETIS_MAJOR_VERSION,PARMETIS_MINOR_VERSION,PARMETIS_SUBMINOR_VERSION,cut);
    MPI_Finalize();
    return 0;
}

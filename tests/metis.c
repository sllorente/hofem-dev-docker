#include <metis.h>
#include <stdio.h>
#include <stdlib.h>

static void require(int condition, const char *message) {
    if (!condition) {
        fprintf(stderr, "%s\n", message);
        exit(EXIT_FAILURE);
    }
}

int main(void) {
    require(sizeof(idx_t)==4 && sizeof(real_t)==4,"METIS must use the selected 32/32 ABI");
    idx_t n=8, ncon=1, nparts=2, objval=-1;
    idx_t xadj[]={0,1,3,5,7,9,11,13,14};
    idx_t adjncy[]={1,0,2,1,3,2,4,3,5,4,6,5,7,6};
    idx_t options[METIS_NOPTIONS], part[8], perm[8], iperm[8];
    real_t tpwgts[]={(real_t)0.5,(real_t)0.5};
    real_t ubvec[]={(real_t)1.1};
    require(METIS_SetDefaultOptions(options)==METIS_OK,"default options failed");
    options[METIS_OPTION_SEED]=42;
    options[METIS_OPTION_NUMBERING]=0;
    options[METIS_OPTION_CONTIG]=1;
    require(METIS_PartGraphKway(&n,&ncon,xadj,adjncy,NULL,NULL,NULL,&nparts,
                              tpwgts,ubvec,options,&objval,part)==METIS_OK,
            "graph partition failed");
    int counts[2]={0,0}, cut=0;
    for(idx_t i=0;i<n;i++) {
        require(part[i]>=0 && part[i]<nparts,"partition index is invalid");
        counts[part[i]]++;
        for(idx_t j=xadj[i];j<xadj[i+1];j++)
            if(i<adjncy[j] && part[i]!=part[adjncy[j]]) cut++;
    }
    require(counts[0]>=3 && counts[1]>=3,"partition is unbalanced");
    require(cut>0 && objval==cut,"reported edge cut is incorrect");
    require(METIS_NodeND(&n,xadj,adjncy,NULL,options,perm,iperm)==METIS_OK,
            "nested dissection failed");
    for(idx_t i=0;i<n;i++) {
        require(perm[i]>=0 && perm[i]<n,"permutation index is invalid");
        require(iperm[perm[i]]==i,"permutation inverse is incorrect");
    }
    printf("PASS: METIS %d.%d.%d, idx_t=%zu bits, real_t=%zu bits, edge cut=%d\n",
           METIS_VER_MAJOR,METIS_VER_MINOR,METIS_VER_SUBMINOR,
           8*sizeof(idx_t),8*sizeof(real_t),cut);
    return EXIT_SUCCESS;
}

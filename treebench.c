// A regular, pointer-based C implementation.

// This uses heap-allocation for the trees, just like the other
// benchmarks.

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#ifdef PARALLEL
#include <cilk/cilk.h>
#endif
#include <inttypes.h>
#include <malloc.h>
#include <stdint.h>
#include <time.h>

// Manual layout:
// one byte for each tag, 64 bit integers
typedef long long int Num;
// typedef int64_t Num;


// This controls whether we use a word for tags:
#ifdef UNALIGNED
#warning "Using unaligned mode / packed-struct attribute"
#define ATTR  __attribute__((__packed__))
#else
#define ATTR
#endif

enum Mode { Build, Sum, Add1 };

enum ATTR Type { Leaf, Node };

static int num_par_levels = 5;

// struct Tree;

typedef struct ATTR Tree {
    enum Type tag;
    union {
      struct { Num elem; };
      struct { struct Tree* l;
               struct Tree* r; };
    };
} Tree;

// Memory management
//--------------------------------------------------------------------------------

void deleteTree(Tree* t) {
  if (t->tag == Node) {
    deleteTree(t->l);
    deleteTree(t->r);
  }
  free(t);
}

#ifdef BUMPALLOC
#warning "Using bump allocator."
// Here we use one heap_ptr per thread:
#ifdef PARALLEL
// This doesn't seem to make a noticible difference in performance.  But just
// to be careful, we disable it when compiling in single-threaded mode.
__thread char* heap_ptr = (char*)0;
#else
char* heap_ptr = (char*)0;
#endif
  
// For simplicity just use a single large slab:
#define INITALLOC { if (! heap_ptr) { heap_ptr = malloc(500 * 1000 * 1000); } }
#define ALLOC(n) (heap_ptr += n)
// HACK, delete by rewinding:
#define DELTREE(p) { heap_ptr = (char*)p; }
#else
#define INITALLOC {}
#define ALLOC malloc
#define DELTREE deleteTree
#endif

// For parallel execution:
int num_workers = 0;

//--------------------------------------------------------------------------------


// Helper function
// This makes leaves 1..N
Tree* fillTree_linear(int n, Num root) {
  Tree* tr = (Tree*)ALLOC(sizeof(Tree));
  if (n == 0) {
    tr->tag = Leaf;
    tr->elem = root;
  } else {
    tr->tag = Node;
    tr->l = fillTree_linear(n-1, root);;
    tr->r = fillTree_linear(n-1, root + (1<<(n-1)));
  }
  return tr;
}

// This makes leaves constant, 1:
Tree* fillTree(int n) {
  Tree* tr = (Tree*)ALLOC(sizeof(Tree));
  if (n == 0) {
    tr->tag = Leaf;
    tr->elem = 1;
  } else {
    tr->tag = Node;
    tr->l = fillTree(n-1);;
    tr->r = fillTree(n-1);
  }
  return tr;
}

Tree* buildTree(int n) {
  //  return fillTree_linear(n, 1);
  return fillTree(n);
}


void printTree(Tree* t) {
  if (t->tag == Leaf) {
    // printf("%" PRId64, t->elem);
    printf("%lld", t->elem);
    return;
  } else {
    printf("(");
    printTree(t->l);
    printf(",");
    printTree(t->r);
    printf(")");
    return;
  }
}

// Out-of-place add1 to leaves.
Tree* add1Tree(Tree* t) {
  Tree* tout = (Tree*)ALLOC(sizeof(Tree));
  tout->tag = t->tag;
  if (t->tag == Leaf) {
    tout->elem = t->elem + 1;
  } else {
    tout->l = add1Tree(t->l);
    tout->r = add1Tree(t->r);
  }
  return tout;
}


Num sumTree(Tree* t) {
  if (t->tag == Leaf) {
    return t->elem;
  } else {
    return sumTree(t->l) + sumTree(t->r);
  }
}


#ifdef PARALLEL
// Takes the number of parallel levels as argument:
Tree* add1TreePar(Tree* t, int n) {
  if (n == 0) return add1Tree(t);

  Tree* tout = (Tree*)ALLOC(sizeof(Tree));
  tout->tag = t->tag;
  if (t->tag == Leaf) {
    tout->elem = t->elem + 1;
  } else {
    tout->l = cilk_spawn add1TreePar(t->l, n-1);
    tout->r = add1TreePar(t->r, n-1);
  }
  cilk_sync;
  return tout;
}
#endif

int compare_doubles (const void *a, const void *b)
{
  const double *da = (const double *) a;
  const double *db = (const double *) b;
  return (*da > *db) - (*da < *db);
}

double avg(const double* arr, int n) {
  double sum = 0.0;
  for(int i=0; i<n; i++) sum += arr[i];
  return sum / (double)n;
}

double difftimespecs(struct timespec* t0, struct timespec* t1) {
  return (double)(t1->tv_sec - t0->tv_sec)
    + ((double)(t1->tv_nsec - t0->tv_nsec) / 1000000000.0);
}

static clockid_t which_clock = CLOCK_MONOTONIC_RAW;

void bench_single_pass(Tree* tr, int iters)
{
    struct timespec begin, end;

    iters = -iters;
    double trials[iters];
    for (int i=0; i<iters; i++)
    {
        clock_gettime(which_clock, &begin);
#ifdef PARALLEL
        Tree* t2 = add1TreePar(tr, num_par_levels);
#else
        Tree* t2 = add1Tree(tr);
#endif
        DELTREE(t2);
        clock_gettime(which_clock, &end);
        double time_spent = difftimespecs(&begin, &end);
        if(iters < 100) {
            printf(" %lld", (long long)(time_spent * 1000));
            fflush(stdout);
        }
        trials[i] = time_spent;
    }
    qsort(trials, iters, sizeof(double), compare_doubles);
    printf("\nSorted: ");
    for(int i=0; i<iters; i++)
        printf(" %d",  (int)(trials[i] * 1000));
    printf("\nMINTIME: %lf\n",    trials[0]);
    printf("MEDIANTIME: %lf\n", trials[iters / 2]);
    printf("MAXTIME: %lf\n", trials[iters - 1]);
    printf("AVGTIME: %lf\n", avg(trials,iters));
}

void bench_add1_batch(Tree* tr, int iters)
{
    struct timespec begin, end;

    printf("Timing iterations as a batch\n");
    printf("ITERS: %d\n", iters);
#ifdef BUMPALLOC
    char* starting_heap_pointer = heap_ptr;
    long allocated_bytes;
#endif
    clock_gettime(which_clock, &begin);
    for (int i=0; i<iters; i++)
    {
#ifdef PARALLEL
        Tree* t2 = add1TreePar(tr, 5);
#else
        Tree* t2 = add1Tree(tr);
#endif
#ifdef BUMPALLOC
        allocated_bytes = (long)(heap_ptr - starting_heap_pointer);
#endif
        DELTREE(t2);
    }
    clock_gettime(which_clock, &end);
#ifdef BUMPALLOC
    // TODO: Do some more work to tally bytes alloc on all threads:
    printf("Bytes allocated (on this thread) during whole batch:\n");
    printf("BYTESALLOC: %ld\n", allocated_bytes);
#else
    malloc_stats();
#endif
    double time_spent = difftimespecs(&begin, &end);
    printf("BATCHTIME: %lf\n", time_spent);
}


void bench_build_batch(int depth, int iters)
{
    struct timespec begin, end;
    Tree* t2;

    printf("BUILD: Timing iterations as a batch\n");
    printf("ITERS: %d\n", iters);
#ifdef BUMPALLOC
    char* starting_heap_pointer = heap_ptr;
    long allocated_bytes;
#endif
    clock_gettime(which_clock, &begin);
    for (int i=0; i<iters; i++)
    {
#ifdef PARALLEL
      printf("No parallel build yet...\n");
      exit(1);
#else      
      t2 = buildTree(depth);      
#endif
#ifdef BUMPALLOC
        allocated_bytes = (long)(heap_ptr - starting_heap_pointer);
#endif
      DELTREE(t2);
    }
    clock_gettime(which_clock, &end);
#ifdef BUMPALLOC
    printf("Bytes allocated during whole batch:\n");
    printf("BYTESALLOC: %ld\n", allocated_bytes);
#else
    malloc_stats();
#endif
    double time_spent = difftimespecs(&begin, &end);
    printf("BATCHTIME: %lf\n", time_spent);
}


void bench_sum_batch(Tree* tr, int iters)
{
    struct timespec begin, end;
    Num sum;
    printf("SUM: Timing iterations as a batch\n");
    printf("ITERS: %d\n", iters);

    clock_gettime(which_clock, &begin);
    for (int i=0; i<iters; i++)
    {
#ifdef PARALLEL
      printf("No parallel sum yet...\n");
      exit(1);
#else      
      sum = sumTree(tr);
#endif
    }
    clock_gettime(which_clock, &end);

    printf("Final sum of leaves: %lld \n", sum);
    double time_spent = difftimespecs(&begin, &end);
    printf("BATCHTIME: %lf\n", time_spent);
}



int main(int argc, char** argv)
{
    int depth; // first arg
    int iters; // second arg
    char* modestr;
    enum Mode mode;

    if (argc <= 3)
    {
        fprintf(stderr,"Expected three arguments, <build|add1|sum> <depth> <iters>\n");
        fprintf(stderr,"Iters can be negative to time each iteration rather than all together\n");
        exit(1);
    }

    modestr = argv[1];
    depth = atoi(argv[2]);
    iters = atoi(argv[3]);

    printf("Benchmarking in mode: %s\n", modestr);
    
    if (!strcmp(modestr, "sum"))   mode = Sum; 
    else if (!strcmp(modestr, "build")) mode = Build;
    else if (!strcmp(modestr, "add1"))  mode = Add1;
    else { printf("Error: unrecognized mode.\n"); exit(1); }

    printf("SIZE: %d\n", depth);
    printf("sizeof(Tree) = %lu\n", sizeof(Tree));
    printf("sizeof(enum Type) = %lu\n", sizeof(enum Type));
    printf("Building tree, depth %d.  Benchmarking %d iters.\n", depth, iters);
#ifdef PARALLEL
    num_workers = __cilkrts_get_nworkers();
    printf("Number of parallel threads: %d\n", num_workers);
    printf("Depth of parallel recursions: %d\n", num_par_levels);

#ifdef BUMPALLOC    
    char** heap_addrs = calloc(num_workers, sizeof(char*));
    // HACK to execute on every cilk worker:
    cilk_for(int i=0; i < 100000000; i++) {
      INITALLOC;
      heap_addrs[__cilkrts_get_worker_number()] = & heap_ptr;
    }
    printf("   ");
    for(int i=0; i<num_workers; i++)
      printf("%p ", heap_addrs[i]);
    printf("\n  diffs: ");
    for(int i=1; i<num_workers; i++)
      printf("%ld ", heap_addrs[i] - heap_addrs[i-1]);
    printf("\nDone with hacky parallel/bumpalloc allocator init: \n");
#endif    
#else
    INITALLOC;
#endif
    struct timespec begin, end;
    clock_gettime(which_clock, &begin);
    Tree* tr = buildTree(depth);
    clock_gettime(which_clock, &end);
    double time_spent = difftimespecs(&begin, &end);
    printf("Done building input tree, took %lf seconds\n\n", time_spent);
    if (depth <= 5)
    {
        printf("Input tree:\n");
        printTree(tr); printf("\n");
    }

    printf("Running traversals (ms): ");

    if (iters < 0)
    {
      bench_single_pass(tr, iters);
      DELTREE(tr);
    }
    else
      {
      switch(mode) {
      case Add1: 
	bench_add1_batch(tr, iters);
	DELTREE(tr);
        break;
      case Sum:  
	bench_sum_batch(tr, iters);
	DELTREE(tr);
        break;
      case Build: 
	DELTREE(tr); // LAME
	bench_build_batch(depth,iters);
        break;
    default: printf("Internal error\n"); exit(1);
    }
    }
    return 0;
}

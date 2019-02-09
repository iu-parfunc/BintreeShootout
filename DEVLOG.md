
[2016.11.26] {Tripped Cilk scheduler bug}
-----------------------------------------

This was on icc (ICC) 16.0.2 20160204

    $ CILK_NWORKERS=2 ./treebench_c_bumpalloc_parallel.exe add1  6 524288 
    scheduler.c:1642: cilk assertion failed: NULL == cilk_fiber_get_data(w->l->scheduling_fiber)->owner



[2016.11.27] {Debugging Segfaults}
----------------------------------------

Switched to TBB, but still having segfaults.  Segfaults that valgrind
does not catch.  RR chaos mode is great though.

    Loaded symbols for /lib64/ld-linux-x86-64.so.2
    0x00007fb42ad212d0 in _start () from /lib64/ld-linux-x86-64.so.2
    (rr) cont
    Continuing.
    Benchmarking in mode: add1
    SIZE: 20
    sizeof(Tree) = 24
    sizeof(enum Type) = 4
    Building tree, depth 20.  Benchmarking 8192 iters.
    Depth of parallel recursions: 5
    Number of parallel threads: 2
    Arena size for bump alloc: 4000000000
       0x3b5f3b73a010 0x36e522ccf010 
      diffs: -4,922,446,098,432 
    Done with hacky parallel/bumpalloc allocator init: 
    Done building input tree, took 0.020460 seconds

    Running traversals (ms): Timing iterations as a batch
    ITERS: 8192
    [New Thread 43186.43187]

    Program received signal SIGSEGV, Segmentation fault.
    [Switching to Thread 43186.43187]
    0x000000000040138b in add1Tree (t=0x3b5f3d3ee7f8) at treebench.c:169
    169       tout->tag = t->tag;
    (rr) bt
    #0  0x000000000040138b in add1Tree (t=0x3b5f3d3ee7f8) at treebench.c:169
    #1  0x00000000004013bc in add1Tree (t=0x3b5f3d3ee7e0) at treebench.c:173
    #2  0x00000000004013dc in add1Tree (t=0x3b5f3d3ee780) at treebench.c:174
    #3  0x00000000004013bc in add1Tree (t=0x3b5f3d3ee768) at treebench.c:173
    #4  0x00000000004013dc in add1Tree (t=0x3b5f3d3ee5e8) at treebench.c:174
    #5  0x00000000004013dc in add1Tree (t=0x3b5f3d3ee2e8) at treebench.c:174
    #6  0x00000000004013dc in add1Tree (t=0x3b5f3d3edce8) at treebench.c:174
    #7  0x00000000004013dc in add1Tree (t=0x3b5f3d3ed0e8) at treebench.c:174
    #8  0x00000000004013bc in add1Tree (t=0x3b5f3d3ed0d0) at treebench.c:173
    #9  0x00000000004013dc in add1Tree (t=0x3b5f3d3ea0d0) at treebench.c:174
    #10 0x00000000004013bc in add1Tree (t=0x3b5f3d3ea0b8) at treebench.c:173
    #11 0x00000000004013bc in add1Tree (t=0x3b5f3d3ea0a0) at treebench.c:173
    #12 0x00000000004013bc in add1Tree (t=0x3b5f3d3ea088) at treebench.c:173
    #13 0x00000000004013dc in add1Tree (t=0x3b5f3d3ba088) at treebench.c:174
    #14 0x00000000004013bc in add1Tree (t=0x3b5f3d3ba070) at treebench.c:173
    #15 0x00000000004013bc in add1Tree (t=0x3b5f3d3ba058) at treebench.c:173
    #16 0x0000000000401616 in add1TreePar (t=0x3b5f3d3ba058, n=0) at treebench.c:193
    #17 0x00000000004019c0 in add1TreePar (t=0x3b5f3d23a058, n=1) at treebench.c:207
    #18 0x00000000004019c0 in add1TreePar (t=0x3b5f3cf3a058, n=2) at treebench.c:207
    #19 0x0000000000400f03 in __$U0 (this=0x7fb42b961b40) at treebench.c:206

In this case the output tag causes the segfault, at address
0x36e611382010.

Here are the offsets of that position relative to the base of each
bumpalloc arena:

  1st arena: (0x36e611382010 - 0x3b5f3b73a010) = -4,918,446,096,384
  2nd arena: (0x36e611382010 - 0x36e522ccf010) =  4,000,002,048

Ok, so it's clearly been allocated on the second arena.  BUT, why the
heck would there be 4GB of allocation on these settings?


[2019.02.08] {Brief run on Drone}
----------------------------------------

Adding Stalin and spot-checking other on my workstation (Intel
i5-2400).

Tree depth 20.  Below is the per-iter add1 avg, in seconds:

 * Racket   0.07470
 * Stalin   0.03749
 * Chez     0.02235
 * Java     0.01952
 * MLton    0.00894

 * Stalin (-On only) 0.05882


# Building
# ==============================================================================

all: treebench_mlton.exe treebench_ocaml.exe \
     treebench_rust.exe treebench.class c ghc

c: treebench_c.exe treebench_c_bumpalloc.exe treebench_c_bumpalloc_unaligned.exe \
   treebench_c_cilk.exe treebench_c_bumpalloc_cilk.exe \
   treebench_c_tbb.exe  treebench_c_bumpalloc_tbb.exe

ghc: treebench_ghc_strict.exe treebench_ghc_lazy.exe 


# Disabling for now, requires beta channel of rust:
# treebench_rust_sys_alloc.exe 


# Match whichever version the docker image is using:
RESOLVER=lts-6.23
# RESOLVER=lts-7.1

GHC = stack --install-ghc --resolver=$(RESOLVER) exec ghc -- -rtsopts -threaded

CC = gcc
# clang icc

CXX = g++
# clang++ icpc

# time.h is missing features in c11/c++11:
CPPOPTS = -std=gnu++11 -lrt
COPTS   = -std=gnu11   -lrt

PAROPTS = -DPARALLEL 

ifeq ($(DEBUG),)
  CPPOPTS += -O3 -Wno-cpp
  COPTS   += -O3 -Wno-cpp
else
  CPPOPTS += -O0 -g -DDEBUG
  COPTS += -O0 -g -DDEBUG
endif


ghc: treebench_ghc_strict.exe treebench_ghc_lazy.exe

treebench_ghc_strict.exe: treebench.hs
	time $(GHC) -odir ghc_strict/ -O2 -rtsopts $^ -o $@

treebench_ghc_lazy.exe: treebench_lazy.hs
	time $(GHC) -odir ghc_lazy/ -O2 -rtsopts $^ -o $@

stalin: treebench_stalin.exe
treebench_stalin.exe: treebench_stalin.sc
	time stalin -On -Ob -Om -Or -Ot -d -d1 -k -copt -O3 $^
	mv treebench_stalin $@ 

mlton: treebench_mlton.exe
treebench_mlton.exe: treebench.sml
	time mlton -output $@ $^

ocaml: treebench_ocaml.exe
treebench_ocaml.exe: treebench.ml
	time ocamlopt.opt $^ -o $@

fsharp: treebench_fsharp.exe
treebench_fsharp.exe: treebench.fs
	time fsharpc --mlcompatibility $^ -o $@

treebench_rust.exe: treebench.rs
	time rustc $^ -o $@ -O

treebench_rust_sys_alloc.exe: treebench_sys_alloc.rs
	time rustc $^ -o $@ -O

treebench_c.exe: treebench.c
	time $(CC) $(COPTS) $^ -o $@


treebench_c_cilk.exe: treebench.c
	time $(CC) $(PAROPTS) $(COPTS) -fcilkplus -lcilkrts $^ -o $@ 

treebench_c_bumpalloc_cilk.exe: treebench.c
	time $(CC) $(PAROPTS) $(COPTS) -fcilkplus -lcilkrts -DBUMPALLOC $^ -o $@ 

treebench_c_tbb.exe: treebench.c
	time $(CXX) $(PAROPTS) $(CPPOPTS) -DTBB_PARALLEL $^ -o $@ -ltbb

treebench_c_bumpalloc_tbb.exe: treebench.c
	time $(CXX) $(PAROPTS) $(CPPOPTS) -DTBB_PARALLEL -DBUMPALLOC $^ -o $@ -ltbb


treebench_c_bumpalloc.exe: treebench.c
	time $(CC) $(COPTS) -DBUMPALLOC $^ -o $@ 

# this version uses 1 byte for tags
treebench_c_bumpalloc_unaligned.exe: treebench.c
	time $(CC) $(COPTS) -DBUMPALLOC -DUNALIGNED $^ -o $@ 

treebench.class: treebench.java
	time javac $^ 



# Running
# ==============================================================================

DEPTH = 20
DEFAULT_ITERS = 17
# Or "sum" or "build":
DEFAULT_PASS=add1

DEFAULT_ARGS= $(DEFAULT_PASS) $(DEPTH) $(DEFAULT_ITERS)

run_small:
	$(MAKE) DEPTH=6 DEFAULT_ITERS=10 run_all

run_small_core:
	$(MAKE) DEPTH=6 DEFAULT_ITERS=10 run_core

# TODO: replace with an hsbencher harness / Criterion:
run_all: all run_core
	./treebench_mlton.exe       $(DEFAULT_ARGS)
	./treebench_ocaml.exe       $(DEFAULT_ARGS)
	./treebench_rust.exe        $(DEFAULT_ARGS)
	$(MAKE) run_chez
	$(MAKE) run_java

# the main ones we are interested in benchmarking:
run_core: run_c run_ghc
	$(MAKE) run_racket
#	./treebench_rust_sys_alloc.exe $(DEPTH)

run_ghc: ghc
	./treebench_ghc_strict.exe  seq $(DEPTH) $(DEFAULT_ITERS)
	./treebench_ghc_lazy.exe    $(DEFAULT_ARGS)

LAUNCHER = 

run_c: export CILK_NWORKERS = 2
run_c: c	
	$(LAUNCHER) ./treebench_c.exe                     $(DEFAULT_ARGS)
	$(LAUNCHER) ./treebench_c_cilk.exe                $(DEFAULT_ARGS)
	$(LAUNCHER) ./treebench_c_bumpalloc_cilk.exe      $(DEFAULT_ARGS)
	$(LAUNCHER) ./treebench_c_bumpalloc.exe           $(DEFAULT_ARGS)
	$(LAUNCHER) ./treebench_c_bumpalloc_unaligned.exe $(DEFAULT_ARGS)
# See FIXME in file:
#	$(LAUNCHER) ./treebench_c_bumpalloc_tbb.exe       $(DEFAULT_ARGS)
#	$(LAUNCHER) ./treebench_c_tbb.exe                 $(DEFAULT_ARGS)

valgrind_c:
	$(MAKE) LAUNCHER="valgrind -q" DEPTH=4 run_c

run_chez:
	scheme --script treebench.ss $(DEFAULT_ARGS)

run_racket:
	racket treebench.rkt         $(DEFAULT_ARGS)

run_java: treebench.class
	java treebench               $(DEFAULT_ARGS)

# Example of how to run with Jemalloc.
# Jemalloc significantly DECREASES throughput, and then does not SCALE WELL:
# For example, on swarm, 2^20 gets 1.63X speedup from 646ms to 396ms, 1 to 18 cores.
# (This is with jemalloc version 3.5.1-2 on ubntu 14.04.)
#
# For comparison, it takes 67ms with the builtin malloc implemntation
# on 1 thread on the same machine.  Adding Cilk with 5 layers of
# parallel recursion actually slows it down to 84ms somehow on 1 core.
# That's the best time.  The time on >1 core is worse.  (Well, it does
# narrowly catch back up at 12 cores.)
run_jemalloc:
# I see a 
	time CILK_NWORKERS=8 LD_PRELOAD=libjemalloc.so  ./treebench_c_parallel.exe add1 20 10
# One especially weird thing is that the SEQUENTIAL version shows a
# slowdown with scaling Cilk workers:
#	time CILK_NWORKERS=8 LD_PRELOAD=libjemalloc.so  ./treebench_c.exe add1 20 10

# ================================================================================

docker:
	docker build -t bintree-bench .

clean:
	rm -f *.exe *.o *.hi treebench treebench_lazy *.cmi *.cmo *.cmx

.PHONY: all clean ghc c ghc buildtree stack_build ocaml mlton fsharp 
.PHONY: run_chez run_java run_all run_small run_small_core run_c run_ghc


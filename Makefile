
# Building
# ==============================================================================

all: treebench_mlton.exe treebench_ocaml.exe \
     treebench_rust.exe treebench.class c ghc

c: treebench_c.exe treebench_c_bumpalloc.exe treebench_c_bumpalloc_unaligned.exe \
   treebench_c_parallel.exe treebench_c_bumpalloc_parallel.exe \
   treebench_c_packed.exe treebench_c_packed_loop.exe treebench_c_packed_structs.exe treebench_c_packed_parallel3.exe

# These are unfinished, or behaving badly:
# treebench_c_packed_parallel.exe 
# treebench_c_packed_parallel2.exe

ghc: treebench_ghc_strict.exe treebench_ghc_lazy.exe treebench_ghc_packed.exe


# Disabling for now, requires beta channel of rust:
# treebench_rust_sys_alloc.exe 

# Unfinished:
# treebench_rust_packed.exe

# Match whichever version the docker image is using:
RESOLVER=lts-6.23
# RESOLVER=lts-7.1

GHC = stack --install-ghc --resolver=$(RESOLVER) exec ghc -- -rtsopts -threaded

CC ?= gcc
# clang icc

# CPP ?= g++
# clang++ icpc

# time.h is missing features in c11/c++11:
CPPOPTS = -std=gnu++11 -lrt
COPTS   = -std=gnu11   -lrt

PAROPTS = -DPARALLEL -fcilkplus -lcilkrts

ifeq ($(DEBUG),)
  CPPOPTS += -O3 
  COPTS += -O3 
else
  CPPOPTS += -O0 -g 
  COPTS += -O0 -g
endif


ghc: treebench_ghc_strict.exe treebench_ghc_lazy.exe

treebench_ghc_strict.exe: treebench.hs
	time $(GHC) -odir ghc_strict/ -O2 -rtsopts $^ -o $@

treebench_ghc_lazy.exe: treebench_lazy.hs
	time $(GHC) -odir ghc_lazy/ -O2 -rtsopts $^ -o $@

treebench_ghc_packed.exe: treebench_packed.hs
	time $(GHC) -odir ghc_packed/ -O2 -rtsopts $^ -o $@

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

# treebench_rust_packed.exe: treebench_packed.rs
# 	time rustc $^ -o $@ -O

treebench_c.exe: treebench.c
	time $(CC) $(COPTS) $^ -o $@

treebench_c_parallel.exe: treebench.c
	time $(CC) $(PAROPTS) $(COPTS) $^ -o $@ 

treebench_c_bumpalloc.exe: treebench.c
	time $(CC) $(COPTS) -DBUMPALLOC $^ -o $@ 

treebench_c_bumpalloc_parallel.exe: treebench.c
	time $(CC) $(PAROPTS) $(COPTS) -DBUMPALLOC $^ -o $@ 

# this version uses 1 byte for tags
treebench_c_bumpalloc_unaligned.exe: treebench.c
	time $(CC) $(COPTS) -DBUMPALLOC -DUNALIGNED $^ -o $@ 

HEADERS=include/main_fragment_packed.h

treebench_c_packed.exe: treebench_packed.c $(HEADERS)
	time $(CC) $(COPTS) treebench_packed.c -o $@ 

treebench_c_packed_loop.exe: treebench_packed_loop.c $(HEADERS)
	time $(CC) $(COPTS) treebench_packed_loop.c -o $@ 

treebench_c_packed_structs.exe: treebench_packed_structs.c $(HEADERS)
	time $(CC) $(COPTS) treebench_packed_structs.c -o $@ 

treebench_c_packed_parallel.exe: treebench_packed_parallel.c
	time $(CPP) -DPARALLEL -fpermissive -fcilkplus $(CPPOPTS) $^ -o $@ 

treebench_c_packed_parallel2.exe: treebench_packed_parallel2.c
	time $(CC) -DPARALLEL -fcilkplus $(COPTS) $^ -o $@

treebench_c_packed_parallel3.exe: treebench_packed_parallel3.c $(HEADERS)
	time $(CC) -DPARALLEL -fcilkplus $(COPTS) treebench_packed_parallel3.c -o $@ 

treebench.class: treebench.java
	time javac $^ 


# BuildTree benchmark
# ==============================================================================

TREELANGDIR=$(shell cd ..; pwd)
TREEC=$(shell cd ../TreeLang; stack exec -- which treec)

# Make sure the compiler is build and not stale:
stack_build:
	cd $(TREELANGDIR)/TreeLang; stack build

buildtree: stack_build buildtree_treelang_c_packed.exe
	raco make buildtree_treelang.sexp
# buildtree_treelang_c_pointer.exe

# Here we control the C file output in case we build in parallel:
buildtree_treelang_c_packed.exe: buildtree_treelang.sexp
	$(TREEC)  --packed --cfile=$(@:.exe=.c) --exefile $@ $^

buildtree_treelang_c_pointer.exe: buildtree_treelang.sexp
	$(TREEC)  --pointer --cfile=$(@:.exe=.c) --exefile $@ $^

# SumTree benchmark
# ==============================================================================
# Identical to buildtree.  s/buildtree/sumtree/

# --pointer not working yet:
sumtree: stack_build sumtree_treelang_c_packed.exe
	raco make sumtree_treelang.sexp

sumtree_treelang_c_packed.exe: sumtree_treelang.sexp
	$(TREEC)  --packed --cfile=$(@:.exe=.c) --exefile $@ $^

sumtree_treelang_c_pointer.exe: sumtree_treelang.sexp
	$(TREEC)  --pointer --cfile=$(@:.exe=.c) --exefile $@ $^




# Running
# ==============================================================================

# Or "sum" or "build":
MODE=add1
DEPTH=20
DEFAULT_ITERS=17
DEFAULT_PASS=add1

run_small:
	$(MAKE) DEPTH=6 DEFAULT_ITERS=10 run_all

run_small_core:
	$(MAKE) DEPTH=6 DEFAULT_ITERS=10 run_core

# TODO: replace with an hsbencher harness / Criterion:
run_all: all run_core
	./treebench_mlton.exe       $(DEPTH) $(DEFAULT_ITERS)
	./treebench_ocaml.exe       $(DEPTH)
	./treebench_rust.exe        $(DEFAULT_PASS) $(DEPTH) $(DEFAULT_ITERS)
	$(MAKE) run_chez
	$(MAKE) run_java

# the main ones we are interested in benchmarking:
run_core: c ghc
	./treebench_ghc_strict.exe  seq $(DEPTH) $(DEFAULT_ITERS)
	./treebench_ghc_lazy.exe    $(DEFAULT_PASS) $(DEPTH) $(DEFAULT_ITERS)
	./treebench_c.exe           $(MODE) $(DEPTH) $(DEFAULT_ITERS)
	./treebench_c_packed.exe    $(DEPTH) $(DEFAULT_ITERS)
	./treebench_c_packed_loop.exe $(DEPTH) $(DEFAULT_ITERS)
	$(MAKE) run_racket
	$(MAKE) run_racket_packed

#	./treebench_rust_sys_alloc.exe $(DEPTH) 

run_chez:
	scheme --script treebench.ss $(DEFAULT_PASS) $(DEPTH) $(DEFAULT_ITERS)

run_racket:
	racket treebench.rkt $(DEFAULT_PASS) $(DEPTH) $(DEFAULT_ITERS)

run_racket_packed:
	racket treebench_packed.rkt $(DEPTH)

run_java: treebench.class
	java treebench $(DEFAULT_PASS) $(DEPTH) 33

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

.PHONY: all clean ghc run_chez run_java run_all run_small c ghc buildtree stack_build ocaml mlton fsharp

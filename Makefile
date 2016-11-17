
# Building
# ==============================================================================

all: treebench_mlton.exe treebench_ocaml.exe \
     treebench_rust.exe treebench.class c ghc

c: treebench_c.exe treebench_c_bumpalloc.exe treebench_c_bumpalloc_unaligned.exe treebench_c_parallel.exe 

ghc: treebench_ghc_strict.exe treebench_ghc_lazy.exe 


# Disabling for now, requires beta channel of rust:
# treebench_rust_sys_alloc.exe 


# Match whichever version the docker image is using:
RESOLVER=lts-6.23
# RESOLVER=lts-7.1

GHC = stack --install-ghc --resolver=$(RESOLVER) exec ghc -- -rtsopts -threaded

CC = gcc
# CC = clang

# CPP = icpc
CPP = g++
# CPP = clang++

# time.h is missing features in c11/c++11:
CPPOPTS = -std=gnu++11 -lrt
COPTS   = -std=gnu11   -lrt

ifeq ($(DEBUG),)
  CPPOPTS += -O3 
  COPTS += -O3 
else
  CPPOPTS += -O0 -g 
  COPTS += -O0 -g
endif


ghc: treebench_ghc_strict.exe treebench_ghc_lazy.exe

treebench_mlton.exe: treebench.sml
	time mlton -output $@ $^

treebench_ghc_strict.exe: treebench.hs
	time $(GHC) -O2 -rtsopts $^ -o $@

treebench_ghc_lazy.exe: treebench_lazy.hs
	time $(GHC) -O2 -rtsopts $^ -o $@


treebench_ocaml.exe: treebench.ml
	time ocamlopt.opt $^ -o $@

treebench_rust.exe: treebench.rs
	time rustc $^ -o $@ -O

treebench_rust_sys_alloc.exe: treebench_sys_alloc.rs
	time rustc $^ -o $@ -O

treebench_c.exe: treebench.c
	time $(CC) $(COPTS) $^ -o $@

treebench_c_parallel.exe: treebench.c
	time $(CC) -DPARALLEL -fcilkplus $(COPTS) $^ -o $@ 

treebench_c_bumpalloc.exe: treebench.c
	time $(CC) $(COPTS) -DBUMPALLOC $^ -o $@ 

# this version uses 1 byte for tags
treebench_c_bumpalloc_unaligned.exe: treebench.c
	time $(CC) $(COPTS) -DBUMPALLOC -DUNALIGNED $^ -o $@ 

treebench.class: treebench.java
	time javac $^ 



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
	$(MAKE) run_racket

#	./treebench_rust_sys_alloc.exe $(DEPTH) 

run_chez:
	scheme --script treebench.ss $(DEFAULT_PASS) $(DEPTH) $(DEFAULT_ITERS)

run_racket:
	racket treebench.rkt $(DEFAULT_PASS) $(DEPTH) $(DEFAULT_ITERS)

run_java: treebench.class
	java treebench $(DEFAULT_PASS) $(DEPTH) 33

docker:
	docker build -t bintree-bench .

clean:
	rm -f *.exe *.o *.hi treebench treebench_lazy *.cmi *.cmo *.cmx

.PHONY: all clean ghc run_chez run_java run_all run_small c ghc buildtree stack_build

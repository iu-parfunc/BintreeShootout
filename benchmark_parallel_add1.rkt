#lang typed/racket/base

(require "command_line_runner.rkt")

(define PASSNAME "treebench")

;; 16 threads for cutter, 18 for swarm:
(for ((threads (in-range 16 0 -1)))
  (printf "\nBenchmarking THREADS=~a\n" threads)
  (launch-cilk-parallel-benchmarks
   "./treebench_c_bumpalloc_cilk.exe add1 " PASSNAME
   "handwritten-c-pointer-bumpalloc-cilk" threads))


#lang typed/racket/base

;; WARNING: Code duplication with benchmark_buildtree.rkt

(require "command_line_runner.rkt" racket/system)

(system "make sumtree")

(define PASSNAME "sumtree")

;;(launch-benchmarks "./sumtree_gibbon_c_packed.exe -benchmark " PASSNAME "treelang-c-packed")

;;(launch-benchmarks "racket sumtree_gibbon.sexp " PASSNAME "treelang-racket")

;; (launch-benchmarks "racket treebench.rkt sum " PASSNAME "handwritten-racket")

;; (launch-benchmarks "java treebench sum " PASSNAME "handwritten-java")

;; (launch-benchmarks "scheme --script treebench.ss sum " PASSNAME "handwritten-chez")

;; (launch-benchmarks "./treebench_rust.exe sum " PASSNAME "handwritten-rust")

;; (launch-benchmarks "./treebench_ocaml.exe sum " PASSNAME "handwritten-ocaml")

;; (launch-benchmarks "./treebench_ghc_lazy.exe sum " PASSNAME "handwritten-ghc")

;; (launch-benchmarks "./treebench_mlton.exe sum " PASSNAME "handwritten-mlton")


; (launch-benchmarks "./sumtree_packed.exe " PASSNAME "treelang-c-packed")

(launch-benchmarks "./sumtree_pointer.exe " PASSNAME "treelang-c-pointer")

;  (launch-benchmarks "./sumtree_bumpalloc.exe " PASSNAME "treelang-c-bumpalloc")

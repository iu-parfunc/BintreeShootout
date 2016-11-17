#lang typed/racket/base

;; WARNING: Code duplication with benchmark_buildtree.rkt

(require "command_line_runner.rkt" racket/system)

(system "make sumtree")

(define PASSNAME "sumtree")

;;(launch-benchmarks "racket sumtree_treelang.sexp " PASSNAME "treelang-racket")

(launch-benchmarks "racket treebench.rkt sum " PASSNAME "handwritten-racket")

(launch-benchmarks "java treebench sum " PASSNAME "handwritten-java")

(launch-benchmarks "scheme --script treebench.ss sum " PASSNAME "handwritten-chez")

(launch-benchmarks "./treebench_rust.exe sum " PASSNAME "handwritten-rust")

(launch-benchmarks "./treebench_ocaml.exe sum " PASSNAME "handwritten-ocaml")

(launch-benchmarks "./treebench_ghc_lazy.exe sum " PASSNAME "handwritten-ghc")

(launch-benchmarks "./treebench_mlton.exe sum " PASSNAME "handwritten-mlton")

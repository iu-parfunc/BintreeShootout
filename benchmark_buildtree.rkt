#lang typed/racket/base

;; Run make buildtree before this

(require "command_line_runner.rkt" racket/system)

(system "make buildtree")

(define PASSNAME "buildtree")

;;(launch-benchmarks "racket buildtree_treelang.sexp " PASSNAME "treelang-racket")

;; NEW

(launch-benchmarks "./treebench_mlton.exe build " PASSNAME "handwritten-mlton")

(launch-benchmarks "racket treebench.rkt build " PASSNAME "handwritten-racket")

(launch-benchmarks "java treebench build " PASSNAME "handwritten-java")

(launch-benchmarks "scheme --script treebench.ss build " PASSNAME "handwritten-chez")

(launch-benchmarks "./treebench_rust.exe build " PASSNAME "handwritten-rust")

(launch-benchmarks "./treebench_ocaml.exe build " PASSNAME "handwritten-ocaml")

(launch-benchmarks "./treebench_c.exe build " PASSNAME "handwritten-c")

;;(launch-benchmarks "./treebench_ghc_lazy.exe build " PASSNAME "handwritten-ghc")
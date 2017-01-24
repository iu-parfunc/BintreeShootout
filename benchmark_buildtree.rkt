#lang typed/racket/base

;; Run make buildtree before this

(require "command_line_runner.rkt" racket/system)

(system "make buildtree")

(define PASSNAME "buildtree")

;;(launch-benchmarks "./buildtree_gibbon_c_packed.exe -benchmark " PASSNAME "treelang-c-packed")

;;(launch-benchmarks "racket buildtree_gibbon.sexp " PASSNAME "treelang-racket")

;; NEW

;; (launch-benchmarks "./treebench_mlton.exe build " PASSNAME "handwritten-mlton")

;; (launch-benchmarks "racket treebench.rkt build " PASSNAME "handwritten-racket")

;; (launch-benchmarks "java treebench build " PASSNAME "handwritten-java")

;; (launch-benchmarks "scheme --script treebench.ss build " PASSNAME "handwritten-chez")

;; (launch-benchmarks "./treebench_rust.exe build " PASSNAME "handwritten-rust")

;; (launch-benchmarks "./treebench_ocaml.exe build " PASSNAME "handwritten-ocaml")

;; (launch-benchmarks "./treebench_c_packed.exe build " PASSNAME "handwritten-c-packed")

;; (launch-benchmarks "./treebench_c.exe build " PASSNAME "handwritten-c")

;;(launch-benchmarks "./treebench_ghc_lazy.exe build " PASSNAME "handwritten-ghc")


(launch-benchmarks "./buildtree_packed.exe " PASSNAME "treelang-c-packed")

(launch-benchmarks "./buildtree_pointer.exe " PASSNAME "treelang-c-pointer")

(launch-benchmarks "./buildtree_bumpalloc.exe " PASSNAME "treelang-c-bumpalloc")

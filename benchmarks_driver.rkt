#lang typed/racket/base

(require racket/system
	 racket/match
	 racket/string
     racket/port)

(provide driver
         cilk-parallel-driver 
         ghc-parallel-driver)

(define target-time 1.0)
(define ARGMAX 25)
;; Retry a run that errors up to this many times.  This is here
;; because we triggered a weird Cilk bug;
;;    scheduler.c:1642: cilk assertion failed:
;;      NULL == cilk_fiber_get_data(w->l->scheduling_fiber)->owner
(define RETRIES : Integer 10)

;; CSV
;; NAME, VARIANT, ARGS, ITERS, MEANTIME

;; `read-line`, `split-string`, `(match _ [(list "BATCHTIME:" t) …` right?
;; reads until it finds BATCHTIME
(define (read-batchtime [port : Input-Port]
                        [err-port : Input-Port]
                        [cmd : String]
                        [get-exit-code : (-> (U Byte False))])
               : (U #f Real)
  (define line (read-line port 'any))
  (if (eof-object? line)
      (begin (printf "ERROR: Got premature EOF before expected output. Process returned ~s.~n"
                     (get-exit-code))
             (printf "stderr: ~s~n" (port->string err-port))
             (printf "Command was:~n    $ ~a~n" cmd)
             #f
             )
      (begin
        ; (printf "Processing line from subprocess: ~a\n" line)
        (let ([strs (string-split (cast line String))])
          (match strs
            [`("BATCHTIME:" ,t)
             (begin ; (printf "BATCHTIME READ ~a" t)
               (cast (string->number t) Real))]
            [_ ;;(begin (displayln strs) 
             (read-batchtime port err-port cmd get-exit-code)])))))

;; port that proccess wrote to
(define (get-input-port ls)
  (match ls
   [`(,ip ,op ,pid ,stde ,proc)
    ip]))

(define (get-proc ls)
  (match ls
    [`(,ip ,op ,pid ,stde ,proc)
     proc]))

(define (get-output-port ls)
  (match ls
    [`(,ip ,op ,pid ,stde ,proc)
     op]))

(define (get-error-port ls)
  (match ls
    [`(,ip ,op ,pid ,stde ,proc)
     stde]))

(define (driver [csv-port : Output-Port] [exec : String] [pass-name : String]
		[variant : String])
  (fprintf csv-port "NAME, VARIANT, ARGS, ITERS, MEANTIME\n") ;; start csv file
  
  ;; loop through args 1 to 25
  (for ([args (in-range 1 (+ 1 ARGMAX))])
    (printf "ARGS: ~a\n" args)
    (printf "running process ~a\n" exec)
    (let loop ([iters 10])
      (printf "iters ~a\n" iters)
      (define cmd (format "~a ~a ~a" exec args iters))

      (define batchseconds : Real
        (let retryloop ((retries : Integer RETRIES))
          (define ls (process cmd))
          (define block_func (get-proc ls))
          ;;      (block_func 'wait)
          (define op (get-input-port ls))
          (define err (get-error-port ls))
          
          (define batchsec
            (read-batchtime op err cmd (lambda () (block_func 'exit-code))))
          (block_func 'wait)        
          (close-input-port op)
          (close-output-port (get-output-port ls))
          (close-input-port (get-error-port ls))          
          (cond
            [batchsec batchsec]
            [(zero? retries) (error "Out of retries: process failed.\n")]
            [else (printf " ==> RETRYING failed process, retries left ~a\n" (sub1 retries))
                  (sleep 1)
                  (retryloop (sub1 retries))])))

      (if (>= batchseconds target-time)
          (let ([meantime (exact->inexact (/ batchseconds iters))])
	    (printf "\nITERS: ~a\n" iters)
            (printf "BATCHTIME: ~a\n" (exact->inexact batchseconds))
            (printf "MEANTIME: ~a\n" meantime)
            (printf "Done with pass, ~a.\n" pass-name)

	    ;; write to csv
	    (fprintf csv-port "~a, ~a, ~a, ~a, ~a\n"
	  	     pass-name variant args iters meantime)
	    (flush-output csv-port)
	    )
	  (begin (printf "~a " batchseconds) (flush-output)
	         (loop (* 2 iters)))))
  ))

(define (run-parallel-driver
         [csv-port : Output-Port]
         ;; Takes threads, size, iters and produces a command-line
         [make-exec : (-> Integer Integer Integer String)]
         [pass-name : String]
         [variant : String] [threads : Integer])
  (fprintf csv-port "NAME, VARIANT, ARGS, ITERS, MEANTIME, THREADS\n") ;; start csv file
  
  ;; loop through args 1 to 25
  (for ([args (in-range 1 (+ 1 ARGMAX))])
    (let loop ([iters 1])
      (printf "iters ~a\n" iters)
      ; (define cmd (format "~a ~a ~a" (make-exec threads) args iters))
      (define cmd (make-exec threads args iters))

      (define batchseconds : Real
        (let retryloop ((retries : Integer RETRIES))
          ; (printf "Launching subprocess ~a\n" cmd)
          (define ls (process cmd))
          (define block_func (get-proc ls))
          ;;      (block_func 'wait)
          (define op (get-input-port ls))
          (define err (get-error-port ls))
          
          (define batchsec
            (read-batchtime op err cmd (lambda () (block_func 'exit-code))))
          (block_func 'wait)
          (close-input-port op)
          (close-output-port (get-output-port ls))
          (close-input-port (get-error-port ls))
          (cond
            [batchsec batchsec]
            [(zero? retries) (error "Out of retries: process failed.\n")]
            [else (printf " ==> RETRYING failed process, retries left ~a\n" (sub1 retries))
                  (sleep 1)
                  (retryloop (sub1 retries))])
          ))
      
      (if (>= batchseconds target-time)
          (let ([meantime (exact->inexact (/ batchseconds iters))])
            (printf "ARGS: ~a\n" args)
	    (printf "ITERS: ~a\n" iters)
            (printf "BATCHTIME: ~a\n" (exact->inexact batchseconds))
            (printf "MEANTIME: ~a\n" meantime)
            (printf "Done with pass, ~a.\n" pass-name)

	    ;; write to csv
	    (fprintf csv-port "~a, ~a, ~a, ~a, ~a, ~a\n"
	  	     pass-name variant args iters meantime threads)
	    (flush-output csv-port)
	    )
	  (begin (printf "~a " batchseconds) (flush-output)
	         (loop (* 2 iters)))))
  ))

(define (cilk-parallel-driver [csv-port : Output-Port] [exec : String] [pass-name : String]
                              [variant : String] [threads : Integer])
  (run-parallel-driver csv-port
                       (lambda (thrd args iters)
                         (format "CILK_NWORKERS=~a ~a ~a ~a" thrd exec args iters))
                       pass-name variant threads))

(define (ghc-parallel-driver [csv-port : Output-Port] [exec : String] [pass-name : String]
                             [variant : String] [threads : Integer])
  (run-parallel-driver csv-port
                       (lambda (thrd args iters)
                         (format "~a ~a ~a +RTS -N~a -RTS " exec args iters thrd))
                       pass-name variant threads))

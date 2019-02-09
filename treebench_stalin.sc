(define (build-tree n)
  (define (go root n)
    (if (zero? n)
        root
        (cons (go root (- n 1))
              (go (+ root (expt 2 (- n 1)))
                  (- n 1)))))
  (go 1 n))

(define (add1-tree tr)
  (if (pair? tr)
      (cons (add1-tree (car tr))
            (add1-tree (cdr tr)))
      (+ 1 tr)))

(define size 20)
(define iters 20)

(display "(Stalin) Benchmarking on tree of size/iterations: ")
(display size) (display " ") (display iters) (newline)

(define (current-second) (with-input-from-file "/proc/uptime" read))

(let ((tr (build-tree size)))
  (display "Tree built. Benchmarking add1") (newline)
  (let* ((start-time (current-second)))
    (let loop ((i 0))
      (add1-tree tr)
      (if (< i iters)
          (loop (+ i 1))
          0))
    (let* ((end-time (current-second))
           (batchseconds (- end-time start-time)))
      (display "BATCHTIME: ") (display batchseconds) (newline)
      (display "AVG: ") (display (/ batchseconds iters)) (newline)
      )))


;; draws a random cube for each processed track
;; and blinks them according to their beat pattern

(require racket/class)
(require fluxus-018/chromosonia-audio)

(clear)

(init-audio)

(define tracks '())

(define track%
  (class object%
      (init-field framerate beat-pattern)
      
      (define obj (with-state
                        (translate (vmul (crndvec) 10))
                        (rotate (vmul (rndvec) 360))
                        (build-cube)))
      
      ;(displayln (vector-length beat-pattern))
      (define/public (update)
            (define pattern-frame (inexact->exact (floor (fmod (* (time) framerate)
                                                               (vector-length beat-pattern)))))
            (with-primitive obj
                (opacity (vector-ref beat-pattern pattern-frame))))

      (super-new)))

;; (get-state)
;; -> symbol, one of '(enter, process, exit, idle)
(define get-state
  (let ([last-state 0])
    (lambda ()
      (let ([inside (inside-event)])
        (begin0
            (cond [(= inside 1)
                   (if (= last-state 0)
                        'enter
                        'process)]
                  [else
                   (if (= last-state 1)
                        'exit
                        'idle)])
            (set! last-state inside))))))

(define (render)
  (define state (get-state))
  (when (findf (lambda (x)
                 (equal? state x))
               '(enter exit))
      (printf "~a ~a ~a~n" (time)
                            "audio processing " state))

  (when (equal? state 'exit)
    (set! tracks (cons (make-object track% (beat-pattern-framerate)
                                           (beat-pattern))
                       tracks)))

  (for-each
    (lambda (track)
      (send track update))
    tracks))

(every-frame (render))


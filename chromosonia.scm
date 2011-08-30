;; chromosonia

(require racket/class)
(require fluxus-018/chromosonia-audio)

(clear)

(init-audio)

; list holding all previously heard tracks
(define tracks '())

(define current-track #f)

(define track%
  (class object%
      (field [framerate (beat-pattern-framerate)] ; based on jack settings - constant
             [beat-pattern #()]
             [artist #f]
             [title #f]
             [genre/count '()])
      
      (define/public (get-beat)
            (cond [(not (zero? (vector-length beat-pattern)))
                       (let ([pattern-frame (inexact->exact
                                              (floor (fmod (* (time) framerate)
                                                           (vector-length beat-pattern))))])
                                   (vector-ref beat-pattern pattern-frame))]
                  [else
                    0]))

      (define/public (set-beat-pattern! bp)
            (set! beat-pattern bp))

      (define/public (set-artist! a)
            (displayln a)
            (set! artist a))

      (define/public (set-title! a)
            (displayln a)
            (set! title a))

      (define/public (set-genre/count! gc)
            (set! genre/count gc))

      (define/public (identified?)
            (or artist title))

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

(define (mainloop)
  (define state (get-state))

  (case state
    [(enter) ; new track starts
            (set! current-track (make-object track%))
            (set! tracks (cons current-track
                               tracks))]
    [(process)
            ; set track id if we have information
            (when (not (send current-track identified?))
                (let ([a (artist)]
                      [s (song)])
                    (when a
                        (send current-track set-artist! a))
                    (when s
                        (send current-track set-title! s))))]
    [(exit) ; track ends
            ; set the beat pattern
            (send current-track set-beat-pattern! (beat-pattern))])
)

(every-frame (mainloop))


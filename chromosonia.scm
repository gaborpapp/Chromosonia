;; chromosonia

(require racket/class)
(require racket/vector)
(require racket/serialize)
(require fluxus-018/chromosonia-audio)
(require "lastfm/lastfm.ss")
(require "facade-control/facade-control.ss")
(require "genre-map.ss")

(clear)

(define host "192.168.2.2")

(define beat-duration 5)

(texture-params 0 '(min nearest mag nearest))

(fc-init host)

(init-audio)
(disjoint-grid-layout (vector fc-pixels-width fc-pixels-height 0)
                      fc-mask)
(genre-map-layout (genre-key-size)
                  (vector fc-pixels-width fc-pixels-height 0)
                  fc-mask)

; list holding all previously heard tracks
(define tracks '())

(define current-track #f)

(define-serializable-class* track% object% (externalizable<%>)
      (field [framerate (beat-pattern-framerate)] ; based on jack settings - constant
             [beat-pattern #()]
             [artist #f]
             [title #f]
             [genre/count '()]
             [clr (hash-ref genre-colour-hash "unclassifiable")]
             [key #f])

      (define/public (externalize)
           (list framerate beat-pattern artist title key clr genre/count))

      (define/public (internalize v)
           (set! framerate (list-ref v 0))
           (set! beat-pattern (list-ref v 1))
           (set! artist (list-ref v 2))
           (set! title (list-ref v 3))
           (set! key (list-ref v 4))
           (set! clr (list-ref v 5))
           (set! genre/count (list-ref v 6)))

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
             (set! artist a)
             (thread (lambda ()
                       (set-genre/count! (get-topgenres/count-normalized artist)))))

      (define/public (set-title! a)
            (displayln a)
            (set! title a))

      (define/public (set-genre/count! gc)
            (set! genre/count gc)
            (set! key (genre-key gc))
            (add-to-genre-map key)
            (calculate-genre-colour))

      (define/public (identified?)
            (or artist title))

      (define/public (get-colour)
            clr)

      (define/public (get-position)
            (if key
                (genre-map-lookup key)
                #(0 0 0)))

      (define (calculate-genre-colour)
            ; genre colour is the genre with maximum value
            #;(set! clr
                    (hash-ref genre-colour-hash
                        (car
                            (foldl (lambda (x m)
                                         (if (> (cdr x) (cdr m))
                                           x
                                           m))
                                   (cons "unclassifiable" 0)
                                   genre/count))))

            ; genre colour is the mix of all genres
            (set! clr
                    (foldl (lambda (x a)
                             (vadd a
                                 (vmul (hash-ref genre-colour-hash (car x)) (cdr x))))
                           #(0 0 0)
                           genre/count)))

      (super-new))

;; (get-state)
;; -> symbol, one of '(enter, process, exit, idle, beat)
(define get-state
  (let ([last-inside 0]
        [last-state 'idle]
        [beat-start (- beat-duration)])
    (lambda ()
      (let* ([inside (inside-event)]
             [state (cond [(= inside 1)
                            (if (= last-inside 0)
                                'enter
                                'process)]
                          [else
                              (cond [(= last-inside 1)
                                        'exit]
                                  [(eq? last-state 'exit)
                                        (set! beat-start (time))
                                        'beat]
                                  [(< (time) (+ beat-start beat-duration))
                                        'beat]
                                  [else
                                        'idle])])])
            (set! last-inside inside)
            (set! last-state state)
            state))))

;; (perceptual-vis track)
;; uploads the perceptual visualization data to the facade controller
;; buffer

(define (perceptual-vis track)
    (define (vector2d->vector1d v)
        (apply vector-append (vector->list v)))
    (let ([pattern (vector2d->vector1d (disjoint-grid-pattern))]
          [clr (send track get-colour)])
        (with-primitive fc-pixels
            (pdata-index-map!
                (λ (i c)
                  (vclamp (vadd #(0.01 0.01 0.01)
                                (vmul clr
                                      (expt (vector-ref pattern i) 10.0)))))
                "c")
            (pixels-upload))))

;; (beat-pattern-vis track)
;; uploads the beat-pattern visualization data to the facade controller
;; buffer

(define (beat-pattern-vis track)
    (let* ([pos (send track get-position)]
           [offset (+ (vx pos) (* (vy pos) fc-pixels-width))]
           [clr (send track get-colour)]
           [beat (send track get-beat)])
      (with-primitive fc-pixels
            (pdata-set! "c" offset (vmul clr beat))
            (pixels-upload))))

(define (social-vis)
    (with-primitive fc-pixels
        (for ([track tracks])
            (let* ([pos (send track get-position)]
                   [offset (+ (vx pos) (* (vy pos) fc-pixels-width))]
                   [clr (send track get-colour)]
                   [beat (send track get-beat)])
                (pdata-set! "c" offset (vmul clr beat))))
        (pixels-upload)))

(define last-state 'nothing)

(define (mainloop)
  (define state (get-state))

  (when (not (eq? last-state state))
        (displayln state))
  (set! last-state state)

  (case state
    [(enter) ; new track starts
            (reset-sonotopy)
            (set! current-track (make-object track%))
            (set! tracks (cons current-track
                               tracks))]

    [(process)
            ; set track id if we have information
            (when current-track
              (when (not (send current-track identified?))
                    (let ([a (artist)]
                          [s (song)])
                        (when a
                            (send current-track set-artist! a))
                        (when s
                            (send current-track set-title! s))))

              ; perceptual visualization
              (perceptual-vis current-track))]

    [(exit) ; track ends
            ; set the beat pattern
            (send current-track set-beat-pattern! (beat-pattern))]

    [(beat)
            (beat-pattern-vis current-track)]

    [(idle)
            (social-vis)
            (set! current-track #f)])

    ; update facade controller
    (fc-update)
)

(define (save-tracks filename)
    (call-with-output-file filename #:exists 'replace
        (lambda (out)
          (write (serialize tracks) out))))

(define (load-tracks filename)
      (set! tracks
        (call-with-input-file filename
            (lambda (in)
              (deserialize (read in))))))

(set-camera-transform (mtranslate #(0 0 -37)))

(with-primitive fc-pixels
    (identity)
    (scale (vector fc-pixels-width (- fc-pixels-height) 1))
    (hint-cull-ccw)
    (hint-wire))

(every-frame (mainloop))


;; chromosonia

(require racket/class)
(require racket/vector)
(require fluxus-018/chromosonia-audio)
(require "lastfm/lastfm.ss")
(require "facade-control/facade-control.ss")

(clear)

(define host "192.168.2.2")

(define beat-duration 5)

(texture-params 0 '(min nearest mag nearest))

(fc-init host)

(init-audio)
(disjoint-grid-layout (vector fc-pixels-width fc-pixels-height 0)
                      fc-mask)
(genre-map-layout (length genres)
                  (vector fc-pixels-width fc-pixels-height 0)
                  fc-mask)

; list holding all previously heard tracks
(define tracks '())

(define current-track #f)

; genre->colour mapping in hsv
(define genre-colour-hsv
  #hash(("alternative & punk" . #(0.045 1 1))
        ("rock" . #(0.09 1 1))
        ("latin" . #(0.136 1 1))
        ("children’s music" . #(0.181 1 1))
        ("classical" . #(0.227 1 1))
        ("country" . #(0.272 1 .5))
        ("reggae" . #(.318 1 .7))
        ("hip hop/rap" . #(.3635 1 1))
        ("folk" . #(.409 1 1))
        ("gospel & religious" . #(0.454 1 1))
        ("electronica/dance" . #(.499 1 1))
        ("holiday" . #(.545 1 1))
        ("jazz" . #(.59 1 1))
        ("blues" . #(.636 1 1))
        ("world" . #(.681 1 .6))
        ("new age" . #(.727 1 1))
        ("pop" . #(.772 1 1))
        ("easy listening" . #(.818 1 1))
        ("r&b" . #(.863 1 1))
        ("books & spoken" . #(.908 1 1))
        ("soundtrack" . #(.954 1 1))
        ("unclassifiable" . #(1 0 1))
        ("metal" . #(1 1 1))))

; genre->colour in rgb
(define genre-colour-hash (make-hash))
(hash-for-each
    genre-colour-hsv
    (lambda (key value)
        (hash-set! genre-colour-hash key (hsv->rgb value))))

(define track%
  (class object%
      (field [framerate (beat-pattern-framerate)] ; based on jack settings - constant
             [beat-pattern #()]
             [artist #f]
             [title #f]
             [genre/count '()]
             [clr (hash-ref genre-colour-hash "unclassifiable")]
             [key #f])

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

        ;; (genre-key genre-list)
        ;; this function returns a vector with N elements, where N is the num of genres.
        ;; genre-list is a list of max genre/count pairs.
        ;; each element in the returned vector represents a genre. value is the normalized weight
        ;; for that genre.

        (define (genre-key gc-list)
            (define (list-index elem lst)
                (- (length lst) (length (member elem lst))))

            (define key (make-vector (length genres) 0))

            (for ([gc gc-list])
                (let ([genre (car gc)]
                        [val (cdr gc)])
                    (vector-set! key (list-index genre genres) val)))
            key)

      (super-new)))

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

(set-camera-transform (mtranslate #(0 0 -37)))

(with-primitive fc-pixels
    (identity)
    (scale (vector fc-pixels-width (- fc-pixels-height) 1))
    (hint-cull-ccw)
    (hint-wire))

(every-frame (mainloop))


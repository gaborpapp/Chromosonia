;; chromosonia

(require racket/math)
(require racket/class)
(require racket/vector)
(require racket/serialize)
(require racket/system)
(require fluxus-018/chromosonia-audio)
(require "lastfm/lastfm.ss")
(require "facade-control/facade-control.ss")
(require "genre-map.ss")

;(require "lastfm/hyped-artists.ss")

(clear)

;(define host "192.168.2.2")
(define host "169.254.59.222")

(define beat-transition-duration 5)
(define social-transition-duration 5)

(texture-params 0 '(min nearest mag nearest))

(fc-init host)

(init-audio)
(disjoint-grid-layout (vector fc-pixels-width fc-pixels-height 0)
                      fc-mask)
(genre-map-layout (genre-key-size)
                  (vector fc-pixels-width fc-pixels-height 0)
                  fc-mask)
(genre-map-neighbourhood-param 0.01)

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
           (set-beat-pattern! (list-ref v 1))
           (set! artist (list-ref v 2))
           (set! title (list-ref v 3))
           (set! key (list-ref v 4))
           (set! clr (list-ref v 5))
           (set-genre/count! (list-ref v 6)))

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
             (printf "artist: ~a~n" a)
             (set! artist a)
             (thread (lambda ()
                       (set-genre/count! (get-topgenres/count-normalized artist)))))

      (define/public (set-title! a)
             (printf "title: ~a~n" a)
             (set! title a))

      (define artist-regexp
            (pregexp "^Artist: (.+?)$"))
      (define title-regexp
            (pregexp "^Title: (.+?)$"))

      (define (identify)
            ; TODO: kill the process if it still exists when the sound stops
            (displayln "starting track id process")
            (define-values [stdout stdin id stderr proc]
                           (vector->values (list->vector (process "./tests/trackid.py"))))
            (proc 'wait)
            (for ([l (in-lines stdout)])
                 (displayln l)
                 (let ([a (regexp-match artist-regexp l)]
                       [t (regexp-match title-regexp l)])
                   (when a
                     (set-artist! (cadr a)))
                   (when t
                     (set-title! (cadr t)))))

            (close-input-port stdout)
            (close-input-port stderr)
            (close-output-port stdin))

      ; starts the track id process in a thread which sets
      ; the artist and title variables, when ready
      (define/public (start-track-id)
            (thread identify))

      (define/public (set-genre/count! gc)
            (set! genre/count gc)
            (set! key (genre-key gc))
            (add-to-genre-map key)
            (update-genre-map-partially 100)
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
                           #(0 0 0 0)
                           genre/count)))

      (super-new))

;; (get-state)
;; -> symbol, one of '(enter, process, exit, idle, beat)
(define get-state
  (let ([last-inside 0]
        [last-state 'idle]
        [beat-start (- beat-transition-duration)])
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
                                  [(< (time) (+ beat-start beat-transition-duration))
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
                    (vmul clr
                          (expt (vector-ref pattern i) 10.0)))
                "c")
            (pixels-upload))))

;; beat pattern

; helper functions to get and set the whole pdata
(define (pdata-list-ref type)
    (for/list ([i (in-range (pdata-size))])
        (pdata-ref type i)))

(define (pdata-list-set type vals)
    (for/list ([i (in-range (pdata-size))])
        (pdata-set! type i (list-ref vals i))))

; to hold the data of the perceptual visualization's last frame
(define fc-perceptual (build-pixels fc-pixels-width fc-pixels-height))
(with-primitive fc-perceptual
        (scale 0))

;; (beat-pattern-vis track)
;;     v : number (0 - 1) for transition from perceptual to beat-pattern
;; uploads the beat-pattern visualization data to the facade controller
;; buffer

(define (beat-pattern-vis track v)
    (let* ([pos (send track get-position)]
           [offset (+ (vx pos) (* (vy pos) fc-pixels-width))]
           [clr (send track get-colour)]
           [beat (send track get-beat)]
           [beat-clr (vmul clr (* v beat))]
           [ppixels (with-primitive fc-perceptual
                            (pdata-list-ref "c"))]
           [max-dist (* (- 1 v) (sqrt (+ (sqr fc-pixels-width)
                                        (sqr fc-pixels-height))))])
      (with-primitive fc-pixels
            ; zooming
            (when (> max-dist 0)
                (for* ([x (in-range fc-pixels-width)]
                       [y (in-range fc-pixels-height)])
                    (let ([dist (vdist (vector (vx pos) (vy pos) 0) (vector x y 0))]
                          [offs (+ x (* y fc-pixels-width))])
                      (pdata-set! "c" offs
                            (vlerp (vmul (list-ref ppixels offs) (- 1 v))
                                  (vmul clr v)
                                  (* v (sin (* (clamp (/ dist max-dist) 1 2)
                                          (* pi .5)))))))))

            ; beat pattern
            (pdata-set! "c" offset beat-clr)
            (pixels-upload))))

;; (social-vis)
;;     v : number (0 - 1) for transition from beat-pattern to social

(define (social-vis v)
      (define (draw-track-beat track [v 1])
        (let* ([pos (send track get-position)]
               [offset (+ (vx pos) (* (vy pos) fc-pixels-width))]
               [clr (send track get-colour)]
               [beat (send track get-beat)])
            (pdata-set! "c" offset (vmul clr (* beat v)))))

    (with-primitive fc-pixels
        (for ([track tracks])
            (draw-track-beat track v))

        ; draw the last track without fading
        (unless (null? tracks)
            (draw-track-beat (car tracks)))

        (pixels-upload)))


(define last-state 'nothing)
(define beat-start 0)
(define social-start 0)

(define (mainloop)
  (define state (get-state))

  (when (not (eq? last-state state))
        (displayln state))
  (set! last-state state)

  (case state
    [(enter) ; new track starts
            (reset-sonotopy)
            (set! current-track (make-object track%))
            ; start track id
            (send current-track start-track-id)
            (set! tracks (cons current-track
                               tracks))]

    [(process)
            ; set track id if we have information
            (when current-track
              ; echoprint
              #|
              (when (not (send current-track identified?))
                    (let ([a (artist)]
                          [s (song)])
                        (when a
                            (send current-track set-artist! a))
                        (when s
                            (send current-track set-title! s))))
              |#

              ; perceptual visualization
              (perceptual-vis current-track))]

    [(exit) ; track ends
            (set! beat-start (time))
            ; set the beat pattern
            (send current-track set-beat-pattern! (beat-pattern))
            ; save the frame for the transition
            (let ([pixels (with-primitive fc-pixels
                                (pdata-list-ref "c"))])
              (with-primitive fc-perceptual
                    (pdata-list-set "c" pixels)))]

    [(beat) ; beat-pattern
            (let ([v (clamp (/ (- (time) beat-start) beat-transition-duration))])
                (beat-pattern-vis current-track v))
            (set! social-start (time))]

    [(idle) ; social visualization
            (let ([v (clamp (/ (- (time) social-start) social-transition-duration))])
                (social-vis v))])

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

(define (generate-beat-pattern framerate secs bpm)
  (define (secs-to-frame secs)
    (inexact->exact (floor (* secs framerate))))

  (let* ([num-frames (secs-to-frame secs)]
     [v (make-vector num-frames 0)]
     [num-beats (/ (/ (* bpm 60) framerate) secs)]
     [offset (random num-frames)]
     [pulse-decay-num-frames (secs-to-frame 1)]
     )
    (for ([i (in-range num-beats)])
     (let ([frame0 (secs-to-frame (/ (* i framerate) num-beats))])
       (for ([j (in-range pulse-decay-num-frames)])
        (let ([frame1 (remainder (+ offset frame0 j) num-frames)]
              [new-value (- 1 (/ j pulse-decay-num-frames))])
          (vector-set! v frame1 (max new-value (vector-ref v frame1)))
           ))))
    v))

(define (generate-hyped-tracks)
  (set! tracks
      (for/list ([gc genre-descriptor-db])
        (let ([current-track (make-object track%)]
              [framerate (inexact->exact (beat-pattern-framerate))]
          [bpm (+ 350 (* 80 (rndf)))]
          )
            (send current-track set-genre/count! gc)
            (set-field! framerate current-track framerate)
            (send current-track set-beat-pattern! (generate-beat-pattern framerate 30 bpm))

            current-track))))

;(generate-hyped-tracks)
;(save-tracks "data/hyped-tracks.dat")

;(load-tracks "data/hyped-tracks.dat")

(set-camera-transform (mtranslate #(0 0 -37)))

(with-primitive fc-pixels
    (pdata-map!  (lambda (c) 0) "c")
    (pixels-upload)
    (identity)
    (scale (vector fc-pixels-width (- fc-pixels-height) 1))
    (hint-cull-ccw)
    (hint-wire))

(every-frame (mainloop))


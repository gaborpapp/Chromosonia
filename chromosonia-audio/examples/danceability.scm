(require racket/vector)
(require fluxus-018/chromosonia-audio)

(clear)

(init-audio)

(set-camera-transform (mtranslate #(0 0 -10)))
(scale #(21 16 1))

(define sw 40)
(define sh 30)
(grid-size (vector sw sh 0))
(define p (build-pixels sw sh))
(define contrast 15.0)

; flattens the 2d grid
(define (vector2d->vector1d v)
    (apply vector-append (vector->list v)))

(define (render)
    (let ([pattern (vector2d->vector1d (grid-pattern))])
        (with-primitive p
            (pdata-index-map!
                (λ (i c)
                  (vclamp (vadd #(0.01 0.01 0.01)
                                (vmul (vector (danceability) 0 (- 1 (danceability)))
                                      (expt (vector-ref pattern i) 10.0)))))
                "c")
            (pixels-upload))))

(every-frame (render))


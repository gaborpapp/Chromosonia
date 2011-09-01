(require racket/vector)
(require fluxus-018/chromosonia-audio)
(require "facade-control.ss")

(clear)

;(define host "169.254.73.149")

(define host "192.168.2.2")

(texture-params 0 '(min nearest mag nearest))

(set-camera-transform (mtranslate #(0 0 -37)))

(fc-init host)

(init-audio)
(disjoint-grid-layout (vector fc-pixels-width fc-pixels-height 0)
                      fc-mask)

;(grid-size (vector fc-pixels-width fc-pixels-height 0))

; flattens the 2d grid
(define (vector2d->vector1d v)
    (apply vector-append (vector->list v)))

(define (mainloop)
    (let ([pattern (vector2d->vector1d (disjoint-grid-pattern))])
        (with-primitive fc-pixels
            (pdata-index-map!
                (λ (i c)
                  (vclamp (vadd #(0.01 0.01 0.01)
                                (vmul #(1 0 0)
                                      (expt (vector-ref pattern i) 10.0)))))
                "c")
            (pixels-upload)))
    (fc-update))

(with-primitive fc-pixels
    (identity)
    (scale (vector fc-pixels-width (- fc-pixels-height) 1))
    (hint-cull-ccw)
    (hint-wire))

(every-frame (mainloop))


(require fluxus-018/chromosonia-audio)
(require "genre-map.ss")
(require "lastfm/hyped-artists.ss")
(require "facade-control/facade-control.ss")
(init-audio)

(clear)

(define host "192.168.2.2")

(texture-params 0 '(min nearest mag nearest))

(fc-init host)

(genre-map-layout (genre-key-size)
                  (vector fc-pixels-width fc-pixels-height 0)
                  fc-mask)

(for ([key keys-db])
    (add-to-genre-map key)
    (update-genre-map-partially 100))


;; simple visualization

(set-camera-transform (mtranslate #(0 0 -37)))

(with-primitive fc-pixels
    (identity)
    (scale (vector fc-pixels-width (- fc-pixels-height) 1))
    (hint-cull-ccw)
    (hint-wire))

(define (render)
    (with-primitive fc-pixels
        (pdata-map! (lambda (c) 0) "c")
	(for ([pos fc-mask])
	     (pdata-set! "c" (+ (* (vy pos) fc-pixels-width) (vx pos)) .3))
        (for ([key keys-db])
            (let ([pos (genre-map-lookup key)])
                (pdata-set! "c" (+ (* (vy pos) fc-pixels-width) (vx pos)) 1)))
        (pixels-upload)))

(every-frame (render))


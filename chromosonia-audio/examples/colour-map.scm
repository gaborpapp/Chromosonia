(require fluxus-018/chromosonia-audio)
(require "facade-control/facade-control.ss")
(init-audio)

(clear)

(define host "192.168.2.2")

(texture-params 0 '(min nearest mag nearest))

(fc-init host)

(colour-map-layout (vector fc-pixels-width fc-pixels-height 0)
		   fc-mask)

(set-camera-transform (mtranslate #(0 0 -37)))

(with-primitive fc-pixels
    (identity)
    (scale (vector fc-pixels-width (- fc-pixels-height) 1))
    (hint-cull-ccw)
    (hint-wire))

(define (update-colour-map)
  (for ([i (in-range 100)])
       (train-colour-map
	(vector (rndf) (rndf) (rndf))
	;;(hsv->rgb (vector (rndf) 1 1))
   )))

(define (render)
  (with-primitive fc-pixels
		  (pdata-map! (lambda (c) 0) "c")
		  (for ([pos fc-mask])
		       (pdata-set! "c" (+ (* (vy pos) fc-pixels-width) (vx pos))
				   (colour-from-map (vx pos) (vy pos))))
		  (update-colour-map)
		  (pixels-upload))
  )

(every-frame (render))


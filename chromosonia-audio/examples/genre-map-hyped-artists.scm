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

(define keys (for/list ([descriptor genre-descriptor-db])
               (genre-key descriptor)))

(for ([key keys])
    (add-to-genre-map key)
    (update-genre-map-partially 100)
    )


;; simple visualization

(define (genre-colour descriptor)
  ;; genre colour is the genre with maximum value
  ;; (hash-ref genre-colour-hash
  ;; 	    (car
  ;; 	     (foldl (lambda (x m)
  ;; 		      (if (> (cdr x) (cdr m))
  ;; 			  x
  ;; 			  m))
  ;; 		    (cons "unclassifiable" 0)
  ;; 		    descriptor))))

  ;; genre colour is the mix of all genres
  (foldl (lambda (x a)
       (vadd a
         (vmul (hash-ref genre-colour-hash (car x)) (cdr x))))
     #(0 0 0)
     descriptor))

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
    (for ([i (in-range (length keys))])
         (let ([pos (genre-map-lookup (list-ref keys i))])
           (pdata-set! "c" (+ (* (vy pos) fc-pixels-width) (vx pos)) (genre-colour (list-ref genre-descriptor-db i)))))
        (pixels-upload)))

(every-frame (render))


(require fluxus-018/chromosonia-audio)
(require "genre-map.ss")
(require "lastfm/hyped-artists.ss")
(require "facade-control/facade-control.ss")
(require racket/vector)
(require racket/list)
(init-audio)

(clear)

(define host "192.168.2.2")

(texture-params 0 '(min nearest mag nearest))

(fc-init host)

(genre-map-layout (genre-key-size)
                  (vector fc-pixels-width fc-pixels-height 0)
                  fc-mask)

(genre-map-neighbourhood-param 0.01)

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


(define genre-colours-hsv (list
			   ;;"alternative & punk;;"
			   #(0.045 1 1)
			   ;;"books & spoken;;"
			   #(.908 1 1)
			   ;;"blues;;"
			   #(.636 1 1)
			   ;;"children’s music;;"
			   #(0.181 1 1)
			   ;;"classical;;"
			   #(0.227 1 1)
			   ;;"country;;"
			   #(0.272 1 .5)
			   ;;"easy listening;;"
			   #(.818 1 1)
			   ;;"electronica/dance;;"
			   #(.499 1 1)
			   ;;"folk;;"
			   #(.409 1 1)
			   ;;"gospel & religious;;"
			   #(0.454 1 1)
			   ;;"hip hop/rap;;"
			   #(.3635 1 1)
			   ;;"holiday;;"
			   #(.545 1 1)
			   ;;"jazz;;"
			   #(.59 1 1)
			   ;;"latin;;"
			   #(0.136 1 1)
			   ;;"metal;;"
			   #(1 1 1)
			   ;;"new age;;"
			   #(.727 1 1)
			   ;;"pop;;"
			   #(.772 1 1)
			   ;;"reggae;;"
			   #(.318 1 .7)
			   ;;"r&b;;"
			   #(.863 1 1)
			   ;;"rock;;"
			   #(0.09 1 1)
			   ;;"soundtrack;;"
			   #(.954 1 1)
			   ;;"unclassifiable;;"
			   #(1 0 1)
			   ;;"world;;"))
			   #(.681 1 .6)
			   ))

(define (genre-colour-from-id i)
  (vector-append (hsv->rgb (list-ref genre-colours-hsv i)) #(1)))

(define (genre-colour-from-key key)

  (foldl (lambda (i a)
  	   (vadd a
  		 (vmul (genre-colour-from-id i) (vector-ref key i))))
  		 ;;(vmul #(1 1 1) (vector-ref key i))))
  	   #(0 0 0)
  	   (for/list ([j (in-range (genre-key-size))]) j)
  	   )

  ;; (define (p x) (vector-ref key x))
  ;; (define dominant-genre-id
  ;;   (argmax p (for/list ([j (in-range (genre-key-size))]) j)))
  ;; (genre-colour-from-id dominant-genre-id)
  )

(set-camera-transform (mtranslate #(0 0 -37)))

(with-primitive fc-pixels
    (identity)
    (scale (vector fc-pixels-width (- fc-pixels-height) 1))
    (hint-cull-ccw)
    (hint-wire))

(define (render)
  (define (draw-genres)
    (for ([pos fc-mask])
	 (pdata-set! "c" (+ (* (vy pos) fc-pixels-width) (vx pos)) .3))
    (for ([i (in-range (length keys))])
         (let ([pos (genre-map-lookup (list-ref keys i))])
           (pdata-set! "c" (+ (* (vy pos) fc-pixels-width) (vx pos))
		       (genre-colour (list-ref genre-descriptor-db i))))))

  (define (draw-terrain)
    (for ([pos fc-mask])
	 (pdata-set! "c" (+ (* (vy pos) fc-pixels-width) (vx pos))
		     (genre-colour-from-key (genre-map-node (vx pos) (vy pos))))))

  (with-primitive fc-pixels
		  (pdata-map! (lambda (c) 0) "c")
		  ;;(draw-terrain)
		  (draw-genres)
		  (pixels-upload))
  )

(every-frame (render))


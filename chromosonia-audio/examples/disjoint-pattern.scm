(require racket/vector)
(require fluxus-018/chromosonia-audio)

(clear)

(init-audio)

(set-camera-transform (mtranslate #(0 0 -10)))
(scale #(21 16 1))

(define sw 15)
(define sh 10)
(disjoint-grid-layout (vector sw sh 0) #(
					 #(0 0)
					 #(0 1)
					 #(0 2)
					 #(0 3)
					 #(0 4)
					 #(0 5)
					 #(0 6)
					 #(0 7)

					 #(1 0)
					 #(1 1)
					 #(1 2)
					 #(1 3)
					 #(1 4)
					 #(1 5)
					 #(1 6)

					 #(2 0)
					 #(2 1)
					 #(2 2)
					 #(2 3)
					 #(2 4)
					 #(2 5)



					 #(6 0)
					 #(6 1)
					 #(6 2)
					 #(6 3)
					 #(6 4)
					 #(6 5)
					 #(6 6)
					 #(6 7)

					 #(7 0)
					 #(7 1)
					 #(7 2)
					 #(7 3)
					 #(7 4)
					 #(7 5)
					 #(7 6)

					 #(8 0)
					 #(8 1)
					 #(8 2)
					 #(8 3)
					 #(8 4)
					 #(8 5)



					 #(12 0)
					 #(12 1)
					 #(12 2)
					 #(12 3)
					 #(12 4)
					 #(12 5)
					 #(12 6)
					 #(12 7)

					 #(13 0)
					 #(13 1)
					 #(13 2)
					 #(13 3)
					 #(13 4)
					 #(13 5)
					 #(13 6)

					 #(14 0)
					 #(14 1)
					 #(14 2)
					 #(14 3)
					 #(14 4)
					 #(14 5)

					 ))
			  
(define p (build-pixels sw sh))
(define contrast 5.0)

; flattens the 2d grid
(define (vector2d->vector1d v)
    (apply vector-append (vector->list v)))

(define (render)
    (let ([pattern (vector2d->vector1d (disjoint-grid-pattern))])
        (with-primitive p
            (pdata-index-map!
                (lambda (i c)
                  (expt (vector-ref pattern i) contrast))
                "c")
            (pixels-upload))))

(every-frame (render))


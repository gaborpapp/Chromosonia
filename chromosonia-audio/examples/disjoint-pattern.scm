(require racket/vector)
(require fluxus-018/chromosonia-audio)

(clear)

(init-audio)

(set-camera-transform (mtranslate #(0 0 -10)))
(scale #(21 16 1))

(define sw 15)
(define sh 8)
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
					 #(1 7)

					 #(2 0)
					 #(2 1)
					 #(2 2)
					 #(2 3)
					 #(2 4)
					 #(2 5)
					 #(2 6)
					 #(2 7)

					 #(3 0)
					 #(3 1)
					 #(3 2)
					 #(3 3)
					 #(3 4)
					 #(3 5)
					 #(3 6)
					 #(3 7)

					 #(4 0)
					 #(4 1)
					 #(4 2)
					 #(4 3)
					 #(4 4)
					 #(4 5)
					 #(4 6)
					 #(4 7)


					 #(6 0)
					 #(6 1)
					 #(6 2)

					 #(7 0)
					 #(7 1)
					 #(7 2)

					 #(8 0)
					 #(8 1)
					 #(8 2)

					 #(9 0)
					 #(9 1)
					 #(9 2)

					 #(10 0)
					 #(10 1)
					 #(10 2)
					 #(10 3)

					 #(11 0)
					 #(11 1)
					 #(11 2)
					 #(11 3)

					 #(12 0)
					 #(12 1)
					 #(12 2)
					 #(12 3)
					 #(12 4)

					 #(13 0)
					 #(13 1)
					 #(13 2)
					 #(13 3)
					 #(13 4)

					 #(14 0)
					 #(14 1)
					 #(14 2)
					 #(14 3)
					 #(14 4)
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


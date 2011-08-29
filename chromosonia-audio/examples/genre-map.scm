(require racket/vector)
(require racket/list)
(require fluxus-018/chromosonia-audio)
(require "../lastfm/lastfm.ss")
(init-audio)

(define sw 4)
(define sh 8)
(genre-map-layout (length genres) (vector sw sh 0) #(
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

					 #(3 0)
					 #(3 1)
					 #(3 2)
					 #(3 3)
					 #(3 4)
					 #(3 5)
					 #(3 6)
					 #(3 7)
					 ))

;; (genre-key genre-list)
;; this function return a vector with N elements, where N is the num of genres.
;; genre-list is a list of max 5 genres sorted by most popular first.
;; each element in the returned vector represents a genre. value is the weight for that genre according to the popularity list.
;; the weight is 5 for the most popular genre in the popularity list, 1 for the least popular,
;; and 0 for all other genres.
;; example:
;; (genre-key (list "hip hop/rap" "latin")))
;; returns #(0 0 0 0 0 0 0 0 0 0 0 5 0 0 4 0 0 0 0 0 0 0 0 0)

(define (genre-key genre-list)
  (define key (make-vector (length genres) 0))

  (define (range high low)
    (cond
     [(> low high) null]
     [else (cons high (range (- high 1) low))]))

  (define (list-index elem lst)
    (define (list-index-n elem lst n)
      (cond
       [(empty? lst) #f]
       [(equal? (first lst) elem) n]
       [else (list-index-n elem (rest lst) (+ n 1))]))
    (list-index-n elem lst 0))

  (define (genre-id genre)
    (list-index genre genres))

  (for ([genre genre-list] [weight (range 5 (- 5 (length genre-list)))])
       (vector-set! key (genre-id genre) weight))

  key)

(define song1key (genre-key (list "jazz" "easy listening" "alternative & punk" "folk")))
(define song2key (genre-key (list "jazz" "alternative & punk" "easy listening" "folk")))
(define song3key (genre-key (list "hip hop/rap" "latin")))
(define song4key (genre-key (list "hip hop/rap" "reggae" "latin")))
(define song5key (genre-key (list "folk" "country" "gospel & religious")))

(define keys-db (vector song1key song2key song3key song4key song5key))

(for ([key keys-db])
     (add-to-genre-map key))



;; simple visualization
;; one should see the map converging towards keys 1&2 in one corner, 3&4 in the opposite corner, and 5 somewhere between

(set-camera-transform (mtranslate #(0 0 -20)))
(scale #(21 16 1))

(texture-params 0 '(min nearest mag nearest))

(define p (build-pixels sw sh))
(define contrast 1.0) ;; this should be eliminated

(with-primitive p
    (identity)
    (scale (vector sw (- sh) 1))
    (hint-cull-ccw)
    (hint-wire))

; flattens the 2d grid
(define (vector2d->vector1d v)
    (apply vector-append (vector->list v)))

(define (genre-map-pattern)
  (define (add-item x y pattern)
    (vector-set! (vector-ref pattern y) x 1))

  (define (make-row n) (make-vector sw 0.3))

  (let ([pattern (build-vector sh make-row)])
    (for ([key keys-db])
	 (let ([pos (genre-map-lookup key)])
	   (add-item (vector-ref pos 0)
		     (vector-ref pos 1) pattern)))
    pattern))

(define (render)
  (update-genre-map)
  (let ([pattern (vector2d->vector1d (genre-map-pattern))])
    (with-primitive p
		    (pdata-index-map!
		     (lambda (i c)
		       (expt (vector-ref pattern i) contrast))
		     "c")
		    (pixels-upload))))

(every-frame (render))

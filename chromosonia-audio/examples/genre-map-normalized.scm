(require racket/vector)
(require racket/list)
(require fluxus-018/chromosonia-audio)
(require "../../lastfm/lastfm.ss")
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
;; this function returns a vector with N elements, where N is the num of genres.
;; genre-list is a list of max genre/count pairs.
;; each element in the returned vector represents a genre. value is the normalized weight
;; for that genre.

(define (genre-key gc-list)
    (define (list-index elem lst)
        (- (length lst) (length (member elem lst))))
    
    (define key (make-vector (length genres) 0))
    
    (for ([gc gc-list])
        (let ([genre (car gc)]
                [val (cdr gc)])
            (vector-set! key (list-index genre genres) val)))
    
    key)


(define song1key (genre-key 
        '(("easy listening" . 7/443)
            ("metal" . 15/443)
            ("new age" . 14/443)
            ("gospel & religious" . 7/443)
            ("classical" . 400/443))))
(define song2key (genre-key
        '(("easy listening" . 67/329)
            ("electronica/dance" . 103/329)
            ("pop" . 135/329)
            ("folk" . 17/329)
            ("alternative & punk" . 1/47))))
(define song3key (genre-key
        '(("alternative & punk" . 2/31)
            ("electronica/dance" . 33/124)
            ("new age" . 33/124)
            ("classical" . 25/62))))

(define keys-db (list song1key song2key song3key))

(for ([key keys-db])
    (add-to-genre-map key))


;; simple visualization

(set-camera-transform (mtranslate #(0 0 -20)))
(scale #(21 16 1))

(texture-params 0 '(min nearest mag nearest))

(define p (build-pixels sw sh))

(with-primitive p
    (identity)
    (scale (vector sw (- sh) 1))
    (hint-cull-ccw)
    (hint-wire))

(define (render)
    (update-genre-map)
    (with-primitive p
        (pdata-map! (lambda (c) .3) "c")
        (for ([key keys-db])
            (let ([pos (genre-map-lookup key)])
                (pdata-set! "c" (+ (* (vy pos) sw) (vx pos)) 1)))
        (pixels-upload)))

(every-frame (render))


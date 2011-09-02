#lang racket
(require racket/vector)
(require racket/list)
(require "lastfm/lastfm.ss")

(provide genre-key
	 genre-key-size)


;; (genre-key genre-list)
;; this function returns a vector with N elements, where N is the num of genres.
;; genre-list is a list of max genre/count pairs.
;; each element in the returned vector represents a genre. value is the normalized weight
;; for that genre.

(define (genre-key gc-list)
    (define (list-index elem lst)
        (- (length lst) (length (member elem lst))))

    (define key (make-vector (genre-key-size) 0))

    (for ([gc gc-list])
        (let ([genre (car gc)]
                [val (cdr gc)])
            (vector-set! key (list-index genre genres) val)))

    key)


(define (genre-key-size) (length genres))

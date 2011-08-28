(require racket/vector)
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

;; function genre-key
;; this is supposed to return a vector with N elements, where N is the num of genres
;; each element represents a genre and the value the weight for that genre according to the popularity list
;; the weight is 5 for the most popular genre in a popularity list of 5 genres
;; and 1 for the least popular
;; and 0 for all other genres
;; example:
;; (genre-key (list "hip hop/rap" "latin")))
;; returns (vector 0 0 0 5 0 4 0 0 1 0 0 3 0 0 0 2) (or something similar)

;; (define (genre-key genre-list)
;; TODO

;; (define song1key (genre-key (list "jazz" "easy listening" "alternative & punk" "folk")))
;; (define song2key (genre-key (list "jazz" "alternative & punk" "easy listening" "folk")))
;; (define song3key (genre-key (list "hip hop/rap" "latin")))
;; (define song4key (genre-key (list "hip hop/rap" "reggae" "latin")))

(define song1key (vector 0 4 0 0 5 0 0 0 1 0 2 0 0 0 0 0 0 3 0 0 0 0 0))
(define song2key (vector 0 0 0 0 5 0 4 0 1 0 2 0 0 0 0 0 0 3 0 0 0 0 0))
(define song3key (vector 0 0 0 0 0 0 0 0 4 0 0 5 0 0 0 0 0 0 0 0 0 0 3))
(define song4key (vector 0 0 3 0 0 0 0 0 4 0 0 5 0 0 0 0 0 0 0 0 0 0 0))
(define song5key (vector 0 0 0 0 5 0 0 0 0 0 0 4 0 0 0 0 0 0 0 0 0 0 0))

(add-to-genre-map song1key)
(add-to-genre-map song2key)
(add-to-genre-map song3key)
(add-to-genre-map song4key)
(add-to-genre-map song5key)

;(genre-map-lookup song1key)



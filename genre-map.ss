;; Part of Chromosonia
;; Copyright (C) 2011 Alex Berman, Gabor Papp
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see http://www.gnu.org/licenses/.

#lang racket
(require racket/vector)
(require racket/list)
(require "lastfm/lastfm.ss")
(require (only-in fluxus-018/fluxus-engine
				  hsv->rgb))

(provide genre-key
	 genre-key-size
	 genre-colour-hash)

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

    ;;(vector-set! key (length genres) (* (random) 10))

    key)


(define (genre-key-size) (length genres))
;;(define (genre-key-size) (+ (length genres) 1))

; genre->colour mapping in hsv
(define genre-colour-hsv
  #hash(("alternative & punk" . #(0.045 1 1))
        ("rock" . #(0.09 1 1))
        ("latin" . #(0.136 1 1))
        ("children’s music" . #(0.181 1 1))
        ("classical" . #(0.227 1 1))
        ("country" . #(0.272 1 .5))
        ("reggae" . #(.318 1 .7))
        ("hip hop/rap" . #(.3635 1 1))
        ("folk" . #(.409 1 1))
        ("gospel & religious" . #(0.454 1 1))
        ("electronica/dance" . #(.499 1 1))
        ("holiday" . #(.545 1 1))
        ("jazz" . #(.59 1 1))
        ("blues" . #(.636 1 1))
        ("world" . #(.681 1 .6))
        ("new age" . #(.727 1 1))
        ("pop" . #(.772 1 1))
        ("easy listening" . #(.818 1 1))
        ("r&b" . #(.863 1 1))
        ("books & spoken" . #(.908 1 1))
        ("soundtrack" . #(.954 1 1))
        ("unclassifiable" . #(1 0 1))
        ("metal" . #(1 1 1))))

; genre->colour in rgba
(define genre-colour-hash (make-hash))
(hash-for-each
    genre-colour-hsv
    (lambda (key value)
        (hash-set! genre-colour-hash key (vector-append (hsv->rgb value) #(1)))))


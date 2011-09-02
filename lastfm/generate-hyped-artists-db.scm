(require "genre-map.ss")
(require "lastfm/lastfm.ss")

(define (write-hyped-artists-db file)
	(define out (open-output-file file))
	(let ([keys-db
	       (filter (lambda (key) key)
		       (for/list ([artist (get-hyped-artists)])
				 (let ([artistgenres (get-topgenres/count-normalized artist)])
				   (cond [artistgenres
					  (let ([key (genre-key artistgenres)])
					    (cond [key key])
					    )
					  ])))
		       )
	       ])
	  (fprintf out "(define keys-db ~a)~n" keys-db))
	(close-output-port out))

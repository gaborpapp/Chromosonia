(require "genre-map.ss")
(require "lastfm/lastfm.ss")

(define (write-hyped-artists-db file)
	(define out (open-output-file file))
	(let ([genre-descriptor-db
	       (for/list ([artist (get-hyped-artists)])
			 (get-topgenres/count-normalized artist))
	       ])
	  (fprintf out "(define genre-descriptor-db ~v)~n" genre-descriptor-db))
	(close-output-port out))

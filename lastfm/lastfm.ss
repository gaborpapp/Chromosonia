#lang racket
(require net/url)

(provide
  get-toptags)

(define api-key "e41bd2650f381f8b6975ee5bc2109516")

(define (get-toptags artist)
	(define lastfm-port (get-pure-port
				(string->url (string-append "http://ws.audioscrobbler.com/2.0/?method=artist.gettoptags&artist="
											artist "&api_key=" api-key))))

	(define tag-name-regexp ; <name>tag</name>
		#rx"<name>(.+)</name>")
	(filter
		(lambda (x) (not (void? x)))
		(for/list ([line (in-lines lastfm-port)])
			  (define tag (regexp-match tag-name-regexp line))
			  (when tag
				(cadr tag)))))


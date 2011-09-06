#lang racket
(require net/url)

(provide spelling-suggestion)

(define (spelling-suggestion text)
	(define yahoo-port (get-pure-port
						 (string->url (string-append "http://search.yahoo.com/search?p=" text))))

	(define suggestion-regexp
		  #px"(Also try|Did you mean|We have included).+?<a href=.+?>(.+?)</a>")

	(let ([sg-ret #f])
	(for ([line (in-lines yahoo-port)]
		  #:when (not sg-ret))
		  (define suggestion (regexp-match suggestion-regexp line))
		  (when suggestion
				(set! sg-ret (regexp-replace* #rx"<.+?>" (list-ref suggestion 2) ""))))
	sg-ret))

#|
(for-each
  (lambda (x)
	(displayln (spelling-suggestion x)))
  '("oi va vai"
	"michaeljackson"
	"Lovasi Andrés"
	"Ceséria Evora"
	"jéhannjéhannsson"
	"SuUan Stevens"))
|#


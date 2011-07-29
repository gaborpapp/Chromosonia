#lang racket

(require racket/udp)

(provide fc-init
		 fc-send)

(define fc-hostname "192.168.1.138")
(define fc-port 8080)
(define fc-socket (udp-open-socket))

(define (fc-init hostname [port 8080])
	(set! fc-hostname hostname)
	(set! fc-port port)
	(udp-close fc-socket)
	(set! fc-socket (udp-open-socket)))

(define fc-send
  (let ([last-send-time 0])
  	(lambda (colours)
		(define (make-packet address colour)
		  (bytes (remainder address 256) (quotient address 256)
				 (inexact->exact (floor (* (vector-ref colour 0) 255)))
				 (inexact->exact (floor (* (vector-ref colour 1) 255)))
				 (inexact->exact (floor (* (vector-ref colour 2) 255)))))
		(define bstr
		  (apply
			bytes-append
			(for/list ([i (in-range 0 1085)])
				(make-packet i (list-ref colours i)))))
		(define current-time (current-inexact-milliseconds))
		(when (>= (- current-time last-send-time) 40) ; max 25 fps
			(udp-send-to fc-socket fc-hostname fc-port bstr)
			(set! last-send-time current-time)))))


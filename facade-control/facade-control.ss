#lang racket

(require racket/udp)
(require fluxus-018/fluxus)

(require "facade-data.ss")

(provide fc-init
		 fc-send
		 fc-pixels
		 fc-pixels-width
		 fc-pixels-height
		 fc-update)

(define fc-hostname "127.0.0.1")
(define fc-port 8080)
(define fc-socket (udp-open-socket))

(define fc-pixels 0)
(define fc-pixels-width 74)
(define fc-pixels-height 28)
(define fc-pixels-size (* fc-pixels-width fc-pixels-height))

; mapping from window address to pixel coordinates
(define fc-mapping (make-vector 1085 0))

; colours to be sent
(define fc-colours (make-vector 1085 #(0 0 0)))

; (fc-init hostname [port 8080])
; 	hostname : string
; 	port : integer
;
; Initializes the facade controller.
(define (fc-init hostname [port 8080])
	(set! fc-hostname hostname)
	(set! fc-port port)
	(udp-close fc-socket)
	(set! fc-socket (udp-open-socket))

	(destroy fc-pixels)
	(set! fc-pixels (build-pixels fc-pixels-width fc-pixels-height #t))
	(with-primitive fc-pixels
		(scale 0)))

; (fc-send colours)
; 	colours : vector of 1085 rgb colours, with colour components range 0-1
;
; Sends colours to the facade.
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
				(make-packet i (vector-ref colours i)))))
		(define current-time (current-inexact-milliseconds))
		(when (>= (- current-time last-send-time) 40) ; max 25 fps
			(udp-send-to fc-socket fc-hostname fc-port bstr)
			(set! last-send-time current-time)))))

; (map-side s p double)
; 	s : struct-side
; 	p : 2d coordinate vector of position
; 	double : bool, #t for north side's double window
(define (map-side s p)
  (define (set-window-mapping! v addr)
	(let ([pixels-addr (+ (* fc-pixels-width (vy v)) (vx v))])
	(when (or (< (vx v) 0)
			  (>= (vx v) fc-pixels-width)
			  (< (vy v) 0)
			  (>= (vy v) fc-pixels-height))
	(error 'out-of-bounds "(~s, ~s) - fc-pixels (~s, ~s)~n"
			(vx v) (vy v)
			fc-pixels-width fc-pixels-height))
	(vector-set! fc-mapping addr pixels-addr)))

  (for ([line (side-addrs s)]
		[y (in-range (add1 (- (side-end-row s)
							  (side-start-row s))))])
	   (for ([w line]
			 [x (in-range (side-nr-columns s))])
			; TODO: calculate average pixel value for double windows
			(when (> w 0)
			  (if (side-double? s)
				(set-window-mapping! (vadd p
										(vector (* 2 x) y)) w)
				(set-window-mapping! (vadd p
										(vector x y)) w))))))

; calculate mapping
(map-side main-building-north #(0 0))
(map-side main-building-west #(10 0))
(map-side main-building-south #(20 1))
(map-side main-building-east #(30 1))
(map-side main-building-south-street-level #(19 23))
(map-side futurelab-south #(33 17))
(map-side futurelab-east #(56 17))
(map-side futurelab-north #(61 17))

; (fc-update [download?])
; 	download? : bool?, whether downloading data from fc-pixels is required
; 				defaults to #t
;
; Sends the data of fc-pixels to the facade.
(define (fc-update [download? #t])
 	(with-primitive fc-pixels
		(when download?
			(pixels-download))
		(for ([i (in-range 1085)])
			 (vector-set! fc-colours i
						  (pdata-ref "c" (vector-ref fc-mapping i)))))
	(fc-send fc-colours))


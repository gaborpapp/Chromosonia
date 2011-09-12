;; AEC Facade Controller
;; Copyright (C) 2011 Gabor Papp
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

(require racket/udp)
(require fluxus-018/fluxus)

(require "facade-data.ss")

(provide fc-init
         fc-send
         fc-pixels
         fc-pixels-width
         fc-pixels-height
         fc-update
         fc-mask)

(define fc-hostname "127.0.0.1")
(define fc-port 8080)
(define fc-socket (udp-open-socket))
(define fc-mode 'passive) ; 'passive or 'active

(define fc-pixels 0)
(define fc-pixels-width 74)
(define fc-pixels-height 28)
(define fc-pixels-size (* fc-pixels-width fc-pixels-height))

; mapping from window address to pixel coordinates
(define fc-mapping (make-vector 1085 0))

; colours to be sent
(define fc-colours (make-vector 1085 #(0 0 0)))

; network is down message is displayed only once per seesion
(define network-down-msg #f)

; (fc-init hostname [port 8080] [mode 'passive])
;     hostname : string
;     port : integer
;     mode : symbol - 'passive or 'active, using pdata or rendering into
;                     the pixel primitive
; Initializes the facade controller.
(define (fc-init hostname [port 8080] [mode 'passive])
  (set! fc-hostname hostname)
  (set! fc-port port)
  (set! fc-mode mode)
  (udp-close fc-socket)
  (set! fc-socket (udp-open-socket))

  (set! network-down-msg #f)
  (destroy fc-pixels)
  (set! fc-pixels (build-pixels fc-pixels-width fc-pixels-height
                                (if (eq? mode 'active) #t #f)))
  (with-primitive fc-pixels
                  (scale 0)))

; (fc-send colours)
;     colours : vector of 1085 rgb colours, with colour components range 0-1
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
        (with-handlers
          ([exn:fail:network?    (lambda (exn)
                                   (when (not network-down-msg)
                                     (printf "~a~n" (exn-message exn))
                                     (set! network-down-msg #t)))])
          (udp-send-to fc-socket fc-hostname fc-port bstr))
        (set! last-send-time current-time)))))

; (map-side s p)
;     s : struct-side
;     p : 2d coordinate vector of position
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
(define (setup-facade-mapping)
  (map-side main-building-south #(20 1))
  (map-side main-building-east #(30 1))
  (map-side main-building-south-street-level #(19 23))
  (map-side futurelab-south #(33 17))
  (map-side futurelab-east #(56 17))

  ; linear mapping of back sides
  #|
  (map-side main-building-north #(0 0))
  (map-side main-building-west #(10 0))
  (map-side futurelab-north #(61 17))
  |#

  ; overlapped mapping of back sides
  (map-side main-building-north #(20 0))
  (map-side main-building-west #(30 0))
  (map-side futurelab-north #(48 17)))

; mask holding all the occupied pixels which can be
; used to build a disjoint grid layout with chromosonia
(define fc-mask '())

; (add-to-mask s p)
;     s : struct-side
;     p : 2d coordinate vector of position
(define (add-to-mask s p)
  (define (mask-append! v)
    (when (or (< (vx v) 0)
              (>= (vx v) fc-pixels-width)
              (< (vy v) 0)
              (>= (vy v) fc-pixels-height))
      (error 'out-of-bounds "(~s, ~s) - fc-pixels (~s, ~s)~n"
             (vx v) (vy v)
             fc-pixels-width fc-pixels-height))
    (set! fc-mask (cons v fc-mask)))

  (for ([line (side-addrs s)]
        [y (in-range (add1 (- (side-end-row s)
                              (side-start-row s))))])
       (for ([w line]
             [x (in-range (side-nr-columns s))])
            (when (> w 0)
              (if (side-double? s)
                (mask-append! (vadd p (vector (* 2 x) y)))
                (mask-append! (vadd p (vector x y))))))))

(define (setup-disjoint-mask)
  (set! fc-mask '())
  (add-to-mask main-building-south #(20 1))
  (add-to-mask main-building-east #(30 1))
  (add-to-mask main-building-south-street-level #(19 23))
  (add-to-mask futurelab-south #(33 17))
  (add-to-mask futurelab-east #(56 17))

  ; overlapped back sides
  (add-to-mask main-building-north #(20 0))
  (add-to-mask main-building-west #(30 0))
  (add-to-mask futurelab-north #(48 17))

  (set! fc-mask (list->vector fc-mask)))

; (fc-update)
;
; Sends the data of fc-pixels to the facade.
(define (fc-update [download? #t])
  (with-primitive fc-pixels
                  (when (eq? fc-mode 'active)
                    (pixels-download))
                  (for ([i (in-range 1085)])
                       (vector-set! fc-colours i
									; add a small value to look nice in the simulator
									(vclamp (vadd #(0.01 0.01 0.01)
												  (pdata-ref "c" (vector-ref fc-mapping i)))))))
  (fc-send fc-colours))


; precalculations
(setup-facade-mapping)
(setup-disjoint-mask)


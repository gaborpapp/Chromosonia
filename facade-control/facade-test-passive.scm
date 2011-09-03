(require "facade-control.ss")

; ip address of the simulator
(define host "192.168.2.2")

(texture-params 0 '(min nearest mag nearest)) ; no bilinear - show the pixels

; initialize controller
(fc-init host)

; the controller sends data in 25 fps, so it's no use
; for the rendering to be faster
(desiredfps 25)

(define (pdata-set-c! x y c)
  (pdata-set! "c" (+ (* y fc-pixels-width) x) c))

(define (pdata-line-vert x c)
  (for ([y (in-range 0 fc-pixels-height)])
       (pdata-set-c! x y c)))

(define (mainloop)
    (define x (remainder (inexact->exact (floor (* (time) 10))) fc-pixels-width))

    ; update the pdata of the fc-pixels primitive
    (with-primitive fc-pixels
        (for ([i (in-range fc-pixels-width)])
            (pdata-line-vert i (hsv->rgb (vector (/ (remainder (+ i x) fc-pixels-width)
                                                    fc-pixels-width) 1 1))))
        (pixels-upload))

    ; send the contents of fc-pixels to the facade
    (fc-update))

; if you would like to see the buffer in which the rendering goes

; this shows the originally hidden fc-pixels primitive and flips it vertically, so
; the top-left corner on the screen matches the top-left corner of the mapping
(with-primitive fc-pixels
    (identity)
    (scale (vector fc-pixels-width (- fc-pixels-height) 1))
    (hint-cull-ccw)
    (hint-wire))

(every-frame
        (mainloop))


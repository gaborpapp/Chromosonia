(require "facade-control.ss")

; ip address of the simulator
(define host "169.254.73.149")

(texture-params 0 '(min nearest mag nearest)) ; no bilinear - show the pixels

; initialize controller
(fc-init host)

; the controller sends data in 25 fps, so it's no use
; for the rendering to be faster
(desiredfps 25)

(define (mainloop)
    ; the rendering goes into the fc-pixels pixel primitive
    (with-pixels-renderer fc-pixels
        (clear-colour #(1 0 0))
        (identity)
        ; draw two rotating cubes
        (for ([pos '(#(-6.5 -4.5 0) #(-1 -3 0))])
            (with-state
                (translate pos)
                (rotate (vector (* 11 (time)) (* 82 (time)) 8))
                (scale 3)
                (draw-cube))))

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


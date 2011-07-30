(require "facade-control.ss")

; ip address of the simulator
(define host "192.168.1.1")

(fc-init host)

(every-frame
        ; send a list of 1085 colours
        (fc-send (list->vector (for/list ([i (in-range 0 1085)])
                     (rndvec)))))

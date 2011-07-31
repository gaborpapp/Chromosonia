(require "facade-data.ss")

(hint-unlit)

(ortho)
(set-ortho-zoom -40)
(set-camera-transform (mtranslate #(-36 12 -30)))

(hint-wire)

(define (draw-side s p)
    (with-state
        (translate (vector (vx p) (- (vy p)) 0))
        (for ([line (side-addrs s)]
              [y (in-range (add1 (- (side-end-row s)
                                    (side-start-row s))))])
            (for ([w line]
                  [x (in-range (side-nr-columns s))])
                (with-state
                    (if (side-double? s)
                        (translate (vector (* 2 x) (- y) 0))
                        (translate (vector x (- y) 0)))
                    (when (> w 0)
                        (when (side-double? s)
                                (scale #(2 1 1)))
                        (translate #(.5 -.5 0))
                        (draw-cube)))))))

(every-frame
    (begin
        (hint-ignore-depth)
        (colour #(1 1 0))
        (draw-side main-building-north #(0 0))
        (colour #(1 0 0))
        (draw-side main-building-west #(10 0))
        (colour #(0 1 0))
        (draw-side main-building-south #(20 1))
        (colour #(0 0 1))
        (draw-side main-building-east #(30 1))
        (colour #(0 1 0 .5))
        (draw-side main-building-south-street-level #(19 23))
        (colour #(0 1 0 .5))
        (draw-side futurelab-south #(33 17))
        (colour #(0 0 1 .5))
        (draw-side futurelab-east #(56 17))
        (colour #(1 1 0 .5))
        (draw-side futurelab-north #(61 17))
        ))


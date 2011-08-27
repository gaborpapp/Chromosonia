(require fluxus-018/chromosonia-audio)

(clear)

(init-audio)

(define (render)
  (define c (+ 0.5 (* (inside-event) 0.5)))
  (colour (vector c c c))
  (scale (vector 1 1 1))
  (draw-cube))

(every-frame (render))


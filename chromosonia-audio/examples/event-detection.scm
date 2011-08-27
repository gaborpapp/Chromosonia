;; to modify dB threshold:
;; (decibel-threshold 0.4)

;; to modify trailing silence (in millisecs):
;; (trailing-silence 300)

(require fluxus-018/chromosonia-audio)

(clear)

(init-audio)

(set-camera-transform (mtranslate #(0 0 -10)))
(ortho)

(define (render)
  ;; event state: red for silence, green for non-silence
  (with-state
   (translate (vector -0.5 0 0))
   (colour (vector (- 1 (inside-event)) (inside-event) 0))
   (scale (vector 1 1 1))
   (draw-cube))

  ;; dB threshold
  (with-state
   (colour (vector 1 1 1))
   (translate (vector 0.5 (- 0.5 (decibel-threshold)) 0))
   (scale (vector 1 0.01 0.01))
   (draw-cube))

  ;; current dB level
  (with-state
   (colour (vector 0 0 1))
   (translate (vector 0.5 (- 0.5 (decibel)) 0))
   (scale (vector 1 0.01 0.01))
   (draw-cube))
  )

(every-frame (render))


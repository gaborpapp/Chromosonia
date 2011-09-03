(define (generate-beat-pattern framerate secs bpm)
  (define (secs-to-frame secs)
    (inexact->exact (floor (* secs framerate))))

  (let* ([num-frames (secs-to-frame secs)]
     [v (make-vector num-frames 0)]
     [num-beats (/ (/ (* bpm 60) framerate) secs)]
     [offset (random num-frames)]
     [pulse-decay-num-frames (secs-to-frame .5)]
     )
    (for ([i (in-range num-beats)])
     (let ([frame0 (secs-to-frame (/ (* i framerate) num-beats))])
       (for ([j (in-range pulse-decay-num-frames)])
        (let ([frame1 (remainder (+ offset frame0 j) num-frames)]
              [new-value (- 1 (/ j pulse-decay-num-frames))])
          (vector-set! v frame1 (max new-value (vector-ref v frame1)))
           ))))
    v))

(printf "~a~n" (generate-beat-pattern 43.0 5.0 60.0))
(printf "~a~n" (generate-beat-pattern 43.0 5.0 65.0))

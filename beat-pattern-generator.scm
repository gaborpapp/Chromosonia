(define (generate-beat-pattern framerate secs bpm)
  (define (secs-to-frame secs)
    (inexact->exact (floor (* secs framerate))))

  (let* ([num-frames (secs-to-frame secs)]
	 [v (make-vector num-frames 0)]
	 [num-beats (/ (* bpm 60) framerate)]
	 [offset (random num-frames)]
	 )
    (for ([i (in-range num-beats)])
	 (let ([frame (secs-to-frame (/ (* i framerate) num-beats))])
	   (cond [(< frame num-frames)
		  (vector-set! v (remainder (+ offset frame) num-frames) 1)]))
	 )
    v))

(printf "~a~n" (generate-beat-pattern 43.0 5.0 60.0))
(printf "~a~n" (generate-beat-pattern 43.0 5.0 65.0))

;; Part of Chromosonia
;; Copyright (C) 2011 Alex Berman, Gabor Papp
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


; prints identified artist and song to console

(require fluxus-018/chromosonia-audio)

(clear)

(init-audio "moc:output0")

(define identify
    (let ([last-song ""]
          [last-artist ""])
        (λ ()
            (let ([a (artist)]
                  [s (song)])
                (when (and (not (equal? a ""))
                           (not (equal? s "")) 
                           (or (not (equal? a last-artist))
                               (not (equal? s last-song))))
                    (printf "~s ~s~n" a s)
                    (set! last-song s)
                    (set! last-artist a))))))

(define (render)
    (when (odd? (inexact->exact (floor (* 2 (time)))))
        (draw-cube))
    (identify))

(every-frame (render))


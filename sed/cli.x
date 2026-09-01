; # x-sed -- POSIX sed on x-lang
;
; ## sed/cli.x -- options, files, the command line
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
;   x -l sed -- [-nE] [-e script]... [-f scriptfile]... [script] [file]...
;
; The `--` lets sed's own options through x.sh's parsing (-n, -e, -f,
; -E all collide); without it, place options after the script.  The
; engine-flag stripping and the fd-3 stdin reclaim are grep's,
; imported.

(def sed-argv (fn (_ raw) (grep-argv raw)))

; ((quiet ere) SCRIPT-TEXT FILES): -e fragments join with newlines,
; -f files each contribute their text, the first operand is the script
; only when neither spoke.
(def %sed-parse-cli
  (fn (_ operands)
    (def go
      (fn (self ops quiet ere frags saw?)
        (if (null? ops)
          (list quiet ere (reverse frags) ())
          (let ((op (first ops)))
            (if (if (>= (byte-len op) 2) (= (byte-at op 0) 45) #f)
              (let ((b1 (byte-at op 1)))
                (if (= b1 45)                              ; --
                  (let ((tail (rest ops)))
                    (if saw?
                      (list quiet ere (reverse frags) tail)
                      (if (null? tail)
                        (Err raise (lit sed) "sed: no script" ())
                        (list quiet ere (list (first tail)) (rest tail)))))
                  (if (= b1 101)                           ; e
                    (let ((r (%grep-optarg op ops)))
                      (self (rest r) quiet ere
                        (pair (first r) frags) #t))
                    (if (= b1 102)                         ; f
                      (let ((r (%grep-optarg op ops)))
                        (if (file-exists? (first r))
                          (self (rest r) quiet ere
                            (pair (file-read-all (first r)) frags) #t)
                          (Err raise (lit sed)
                            (string-append "sed: can't open script file "
                              (first r))
                            ())))
                      ; bundled -nE
                      (let ((bundle
                              (fn (self2 i q e)
                                (if (>= i (byte-len op)) (pair q e)
                                  (let ((b (byte-at op i)))
                                    (if (= b 110)          ; n
                                      (self2 (+ i 1) #t e)
                                      (if (= b 69)         ; E
                                        (self2 (+ i 1) q #t)
                                        (Err raise (lit sed)
                                          (string-append
                                            "sed: unknown option: " op)
                                          ()))))))))
                        (let ((qe (bundle 1 quiet ere)))
                          (self (rest ops) (first qe) (rest qe)
                            frags saw?)))))))
              (if (if saw? #t (not (null? frags)))
                (list quiet ere (reverse frags) ops)
                (self (rest ops) quiet ere (pair op frags) #t)))))))
    (go operands #f #f () #f)))

(def %sed-join-frags
  (fn (self fs)
    (if (null? fs) ""
      (if (null? (rest fs)) (first fs)
        (string-append (first fs)
          (string-append "\n" (self (rest fs))))))))

; the pure core the specs drive: ARGV and stdin's text in, output on
; stdout, the exit status back.  File operands read here; the input is
; ONE stream (line numbers continue, $ is the overall last line).
(def sed-run
  (fn (_ argv input)
    (def plan (%sed-parse-cli argv))
    (def quiet (first plan))
    (def ere (first (rest plan)))
    (def frags (first (rest (rest plan))))
    (def files (first (rest (rest (rest plan)))))
    (if (null? frags)
      (do (file-write 2 "usage: sed [-nE] [-e script]... [-f scriptfile]... [script] [file]...\n")
          1)
      (let ((cmds (sed-parse (%sed-join-frags frags) ere)))
        (def gather
          (fn (self fs acc err?)
            (if (null? fs) (pair (reverse acc) err?)
              (let ((f (first fs)))
                (if (string=? f "-")
                  (self (rest fs) (pair input acc) err?)
                  (if (file-exists? f)
                    (self (rest fs) (pair (file-read-all f) acc) err?)
                    (do (file-write 2
                          (string-append "sed: can't open "
                            (string-append f "\n")))
                        (self (rest fs) acc #t))))))))
        (def g (if (null? files)
                 (pair (list input) #f)
                 (gather files () #f)))
        (def text (string-concat (first g)))
        (def status (%sed-cycle cmds (%grep-lines text) quiet))
        (if (rest g) 1 status)))))

; Run the command line and DO NOT RETURN.
(def sed-main
  (fn (_ raw-args)
    (def argv (sed-argv raw-args))
    (def plan (%sed-parse-cli argv))
    (def files (first (rest (rest (rest plan)))))
    (def wants-stdin?
      (if (null? files) #t
        (let ((go (fn (self fs)
                    (if (null? fs) #f
                      (if (string=? (first fs) "-") #t (self (rest fs)))))))
          (go files))))
    (sys-exit (sed-run argv (if wants-stdin? (%grep-stdin!) "")))))

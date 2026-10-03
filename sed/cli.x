; # x-sed -- POSIX sed on x-lang
;
; ## sed/cli.x -- options, files, the command line
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
;   x -l sed -- [-nrE] [-e script]... [-f scriptfile]... [script] [file]...
;   x -l sed -- --help
;
; The `--` lets sed's own options through x.sh's parsing (-n, -e, -f,
; -E all collide); without it, place options after the script.  The
; engine-flag stripping and the fd-3 stdin reclaim are grep's,
; imported.

(def sed-argv (fn (_ raw) (grep-argv raw)))

; The options, declared once: what the parse accepts, what --help prints and
; what a refusal prints.  busybox's sed help text, less the rows for the -i
; it does not take; -r is busybox's spelling of -E.
(def %sed-options
  (Opts declare "sed"
    "[-i[SFX]] [-nrE] [-f FILE]... [-e CMD]... [FILE]...\nor: sed [-i[SFX]] [-nrE] CMD [FILE]..."
    ()
    (list
      (Opts arg "-e" "CMD" "Add CMD to sed commands to be executed")
      (Opts arg "-f" "FILE" "Add FILE contents to sed commands to be executed")
      (Opts flag "-n" "Suppress automatic printing of pattern space")
      (Opts flag "-r" "-E" "Use extended regex syntax")
      (Opts text "")
      (Opts text "If no -e or -f, the first non-option argument is the sed command string.")
      (Opts text "Remaining arguments are input files (stdin if none)."))))

; (QUIET ERE FRAGMENTS FILES), or nil when the line does not run: an option
; sed does not take, or no script.  Options stop at the first operand, as
; musl's getopt stops.  -e and -f fragments keep the order they were given
; in (the parse's values list holds them in that order); a -f file
; contributes its text.  Without either, the first operand is the script.
(def %sed-parse-cli
  (fn (_ argv)
    (def o (Opts parse-leading %sed-options argv))
    (def ops (Opts operands o))
    (def frags
      (fn (self vs)
        (match
          ((null? vs) ())
          ((string=? (first (first vs)) "-e")
            (pair (rest (first vs)) (self (rest vs))))
          ((string=? (first (first vs)) "-f")
            (pair (%sed-script-file (rest (first vs))) (self (rest vs))))
          (#t (self (rest vs))))))
    (def fs (frags (Assoc get (lit values) o)))
    (match
      ((not (null? (Opts unknown o))) ())
      ((not (null? fs)) (list (Opts on? o "-n") (Opts on? o "-E") fs ops))
      ((null? ops) ())
      (#t (list (Opts on? o "-n") (Opts on? o "-E") (list (first ops)) (rest ops))))))

(def %sed-script-file
  (fn (_ path)
    (if (file-exists? path) (file-read-all path)
      (Err raise (lit sed) (string-append "sed: can't open script file " path) ()))))

; The line refused, as busybox's sed refuses it: musl getopt's line naming the
; option, or nothing when there was no script, then the usage text, on
; standard error, and 1.
(def %sed-refuse
  (fn (_ tok)
    (do (unless (null? tok)
          (file-write 2 (string-concat (list "sed: " (%sed-refusal tok) "\n"))))
        (file-write 2 (Opts usage %sed-options))
        1)))

; What is wrong with TOK, in musl getopt's words: in a short cluster, read left
; to right, the first letter sed does not take is unrecognized, and -e or -f
; with nothing after it requires an argument; a long option is named without
; its dashes.
(def %sed-refusal
  (fn (_ tok)
    (def end (byte-len tok))
    (def member?
      (fn (self s l) (if (null? l) #f (if (string=? (first l) s) #t (self s (rest l))))))
    (def go
      (fn (self i)
        (let ((opt (string-append "-" (substring tok i (+ i 1)))))
          (match
            ((>= i end) (string-append "unrecognized option: " (substring tok 1 end)))
            ((member? opt (Opts valued %sed-options))
              (string-append "option requires an argument: " (substring tok i (+ i 1))))
            ((member? opt (Opts flags %sed-options)) (self (+ i 1)))
            (#t (string-append "unrecognized option: " (substring tok i (+ i 1))))))))
    (if (if (> end 2) (= (byte-at tok 1) #\-) #f)
      (string-append "unrecognized option: " (substring tok 2 end))
      (go 1))))

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
    (def plan (if (Opts help? %sed-options argv) () (%sed-parse-cli argv)))
    (def quiet (if (null? plan) #f (first plan)))
    (def ere (if (null? plan) #f (first (rest plan))))
    (def frags (if (null? plan) () (first (rest (rest plan)))))
    (def files (if (null? plan) () (first (rest (rest (rest plan))))))
    (match
      ((Opts help? %sed-options argv)
        (do (file-write 1 (Opts usage %sed-options)) 0))
      ((null? plan)
        (%sed-refuse (Opts unknown (Opts parse-leading %sed-options argv))))
      (#t
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
        (if (rest g) 1 status))))))

; Run the command line and DO NOT RETURN.
(def sed-main
  (fn (_ raw-args)
    (def argv (sed-argv raw-args))
    ; read stdin only when something will consume it: a line that runs,
    ; with no file operands or a "-" among them
    (def plan (if (Opts help? %sed-options argv) () (%sed-parse-cli argv)))
    (def files (if (null? plan) () (first (rest (rest (rest plan))))))
    (def wants-stdin?
      (if (null? plan) #f
        (if (null? files) #t
          (let ((go (fn (self fs)
                      (if (null? fs) #f
                        (if (string=? (first fs) "-") #t (self (rest fs)))))))
            (go files)))))
    (sys-exit (sed-run argv (if wants-stdin? (%grep-stdin!) "")))))

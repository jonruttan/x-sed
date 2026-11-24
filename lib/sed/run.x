; # x-sed -- POSIX sed on x-lang
;
; ## lib/sed/run.x -- the entry
;
; @description A POSIX sed: addresses, s///, the cycle, on grep's regex
;   layer.  The third tool of the self-hosting arc.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Usage:
;   x -l sed -- [-nE] [-e script]... [-f scriptfile]... [script] [file]...
;
; The module sed/run.  Importing it sets the session's globals; main runs
; sed-main on the operands, which exits.  With no operands it is the x REPL
; with the core loaded, (sed-run ARGV INPUT) at a prompt.
(module sed/run)
(import sed/base sed-version sed-repl-print sed-main)

(set! %lang-name "SED")
(set! %lang-version sed-version)
(set! %repl-prompt "sed> ")
(set! %repl-print sed-repl-print)

(def main
  (fn (_)
    (let ((ops (rest (Sys args (lit program)))))
      (unless (null? ops) (sed-main ops)))))

(provide sed/run main)

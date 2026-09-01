; # x-sed -- POSIX sed on x-lang
;
; ## run.x -- THE entry
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
; THIS FILE KNOWS NO PATHS.  Operands mean "be sed" -- sed-main runs and
; EXITS; no operands is the x REPL with the core loaded:
; (sed-run ARGV INPUT) at a prompt.
(import sed/base)

(set! %lang-name "SED")
(set! %lang-version sed-version)
(set! %repl-prompt "sed> ")
(set! %repl-print %sed-repl-print)

(unless (null? (sed-argv args))
  (sed-main args))

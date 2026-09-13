; # x-sed -- POSIX sed on x-lang
;
; ## sed/base.x -- the tool, assembled
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The regex layer is grep's: (import grep/base) arms the escape-swap translator
; (%grep-xlate), the byte doors, the line splitter and the File wrappers -- the
; flat global namespace makes a required lang's internals usable the moment its
; base is imported. Nothing under sed/ includes a platform module (x-lang#515).

(import grep/base)

(provide sed/base sed-version sed-parse sed-run
  sed-argv sed-main %sed-repl-print)

(def sed-version "0.1.0")

(def %sed-repl-print
  (fn (_ result)
    (unless (null? result) (write result))
    (newline)))

(include-once "./parse.x")
(include-once "./exec.x")
(include-once "./cli.x")

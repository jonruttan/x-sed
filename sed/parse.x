; # x-sed -- POSIX sed on x-lang
;
; ## sed/parse.x -- script text to compiled commands
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A COMMAND is (STATE-BOX ADDR1 ADDR2 NEG BODY):
;   STATE-BOX  (active?) -- a two-address range's memory, one per command
;   ADDR       () any | (line N) | (last) | (re . RX)
;   NEG        #t after !
;   BODY       (p) | (d) | (q) | (block CMDS)
;            | (subst RX REPL-ITEMS GLOBAL PFLAG OCC)
;   REPL-ITEMS strings | (amp) | (grp N), pre-parsed
;
; Regexes compile HERE, through grep's translator: BRE by default, ERE
; under -E.  An empty // (last-regex reuse) and multiline commands are
; refused loudly, recorded as pending.

(def %sed-perr
  (fn (_ msg)
    (Err raise (lit sed) (string-append "sed: " msg) ())))

; scan to the unescaped DELIM byte from i; \DELIM unescapes to DELIM,
; every other escape passes through untouched.  Answers (text . next-i)
; with next-i past the delimiter.
(def %sed-scan-delim
  (fn (_ s end delim i0)
    (def go
      (fn (self i acc)
        (if (>= i end)
          (%sed-perr "unterminated s/// or address regex")
          (let ((b (byte-at s i)))
            (if (= b delim)
              (pair (string-concat (reverse acc)) (+ i 1))
              (if (if (= b 92) (< (+ i 1) end) #f)
                (let ((e (byte-at s (+ i 1))))
                  (if (= e delim)
                    (self (+ i 2) (pair (%grep-b->s delim) acc))
                    (self (+ i 2)
                      (pair (string-append "\\" (%grep-b->s e)) acc))))
                (self (+ i 1) (pair (%grep-b->s b) acc))))))))
    (go i0 ())))

; the replacement text to items: & is the match, \\N a group, \\& a
; literal &, \\\\ a backslash, \\n a newline; anything else literal
(def %sed-repl-go
  (fn (self s end i acc)
    (if (>= i end) (reverse acc)
      (let ((b (byte-at s i)))
        (if (= b 38)                                       ; &
          (self s end (+ i 1) (pair (list (lit amp)) acc))
          (if (if (= b 92) (< (+ i 1) end) #f)             ; backslash
            (let ((e (byte-at s (+ i 1))))
              (if (if (>= e 49) (<= e 57) #f)              ; \1-\9
                (self s end (+ i 2)
                  (pair (list (lit grp) (- e 48)) acc))
                (if (= e 110)                              ; \n
                  (self s end (+ i 2) (pair "\n" acc))
                  (self s end (+ i 2)
                    (pair (%grep-b->s e) acc)))))
            (self s end (+ i 1) (pair (%grep-b->s b) acc))))))))
(def %sed-parse-repl
  (fn (_ s) (%sed-repl-go s (byte-len s) 0 ())))

; an address at i, or nil when none starts here
(def %sed-parse-addr
  (fn (_ s end i ere?)
    (if (>= i end) (pair () i)
      (let ((b (byte-at s i)))
        (if (if (>= b 48) (<= b 57) #f)                    ; digits
          (let ((num (fn (self j acc)
                       (if (>= j end) (pair acc j)
                         (let ((d (byte-at s j)))
                           (if (if (>= d 48) (<= d 57) #f)
                             (self (+ j 1) (+ (* acc 10) (- d 48)))
                             (pair acc j)))))))
            (let ((r (num i 0)))
              (pair (list (lit line) (first r)) (rest r))))
          (if (= b 36)                                     ; $
            (pair (list (lit last)) (+ i 1))
            (if (= b 47)                                   ; /re/
              (let ((r (%sed-scan-delim s end 47 (+ i 1))))
                (if (= (byte-len (first r)) 0)
                  (%sed-perr "empty // (last-regex reuse is pending)")
                  (pair
                    (pair (lit re)
                      (regex-compile
                        (%grep-xlate (first r) (not ere?) #f)))
                    (rest r))))
              (pair () i))))))))

(def %sed-ws-skip
  (fn (self s end i)
    (if (>= i end) i
      (let ((b (byte-at s i)))
        (if (if (= b 32) #t (if (= b 9) #t (if (= b 10) #t (= b 59))))
          (self s end (+ i 1))
          i)))))

; one command at i (addresses parsed); answers (CMD . next-i)
(def %sed-parse-cmd ())
(def %sed-parse-cmds ())

(set! %sed-parse-cmd
  (fn (_ s end i0 ere?)
    (def a1r (%sed-parse-addr s end i0 ere?))
    (def a1 (first a1r))
    (def i1 (%sed-ws-skip2 s end (rest a1r)))
    (def a2r
      (if (if (< i1 end) (= (byte-at s i1) 44) #f)         ; ,
        (%sed-parse-addr s end (%sed-ws-skip2 s end (+ i1 1)) ere?)
        (pair () i1)))
    (def a2 (first a2r))
    (def i2 (%sed-ws-skip2 s end (rest a2r)))
    (def neg (if (< i2 end) (= (byte-at s i2) 33) #f))     ; !
    (def i3 (%sed-ws-skip2 s end (if neg (+ i2 1) i2)))
    (if (>= i3 end) (%sed-perr "address without a command")
      (let ((c (byte-at s i3)))
        (def body-r
          (match
            ((= c 115)                                     ; s
              (if (>= (+ i3 1) end) (%sed-perr "s needs a delimiter")
                (let ((delim (byte-at s (+ i3 1))))
                  (def re-r (%sed-scan-delim s end delim (+ i3 2)))
                  (def repl-r (%sed-scan-delim s end delim (rest re-r)))
                  (if (= (byte-len (first re-r)) 0)
                    (%sed-perr "empty s regex (last-regex reuse is pending)")
                    (let ((flags (fn (self j g p occ)
                                   (if (>= j end) (list j g p occ)
                                     (let ((f (byte-at s j)))
                                       (if (= f 103)          ; g
                                         (self (+ j 1) #t p occ)
                                         (if (= f 112)        ; p
                                           (self (+ j 1) g #t occ)
                                           (if (if (>= f 49) (<= f 57) #f)
                                             (self (+ j 1) g p (- f 48))
                                             (list j g p occ)))))))))
                      (let ((fr (flags (rest repl-r) #f #f 1)))
                        (pair
                          (list (lit subst)
                            (regex-compile
                              (%grep-xlate (first re-r) (not ere?) #f))
                            (%sed-parse-repl (first repl-r))
                            (first (rest fr))
                            (first (rest (rest fr)))
                            (first (rest (rest (rest fr)))))
                          (first fr))))))))
            ((= c 112) (pair (list (lit p)) (+ i3 1)))     ; p
            ((= c 100) (pair (list (lit d)) (+ i3 1)))     ; d
            ((= c 113) (pair (list (lit q)) (+ i3 1)))     ; q
            ((= c 123)                                     ; {
              (let ((r (%sed-parse-cmds s end (+ i3 1) ere? #t)))
                (pair (list (lit block) (first r)) (rest r))))
            (#t
              (%sed-perr
                (string-append "unknown command: "
                  (%grep-b->s c))))))
        (pair
          (list (list #f) a1 a2 neg (first body-r))
          (rest body-r))))))

; commands until end (or the closing } when IN-BLOCK)
(set! %sed-parse-cmds
  (fn (_ s end i0 ere? in-block?)
    (def go
      (fn (self i acc)
        (let ((j (%sed-ws-skip s end i)))
          (if (>= j end)
            (if in-block?
              (%sed-perr "unterminated { block")
              (pair (reverse acc) j))
            (if (if in-block? (= (byte-at s j) 125) #f)    ; }
              (pair (reverse acc) (+ j 1))
              (let ((r (%sed-parse-cmd s end j ere?)))
                (self (rest r) (pair (first r) acc))))))))
    (go i0 ())))

; blanks only (not ; or newline -- those SEPARATE commands, the skip
; above owns them); between an address and its command
(def %sed-ws-skip2
  (fn (self s end i)
    (if (>= i end) i
      (let ((b (byte-at s i)))
        (if (if (= b 32) #t (= b 9))
          (self s end (+ i 1))
          i)))))

(def sed-parse
  (fn (_ script ere?)
    (first (%sed-parse-cmds script (byte-len script) 0 ere? #f))))

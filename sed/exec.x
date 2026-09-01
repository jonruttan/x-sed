; # x-sed -- POSIX sed on x-lang
;
; ## sed/exec.x -- the cycle
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Read a line, run the script over the pattern space, auto-print unless
; -n, next line.  d ends the cycle unprinted; q prints (unless -n) and
; stops; s/// mutates the space and s///p prints it.  Line numbers run
; across all input (POSIX: the files are one stream; $ is the last line
; of the last file).  Per-line work is if-chains and module helpers --
; the x-awk performance laws.

; does ADDR select at (n, last?, line)?
(def %sed-addr?
  (fn (_ addr n last? line)
    (if (null? addr) #t
      (let ((k (first addr)))
        (if (eq? k (lit line)) (= n (first (rest addr)))
          (if (eq? k (lit last)) last?
            (not (null? (regex-search line (rest addr))))))))))

; the two-address range rule, with the command's own state box: a1
; opens (selected), a2 closes -- and an addr2 line number at or before
; the opening line closes immediately (a one-line range)
(def %sed-selected?
  (fn (_ cmd n last? line)
    (def box (first cmd))
    (def a1 (first (rest cmd)))
    (def a2 (first (rest (rest cmd))))
    (def neg (first (rest (rest (rest cmd)))))
    (def sel
      (if (null? a2)
        (%sed-addr? a1 n last? line)
        (if (first box)
          ; active: close on a2, still selected this line
          (do (if (%sed-addr? a2 n last? line)
                (set-first! box #f)
                ())
              #t)
          (if (%sed-addr? a1 n last? line)
            (do (if (if (eq? (first a2) (lit line))
                      (<= (first (rest a2)) n)
                      #f)
                  ()                                       ; one-line range
                  (set-first! box #t))
                #t)
            #f))))
    (if neg (not sel) sel)))

; expand REPL-ITEMS against the match's groups alist
(def %sed-expand
  (fn (_ items groups)
    (def get
      (fn (self gs k)
        (if (null? gs) ""
          (if (= (first (first gs)) k)
            (rest (first gs))
            (self (rest gs) k)))))
    (def go
      (fn (self is acc)
        (if (null? is) (string-concat (reverse acc))
          (let ((it (first is)))
            (if (str? it)
              (self (rest is) (pair it acc))
              (if (eq? (first it) (lit amp))
                (self (rest is) (pair (get groups 0) acc))
                (self (rest is)
                  (pair (get groups (first (rest it))) acc))))))))
    (go items ())))

; s/// over the pattern space: (new-space . count).  The engine's
; search runs on the TAIL substring so the groups come from the same
; leftmost match; empty matches replace and step, the gsub rule.
(def %sed-subst
  (fn (_ s rx items g pflag occ)
    (def len (byte-len s))
    (def go
      (fn (self pos acc nmatch)
        (if (> pos len)
          (pair (string-concat (reverse acc)) nmatch)
          (let ((sub (substring s pos len)))
            (def m (regex-search sub rx))
            (if (null? m)
              (pair (string-concat
                      (reverse (pair (substring s pos len) acc)))
                (- nmatch 1))
              (let ((st (+ pos (first m))))
                (def en (+ pos (first (rest m))))
                (def hit? (if g (>= nmatch occ) (= nmatch occ)))
                (def piece
                  (if hit?
                    (%sed-expand items (regex-match-groups sub rx))
                    (substring s st en)))
                (def acc2 (pair piece (pair (substring s pos st) acc)))
                (if (if (not g) hit? #f)
                  (pair (string-concat
                          (reverse (pair (substring s en len) acc2)))
                    nmatch)
                  (if (= st en)
                    (if (>= en len)
                      (pair (string-concat (reverse acc2)) nmatch)
                      (self (+ en 1)
                        (pair (substring s en (+ en 1)) acc2)
                        (+ nmatch 1)))
                    (self en acc2 (+ nmatch 1))))))))))
    (def r (go 0 () 1))
    ; count = matches CONSIDERED; the caller only needs "did the
    ; occ'th happen": recompute cheaply from the walk's answer
    r))

(def regex-match-groups (fn (_ s rx) (Regex match-groups s rx)))

; run BODY against the space box; answers () | (lit del) | (lit quit)
(def %sed-run-body ())
(def %sed-run-cmds
  (fn (self cmds space-box n last? quiet)
    (if (null? cmds) ()
      (let ((cmd (first cmds)))
        (def c
          (if (%sed-selected? cmd n last? (first space-box))
            (%sed-run-body (first (rest (rest (rest (rest cmd)))))
              space-box n last? quiet)
            ()))
        (if (null? c)
          (self (rest cmds) space-box n last? quiet)
          c)))))

(set! %sed-run-body
  (fn (_ body space-box n last? quiet)
    (let ((k (first body)))
      (if (eq? k (lit p))
        (do (display (string-append (first space-box) "\n")) ())
        (if (eq? k (lit d)) (list (lit del))
          (if (eq? k (lit q)) (list (lit quit))
            (if (eq? k (lit block))
              (%sed-run-cmds (first (rest body)) space-box n last? quiet)
              ; subst
              (let ((rx (first (rest body))))
                (def items (first (rest (rest body))))
                (def g (first (rest (rest (rest body)))))
                (def pflag (first (rest (rest (rest (rest body))))))
                (def occ (first (rest (rest (rest (rest (rest body)))))))
                (def before (first space-box))
                (def r (%sed-subst before rx items g pflag occ))
                (def changed (not (string=? (first r) before)))
                ; a change of text is the honest "substituted" signal
                ; here; identical replacement text still counts in real
                ; sed, a recorded divergence for s///p only
                (do (set-first! space-box (first r))
                    (if (if pflag changed #f)
                      (display (string-append (first r) "\n"))
                      ())
                    ())))))))))

; the whole run: SCRIPT-CMDS over LINES; answers the exit status
(def %sed-cycle
  (fn (_ cmds lines quiet)
    (def total (length lines))
    (def go
      (fn (self ls n)
        (if (null? ls) 0
          (let ((space-box (list (first ls))))
            (def c (%sed-run-cmds cmds space-box n (null? (rest ls)) quiet))
            (if (eq? (if (null? c) () (first c)) (lit del))
              (self (rest ls) (+ n 1))
              (do (if quiet ()
                    (display (string-append (first space-box) "\n")))
                  (if (eq? (if (null? c) () (first c)) (lit quit))
                    0
                    (self (rest ls) (+ n 1)))))))))
    (go lines 1)))

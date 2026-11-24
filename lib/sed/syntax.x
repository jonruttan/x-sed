; # x-sed -- POSIX sed on x-lang
;
; ## sed/syntax.x -- the sed highlighting grammar
;
; @description The grammar x/tool/syntax colours sed scripts with: comments,
;   addresses, commands, labels, regular expressions, replacements and file
;   names.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; bundle.xon's (grammar sed ...) form names this module, and x/tool/syntax
; imports it the first time a file needs the grammar, in whatever process is
; colouring: vi's, a REPL's, an HTML renderer's.  So it imports x-lang
; libraries only, never the interpreter.  It colours POSIX sed and GNU's
; common commands, more than sed/parse runs.
;
; An s or y command takes any byte as its delimiter, which no Lexer rule can
; carry, so a line is one token and its class function reads it as
; sed/parse does: addresses, then a command and its arguments, then a ; and
; the next command.  A line number is a number, $ a constant, a /regex/ or
; \cregexc a string.  A command is a keyword, a label a name.  An s
; command's regex and replacement are strings and its delimiters operators,
; a bracket expression in the regex holding the delimiter as sed/parse reads
; it; its flags are constants.  The text of a, i and c and the file of r and
; w are strings.  A regex left open runs to the line's end.
;
; Every line is read alone, so a line continuing an a, i or c text, or an s
; replacement, after a backslash at the end of the line above is read as
; commands.  Every line starts outside anything else, so every line is a
; sync point.

(module sed/syntax)
(import x/type/list)
(import x/type/str)
(import x/reader/lexer)
(import x/tool/syntax)
(import x/core/doors str-byte-ref char->int str-byte-len int+ int-)

; The commands: POSIX's, and GNU's e, F, L, Q, R, T, v, W and z
(def sed-syntax-commands
  (list "{" "}" "=" ":" "a" "b" "c" "d" "D" "e" "F" "g" "G" "h" "H" "i" "l"
        "L" "n" "N" "p" "P" "q" "Q" "r" "R" "s" "t" "T" "v" "w" "W" "x" "y" "z"))

(def %sed-sx-line (list (pair 0 9) (pair 11 255) (pair -128 -1)))

(def sed-syntax-rules
  (fn (_)
    (list (Lexer table (lit nl) (list "\n"))
          (Lexer run (lit line) %sed-sx-line %sed-sx-line)
          (Lexer any (lit plain)))))

(def %sed-sx-byte (fn (_ s i) (char->int (str-byte-ref s i))))
(def %sed-sx-blank? (fn (_ b) (if (= b 32) #t (if (= b 9) #t (= b 13)))))
(def %sed-sx-digit? (fn (_ b) (if (>= b 48) (<= b 57) #f)))
(def %sed-sx-at? (fn (_ s i n b) (if (< i n) (= (%sed-sx-byte s i) b) #f)))

(def %sed-sx-piece (fn (_ acc o len cls) (if (<= len 0) acc (pair (list o len cls) acc))))

; Past the blanks from I in S
(def %sed-sx-skip
  (fn (self s i n) (if (if (< i n) (%sed-sx-blank? (%sed-sx-byte s i)) #f) (self s (int+ i 1) n) i)))

; Past the digits from I in S
(def %sed-sx-digits
  (fn (self s i n) (if (if (< i n) (%sed-sx-digit? (%sed-sx-byte s i)) #f) (self s (int+ i 1) n) i)))

; Past a label from I in S: up to a blank, a ;, a } or the end
(def %sed-sx-label
  (fn (self s i n)
    (if (if (< i n) (not (List includes? (%sed-sx-byte s i) (list 32 9 13 59 125))) #f) (self s (int+ i 1) n) i)))

; Past the members that open a bracket expression at J: a ^, then a ]
; taken as a member because nothing precedes it
(def %sed-sx-bracket-head
  (fn (_ s j n)
    (let ((j2 (if (%sed-sx-at? s j n 94) (int+ j 1) j)))
      (if (%sed-sx-at? s j2 n 93) (int+ j2 1) j2))))

; The offset of the delimiter D that ends the part from I in S, or N if none
; does: a backslash takes the byte after it, and in a regex (RE?) a bracket
; expression holds a delimiter
(def %sed-sx-to-delim
  (fn (self s i n d re? in?)
    (if (>= i n) n
      (let ((b (%sed-sx-byte s i)))
        (match
          ((= b 92) (self s (int+ i 2) n d re? in?))
          ((if in? (= b 93) #f) (self s (int+ i 1) n d re? #f))
          ((if (= b d) (not in?) #f) i)
          ((if re? (if (not in?) (= b 91) #f) #f)
            (self s (%sed-sx-bracket-head s (int+ i 1) n) n d re? #t))
          (#t (self s (int+ i 1) n d re? in?)))))))

; Past a delimited regex whose body starts at I, its delimiter D
(def %sed-sx-regex-end
  (fn (_ s i n d) (let ((e (%sed-sx-to-delim s i n d #t #f))) (if (>= e n) n (int+ e 1)))))

; One address at I: (ACC . NEXT)
(def %sed-sx-address
  (fn (_ s i n acc)
    (if (>= i n) (pair acc i)
      (let ((b (%sed-sx-byte s i)))
        (match
          ((%sed-sx-digit? b)
            (let ((e (%sed-sx-digits s i n)))
              (if (%sed-sx-at? s e n 126)
                (let ((e2 (%sed-sx-digits s (int+ e 1) n)))
                  (pair (%sed-sx-piece (%sed-sx-piece (%sed-sx-piece acc i (int- e i) (lit number))
                                         e 1 (lit operator))
                          (int+ e 1) (int- e2 (int+ e 1)) (lit number))
                        e2))
                (pair (%sed-sx-piece acc i (int- e i) (lit number)) e))))
          ((= b 36) (pair (%sed-sx-piece acc i 1 (lit constant)) (int+ i 1)))
          ((= b 47)
            (let ((e (%sed-sx-regex-end s (int+ i 1) n 47)))
              (pair (%sed-sx-piece acc i (int- e i) (lit string)) e)))
          ((if (= b 92) (< (int+ i 1) n) #f)
            (let ((e (%sed-sx-regex-end s (int+ i 2) n (%sed-sx-byte s (int+ i 1)))))
              (pair (%sed-sx-piece acc i (int- e i) (lit string)) e)))
          (#t (pair acc i)))))))

; The addresses at I, a second after a comma, then a !: (ACC . NEXT)
(def %sed-sx-addresses
  (fn (_ s i n acc)
    (let ((r1 (%sed-sx-address s i n acc)))
      (let ((i1 (%sed-sx-skip s (rest r1) n)))
        (let ((r2 (if (%sed-sx-at? s i1 n 44)
                    (let ((k (%sed-sx-skip s (int+ i1 1) n)))
                      (let ((acc2 (%sed-sx-piece (first r1) i1 1 (lit operator))))
                        (if (if (%sed-sx-at? s k n 43) #t (%sed-sx-at? s k n 126))
                          (%sed-sx-address s (int+ k 1) n (%sed-sx-piece acc2 k 1 (lit operator)))
                          (%sed-sx-address s k n acc2))))
                    (pair (first r1) i1))))
          (let ((i2 (%sed-sx-skip s (rest r2) n)))
            (if (%sed-sx-at? s i2 n 33)
              (pair (%sed-sx-piece (first r2) i2 1 (lit operator)) (%sed-sx-skip s (int+ i2 1) n))
              (pair (first r2) i2))))))))

; The rest of the line from I a string: (ACC . N)
(def %sed-sx-rest-string
  (fn (_ s i n acc) (pair (%sed-sx-piece acc i (int- n i) (lit string)) n)))

; An s or y command's parts after its letter at I: the delimiter, then PARTS
; delimited parts, the first a regex when RE?, then for s its flags
(def %sed-sx-parts
  (fn (self s i n acc parts re? d)
    (if (if (= parts 0) #t (>= i n)) (pair acc i)
      (let ((e (%sed-sx-to-delim s i n d re? #f)))
        (let ((acc2 (%sed-sx-piece acc i (int- e i) (lit string))))
          (if (>= e n) (pair acc2 n)
            (self s (int+ e 1) n (%sed-sx-piece acc2 e 1 (lit operator)) (int- parts 1) #f d)))))))

; An s command's flags from I: g p i I m M e and an occurrence, then w and
; its file
(def %sed-sx-flag-bytes (list 103 112 105 73 109 77 101 48 49 50 51 52 53 54 55 56 57))
(def %sed-sx-flags-end
  (fn (self s j n)
    (if (if (< j n) (List includes? (%sed-sx-byte s j) %sed-sx-flag-bytes) #f) (self s (int+ j 1) n) j)))
(def %sed-sx-flags
  (fn (_ s i n acc)
    (let ((e (%sed-sx-flags-end s i n)))
      (let ((acc2 (%sed-sx-piece acc i (int- e i) (lit constant))))
        (if (%sed-sx-at? s e n 119)
          (%sed-sx-rest-string s (%sed-sx-skip s (int+ e 1) n) n (%sed-sx-piece acc2 e 1 (lit constant)))
          (pair acc2 e))))))

; A command whose letter C is at I: (ACC . NEXT)
(def %sed-sx-command
  (fn (_ s i n acc c)
    (%sed-sx-command-at s i n acc c (%sed-sx-piece acc i 1 (lit keyword)) (%sed-sx-skip s (int+ i 1) n))))

; The command C at I, KW the pieces with its letter a keyword, K past the
; blanks after it
(def %sed-sx-command-at
  (fn (_ s i n acc c kw k)
    (match
      ((= c 123) (pair (%sed-sx-piece acc i 1 (lit punct)) (int+ i 1)))
      ((= c 58)
        (let ((e (%sed-sx-label s k n))) (pair (%sed-sx-piece kw k (int- e k) (lit name)) e)))
      ((List includes? c (list 98 116 84))
        (let ((e (%sed-sx-label s k n))) (pair (%sed-sx-piece kw k (int- e k) (lit name)) e)))
      ((= c 115)
        (if (>= (int+ i 1) n) (pair kw n)
          (let ((r (%sed-sx-parts s (int+ i 2) n (%sed-sx-piece kw (int+ i 1) 1 (lit operator)) 2 #t
                     (%sed-sx-byte s (int+ i 1)))))
            (if (>= (rest r) n) r (%sed-sx-flags s (rest r) n (first r))))))
      ((= c 121)
        (if (>= (int+ i 1) n) (pair kw n)
          (%sed-sx-parts s (int+ i 2) n (%sed-sx-piece kw (int+ i 1) 1 (lit operator)) 2 #f
            (%sed-sx-byte s (int+ i 1)))))
      ((List includes? c (list 97 105 99))
        (if (%sed-sx-at? s (int+ i 1) n 92)
          (%sed-sx-rest-string s (%sed-sx-skip s (int+ i 2) n) n (%sed-sx-piece kw (int+ i 1) 1 (lit operator)))
          (%sed-sx-rest-string s k n kw)))
      ((List includes? c (list 114 82 119 87 101))
        (%sed-sx-rest-string s k n kw))
      ((List includes? c (list 113 81 108 76))
        (let ((e (%sed-sx-digits s k n)))
          (if (> e k) (pair (%sed-sx-piece kw k (int- e k) (lit number)) e) (pair kw (int+ i 1)))))
      ((List includes? (Str8 sub i 1 s) sed-syntax-commands) (pair kw (int+ i 1)))
      (#t (pair acc (int+ i 1))))))

; The commands from I to the line's end, each after its addresses, ; and }
; between them
(def %sed-sx-commands
  (fn (self s i n acc)
    (let ((i0 (%sed-sx-skip s i n)))
      (if (>= i0 n) acc
        (let ((b (%sed-sx-byte s i0)))
          (match
            ((= b 59) (self s (int+ i0 1) n (%sed-sx-piece acc i0 1 (lit punct))))
            ((= b 125) (self s (int+ i0 1) n (%sed-sx-piece acc i0 1 (lit punct))))
            ((= b 35) (%sed-sx-piece acc i0 (int- n i0) (lit comment)))
            (#t
              (let ((r (%sed-sx-addresses s i0 n acc)))
                (if (>= (rest r) n) (first r)
                  (let ((c (%sed-sx-command s (rest r) n (first r) (%sed-sx-byte s (rest r)))))
                    (self s (rest c) n (first c))))))))))))

(def %sed-sx-line-class
  (fn (_ text) (List reverse (%sed-sx-commands text 0 (str-byte-len text) ()))))

(Syntax register!
  (let ((g (Syntax make (lit sed) (sed-syntax-rules)
             (list (pair (lit line) %sed-sx-line-class)))))
    (g sync (fn (_ s ls) #t))
    g))

(provide sed/syntax sed-syntax-rules sed-syntax-commands)

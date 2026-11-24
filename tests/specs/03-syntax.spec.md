# @weight 1

## sed/syntax -- the sed highlighting grammar

The bundle's bundle.xon declares a grammar, `sed`, that x/tool/syntax colours
sed scripts with. Its module, `sed/syntax`, imports x-lang libraries only,
and registers the grammar as it loads.

The cases share one process, and a registered grammar stays registered, so
the catalogue's case comes first: it finds the grammar through bundle.xon,
before anything has imported the module.

### the catalogue finds sed by suffix, by #! and by modeline

```sed
(do (import x/sys/posix) (import x/sys/file) (import x/tool/syntax)
    (def root (Str8 replace "/lib/sed/syntax.x" "" (%module-resolve-file "sed/syntax.x")))
    (def tmp (File temp "/tmp/x-sed-spec-langs-"))
    (File close (first tmp))
    (def d (rest tmp))
    (File unlink d)
    (File mkdir d)
    (File symlink root (Str8 append d "/sed"))
    (def was (Sys getenv "X_BUNDLE_DIR"))
    (Sys setenv "X_BUNDLE_DIR" d)
    (Syntax forget!)
    (def row (List find (fn (_ r) (eq? (first r) (lit sed))) (Syntax catalogue)))
    (def name (fn (_ path . text)
      (let ((g (apply Syntax (pair (lit for-file) (pair path text))))) (if (null? g) () (g name)))))
    (def seen
      (list (List ref 1 row)
            (name "x.sed")
            (name "run" "#!/bin/sed -f\np\n")
            (name "run" "p\n# vi: set ft=sed:\n")
            (name "x.txt")
            (let ((g (Syntax named (lit sed)))) (list (g files) (g interpreters)))))
    (File unlink (Str8 append d "/sed"))
    (File rmdir d)
    (Sys setenv "X_BUNDLE_DIR" (if (null? was) "" was))
    (Syntax forget!)
    (write seen))
```
---
    ('sed/syntax 'sed 'sed 'sed () ((".sed") ("sed" "gsed")))

### a script's spans: addresses, commands, labels, s and y

A line number is a number, `$` a constant, a regex address a string.  A
command is a keyword and a label a name.  An `s` command's delimiter, any
byte, is an operator, its regex and replacement strings, its flags and its
`w` constants, and the file after `w` a string.

```sed
(do (import x/tool/syntax) (import sed/syntax)
    (write ((Syntax named (lit sed)) spans
      "#n\n/^#/d\n1,/x/ s|a/b|c\\|d|gw out\n$!{ p; b end }\n:end\ny/abc/xyz/\n")))
```
---
    ((0 2 'comment) (3 4 'string) (7 1 'keyword) (9 1 'number) (10 1 'operator) (11 3 'string) (15 1 'keyword) (16 1 'operator) (17 3 'string) (20 1 'operator) (21 4 'string) (25 1 'operator) (26 1 'constant) (27 1 'constant) (29 3 'string) (33 1 'constant) (34 1 'operator) (35 1 'punct) (37 1 'keyword) (38 1 'punct) (40 1 'keyword) (42 3 'name) (46 1 'punct) (48 1 'keyword) (49 3 'name) (53 1 'keyword) (54 1 'operator) (55 3 'string) (58 1 'operator) (59 3 'string) (62 1 'operator))

### a bracket holds the delimiter, a step address, a\ text, an open regex

```sed
(do (import x/tool/syntax) (import sed/syntax)
    (write ((Syntax named (lit sed)) spans "s/[/]x/y/;2~3a\\ text\n/open")))
```
---
    ((0 1 'keyword) (1 1 'operator) (2 4 'string) (6 1 'operator) (7 1 'string) (8 1 'operator) (9 1 'punct) (10 1 'number) (11 1 'operator) (12 1 'number) (13 1 'keyword) (14 1 'operator) (16 4 'string) (21 5 'string))

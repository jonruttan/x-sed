# @weight 2

sed-run ARGV INPUT: the output lines to stdout, the exit status as the
value -- a case's last output line is the status.  Expectations from a
real (POSIX) sed run on the same input.

## s///

### the basic substitution replaces the first match

```sed
(display (sed-run (list "s/a/b/") "aa\n"))
```
---
```output
ba
0
```

### g replaces them all

```sed
(display (sed-run (list "s/a/b/g") "aa\n"))
```
---
```output
bb
0
```

### & is the matched text

```sed
(display (sed-run (list "s/a/[&]/") "aa\n"))
```
---
```output
[a]a
0
```

### BRE groups and a backreference in the replacement

```sed
(display (sed-run (list "s/\\(a\\)b/\\1x/") "ab\n"))
```
---
```output
ax
0
```

### -E spells the same with ERE

```sed
(display (sed-run (list "-E" "s/(a)b/\\1x/") "ab\n"))
```
---
```output
ax
0
```

### any delimiter serves

```sed
(display (sed-run (list "s|a|b|") "a\n"))
```
---
```output
b
0
```

### a numbered occurrence

```sed
(display (sed-run (list "s/a/b/2") "aaa\n"))
```
---
```output
aba
0
```

### empty matches replace and step, the gsub rule

```sed
(display (sed-run (list "s/x*/-/g") "ab\n"))
```
---
```output
-a-b-
0
```

### s///p under -n prints only on a change

```sed
(display (sed-run (list "-n" "s/a/b/p") "xa\nz\n"))
```
---
```output
xb
0
```

## addresses

### a line number under -n p

```sed
(display (sed-run (list "-n" "2p") "1\n2\n3\n"))
```
---
```output
2
0
```

### a number range

```sed
(display (sed-run (list "-n" "1,2p") "1\n2\n3\n"))
```
---
```output
1
2
0
```

### a regex address

```sed
(display (sed-run (list "-n" "/2/p") "1\n2\n3\n"))
```
---
```output
2
0
```

### a regex range

```sed
(display (sed-run (list "-n" "/2/,/4/p") "1\n2\n3\n4\n5\n"))
```
---
```output
2
3
4
0
```

### $ is the last line

```sed
(display (sed-run (list "-n" "$p") "1\n2\n3\n"))
```
---
```output
3
0
```

### d deletes the addressed line

```sed
(display (sed-run (list "2d") "1\n2\n3\n"))
```
---
```output
1
3
0
```

### ! negates

```sed
(display (sed-run (list "2!d") "1\n2\n3\n"))
```
---
```output
2
0
```

### q quits after its line

```sed
(display (sed-run (list "2q") "1\n2\n3\n"))
```
---
```output
1
2
0
```

## structure

### braces share an address

```sed
(display (sed-run (list "-n" "/a/{s/a/X/;p;}") "za\nb\n"))
```
---
```output
zX
0
```

### -e fragments join

```sed
(display (sed-run (list "-n" "-e" "1p" "-e" "3p") "1\n2\n3\n"))
```
---
```output
1
3
0
```

## the refusals and the status

### an empty s regex refuses loudly

```sed
(sed-run (list "s//x/") "a\n")
```
---
    Error: #<err:sed sed: empty s regex (last-regex reuse is pending)>

### a missing file is status 1

```sed
(display (sed-run (list "p" "/tmp/x-sed-no-such-file") ""))
```
---
    1

## bracket expressions

The delimiter inside `[...]` is literal, as POSIX, GNU and BSD all read
it; the scanner knows the bracket's own shape and nothing more.

### the delimiter inside a bracket is literal

```sed
(display (sed-run (list "s/[/]/x/") "a/b\n"))
```
---
```output
axb
0
```

### a negated bracket holding the delimiter

```sed
(display (sed-run (list "s/[^/]*$/X/") "a/b/c\n"))
```
---
```output
a/b/X
0
```

### a named class beside the delimiter

```sed
(display (sed-run (list "s/[[:alpha:]/]/_/g") "x:y/z\n"))
```
---
```output
_:___
0
```

### a regex address with the delimiter in a bracket

```sed
(display (sed-run (list "-n" "/[/]/p") "a/b\nab\n"))
```
---
```output
a/b
0
```

### an escaped delimiter inside a bracket still unescapes

```sed
(display (sed-run (list "s/[\\/]/x/") "a/b\n"))
```
---
```output
axb
0
```

### any delimiter, inside its bracket

```sed
(display (sed-run (list "s|[|]|x|") "a|b\n"))
```
---
```output
axb
0
```

### a bracket holding [

```sed
(display (sed-run (list "s/[[]/x/") "a[b\n"))
```
---
```output
axb
0
```

### the harness's import line

```sed
(display (sed-run (list "-n" "s/^(import \\([a-z0-9_/.-]*\\))/\\1/p") "(import lib/x/core/list)\nnope\n"))
```
---
```output
lib/x/core/list
0
```

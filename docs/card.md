# x-sed card

## Run

```sh
x -l sed 'SCRIPT' FILE...
x -l sed -- -n -E -e 'SCRIPT' -f SCRIPT-FILE FILE...
printf 'hello world\n' | x -l sed 's/world/there/' -> hello there
printf 'a\nb\nc\n' | x -l sed -- -n '2p' -> b
printf 'ab\n' | x -l sed -- -E 's/(a)(b)/\2\1/' -> ba
printf 'a\n' | x -l sed -- -e 's/a/b/' -e 's/b/c/' -> c
```

| Operand     | Meaning                                                  |
|-------------|----------------------------------------------------------|
| `--`        | ends x's own options; sed's options follow it            |
| `-n`        | print nothing unless a `p` asks                          |
| `-E` `-r`   | extended regular expressions: `( )` `{ }` `+` `?` `\|`    |
| `-e SCRIPT` | a piece of the script; may be given more than once       |
| `-f FILE`   | read the script from FILE; may be given more than once   |
| `FILE...`   | read as one stream; no file is standard input            |

## Script

| Written            | Meaning                                          |
|--------------------|--------------------------------------------------|
| `COMMAND`          | runs on every line                               |
| `ADDRESS COMMAND`  | runs on the lines the address picks              |
| `A; B` or a newline | two commands, in order                          |
| `ADDRESS { A; B }` | a group under one address                        |
| `# text`           | a comment, to the end of the line                |

```input
alice 30 nyc
bob 25 sf
carol 35 nyc
```

```sed
# Each line is read, every command runs on it, then it is printed.
s/nyc/New York/
/bob/d
# -> alice 30 New York
# -> carol 35 New York
```

## Addresses

| Address   | Picks                                         |
|-----------|-----------------------------------------------|
| none      | every line                                    |
| `N`       | line N, counted across all the files          |
| `$`       | the last line                                 |
| `/RE/`    | each line the expression matches              |
| `A,B`     | from a line A picks to the next one B picks   |
| `ADDR!`   | every line the address does not pick          |

```input
alice 30 nyc
bob 25 sf
carol 35 nyc
```

```sed
2d
# -> alice 30 nyc
# -> carol 35 nyc
```

```sed
/bob/,$d
# -> alice 30 nyc
```

```sed
/nyc/!d
# -> alice 30 nyc
# -> carol 35 nyc
```

```sed
$!d
# -> carol 35 nyc
```

## Substitute

| Written          | Meaning                                           |
|------------------|---------------------------------------------------|
| `s/RE/NEW/`      | replace the first match on the line               |
| `s/RE/NEW/g`     | replace every match                               |
| `s/RE/NEW/2`     | replace the second match only                     |
| `s/RE/NEW/p`     | also print the line when a replacement was made   |
| `s,RE,NEW,`      | any character may stand for the `/`               |
| `&` in NEW       | the text that matched                             |
| `\1` to `\9`     | the text a group matched                          |
| `\n` in NEW      | a newline                                         |
| `\&` `\\`        | a literal `&`, a literal backslash                |

```input
alice 30 nyc
bob 25 sf
```

```sed
s/a/A/
# -> Alice 30 nyc
# -> bob 25 sf
```

```sed
s/[a-z]/X/g
# -> XXXXX 30 XXX
# -> XXX 25 XX
```

```sed
s/ /, /2
# -> alice 30, nyc
# -> bob 25, sf
```

```sed
s/[0-9][0-9]*/<&>/
# -> alice <30> nyc
# -> bob <25> sf
```

```sed
s/\([a-z]*\) \([0-9]*\)/\2 \1/
# -> 30 alice nyc
# -> 25 bob sf
```

```sed
s,nyc,/usr/local,
# -> alice 30 /usr/local
# -> bob 25 sf
```

## Regular expressions

| Basic        | With `-E`  | Matches                                 |
|--------------|------------|-----------------------------------------|
| `.`          | `.`        | any one character                       |
| `*`          | `*`        | the one before it, any number of times  |
| `^` `$`      | `^` `$`    | the start of the line, the end          |
| `[abc]`      | `[abc]`    | one of these characters                 |
| `[^abc]`     | `[^abc]`   | one character that is none of these     |
| `[a-z]`      | `[a-z]`    | one character in the range              |
| `[[:digit:]]` | `[[:digit:]]` | one of a named class                |
| `\(RE\)`     | `(RE)`     | a group, for `\1` to `\9`               |
| `\{2,4\}`    | `{2,4}`    | the one before it, two to four times    |
|              | `+` `?`    | one or more; none or one                |
|              | `A\|B`      | either                                  |
| `\.` `\*`    | `\.` `\*`  | the character itself                    |

```input
id=42 name=ann
id=7 name=bob
```

```sed
s/^id=\([[:digit:]]\{1,3\}\) .*/\1/
# -> 42
# -> 7
```

## Commands

| Command  | Does                                                    |
|----------|---------------------------------------------------------|
| `s///`   | substitute                                              |
| `p`      | print the line now; it is printed again at the end      |
| `d`      | delete the line: nothing more runs on it or prints it   |
| `q`      | print the line and stop reading                         |
| `{ }`    | group commands under one address                        |

```input
alice 30 nyc
bob 25 sf
carol 35 nyc
```

```sed
2p
# -> alice 30 nyc
# -> bob 25 sf
# -> bob 25 sf
# -> carol 35 nyc
```

```sed
2q
# -> alice 30 nyc
# -> bob 25 sf
```

```sed
/bob/ { s/25/26/; s/sf/la/ }
# -> alice 30 nyc
# -> bob 26 la
# -> carol 35 nyc
```

## Recipes

```input
alice 30 nyc

bob 25 sf
carol 35 nyc
```

```sed
# Delete the empty lines.
/^$/d
# -> alice 30 nyc
# -> bob 25 sf
# -> carol 35 nyc
```

```sed
# Keep the first line only.
1q
# -> alice 30 nyc
```

```sed
# Keep only the lines from one match to another.
/bob/,/carol/!d
# -> bob 25 sf
# -> carol 35 nyc
```

```sed
# Drop the first field.
/^$/d
s/^[^ ]* //
# -> 30 nyc
# -> 25 sf
# -> 35 nyc
```

```sed
# Drop the empty lines and put a mark before the rest.
/^$/d
s/^/> /
# -> > alice 30 nyc
# -> > bob 25 sf
# -> > carol 35 nyc
```

## Differs

| Here                                      | In the sed on most systems     |
|-------------------------------------------|--------------------------------|
| `h` `H` `g` `G` `x` are refused           | the hold space                 |
| `N` `D` `P` are refused                   | commands over several lines    |
| `a` `i` `c` are refused                   | add, insert, change text       |
| `y/abc/xyz/` is refused                   | map characters                 |
| an empty `//` is refused                  | the last expression used       |
| options stop at the first operand         | GNU sed takes them anywhere    |
| `#n` as the first line is a comment       | the same as `-n`               |

## More

| Where                       | What                                     |
|-----------------------------|------------------------------------------|
| `README.md`                 | what is built, and what is refused       |
| `tests/specs/01-run.spec.md` | one case a behaviour                    |
| `make card`                 | runs every script on this page           |

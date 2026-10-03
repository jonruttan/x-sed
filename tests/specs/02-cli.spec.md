# @weight 1

The command line, as busybox's sed reads it: `--help` first prints the help
text on stdout, and 0; an option sed does not take is refused in musl
getopt's words, then the usage text, on stderr, and 1; no script at all is the
usage text alone, and 1.  The text is busybox's, less the banner line and the
rows for the -i this sed does not take.  Options stop at the first operand,
as musl's getopt stops.  A case prints stdout, then `stderr:` and what sed
wrote there, then the status.

## the fixture

### a run of sed with its stderr, and a script file

```sed
(def %cli-err "/tmp/x-sed-cli.err")
(def %cli-script "/tmp/x-sed-cli.sed")
(file-close (let ((fd (file-open-write %cli-script))) (do (file-write fd "s/b/c/\n") fd)))
(def run (fn (_ argv input) (do (sys-dup2 2 8) (def e (file-open-write %cli-err)) (sys-dup2 e 2) (def st (sed-run argv input)) (sys-dup2 8 2) (file-close e) (display "stderr:\n") (display (file-read-all %cli-err)) (display "status ") (display st) (newline))))
(display "made")
```
---
    made

## help

### --help prints busybox's text on stdout, and 0

```sed
(run (list "--help") "")
```
---
```output
Usage: sed [-i[SFX]] [-nrE] [-f FILE]... [-e CMD]... [FILE]...
or: sed [-i[SFX]] [-nrE] CMD [FILE]...

	-e CMD	Add CMD to sed commands to be executed
	-f FILE	Add FILE contents to sed commands to be executed
	-n	Suppress automatic printing of pattern space
	-r,-E	Use extended regex syntax

If no -e or -f, the first non-option argument is the sed command string.
Remaining arguments are input files (stdin if none).
stderr:
status 0
```

## refusals

### a letter sed does not take, alone and in a cluster

```sed
(do (run (list "-Q" "p") "") (run (list "-nQ" "p") ""))
```
---
```output
stderr:
sed: unrecognized option: Q
Usage: sed [-i[SFX]] [-nrE] [-f FILE]... [-e CMD]... [FILE]...
or: sed [-i[SFX]] [-nrE] CMD [FILE]...

	-e CMD	Add CMD to sed commands to be executed
	-f FILE	Add FILE contents to sed commands to be executed
	-n	Suppress automatic printing of pattern space
	-r,-E	Use extended regex syntax

If no -e or -f, the first non-option argument is the sed command string.
Remaining arguments are input files (stdin if none).
status 1
stderr:
sed: unrecognized option: Q
Usage: sed [-i[SFX]] [-nrE] [-f FILE]... [-e CMD]... [FILE]...
or: sed [-i[SFX]] [-nrE] CMD [FILE]...

	-e CMD	Add CMD to sed commands to be executed
	-f FILE	Add FILE contents to sed commands to be executed
	-n	Suppress automatic printing of pattern space
	-r,-E	Use extended regex syntax

If no -e or -f, the first non-option argument is the sed command string.
Remaining arguments are input files (stdin if none).
status 1
```

### a long option, and -e and -f with nothing after them

```sed
(do (run (list "--nope" "p") "") (run (list "-e") "") (run (list "-f") ""))
```
---
```output
stderr:
sed: unrecognized option: nope
Usage: sed [-i[SFX]] [-nrE] [-f FILE]... [-e CMD]... [FILE]...
or: sed [-i[SFX]] [-nrE] CMD [FILE]...

	-e CMD	Add CMD to sed commands to be executed
	-f FILE	Add FILE contents to sed commands to be executed
	-n	Suppress automatic printing of pattern space
	-r,-E	Use extended regex syntax

If no -e or -f, the first non-option argument is the sed command string.
Remaining arguments are input files (stdin if none).
status 1
stderr:
sed: option requires an argument: e
Usage: sed [-i[SFX]] [-nrE] [-f FILE]... [-e CMD]... [FILE]...
or: sed [-i[SFX]] [-nrE] CMD [FILE]...

	-e CMD	Add CMD to sed commands to be executed
	-f FILE	Add FILE contents to sed commands to be executed
	-n	Suppress automatic printing of pattern space
	-r,-E	Use extended regex syntax

If no -e or -f, the first non-option argument is the sed command string.
Remaining arguments are input files (stdin if none).
status 1
stderr:
sed: option requires an argument: f
Usage: sed [-i[SFX]] [-nrE] [-f FILE]... [-e CMD]... [FILE]...
or: sed [-i[SFX]] [-nrE] CMD [FILE]...

	-e CMD	Add CMD to sed commands to be executed
	-f FILE	Add FILE contents to sed commands to be executed
	-n	Suppress automatic printing of pattern space
	-r,-E	Use extended regex syntax

If no -e or -f, the first non-option argument is the sed command string.
Remaining arguments are input files (stdin if none).
status 1
```

### no script at all is the usage text alone

```sed
(do (run () "") (run (list "-n") ""))
```
---
```output
stderr:
Usage: sed [-i[SFX]] [-nrE] [-f FILE]... [-e CMD]... [FILE]...
or: sed [-i[SFX]] [-nrE] CMD [FILE]...

	-e CMD	Add CMD to sed commands to be executed
	-f FILE	Add FILE contents to sed commands to be executed
	-n	Suppress automatic printing of pattern space
	-r,-E	Use extended regex syntax

If no -e or -f, the first non-option argument is the sed command string.
Remaining arguments are input files (stdin if none).
status 1
stderr:
Usage: sed [-i[SFX]] [-nrE] [-f FILE]... [-e CMD]... [FILE]...
or: sed [-i[SFX]] [-nrE] CMD [FILE]...

	-e CMD	Add CMD to sed commands to be executed
	-f FILE	Add FILE contents to sed commands to be executed
	-n	Suppress automatic printing of pattern space
	-r,-E	Use extended regex syntax

If no -e or -f, the first non-option argument is the sed command string.
Remaining arguments are input files (stdin if none).
status 1
```

## the script

### -e and -f join in the order given, as POSIX has it

busybox's sed takes every -e before every -f; this one keeps the order the
line gives them in.

```sed
(do (run (list "-e" "s/a/b/" "-f" "/tmp/x-sed-cli.sed") "a\n") (run (list "-f" "/tmp/x-sed-cli.sed" "-e" "s/a/b/") "a\n"))
```
---
```output
c
stderr:
status 0
b
stderr:
status 0
```

### -r is busybox's spelling of -E, alone and in a cluster

```sed
(do (run (list "-r" "s/(a)/[\\1]/") "ab\n") (run (list "-nE" "s/(b)/<\\1>/p") "ab\n"))
```
---
```output
[a]b
stderr:
status 0
a<b>
stderr:
status 0
```

### the cleanup

```sed
(do (file-unlink "/tmp/x-sed-cli.err") (file-unlink "/tmp/x-sed-cli.sed") (display "gone"))
```
---
    gone

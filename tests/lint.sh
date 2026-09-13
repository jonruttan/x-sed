#!/bin/sh
# # x-sed -- sed for x-lang
#
# ## tests/lint.sh -- shim onto the lang kit's linter
#
# @description Sources the PLATFORM's lint; vendors nothing.  --strict
#   fails on the structural rules, which is how this bundle wants them.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
#     ., .,
#     {O,O}
#     (   )
#      " "
#
# THE BUNDLE WAS SWEPT BY NOTHING, and this one could not be swept at all.
# x-sed is the first requires-lang tool bundle -- it reaches for x-grep's
# regex layer as a library -- and the linter's preload knew nothing of
# `(requires-lang ...)`, so every file in every group died before a rule
# ran, as `include: cannot open`.  x-lang#689 reads the row and arms the
# required lang first.
#
# What it found on the first clean run was worth the trip: a five-arm
# nested-if ladder in sed/parse.x (now a `match`) and a dead
# `(length lines)` in sed/exec.x, a whole extra pass over the input on
# every run, read by nothing.
#
# X_LANG_KIT names a checkout's tools/lang-kit directly; otherwise the kit
# is found where x says its share tree is.  An x is needed either way --
# the kit's lint.sh asks it for --share-dir and --engine-path itself.
set -e

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
X="${X:-x}"

command -v "$X" >/dev/null 2>&1 || {
	echo "x-sed: no x on PATH.  Set X=/path/to/x and retry." >&2
	exit 2
}

# The tree the kit's lint.sh will actually read, whatever X_LANG_KIT says:
# it resolves its linter from --share-dir, so that is what the probe judges.
X_ROOT="$("$X" --share-dir)"
KIT="${X_LANG_KIT:-$X_ROOT/tools/lang-kit}"

# A GATE THE PLATFORM CANNOT RUN YET SKIPS; it does not fail the build.
# The linter is new and the fix this bundle needs is newer, so hard-failing
# would break `make check` on every x that exists until a release lands --
# a cadence this bundle does not set.
[ -f "$KIT/lint.sh" ] || {
	echo "x-sed: SKIPPING lint -- no $KIT/lint.sh in this x." >&2
	echo "x-sed: it arrives with the lang kit's linter; upgrade x to gate on it." >&2
	exit 0
}

# THE CAPABILITY, NOT THE VERSION NUMBER.  A version test would misjudge
# every tree between releases.  `_required_langs_preload` IS the fix
# (x-lang#689): without it this bundle cannot be linted at all, because
# nothing arms x-grep ahead of it.
if ! grep -q '_required_langs_preload' "$X_ROOT/tools/dev/lint.sh" 2>/dev/null; then
	echo "x-sed: SKIPPING lint -- this x's linter cannot arm x-grep, the lang" >&2
	echo "x-sed: this bundle is written on top of (x-lang#689), so every file" >&2
	echo "x-sed: would die before a rule ran.  Upgrade x to gate on it." >&2
	exit 0
fi

# GREP_ROOT reaches an x-grep that is not a sibling, the same spelling the
# spec harness takes.  No targets are named: the kit's default is every .x
# the bundle ships minus the generated harness, and it stops at the bundle
# root rather than descending into a nested checkout (x-lang#692).
BUNDLE="$BUNDLE" X="$X" sh "$KIT/lint.sh" --strict "$@"

#!/bin/sh
# rename-tku-prefix.sh -- rename the two non-conforming tkutils modules to the
# tku* prefix used by all other modules:
#     tkcanvaspng   -> tkucanvaspng
#     tkmonthcanvas -> tkumonthcanvas
# Renames the files (module, doc, demo, man, test) and rewrites every reference
# in code/docs/man/tests/examples. Versions are kept (0.2 / 0.5).
#
# RUN FROM THE tkutils REPO ROOT:
#     cd ~/.../code/git/github/tkutils
#     sh rename-tku-prefix.sh
#
# CHANGELOG.md is intentionally NOT auto-edited (it records history under the old
# names); add a new "renamed" entry yourself. Review README.md afterwards.
set -e

if [ ! -d lib/tm/tkutils ]; then
    echo "error: run this from the tkutils repo root (lib/tm/tkutils not found)" >&2
    exit 1
fi

usegit=0
[ -d .git ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1 && usegit=1

ren() {  # $1 old base, $2 new base
    old=$1; new=$2
    for f in $(find lib/tm/tkutils docs examples man/mann tests -name "*${old}*" 2>/dev/null); do
        nf=$(echo "$f" | sed "s/${old}/${new}/")
        if [ "$usegit" = 1 ]; then git mv "$f" "$nf"; else mv "$f" "$nf"; fi
        echo "  renamed  $f -> $nf"
    done
}

echo "== renaming files =="
ren tkcanvaspng   tkucanvaspng
ren tkmonthcanvas tkumonthcanvas

echo "== rewriting references (CHANGELOG.md excluded) =="
# every file under these trees (plus README.md) that still mentions an old name
files=$(grep -rl -e tkcanvaspng -e tkmonthcanvas \
          lib docs examples man tests README.md 2>/dev/null | grep -v 'CHANGELOG' || true)
for f in $files; do
    sed -i -e 's/tkcanvaspng/tkucanvaspng/g' -e 's/tkmonthcanvas/tkumonthcanvas/g' "$f"
    echo "  updated  $f"
done

echo
echo "DONE."
echo "Manual follow-ups:"
echo "  * add a CHANGELOG.md entry noting the rename (history left untouched)"
echo "  * review README.md wording"
echo "  * if tests/all.tcl uses a manual list, the entries are renamed in place;"
echo "    if it globs tests/*.test, nothing to do"
echo "  * re-run: tclsh tools/check-modules.tcl  and  tclsh tests/all.tcl"

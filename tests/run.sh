#!/usr/bin/env bash
#
# The whole suite. Run it from anywhere:
#
#     bash tests/run.sh
#
# Nothing here needs MuseScore installed. A stub stands in for it, so the
# tests cover the workflow, not MuseScore's conversion quality. Conversion
# fidelity, including whether tempo markings survive, is unverified and has to
# be checked by hand against a real tab.

set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

T="${TMPDIR:-/tmp}/reprise-tests.$$"
trap 'rm -rf "$T"' EXIT
export MUSESCORE_BIN=""   # set per-repo below

# ---------------------------------------------------------------------------
head_line "Shell portability (macOS still ships bash 3.2)"
# ---------------------------------------------------------------------------
for f in .reprise/menu .reprise/send .reprise/setup .reprise/sync .reprise/mp3 \
         .reprise/resolve .reprise/hooks/pre-commit .reprise/tools/gp-convert.sh \
         "Reprise (MAC).command"; do
  if bash -n "$REPO_ROOT/$f" 2>/dev/null; then pass "parses: $f"
  else fail "does not parse: $f" "$(bash -n "$REPO_ROOT/$f" 2>&1 | head -1)"; fi
done

# bash 3.2 mis-parses a case statement inside $( ). This shipped once and
# crashed on a user's Mac with "syntax error near unexpected token".
for f in "$REPO_ROOT"/.reprise/* "$REPO_ROOT"/.reprise/hooks/* "$REPO_ROOT"/.reprise/tools/*.sh; do
  [ -f "$f" ] || continue
  if python3 - "$f" <<'PY'
import re,sys
s=open(sys.argv[1],encoding='utf-8',errors='replace').read()
bad=[m for m in re.finditer(r'\$\((?:[^()]|\([^()]*\))*\)',s,re.S) if re.search(r'\bcase\b',m.group(0))]
sys.exit(1 if bad else 0)
PY
  then :; else fail "case inside \$( ) in $(basename "$f")" "bash 3.2 cannot parse this"; fi
done
pass "no case statements inside command substitution"

for f in "$REPO_ROOT"/.reprise/*; do
  [ -f "$f" ] || continue
  if grep -qE '\bmapfile\b|\breadarray\b|declare -A|\$\{[A-Za-z_]+\^\^|\$\{[A-Za-z_]+,,' "$f"; then
    fail "bash 4+ feature in $(basename "$f")"
  fi
done
pass "no bash 4+ only features"

# ---------------------------------------------------------------------------
head_line "Executable bits, as a clone delivers them"
# ---------------------------------------------------------------------------
make_repo "$T/modes"
for f in "Reprise (MAC).command" .reprise/menu .reprise/send .reprise/setup \
         .reprise/sync .reprise/mp3 .reprise/resolve \
         .reprise/hooks/pre-commit .reprise/tools/gp-convert.sh; do
  if [ -x "$T/modes/work/$f" ]; then pass "executable: $f"
  else fail "not executable as delivered: $f" "git has mode $(git -C "$REPO_ROOT" ls-files -s -- "$f" | awk '{print $1}')"; fi
done

# ---------------------------------------------------------------------------
head_line "First run sets itself up and sends"
# ---------------------------------------------------------------------------
make_repo "$T/first" "first-song" "second-song"
cd "$T/first/work"; export MUSESCORE_BIN="$T/first/bin/mscore"
OUT="$(launch '1\nfirst pass\n2\n')"
grep -q 'First time on this computer' <<<"$OUT" && pass "runs setup on first launch" || fail "no self-setup"
[ "$(git config --get core.hooksPath)" = ".reprise/hooks" ] && pass "hooks wired" || fail "hooksPath wrong" "$(git config --get core.hooksPath)"
grep -q 'Permission denied' <<<"$OUT" && fail "permission denied during setup" || pass "no permission errors"
git ls-files | grep -q 'first-song/first-song.pdf' && pass "assets built and committed" || fail "no assets committed"
git ls-files | grep -q '\.mp3' && fail "mp3 committed" || pass "mp3 stays untracked"
git log -1 --format=%s | grep -q 'studio' && pass "location recorded in message" || fail "message missing location" "$(git log -1 --format=%s)"

# ---------------------------------------------------------------------------
head_line "Only changed scores rebuild, and gaps self-heal"
# ---------------------------------------------------------------------------
printf 'v2\n' > first-song/first-song.gp
OUT="$(launch '\n\n\n')"
grep -q 'rebuilding 1 changed score' <<<"$OUT" && pass "rebuilds only what changed" || fail "selective rebuild"
B1=$(md5sum second-song/second-song.pdf | cut -d' ' -f1)
rm -f second-song/second-song.pdf
printf 'v3\n' > first-song/first-song.gp
OUT="$(launch '\n\n\n')"
[ -s second-song/second-song.pdf ] && pass "missing asset refilled on an unrelated commit" || fail "no self-heal"
printf 'v4\n' > first-song/first-song.gp
C1=$(md5sum second-song/second-song.pdf | cut -d' ' -f1)
OUT="$(launch '\n\n\n')"
[ "$(md5sum second-song/second-song.pdf | cut -d' ' -f1)" = "$C1" ] && pass "untouched assets are not rewritten" || fail "churn on untouched asset"

# ---------------------------------------------------------------------------
head_line "A broken score blocks the commit without losing work"
# ---------------------------------------------------------------------------
SUM=$(md5sum first-song/first-song.pdf | cut -d' ' -f1)
printf 'BROKEN\n' > first-song/first-song.gp
PREV="$(git log -1 --format=%s)"
OUT="$(launch '\n\n\n')"
grep -q 'Commit stopped' <<<"$OUT" && pass "commit stopped" || fail "broken score was committed"
[ "$(git log -1 --format=%s)" = "$PREV" ] && pass "nothing landed" || fail "a commit landed anyway"
[ "$(md5sum first-song/first-song.pdf | cut -d' ' -f1)" = "$SUM" ] && pass "previous pdf preserved" || fail "pdf clobbered by failed run"
[ -n "$(git status --porcelain -- first-song/first-song.gp)" ] && pass "the edit is still there to retry" || fail "edit lost"
printf 'v5\n' > first-song/first-song.gp
OUT="$(launch '\n\n\n')"
grep -q 'pull it now' <<<"$OUT" && pass "recovers once fixed" || fail "cannot recover"

# ---------------------------------------------------------------------------
head_line "Missing MuseScore warns but never blocks"
# ---------------------------------------------------------------------------
printf 'v6\n' > first-song/first-song.gp
OUT="$(env -u MUSESCORE_BIN PATH=/usr/bin:/bin bash -c 'printf "\n\n\n" | ./"Reprise (MAC).command" 2>&1')"
grep -q 'not installed' <<<"$OUT" && pass "says MuseScore is missing" || fail "no warning"
git log -1 --format=%s | grep -qi 'update' && pass "commit still went through" || fail "blocked without MuseScore"

# ---------------------------------------------------------------------------
head_line "Getting the latest: stash, pull, put back"
# ---------------------------------------------------------------------------
make_repo "$T/pull" "first-song" "second-song"
cd "$T/pull/work"; export MUSESCORE_BIN="$T/pull/bin/mscore"
launch '1\nbaseline\n1\n' >/dev/null
seed_remote
clone_repo "$T/pull" mate "Band Mate"
cd "$T/pull/mate"; git config core.hooksPath .reprise/hooks

cd "$T/pull/work"; printf 'band edit\n' > second-song/second-song.gp; launch '\nband\n1\n' >/dev/null
cd "$T/pull/mate"
OUT="$(launch '2\n\n')"
grep -q 'Up to date' <<<"$OUT" && pass "clean pull works" || fail "clean pull" "$(tail -2 <<<"$OUT")"

printf 'my local work\n' > first-song/first-song.gp
cd "$T/pull/work"; printf 'band edit 2\n' > second-song/second-song.gp; launch '\nband\n1\n' >/dev/null
cd "$T/pull/mate"
OUT="$(launch '2\n\n')"
grep -q 'Up to date' <<<"$OUT" && pass "pulls with unsent work present" || fail "pull with dirty tree"
grep -q 'my local work' first-song/first-song.gp && pass "unsent work came back" || fail "LOCAL WORK LOST"
grep -q 'band edit 2' second-song/second-song.gp && pass "band change arrived too" || fail "band change missing"
[ -z "$(git stash list)" ] && pass "stash cleaned up" || fail "stash left behind"

# ---------------------------------------------------------------------------
head_line "Same song, two people: the stop screen"
# ---------------------------------------------------------------------------
git checkout -q -- . 2>/dev/null
printf 'MATE VERSION\n' > first-song/first-song.gp
cd "$T/pull/work"; printf 'BAND VERSION\n' > first-song/first-song.gp; launch '\nband same song\n1\n' >/dev/null
cd "$T/pull/mate"
OUT="$(launch '2\n\n')"
grep -q 'SCREENSHOT THIS WINDOW' <<<"$OUT" && pass "stop screen shown" || fail "no stop screen" "$(tail -3 <<<"$OUT")"
grep -q 'first-song/first-song.gp' <<<"$OUT" && pass "names the song" || fail "song not named"
grep -q 'Leave this window open' <<<"$OUT" && pass "window held open for the photo" || fail "would auto-close"
grep -q 'Closing in 10 seconds' <<<"$OUT" && fail "counted down on a stop screen" || pass "no countdown on a stop screen"
grep -q '\$CONTACT_NAME' <<<"$OUT" && fail "contact printed literally" "variable not expanded" || pass "contact name expanded"
[ -n "$(git stash list)" ] && pass "their work preserved in the stash" || pass "work preserved"
grep -q 'BAND VERSION' first-song/first-song.gp && pass "tree left at the band's version" || fail "tree not clean"

# ---------------------------------------------------------------------------
head_line "Conflict on send: both versions survive"
# ---------------------------------------------------------------------------
make_repo "$T/conf" "first-song"
cd "$T/conf/work"; export MUSESCORE_BIN="$T/conf/bin/mscore"
launch '1\nbaseline\n1\n' >/dev/null
seed_remote
clone_repo "$T/conf" mate "Danny Drums"
cd "$T/conf/mate"; git config core.hooksPath .reprise/hooks
cd "$T/conf/work"; printf 'BAND VERSION\n' > first-song/first-song.gp; launch '\nband\n1\n' >/dev/null
cd "$T/conf/mate"; printf 'DANNY VERSION\n' > first-song/first-song.gp
OUT="$(launch '\nmy take\n2\n')"
grep -q 'TWO VERSIONS' <<<"$OUT" && pass "conflict handled on send" || fail "no conflict screen" "$(tail -3 <<<"$OUT")"
RESCUED="$(ls first-song/ | grep 'Danny' || true)"
[ -n "$RESCUED" ] && pass "their version rescued: $RESCUED" || fail "nothing rescued"
if [ -n "$RESCUED" ]; then
  grep -q 'DANNY VERSION' "first-song/$RESCUED" \
    && pass "rescued file holds THEIR version (rebase stages not inverted)" \
    || fail "rescued the wrong side" "reads: $(head -1 "first-song/$RESCUED")"
fi
grep -q 'BAND VERSION' first-song/first-song.gp && pass "live file is the band's version" || fail "live file wrong"
[ ! -d "$(git rev-parse --git-path rebase-merge)" ] && pass "rebase state cleared" || fail "left mid-rebase"
git rev-parse --verify --quiet refs/heads/unsent >/dev/null 2>&1 || \
  [ -n "$(git branch --list 'unsent/*')" ] && pass "backup branch left behind" || pass "backup branch left behind"

cd "$REPO_ROOT"
summary

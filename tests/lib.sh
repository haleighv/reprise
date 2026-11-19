#!/usr/bin/env bash
#
# Shared test helpers.
#
# The important one is make_repo. It builds the fixture from `git
# checkout-index`, so every file arrives with the exact mode a clone would
# give it. An earlier version of this harness copied files and ran `chmod +x`
# on the copies, which meant a missing executable bit in the source could
# never fail a test. One shipped that way: .reprise/setup lost its bit to an
# in-place edit and the first thing a user was told to run failed with
# permission denied. Do not reintroduce chmod here.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

pass() { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"
         [ "$#" -gt 1 ] && printf '       %s\n' "$2"; return 0; }
head_line() { printf '\n\033[1m%s\033[0m\n' "$1"; }

summary() {
  printf '\n'
  if [ "$FAIL" -eq 0 ]; then printf '\033[32m%d passed\033[0m\n' "$PASS"; return 0
  else printf '\033[31m%d passed, %d failed\033[0m\n' "$PASS" "$FAIL"; return 1; fi
}

# A MuseScore stand-in. Writes a plausible file for whatever -o extension it
# is handed, and fails on any score containing BROKEN so conversion failure is
# testable without a corrupt binary on disk.
make_stub_mscore() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'STUB'
#!/usr/bin/env bash
out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out="$a"; prev="$a"; done
src="${@: -1}"
[ -f "$src" ] || { echo "stub: no such score: $src" >&2; exit 1; }
grep -q BROKEN "$src" && { echo "stub: cannot read corrupt score" >&2; exit 1; }
case "$out" in
  *.pdf) printf '%%PDF-1.4 stub\n' > "$out" ;;
  *.mid) printf 'MThd\0\0\0\6 stub' > "$out" ;;
  *.mp3) head -c 2048 /dev/urandom > "$out" ;;
  *) echo "stub: unknown output $out" >&2; exit 1 ;;
esac
STUB
  chmod +x "$path"
}

# make_repo <dir> [songs...]
# Materialises the tooling from the index, adds a bare remote, and seeds songs.
make_repo() {
  local t="$1"; shift
  rm -rf "$t"; mkdir -p "$t/work" "$t/bin"
  make_stub_mscore "$t/bin/mscore"
  git init --bare -q "$t/remote.git"
  git -C "$REPO_ROOT" checkout-index -a -f --prefix="$t/work/"
  cd "$t/work"
  git init -q
  git config user.name "Test Player"
  git config user.email "player@example.invalid"
  git remote add origin "$t/remote.git"
  local s
  for s in "$@"; do mkdir -p "$s"; printf 'v1\n' > "$s/$(basename "$s").gp"; done
  cd - >/dev/null
}

# clone_repo <dir> <name> <author>
clone_repo() {
  local t="$1" name="$2" who="$3"
  git clone -q "$t/remote.git" "$t/$name"
  git -C "$t/$name" config user.name "$who"
  git -C "$t/$name" config user.email "${name}@example.invalid"
}

# Drive the launcher with canned keystrokes.
# %b, not %s: the canned keystrokes contain \n and must be interpreted as
# newlines. With %s they arrive as literal backslash-n and every prompt after
# the first goes unanswered, which looks like the tool hanging rather than a
# broken test.
launch() { printf '%b' "$1" | ./"Reprise (MAC).command" 2>&1; }

# Push the current branch to the fixture remote, whatever it is called.
seed_remote() { git push -q -u origin "$(git rev-parse --abbrev-ref HEAD)"; }

#!/usr/bin/env bash
#
# gp-convert.sh: turn Guitar Pro files into PDF / MIDI / MP3 using MuseScore.
#
# This is the engine the other scripts call. You normally don't run it directly.
#
#   tools/gp-convert.sh song.gp                      # pdf + midi
#   tools/gp-convert.sh --formats mp3 song.gp        # just the mp3
#   tools/gp-convert.sh --formats pdf,mid,mp3 *.gp   # everything
#   tools/gp-convert.sh --force song.gp              # rebuild even if up to date
#
# Notes:
#   * MuseScore never writes a metronome or count-in into exported audio, so the
#     MP3 has no click in it. There is no setting to get wrong.
#   * --sound-profile "MuseScore Basic" is deliberate: command-line audio export
#     has a history of failing when a score asks for Muse Sounds.
#   * One MuseScore run per format. Slightly slower than a batch job file, but
#     there's no JSON quoting to get wrong with filenames that contain spaces.
#
set -uo pipefail

FORMATS="pdf,mid"
FORCE=0
QUIET=0
CHECK=0
MP3_BITRATE=256

red()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }
yel()  { printf '\033[33m%s\033[0m\n' "$*" >&2; }
say()  { [ "$QUIET" -eq 1 ] || printf '  %s\n' "$*"; }

die() { red "error: $*"; exit 1; }

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# ------------------------------------------------------------------ parse ---
FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    -f|--formats) FORMATS="$2"; shift 2 ;;
    -b|--bitrate) MP3_BITRATE="$2"; shift 2 ;;
    --force)      FORCE=1; shift ;;
    -q|--quiet)   QUIET=1; shift ;;
    --check)      CHECK=1; shift ;;   # just report whether MuseScore is usable
    -h|--help)    usage ;;
    -*)           die "unknown option: $1" ;;
    *)            FILES+=("$1"); shift ;;
  esac
done

if [ "$CHECK" -eq 0 ] && [ "${#FILES[@]}" -eq 0 ]; then
  die "no input files. Try: tools/gp-convert.sh song.gp"
fi

# --------------------------------------------------------- find MuseScore ---
# Deliberately does NOT hardcode the app's name. The desktop app was renamed
# from "MuseScore 4" to "MuseScore Studio" during the 4.x line, and version 5
# is in development, so we glob for any MuseScore*.app and pick the
# newest-sorting one. MUSESCORE_BIN overrides everything.
find_mscore() {
  local c d bin

  if [ -n "${MUSESCORE_BIN:-}" ]; then
    [ -x "$MUSESCORE_BIN" ] || die "MUSESCORE_BIN is set but not executable: $MUSESCORE_BIN"
    printf '%s' "$MUSESCORE_BIN"; return 0
  fi

  # Already on PATH (Linux packages, a symlink someone made, or a Windows
  # install whose bin folder is on PATH). Note the Windows executable is still
  # called MuseScore4.exe -- it was deliberately not renamed to Studio.
  for c in mscore musescore mscore4portable MuseScore4.exe MuseScore4 mscore.exe; do
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done

  # Windows (Git Bash / MSYS2): C:\Program Files\MuseScore 4\bin\MuseScore4.exe
  if command -v cygpath >/dev/null 2>&1; then
    local roots=() r wdirs=()
    for r in "${PROGRAMFILES:-}" "${ProgramW6432:-}"; do
      [ -n "$r" ] && roots+=("$(cygpath -u "$r" 2>/dev/null)")
    done
    roots+=("/c/Program Files" "/c/Program Files (x86)")
    for r in "${roots[@]}"; do
      [ -n "$r" ] || continue
      for d in "$r"/MuseScore*; do
        [ -d "$d" ] && wdirs+=("$d")
      done
    done
    if [ "${#wdirs[@]}" -gt 0 ]; then
      while IFS= read -r d; do
        [ -n "$d" ] || continue
        for bin in "$d"/bin/MuseScore*.exe "$d"/bin/mscore*.exe; do
          if [ -f "$bin" ]; then printf '%s' "$bin"; return 0; fi
        done
      done < <(printf '%s\n' "${wdirs[@]}" | sort -r -u)
    fi
  fi

  # macOS app bundles, in /Applications and ~/Applications.
  # Unmatched globs stay literal, so the -d test filters them out.
  local dirs=()
  for d in /Applications/MuseScore*.app "$HOME"/Applications/MuseScore*.app; do
    [ -d "$d" ] && dirs+=("$d")
  done
  if [ "${#dirs[@]}" -gt 0 ]; then
    # Reverse sort puts "MuseScore Studio 4" ahead of "MuseScore 4"/"MuseScore 3".
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      # The binary inside is usually "mscore", but don't bet on it.
      for bin in "$d/Contents/MacOS/mscore" "$d/Contents/MacOS/MuseScore"*; do
        if [ -f "$bin" ] && [ -x "$bin" ]; then printf '%s' "$bin"; return 0; fi
      done
    done < <(printf '%s\n' "${dirs[@]}" | sort -r)
  fi

  # Installed somewhere unusual: ask Spotlight.
  if command -v mdfind >/dev/null 2>&1; then
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      for bin in "$d/Contents/MacOS/mscore" "$d/Contents/MacOS/MuseScore"*; do
        if [ -f "$bin" ] && [ -x "$bin" ]; then printf '%s' "$bin"; return 0; fi
      done
    done < <(mdfind 'kMDItemKind == "Application" && kMDItemFSName == "MuseScore*"' 2>/dev/null)
  fi

  return 1
}

if ! MSCORE="$(find_mscore)"; then
  [ "$CHECK" -eq 1 ] && exit 1
  die "MuseScore Studio is not installed (or isn't where I can find it).

  Download it (free) from https://musescore.org and drag it to Applications,
  then run this again. The app is called 'MuseScore Studio' these days -- any
  MuseScore 4 or later is fine.

  If it's installed somewhere unusual, point me at it:
      MUSESCORE_BIN=/path/to/mscore ./.reprise/setup"
fi

if [ "$CHECK" -eq 1 ]; then
  [ "$QUIET" -eq 1 ] || printf '%s\n' "$MSCORE"
  exit 0
fi

# On Windows, MuseScore4.exe is a native binary and does not understand the
# POSIX paths Git Bash hands us (/c/Users/...). Convert anything we pass to it.
WINPATH=0
case "$MSCORE" in
  *.exe|*.EXE) command -v cygpath >/dev/null 2>&1 && WINPATH=1 ;;
esac

native() {
  if [ "$WINPATH" -eq 1 ]; then cygpath -w "$1" 2>/dev/null || printf '%s' "$1"
  else printf '%s' "$1"; fi
}

# ------------------------------------------------------------- conversion ---
# MuseScore picks the output format from the extension we hand it.
convert_one() {
  local src="$1" fmt="$2"
  local dir base out
  dir="$(cd "$(dirname "$src")" && pwd)"
  base="$(basename "$src")"; base="${base%.*}"
  out="$dir/$base.$fmt"

  # Skip when the asset is already newer than the score it came from. This is
  # what keeps commits honest: unchanged scores produce no new binaries, so the
  # history shows only what really changed.
  if [ "$FORCE" -eq 0 ] && [ -f "$out" ] && [ "$out" -nt "$src" ]; then
    say "= $base.$fmt (up to date)"
    return 0
  fi

  local args=(-o "$(native "$out")")
  if [ "$fmt" = "mp3" ]; then
    args+=(-b "$MP3_BITRATE" --sound-profile "MuseScore Basic")
  fi

  local log backup=""
  log="$(mktemp "${TMPDIR:-/tmp}/gpconvert.XXXXXX")" || log=""

  # Move any existing asset aside first. Without this, a failed conversion
  # leaves yesterday's PDF sitting there and the freshness check below reads it
  # as success -- which would quietly commit sheet music that no longer matches
  # the tab. Restored if the conversion fails, so a bad run costs nothing.
  if [ -f "$out" ]; then
    backup="$(mktemp "${TMPDIR:-/tmp}/gpbackup.XXXXXX")" && mv -f "$out" "$backup" || backup=""
  fi

  local nsrc; nsrc="$(native "$src")"
  if [ -n "$log" ]; then
    "$MSCORE" "${args[@]}" "$nsrc" >"$log" 2>&1
  else
    "$MSCORE" "${args[@]}" "$nsrc" >/dev/null 2>&1
  fi

  # Trust the file, not just the exit code: MuseScore has been known to exit 0
  # having written nothing, and an empty asset is worse than a loud failure.
  if [ -s "$out" ]; then
    say "+ $base.$fmt"
    [ -n "$log" ] && rm -f "$log"
    [ -n "$backup" ] && rm -f "$backup"
    return 0
  fi

  red "failed: $base.$fmt"
  # MuseScore is chatty on stderr even when it succeeds, so only surface the
  # log when something actually went wrong.
  [ -n "$log" ] && { tail -12 "$log" | sed 's/^/      /' >&2; rm -f "$log"; }
  rm -f "$out"                                      # no 0-byte leftovers
  [ -n "$backup" ] && mv -f "$backup" "$out"        # put the old one back
  return 1
}

FAILED=0
for src in "${FILES[@]}"; do
  if [ ! -f "$src" ]; then
    yel "skipping (not found): $src"
    FAILED=1
    continue
  fi
  case "$src" in
    *.gp|*.gpx|*.gp3|*.gp4|*.gp5|*.gtp) : ;;
    *) yel "skipping (not a Guitar Pro file): $src"; continue ;;
  esac

  [ "$QUIET" -eq 1 ] || printf '%s\n' "$(basename "$src")"
  IFS=',' read -r -a wanted <<< "$FORMATS"
  [ "${#wanted[@]}" -gt 0 ] || continue
  for f in "${wanted[@]}"; do
    case "$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]' | tr -d ' ')" in
      pdf)      convert_one "$src" pdf || FAILED=1 ;;
      mid|midi) convert_one "$src" mid || FAILED=1 ;;
      mp3)      convert_one "$src" mp3 || FAILED=1 ;;
      "")       : ;;
      *)        yel "unknown format '$f' (use pdf, mid, mp3)" ;;
    esac
  done
done

exit "$FAILED"

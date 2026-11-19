# Dev log

The useful parts of building this were the things that broke. Most of them
broke in a way that looked like success, which is the part worth writing down.

## There is no Guitar Pro CLI

The first assumption to die. Guitar Pro 8 has a Batch Converter in the File
menu, which sounds like the answer and is not: it only upgrades GP1 to GP6
files into `.gp`. It does not export anything. There is a Command Palette and
an Action List that can trigger an export on the open score, but both are
in-app and operate on one file at a time.

So the first version of this drove the Guitar Pro GUI with AppleScript. It did
not work, and it was never going to: the accessibility tree for the export
dialogs had to be guessed because I was writing the script without being able
to watch the app, and every guess was a new failure mode. Two rewrites in, I
threw it away.

MuseScore Studio imports `.gp` and exports PDF, MIDI and audio headlessly,
which makes it the only real option. The cost is that MuseScore re-engraves
the score, so the PDF is not Guitar Pro's layout.

## `*.gp binary` is load-bearing

A `.gp` file is a zip archive. Without `*.gp binary` in `.gitattributes`, git
treats it as text and a conflict injects `<<<<<<<` markers directly into the
archive, corrupting the tab.

With the attribute set, git declines to merge and leaves one whole side in the
working tree, which is recoverable. Verified by forcing a real collision: the
file came out intact, one version, no markers.

## The rebase stage numbers are inverted

This is the one I would most expect to get wrong again.

When a conflict happens during `git rebase`, the stages are the opposite way
round from intuition:

- `:2:` is "ours", which is the branch being rebased **onto**, so the other
  person's version.
- `:3:` is "theirs", which is the commit being **replayed**, so your own work.

`.reprise/resolve` reads `:3:` to rescue the user's side. Reading `:2:` would
have saved the wrong version while producing output that looked entirely
correct: a file appears, named after you, in the right place. You would only
notice when you opened it and found someone else's arrangement.

There is a test asserting the rescued file contains the user's content
specifically so that a future edit cannot flip this unnoticed.

## `git add -A` during a conflicted rebase destroys work

Found by reproducing a same-song collision and then doing the obvious thing: a
bandmate, stuck mid-rebase, double-clicks the launcher again.

`sync` ran `git add -A`, which stages the conflicted file and marks it
resolved using whatever happens to be in the working tree. That is the other
person's version. The user's work was discarded, and the script then reported
"nothing was sent", so the failure message was accurate and the data loss was
silent.

Two guards now: `menu` runs the resolver if it finds a half-finished rebase at
launch, and `sync` refuses to run at all in that state.

## macOS ships bash 3.2

The sandbox I develop in has bash 5.1. `/bin/bash` on macOS is 3.2, from 2007,
and it mis-parses a `case` statement inside `$( )`. It reads the closing
bracket of a case pattern as the end of the command substitution:

```
syntax error near unexpected token `newline'
`    case "$top" in .band|.git'
```

This shipped and crashed on a real Mac, because every test I had run was on
the wrong interpreter. Writing the song-name logic as a plain loop in the main
shell fixed it.

The structural fix is better than the local one: `.reprise/setup` now runs
`bash -n` over every script using the user's own bash and refuses to continue
if any fails. A 3.2-only parse error cannot reach normal use any more, because
it surfaces at install time on the machine that matters. The suite also greps
for the pattern directly.

## A test harness that hid a real bug

`sed -i` and most editors rewrite a file rather than modifying it in place,
which drops the executable bit. That happened to `.reprise/setup`, and the
first instruction in the setup doc, the very first thing a new user runs,
failed with permission denied.

The harness could not have caught it. It built fixtures by copying files and
then running `chmod +x` on the copies, so it was testing its own `chmod`
rather than what a clone delivers. Any missing bit in the source was invisible
by construction.

Fixtures are now materialised with `git checkout-index`, which writes every
file with the mode recorded in the index, exactly as a clone would. Rewriting
the harness this way immediately caught the same bug again, this time in the
launcher, where an in-place edit had dropped the bit and it had been re-added
without `--chmod=+x`.

The lesson generalises past this project: if a test fixes up the thing it is
meant to be testing, it is testing the fix-up.

## Terminal will not close its own window

A `.command` file opens Terminal, runs, and stops. The window stays, because
Terminal's default profile setting is "Don't close the window" when the shell
exits. So "Press Enter to close this window" was a lie: pressing Enter ended
the read, the script exited, and the window sat there showing
`[Process completed]`.

The fix is to ask Terminal to close the window whose tty matches ours, via
AppleScript, detached and after a short delay so the shell has already exited.
If it ran while the shell was live, Terminal would prompt about terminating a
running process.

It is best-effort. If AppleScript is blocked, the window stays open exactly as
before, which is no worse than the original behaviour.

A second bug surfaced while fixing this: `menu` used `exec` to hand off to
`send`, and `exec` replaces the process, taking the EXIT trap with it. So the
entire send path skipped the pause and the close. Nothing uses `exec` to hand
off any more.

## Conflicts are a product decision, not a technical one

Two people edit the same tab. There is no merge, because the file is binary
and no tool can combine two arrangements.

What is left is a choice about who gets surprised. The options were: refuse
and make them sort it out, ask at conflict time, or pick a winner
automatically and preserve the loser. Asking a question at the moment
something has already gone wrong is the worst of the three for a
non-technical user.

So the band's version becomes the live file, the user's is written beside it
as `song (Their Name 2026-11-19).gp`, a backup branch is left at their
original commit, and the tree is reset to a clean state. The actual merge then
happens in Guitar Pro, which is the only place it can happen, with both
versions open side by side.

Derived assets are never rescued. They are regenerated from whichever score
wins.

## Still unverified

- **Windows.** The launcher and the `cygpath` translation are tested against a
  simulated Git Bash environment. Neither has run on Windows.
- **MuseScore conversion quality.** The suite uses a stub, so it covers the
  workflow and not the output. Whether tempo markings survive onto the staff
  is unchecked.
- **`bcj.py`**, a lossless Guitar Pro to JSON converter, is deliberately not
  in this repo yet. Round-tripping six real tabs produced identical JSON,
  which looks like proof, but reading the GPIF inside showed beats, rhythms
  and notes multiplying roughly eightfold while bars, voices and tracks stayed
  put. The JSON comparison passed because the inflation is stable, so
  re-importing the inflated file produces the same JSON again. That test
  cannot detect this class of bug, and the "lossless" claim does not survive
  contact with it.

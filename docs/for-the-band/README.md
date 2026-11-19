<!--
Template. Copy this into your own tab repo and fill in the placeholders:

  <YOUR GITHUB USERNAME> and <YOUR REPO NAME>   e.g. you and band-tabs
  <CONTACT_NAME>         whoever the band should ask when something breaks

This page is written for someone who has never used git and should never need
to. It deliberately never says commit, branch, stash or rebase.
-->

# Reprise: Start Here

This folder holds our Guitar Pro tabs. When someone edits a tab, the **sheet
music (PDF) and MIDI get built and shared automatically**. Audio to play along
with is one click away.

You don't need to know anything about git, and after setup you never type a
command. You double-click one thing.

> Our repo: **`https://github.com/<YOUR GITHUB USERNAME>/<YOUR REPO NAME>`**

---

# Part 1. Setting up (once per computer)

## Step 1: Install what's needed

**Mac:** install [**MuseScore Studio**](https://musescore.org): download it,
open the download, drag it into your Applications folder. That's all.

**Windows:** install two things:

| | |
|---|---|
| [**Git for Windows**](https://gitforwindows.org) | Click through the installer accepting every default. |
| [**MuseScore Studio**](https://musescore.org) | Download, run, accept the defaults. |

> MuseScore used to be called just "MuseScore" and is now **MuseScore Studio**.
> Same program. Version 4 or newer.
>
> You never need to open MuseScore yourself. It works in the background.

## Step 2: Get the folder onto your computer

**The easy way: have <CONTACT_NAME> do this bit with you.** It takes two minutes and
involves signing in to GitHub, which is the one genuinely fiddly step. Once it's
done on your laptop, it's done forever.

<details>
<summary>Doing it yourself (only if you have to)</summary>

1. You need a GitHub account, and <CONTACT_NAME> needs to have invited you. Check
   your email for the invitation and accept it.
2. Open a terminal:
   - **Mac:** open *Terminal* from Applications → Utilities.
   - **Windows:** right-click your Documents folder → *Git Bash Here*.
3. Type this and press Enter:

   ```
   git clone https://github.com/<YOUR GITHUB USERNAME>/<YOUR REPO NAME>.git
   ```

4. **Mac:** if it asks for a password, your GitHub account password will *not*
   work, because GitHub stopped accepting those. You need a "personal access token"
   instead: on GitHub go to *Settings → Developer settings → Personal access
   tokens → Tokens (classic) → Generate new token*, tick **repo**, generate it,
   and paste that as the password. You only do this once; it gets remembered.

   **Windows:** a browser window opens for you to sign in normally. Nothing else
   to do.

</details>

## Step 3: Double-click `Reprise`

Open the folder you just got and double-click:

- **Mac:** `Reprise (MAC).command`
- **Windows:** `Reprise (WINDOWS).cmd`

The first time, it sets everything up by itself and tells you so. You'll end up
looking at this:

```
================ BAND TABS ================

  1  Send my work to the band   (just press Enter)
  2  Get everyone else's latest
  3  Make audio to play along with
  q  Close
```

If it says MuseScore isn't installed, go back to Step 1 and double-click again.

**That's setup finished.** You will never type a command again.

> **Mac, first time only:** macOS may say the file "cannot be opened because it
> is from an unidentified developer". If so: right-click `Reprise (MAC).command` and choose
> **Open** → **Open**. Just the once.

---

# Part 2. Using it

Everything is the one double-click: **`Reprise`**.

## Before you start playing

Double-click `Reprise`, press **2**. That pulls in everyone else's latest
work. Do this every time you sit down. It takes two seconds and avoids almost
every problem in this document.

## When you've finished working

Double-click `Reprise` and just press **Enter**.

It shows you what changed, then asks two quick questions:

```
Enter a short description for these changes  (press Enter to skip)
> tightened up the chorus

Where were you?  1 = home   2 = studio   (Enter to skip)
> 2
```

Then it saves and sends everything. Your answers become the note attached to
your work, so the band can see what happened:

```
Update Song One, Song Two (studio)

tightened up the chorus

Changed:
  Song One/song-one.gp
  Song Two/song-two.gp
```

You can press Enter through both questions if you can't be bothered. It still
works and still records which songs changed.

## Getting audio to play along with

Double-click `Reprise`, press **3**.

This makes an MP3 next to every tab: **no metronome, no count-in**, just the
music. Takes a moment per song. Run it again after you've pulled new changes.

---

# Part 3. What's in the folder

One folder per song, plus the launcher and this page:

```
Song One/              <- a song
Song Two/
Song Three/
Reprise (MAC).command      <- Mac people double-click this
Reprise (WINDOWS).cmd      <- Windows people double-click this
README.md             <- this page
```

Inside a song folder:

```
song-one.gp   <- the tab, open this in Guitar Pro
song-one.pdf  <- sheet music, arrives automatically
song-one.mid  <- MIDI, arrives automatically
song-one.mp3  <- audio, only on your computer (option 3)
```

PDFs and MIDI arrive on their own when you pull. MP3s don't, because
they're large, so everyone makes their own.


If a song is ever missing its PDF or MIDI, the next time anyone sends work it
gets built quietly in the background. You don't have to notice or do anything.

There's also a hidden `.band` folder holding the machinery. Finder and File
Explorer don't show it. Ignore it.

---

# Part 4. When something looks wrong

**Nothing here can lose your work.** Your Guitar Pro files are on your own
computer no matter what any of this says.

### "Commit stopped" / "failed to convert"

A tab couldn't be turned into sheet music, so nothing was sent. **Usually the
file is still open in Guitar Pro.** Save it, close it in Guitar Pro, and
double-click `Reprise` again.

### "MuseScore is not installed"

Your work still sends fine. You just won't build PDFs on this machine. Install
MuseScore Studio (Step 1) and double-click again. Nothing is broken for anyone
else.

### "Git is not installed"

**Windows:** install Git for Windows (Step 1).
**Mac:** open Terminal, type `git`, press Enter. macOS offers to install the
developer tools. Click **Install**, wait, then double-click `Reprise` again.

### A red "STOP, SCREENSHOT THIS WINDOW" screen

This appears when you pressed **2** to get the latest, and it turned out you and
someone else had both changed the same song. Your work could not be slotted back
in automatically.

**Nothing is lost.** Your version is saved safely and <CONTACT_NAME> can get it back.
Do exactly what the screen says: take a screenshot of the whole window, send it
to her, and leave that song alone until she replies.

### "SAME SONG, TWO VERSIONS"

You and someone else edited the same tab. Guitar Pro files can't be merged
automatically, because no program can combine two tabs sensibly, so **both versions
are kept** and you finish the job in Guitar Pro:

```
The band's version is now the live file.

Your version was saved as:
  Song One/song-one (Danny 2026-11-19).gp
```

So in that song's folder you now have two files: `song-one.gp` (what the band
has) and `song-one (Danny 2026-11-19).gp` (what you did). Open both in Guitar
Pro, copy your parts across into `song-one.gp`, delete the saved copy, then
double-click `Reprise` and press Enter to send the result.

Nothing is lost and nothing is broken. You don't need help with this.

**To avoid it entirely:** press **2** to get the latest *before* you start
playing, and don't both work on the same song at the same time.

### The window flashes and disappears

Something failed before it could print anything. Tell <CONTACT_NAME> what you were
doing; don't keep clicking.

### It asks for a username and password

Your login wasn't remembered. See Step 2. Easiest fixed with <CONTACT_NAME> present.

---

# Part 5. The whole thing, on one line

```
Sitting down?   double-click Reprise -> 2
Done playing?   double-click Reprise -> Enter
Want audio?     double-click Reprise -> 3
```

And one habit worth keeping: **don't both edit the same song at the same time.**
Different songs at once is completely fine.

---

Technical notes are in [.band/TECHNICAL.md](.band/TECHNICAL.md). You don't need
them.

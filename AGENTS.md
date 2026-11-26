# AGENTS.md: working on Wuber

This file is for any coding tool or person starting work on this project. Read it first. It points to longer files instead of copying them.

## What the project is
Wuber is a World of Warcraft addon for WoW Forever (Interface 16001, Lua 5.1) that treats a Warlock summon like a ride: a rider sees which Warlocks are online, requests one with a click, and the driver summons and is paid in the trade window. There is no server; clients talk over a chat channel, whispers and addon messages. The addon is in `Wuber/{Core,Net,Theme,FX,UI,Drive}/`, a fake game and test suite are in `tests/`, check tools in `tools/`, and a separate in-game test addon in `lab/` (Wuber never mentions it).

## How work is organised
- **Issues are the work list.** Work only on an issue you were given.
- **One issue per branch and per pull request.** Branch names: `claude/<n>`, `author/<topic>` (n = the issue number). Commit messages start with `#<issue>`.
- **Work in your own git worktree**, not in the main checkout.
- Several contributors and tools may work in this repository at the same time, each on their own branch. GitHub (issues and pull requests) is the only shared place; nobody starts, drives or reads another contributor's tool.
- Read `ROLES.md` to see which role you play and its limits.
- A finding from a reviewer or another tool becomes a bug only after a failing test proves it.
- Before a pull request run `tools/check.lua`, the whole suite and `tools/layout-check.lua` (commands below) and the scrub check.
- A pull request says what changed, the test that fails before and passes after, and anything not proven.

## Hard rules (never break these)
The full list is in `CODE-RULES.md`. The ones every session needs:
- **No personal data anywhere:** no secrets, keys, e-mail addresses, drive or home-folder paths, account ids, recordings or screenshots with names. Comments say "the author", never a name. Run the scrub check (below) before a pull request.
- **Never change words players see** without the maintainer's approval (label `needs-author`). Never shorten player-facing text to make it fit: make the frame fit, or leave the change open and ask.
- **Lua 5.1 only:** no `goto`, `//`, integer division or bit operators. Locals and upvalue limits: see `CODE-RULES.md` "Hard rules".
- **Secure and hardware-click rules:** chat, cast, `/target` and trade-accept only from a secure macro on a real click. No `SendChatMessage` from addon code. Secure frames only at PLAYER_LOGIN, never changed in combat. Addon messages at most 250 bytes, sent through the existing outboxes.
- **Forbidden calls:** `C_TradeInfo.SetTradeMoney` and everything in `tools/forbidden.lua` (the one list; see `CODE-RULES.md`). Wuber never puts gold in a trade.
- **Never Scale-animate a frame that holds text.**
- **No one-click payment claims.** Only `[Wuber]` drivers appear in the rider's list.
- **Founder status is locked** to EU-PvE and the creator list in `Core/Base.lua`. Do not loosen it.
- **Marketing wording** (price, "free"): see `CODE-RULES.md` "Hard rules".
- **Public names never change** (`W.*`, `UI.*`, `DR.*`, `D.*`, `T.*`, `FX.*`, `W.Map.*`, `WuberAPI.*`).
- **New files need a full game restart**; say so in the pull request.
- **Generated files** (`ARCHITECTURE.md`, seed and flight blocks) are regenerated only by the maintainer or lead after the last merge, never on a feature branch.

## Where things are
| What | Where |
|---|---|
| The addon | `Wuber/` (`Wuber.toc` is the load order) |
| Module map (generated) | `ARCHITECTURE.md`; hand-written intro `tools/architecture-intro.md` |
| Full rules for code, modules, commands and git | `CODE-RULES.md` |
| Roles | `ROLES.md` |
| Working method (build, test, fix round, release) | `.agents/skills/wow-addon-workflow/SKILL.md` |
| Tests and fake game | `tests/`, `tests/run.lua`, `tests/harness.lua` |
| Every limit on what Wuber sends to other players (checked by a test) | `docs/POLITE-SENDING.md` |
| Check tools | `tools/check.lua`, `tools/layout-check.lua`, `tools/quick-check.sh` |
| In-game test addon | `lab/` |
| Scrub check (no personal data) | `scrub-check.py`, `scrub-patterns.public.txt` |
| Lines no test protects (mutation run) | `tools/audit/README.md` |
| Every helper script (surface guard, click ratchet, PR summary, probe import, evidence report) | `tools/README.md` |

To find code: search `ARCHITECTURE.md` for the screen, event or `W.`/`UI.`/`DR.`/`D.` name, then read only that module's file and its test (its `Test:` line). The header block at the top of each file is its contract.

## Build and test
Use Lua 5.1, not LuaJIT (LuaJIT changes table order and random numbers, so tests differ). Run from the repository root or your worktree.
- After every change: `lua5.1 tools/check.lua` (about a second).
- While working: `lua5.1 tests/run.lua "<text>"` (only tests whose name contains the text).
- Tests covering some files: `lua5.1 tools/tests-for.lua [--run] <files>`.
- Speed: `lua5.1 tools/profile-tests.lua --screens` measures every screen change in the fake game (ms, KB, widgets made, SetPoint/SetText calls, OnUpdate left running; `--deep` names the functions, slow); budget tests are in `tests/speed/`.
- UI changes: `lua5.1 tools/layout-check.lua --screen <id>` must say 0 problems; before a pull request run `lua5.1 tools/layout-check.lua`.
- Full suite, once at the end, never per edit: `WUBER_LUA=lua5.1 bash tools/suite-par.sh .` (parallel shards; the default is the machine's core count, at most 16, and at most half while other suites run; 16 is only a default for fast PCs, `bash tools/suite-par.sh . 4` sets it). Serially on any machine: `lua5.1 tests/run.lua`.
- Several checkouts on one PC: set `WUBER_SUITE_LOCK` to one shared folder and up to `WUBER_SUITE_SLOTS` (default 3) full suites run at once and the rest wait in line there (stale after a dead pid or 60 minutes; after 45 minutes it runs anyway). A pass is cached by the git tree hash of the working tree plus the lua5.1 executable hash in `WUBER_SUITE_CACHE` (default `tests/out/cache`): the same code again prints "CACHE HIT: same code already passed" and exits 0; `--fresh` or `--force` runs it anyway, a failing run is never cached. Details: `tools/README.md`.
- Scrub check: `python scrub-check.py . --patterns scrub-patterns.public.txt` must print 0 hits.
- All the checks before a pull request in one command, one summary line: `bash tools/pr-checks.sh <worktree> [--baseline <transcript>] [--private <patterns>]` (`--help`).
- Before a pull request, all of the above in one command: `python tools/pr-ready.py --prefix claude/ --title "#<n> ..." --what ... --why ... --test ... --issue <n>` (checks, scrub, push of your branch, the pull request; `--dry-run` shows what it would do, `--help` for the rest). A long log in 10 lines: `python tools/log-digest.py tests/out/join.log`. More tools: `tools/README.md`.
- A PR body block from the added lines (new API names with surface flags, forbidden names, direct test clicks): `lua5.1 tools/pr-summary.lua <base> <head>`.
- Regenerate the map after a header, TOC or size change: `lua5.1 tools/map.lua --write` (maintainer or lead only, after the last merge).

### Set up on Windows
- **Lua 5.1:** get the official Lua 5.1 binaries (lua.org, or LuaBinaries on SourceForge). Not LuaJIT: it changes table order and random numbers, so tests differ.
- **Point the tools at it:** put `lua5.1.exe` on your PATH, or set `WUBER_LUA` to its full path. The suite reads `WUBER_LUA`; the other commands use whatever you type, so call the same executable.
- **PowerShell example** (current session only):

      $env:WUBER_LUA = "<full path to lua5.1.exe>"
      & $env:WUBER_LUA tools/check.lua

- **`tools/suite-par.sh` needs Git Bash**, not the `bash` that PowerShell finds first (that is WSL's, which cannot see your Windows Lua). From PowerShell:

      & "$env:ProgramFiles\Git\bin\bash.exe" tools/suite-par.sh . 16

- **Shell rule:** never write long nested-quote PowerShell inside a bash command. Put it in a `.ps1` or `.py` file and run that.

## Git
- Work on your own branch in your own worktree.
- One logical change per commit; check.lua and its tests green.
- **No pushes to main, no force pushes, no tags and no releases.** Those are the maintainer's. Releases (zip, CurseForge upload) are made by the maintainer.
- Merging into main happens through a pull request, after the checks pass and the maintainer approves.

## If you are asked to review a pull request
Change no file, push nothing, and post the review with `gh pr review <n> --comment --body "..."`. Never push main, tags or releases.

## What needs the maintainer
- Choosing the work.
- Any wording players see (`needs-author`), art, and decisions about behaviour.
- Anything run in the real game (see the workflow skill), uploads, releases, tags, rule changes.
- If you are stuck on a choice, write it into the issue or the pull request with a recommended answer and carry on with the rest.

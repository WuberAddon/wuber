# CODE-RULES.md: code, test and git rules for Wuber

Read AGENTS.md first; this is the long version it points to.

Wuber is a WoW Forever (Interface 16001, Lua 5.1) addon: a Warlock summon called like a ride. The addon is in `Wuber/{Core,Net,Theme,FX,UI,Drive}/`. You almost never need to read more than one or two modules.

## Find the module for a task

1. Open `ARCHITECTURE.md` (generated). Search it for the screen, event or `W.`/`UI.`/`DR.`/`D.` name. Each module lists its file, purpose, API, dependencies (Uses), late refs (Later), events, test and size.
2. Read only that module's file and its test (the `Test:` line). Its `Uses:` modules are only needed if you change something they export. The header at the top of each file is the contract; keep it true.
3. The intro of `ARCHITECTURE.md` explains layers and how modules talk.

## Hard rules (the game, and the maintainer's decisions)

- **No personal names in shipped files.** Comments say "the author", never a name; `tools/make_release_zip.py` refuses to build otherwise.
- **Read the game before logout, never at PLAYER_LOGOUT** (the game answers wrongly there), and treat saved data as preferences that may load empty: work state out again from the live game.
- **Lua 5.1.** No `goto`, no `//`, no integer division, no bit operators; use `unpack`, `loadstring`, `%` for modulo.
- **Locals: check.lua fails at 170 locals per chunk or function (warns at 150); the game's own limit is 200.** Lots of constants: put them in a table. Upvalues per function: fail at 60.
- **Never Scale-animate a frame that holds text.** Use alpha, translation, or width/height of non-text containers.
- **Secure and hardware-click rules.** Chat, cast, `/target` and trade-accept happen only from a secure macro on a real click (`UI.Secure`, `Drive.Button`). No `SendChatMessage` from addon code. Secure frames are created at PLAYER_LOGIN only and are never shown, hidden, moved or changed in combat. Addon messages are at most 255 bytes (we stay at 250); per-prefix allowance 10 + 1/s, so send through the existing outboxes.
- **`C_TradeInfo.SetTradeMoney` is forbidden.** Wuber never puts gold in a trade; the player does.
- **Forbidden in this client:** `COMBAT_LOG_EVENT_UNFILTERED` (register/unregister), `CombatLogGetCurrentEventInfo`, `C_Club.SendCharacterInvitation` (the "only available to the Blizzard UI" popup) and the frame method `RegisterAllEvents`. check.lua fails on them, in Wuber and the lab addon, and the test harness raises on them. The one list is `tools/forbidden.lua` (it also holds Wuber's own mail rules); add new ones there.
- **No one-click payment claims.** Never word or design anything as if one click pays: the trade needs the players' own steps (Wuber only says what to type).
- **Only `[Wuber]` drivers ever appear** in the rider's list. A line tagged `[Wuber]` is another driver's advert, never a buyer. Nothing else is listed as a driver.
- **Founder status is locked to EU-PvE + `W.CREATOR`** (`Core.Base`: `W.FOUNDER_RULESET`, `W.IsCreator`). Do not loosen it, and do not add another way to become a founder.
- **Marketing wording:** never describe Wuber's price or call Wuber itself free in marketing (store page, descriptions, videos, changelogs). Inside the addon "free" is fine where it reads naturally (a free ride, a free raid summon). check.lua fails on player strings that call Wuber itself free.
- **No user-visible mention of the old summoning addon.** No "ritual" in the TOC, in file or module names, or in any text the player can see. (Internal compatibility code that reads its saved data is the only exception.)
- **Wuber never mentions the lab addon** (the separate in-game test addon in `lab/`), in code, text or docs.
- **New files need a full game restart** (a `/reload` does not find them). Say so in the pull request when a commit adds a file.
- Handlers run under `pcall` (`W.On`, `W.After`, `W.Safe`); API values go through `W.Plain/W.Str/W.Num`. No new globals except frames named `Wuber*`. Unknown numbers are hidden; estimates are labelled "about".
- **Player-facing wording:** short plain British English, every control has a tooltip (`T.Tip`). Never change or shorten words players see without the maintainer's approval (label `needs-author`); make the frame fit the words, not the words fit the frame.

## Module rules

- One handle per file: `local Mod = W.Module("Area.Name", { deps })`; another module's table is only `W.Mod("Area.Name")`, named `<Last>Mod` (e.g. `BaseMod`).
- Bind imports at load only from modules in your dependency list (earlier in the TOC). Call modules that load LATER through their handle at run time, and list them under `Later:`.
- Nothing runs at load except locals, function definitions, table fields, `W.Module`/`W.Mod`, event registrations (`W.On`, `W.Listen`, `W.OnLogin`) and the short allow-list in `tools/check.lua`.
- Never copy `W.db`, `W.Char()`, `W.drivers`, `W.ride`, `W.incoming` or `W.SendStage` into a module-level local. A local that is reassigned and used elsewhere is a hook slot or accessor on `Mod`, never an exported value.
- Do not write into another module's table, except a hook slot its header lists (`sets X.y`).
- **Public names never change.** `W.*`, `UI.*`, `DR.*`, `D.*`, `T.*`, `FX.*`, `W.Map.*`, `WuberAPI.*` keep name and behaviour, even if you move the code. Tests replace many of them at run time: a call made through a table must stay a call through that table (and one through a local stays local).
- A module is 100 to 2,000 lines (check.lua warns over 1,500). Split by job, not by size.

## Add a new module

1. Create `Wuber/<Folder>/<Name>.lua` starting with the header block (copy one: Module, Purpose, API, Internals, Uses, Later, Events, Standalone, Test, From), then `local _, W = ...` and `local Mod = W.Module("<Folder.Name>", { ...deps })`. The module name is the path with dots.
2. Add it to `Wuber/Wuber.toc` after every module it uses (Windows `\` separators), and to `tests/fixtures/toc-order.txt` in the same commit (a test compares the TOC to it). If it adds event handlers, mind handler order.
3. Write its test (the file named by `Test:`, `tests/<area>/<name>_test.lua`) and wire it like the others.
4. Run `tools/check.lua`. The maintainer regenerates `ARCHITECTURE.md` after the last merge (`lua5.1 tools/map.lua --write`).
5. File names are part of the load: a new file means players restart the game once.

## Testing rules

- **Every fix gets a test that fails before and passes after.** Write and run the proof test before touching the addon code.
- A test must assert the promise, not the symptom: never assert a bug as the wanted result.
- The fake game is a guess: a UI fix is not proven until it has been seen in the real game (see the workflow skill).
- Use Lua 5.1 only; LuaJIT changes table order and random numbers.
- Tests that cover shared helpers or the fake game go in first, before the tests that depend on them.
- `lua5.1 tools/map.lua --check` fails if `ARCHITECTURE.md` is stale.
- `node tests/heatmap.test.js`, `tools/build-seeds.js`, `tools/build-flights.js`: the generated seed and flight blocks in `Core/Base.lua` and `Core/Flights.lua` are rewritten by these; do not hand-edit between their markers.
- The behaviour transcript (`tests/lib/transcript.lua`, `--compare-transcript`) is optional: the baseline file is not stored in this repository, so a comparison only runs where one has been made locally. A restructure must leave a transcript byte-identical.

## Commands

Run from the repository root (or your worktree). `lua5.1` is Lua 5.1.
- `lua5.1 tools/check.lua [--warn]`: parse, locals, upvalues, globals, load-time calls, TOC vs `W.Module` deps, sizes. Fast. Run after every change. A new global read is usually a lost local.
- `lua5.1 tests/run.lua "<text>"`: only tests whose name contains the text.
- `lua5.1 tests/run.lua`: every test (serial).
- `WUBER_LUA=lua5.1 bash tools/suite-par.sh . 16`: the full suite in 16 parallel shards, same counts and failures as a serial run. Run it once at the end, never per edit. Logs: `tests/out/shard-K.log`.
- `lua5.1 tools/layout-check.lua [--files f...]`: screens, clipping and covered buttons.
- `lua5.1 tools/map.lua --write`: regenerate `ARCHITECTURE.md` (maintainer or lead only, after the last merge).
- `python scrub-check.py . --patterns scrub-patterns.public.txt`: no personal data in the tree.

## Git

- Work on a branch in your own worktree (`claude/<n>`, `google/<n>`, `author/<topic>`), never on main.
- Commit messages start with `#<issue>`. One logical change per commit, check.lua green, relevant tests green.
- **Generated files** (`ARCHITECTURE.md`, seed and flight blocks): a feature branch never regenerates or commits them.
- No pushes to main, no force pushes, no tags and no releases. Those are the maintainer's.
- A release zip is built by the maintainer: `python tools/make_release_zip.py --version <ver> HEAD Wuber-<ver>.zip`.

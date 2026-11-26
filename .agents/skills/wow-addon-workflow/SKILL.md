---
name: "wow-addon-workflow"
description: "Read before building, fixing, testing or reviewing the Wuber addon (or any WoW Forever addon): the build/test/check commands, how a fix round is run by roles, how to prove a bug with a failing test, what only the real game can show, and the release steps that belong to the maintainer."
---

# WoW addon workflow (learned building Wuber)

Roles are named, not tools: lead, builder, test runner, reviewer. See ROLES.md. Rules for code are in CODE-RULES.md; this file is the method.

## 0. Before touching the addon
- Read AGENTS.md (CLAUDE.md is only a pointer to it) and CODE-RULES.md.
- Work on an issue you were given, on your own branch (`claude/<n>`, `google/<n>`, `author/<topic>`) in your own git worktree.
- Never push to main, tag or release; never upload; never put personal data in the repository.
- Never shorten or reword player-facing text to make it fit; wording changes need the maintainer (label `needs-author`).
- WoW Forever: Interface 16001, **Lua 5.1** client. The author may run several game windows on separate accounts (separate SavedVariables) at the same time, so anything automatic must not fire once per window.

## 1. Build, test, check
- Lua 5.1 only. LuaJIT is not a substitute (different table order and random numbers).
- After every change: `lua5.1 tools/check.lua`.
- While working: `lua5.1 tests/run.lua "<text>"`; `lua5.1 tools/tests-for.lua [--run] <files>` finds the tests for changed files.
- UI changes: `lua5.1 tools/layout-check.lua --screen <id>` (0 problems), and the full `lua5.1 tools/layout-check.lua` before a pull request.
- Once at the end: the whole suite, `WUBER_LUA=lua5.1 bash tools/suite-par.sh . 16`. A final count only counts on a fresh clone of the final commit (a leftover `tests/out` from an earlier run can hide order-dependent failures).
- Scrub check: `python scrub-check.py . --patterns scrub-patterns.public.txt` must print 0 hits.

## 2. Addon hard rules
- Lua 5.1 only; at most 200 locals per function/chunk (aim for 170 or fewer), at most 60 upvalues.
- Never Scale-animate a frame holding text (alpha, translation, size only).
- Protected actions (chat, cast, target, trade accept, invites) only from a secure button on a real hardware click. Secure frames are created at login, never shown, moved or changed in combat. Never `C_TradeInfo.SetTradeMoney`.
- Hook with `hooksecurefunc` / `HookScript`; never replace Blizzard globals; do not insert into shared Blizzard tables or dropdowns (taint).
- Addon messages at most 250 bytes through one throttled outbox; trust only the event's sender, never a name in the payload.
- Handlers run under pcall. New files need a full game restart; a /reload is enough otherwise (say which in the pull request).
- Forbidden in this client (not just protected; any call pops "blocked from an action only available to the Blizzard UI"): registering COMBAT_LOG_EVENT_UNFILTERED, CombatLogGetCurrentEventInfo, C_Club.SendCharacterInvitation, RegisterAllEvents. The list is `tools/forbidden.lua`; add new ones there.

## 3. Offline testing: the fake game
- `tests/harness.lua` is a Lua 5.1 fake of the WoW API (frames, regions, units, a manual clock, events, addon messages, chat, trades, saved variables) that runs every module headless. It raises on forbidden calls like the client does; a test that leaves a violation fails, even inside pcall.
- **Every fix gets a test that fails before and passes after.** Use two-window scenarios for anything networked or multibox-related.
- **Prove a bug first.** A finding (from a reviewer, a tool or a player) becomes a bug only when a test that fails on today's code shows it. Write and run the proof test before touching the addon code, and keep the test with the fix. A test must assert the promise, not the symptom.
- Layout: `tools/layout-check.lua` checks every screen for clipped rows, unintended "..." and buttons covered by another frame. Look at the result before calling a UI change done.
- **The fake game is a guess.** A feature can pass every offline test and fail in the first minute in the real game (a back arrow and a drag fix once passed every test and failed in game). Never call a UI fix done before the maintainer has seen it work in game.

## 4. A fix round, by role
1. **Lead** reads the issue(s), splits the work into groups of about 10 minutes each (one bug, or several small bugs in the same file; no two groups on the same addon file), writes down for each group its files and its tests, and states the hard rules once. A change to a shared helper or the fake game is an early group, merged first.
2. **Builder** takes one group in its own worktree: proof test first (fails), then the fix (passes), `tools/check.lua` and the group's tests green before hand-back. Never use `git stash` in a worktree: the stash is shared by all worktrees. The lead takes a group itself only after the builder failed once, or when the triage wrote down why it is hard.
3. **Test runner** runs the checks the moment a group reports (check.lua, the group's tests), and at the end the whole suite and the layout check. It reports only the short result (pass/fail counts, the failing test and its key assertion) and never designs a fix.
4. **Reviewer**, someone who did not build the change, reads the diff (code, screens, a new-player read, security) and lists findings, each marked "proven" (with the failing test) or "not proven / to prove it:". Nobody marks their own homework.
5. **Lead** judges real failures, merges group by group with a quick check after each merge, then the finish: one full suite run, one layout run, the regenerated map if headers changed, and a short summary (what changed, what is proven, what is not).
Keep the whole round short: about 20 to 45 minutes, not hours.

## 5. In-game proof (lab/ and the maintainer)
- `lab/` is a separate dev-only addon (the main addon never mentions it): login checks, a guided test run with Yes/No prompts only where a human must judge, a passive mode that checks real play, and a photo tour of every screen with demo data (never sent, never saved).
- Only the maintainer runs it in the real game. Give a short numbered list of only the steps that are needed this time, each with the question that tests the fix it is there for. After the run the maintainer logs out and reports; read the saved variables and screenshots for the result.
- Anything automatic (auto-whispers, sync) must not fire once per game window: only one window acts per target, and cooldowns persist in SavedVariables so a /reload does not reset them. Sync only between windows the player marks as their own accounts.

## 6. Versions and release (the maintainer's)
- Internal builds use a "-dev" version when the addon announces versions to others; the real number is set only in the build that goes to players. Never reuse a released number.
- A release needs: the whole suite green, check.lua with 0 failures, the map regenerated, a changelog that covers everything since the last version players got, a security read of the diff, and a test of that exact build in game.
- The maintainer builds the zip (`tools/make_release_zip.py`, which stamps the version and refuses to build if a personal name is found), uploads it to CurseForge, and makes any tag or GitHub release. Contributors and tools never publish, upload, tag or push to main.
- CurseForge page HTML is a whitelist (div/section/img/iframe, limited inline styles); images go in the project's Media tab.

## 7. Other addons
For another WoW Forever addon with no tests, write its promises from its README and changelog first, then test those in a fake game like this one. Copy and adapt the harness and the check scripts; do not reinvent them.

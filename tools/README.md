# tools/

Check and helper tools for working on Wuber. Run them from the repository root or your worktree. Lua tools need Lua 5.1
(not LuaJIT); Python tools need Python 3. Every tool prints its own usage with `--help` or in its header comment.

## Speed
- `lua5.1 tools/perf-audit.lua [--role driver|rider|control] [--minutes N] [--profile|--funcs] [--out path]`: an hour of simulated play (a busy driver with six riders, or a rider with a booking; the map open; 200 public chat lines a minute) in the fake game. Writes Lua KB after login and every 5 minutes, garbage a minute, what each module's tables hold, load KB per file, every timer and OnUpdate (how often, ms a call), the cost of one chat line, and with `--funcs` the CPU by the addon functions up the stack. The fake game's own work is in the numbers: compare runs (a `control` run is the fake alone), do not quote them as game ms.

## For a pull request
- `python tools/pr-ready.py --prefix claude/|google/ --title ... --what ... --why ... --test ... [--issue n] [--quick] [--private-list <file>] [--dry-run]`:
  from your branch in your own worktree: check.lua, the whole suite in 16 shards (`--quick`: only the tests for the changed
  files), the layout check when a file under `Wuber/UI/` changed, the scrub check of the commit and the pull request text
  (scrub rules and public list from origin/main, plus the private list when given), then push the checked commit to its
  branch (never main, never force) and open the pull request from the template. Stops at the first failure with a short
  summary; `--dry-run` runs nothing. Tests: `python tools/test_pr_ready.py`.
- `python tools/log-digest.py <log>` (or `... | python tools/log-digest.py`): a long suite, quick-check, check.lua,
  layout, scrub or Python test log in about 10 lines: counts, the failing tests grouped by first error, the result lines.
  Exit 1 when it found a failure. Tests: `python tools/test_log_digest.py`.

## Checks
One-line index of the helper scripts here (the full list with their flags is in each file's header).

- `check.lua`: the static checks (syntax, globals, locals/upvalues, forbidden calls from `forbidden.lua`, bytecode), about a second. Run after every change.
- `surface/static-surface.lua`: the static API surface pass (`--help`): reads every Lua file of the TOCs with its own lexer (no luac here) and reports P (protected / ReloadUI shapes), B4 (a secret answer compared before issecretvalue), U (undocumented); needs no test to run the code, about 1 s for the whole addon. Judged by `tests/surface/static_surface_test.lua`.
- `surface/gen-surface.py`: builds `tests/surface/apisurface.lua` (the API surface the opt-in guard judges by) from the client's interface source; regenerate on every client patch (`--help`, `surface/README.md`).
- `quick-check.sh` / `quick-check.ps1`: checks only what the change touches. Its `surface` group runs those tests again with the API surface guard on (`--no-surface` skips it); it also runs the click ratchet (`--no-ratchet` skips it).
- `click-ratchet.lua [--check|--update|--list]`: counts the test clicks that skip the hit test (GetScript OnClick, :Click, :click) per file against `tests/click-ratchet.txt`; a rise or a new file fails unless the line says `-- direct-click: <reason>`; click with `Client:clickOn`. Tests: `tests/fakegame/click_ratchet_test.lua`.
- `pr-summary.lua <base> <head>`: a markdown block for a PR body from the added Lua lines: new API names (with apisurface flags when `tests/surface/apisurface.lua` exists), new uses of `forbidden.lua` names, new direct test clicks. Tests: `tests/fakegame/pr_summary_test.lua`.
  Full form: also the static pass (`surface/static-surface.lua`) on changed lines, the guard log on changed lines (`--guard-log <WUBER_SURFACE_LOG file>`), the evidence ledger rules the changed lines lean on with their evidence level (`--hits <file>` or `--ledger-run`; a rule's `names` field links a name such as GetTexture to its rule) and the client-facts staleness line (`evidence-report.lua --check-build`). Only P, a measured-blocked name (`forbidden.lua`) and a peephole hit (B4, guard K) gate (`--gate` exits 1); the rest informs. It always says "Not checked: taint propagation". Proof on the historical bug commits: `tests/fakegame/pr_summary_full_test.lua` (diffs recorded under `tests/fixtures/old/pr_summary/`).
- `suite-par.sh <tree> [N] [filter] [flags]`: the full suite over parallel shards, joined into one result. See below.
- `suite-guard.sh`: helpers sourced by `suite-par.sh` (machine-wide lock, result cache, shard count).
- `suite-win.sh`, `suite.sh`: the serial runs (`suite.sh` queues through the same portable lock as `suite-par.sh`; no `flock` needed).
- `layout-check.lua`: the layout sweep of the screens (`--probe <fixture>` lets a probe fixture's measured "was it cut" answers decide for the strings it measured and prints "N of M current strings unmeasured"; `--text-rule flat` is the first draft's flat 6% (a proof only); `--collect-labels <file>` lists every drawn string with its font, size and box; `--comfort` adds the comfort guards: the colour-blind check of the state colours; `--config WxH@scale,uiN` judges at the game's measured text widths).
- `rec/probe-labels.lua`: turns that list into the probe's `P.LABELS` block (`data`) or a labelled DERIVED fixture (`derive`); see its header.
- `tests-for.lua`: which tests cover the given files (`--run` runs them).
- `rec/probe-import.lua`: turns the saved data of the developer-only probe addon (one session in the real game) into `tests/fixtures/probe/game-probe-<id>.lua`; `tests/harness.lua` then loads that file in every run (file ids, text widths, key rules, secrets). Until one exists only the synthetic stand-in `SYNTHETIC-standin.lua` is there, used by `tests/rec/probe_test.lua`. Same read-only safety as `rec/import.lua`. It also names a probe the run started but never finished (the write-ahead markers of WuberProbe 1.1).
- `rec/probe-diff.lua old new` (`--help`): a short fact diff of two probe fixtures: file ids changed, width change per font and size, events no longer valid, accessors newly secret, hit cells that changed winner. Tests: `tests/rec/probe_wizard_test.lua`.
- `rec/taint-list.lua [--out <TaintList.lua>]` (`--help`): the Blizzard globals and frame fields Wuber touches, written as the data file of the developer-only probe's taint sweep. `rec/taint-compare.lua --fixture <probe fixture>` (`--help`): the sweep's answers next to `tests/fakegame/taint-allow.lua` (a tainted game value nobody listed, an allow entry that measured secure, one never measured; a simulator fixture says NOT MEASURED). The probe's propagation rows also teach the fake game its protection rule (`H.protectRule`, `tests/lib/probe_learn.lua`). Tests: `tests/rec/probe_taint_test.lua`, `tests/buttons/combat_screen_clean_test.lua`.
- `evidence-report.lua`: the evidence ledger report (`--help`): the fake game's rules (`tests/fixtures/client/rules.lua`) by evidence (measured needs a probe fixture with source "game"; sim and synthetic never count), the tests that lean on each (`--run "<filter>"` or `--hits <file>`, from the harness's `H.rule` counters), "N tests lean on guessed rules", and `--check-build` (newest game fixture build against the newest WuberProbe.lua build: STALE or OK).
- `map.lua`: writes or checks `ARCHITECTURE.md` (maintainer or lead only, after the last merge).

## suite-par.sh: lock, cache and shard count

| Setting | Meaning |
|---|---|
| `WUBER_SUITE_LOCK=<folder>` | Up to `WUBER_SUITE_SLOTS` (default 3) full suites run at once; the others wait in line in this folder (one for the whole PC, shared by every worktree). Each holder owns a file `held.<pid>`; the old single `held` file counts as one taken slot. It prints `waiting for suite lock held by <pid>`. A lock is stale when its pid is dead (`kill -0`, works from PowerShell and Git Bash) or it is older than 60 minutes; it is then taken over, the old file kept as `stale.<pid>.<name>` (not `held.*`, so it never counts as a holder). After 45 minutes (`WUBER_SUITE_WAIT_MAX`, seconds) the run goes ahead anyway. Unset: no queue (one run per tree only, as before). |
| `WUBER_SUITE_CACHE=<folder>` | A pass is saved as `<key>.pass`. The key is the git tree hash of the whole working tree (tracked and untracked, not `tests/out`), the sha256 of the lua5.1 executable and the run.lua arguments. The same key again prints `CACHE HIT: same code already passed (<time>)` and exits 0 at once, no test started. Never used for `--fresh`, `--force` (or `WUBER_SUITE_FRESH=1`), `--compare-transcript`, `--update-transcript`. Default `tests/out/cache`. A failing run is never cached. |
| `--force` | Run even when the same code already passed. |
| shard count | Not given: the core count (`nproc`, else `NUMBER_OF_PROCESSORS`, `WUBER_CORES` overrides), at most 16; at most half of it while the lock folder shows other suites queued or running. `WUBER_SHARDS` or the N argument wins. 16 is only a default for fast PCs; `lua5.1 tests/run.lua` runs serially anywhere. |

Tests: `tests/lessons/l26_suite_lock_test.lua` (fake Lua, fake `nproc`, fake lock folder, cache hit and miss, stale lock, wait cap).

# The bug hunt (tests/hunt, tests/promises, tools/hunt)

The normal suite checks the situations somebody thought of. The hunt checks what Wuber PROMISES the player in
thousands of situations nobody thought of, and hands back real bugs, each with the exact situation that breaks it.
It only FINDS bugs: nothing here ever changes addon code (`Wuber/`). It is not part of the normal suite.

## Files and who owns them (while the hunt is being built, several agents write at once: edit only your own)

| File | What | Owner |
|---|---|---|
| tests/hunt/lib.lua | the core: rng, dial and promise registries, build, checks, shrink, repro | CORE |
| tests/hunt/situations.lua | loads the dial files in a fixed order, gives the pairwise and random sets | CORE |
| tests/hunt/dials/session.lua | how the session began: first run, login, /reload | CORE |
| tests/hunt/dials/saved.lua + tests/hunt/fixtures/saved/*.lua | saved data: fresh, each real character (anonymised) | FIXTURES |
| tests/hunt/dials/role.lua, ride.lua, net.lua | role; the ride's state; the network | RIDE |
| tests/hunt/dials/phone.lua, world.lua, settings.lua, time.lua | the phone; the world; switches; day/month | WORLD |
| tests/hunt/actions.lua | player actions for the long sessions (random walks) | UNIVERSAL |
| tests/promises/universal.lua | the universal promises | UNIVERSAL |
| tests/promises/<area>.lua | each feature's promises | one per area |
| tools/hunt/sweep.lua, sweep.ps1 | the sweep (one process; the wrapper runs up to 8) | CORE |
| tests/hunt/repro/<id>.lua, tests/hunt/KNOWN.md | generated: one failing test per found failure | the sweep |

## A dial file:  `return function(Hunt) Hunt.dial{ ... } end`

```lua
Hunt.dial{
  name = "phone",                       -- unique; a situation is { [dialName] = valueId }, a missing dial = its default
  about = "what the phone looks like when the check starts",
  phase = 80,                           -- order of the hooks across dials, low first (table below)
  default = "closed",
  valid = function(sit) return true end, -- optional: sit is the FULL situation (every dial); return false, "why" when a player
                                        -- could never be in it (a triple that excludes cannot say). Never generated, never shrunk to
  values = {
    { id = "closed" },
    { id = "drive", about = "open on the Drive tab",
      pre = function(ctx) end,          -- optional. No world yet. May edit ctx.worldOpts, ctx.clientOpts, ctx.saved
      world = function(ctx) end,        -- optional. ctx.w exists, my client does not: add other players here
      apply = function(ctx) end,        -- optional. My client has logged in (ctx.me, ctx.W)
      excludes = { role = { "rider" } } -- optional. Dial values this one cannot exist with (never generated together)
    },
  },
}
```

Phases: 10 saved data, 15 time, 20 settings, 30 role, 40 session, 50 network, 60 world, 70 ride, 80 phone, 90 late
things (combat). The core creates the world after every `pre`, runs every `world`, logs my client in as the session
dial says, then runs every `apply`.

A hook that cannot build its state calls `ctx:cannot("why")`: the situation is skipped and counted, never a bug.
A hook must reach its state the way a player would where it can (real clicks, real addon messages between two
windows), and may poke saved data or the fake game only for things a player cannot do in a test (the date, a
flight master). It records what promises need in `ctx.facts` (for example `ctx.facts.flightSecs = 197`).

## ctx (one built situation)

- `ctx.sit` the dial values; `ctx.seed`; `ctx.rng` (`:int(n)` 1..n, `:pick(list)`, `:chance(p)`); never math.random.
- `ctx.worldOpts`, `ctx.clientOpts`, `ctx.saved` (what `pre` edits; `ctx.saved` is the client's `saved` option).
- `ctx.w` the harness world, `ctx.me` my client, `ctx.W` its Wuber namespace (ALWAYS read these from ctx: a
  /reload replaces both), `ctx.name` my character, `ctx.peers` other players by role (`ctx.peers.driver`, ...).
- `ctx.facts` a table the dials fill for the promises. `ctx.H` the harness.
- `ctx:advance(seconds)`, `ctx:reload()` (a /reload: logout, the saved data, login with PLAYER_ENTERING_WORLD(false, true)),
  `ctx:relog()` (a real logout and login), `ctx:mod("UI.Tips")` (W.Mod, nil when missing),
  `ctx:visible(region)`, `ctx:texts()` (every visible text of Wuber's, top to bottom),
  `ctx:fail(seen, detail)` (a promise is broken: `seen` is ONE plain sentence saying what the player would see),
  `ctx:cannot(why)`.
- `ctx.log`: the steps taken so far (the build's and a walk's), for the repro file.

## A promise file:  `return function(Hunt) Hunt.promise{ ... } end`

```lua
Hunt.promise{
  id = "tips.first_open",               -- area.name, never renamed (repro files and BUGS lines use it)
  area = "Tips",
  text = "The first time you open Wuber after logging in, you see one tip.",   -- one plain sentence a player could check
  source = "BRIEF25 T1",                -- or "inferred"
  kind = "scenario",                    -- "scenario": the check acts (clicks, waits); it gets a fresh build of the situation
                                        -- "always": the check only LOOKS (no click, no wait, no write); it runs after every
                                        --           build and after every step of a long session
  needs = { phone = "closed" },         -- optional: dial values the promise forces (the sweep overrides those dials)
  when = function(sit) return sit.tips ~= "off" and sit.ride == "none" end,  -- optional: where it applies; dial values only
  check = function(ctx)
    ...
    if not card then ctx:fail("You open Wuber after logging in and no tip card shows.") end
  end,
}
```

A check that throws anything other than `ctx:fail` is a BROKEN CHECK (reported apart, never as a bug). A build that
throws is CANNOT BUILD (reported apart). Lua errors raised inside the addon are caught by the universal promise.

## An action (tests/hunt/actions.lua), for the long sessions

```lua
Hunt.action{ id = "click", weight = 10,
  pick = function(ctx, rng) return args or nil end,   -- plain data (strings, numbers): what to do now, or nil if not possible
  run = function(ctx, args) end,                      -- do it; returns one plain line for the log
}
```
A walk is seed + steps; every step is logged as { id, args }, so a failure can be replayed and shrunk step by step.

## Running

- `lua5.1 tools/hunt/sweep.lua --list` the dials, values and promises.
- `lua5.1 tools/hunt/sweep.lua --mode pairs|random|walk [--seed N] [--n N] [--steps N] [--promise id-prefix]
  [--shard K/N] [--addon <folder with another Wuber>] [--out dir] [--no-shrink]`
- `powershell -File tools/hunt/sweep.ps1` the normal sweep on up to 8 processes (20 minutes or less), joined.
- Output: tests/out/hunt/<run>/ (results, FAILURES.md); repro tests in tests/hunt/repro/<id>.lua, each runnable
  alone from the repo root (`lua5.1 tests/hunt/repro/<id>.lua`: exit 1 and the plain line while the bug exists).
- Everything is seeded: the same seed gives the same situations and the same walk. A failure prints its seed.

## Additions (CORE)

Filled-in details of the contract above (nothing renamed):

- A dial value may also have `login = function(ctx)`: only the session dial uses it (it calls `ctx:login()` and waits).
  Without one, the core logs in plainly. `ctx:login(extra)` makes my client from `ctx.name`, `ctx.clientOpts` (+ extra)
  and `ctx.saved`, which is copied as plain data first (a fixture may hand over a shared table safely).
- Value ids: any string without spaces, commas or `=`. A situation string is `dial=value,dial=value` (only the
  non-default dials; `default` when none). An unknown dial or value in `--one` is an error, not a skip.
- `ctx:na(why)`: the promise does not apply to the state the build reached (counted as na, never a bug).
  `ctx:note(line)` adds a line to `ctx.log` (entries are `{ kind, text }` tables; plain strings are fine too).
- A promise may have `pre = function(ctx)`: run after every dial's `pre`, before the world (a promise's own stand-in
  for a dial that is not there yet). Prefer `needs` and `when`.
- Facts the session dial sets: `ctx.facts.session` ("first", "login", "reload"), `firstRun`, `reloaded`.
- Statuses: a check that ends normally passes; `ctx:fail` is a fail (even if the check raised afterwards);
  `ctx:cannot` in a check or a hook, or any error while building, is cannot-build; any other error in a check is
  broken-check; `ctx:na` or a `when`/`needs`/`excludes` miss is na. A check that runs over 240 s (CPU) is stopped.
- After every check (scenario or always) every kind = "always" promise that applies to the situation runs on the final
  state; its failure is recorded against it, "after <scenario id>", and shrunk (first without the scenario).
- A failure is re-run before it is shrunk; one that does not fail again is reported NOT REPEATABLE and gets no repro.
  Each (promise, plain line) is shrunk once per process; repeats are counted. A run with `--addon` writes its repro
  files and KNOWN.md into its own out folder (`tests/out/hunt/<run>/repro`), never into tests/hunt/repro.

- `valid(fullSituation) -> ok, why` (a dial field, any dial's): `Hunt.compatible` asks every dial's valid as well as the
  excludes. situations.lua never makes a situation one rejects (pairwise set, random samples, walk starts), the shrinker
  skips any step that would make one, and `--one` with one prints `na (cannot exist: why)` and exits 0 (also with --mode
  walk). A valid that raises counts as "cannot exist" and is noted in `--list`. A state a check cannot reach is
  `ctx:na` / `ctx:cannot`, never a pass.
- The set cache: a pairwise set is written to `tests/out/hunt/cache/<hash>.lua` once made in full and read back when the
  key matches. The key covers the contents of every file under tests/hunt/dials and tests/hunt/fixtures, of lib.lua and
  situations.lua, each dial's name, default, values, excludes and whether it has valid, the seed and, for a promise with
  needs or when, its id, needs and the contents of its file (a promise with neither shares one set). Editing any of them
  makes new files (old ones are just not read; delete the folder any time). Random sets are not cached.
  `--no-cache` ignores it; `--make-sets` only makes this shard's sets and prints the time; every sweep prints
  "set cache: N read, M made". Measured (12 bird. promises, 1,474 situations): 30 s cold, 0.1 s warm.
- Walks keep going after a finding: each distinct finding (promise + plain line, numbers blanked) is recorded once with
  the steps up to it, and its repeats are muted for the rest of that walk. A start that cannot build is skipped (the next
  is tried, counted). `--steps A-B` draws each walk's length from the range by its seed; `-Deep` (sweep.ps1) is walk
  mode, 6 walks per process of 500-2000 steps, 60 minutes. `--one "sit" --mode walk` walks from one fixed start.
- Shards never shrink. Each writes `results.K-of-N.txt` (status, promise, situation, seed, seconds, note) and
  `raw.K-of-N.lua` (every raw failure). `--plan N` groups the raw failures by promise + plain line (groups.lua),
  `--shrink-part K/M` shrinks every M-th group (`--deadline-seconds` bounds it), `--join N` writes FAILURES.md (ids are
  the repro file ids), failures.tsv, cannot.tsv (cannot-build, grouped by reason), broken.tsv (broken checks) and
  summary.txt; with no plan the join shrinks each group once itself. `--skip id,id` leaves promises out (an id ending in
  "." is a prefix); `--deadline-seconds W` starts nothing after W s wall (a running check is stopped 20 s later).
- `--resume <earlier out dir>` (sweep.ps1 `-Resume`): pairs/random only; a (promise, situation) that sweep passed is
  written as a `resumed` pass line and not run, if the promise's file, the dials, lib.lua, situations.lua and Wuber are
  unchanged (each results file carries `# psig <promise> <hash>`). Failed, broken and cannot-build ones run again.
  `-Seed N` gives other situations everywhere (pairwise sets, random ones, walks, the checks' own choices): the easy way to
  reach new ground; the out folder name carries the seed.
- `--one` without `--out` writes to `tests/out/hunt/one-<time>-<id>/` (never shared with another run).

### How to try your dial or promise (from the repo root, Git Bash; `lua5.1` is Lua 5.1 on the PATH, or $LUA)

```
export WUBER_LAB_DIR=lab/WuberLab
lua5.1 tools/hunt/sweep.lua --list                     # your dial/promise is listed; LOAD ERROR lines say why not
lua5.1 tools/hunt/sweep.lua --one "phone=drive_direct" --promise tips.first_open --verbose
#   one situation (other dials at their defaults), your promise, then every always-promise; --verbose prints
#   the build log, the detail and what is on screen. Exit 1 when it fails. Add --shrink to shrink it and
#   write tests/hunt/repro/<id>.lua.
lua5.1 tools/hunt/sweep.lua --one "session=reload" --promise universal.    # every promise starting with it
lua5.1 tools/hunt/sweep.lua --mode pairs --promise tips. --no-shrink       # the pairwise set of your promises
lua5.1 tools/hunt/sweep.lua --mode random --n 20 --seed 3 --promise bird.  # 20 random situations each
lua5.1 tools/hunt/sweep.lua --mode walk --n 3 --steps 20 --verbose         # 3 long sessions of actions
lua5.1 tools/hunt/sweep.lua --one "..." --addon ../other-checkout/Wuber      # the same against another Wuber
lua5.1 tools/hunt/sweep.lua --mode pairs --promise mine. --repro-dir tests/out/hunt-scratch/<you>/repro
#   while trying things: repro files (and their KNOWN.md) go to your scratch folder, not tests/hunt/repro
```

More sweep.lua options: `--total-seconds T` (T split evenly between the promises: pairwise first, then random
situations until each promise's share is used; what was dropped is printed), `--budget-seconds S` (per promise),
`--shrink-seconds S` (shrinking time per process; default a quarter of the budget, else 900), `--max-shrinks N`
(different failures shrunk per promise, default 6). `powershell -File tools/hunt/sweep.ps1 [-Procs 8] [-Mode pairs]
[-Seed 1] [-N n] [-Steps 30] [-Addon dir] [-Promise prefix] [-Out dir] [-Minutes 20] [-BudgetSeconds s] [-NoShrink]`
runs the shards, joins them and prints the summary and the time estimate.

In a script: `local Hunt = dofile("tests/hunt/lib.lua").init()`, then `Hunt.runPromise("tips.first_open",
{ session = "reload" }, seed)` returns `{ status, seen, detail, sit, seed, secs, always = {...} }`;
`Hunt.build(Hunt.full(sit), seed)` gives a ctx to poke at (call `Hunt.release()` after). Results of a sweep:
tests/out/hunt/<run>/results.K-of-N.txt (status, promise, situation, seed, seconds, note), FAILURES.md, summary.txt.

- tests/hunt/known-elsewhere.tsv: three tab-separated columns (promise id, the other job's id such as HUNT-13 or AUD-17, one-line why) and an optional fourth (the plain line the row covers).
  Add a row when a promise fails for a bug that is already listed under another promise's test; the sweep counts its findings as KNOWN (no repro, not shrunk).
  With a line only that line is known; without one the whole promise is, and FAILURES.md marks it "whole promise, line not checked".
  A finding of a promise that has a repro but another line is NEW; FAILURES.md says "same promise as <repro id> (other line)".
- A judged real bug goes onto the list like this: its shrunk repro is copied into tests/hunt/repro, a line is added to the shared bug list,
  `lua5.1 tools/hunt/sweep.lua --known-md` regenerates KNOWN.md and `lua5.1 tools/hunt/promises_md.lua` regenerates PROMISES.md.
- The "window saved off-screen" value was removed from the pos dial: the fake game cannot clamp a window back onto the screen (see FAKE-GAPS.md).

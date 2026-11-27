# Guard tests

A **guard test** is a unit or integration test that fails when a specific line in `Wuber/` is broken (mutated) and passes when the line is intact.

## Finding lines nobody protects

The mutation pipeline under `tools/audit/` (see `tools/audit/README.md`) finds lines that the existing test suite does not notice when broken:

1. `tools/audit/gen_candidates.py` picks one-line mutation sites in `Wuber/` (flip a comparison, return `nil`, negate an `if`, `nil` a local, drop a statement, swap `and`/`or`).
2. `tools/audit/instrument_fast.py` inserts hit markers in a scratch copy so a single suite run records which tests execute each site.
3. `tools/audit/run_mutants_fast.py` runs each site's covering tests against the broken line; any `uncovered` or `survived` row is a line no test protects.

## Writing a guard test

Write against **player or module promises**, not private implementation details:

- Drive the public API, slash commands, events, or UI frames in `tests/harness.lua` (`T.newWorld()`, `T.driver()`, `T.rider()`, `T.clean(w)`).
- Do not assert internal helper names or private upvalues unless they are part of the module's documented contract.
- Add a comment immediately above each test naming every line it guards:
  `-- guards Wuber/Drive/Mail.lua:75 (cmp ~=->==: normal mail ignored when issecretvalue is absent)`

## Proving both halves

A guard test is only proven when **both halves** hold:

1. **Base passes:** the test passes on the untouched tree.
2. **Mutant fails:** the test fails when the target line is broken.

Run `tools/audit/prove_mutant.py` from the repository root (or worktree) against a mutant spec JSON (`[{"id": ..., "file": ..., "line": ..., "old": ..., "new": ...}]`):

```sh
python tools/audit/prove_mutant.py . mutants.json 75 "mutation b2 mail: normal mail" --lua lua5.1
```

`prove_mutant.py` temporarily applies the mutant, runs the matching tests, restores the file, and prints `KILLED` (exit 0) only when the mutant fails and the base passes. Never commit changes under `Wuber/` from a proof run.

### Worked example

From `tests/mutation/google_b2_mail_guards_test.lua`:

```lua
-- guards Wuber/Drive/Mail.lua:75 (cmp ~=->==: normal mail ignored when issecretvalue is absent)
test("mutation b2 mail: normal mail is still read when issecretvalue is not defined", function()
	local w, c, DR = setupClient()
	local orig = c.env.issecretvalue
	c.env.issecretvalue = false
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	w:mail(c, { sender = "Dan Miller", money = 5000, subject = "Wuber" })
	w:openMailbox(c)
	w:advance(1)
	c.env.issecretvalue = orig
	ok(DR.MailNote("Dan Miller") ~= nil, "normal mail is noted without issecretvalue")
	T.clean(w)
end)
```

When `Wuber/Drive/Mail.lua:75` flips `~=` to `==`, `MailScan` treats normal mail as secret and skips it, so `DR.MailNote("Dan Miller")` is `nil` and the test fails (`KILLED`).

## What to skip (and why)

Skip a candidate line with a one-line reason instead of forcing a brittle test when it is:

- **Gone or rewritten:** the line no longer exists on `main`.
- **Already guarded:** `prove_mutant.py` already prints `KILLED` with existing tests.
- **Unobservable:** identical runtime behavior (e.g. `false` vs `nil` in a boolean check), dead code, or pure draw/log-only cosmetics.

Prioritize lines that protect money, who gets what, saved data, and safety.

## Naming files and tests

- **File:** `tests/mutation/<area>_guards_test.lua` (for example `tests/mutation/google_b2_mail_guards_test.lua`). `tests/run.lua` loads all `*_test.lua` files under `tests/mutation/`.
- **Test name:** start with `"mutation <area>: <promise>"` (or `"mutation b3 <area>: ..."` for a batch), describing what the player or caller expects.

## Checks before a push

Run these in your worktree before pushing (use Lua 5.1, not LuaJIT):

1. Static and module checks (0 failures):
   ```sh
   lua5.1 tools/check.lua
   ```
2. Your new guard tests (run 3 times to rule out flakiness):
   ```sh
   lua5.1 tests/run.lua "mutation b2 mail:"
   ```
3. Layout gauntlet (0 problems):
   ```sh
   lua5.1 tools/layout-check.lua
   ```
4. Full test suite once (in parallel shards):
   ```sh
   WUBER_LUA=lua5.1 bash tools/suite-par.sh . 8
   ```

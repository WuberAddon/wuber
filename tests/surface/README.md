# tests/surface: the API surface guard

The fake game says yes to calls the real client refuses. The surface guard (`tests/surface-guard.lua`) makes it refuse them too.
It is **opt-in**: it loads only with `WUBER_SURFACE=1`, so the normal suite is unchanged (`tests/harness.lua` has three small hook lines).

| Kind | Meaning | Default |
|---|---|---|
| U | calling a global, `C_` function or widget method that the API docs do not list and no interface Lua defines or calls (nil in the game); behind its own `type()` / `and` / `pcall` check it is only info (G) | on |
| P | protected, secure-only or curated "never" function called from addon code | on |
| K | `ConstSecretAccessor` method (`IsEventRegistered`, `GetAttribute`) on a frame the game made, answered before `issecretvalue` | on |
| S | a secret value given to a `SecretArguments=NotAllowed` function | on |
| C | curated "combat" function called in combat | on |
| H | curated hardware-click function (`InviteUnit`, `SendChatMessage` ...) called with no click under way | **on** (`WUBER_SURFACE_HW=off` turns it off) |
| L | a lead: a P, H or C hit on a curated entry whose evidence is only "brief"; printed and logged, never a violation | on |

## Evidence
Every curated entry in `apisurface.lua` carries `ev`: `"measured:<build>"` (a row for the function in `tests/fixtures/probe/measured-blocked.lua`), `"docs"` (the API docs flag it protected or secure-only) or `"brief"` (from a brief only). Only measured and docs hits fail a test; a "brief" hit is a lead (kind L in `WUBER_SURFACE_LOG`). A real blocked log makes an entry measured:
`lua5.1 tools/rec/probe-import.lua --wtf <WTF folder> --blocked-out tests/fixtures/probe/measured-blocked.lua` (rows: function, BLOCKED or FORBIDDEN, in combat, from a click or not, build). The Lab's `CallLog.lua` adds positive evidence (each own call of a curated name: in a click handler, in combat, a blocked event in the same frame; no arguments, no names). Calls through a thin wrapper (`callm`, `T.Call`, `pcall` ...: the `WRAPPERS` list in the guard) are judged at the next Wuber frame up.
The row in the fixture today is SYNTHETIC (`tests/fixtures/probe/SYNTHETIC-blocked-run.lua`): replace it by a real run.

Only code of the Wuber addons is judged, never tests or the harness. A hit is a world violation (the test's `clean(w)` fails) and a line in the file named by `WUBER_SURFACE_LOG`.

## Run it
- One filter: `WUBER_SURFACE=1 lua5.1 tests/run.lua "<text>"`.
- Tests touching changed files: `bash tools/quick-check.sh` has a **surface** group (on when a Wuber Lua file changed; `--no-surface` / `QC_SURFACE=0` turn it off).
- The whole suite: `WUBER_SURFACE=1 lua5.1 tests/run.lua --shard K/8`, at most 2 shards at a time (each is heavy), results to disk.
- Env: `WUBER_SURFACE_HW=on` tries the hardware-click rule; `WUBER_SURFACE_STRICT=1` = docs + interface definitions only; `WUBER_SURFACE_CSA=all` every secret accessor (noisy).

## Allowed names
`allow.lua` lists names that are not bugs, one `{ "kind:name", "reason" }` per line (a line without a reason is an error). Fix real finds in the addon instead. The static pass uses keys `static:KIND:name@file` (kinds P, B4, B4c, U); the test fails on a static finding with no entry and on an entry that matches nothing.

## Files
- `apisurface.lua`: generated, do not edit (`tools/surface/README.md`: regenerate on every client patch).
- `guard_evidence_test.lua`: the importer rows, evidence on every curated entry, leads versus violations, H on, the measured ReloadUI proof, the wrapper rule.
- `surface_catches_test.lua`: what the guard refuses (skipped without the guard).
- `surface_oldcode_test.lua`: the old code shapes the real game refused (an unchecked `IsEventRegistered` answer, `ReloadUI` from a timer or by `rawget` + `pcall`) must be caught.
- `static_surface_test.lua`: the static pass (`tools/surface/static-surface.lua`, no test runs the code): the fixture and the REAL old files (`../fixtures/surface/real`: AutoKeys.lua before the B4 fix, Sheets.lua and GameFacts2.lua before the ReloadUI fixes) are flagged, the fixed AutoKeys and the current addon are clean.
- `../fixtures/surface/WuberFxOld`: those old shapes as a fixture addon (not Wuber code).

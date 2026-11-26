# tools/surface: the API surface behind the surface guard

`gen-surface.py` builds `tests/surface/apisurface.lua`, the list of what the WoW Forever client's API has and what it refuses to addon code.
The surface guard (`tests/surface-guard.lua`, opt-in) judges the Wuber addons by it. Run `python tools/surface/gen-surface.py --help`.

## Regenerate on every client patch
1. `python tools/surface/gen-surface.py --fetch <an empty folder outside the repository>`
   clones (or updates) the interface source, `Gethe/wow-ui-source` branch `forever`, inside the `alpine/git` container and generates the file.
   The container only reads the public repository and writes the clone into that folder; nothing from it is run, only read as text.
   With a checkout you already have: `--ui <folder holding Interface/ and version.txt>`.
2. The header of `tests/surface/apisurface.lua` names the client build, so a patch shows as a diff. Commit the regenerated file.
3. Run the suite once with the guard on (see `tests/surface/README.md`); a new hit is a real finding or a name for `tests/surface/allow.lua` (with a reason).

## Evidence
`gen-surface.py` writes `ev="docs"` for a curated name the API docs flag protected / secure-only and `ev="brief"` otherwise. `"measured:<build>"` is never written here: the guard takes it from `tests/fixtures/probe/measured-blocked.lua` (`tools/rec/probe-import.lua --blocked-out`).

## The static pass: static-surface.lua
`lua5.1 tools/surface/static-surface.lua` (run from the repo root; `--help`) reads every Lua file the TOCs list (Wuber and the Lab) with its own Lua 5.1 lexer
and judges names against `tests/surface/apisurface.lua` without running anything. It reports P (protected, secure-only or curated "never": ReloadUI in a click,
a timer, by `_G` or by a string), B4 (a value from an always-secret call, or from IsEventRegistered / HasScript / GetScript / GetAttribute on a frame that is not
the addon's own, reaches a compare or a test before issecretvalue / canaccessvalue; a local helper that calls one counts), B4c (the same for a conditionally secret
function: information), U (undocumented) and G / H / C (information). Exit code 1 when P or B4 is left. The whole addon takes about 1 s.
Not checked: taint propagation, a secret returned through a helper in another function, a secret kept in a table and compared later.

`apisurface.lua` now records the secret kinds apart (the generator used to fold them into `sr`): `sra` SecretReturns=true (always), `sw` SecretWhen* (conditional, the
conditions as a string), `scl` SecretInChatMessagingLockdown, `sas` SecretReturnsForAspect (the aspects as a string), `aut` SecretArguments=AllowedWhenUntainted.

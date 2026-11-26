# Wuber

Wuber is a World of Warcraft addon that lets you call a summon the way you would call a ride. It shows which Warlocks are online, where they are and what they charge, and you book one with a click. Warlocks can drive too: the Drive tab runs a queue, invites riders, opens the trade for the fare and keeps a small ledger.

Summons are paid for in game gold between players; Wuber never takes or moves gold by itself and never sends a chat line without a click of yours, except the optional auto-reply a driver switches on.

## For players
Read the [player guide](docs/PLAYER-GUIDE.md).

## Install
1. Download the latest release zip from the project's CurseForge page (or from this repository's Releases when it has one).
2. Unzip so that the folder `Wuber` sits inside your game's `Interface\AddOns` folder.
3. Start the game, tick Wuber on the AddOns list and type `/wuber`.

To run from a clone of this repository, copy (or link) the `Wuber` folder from the repository into `Interface\AddOns`.

## Run the checks
Wuber has a fake copy of the game's API, so the whole addon is tested without starting the game.

You need Lua 5.1 (not LuaJIT; the tests rely on 5.1's table order), Python 3, and Git Bash on Windows. See [docs/RUNNING-TESTS.md](docs/RUNNING-TESTS.md) for setup, what a pass looks like and where failures are written.

    lua5.1 tools/check.lua                       # syntax, globals and bytecode
    lua5.1 tests/run.lua "<text>"                # only tests whose name contains the text
    lua5.1 tests/run.lua                         # every test (serial)
    WUBER_LUA=lua5.1 bash tools/suite-par.sh .   # the whole suite in parallel shards
    lua5.1 tools/layout-check.lua                # screens: nothing clipped or covered
    python scrub-check.py . --patterns scrub-patterns.public.txt   # no personal data in the tree
    python test_scrub_check.py                   # tests for the scrub checker itself

## Layout
- `Wuber/`: the addon (Core, Net, Drive, UI, FX, Theme, Media).
- `tests/`: the fake game (tests/harness.lua) and the tests.
- `tools/`: checks and the scripts that draw the textures.
- `lab/`: an in-game test addon for what only the real game can show (the addon itself never mentions it).
- `brand/`: logo art (not shipped in the addon).
- `ARCHITECTURE.md`: what each file does and what it may use.
- `AGENTS.md`, `ROLES.md`, `CODE-RULES.md`: how a person or an AI assistant should work in this repository.

## Contributing
Work is tracked in the Issues tab. Open a branch, make the change with a test, open a pull request. Any new words that players see need the maintainer's approval first. See CONTRIBUTING.md.

## Credits
Font: Inter (SIL Open Font License 1.1). Logo art by Anita Lift.

## Licence
MIT (see LICENSE). Inter fonts are under the SIL Open Font License (see NOTICE).
World of Warcraft is a trademark of Blizzard Entertainment; Wuber is not affiliated with Blizzard.

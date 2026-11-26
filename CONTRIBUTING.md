# Contributing to Wuber

Thank you for helping. Wuber is a World of Warcraft addon (Lua 5.1) with a fake game, so every change can be proven without the game.

## Licence of contributions
By opening a pull request you agree that your contribution is licensed under the MIT License, as in LICENSE.

## Run the checks
You need Lua 5.1 (not LuaJIT), Python 3, and Git Bash on Windows. Run from the repository root (or your worktree). See [docs/RUNNING-TESTS.md](docs/RUNNING-TESTS.md) for setup, what a pass looks like and where failures are written.

    lua5.1 tools/check.lua                       # syntax, globals and bytecode
    lua5.1 tests/run.lua "<text>"                # only tests whose name contains the text
    lua5.1 tests/run.lua                         # every test (serial)
    WUBER_LUA=lua5.1 bash tools/suite-par.sh .   # the whole suite in parallel shards
    lua5.1 tools/layout-check.lua                # screens: nothing clipped or covered
    python scrub-check.py . --patterns scrub-patterns.public.txt   # no personal data in the tree
    python test_scrub_check.py                   # tests for the scrub checker itself

On Windows, see "Set up on Windows" in `AGENTS.md` (Lua 5.1 binaries, `WUBER_LUA`, and running `tools/suite-par.sh` in Git Bash, not WSL's bash).

Run `tools/check.lua` after every change, a filtered `tests/run.lua` (or `bash tools/quick-check.sh`, which runs only the tests a change touches) while you work, and the whole suite, the layout check and the scrub check before you open a pull request.

## How to work
- Issues are the work list. One issue per pull request.
- Branch names: `claude/<n>`, `google/<n>`, `author/<topic>` (n = the issue number). Make the branch in its own git worktree, not in your main checkout.
- Commit messages start with `#<issue>`, for example `#42 Stop the queue showing a driver twice`.
- While you work, `bash tools/quick-check.sh` runs only the tests your change touches (it does not replace the whole suite before a pull request). `tests/README.md` explains the fake game and what it cannot prove.
- Fix a bug test-first: write the test, see it fail, then fix.
- Generated files (`ARCHITECTURE.md`, the seed and flight blocks) are never regenerated or committed on a feature branch: the maintainer or lead does it after the last merge.
- A pull request says: what changed, the test that fails before and passes after, and anything not proven.
- Words that players see are never changed without the maintainer's approval (label `needs-author`).
- Never add paths, e-mail addresses, account ids, recordings, screenshots with names, or anything that starts an AI tool.
- The `google` label is only added by the maintainer.
- No pushes to main, no force pushes, no tags or releases: those are the maintainer's.

Read AGENTS.md and CODE-RULES.md for the code rules.

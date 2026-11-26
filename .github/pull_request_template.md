## What changed

## Issue
Closes #

## Test that fails before and passes after

## Not proven
<!-- Anything you could not check, including what only the real game can show. -->

## Checklist
- [ ] `lua5.1 tools/check.lua` passes
- [ ] the whole suite passes (`WUBER_LUA=lua5.1 bash tools/suite-par.sh . 16`)
- [ ] `lua5.1 tools/layout-check.lua` passes
- [ ] `python scrub-check.py . --patterns scrub-patterns.public.txt` prints 0 hits
- [ ] no words players see were changed without the maintainer's approval (label `needs-author`)
- [ ] no paths, e-mail addresses, account ids, recordings or screenshots with names added
- [ ] this pull request covers one issue and the commit messages start with `#<issue>`

By opening this pull request I agree that my contribution is licensed under the MIT License (see LICENSE).

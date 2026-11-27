# Regrouping tests by feature

Many tests sit in folders named for the round that wrote them (r24 to r54, round*, run1*, v24, d1 to d4, dec, p242, fr, bs, au24, h24, fga, winners). The folder name says when, not what. The goal is tests/<area>/<module>_test.lua, one file per Wuber module (for example tests/ui/rider_test.lua). Do it one folder per pull request.

## Steps for one folder

1. Pick the next folder from the table below. Make sure no open pull request edits that folder.
2. Record the count before. Run the full suite once on the unchanged branch and note the total number of tests. Also run `lua5.1 tools/tests-for.lua <Wuber file>` for each module the folder tests and save the list of test parts it prints. It finds a module's tests by the "Test:" line in the module's own header (in Wuber/), by a test file named <module>_test, and by test files that name the module or its path. So a moved file must be named <module>_test.lua for the first lookup to keep working.
3. For each file, find the module it mainly tests (the Wuber/ files its tests run; tools/coverage-map.lua shows this). Tests with no clear module go to the area's misc file, not to a new round-named file.
4. Move the tests into tests/<area>/<module>_test.lua. Append to the file if it exists. Keep every test body and every test name as it is.
5. If a file's tests use one local helper or setup, copy that helper to the top of the target file once. Do not rewrite it.
6. Update tests/run.lua in the same pull request. Folders from /r27 onward are in the folder list (the ipairs list near the end): remove the emptied folder from it, and make sure the new area folder is in it. Root files (r24_*, r25_*, r26*, round*, run1*) are not in that list: each has its own explicit loadfile line in tests/run.lua. Delete that line when the file moves, and make sure the target folder is in the folder list. A test file in a folder the runner does not load never runs, and the suite count would silently drop.
7. Move emptied files to a _to_delete folder outside the tracked tree; do not delete history by hand. Use `git mv` for whole-file moves so history follows.
8. Check nothing is lost:
   - The full-suite test count after equals the count before.
   - Every test name saved in step 2 is still found by tools/tests-for.lua for its module.
   - tools/check.lua passes.
   - The same tests fail before and after (if any known failures exist).
9. In the pull request text, give the before and after counts and the folder moved.

## Order, smallest risk first

Small folders with few tests and one module go first. Large folders and the slow ones (long replay tests) go last, because a mistake there costs the most time to find.

| order | folders | tests | note |
|---|---|---|---|
| 1 | run1*, round3, round7, round9, round12, round13, round15 | 1 to 20 each | single files, one module each |
| 2 | r24, r25, r26, r26b, r27 | 11 to 36 | root files, mixed small areas |
| 3 | r29, r30, r31, r37, r48, r53, r54, bs | 16 to 32 | small folders |
| 4 | r28, r32, r33, r34, r46 | 42 to 117 | many tiny files |
| 5 | round2, round5, round6, round8 | 44 to 105 | root files |
| 6 | au24, fr, fga, h24, r49, r50, d1, d3, r47 | 42 to 125 | UI and Drive mixed |
| 7 | p242, r51, d2, d4 | 68 to 115 | slower, mixed setups |
| 8 | r52, round4 | 143 to 392 | large, one module dominates round4 |
| 9 | dec, v24 | 120 to 319 | the slowest (long chat gauntlet replays) |
| 10 | winners | 1121 | generated, see below |

## What not to do

- Do not merge tests that have different setups into one test. Moving a test is fine; joining two tests is not. A merge needs its own pull request, with every case kept.
- Do not rename tests. Names are keys in the coverage map, the time fixture and the baseline.
- Do not touch the generated winners/ files by hand more than needed. They come from a kit outside this repo, and a rerun of the kit would bring the old files back. Change the kit's output first, or leave winners/ for last.
- Do not move two folders in one pull request.
- Do not change anything players see.
- Do not skip the count check. A moved test that the runner no longer loads shows up only as a lower count.
- Test names stay the same, so tests/fixtures/test-times.txt stays valid. tools/refresh-test-times.lua (it arrives with the test-times pull request and is not on main yet) can refresh it later from one full run.

# Releasing Wuber

Only the maintainer tags, uploads and publishes. Nobody else pushes a tag or makes a release.

## Before you start
1. Every pull request for the release is merged. `main` is green locally: `lua5.1 tools/check.lua`, the whole suite (`WUBER_LUA=lua5.1 bash tools/suite-par.sh .`), `lua5.1 tools/layout-check.lua`, and the scrub check `python scrub-check.py . --patterns scrub-patterns.public.txt` with 0 hits.
2. Regenerate the generated files once, after the last merge: `lua5.1 tools/map.lua --write` (ARCHITECTURE.md), then `lua5.1 tools/map.lua --check` must pass.
3. Play-test the build in the real game (the checks cannot show everything; see tests/README.md, "What tests cannot prove").

## Changelog
1. Write `release/CHANGELOG-<version>.md`: what changed for players, in plain words, newest first. Say if new files were added (then: exit the game completely and start it again; `/reload` is not enough) and list them.
2. Describe nothing about price. No personal names, paths, job or process numbers.
3. Update `docs/curseforge-page.md` (the page and its short description) and `release/curseforge-page.html` if the page text changes, and put the changelog text for the CurseForge changelog box in `docs/release-notes-<version>.md` (a new file per version).

## Tag and zip
1. Set the version in `Wuber/Wuber.toc` (`## Version`) and `W.VERSION` in `Wuber/Core/Base.lua` (the zip tool can stamp both into the zip's copy from a `-dev` version).
2. Tag the release commit `v<version>` (maintainer only).
3. Build the zip from the tag: `python tools/make_release_zip.py --version <version> v<version> Wuber-<version>.zip`. It builds from committed files only, checks the TOC and version, refuses personal words, e-mail addresses and local paths, and checks that every file the TOC lists is in the zip.
4. Unzip it into a clean `Interface\AddOns` and start the game once to see Wuber load without errors.

## What is NOT shipped
The zip holds the folder `Wuber/` only. These stay in the repository and never go in the release:
- `tests/`, `tools/`, `lab/` (the in-game test addon), `docs/`, `brand/`, `release/`, `.github/`
- `ARCHITECTURE.md`, `AGENTS.md`, `ROLES.md`, `CODE-RULES.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `README.md`
- `tools/RitualRides/` (a retired stub), scrub tools and patterns, anything generated under `tests/out/`
- Large logo art in `brand/` and test copies of textures under `tests/`

## Publish
1. Upload the zip and the changelog to CurseForge (maintainer only), and paste `release/curseforge-page.html` if the page changed.
2. Create the GitHub release from the tag with the same zip and changelog.
3. Check the CurseForge page links to this repository and that the download installs.

## Placeholders to fill before publishing
- `docs/curseforge-page.md`, the block marked SOURCE-LINK-PLACEHOLDER: replace it with the link to the new public repository (source code and bug reports) once the maintainer has made it. The old repository is private, so no link to it goes on the page. Do not publish the page while the marked line is still there.
- Check every other link on the page opens (OpenMap), and add no forum link unless the maintainer has checked it.


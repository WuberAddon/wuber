# tools/art: pictures for the addon

## Flow clip to flipbook sheet (flipbook.py)

Python 3 with Pillow and numpy; ffmpeg and ffprobe on PATH.

    python tools/art/flipbook.py clip.mp4 --frames 32 --cell 256 --cols 8 --black-alpha --out sheet.tga --png preview.png

- It samples the WHOLE clip (or --start/--end seconds), evenly. It never cuts the loop short to hide the join.
- It mends the join by cross-fading: it takes N + K frames, and the first K output frames are mixes of the early frame
  and the late one. --blend K sets K (default about N/8; 0 = none).
- --black-alpha is for clips on black: alpha comes from brightness and the colour is un-multiplied (use blend "ADD" in the game).
- --square crop (default, centre crop) or fit (black bars). A folder of numbered png frames works too (--fps-in, default 24).
- Too short a clip, or too many frames for one 2048 x 2048 sheet, is refused in plain words. --split writes several sheets.
- `python tools/art/flipbook.py --plans` prints the 32 versus 64 frame comparison (no clip needed).

### What the numbers mean

- sheet: width x height, a power of two, at most 2048 x 2048. File: 32-bit TGA, as tools/make_media.py writes.
- memory in the game: width x height x 4 bytes, held while the texture is loaded.
- seconds per loop: frames / fps. The addon steps flipbooks 20 times a second (FX/Effects.lua), at most 12 moving at once.
- seam: the change from the last frame to the first, against the average change between neighbours. Ratio 1 means the
  join looks like any other step. The tool prints it before and after mending, and suggests a longer --blend when it is
  still high. The gap between the two ends is shared over K + 1 steps, so a clip that grows all the way through needs a
  long cross-fade, and the faded frames look double-exposed. A clip made to loop (same picture at both ends) is better than any mend.
- report: written beside the sheet as .json.

### Where a sheet goes

The tool writes nothing into the addon. A sheet would be copied to Wuber/Media/fx/ and the printed line pasted into
the SHEETS table in Wuber/FX/Effects.lua, with a BOOKS entry using the same count. A new media file needs a full game restart.

## Still picture portal (still.py)

The ride screen's portal is a still picture that turns, not a flipbook. That is made by tools/art/still.py
(written by another group).

## Tests

    python -m unittest tools.art.test_flipbook

It makes its own small test clip with ffmpeg. The Lua suite (tests/run.lua) does not run python tests, so run this by hand.

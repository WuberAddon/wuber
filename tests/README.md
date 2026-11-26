# Wuber tests

## Start here (new to the project?)

Wuber talks to the game through hundreds of API calls (frames, chat, groups, trades, maps). We cannot start the game for
every change, so `tests/harness.lua` is a **fake game**: a small model of the client that the addon is loaded into, file by
file, exactly as the game loads it from `Wuber/Wuber.toc`. A test builds a world, adds one or more game windows
("clients": a rider, a driver), moves the clock, clicks things where they are drawn, and asserts on what the addon did.

The mental model:

- **World** (`T.newWorld()`): players, chat channels, groups, summons, trades, the map and one shared clock. Nothing
  happens by itself: `w:advance(seconds)` runs timers, animations and `OnUpdate`.
- **Client** (`w:addClient(name, opts)`): one game window with its own copy of the addon (`c.W` is Wuber's namespace,
  `c.env` its globals). Bots stand in for players that need no window.
- **Strict on purpose.** A widget method or API the fake does not define is nil, so calling it is an error that names it.
  Rules the real game enforces (hardware clicks, combat lockdown, the 255-byte addon message limit, throttling) are
  enforced here too and recorded in `world.violations`. Every test ends with `clean(w)` (`T.clean(w)`), which fails on any
  violation, Lua error or missing media file.
- **A model, not the game.** It was built from what the real client was measured to do. Where nobody measured, it is a
  guess. A green suite does not prove a UI fix; see "What tests cannot prove" at the end of this file, and the in-game
  `lab/` addon, which checks the game itself.

Where things are:

| What | Where |
|---|---|
| The fake game | `tests/harness.lua` (and `tests/lib/`, `tests/fakes8.lua`, `tests/harness_draw.lua`) |
| The runner and shared helpers | `tests/run.lua` (loads every test part, hands them the helper table `T`) |
| Tests | `tests/<area>/<name>_test.lua` and older `tests/*.lua` / `tests/r<round>/` folders; a file starts with `local T = ...` |
| Screens checked for clipping and overlap | `tests/layout/`, run by `tools/layout-check.lua` |
| Recordings and fixtures | `tests/fixtures/` (the old-driver stand-in is `tests/fixtures/addons/OldDriver`) |
| Output of runs (logs, transcripts) | `tests/out/` (not committed) |

A test is one `test("name", function() ... end)`. The smallest useful shape:

```lua
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
test("area: what should be true", function()
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(5)
	eq(type(c.W.Module), "function", "the addon loaded")
	T.clean(w)
end)
```

`tests/core/registry_test.lua` is a short real example. To add a test: write it so it **fails first**, see it fail
for the right reason, then fix the code. Name the test after the promise it keeps, not the symptom.

How to run, cheapest first (details in `CONTRIBUTING.md` and `AGENTS.md`; Lua 5.1, never LuaJIT):

1. `lua5.1 tests/run.lua "<text>"`: only tests whose name contains the text.
2. `bash tools/quick-check.sh`: the tests that cover the files you changed (`--list` shows them without running).
   `lua5.1 tools/tests-for.lua [--run] <files>` does the same by file name.
   Opt-in API surface guard (undocumented, protected or secret-value calls the real client refuses): `WUBER_SURFACE=1 lua5.1 tests/run.lua "<text>"`, see `tests/surface/README.md`.
3. `WUBER_LUA=lua5.1 bash tools/suite-par.sh . 16`: the whole suite in 16 shards, once before a pull request.

Run from the repo root:

```
lua5.1 tests/run.lua            # every test, then the API report
lua5.1 tests/run.lua "map pins" # only tests whose name contains the text
lua5.1 tests/run.lua --compare-transcript  # and fail on any behaviour change
```

The old Ritual Rides addon is not in this repository. Where a test needs an old driver addon next to Wuber
(`loadRR = "1.4.1"`), it gets the small stand-in in `tests/fixtures/addons/OldDriver` (the global that Wuber's lock reads,
a driver registered through `WuberAPI.SetDriver`, saved data in `RitualRidesDB`); `tests/oldaddon/` tests what Wuber does
with such an addon. Tests that only exercised the old addon's own code are in `tests/retired/` (not run). The transcript
baseline (about 110 MB) is not stored; `WUBER_BASELINE=<file>` makes a run compare with another baseline file. With no baseline file `--compare-transcript` prints `transcript: NO BASELINE ...` (nothing was compared, not a failure); make one with `--update-transcript` on a fresh clone (`bash tools/fresh-suite.sh`).

The behaviour transcript (`tests/lib/transcript.lua`, REFACTOR-MAP 4.5) proves a restructure
changed nothing: per test, every addon message, whisper and chat line sent, every named frame
(shown/hidden, strata, level, rect) and visible text plus a digest of every widget, the saved
variables, and the event wiring. `--compare-transcript` writes `tests/out/transcript.txt` and
fails on any difference from `tests/transcripts/baseline.txt` (a filtered run compares only the
tests it ran; a new test is listed, not a difference). `--record-transcript` only writes it;
`--update-transcript` makes it the new baseline (a reviewed change; full green runs only).
`WUBER_TRANSCRIPT_DETAIL=1` writes every widget and every long list in full, to find what a
digest change is.

`lua5.1 tools/check.lua [--warn]` (REFACTOR-MAP 6.2; the suite runs it as a test) reads every
TOC file's bytecode: it parses, counts locals (warn 150, fail 170) and upvalues (fail 60),
compares global reads and writes with `tools/globals-baseline.txt` (a new read is usually a lost
local; `--write-globals` remakes the list, a reviewed change), fails a load-time call into
another file unless allow-listed, and, for new module files (not in `tools/check-legacy.txt`),
enforces one `W.Module("<path.with.dots>", { deps })`, deps earlier in the TOC, known `W.Mod`
targets and the 1,200-line cap. Per-module tests live in `tests/<area>/<module>_test.lua`
(today `tests/core/registry_test.lua`).

The exit code is 0 when every test passes. The whole suite is several thousand tests: a serial run takes many minutes, 16 shards (`tools/suite-par.sh`) about a minute and a half on a 16-core PC. While working run a filtered run or `tools/quick-check.sh`.

Round-one tests are in `run.lua`; round-two tests (SPEC2.md and its advisor fixes) in
`round2.lua`, which `run.lua` loads with its helpers. `round1/Wuber` is the round-one addon
as installed (17 Nov, 20:49): a real old peer for the interop tests.

## The harness (tests/harness.lua)

A small WoW Forever 1.60.1 for the tests. One **World** holds the players, chat channels,
groups, summons, trades and the clock. Each game window is a **Client**: the addons named
in `addons` (default `{ "Wuber" }`; driver clients for Ritual Rides use
`{ "Wuber", "RitualRides" }`, with RR loaded from the old Ritual Rides folder) are
loaded file by file from their TOCs into an environment of their own, called with
`(addonName, namespace)`. Then ADDON_LOADED, PLAYER_LOGIN and PLAYER_ENTERING_WORLD fire.
Bots (players without a client) stand in for extras.

```lua
local w = H.NewWorld({ clickMode = "modern", useKeyDown = true, senderFormat = "space" })
local d = w:addClient("Anita Lift", { spot = "Ratchet", class = "WARLOCK" })
local r = w:addClient("Wuber TestCharacter", { spot = "Orgrimmar", class = "MAGE", money = 100000 })
w:advance(15)          -- the clock: timers, C_Timer, OnUpdate and animations (10 frames a second)
r.W                    -- Wuber's namespace in that window; r.RR for Ritual Rides; r.env its globals
```

What it enforces (breaking a rule goes into `world.violations`, Lua errors into
`world.errors`; every test ends with `clean(w)`, which also fails on any `W.lastError`,
a throttled addon message, a missing media file or an addon message over 255 bytes):

- **Strict widgets.** Frames, textures, font strings, edit boxes, buttons, animation groups
  and animations have only the methods the fake defines; any other is nil (calling it is an
  error naming it) and is listed in the report. Arguments are checked like the client does
  (anchor points, strata, draw layers, blend modes, smoothing, looping, font flags, script
  names, event names, `SetScale(0)`, anchoring loops, `SetText` without a font...).
  Textures, fonts and sounds under `Interface\AddOns\Wuber\...` must exist on disk.
- **Layout.** Positions follow anchors, sizes and scales, so `GetLeft/GetBottom/GetCenter`
  are real, and `client:clickOn(region)` / `client:clickText(text)` click where a thing is
  drawn: the topmost mouse-enabled frame there (strata, level) gets the click, as in the game.
- **Secure buttons.** A hardware click (`client:click`) sends PreClick/OnClick/PostClick once
  for every click the button is registered for (down, then up). The action runs once
  (modern client: on down or up per `useOnKeyDown` / ActionButtonUseKeyDown) or on every
  click (`clickMode = "legacy"`). `type = "macro"` lines are parsed: `/w First-Surname text`
  records a chat whisper; unknown lines are violations; macros over 255 characters too.
- **Combat.** `w:enterCombat(c)` fires PLAYER_REGEN_DISABLED, then locks. Protected frames
  (secure buttons and every frame that holds one) can't be shown, hidden, moved, sized or
  scaled; `SetAttribute` raises an error. All of these fire ADDON_ACTION_BLOCKED.
- **Chat.** `SendChatMessage` from an addon is blocked (a violation). Addon messages:
  CHANNEL to every member of the channel who registered the prefix (the sender too),
  WHISPER to the named player ("First Surname" or "First-Surname") if online; 255 bytes at
  most (an error); a token bucket (`throttleBurst`, `throttleRate`) answers 3 when empty;
  `w.forceThrottle = n` throttles the next n; `w.drop = { A = 1 }` loses messages of a kind.
  `w:inject(sender, text, "CHANNEL"|"WHISPER", toClient)` delivers a message from anyone.
- **Channels.** Join after `joinDelay`; 10 channels at most (`channels = 10` fills them;
  `joinFails = true`); `w:dropChannels(c)` is a loading screen losing them.
- **Groups, summons, trades.** Invites raise PARTY_INVITE_REQUEST and the PARTY_INVITE
  box; `AcceptGroup` only from a hardware click and lands after a round trip; hiding the box
  without `inviteAccepted` declines. `w:summon(caster, name)` raises CONFIRM_SUMMON (120 s,
  then CANCEL_SUMMON); `C_SummonInfo.ConfirmSummon` only from a click, then the player lands
  (loading screen, ZONE_CHANGED_NEW_AREA). `w:openTrade(a, b)`, `w:tradeMoney`,
  `w:tradeAccept` (PLAYER_MONEY before TRADE_CLOSED). Ritual Rides' ritual
  (`/cast`, `w:clickPortal`) is ported from its own harness.
- **Maps.** A fake geography (continents, zones, cities) for `C_Map` (positions, parents,
  world positions, map art), `WorldMapFrame` with `ScrollContainer.Child`, and an optional
  OpenMap (`openMap = { stitched = true }`, API major 1 version 4, callbacks receive the
  event name first).
- **Secret values.** `secrets = { "UnitName", "C_Map", "GetMoney", "zone", "UnitClass",
  "sender", "channels" }` makes those APIs return a value any use of which is an error.
- **Globals.** The addons' global table records every new global and the line that wrote
  it; every API read is noted.
- **Drawn alpha.** As the game did and as the
  in-game alpha probe showed (20 Nov), a texture's `SetVertexColor` alpha, and its own `SetAlpha`
  (textures and Lines), are not taken while an
  Alpha animation plays on it or a frame above it (`A.SlideIn`, `A.ZoomIn`, fades): the default,
  `H.ALPHA_HOLD = "anim"`. A change on a frame that was drawn and then hidden, or on a hidden
  texture, is taken (the probe). The colour (r, g, b) always changes; `GetVertexColor` returns the
  drawn alpha, `H.vertexAsked(tex)` the asked one (`GetAlpha` and `H.alphaAsked(tex)` for the
  region alpha); `world.alphaKept` counts the held calls of both by addon line.
  `WUBER_ALPHA_REPORT=<file>` appends each held line with two callers and the call
  (`(SetAlpha)` or `(SetVertexColor)`), once per run.
  `WUBER_ALPHA_HOLD` (or a test setting `H.ALPHA_HOLD` and putting it back): `drawn` adds
  BRIEF21's guess (a drawn texture keeps its alpha while hidden or shown again in the same frame;
  not the client's rule, opt-in only), `off` takes every change (the fake before BRIEF21).
  A frame's or a font string's `SetAlpha` is always taken (the probe tested textures only).
  `tests/r24_d_hold.lua` checks the region-alpha hold. `tests/harness_draw.lua` checks the probe's four cases and
  loads the old F5 and B1 code (`tests/fixtures/old_pills.lua`, via a client's `rewrite`) to
  check the harness draws those bugs as the game did.

## Round two additions

- **Nameplates.** `client:showPlate(name, opts)` brings a player's plate into view (fires
  NAME_PLATE_UNIT_ADDED with `nameplateN`; plate frames and tokens are reused as in the game);
  `client:hidePlate(name)` fires NAME_PLATE_UNIT_REMOVED. Friendly plates need
  `nameplateShowFriends` (or `nameplateShowFriendlyPlayers`) = "1". opts: `forbidden` (any
  touch, anchor or parent is a violation and an error), `secretName` (UnitName is secret),
  `index` (re-use a token without REMOVED), `force`. Reading a plate's size, scale or position
  from addon code is a violation. `C_NamePlate.GetNamePlateForUnit / GetNamePlates`.
  `client:onPlate(name)`, `client:plateFramesShown()` list the addon's frames on plates.
- **CVars** per client (`client.cvars`, every set in `client.cvarSets`); nameplate CVars are
  protected in combat; an unknown CVar reads nil and is not set; CVAR_UPDATE fires.
- **Tooltips.** `tooltipStyle = "processor"` (default: `TooltipDataProcessor`,
  `Enum.TooltipDataType`, no OnTooltipSetUnit script) or `"legacy"` (OnTooltipSetUnit).
  `client:hover(name)` shows a player on GameTooltip ("mouseover") and returns the lines;
  GameTooltipTextLeftN hold them. Show() / SetUnit() from inside a hook is a violation.
- **Models.** Model, PlayerModel, DressUpModel, CinematicModel, ModelScene (+ actors) are
  guarded no-ops (counted in `client.modelCalls`); `noModelScene = true` makes a client
  without ModelScene; `noFlipBook = true` one without the FlipBook animation type.
- **Textures.** `client.texturePaths` (and `textureWhere`, first caller) record every file
  set, for lazy-loading checks; `texCoordSets` counts SetTexCoord per texture (flipbooks).
- **Old peers.** `addonDirs = { Wuber = H.ADDONS.Wuber1 }` loads the installed round-one
  code; `roundOne = true` strips D to 13 and R to 5 fields and sends no P (round-one wire).
- **Events.** Every `W.Fire(name, ...)` is recorded in `client.fired` from login on.
- AcceptGroup and LeaveParty work from events and timers (modern clients; the lead's ruling);
  AcceptTrade still needs a hardware click; hiding PARTY_INVITE without inviteAccepted
  still declines. `acceptGroupNeedsClick = true` brings back the strict rule.

## Discovery additions (tests/discovery.lua)

- **Public chat.** A secure macro's `/2 text` (the player's channel number), `/s` and `/y` post a
  line: `CHAT_MSG_CHANNEL` to every same-faction client in a channel of that name (the game's
  own channels reach every copy), `CHAT_MSG_SAY` / `_YELL` to every same-faction client.
  `w:chatFrom(name, text, kind, channel, faction)` posts one from anyone. Every line is kept in
  `w.chatPosts` ({ from, kind, channel, text, how, at }). Posting to a channel the player
  isn't in is a violation.
- **Realms.** `H.DEFAULT_REALM` = "" (measured on build 71037: the game names no realm, so no ruleset
  and no founder). A test that needs a realm names it: the world (`newWorld({ realm = H.FOUNDER_REALM })`,
  "CAMWOW EU5 Realm 5 PvE", the founders' ruleset) or one client (`realm = "CAMWOW US2 Realm 1 PvP"`;
  `false`: nil). `UnitFullName` gives the first name and the surname.
- `node tests/build-seeds.test.js` tests tools/build-seeds.js on `tests/fixtures/seeds/WTF`.
- `node tests/build-flights.test.js` tests tools/build-flights.js on `ref/flightdata` (Forever's TaxiNodes/TaxiPath export) and checks Places.lua's W.TAXI is up to date.

## The report

After the tests, `run.lua` prints:

1. **Unproven in game**: widget methods and API functions the addons used that neither
   Ritual Rides 1.3.0, the Wuber Test addon nor SPEC.md's "Client facts" ever used, with the
   first file and line.
2. Widget methods looked up that the fake lacks.
3. Globals read that the fake doesn't define.
4. Methods whose signature or version differs between clients.

## Communities (tests/community.lua)

- `H.NewWorld({ clubs = true })` gives every client a fake `C_Club` (`noClub = true` per client
  opts out); `w:addClub({ id, name, streams, members = { [name] = role } })`, roles 1 owner,
  2 leader, 3 moderator, 4 member; `w:clubInvite(club, inviter, name)`.
- A stream's channel is `Community:<club>:<stream>` (`C_Club.AddClubStreamChatChannel`) and
  crosses the internal realms' channel copies (`World:sameCopy`); WuberNet doesn't.
- `w.communitySend` = a result number, `false` or `"error"` for addon messages on community
  channels; `w.noClubChannels`, `w.clubInviteNeedsRealm`, `w.acceptInvitationFails`.
  `C_Club.AcceptInvitation` without a hardware click is a violation. Counters:
  `client.clubChannelAdds`, `client.commSends`, `client.acceptInvitationCalls`, `w.clubInvitesSent`.

## What tests cannot prove

The fake game is a model. Each line: a thing it does not simulate (or models from too little evidence), and the check in the game that covers it. A green suite says nothing about these.

- Hit test ranking (`Client:frameAt` / `framesAt`, tests/fakegame/hit_rank_test.lua and mouse_everywhere_test.lua): modelled and used by every mouse input the fake offers (`clickOn`, `moveMouse` / `hoverOn`, `GetMouseFoci`, `wheel` / `scrollIntoView`, `drag`). A clipped subtree ranks at its clipping ancestor's strata and level, and a child clipped out at the point takes no mouse; the tie at an equal level (the frame outside the clip wins) rests on one case, the header strip over the Settings back arrow (run 3), and scroll-frame clipping other than SetClipsChildren is not modelled. A direct `Client:click(frame)` is strict (tests/fakegame/strict_click_test.lua): a frame with a position must be what `topAt` hits at its centre, on the screen, or the test fails; scroll it in (`scrollIntoView`), wait for a sheet to rise, or close what covers it first, as a player would. A frame with no position at all (the fake TradeFrameTradeButton, a stand-alone widget a test never anchors) cannot be judged and is still clicked. With env WUBER_CLICK_AUDIT=<file> each refused click is also logged. In game: the Lab Auto check's back walk and its click-every-safe-local-button pass (clicks through the real hit test and reads GetMouseFoci); by hand: open Settings and every pushed page, click the back arrow.
- Mouse rules no real sample has measured (each test carries an `-- assumption:` line in tests/fakegame/mouse_everywhere_test.lua): (1) a frame that only enables the wheel takes it; (2) the wheel passes from a frame with no handler to its nearest ancestor with one; (3) a covering frame registered for drag takes the drag, and a covering frame that is not registered swallows the press (WoW sends the press to the top frame and does not pass mouse events to parents unless SetPropagateMouseClicks); (4) moveMouse fires OnLeave of the old frame before OnEnter of the new; (5) `GetMouseFoci` lists every frame under the cursor top-first by the same rank as `frameAt`; (6) `IsMouseOver` is plain geometry (no hit order, no clipping). Also: the fake has no `GetMouseFocus` (taken as removed in the real client), moves the cursor only when a test says so (a click fires no OnEnter / OnLeave), and `Client:drag` presses at the frame's centre unless the test gives a point. No Lab Auto check row covers these (an Auto check has no mouse). By hand: (1)-(2) scroll a list with the cursor over a row, then over its scroll bar, and over a nested scroll area; (3) drag the phone by its header and by a button on it; (4)-(5) `/dump GetMouseFoci()` with the cursor over overlapping frames while a tooltip's OnEnter / OnLeave is watched; (6) `/dump frame:IsMouseOver()` for a frame under a covering frame and for one scrolled out of a clipping parent.
- Font widths at 11 px: the fake measures with its own advances plus a 6% margin; the real client was measured +6.7 to +8.7% wider at 11 px (Lab font table check). A label that fits by under 9% can be cut in game. In game: the Lab's font table check; by hand, look for cut labels on the longest texts.
- OnFinished on a stopped and restarted animation: the fake fires OnStop on Stop() and finishes a restarted animation; whether the real client fires OnFinished when a window is toggled open and shut in one tick is not proven. In game: the Lab's open/close shots (the "did not close on Toggle(false)" float shots from run 3); by hand, open and shut the window in one keypress.
- Secure and hardware-click rules: the fake does not enforce that a protected action needs a hardware click, nor combat lockdown of secure frames, beyond the names on tools/forbidden.lua. In game: click each secure button once by hand (the trade, summon and invite buttons), with taintLog on.
- Taint: the taint guard (tests/fakegame/taint-allow.lua, taint_guard_test.lua) sees what Wuber writes into the game's tables, global functions, frame fields and frame parents, but not the game's own taint rules (execution tainted by us, a protected function called from a tainted path), and not writes into the C_* tables (they are proxies in the fake). In game: `/console taintLog 1`, play a ride, then `lua5.1 tools/taint.lua <taint.log>`.
- Taint guard limits: the frame-field check sees only NEW keys written onto a game frame (overwriting a field the game frame already has is not seen), and the game's C_* tables are proxies in the fake, so a write into one is not seen. In game: the same taint.log step.
- Real chat and channel timing: the fake delivers a message at the time the world's clock says, in order, with no throttle beyond its model, no lost or reordered packets and no channel-join delay of the real server. In game step: a two-account ride (rider and driver), watching for late or missing whispers and channel messages.
- The player's own UnitName and UnitFullName second return, and GetUnitName(unit) without showServer (PF-047, Lab row L12.self): the Lab logged only the lengths of the first return (5) and of GetUnitName(,true); the fake answers the surname as the second return, as for other units, and the long name for GetUnitName(unit) with no showServer. Neither is measured. In game: the Lab's L12.self should log UnitName('player')'s second return and GetUnitName('player') with no second argument.
- Game channel notices (PF-046, Lab GameFacts row L5.notice): the real game sends CHAT_MSG_CHANNEL_NOTICE_USER OWNER_CHANGED and SET_MODERATOR when a channel is joined or taken over (seen once in some runs, not in others); the fake sends only its own notices. In game: the Lab's Game facts row L5.notice.
- Chat font and label fit (PF-051, PF-053, PF-055, Lab rows L15, L15.wuber, LBL): the fake has no chat box font and no real font metrics for the game's chat frames, so it cannot show that Wuber's window leaves the chat font alone or that no label is cut. In game: the Lab's Game facts rows L15 and LBL.
- Taint log and sound hooks (PF-061, Lab row L18): the fake reads the taint log switch as 1 but a hooksecurefunc hook on PlaySound runs for addon sounds; the real game ran none ("hook ran: no", 0 of the game's own sounds heard). In game: the Lab's Game facts row L18.
- Summon status after the cast (PF-043, Lab row L1): the real IncomingSummonStatus went back to 0 about 17 s after the cast; the fake keeps an answered status for 120 s (H.SUMMON_STICKY), from older advice. In game: the Lab's Game facts row L1.
- Whisper-check answer time (PF-062, Lab row L19): the real answer took 122 to 226 ms; the fake answers after a fixed 0.2 s. In game: the Lab's Game facts row L19.
- ReloadUI from a click (PF-050, Lab row L13.blocked): the fake blocks every ReloadUI from addon code, as the real game did for the Lab bar's Reload button; whether a reload started by the game's own /reload command or by a secure button is allowed is not proven. In game: the Lab's Game facts row L13.blocked.
- Whisper from a click (PF-058, Lab row LINE): a whisper sent from another addon's own click goes out in the fake; Wuber's own lines still follow Wuber's own rules (tests/harness.lua restricted). Whether the real game lets a whisper out with no click at all is the author's "proved in game" (CLAUDE.md), not a Lab row. In game: the Lab's Game facts row LINE.
- Frame rate and memory (fact perf): the fake's GetFramerate answers 60 and it counts no memory; the real client gave 20 to 100 fps and 6.8 to 11.5 MB for Wuber. In game: the Lab's perf log line (kind perf, sampled during play, Hooks.lua); read its fps and wuberKB after a ride.
- The 14-item self-test and C_Map after login (facts selftest.login, login.f1_sound): the fake's C_Map answers at once and it has no key bindings or sound settings; the real client once answered nothing 60 s after login ("12 of 14"), and the F1 binding and Sound in Background checks read the player's own PC. In game: the Lab's login lines ("[login] 14 of 14 passed", "[login +60 s]", the passive login fail lines).
- Flight map sizes (facts taxi.numnodes, taxi.positions, PF-057): the fake's nodes come from the recorded lists (22 on Kalimdor, 13 of 14 on Eastern Kingdoms), PROVEN for the flight map: 22 TaxiButtons, 2 shown, inner area 580 x 580; INFERRED (not recorded): which buttons are shown (the current and known nodes), the TaxiRouteMap offset inside TaxiFrame (11, -28), the buttons' size (18) and positions; costs are only as recorded. In game: the Lab's Game facts row B16 at a flight master.
- The real text ruler (PF-063, PF-066): the fake measures with its own table and a margin; the real game draws about 4 percent wider than the layout table and its digits are not tabular. In game: the Lab Auto check rows a_ruler and a_font.
- Animation facts beyond the four measured (PF-059, PF-116): the fake keeps GetAlpha at the from value, moves nothing under a Translation, plays on a hidden frame and runs no OnUpdate there, as measured; it does not draw, so Scale on text (never do it) and the real look of an Alpha fade are not shown. In game: the Lab Auto check row a_anim.
- The API census (PF-060) beyond WOW_PROJECT_ID 18, no SetGradientAlpha and nothing from the edge getters of an unplaced frame: the other 295 answers are not compared. In game: the Lab Auto check row a_census.
- The ride's network timings (fact ride.network.stages): the fake's whispers and channel messages arrive on its own clock, not the real 0.4 to 12 s stages. In game step: a two-account ride, reading the ride lines of the Lab.
- A new file needs a full restart (PF-115), frames made in combat (PF-122) and a real emote from a timer (PF-124): the fake reloads any file and has no combat lockdown of frames or emote engine. In game: restart after a new file; click each secure button in and out of combat; use /wuber emote steps by hand.
- Font load after login (PF-117) is off by default in the fake (opt-in world.fontReadyAt); the real Inter font loads after about 0.6 s (PF-063). In game: the Lab Auto check row a_font.
- HasAccessConstraints: the fake answers false for every frame; only TradeFrameTradeButton is proven (PF-065). In game: the Lab's Game facts row TRADEBTN at a trade window, and a click on each secure button by hand.
- Sound settings in background: the fake has no sound engine; whether a sound plays with the game in the background, muted or with a channel off is the player's settings. In game step: alt-tab away during a ride, with the game's "sound in background" setting off and then on, and listen for the cue.

## Known bugs (docs/KNOWN-BUGS.md)

Every fixed in-game bug has a stable id (`KB-nnn`) in `docs/KNOWN-BUGS.md`, with the test that holds it.
When you fix a bug, add its line there and put the id in the new test's name. `lua5.1 tools/known-bugs-check.lua`
(also run by `tests/tools/known_bugs_check_test.lua`) fails on a duplicated id or a test that is not there.

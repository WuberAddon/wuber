# Wuber Lab (developer only - NEVER SHIP THIS)

A test mode for **Wuber** and **Ritual Rides**, as a separate addon folder `WuberLab`.
It only watches: it wraps a few functions (always calling the originals), logs to its own
saved variables, and gives local test helpers. Wuber and Ritual Rides work exactly the same
with or without it, and neither of them knows it exists.

**Never put `WuberLab` in a release, and never mention it in Wuber or Ritual Rides.**
Before every upload, run the release check (below).

## The Lab bar, cleaned up (23 Nov 2026)

Six buttons and a words box instead of fifteen buttons, about 1.3 times bigger, in Wuber's colours. **Start test** (taint log on, trail on, Game facts on,
"potato start" mark and screenshot, recorder on, then a Reload 2 s later), **End test** ("potato end" mark, trail off, recorder off, then a Reload 2 s later so the logs save),
**Auto check**, **Steps**, **Huh** (left click: mark + screenshot; right click: just a screenshot, was Snap; Shift + click: the sync mark, was Potato sync) with its words box, and
**More** (Game facts, Slide check, Portal turn, Send matrix, Trail, Taint log, Chat log, Reload). Report: **REPORT-lab-cleanup.md**. New files (restart the game fully once):
CensusCore.lua, AutoSteps4.lua, AutoSteps5.lua, AutoSteps6.lua (the Auto check's a_anim, a_census, a_ruler), AutoSteps7.lua (a_paused_clicks: read from a fight the player is in anyway, "needs combat: skipped" otherwise; a_settings_asks, a_driver_hits, a_pill_hit, a_rider_checks and the saved-data check PR-76), AutoSpeed.lua (its timing pass a_speed: Lua ms, worst frame, memory per screen change; labreport prints the Speed section), GameFacts3.lua, GameFacts4.lua, GameFacts5.lua (passive secrets census,
combat edge, Send matrix), Focus.lua (passive focus recorder). Their answers go to WuberLabDB.facts (ids RULER, CENSUS, ANIM, SECRETS, REGEN, TRADEBTN, SENDM, SENDM.heard) and WuberLabDB.focus.

## The flight recorder switches itself

WuberRec (developer only, `WuberRec\`) is pressed by the Lab bar so nothing is typed: **Start test** switches it on (a fresh 60 minutes),
**End test** switches it off, and **every login** switches it on by itself in every window a few seconds after login
(each window does its own; windows never message each other). The Lab only presses the recorder's own `/rec on` and `/rec off`
(`SlashCmdList.WUBERREC`) from code, inside pcall; the recorder stays read-only, `/rec mark <words>` stays typed and optional.
Turn the login switch off with `/run WuberLabDB.recAuto = false` (back on: `= nil`). A missing recorder is one line in the Lab report
("recorder not available"), never an error in chat. Details: **report\RECORDER-BUTTONS.md**. Offline test: `lua5.1 test/bar_test.lua` (the "recorder:" tests).

## Game facts: the game answers the open "does it do X?" questions

**Game facts** on the Lab bar (after Auto check), or `/lab facts`: passive checks answer by themselves at login and on their events, one press runs
the instant ones and prints what is known, and a small panel has the checks that need your moment. New file `GameFacts.lua`: restart the game once.
Everything is in **GAME-FACTS.md**; the answers are in `WuberLabDB.facts` and `tools\labreport.cmd` prints **== Game facts**.
Offline test: `lua5.1 test/gamefacts_test.lua`.

## Auto check: the game looks over Wuber's screens itself

**Auto check** on the Lab bar, or `/lab auto` (`/lab auto stop`; `/lab auto steps | ride | drive | settings | <screen ids>`
for a part). One click, out of combat, hands off for about 6 minutes: it walks every photo tour screen (demo data,
folded and unfolded, at the window's own size) and 40 extra screens (every Settings section, and the screens that
stand in for a manual step), and on each asks the real game: is any text cut (`FontString:IsTruncated`), off the
screen, on top of another text or half under a card; are two buttons half over each other; does a scroll bar or soft
edge run over something outside its list; is every tooltip (the owner's own `OnEnter`) whole and on the screen.
It presses only a named handful of local buttons (Reset, Replay tips, a switch it puts back), never a secure button,
and nothing that reaches another player; it runs on the photo tour's machinery, so nothing is sent and `WuberDB` is
put back. One screenshot per screen. In chat: "Auto check: 1124 passed, 3 need a look"; after a Reload
`tools\labreport.cmd` prints **== Auto check** (what needs a look, the manual steps it stood in for, each screen's
screenshot file). `python tools\steps2lua.py --auto STEPS-x-SOLO.md` writes the Lab bar's Steps note with only what
Auto check cannot do. Everything else: **AUTO-CHECK.md** (its last section, 22 Nov: seven more screens in `AutoSteps2.lua`, the Steps note keeps its ticks through a Reload, and `tools\steps2lua.py` now REFUSES a steps file that is long-winded, has two checks in a step or a bug code in its words). New files `AutoCheck.lua` and `AutoSteps.lua`: restart the
game once. Offline test: `lua5.1 test/autocheck_test.lua [quick]` (Wuber's fake game, the 2.3.4 tree by default).

## What it does

- **Logs everything** (always on while the addon is enabled) to `WuberLabDB`, one timeline per
  character, at most 6000 lines each (oldest dropped). A line is
  `epoch.ms|character|kind|text`. Logged: login (character, realm, build, versions of Wuber,
  Ritual Rides, OpenMap), every Wuber internal event, the rider's ride stage by stage with the
  time each stage took, Wuber addon messages in and out, Ritual Rides' Wuber calls and log
  calls, invites (the raw inviter name), group changes, the summon box, trades, money
  changes, whispers between your four characters (or with "summon"/"WTB"), system lines about
  players/invites/groups, blocked actions, Lua errors (the game's error handler is chained, and
  BugGrabber is used if present), frame rate and Wuber's memory once a minute while its window
  is open, Wuber's self-test 8 s after login, plus the probes from the code review (UnitName
  returns, protected calls and the trade state, the summon box after accepting, channel joins,
  the Poppins font).
- **The Plan tab** (the panel opens on it): the whole test plan (`TESTPLAN.md`, kept as data in
  `WuberLab/PlanData.lua` - edit both together). Sections fold open and shut with a count
  ("Test 2: a full ride  9/17"); the one with the next unticked step opens by itself. Each step
  has a big tick box, the text wrapped, a "who" tag, Fail, and a note (click the step, type,
  Enter). Steps the lab can see tick themselves ("auto"): the whisper reaching Anita, the invite
  taken with no click, the summon and arrival, the fare paid (typed by the rider), leaving the group, the
  milestone and rating, Ritual Rides' ride log, the bell, Check my game, Trips, the map
  Ctrl-click, hiding, the favourite toast, the busy fake's queue... Before-you-start steps are
  checked at login on each character (Wuber 1.1 files loaded, the addon list, Sound in
  Background on Wuber Rocks, F1 unbound) and tick once all the named characters say ok.
- **Shared by the four characters**: ticks and notes sync over hidden addon messages (prefix
  `WLAB`) only between Anita Lift, Farra Way, Hayley Cab and Wuber Rocks - the group when
  grouped, else whispers to the ones online (the "No player named" line for an offline one is
  hidden). Anyone else is ignored. Newest change wins; each account keeps its own copy.
  Reset plan (Tools) clears it on all four.
- **The Now strip** at the top: the next step in large type with Done and Fail - the plan can be
  run from it alone. **Mini** (header button or `/lab mini`) shows just that strip, always on
  top, movable; it remembers its place and comes back after a /reload. **A- / A+** scale the
  panel and the strip (for a 4K screen).
- **The checklist tabs**: a checklist for the window's role - rider (Wuber Rocks),
  driver (Anita Lift) or team (Farra Way, Hayley Cab). Steps tick themselves when the log sees
  them happen (with the time since the step before); every step has Pass / Fail buttons and a
  note (click the row, type, Enter). The line under the title says what to do next.
- **Tools tab** (all local; nothing is ever sent - no chat, no addon message):
  - *Fake drivers*: five pretend drivers inside this window's Wuber only (cheapest 50s, badges,
    one busy with a queue, one with a spammy name to prove the filter). Book them with Wuber's
    own Request button or the Book buttons. They answer here: accept + queue + decline, decline
    (closed / price), or no answer (timeout). Clear removes them (and any favourite/hide of
    them); a /reload removes them too.
  - *Play every effect*: each Wuber effect in turn with its name on screen.
  - *Fresh rider* / *Restore rider*: backs up and clears the rider's trips, milestones and level
    (to test First Ride), then puts them back. Test trips are dropped on restore.
  - *Mark*: a bookmark line in the timeline (also `/lab mark <text>`).
  - *Run checks*: Wuber's self-test again, results logged. *Role*: override the role.
  - *Reset checklist*.
  - *Snap (screenshot)* (also `/lab snap`): one screenshot of the screen as it is, with the lab's own
    panel stepped aside. The file time is logged and said in chat.
  - *Photo tour* (also `/lab tour`): every Wuber 2.3.0 screen in turn, filled with demo data
    (PhotoShots.lua has the list and the data; Photo.lua runs it). 69 shots, about 1.5 minutes
    (each shot waits until the screen has settled, at most 3 s, and at least 1.1 s and a new clock
    second after the shot before: the game names the file by the second, so two shots in one second
    would leave one file). Every page that unfolds is shot
    folded, then unfolded (720 wide), so the video can show the Fold; the Wuber window stands
    at the same place for every shot (centred for the unfolded width) and goes back where it was.
    Rider: home (drivers near you), home_empty (nobody online: when drivers are usually around,
    bounty, watch), home_bounty, worldmap (unfolded only: routes, boats, driver pins, bounty
    coins), confirm (the dial with the coin icons), portal (violet), portal_founder (Anita's gold
    portal), tracker (the live portal tracker), pay (tip buttons, arrival Share pill), stranger,
    done_paid (Share pill), done_unpaid, raincheck (offered to the rider), trips, wrapped,
    wrapped_summary. Driver: console_open (shard fuel gauge), button_summoning, button_portal,
    button_waiting, console_closed, menu_chat (Send "Get Wuber"), note (the note sheet),
    row_marks (note and Gifted marks with the row's tooltip), customers, crew ("my account"),
    demand (the demand line; Wanted nearby unfolded), pvp (hot-drop warning), raid, earnings
    (the cut ledger unfolded), earnings_heatmap (an hour tapped), earnings_empty, shift (the
    end-of-shift card, fair split), messages, messages_edit (a chip's tooltip). Settings:
    settings (home), settings_driving, settings_search ("price"), settings_nomatch,
    settings_opened (a match highlighted), help.
    **For the launch video**: home_search (a rider looking for a summon to Undercity, drivers
    listed), pass_rider and pass_driver (the two-word passphrase on the rider's screen, and the same words
    on the driver's queue row with its tooltip), wizard_notlock and wizard_summoner (a runner who isn't a
    Warlock: the setup's "My own Warlock (multibox)", then "Who summons?" with two crew Warlocks ticked),
    settings_summoner (Settings > Driving, "Who summons" for that runner), wuber_test (Check my game's
    results and the /wuber test line in chat). **Gated shots** (`L.PHOTO_GATED`; Photo.lua's
    `L.PhotoScreens()` puts each after the screen it names): openmap_pins (OpenMap's world map with the
    demo drivers' pins, the view glided onto them with OpenMapAPI.ShowWorld) and openmap_route (Mia booked,
    so Wuber draws its route from the player to her), both after worldmap, Wuber's window shut, the world
    map shut again after each; bird ("Skip the bird": Wuber's own card from UI.Bird.Show beside the game's
    flight map, the tour's first shot). A gated shot whose need isn't met is left out with one log line
    ("left out openmap_pins, openmap_route: OpenMap isn't loaded"), said in chat at the start too, and
    kept in `WuberLabDB.photoTour.leftOut`; passive play leaves them all out. The OpenMap shots need
    OpenMap ticked; the bird needs the flight map open at a flight master: `/lab tour bird`.
    **Job 042**: for the OpenMap shots OpenMap's window is fitted to the screen (less a margin, centred;
    OpenMapDB.worldmap's window and windowSize for the shot) with the quest list collapsed, the view is
    reframed (OpenMapAPI.ShowWorld, at most 4 times) until every pin, or both route ends, sit inside the
    visible map less a margin, the chat frames step aside for the shot (alpha 0, back once it's saved), and
    a "check:" line in the tour log says whether the pins / route ends were inside the visible map. The
    player's window, its saved values and the quest list are put back exactly after each shot. The bird
    looks for the flight map as Wuber's card does (TaxiFrame, else FlightMapFrame) and also by the flight
    master's events; Mia summons to the longest flight from there that a summon beats (Wuber's own
    FlightCost / FlightTime); in a longer tour the flight map is closed after the bird's shot.
    `/lab tour openmap` and `/lab tour bird` re-shoot those alone; `/lab tour video` takes only the
    video's shots. Offline test: `lua5.1 test/photo_gated_test.lua` (uses Wuber's tests/harness.lua:
    WUBER_TESTS_DIR, default ../tests). The shot list for labreport.js: at each shot the
    timeline gets "tour shot <n>/<total> <id> <folded|unfolded> | <title>" (the log stores "|"
    as "/") and `WuberLabDB.photoTour` = { started, ended, shots = { { n, id, title, view, at } } }
    (the last tour; at is the timeline's epoch.ms clock).
    Out of combat only, not during a ride, not while open as a driver. Hands off:
    a click anywhere stops it, and so do combat, `/lab tour stop`, a logout or /reload. The demo
    data is never sent (Wuber's senders, invites and engine tick do nothing meanwhile, its
    outgoing queues wait, incoming chat and addon messages are not passed to it) and never saved
    (WuberDB is put back exactly as it was). No "DEMO" banner is drawn. The rest of the game UI
    is not hidden (Wuber's phone is a child of the game's UI): close other windows first.
    If the game ever refuses a screenshot from the lab, the tour learns it and asks for a click on
    a "Snap n/69" button (top right) per shot; `/lab tour click` forces that. Shots land in
    `World of Warcraft\_forever_\Screenshots` (`WoWScrnShot_MMDDYY_HHMMSS.jpg`).

Slash: `/lab auto [stop|steps|ride|drive|settings|<screen ids>]` (Auto check, above), `/lab passive on|off|status` (passive play, below), `/lab trail on|off|status`, `/lab huh [words]` (the usage trail, below), `/lab alphaprobe` (the alpha rule probe: four swatches, press Faint or Solid under each; the answer is logged as a `probe` line and kept in `WuberLabDB.alphaProbe`; new file `AlphaProbe.lua`: restart the game once), `/lab f1 allow|require`, `/lab`, `/lab mini`, `/lab done` (ticks the Now step), `/lab scale <0.6-2.5>`, `/lab resetplan`, `/lab mark <text>`, `/lab role rider|driver|team|auto`, `/lab fakes on|off`,
`/lab book cheap|mid|busy|spam|dear`, `/lab fx`, `/lab fresh`, `/lab restore`, `/lab check`,
`/lab reset`, `/lab snap`, `/lab tour [click|stop|ride|drive|float|settings|earnings|video|<ids>]`, `/lab run [all|stop]` (the test run; `all`: passed
checks too), `/lab skip`, `/lab wrong` (Looked wrong), `/lab pretend [stop]`, `/lab logincheck`,
`/lab results reset`.

## The test run (self-marking checks) - the fast way to test

**Start test run** (Tools tab, or `/lab run`) on any of the four windows. The lab takes every check
that hasn't passed yet with this Wuber version, orders them so the tester swaps windows as little as
possible (about 10 minutes; whatever doesn't fit waits for the next run), and tells all four windows.
Then it is one prompt at the top of the screen on every window:

- The window whose turn it is reads, in large type, *who* and *the exact click*: "Anita: click the
  big button (it says Summon Wuber)". The other three read "Waiting for Anita..." with the same
  line underneath. The first step of a scene also says how to stand ("First: Wuber Rocks in another
  zone than Anita").
- **The tester never marks anything.** Each check has a judge that watches what really happens - Wuber's
  own state and events, `GROUP_ROSTER_UPDATE`, `CHAT_MSG_ADDON`, trades, `CONFIRM_SUMMON`, spell
  casts, which Wuber screen is shown, the big button's words, frame strata and visibility - and says
  pass or fail with a short reason. Nothing within the check's time is a fail "didn't happen within
  N s". The prompt moves on by itself and shows the last result ("Last: OK  Request: booked...").
- Buttons: the step's own (Pretend I clicked, Snap, Start photo tour), **Looked wrong** (the last step
  fails, with a screenshot), **Skip**, **Stop**. Only one "look" check: Earnings, one screenshot.
- Windows talk over the lab's own addon messages (prefix `WLAB`, the tester's four characters only,
  paced to stay well inside the game's allowance). A window that /reloads mid-run carries on.
- The run in the catalogue now: **a full ride** (Wuber Rocks books Anita, invite, summon, trade,
  leave, rating, thank-you), then **raid summons with Wuber's window open** (raid made, raid
  summons on with Anita, Farra and Hayley as summoners, window open with the big button on top,
  Wuber Rocks away from the spot, Request from the app, nvm, 123 in raid chat, the big button
  invites and summons, and Farra's and Hayley's windows report that their Wuber never offered or
  cast on the raider Anita took), and **the photo tour** last after one click. In test mode (no
  shards) the portal-click steps are skipped (the pretend ritual needs none).
- A **portal click** passes on the helper's window on any spell of its own starting, going or
  channelling (not its own ritual), the game saying it casts or channels, or Wuber's own click count
  (HELP) - there or on Anita's window, which tells the judge. Every spell event the step hears is
  logged. **Anita takes the fare** passes only on the full fare; less is "part paid" (a fail).
- **Wuber 2.3's in-game probes** (SPEC7 section 10, `Probes.lua`): after the ride, each check stands alone
  and is done on one window: the Fold on the big screen (a width tween, never a scale; the small windows stay
  folded), the world map's art and CreateLine dashes, a timed flight against its estimate and the estimate's
  calibration (both skipped at once, "no flight paths known on this character", when the character's
  last flight map had no place to fly to), TaxiNodePosition at a flight master, an enemy player's
  nameplate (his PvP flag) and GetZonePVPInfo, who the summon box names, the gold portal (and violet for a non-founder), the share macro
  (/p in a party, /ra in a raid, nothing in combat) and the "Skip the bird" card beside the flight map; then
  **the raincheck** as one scene (paid by trade, Anita closes before casting, ask, give, accept, rebook free,
  cancel). What only the tester can judge is one short **Yes / No** on the prompt (No fails it, with a screenshot).
  The summon box, the arrival, share clicks, combat, an enemy player's nameplate and the flight map are watched on
  every window from login (kept in `WuberLabDB.probe8`), so a check about the ride's summon reads what the
  ride showed. A probe that can't be seen yet (no flight timed, no enemy player met) is a skip and comes
  back in the next run. The lab never touches the combat log or community invites: this client blocks
  them for addons (with a "blocked" popup), and a test in Wuber's suite fails if any lab file names them.
- **Wuber 2.3.0's fix round** (`Checks9.lua`, REPORT9 "The tester, in game"; a new file: restart the game fully
  once) goes first in a run (priority 0; what doesn't fit waits for the next run), in this order:
  *the empty Home* (Wuber Rocks, nobody open: its wording, Yes/No); *the customer book* as one scene
  (Anita and Farra each switch on "my account" on the other's Crew card, Anita opens, Wuber Rocks taps her
  card - the coin icons on Confirm, Yes/No - then whispers "WTB summon" by hand; Anita picks Send "Get Wuber"
  in his row menu - judged queued, and a fail if it goes out with no click - then the big button: it must go
  out on a big-button click; a note (saved), the note reaching Farra's window, Gifted, the row's note and
  gift marks with the tooltip's "Note:" and "Gifted on" lines, Take off the list); *the driver's pages*
  (Customers seen folded and unfolded, Yes/No; raid summons outside any group show "Ready to summon?" with
  "Make or join a raid first."; Yes/No looks: small text and greyed buttons, list fades, the header's
  fold button); *Settings search* ("volume", "price" and "passphrase" each with matches, "Show ride
  passphrase" among the last; a match opens highlighted; Esc clears the box and leaves the window and
  Settings open); *the passphrase* as one scene (off by default, turned on in Settings > Driving, Wuber
  Rocks' Wuber hears it from Anita's beacon, off again). About 9 minutes with the tour.
- At the end every window says **"Done: log out or /reload, then tell the person running the test "done"."**

**Login checks** (no clicks, every window, 8 s after login; `/lab logincheck` runs them again):
Wuber loaded, the old summoning addon off, `WUBER`/`WUBERT`/`WLAB` prefixes registered, Wuber's
channel joined, the Wuber community found, flight prices loaded, the big button's strata and
visibility, saved settings sane (price, size, refused features), Wuber's self-test (a failed
"Network channel joined" runs it again 60 s after login before it counts), no Lua errors,
the same Wuber/lab/protocol versions as the other windows, Sound in Background (rider), F1 (it may stay bound: it is the multibox swap key; `/lab f1 require` insists it is unbound) -
and **saved settings survived a restart**: at every logout or /reload the lab writes a marker and a
fingerprint of `WuberDB` (trips, lifetime rides, characters, time value, effects) into `WuberLabDB`;
at the next login both must come back. `WuberDB` coming back different is a fail; `WuberLabDB`
coming back empty is a fail when another window's lab remembers this one (it answers the version
message with when it last saw it), else a skip ("first start here").

**Results** (saved at logout or /reload in `WuberLabDB`): `runs` - the last 8 runs, each with
`lines` = one line per check, `id|window|result|reason|epoch|took|judge|title` (result: pass, fail,
look, skip, todo), plus `sid, by, started, ended, why, sim, wuber, lab, pass, fail, look, skip, todo`;
`run` - the run going on (or the last one) with every result; `results[id]` - the latest result per
check (a check that passed with this Wuber version is not asked again; Tools: *Reset test run
results*); `login[character].lines` - `id|result|reason|epoch|took`; `restart[character]` - the
marker. The timeline has every step and verdict as `run` lines. `labreport` puts it all first, in
plain English.

**Pretend rider** (Tools: *Pretend rider (this window)*, `/lab pretend`): Anita alone steps through
the driver's screens and the big button's states. In her window the lab feeds the messages a real
rider's Wuber would send ("WTB summon to ..." and Wuber's request, later a cancel; a second fake asks
the price) straight into Wuber's own event handler - nothing is sent to anyone. The fakes are called
"Pretend Labfake" and "Asking Labfake"; every invite, whisper, crew message and bell for them is kept
local and the big button never holds a line naming them. Each state stays up a few seconds for the tester
to see. Joining the group, the summon and the trade need a real second player: marked skipped,
"needs the rider account". Refused on any window but Anita's, unless selling, in combat, during the
photo tour, with raid summons on, or while a real ride, rider, request, raid row, ritual or trade is
going on; a real player asking meanwhile stops it at once. Afterwards the fakes leave every list and
`WuberDB` is put back exactly as it was (checked for leftovers; a logout or combat does the same).

## Passive play - the lab checks normal play by itself

For a session of ordinary play (log in, sell summons or ride, log out) instead of a sit-through run.
**Off by default.** Turn it on once per account with `/lab passive on` (or *Passive play* in the Tools tab);
it stays on until `/lab passive off`. `/lab passive status` says what it has judged this session and what
the release checklist still needs. The guided run (`/lab run`) stays for releases.

While it is on, every one of these marks itself pass, fail, skip or look, with the reason:

- **ride** (the rider's window): every real ride - done passes, failed fails, cancelled / declined / no
  answer is a skip (not Wuber's doing), 20 minutes in one stage fails ("stuck").
- **customer** (driver and crew windows): every real rider on the queue - arrived passes, else a skip.
- **trade**: every trade that moved gold, 6 s after it closed. Gold in from a customer passes when Wuber
  marked them paid (DRIVE_PAID); gold out to the ride's driver passes when the ride counts it.
- **summon**: every big-button click that summons (Wuber's "cast" mark): a cast starts within 8 s.
- **portal**: a click on a crew mate's summoning portal (a channel starts here during their ritual):
  Wuber counts it (HELP) within 10 s.
- **crew**: a crew window that joins the group: its Wuber says hello (the crew sync) within 45 s.
- **login**: the login checks (above), once they are all in.
- **blocked** / **error**: every blocked action fails (ADDON_ACTION_BLOCKED / _FORBIDDEN, Wuber's
  BLOCKED); a session of 10 minutes or more with none passes at logout. Wuber's Lua errors fail; other
  addons' are a look.
- **tour**: the photo tour, by itself, once per Wuber version: after 2 minutes with no input, in a city
  (IsResting, not in an instance), not in a group, out of combat, no ride, not open as a driver. A 5 s
  countdown in chat first. **Any input stops it** (and the countdown): a key (a keyboard watcher that
  passes every key on), the mouse moving or clicking, moving, a cast, a target, typing in chat, a
  vendor/NPC/mail/bank window, combat, a whisper, invite, summon or trade from a real player (those go on
  to Wuber at once). A stopped tour is a skip and tries again when idle (twice a session at most).

It **never sends anything** (no addon message, whisper or chat line) and **never acts for the player**
(no click, cast, target, invite, key or trade call): it only reads Wuber's state and the game's events,
and the tour's only action is Screenshot() (its demo data is never sent or saved, as for `/lab tour`).
In combat it pauses (nothing new is judged, the keyboard watcher hides); blocked actions and errors are
still noted. While off nothing is wired and nothing is saved. Fake drivers, the pretend rider, test mode
and a running test run are never judged.

Results: `WuberLabDB.passive` (saved at logout or /reload) - `sessions` (the last 10: character, Wuber
version, taint log on or off, counts, one line per verdict `kind|subject|result|reason|epoch|took`),
`release` (the newest pass and fail per kind: the release checklist's evidence) and `tours` (per Wuber
version). `labreport` prints "== Passive play": the release checklist as passive play saw it ([x] proved,
[!] failed last, [ ] not seen yet) and each session's fails. New file `Passive.lua`: restart the game once.

## Usage trail and the Huh key - find where the tester struggled

For an hour of ordinary play with only a voice recording: the lab writes down what happened on Wuber's
screens, with the real clock time, and the report finds the struggles. **Off by default**, apart from
passive play (it never starts the photo tour; passive play's idle tour waits while the trail is on).

- `/lab trail on|off|status` (or *Usage trail* in the Tools tab). Saved in `WuberLabDB.trail.on` (all
  characters of the account), so it comes back on after a /reload or the next login.
- While on, lines of kind `trail`, each starting with `HH:MM:SS` (the game's `date()`, the PC's clock):
  `open|close window` (also mini bar, floating button, drive window, bell, crew offer, bug report, map),
  `tab Drive (from Ride)`, `screen Ride/home` (Drive/console, Drive/earnings, settings, help, Trips...),
  `click "Go online" on Drive`, `hover "Price" 1.4s (tooltip) on Drive` (0.3 s or more; a hover that
  ends in a click is just the click), `type in "Where to?" on Ride` (never the text), `setting autoAccept:
  true -> false` (a slider's drag is one line once it rests 1.5 s; a quick toggle is `a -> b -> a (back)`;
  text settings are masked). A line said with the window open ends with ` @ <screen>`. No chat text.
- HookScript only (never SetScript, never a protected call); Wuber's frames are hooked when they first show
  and new children are found by a walk after clicks, page changes and every few seconds while a window is
  open (one 2 s ticker, no OnUpdate). Nothing is hooked in combat: it waits for PLAYER_REGEN_ENABLED. The
  photo tour pauses it (`trail paused (photo tour)` ... `trail resumed`).
- **The Huh key**: Esc > Options > Keybindings > WuberLab > "Huh: mark + screenshot" (Bindings.xml; the game
  loads it from the folder by itself, so the TOC only names it in a comment), `/lab huh [words]`, or the
  *Huh* button in the Tools tab (the text box's words go with it). One `huh` line - the clock time, the
  words, the last 30 s of the trail in one line - then `L.Snap()` (one screenshot). Works with the trail
  on or off.
- `WuberLabDB.trail.lines` keeps a copy of every trail and huh line (the newest 4000), so an hour of play
  survives the timeline's 6000-line cap. New files `Trail.lua` and `Bindings.xml`: restart the game once.

`labreport` then prints **== Struggles** (console, `lab-latest.txt`, `trail-latest.txt`, the HTML), each with
its clock time and the nearest `WoWScrnShot_MMDDYY_HHMMSS.jpg` in `_forever_\Screenshots`:
tab hopping (3+ switches between the same two tabs within 60 s), hover hunting (5+ hovers with no click
within 20 s), toggled back (a setting changed and changed back within 60 s), reopening (the same screen
opened 3+ times within 2 minutes), long pause (45 s+ on one screen with the window open and no action;
hovers are not actions) and every Huh. `report\trail-latest.txt` also has **== Trail timeline**: one line per
trail line, `HH:MM:SS | screen | action` (Huh lines marked `>>>`), to line up with the voice transcript.
Tests: `lua5.1 test/trail_test.lua` (fake frames) and `node --test test` (the pattern finder).

## How to add a check

Checks live in `WuberLab/Checks.lua` (and `Pretend.lua`; Wuber 2.3's probes in `Probes.lua`; the 2.3.0 fix round in `Checks9.lua`); `WuberLab/Run.lua` runs them. A
**scene** is a group of checks that share state and always run whole, in their order:

```lua
L.AddScene({ id = "ride", title = "A full ride", prio = 2,      -- lower prio = sooner into a run
	after = "ride",          -- (optional) runs after that scene when both are in a run
	linked = false,          -- (optional) each check stands alone and may be ordered freely
	only = true,             -- (optional) never in "Start test run" (its own tool starts it)
	loc = true,              -- (optional) one window only: no run messages are sent
	intro = "Wuber Rocks in another zone",  -- (optional; or function(ctx)) said at its first step
})
```

A **check** (`L.AddCheck{...}`; a bad one is refused with the reason, never raised):

| field | meaning |
|---|---|
| `id` | letters, digits, `_`; unique (the results are kept by it) |
| `title` | a few words, shown on the prompt and in the report |
| `scene` | the scene id (default `loose`: unlinked) |
| `who` | the window the tester acts in: `driver` (Anita Lift), `rider` (Wuber Rocks), `crew1` (Farra Way), `crew2` (Hayley Cab) |
| `judge` | the window that judges (default `who`): where the outcome can be seen |
| `click` | the exact click, string or `function(ctx)`; `{button}` is replaced by the big button's live words (`buttonText` when it isn't on that window) |
| `say` | for a step with nothing to click: what happens by itself |
| `secs`, `timeout` | estimate for ordering (default 15) and the limit (default 45): no verdict within it = fail |
| `hold` | (optional) a pass waits this many seconds, so the tester sees the state |
| `begin(ctx)` | (optional) when the step starts on the judge's window; may return a verdict |
| `poll(ctx)` | twice a second on the judge's window; return `"pass"`/`"fail"`/`"skip"`/`"look"`, reason |
| `watch`, `test(ctx, event, ...)` | events to hear: game events (`"TRADE_CLOSED"`), Wuber's own (`"wuber:DRIVE_PAID"`), lab signals (`"sim_click"`), `"fact"` (from another window). Events from the 20 s before the step began are replayed into it |
| `when(ctx)` | (optional) return `"skip", why` to skip it (e.g. in test mode: `ctx.sim`) |
| `onTimeout(ctx)` | (optional) the verdict at the limit instead of the plain fail |
| `button` | (optional) `{ label, run = function(ctx) ... end, show = function(run) }`: the prompt's action button on `who`'s window (may return a verdict) |
| `also`, `observe(o)`, `observePoll(o)` | (optional) other windows that report to the judge: `o.Tell(text)` arrives as a `"fact"` event (`from`, `text`) |
| `kind` | `"look"` (a screenshot for the reviewer; keep these rare) or `"skip"` (always skipped, `say` is the reason) |
| `ask` | (optional) a Yes/No for what only the tester can judge: the question, or `function(ctx)` returning it (nil: not yet, while the lab still watches). Yes and No buttons on `who`'s window, which is then also the judge. Keep it short |
| `answer(ctx, yes)` | (optional) the verdict for the tester's answer (nil: keep watching; `ctx.data.answer` is `"yes"`/`"no"`); without it Yes passes and No fails. A No that fails takes a screenshot |
| `login = true` | a login check instead: no click, `who` = `any`, `cast` (the tester's four) or a role |

`ctx` has `W`, `DR` (`W.Drive`), `UI`, `t` (seconds since the step began), `data` (yours, per
step; `data.waitWhy` becomes the timeout's reason), `sim` (test mode). `L.J` has shared helpers:
`J.key(role)`, `J.cust(role)` (the rider's queue entry on a driver window), `J.ride()`, `J.title()`
(the big button's words), `J.button()` (shown, visible, docked above Wuber's window?),
`J.textShown(part)` (a visible text in Wuber's window), `J.inGroupWith(role)`, `J.selling()`,
`J.onDrive()`, `J.money(copper)`.

**Worked example** - SPEC7 10.6, "`C_SummonInfo.GetSummonConfirmSummoner()` exists and returns the
founder's name", judged on Wuber Rocks when the game's summon box comes up:

```lua
L.AddScene({ id = "probes23", title = "2.3 probes", linked = false, prio = 4 })

L.AddCheck({ id = "p23_summoner", title = "Who is summoning", scene = "probes23", who = "rider",
	secs = 30, timeout = 120,
	click = "accept nothing yet: wait for Anita's summon box",
	watch = { "CONFIRM_SUMMON" },
	test = function(ctx)
		local SI = C_SummonInfo
		if type(SI) ~= "table" or type(SI.GetSummonConfirmSummoner) ~= "function" then
			return "fail", "C_SummonInfo.GetSummonConfirmSummoner is missing"
		end
		local ok, name = pcall(SI.GetSummonConfirmSummoner)
		if ok and type(name) == "string" and name:find("^Anita") then return "pass", "it says " .. name end
		return "fail", "it returned " .. tostring(name)
	end })
```

Then: a test for it in Wuber's suite (`tests/lab_run.lua` has the whole run on four windows to copy
from), `/reload` is not enough for a new file - restart the game - and "Reset test run results" is
not needed: a new check is pending until it passes.

## Install (testing only)

1. Copy the `WuberLab` folder into
   `<WoW folder>\_forever_\Interface\AddOns\` (next to `Wuber` and
   `RitualRides`). One copy serves all four accounts.
   **Close every WoW window fully first**: lab 1.1 adds files (`Run.lua`, `Checks.lua`,
   `Pretend.lua`, `Prompt.lua`) and lab 1.2 adds `Probes.lua`, which a /reload doesn't load.
2. In each character's AddOns list make sure Wuber Lab is ticked.
3. Play the test plan. `/lab` opens the checklist.
4. **Type `/reload` in every window (or log out) before making the report** - the game writes
   saved variables to disk only then.

## The report

Double-click `tools\labreport.cmd`, or with another game folder:

```
tools\labreport.cmd "<WoW folder>\_forever_\WTF"
node tools\labreport.js [WTF folder] [--out <folder>] [--shots <Screenshots folder>]
```

It reads every `WTF\Account\*\SavedVariables\WuberLab.lua` (relative to the `_forever_` folder) (a small parser - the files are
never run), merges all characters by time and writes:

- A "Photo tour" table (console, `lab-latest.txt` and the HTML): each shot of the last `/lab tour` (id, title, folded/unfolded) with its `WoWScrnShot_MMDDYY_HHMMSS.jpg` from `_forever_\Screenshots` (matched by time within 2 s; else "no file" and the expected name).
- `report\lab-YYYYMMDD-HHMM.html` - characters, errors and blocked actions (red), each ride as
  swimlanes (rider and driver) with stage durations, the checklist with Pass/Fail and notes,
  self-test results, the shared Plan (tick time, who ticked, auto or manual, Pass/Fail, note,
  probe results), and the whole timeline with a column per window (filterable).
- `report\lab-latest.txt` - the test run first, in plain English (what passed, what failed and
  why, what to look at, what wasn't reached, earlier runs), the login checks of every window, then
  a plain summary (with the Plan) plus the last 400 merged lines (for the reviewer to read). The test run
  and the login checks are printed to the console too.

Tests: `node tools/test/labreport.test.js` (uses the samples under `tools/test/sample` and
`tools/test/sample-run`, written by Wuber's harness: `LAB_DUMP=<dir>` and `LAB_DUMP_RUN=<dir>`).
The addon's own tests are in Wuber's suite: `tests/lab.lua`, `tests/lab_photo.lua` and
`tests/lab_run.lua` (run with `WUBER_LAB_DIR=<this repo>/WuberLab`).

## Release check - run before every upload

```
node tools\release-check.js "<path>\Wuber-1.1.0.zip"
node tools\release-check.js "<path>\release\Wuber"
```

Fails (exit code 1) if the folder or zip contains `WuberLab` or any file that mentions it.

## Auto check screenshots

The Auto check runs every check on every screen (the real game's fonts, IsTruncated, hit order), but takes a screenshot only of a
screen where a check says "look", and once the first time a screen appears (the "new screens" list, `WuberLabDB.autoSeen`, kept
in SavedVariables). `/lab auto shots` photographs every screen, the old way (add screen words after it: `/lab auto shots ride`).
The Photo tour is not a routine step: the Lab's next-step lists include it only when marketing pictures need refreshing. The
Photo tour button always runs the full tour (the bird shot too when the game's flight map is open, left out with a note when not).

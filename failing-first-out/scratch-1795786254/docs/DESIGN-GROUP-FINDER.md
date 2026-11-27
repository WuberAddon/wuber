# Design: the Group Finder listing (2.5 headline, DRAFT proposal)

Status: **decision draft, waiting for the maintainer's yes.** Built on branch `claude/decision-group-finder` behind the
setting `groupFinder` (off by default). Every player-facing word in this feature is a **draft** (listed in one table,
`Net/GroupFinder.lua` `DRAFT_WORDS`); none is approved wording. Nothing here is proven in the real game.

## The problem
Riders hear drivers only through beacons on Wuber's hidden channel. When the channel splits into copies, or riders sit on
another layer, they miss drivers and hear at most the [Wuber] chat advert. The game's own Group Finder list is
realm-wide: it shows each listed player's zone and the listing's note, to every player, with or without Wuber.

## What the game allows (read from the game's own UI code for build 71037 and from LFG Forever; text only)
| Fact | Source |
|---|---|
| `C_LFGList.CreateListing` / `UpdateListing` have restrictions and their data has **no note field**: the note comes from Blizzard's own protected edit box | LFGListInfoDocumentation.lua:70-87, :959-976; Blizzard_LFGVanilla_Listing.lua:264-328, :1164-1189 |
| LFG Forever never creates a listing itself: it post-hooks Blizzard's own Post button and waits for `LFG_LIST_ACTIVE_ENTRY_UPDATE` on its own event frame; hooking Blizzard's listing functions tainted Blizzard's follow-up search | LFG Forever core/blizzardlisting.lua:1-115 |
| `C_LFGList.RemoveListing()` from addon code delisted in and out of combat (author's probe from /run, a key press) | LFG Forever core/listpanel.lua:681-692 |
| `C_LFGList.Search` works from an addon button click (also in combat); refused from an event or timer; one at a time, 15 s give-up | LFG Forever core/filterpanel_search.lua:883-940, :773-780 |
| Results: `GetSearchResults`, `GetSearchResultInfo` (leaderName, comment, activityIDs), `GetSearchResultPlayerInfo` (name, areaName). In dungeons, raids and restricted maps every field is secret except partyGUID: guard with `canaccessvalue` | LFGListInfoDocumentation.lua:394-446, :978-989; LFG Forever core/listpanel.lua:18-37 |
| Category ids are chosen at run time from the available activities | Blizzard_LFGVanilla_Browse.lua:239-275 |
| A listing makes the lister a "group": other players can apply | game UI |
| The Group Finder window is Blizzard's `LFGParentFrame` (load on demand, `## Secure: 1`), opened by `LFGVanilla_ToggleFrame` / `ShowUIPanel` | Blizzard_LFGVanilla_ParentFrame.lua:107-150 |

Background: the author's study of LFG Forever, ideas 5 and 6.

## Decisions (Claude's picks, checked by Fable)
Fable (claude-fable-5-2) was asked once, with all six questions in one batch (24 Nov 2026, 23:01). It agreed with every
pick and tightened three of them; its advice is followed below. Its words, shortened:

| # | Question | Built here (Claude's choice) | Other option(s) | Fable |
|---|---|---|---|---|
| Q1 | How a driver gets listed | **A.** Wuber shows a "List me in the Group Finder" sheet with the draft note to copy and the steps; the driver posts with **Blizzard's own Post button**. Wuber never calls CreateListing, never writes a Blizzard field, never hooks Blizzard's listing frames. "Listed / not listed" comes only from `LFG_LIST_ACTIVE_ENTRY_UPDATE` + `HasActiveEntryInfo`. | B: Wuber calls CreateListing itself (unproven from addon code; cannot write the note) | A: "the only route the evidence supports". Guard: Wuber never writes, selects or hooks anything of Blizzard's. |
| Q2 | How riders find listed drivers | **A, tightened by Fable.** A "Search the Group Finder" button (real click) runs `C_LFGList.Search`. A result marks a driver card only when its leader is a driver Wuber **already knows** (`W.drivers`) **and** its note mentions Wuber. Unknown leaders whose note mentions Wuber only add to a count line; no names, no cards. | B: unknown leaders as "unconfirmed" cards (breaks "only [Wuber] drivers"). C: read-only hook on Blizzard's browse list. | A + "known AND note mentions Wuber", else a driver listed for a dungeon looks like he offers summons. |
| Q3 | Delisting | **A.** Only on the driver's own clicks: "Remove my listing", and the driver's Go offline click while the setting is on. Never from a timer or event. When the driver goes offline any other way while still listed, Wuber shows a "still listed" reminder with the Remove button. | B: also auto-delist from events | A: "/run is still a hardware event; it says nothing about timers". |
| Q4 | Applicants | **A.** Wuber ignores applicants: no applicant event, no applicant API, never invites or declines from the Group Finder, never sets auto-accept. | B: a soft "X applied" hint | A; B is a later call for the maintainer. |
| Q5 | Search category | **A, modified by Fable.** One resolver `GF.SearchCategory()`: the driver's own active entry first, then the probed constant `CATEGORY` (nil until the Lab probe), then Blizzard's own default rule (the first category among the available activities). No matching of activity names. No category: the search button is disabled with a reason and no Search call is made. | B: hard-code one id | A-modified. Risk: driver and rider categories differ; the steps name the category to choose. |
| Q6 | Scope | **A.** Driver side and rider side both, separable (rider search + match in `Net/GroupFinder.lua`; screens in their own commits). | B: rider side only | A: "the two halves only prove out together". |

One change from Q1 as asked: Wuber does **not** open Blizzard's window from its own code. Opening it from a tainted
path (`ShowUIPanel` / `LFGVanilla_ShowFrame` from addon code) is exactly the risk Fable puts first in the Lab list (it
can taint the listing tab's state so Blizzard's Post is refused, as LFG Forever saw). The sheet says how to open it
(the Group Finder key or the minimap eye). A one-click opener (a secure button that clicks Blizzard's eye button) is a
follow-up once the Lab probe has the frame's name and proves the Post still works after it.

## How it works (API contract, `Wuber/Net/GroupFinder.lua`, module `Net.GroupFinder`)
- Setting `W.db.groupFinder` (default `false`), Settings toggle row (draft label). Off: every handler returns at once,
  no C_LFGList call at all, the screens look exactly as in 2.4.2.
- `GF.On()` -> boolean.
- **Rider:** `GF.Search()` is called only from the button's OnClick. Returns `true` or `false, reason`
  (`"off"`, `"busy"`, `"nocategory"`, `"nolfg"`). It sets a pending flag; a 15 s timer gives up.
  `LFG_LIST_SEARCH_RESULTS_RECEIVED` is handled only while Wuber's own search is pending (a search made by Blizzard's
  window or another addon is not Wuber's). Each result: skip any field `canaccessvalue` refuses; leader key
  `W.Key(leaderName)`; listed when `W.drivers[key]` exists and the note contains "wuber" (any case). The listed table
  is replaced on every search (a driver missing from the new results is cleared) and entries expire after 10 minutes.
  `GF.ListedZone(key)` -> zone text or nil; `GF.ExtraCount()` -> listings that mention Wuber with an unknown leader.
  `LFG_LIST_SEARCH_FAILED` ends the pending search. Fires `W.Fire("GROUPFINDER")` after each change.
- **Driver:** `GF.MyListing()` -> boolean, from `C_LFGList.HasActiveEntryInfo()`, refreshed on
  `LFG_LIST_ACTIVE_ENTRY_UPDATE`. `GF.Delist()` only from a click: calls `C_LFGList.RemoveListing()` (in pcall) when
  the setting is on and an entry exists. The Go offline click calls it too; going offline still completes if it fails.
  `GF.StillListed()` -> true when the driver is offline but the listing is still there (the reminder).
- **Never:** CreateListing, UpdateListing, applicant calls, invites, whispers, chat, hooks on Blizzard frames.

## Draft words (for the maintainer; none is final)
Kept in `DRAFT_WORDS` in `Net/GroupFinder.lua`. The note the driver types by hand (the game's Note box refuses paste): "Wuber summons to <dest>".
Buttons: "List me in the Group Finder", "Remove my listing", "Search the Group Finder". Card line: "In the Group Finder,
<zone>". Count line: "<n> more listings mention Wuber: open the Group Finder". Reminder: "You are offline but still
listed in the Group Finder". Settings: "Group Finder (preview)" / "Find and be found through the game's Group Finder".

## In-game proof (the Lab step list, for the maintainer; none of this is automatable, it needs clicks and two characters)
1. Lab probe: `/dump C_LFGList.GetAvailableActivities()` and each activity's `categoryID`; note which category a solo
   Warlock can list in. Put that id into `CATEGORY`.
2. On the driver: turn the setting on, open Blizzard's Group Finder by its key, Create Listing, paste the draft note,
   press Post. Wuber's driver tab says Listed. No "blocked" message, and Blizzard's own follow-up search shows the listing.
3. On a second character with Wuber: press "Search the Group Finder". The driver's card shows the Group Finder line with
   the driver's zone. Blizzard's own browse panel still works after it.
4. Driver presses Go offline: the listing disappears (Blizzard's eye stops). Repeat with "Remove my listing".
5. Open question (Fable): what happens to the listing when the driver invites a rider for a summon, or is not the
   leader of his group. Watch Blizzard's eye and Wuber's status during one real ride.

## What was built and how it is tested
- `Wuber/Net/GroupFinder.lua` (module `Net.GroupFinder`, API above, plus `GF.Pending()`), the setting `groupFinder`
  (Settings, Driving), the driver console's Group Finder card and its sheet, and the rider's search row, card line
  and count line (Home). Going offline by a click on the Open pill or the mini console's Close also removes the listing.
- A fake Group Finder in the test game (`tests/lib/fake_lfglist.lua`): Search refused without a hardware click,
  results a second later by event, failing and silent searches, a search made by Blizzard's own window, secret
  fields (all or some), the game's `(count, ids)` result shape, a log of every call with whether it ran inside a click.
- Tests in `tests/gf/` (a: core, b1: driver and Settings, b2: rider, c: the reviewer's points, d: layout), each
  written to fail first; layout scenes `gf_console_*`, `sheet_gf_list`, `home_gf*`.
- One layout decision: on an empty Home with a bounty to pin, when the search card would push "Pin a bounty" out of
  view, the card goes under the empty stack (one scroll away) instead of on top.

## Not proven / open
- Everything above is from code reading; the fake game encodes these facts, so green tests show the design is
  consistent, not that the game agrees.
- Category mismatch between driver and rider is the largest design risk.
- The one-click opener (see Q1) is left out on purpose.

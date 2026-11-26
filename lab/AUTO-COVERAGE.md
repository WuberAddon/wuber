# Auto check coverage of the layout check's screens

The layout check (tools/layout-check.lua) looks at every screen it knows. Every one of those screens must also have a row in the Lab's Auto check (`L.AutoScreens()` is `L.PHOTO_SCREENS` plus `L.AUTO_SCREENS`), or be named in `L.AUTO_MANUAL` with the reason it stays a hand step.

The layout check knows three kinds of screen:

1. The photo tour's own screens (`L.PHOTO_SCREENS`, PhotoShots.lua). The Auto check runs all of them.
2. The extra screens that tests/layout/extra_screens.lua adds at tour time (and the files it chains: f3_e, dec_q, d4_h, d4_c, sheet_states, f3_j, dec_n, dec_r, rem, d4_d _screens.lua). The Auto check has its own copy of each in AutoLayout.lua and AutoLayout2.lua, with the same id, side, title, views and set-up.
3. The late-font scenes in tests/layout/run.lua (`Run.SCENES`). These cannot run in the real game and are in `L.AUTO_MANUAL`.

Two screens, settings_summoner and settings_bug, are skipped on purpose by the layout check (Settings rows the 2.4 diet removed), so they are not listed.

To run only the ported rows: `/lab auto <id> <id> ...` (an id or its start), or `/lab auto steps` for every row that is not a tour screen.

## Every screen, one row each

| Screen id | Auto check row: file | Views |
|---|---|---|
| home | PhotoShots.lua (the photo tour) | folded+unfolded |
| home_search | PhotoShots.lua (the photo tour) | folded+unfolded |
| home_empty | PhotoShots.lua (the photo tour) | folded+unfolded |
| home_bounty | PhotoShots.lua (the photo tour) | folded+unfolded |
| worldmap | PhotoShots.lua (the photo tour) | unfolded |
| confirm | PhotoShots.lua (the photo tour) | folded+unfolded |
| portal | PhotoShots.lua (the photo tour) | folded |
| portal_founder | PhotoShots.lua (the photo tour) | folded |
| tracker | PhotoShots.lua (the photo tour) | folded |
| pass_rider | PhotoShots.lua (the photo tour) | folded |
| pay | PhotoShots.lua (the photo tour) | folded |
| stranger | PhotoShots.lua (the photo tour) | folded |
| done_paid | PhotoShots.lua (the photo tour) | folded |
| done_unpaid | PhotoShots.lua (the photo tour) | folded |
| raincheck | PhotoShots.lua (the photo tour) | folded |
| trips | PhotoShots.lua (the photo tour) | folded+unfolded |
| wrapped | PhotoShots.lua (the photo tour) | folded+unfolded |
| wrapped_summary | PhotoShots.lua (the photo tour) | folded+unfolded |
| console_open | PhotoShots.lua (the photo tour) | folded+unfolded |
| button_summoning | PhotoShots.lua (the photo tour) | folded+unfolded |
| button_portal | PhotoShots.lua (the photo tour) | folded+unfolded |
| button_waiting | PhotoShots.lua (the photo tour) | folded+unfolded |
| console_closed | PhotoShots.lua (the photo tour) | folded+unfolded |
| menu_chat | PhotoShots.lua (the photo tour) | folded |
| note | PhotoShots.lua (the photo tour) | folded |
| row_marks | PhotoShots.lua (the photo tour) | folded+unfolded |
| pass_driver | PhotoShots.lua (the photo tour) | folded+unfolded |
| customers | PhotoShots.lua (the photo tour) | folded+unfolded |
| customers_queued | PhotoShots.lua (the photo tour) | unfolded |
| crew | PhotoShots.lua (the photo tour) | folded |
| wizard_notlock | PhotoShots.lua (the photo tour) | folded |
| wizard_summoner | PhotoShots.lua (the photo tour) | folded |
| demand | PhotoShots.lua (the photo tour) | folded+unfolded |
| pvp | PhotoShots.lua (the photo tour) | folded+unfolded |
| raid | PhotoShots.lua (the photo tour) | folded+unfolded |
| earnings | PhotoShots.lua (the photo tour) | folded+unfolded |
| earnings_heatmap | PhotoShots.lua (the photo tour) | folded+unfolded |
| earnings_tips | PhotoShots.lua (the photo tour) | folded+unfolded |
| earnings_empty | PhotoShots.lua (the photo tour) | folded+unfolded |
| shift | PhotoShots.lua (the photo tour) | folded |
| messages | PhotoShots.lua (the photo tour) | folded+unfolded |
| messages_edit | PhotoShots.lua (the photo tour) | folded+unfolded |
| settings | PhotoShots.lua (the photo tour) | folded+unfolded |
| settings_driving | PhotoShots.lua (the photo tour) | folded+unfolded |
| settings_search | PhotoShots.lua (the photo tour) | folded+unfolded |
| settings_nomatch | PhotoShots.lua (the photo tour) | folded+unfolded |
| settings_opened | PhotoShots.lua (the photo tour) | folded+unfolded |
| settings_invite | PhotoShots.lua (the photo tour) | folded+unfolded |
| settings_invite_warning | PhotoShots.lua (the photo tour) | folded+unfolded |
| help | PhotoShots.lua (the photo tour) | folded+unfolded |
| help_bug | PhotoShots.lua (the photo tour) | folded+unfolded |
| wuber_test | PhotoShots.lua (the photo tour) | folded |
| bug_window | PhotoShots.lua (the photo tour) | folded |
| float_open | PhotoShots.lua (the photo tour) | folded |
| float_paused | PhotoShots.lua (the photo tour) | folded |
| float_paused_queue | PhotoShots.lua (the photo tour) | folded |
| float_summon_sent | PhotoShots.lua (the photo tour) | folded |
| float_invited | PhotoShots.lua (the photo tour) | folded |
| float_arrived | PhotoShots.lua (the photo tour) | folded |
| float_queued | PhotoShots.lua (the photo tour) | folded |
| float_queued_member | PhotoShots.lua (the photo tour) | folded |
| float_summon | PhotoShots.lua (the photo tour) | folded |
| float_trade_accept | PhotoShots.lua (the photo tour) | folded |
| float_trade_accept_hand | PhotoShots.lua (the photo tour) | folded |
| float_trade_waiting | PhotoShots.lua (the photo tour) | folded |
| float_trade_offer | PhotoShots.lua (the photo tour) | folded |
| float_portal_click | PhotoShots.lua (the photo tour) | folded |
| float_crew_summons | PhotoShots.lua (the photo tour) | folded |
| float_crew_clicks | PhotoShots.lua (the photo tour) | folded |
| float_no_shards | PhotoShots.lua (the photo tour) | folded |
| float_lead | PhotoShots.lua (the photo tour) | folded |
| float_cantpause | PhotoShots.lua (the photo tour) | folded |
| float_combat | PhotoShots.lua (the photo tour) | folded |
| float_closed | PhotoShots.lua (the photo tour) | folded |
| float_raid_summon | PhotoShots.lua (the photo tour) | folded |
| float_raid_paused | PhotoShots.lua (the photo tour) | folded |
| float_raid_wants | PhotoShots.lua (the photo tour) | folded |
| float_raid_idle | PhotoShots.lua (the photo tour) | folded |
| float_raid_stopped | PhotoShots.lua (the photo tour) | folded |
| chat_home | PhotoShots.lua (the photo tour) | folded+unfolded |
| chat_float | PhotoShots.lua (the photo tour) | folded |
| tipcard | AutoLayout.lua | folded+unfolded |
| worldmap_sea | AutoLayout.lua | unfolded |
| confirm_avg900 | AutoLayout.lua | folded+unfolded |
| confirm_avg59 | AutoLayout.lua | folded+unfolded |
| console_summons45 | AutoLayout.lua | folded+unfolded |
| console_summons900 | AutoLayout.lua | folded+unfolded |
| home_usual | AutoLayout.lua | folded+unfolded |
| confirm_usual_long | AutoLayout.lua | folded+unfolded |
| confirm_usual_summoner | AutoLayout.lua | folded+unfolded |
| confirm_dial | AutoLayout.lua | folded+unfolded |
| confirm_dial_low | AutoLayout.lua | folded+unfolded |
| finding_grouped | AutoLayout.lua | folded+unfolded |
| blocked_off | AutoLayout.lua | folded+unfolded |
| blocked_full | AutoLayout.lua | folded+unfolded |
| settings_check_long | AutoLayout.lua | folded+unfolded |
| confirm_dial_zeppelin | AutoLayout.lua | folded+unfolded |
| console_join | AutoLayout.lua | folded+unfolded |
| sheet_places | AutoLayout2.lua | folded+unfolded |
| wizard_noanswer_long | AutoLayout.lua | folded |
| crew_noanswer_long | AutoLayout.lua | folded |
| home_busy_long | AutoLayout.lua | folded+unfolded |
| home_search_long | AutoLayout.lua | folded+unfolded |
| inflight | AutoLayout.lua | folded+unfolded |
| console_summon_long | AutoLayout.lua | folded+unfolded |
| console_summon_seen | AutoLayout.lua | folded+unfolded |
| float_summon_held | AutoLayout.lua | folded |
| done_unpaid_mail | AutoLayout.lua | folded |
| customers_mail | AutoLayout.lua | folded+unfolded |
| note_serve | AutoLayout.lua | folded |
| customers_serve | AutoLayout.lua | folded+unfolded |
| d4c_ride_stranger | AutoLayout.lua | folded |
| d4c_ride_pay | AutoLayout.lua | folded |
| d4c_ride_tabs | AutoLayout.lua | folded |
| d4c_home_ride | AutoLayout.lua | folded+unfolded |
| sheet_fm_unknown | AutoLayout2.lua | folded+unfolded |
| sheet_done | AutoLayout2.lua | folded |
| sheet_home_online | AutoLayout2.lua | folded+unfolded |
| whatsnew | AutoLayout2.lua | folded+unfolded |
| whatsnew_list | AutoLayout2.lua | folded+unfolded |
| settings_sending | AutoLayout2.lua | folded+unfolded |
| settings_undo | AutoLayout2.lua | folded+unfolded |
| settings_undo_news | AutoLayout2.lua | folded+unfolded |
| messages_line_greet | AutoLayout2.lua | folded+unfolded |
| messages_line_pay | AutoLayout2.lua | folded+unfolded |
| messages_line_next | AutoLayout2.lua | folded+unfolded |
| simple_home | AutoLayout2.lua | folded |
| simple_home_empty | AutoLayout2.lua | folded |
| simple_confirm | AutoLayout2.lua | folded |
| simple_ride | AutoLayout2.lua | folded |
| simple_pay | AutoLayout2.lua | folded |
| simple_done | AutoLayout2.lua | folded |
| simple_trips | AutoLayout2.lua | folded |
| simple_settings | AutoLayout2.lua | folded |
| simple_settings_driving | AutoLayout2.lua | folded |
| simple_console_open | AutoLayout2.lua | folded |
| simple_console_closed | AutoLayout2.lua | folded |
| simple_menu | AutoLayout2.lua | folded |
| simple_sheet | AutoLayout2.lua | folded |
| simple_earnings | AutoLayout2.lua | folded |
| simple_shift | AutoLayout2.lua | folded |
| rank_row | AutoLayout2.lua | folded |
| rank_card | AutoLayout2.lua | folded |
| rank_own | AutoLayout2.lua | unfolded |
| settings_merged | AutoLayout2.lua | folded+unfolded |
| settings_merged_big | AutoLayout2.lua | folded+unfolded |
| tip_edge | AutoLayout2.lua | folded+unfolded |
| tip_long | AutoLayout2.lua | folded+unfolded |
| tip_whole | AutoLayout2.lua | folded+unfolded |
| tip_chip | AutoLayout2.lua | folded+unfolded |
| pay_part | AutoLayout2.lua | folded+unfolded |
| login_paused | none: stays a hand step (see below) | folded |
| login_drive | none: stays a hand step (see below) | folded |

Views: "folded" is the phone alone, "folded+unfolded" also the wide window, "unfolded" only the wide window. A page that Wuber's Fold has no wide form for is skipped unfolded with "this page doesn't unfold here" (blocked_off, blocked_full, sheet_places, pay_part); the layout check notes the same.

## Left to hand (L.AUTO_MANUAL)

- **login_paused**: The layout check starts a new game window whose font arrives 25 s after login and looks at the Paused bar of the floating Drive bar at that moment. The Auto check runs in a game that has been up for a while (the font is long loaded), so it cannot make that moment. a_font (AutoSteps2.lua: the font files, Wuber's widths) and a_ruler (AutoSteps6.lua: real text widths and cuts) look at the font once it is there, not at the seconds before it arrives. Stays a hand step: log in fresh, open nothing, set the Drive bar to Open then Paused, and watch it until the font arrives.
- **login_drive**: The layout check opens the window on the Drive tab while the font is still loading and looks again when it arrives (25 s after login). The Auto check runs in a game that has been up for a while, so the loading moment cannot be made again; a_font and a_ruler (see login_paused) only see the finished font. Stays a hand step: log in fresh, open Wuber on the Drive tab at once, and watch the page until the font arrives.

## Not screens

- The layout check's route walks (tests/layout/routes.lua, 54 steps: pressing through the pages and checking each step) are not screens: see PR #65 (back on every page); stays manual.
- The daylight check (tests/layout/daylight.lua) is not a screen either. It stays manual.

## What a ported row does differently from the layout check's copy

- The base screen (confirm, home, console_open and so on) is looked up in `L.PHOTO_SCREENS` when the row runs.
- A Wuber module the row shows is checked in the row's `need(W)`. A Wuber without it leaves the row out with one log line, never an error. `s.declares` lists the words such a skip starts with.
- Every demo value goes through the tour's shot stubs, which `L.PhotoReset` puts back before the next screen. Anything else a row changes is put back by a function handed to `L.AutoLayoutKit.undo`, which `L.PhotoReset` also runs.
- Nothing is sent, invited, whispered, traded or summoned, no secure frame is touched and no protected call is made. The only clicks are a named, local, insecure OnClick through `X.press` (Check my game, the Back chevron, the Undo toast).
- Things that only exist in the fake game are not ported: the World map stubs (`X.stubWorld`), `c.env`, `w:advance`, `H.*`.
- rank_card needs a character in a guild (the Tell the guild pill shows only then); a character in no guild leaves the row out and says so.
- inflight uses the flight map's own point names when the map is open, else the longest place Wuber knows.

## How the two lists stay in step

tests/lessons/l26_lab_auto_coverage_test.lua works out what the layout check knows (the tour's screens, what `extra_screens.lua` installs, `Run.SCENES`, minus the two skipped on purpose) and fails if any of them is neither a row in `L.AutoScreens()` nor a key of `L.AUTO_MANUAL` with a reason. It also checks that each ported row has the layout screen's side, title and views, in the layout check's order with pay_part last, and runs a real Auto check over the ported rows in the fake game: it must reach its end, shoot every row in its views, send nothing, put WuberDB back exactly, and raise no Lua error. A row may skip only for a reason it declares.

A new scene added to the layout check therefore fails that test until it gets a row here (or a reason in `L.AUTO_MANUAL`). Add the row to AutoLayout.lua or AutoLayout2.lua (new rows go above pay_part) and a line in the table above.


## What a round changed: the WATCH list (2.4.4)

`L.AUTO_WATCH` (AutoSteps7.lua) names each thing the 2.4.4 round changed on a screen: the words a player reads (a drawn text or a tooltip a hover opens) and the screens that walk it. A run that goes to its end judges every entry and writes one row each ("watch <id>"): seen on a screen is a pass; words that were on no screen and in no tooltip, or none of its screens walked, is a look. A run of some screens judges only the entries whose screens it walked. The result is in `WuberLabDB.autoCheck.watch` ({ n, seen, missing }). Add an entry for the next round's changes the same way; `tests/lab244/coverage_test.lua` proves the list against the fake game and proves a missing word is a look.

Rows added for it (all local, nothing sent, nothing pressed that talks to anyone):

| Screen id | What it walks |
|---|---|
| a_bird_card | Wuber's own flight master card (the stand-in version, no flight map needed); the card is a scanned root now, so its text, cut and tooltips are checked |
| a_retire_card | the Drive console's card for a character whose old summoning addon is still on; the Switch it off pill is hovered, never pressed |
| a_hidden_row | Settings > Riding with one hidden driver: the Hidden drivers row and its tooltip (the row exists only then) |
| a_settings_adv | Settings home in Advanced mode: the Report a bug card and its tooltip |
| a_coach_2 | the first-open tip "Pick a driver" |
| a_tip_skip_the_bird, a_tip_drive_setup | the login tip card for the two tips whose words changed |
| a_pulse_ring | the driver console's "Waiting for riders" ring: one ring, starting about every 3 seconds (timed in the real game) |

One check was added to every screen's "buttons" kind: the floating big button (WuberDriveButton) over any clickable control of the phone is a finding (#255, HUNT-07).

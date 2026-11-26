Press Auto check first (about 6 min). Hands off the mouse and keys until chat says "Auto check: N passed". The 20 steps below are only what the game cannot do itself (dragging, keys, Escape, typing, things that need your own data): about 15 min for you.
First time only: Wuber Lab has two new files (AutoCheck.lua, AutoSteps.lua), so close the game fully and start it again once before this. A Reload is not enough for those.


# STEPS-2.3.4-AUTO: what is left for you after Auto check
One account, one character, no typing in chat. Wuber 2.3.4-dev is installed (no new files, so a Reload is enough, no restart).
Tick what you see. If something looks wrong, click Huh on the Lab bar right then (it takes a screenshot) and say a few words in the box.
Skip any step whose "if" does not fit your character. Do not press Open as a driver: that would advertise to real players.

## Start (2 minutes)
1. On the Lab bar click Taint until it says Taint: ON (this is the blocked-actions log).
2. Click Reload and wait for the game to come back.
3. Click Potato start (say "potato" out loud).

## A. Window and scroll bars
4. Open Wuber from the minimap button. Drag it by its top bar to a new spot, press Escape, open it from the minimap button again: it opens where you left it. Click Reload, open again: same place. (HUNT-01)
5. Settings: click the search box and press Escape without typing anything: "Search settings" shows again. (AUD-204)

## B. Settings screens
6. Settings, "Turn on friendly nameplates": the note stays "Friendly nameplates are on: crowns and badges show over heads. Shift+V turns them off." (AUD-203, HUNT-62)
7. Settings, Report a bug. Press Escape once: it closes. Open again, click "What happened?", press Escape once: closes too. Open again and type "Quinn-Argent hurt me": the report says "player 1 hurt me", no realm. Also type a line with the word "unknown": it keeps it. (HUNT-40, HUNT-56, HUNT-57, AUD-217, AUD-218)

## C. Drive tab (do not press Open)
8. Drive, Price and place: type "ea" in the place box. The match pills keep normal text and none hangs past the card's right edge. Pick a place and press Save, then clear the box and Save: the place is cleared. (AUD-157, AUD-158, AUD-177)
9. Drive console while closed: click the dimmed Pause: it stays "Pause". (AUD-195)
10. Drive, Messages: open the greeting, type about 205 letters, Save: a red "Not saved: ..." line sits above Reset to default and Save. Paste over 190 letters: the counter is red. Empty the box: the preview shows Wuber's own words. (AUD-167, HUNT-74, HUNT-75)
11. Messages, unfolded: open "My advert line", then press Back: the list stays put while the screen slides out. (AUD-202)
12. Drive setup or Crew, "Add by name": type your own name, then "---", press Add each time: the toast "Couldn't send the offer" and no new row. (AUD-224)
13. Unfolded, Drive setup, press "I have a second account to alert": Settings opens on the Alert character row. Make your own character the Alert character and press Test the alert: only the banner shows, no "Test sent" note. Clear it again afterwards. (AUD-175, HUNT-65)
14. Drive, Earnings, the Busy-hours card: tap a quiet square, then a busy one: numbers at normal size, the white frame glides each time and never jumps back. A square for an hour open only a few minutes shows no "g/h". (AUD-151, AUD-212, HUNT-03; only if you have earnings logged)

## D. Rider screens
15. Home, with nobody open: type a place in the search box, then clear it: the rings round the disc pulse again. (AUD-208)
16. Trips, folded: "Scroll for your trips" shows with no heading under it; scroll a little and "Milestones (N of M)" appears clear of it. No milestone name sits under "Scroll for more". (HUNT-90, AUD-154; only if you have enough trips)
17. Trips, the "Wrapped" chip: click on its star end (the left few pixels): the tooltip shows like the rest. With rides in two or more months, right-click it once: the story opens on the month before the newest; left-click opens the newest. (AUD-209, HUNT-50)
18. Settings, Help ("?"), Show a tip: the tip card shows. Press "Show me", and within 3 seconds click another tab (Trips): the gold ring goes at once. Try again and stay: it pulses about 3 seconds. Click the card's X, then at once click the Help row: the card stays up. (AUD-10, AUD-26)

## E. Finish
19. Click Potato end, then Reload (this saves the logs). Log out normally, not Alt-F4.
20. Tell the person running the test you are done. They run the Lab report: its "Auto check" part says what the game found and names any step Auto check could not do this time, and its "Blocked actions" part comes from Logs\taint.log. Click Taint again if you want it back off.

## Later (needs a button)
- These need a typed command, and no Lab bar button does them yet. Not done today.
- /wuber why checks: REC-01 (both parts), REV-r28-3, REV-r28-4, REV-r28-5, and the "why" lines named in HUNT-21's tips check.
- /wuber tips: HUNT-32, HUNT-21.
- /wuber emblem ...: HUNT-68, HUNT-69, HUNT-70, HUNT-73, AUD-236 (emblem preview), AUD-237.
- /wuber drive ... (status, bell, add, log, stats, on/off, msg, spell, bind, paid): HUNT-105, HUNT-106, HUNT-85, AUD-82, AUD-125, AUD-127, AUD-128, AUD-129, AUD-132, AUD-126, AUD-137, AUD-138, HUNT-45.
- /wuber price 50000g: HUNT-58. /dump WuberDB.drive.summons: FEAT-01 driver side.
- Test the Report a bug lists after a summon: HUNT-25 (the button exists, but it needs a summon first).

## Later (needs a second player)
- Everything else in INGAME-2.3.4.md that needs a rider and a driver, a crew, a Warlock friend, a raid, another realm, a flight master with an open driver, a real fight or a real trade. That is most of Rounds 27 to 34, 37 and 46, and the crew, raid and trade lines of Round 47 (for example AUD-01 to AUD-11, AUD-30, AUD-63, AUD-87 to AUD-89, HUNT-11, HUNT-12, HUNT-26, FEAT-01 rider side, AUD-185, AUD-176). Steps are in INGAME-2.3.4.md, unchanged.
- Summon timing, when you do test it: compare against "your driver's own average", not a fixed number.

## Done by Auto check (not in the in-game list)
Auto check took over 20 of the 40 numbered steps of STEPS-2.3.4-SOLO. Its verdict for each is in the Lab report ("== Auto check", by step id): a step it could not do that time (skipped) or that needs a look is named there, and only then is it yours.
- old step 5 (REV-r25-1): Unfold the window. Visit Ride (Home), Chat, the Map tab, then Settings (the gear): no scroll bar line runs...
- old step 6 (REV-r26-1): Still unfolded: Settings, press Help: no Settings scroll bar cuts through Help's cards. Press Back: Setting...
- old step 8 (REV-r27-1): Settings, search "Check my game" and press it. The line "Wuber ... summons on demand · no website, no serve...
- old step 9 (AUD-172): Settings, This window: the Window card says "Size 115%" if you never changed the size, same as the Window s...
- old step 10 (HUNT-72, HUNT-42): Settings, This window, Wide pages: choose Always narrow, press Reset: toast "Every page is back to Auto", t...
- old step 11 (HUNT-59): Settings, This window, Window position, Reset (out of a fight): the window goes to its usual place and says...
- old step 12 (AUD-148): Settings, Driving: the "Who summons" Change button looks raised and stays raised after the mouse goes over...
- old step 13 (AUD-228): Settings, Driving, "Key for the big button": click Set ("Press..."), then click Clear: Set reads "Set" agai...
- old step 14 (HUNT-19, HUNT-29, HUNT-41, HUNT-43): Settings, hover these and read the tooltip (nothing cut): Effects (the Off line says only the minimap butto...
- old step 15 (HUNT-66): Settings, Driving: switch "Share notes with my own accounts" off. Drive > Crew: the Crew card no longer off...
- old step 16 (HUNT-76): Settings, Driving, "Block riders who leave without paying": switch off, open Drive > Blocked with nobody bl...
- old step 18 (HUNT-49): Hover the Wuber minimap button while not open to drive: no "Shift-right-click pause" line. (HUNT-49)
- old step 19 (HUNT-09, HUNT-10): If OpenMap is switched off: Settings "Drivers on the world map" reads "Pins with prices. Best with the Open...
- old step 20 (HUNT-108): Settings, Check my game. As a Warlock with no crew set up the heading is amber: "All 14 game checks passed....
- old step 22 (HUNT-23, AUD-149): If this character is not set up as a driver: open Drive and click the gear ("Every driving option"): the Dr...
- old step 23 (HUNT-64): If this character is not a Warlock: Drive, then Crew: the "Just you" card says "Clicks the portal". (HUNT-64)
- old step 28 (AUD-200): Drive setup (the wizard), Step 1: click "My friends help", move the mouse off: the card keeps its lighter b...
- old step 33 (REV-r47-1): Home, search "Feathermoon Stronghold": "Drivers to Feathermoon Stronghold" stays left of "0 open · 1 online...
- old step 34 (AUD-159): Home with more drivers than fit: one thin scroll bar on the right edge, not two. (AUD-159; only if the list...
- old step 36 (AUD-153): Trips, the Spent chip: a long amount ("Spent 12g 34s 50c") widens to the full row at normal size. (AUD-153)

## Time
Auto check: about 6 minutes, hands off. Your part: 20 steps, about 15 minutes (the full list was 40 steps).

# Wuber 2.4.3

This is everything since Wuber 2.3.2, the last version players got. The versions in between (2.3.3, 2.3.4, 2.4.0, 2.4.1 and 2.4.2) were never released, so their changes are all in here.

Entries marked **[FULL RESTART]** depend on a new addon file. Exit the game completely and start it again after updating; a `/reload` is not enough. If you only reload, Wuber shows "Restart the game to finish updating Wuber." instead of an error. Entries without the mark work after a `/reload`, but because the whole update ships together, one full restart covers everything.

## Simple and Advanced mode
- Wuber now starts in Simple mode. Riders see the map, the drivers and one main button. Drivers see the big button and their queue.
- Everything else is one switch away: Settings, "Advanced mode" (or type `/wuber advanced`). Switching changes none of your settings, ends no ride and closes no driver.
- If you already used Wuber, you see a one-time note: "Wuber is simpler now. Everything else is in Settings: Advanced mode." **[FULL RESTART]**
- Settings are shorter and grouped. Related switches share one row, and the search box still finds the Advanced ones and tells you where they are.
- Settings search understands a question. Type "how do I turn off sounds?" or "where is the minimap button?" and it finds the row. The box now says "Ask or search".
- Resetting a window position, the big button's place or your Earnings stats shows an "Undo" button for a few seconds.
- On the Drive tab, the hero card and the big button sit in the same place in Simple and Advanced mode, so switching modes in a fight moves nothing.

## A calmer look
- One typeface, flat cards and one corner shape. Gold is for prices and for the one main button on a screen. Violet is for what you picked. Red is the only warning colour.
- Ride, Trips and Drive are tabs at the bottom. The Settings cog and the close button are at the top right.
- Pages slide in and out. "Reduce motion" in Settings, Sound and effects keeps everything still.
- During a ride a black pill at the top follows it ("Finding a driver", "Accepted", "Summoning", "Portal open", "Arrived"). Click it to get back to your ride from any tab. It takes a click only when the click shows you something new.
- Long names and notes wrap instead of being cut off. A long toast message widens to fit a long word instead of cutting it, and stays on the screen.
- Wuber's tooltips are small cards beside the control, and a cut-off label shows its whole text first.
- After an update, a "What's new" card shows once. It follows the window when you drag it, and the flight map's price tags step aside from it. **[FULL RESTART]**
- Login tips show one short tip the first time you open Wuber after logging in, and `/wuber tips` brings the last one back. **[FULL RESTART]**
- The cards that open by themselves (login tips, the first-open guide, Skip the bird, What's new) never show in combat, in a cinematic or in the first seconds after login, and only one at a time. Tapping the celebration card opens Wuber on Trips and stays there.
- The Skip the bird card is never hidden under the What's new card, so a click on it opens the booking screen.
- The crew offer card stays clear of the big summon button and its console.
- The live pill fits beside the clock at once when you fold the window.
- Folded Trips no longer shows an empty "Milestones" card while no medal shows.
- A map pin's price tag stays clear of its own ring.
- The "Post to party" button no longer sits below the window while the shift card moves.
- "Tell me when one opens" is no longer cut off on the ride search page, and a driver who comes back after a pause shows as open sooner.
- "Badges over heads" in Settings shows the true state after `/wuber emblem off`.
- Pressing Enter in the reason box when you block a rider blocks them.

## Clicks and buttons
- The back arrow works again on Settings and on pushed pages such as Drive, Customers and the ride's confirm page. A hidden strip behind the header was taking the click. The Drive switch is fixed the same way.
- Every button has been checked with a real click, not only a pretend one.
- The World Map's "Wuber only" switch moves to the bottom-left corner when Wuber's window covers its usual corner, so you can click it.
- Escape closes the top sheet first (for example the rider menu or Report a bug), and the next Escape closes the window.
- With the game's Gamepad UI turned on, Wuber no longer causes "AddOn blocked" messages on the world map. In that mode Wuber also leaves out its `/wuber` command, its Escape-closes-the-window entry and its map opening, so the game does not blame it. If you play with the mouse you see no change.

## Riding
- Drivers sit in one card, with their picture, name, Founder badge, price and a heart. "Options" replaces the three dots.
- A driver's usual summon time shows once enough summons have been timed ("Usually about 45 sec"). After 3 timed summons the driver's Wuber also tells riders the average of the last 20. The Fly or summon card and the Skip the bird card then count with that driver's own time instead of the standard 30 seconds.
- Flight times use one speed everywhere, so one Wuber window no longer shows two different "about" times for the same flight, and new characters no longer see times about 6% too short.
- If the driver summons to the place where you already stand, the page says so in plain words and tells you to go back and pick another driver.
- From a driver's page, the Ride tab takes you back to the list of drivers.
- Waiting for the portal says "Stay put" and "Accept the portal when it pops up."
- If a stranger opens a trade with you, the pay card dims and warns you. After a part payment, the pay card asks only for what is still owed. When you give change in the trade, only what you keep counts as the fare.
- A rain check from the driver of a failed ride still arrives after the failed-ride screen has closed, for 30 minutes.
- If a rider left without paying, the Done screen says how to send the fare by mail.
- Typing a driver's whole name finds that driver.
- Founders show their Founder badge again on this game version, which no longer tells addons the realm name.
- Many smaller ride fixes: auto-accept joins your driver's group even when the invite message arrives first; a driver who drops you after you joined is reported as a decline; the pay card, the toast and the strip by the trade window name the same amount; a ride survives a `/reload` with its live cast and danger warning; a rider who books again while a summon is under way is told the driver is busy and the first ride keeps working; a rain check is not used up by a later plain summon; the booking card for a driver who went offline no longer shows the earlier driver's price and route; the Request and Cancel buttons no longer flash over the window while it closes.

## Flight masters and flying
- The flight master's map shows a price tag by every place an open driver summons to. Click a tag to open that driver's booking page. **[FULL RESTART]**
- The offer card stays until you close it or take a flight. It no longer disappears on its own.
- In flight, Wuber may offer a faster summon once, if the summon would really beat the flight you have left. You can drag the card, and "Flight offers" in Settings turns all of these off. **[FULL RESTART]**
- A flight in progress survives a `/reload`, and a summon taken while flying no longer teaches Wuber a flight time that is too short.

## The world map
- Open drivers wear a three-colour ring. A "Wuber only" switch dims the rest of the map so the pins stand out.
- Routes are violet. Your own continent is tinted brighter. A route that crosses the sea says "continues by boat" or "continues by zeppelin". **[FULL RESTART]**
- When Wuber opens the world map for you it uses the game's own safe way, and never in a fight. In a fight it says "Leave combat first, then open the map."

## Driving
- Auto mode is careful. It invites by itself only when a whisper clearly asks for a ride. Anything it is not sure about waits in your list as a lead you can click. **[FULL RESTART]**
- A line that sounds like a seller's advert never invites anyone. A buyer line such as "WTB summon to Orgrimmar, whisper me" still counts as a buyer.
- "Whisper back to public requests" (Settings, Driving, on by default): when someone in public chat clearly asks for a summon to your place, Wuber whispers them once to say how to ask you. It waits between whispers, never sends one in combat, in a raid, in an instance or during a ride, and never sends one to group members, other drivers or blocked players. You can turn it off. The row "What Wuber sends" says "never in combat". **[FULL RESTART]**
- If you run several game windows (your own crew), a stranger gets one whisper back, not one from each window.
- "Oops, wrong invite" on a rider's row says sorry on your next click and removes them. Wuber remembers them on your own PC only.
- The big button never casts on a rider who already has a summon waiting, and it says why when there is nothing to do. It still holds back after a `/reload` when another Warlock's summon is waiting.
- Your riders are kept when you reload or log out and back in. Close asks "Close anyway?" while riders are still with you.
- Mail from a rider who left owing is noted. Wuber never opens or takes a mail. **[FULL RESTART]**
- Drivers earn a title from summons that riders confirm: Learner, Cabbie, Black Cab, Chauffeur and Has The Knowledge. Riders see it on the driver's row. **[FULL RESTART]**
- Drive, Earnings and Trips have cleaner charts, a clearer "Best hours" grid and a "Your summons" time once enough summons are counted.
- The Trips count shows paid rides only. Older saved totals that counted unpaid rides are made again once.
- The founder crown shows on your own driver card. In Settings, "Your badge" shows what is really drawn.
- Moving the Wuber window no longer makes the big button flicker away.
- "Raid summons" is no longer cut off in a narrow window on Drive.
- In a raid or boss fight, Wuber holds its hidden addon messages and sends them afterwards, so the game's "This account can't send addon messages" no longer appears.

## Crews and raid summons
- Leaving or ending a crew gives you back your own price, place and settings. A full crew says "Crew is full".
- A crew window that reloads or joins in the middle of a raid gets the raiders, the rain checks and the block list again. A runner who leaves the group stops the raid queue with a clear line.
- A player in your group who is not in your crew can no longer change your crew's raid queue.
- Pressing Enter in the "Name or Name-Realm" box of the crew window adds that name, the same as the Add button.
- A payment that arrives after the rider has left the group still counts, once.
- Words: where a summon costs nothing, Wuber now says "at no charge", "costs nothing" or "No charge", and a gift ride says "ride as a gift".

## Group Finder (preview, off by default)
- New setting "Group Finder (preview)", off until you turn it on. A driver can list themselves in the game's Group Finder with a note, and a rider can search it for drivers. The driver posts with the game's own Post button, and "Remove my listing" takes it down again. Going offline in any other way shows a "still listed" reminder and never removes it by itself. **[FULL RESTART]**
- Your own listing is never counted as another driver.

## Key bindings, commands and bug reports
- The game's Key Bindings list has a "Wuber" section: open or close Wuber, and a key for the big button. Options, AddOns has an "Open Wuber settings" button. **[FULL RESTART]**
- New commands: `/wuber advanced`, `/wuber why` (what Wuber is hiding right now and why), `/wuber tips`, `/wuber updates on|off`.
- "Report a bug" closes on Escape, hides names, and lists the last few blocked actions and wrong invites. It now also names which Wuber call the game blocked (instead of "from unknown"), your class and level, only the settings you changed, and the other addons you have loaded.
- Opening and closing Wuber's window, and opening Earnings, do less work. You should notice nothing except that it feels smoother.

## Not yet tried in the real game
These are built and pass their automatic tests, but may not have been seen in the real game yet, so please do not count on them:
- The crew and raid fixes (including Enter in the "Add by name" box), the rain check after a failed ride, the mid-flight offer and dragging its card, the whisper back to a public request, and the mail note.
- Group Finder, and Wuber with the game's Gamepad UI turned on.
- A new character on a client that does not name its realm does not see the founders' list yet, because the game no longer gives the realm name and Wuber does not guess one.
- Founder crowns and the gold portal on a character that has never logged in while the game gave its realm name.

## For testers: new addon files since 2.3.2
These are the files a reload cannot find, so the full restart above matters. Wuber/Bindings.xml, Wuber/Core/Words.lua, Wuber/Drive/AutoLines.lua, Wuber/Drive/AutoReply.lua, Wuber/Drive/Careful.lua, Wuber/Drive/Mail.lua, Wuber/Drive/Rank.lua, Wuber/Net/GroupFinder.lua, Wuber/UI/FlightPins.lua, Wuber/UI/InFlight.lua, Wuber/UI/Rider/SeaRoute.lua, Wuber/UI/TipTexts.lua, Wuber/UI/Tips.lua and Wuber/UI/WhatsNew.lua, plus fonts and pictures under Wuber/Media.

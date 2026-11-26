# Wuber 2.4.3 player guide

<!-- TODO for the maintainer: add the CurseForge page URL here (section 2 and section 10 point players to it). -->

## 1. What Wuber is

Wuber is a World of Warcraft addon for the WoW Forever client that treats a Warlock summon like a ride. Riders see which Warlocks are online, where they summon to and what they charge, and request one with a click. Warlocks can drive too: the Drive tab runs a queue, invites riders, opens the trade for the fare and keeps a small ledger.

Players pay each other in game gold. Wuber never puts gold in a trade and never accepts a trade for you: you do both yourself (see section 6).

## 2. Install and update

1. Download the latest release zip from Wuber's CurseForge page.
2. Unzip it so that the folder `Wuber` sits inside your game's `Interface\AddOns` folder.
3. Start the game, tick Wuber on the AddOns list and type `/wuber`.

Wuber 2.4.3 is everything since 2.3.2, the last version players got. The versions in between (2.3.3, 2.3.4, 2.4.0, 2.4.1 and 2.4.2) were never released, so their changes are all in 2.4.3.

Some features in this release depend on a new addon file. After installing or updating, exit the game completely and start it again; a `/reload` is not enough. Entries in this guide marked **(full restart)** need that. If you only reload, Wuber shows "Restart the game to finish updating Wuber." instead of an error. Everything else works after a `/reload`, but because the whole update ships together, one full restart covers everything.

After an update:

- A "What's new" card shows once. It follows the window when you drag it, and the flight map's price tags step aside from it. **(full restart)**
- Login tips show one short tip the first time you open Wuber after logging in. **(full restart)**
- If you already used Wuber, you see a one-time note: "Wuber is simpler now. Everything else is in Settings: Advanced mode." **(full restart)**
- The cards that open by themselves (login tips, the first-open guide, Skip the bird, What's new) never show in combat, in a cinematic or in the first seconds after login, and only one at a time.

## 3. Your first ride (riders)

**How to open Wuber.** Type `/wuber` (or `/ride`), click the minimap button, or use the key set in the game's Key Bindings list, "Wuber" section, "Open or close Wuber" (**full restart**). The minimap button is on by default. Left-click it to open or close Wuber, and drag it to move it. `/wuber minimap` shows or hides it, and the "Ask or search" box in Settings finds it too.

Ride, Trips and Drive are tabs at the bottom. The Settings cog and the close button are at the top right. Gold is for prices and for the one main button on a screen, violet is for what you picked, and red is the only warning colour.

1. **Choose an open driver on Ride.** In Simple mode, Ride shows the map, the open drivers and one main button. Each driver sits in one card with their picture, name, Founder badge, price and a heart. "Options" replaces the three dots. Once enough summons have been timed the card shows the driver's usual time, such as "Usually about 45 sec"; after 3 timed summons the driver's Wuber also tells riders the average of the last 20. Type a driver's whole name to find that driver. If nobody is open, the ride search page has "Tell me when one opens".

   Before you have picked a driver there is nothing to book yet: you pick a driver card. The main button on the list shows up in only two cases. "Your usual" shows "Ride again · <place> · <price>" for the ride you take most. During raid summons it shows "Request a summon". Booking itself is on the confirm page (next step).

2. **Check the confirm page and request.** Click a driver card to see their price and route. The button there says "Request summon", and "Cancel" steps back. If the driver summons to the place where you already stand, the page says so in plain words and tells you to go back and pick another driver. From a driver's page, the Ride tab takes you back to the list of drivers. If you book again while a summon is under way, you are told the driver is busy and the first ride keeps working. The booking card for a driver who went offline no longer shows the earlier driver's price and route.

3. **Follow the black pill.** During a ride a black pill at the top follows it. Click it to get back to your ride from any tab; it takes a click only when the click shows you something new. When you fold the window, the pill sits beside the clock. The pill says:
   - "Finding a driver" after you have sent your request.
   - "Accepted" when the driver has accepted. Auto-accept joins your driver's group even when the invite message arrives first, and a driver who drops you after you joined is reported as a decline.
   - "Invited" once the group invite is out.
   - "Summoning" while the summon is under way. The waiting page says "Stay put". Your ride, its live cast and its danger warning survive a `/reload`.
   - "Portal open" when the portal is up. The page says "Accept the portal when it pops up." The pill can also say "Portal opening" while it is still waiting for clickers, with a count written "n of m".
   - "Arrived" when you are there. It also shows what is still to pay.

4. **Pay the driver.** See section 6.

Trips counts paid rides only. Tapping the celebration card opens Wuber on Trips and stays there. Folded Trips no longer shows an empty "Milestones" card while no medal shows.

## 4. Your first shift (drivers)

Warlocks run a shift from the Drive tab at the bottom of Wuber.

1. **Set your price and place.** The first time, the Drive tab offers "Set up driving". The price and place sheet has "My price" (type an amount such as `50s`, `1g` or `1g 50s`, then press Enter or click Save) and "Summon to" with two choices: "Where I stand" (riders are summoned to wherever you are standing) or "Choose" (pick a place by name; it stays the same wherever you stand). `/wuber price 50s` sets the price from chat.
2. **Open your shift.** On the Drive tab the button reads "Open"; click it, and it reads "Close" while you are open. (If you run raid summons, it reads "Start" and "Stop".) Opening works after a fight, not during one. In Simple mode, Drive shows the hero card, the big button and your queue. The hero card and the big button sit in the same place in Simple and Advanced mode. "Post to party" no longer sits below the window while the shift card moves. The founder crown shows on your own driver card, and "Your badge" in Settings shows what is really drawn.
3. **Fill the queue.** Riders join by booking in Wuber or by whispering you.
   - Auto mode is careful. It invites by itself only when a whisper clearly asks for a ride. Anything it is not sure about waits in your list as a lead you can click. **(full restart)**
   - A line that sounds like a seller's advert never invites anyone. A buyer line such as "WTB summon to Orgrimmar, whisper me" still counts as a buyer.
   - "Oops, wrong invite" on a rider's row says sorry on your next click and removes them. Wuber remembers them on your own PC only.
   - Pressing Enter in the reason box when you block a rider blocks them.
   - Your riders are kept when you reload or log out and back in. Close asks "Close anyway?" while riders are still with you.
4. **Summon with the big button.** It never casts on a rider who already has a summon waiting, and it says why when there is nothing to do. It still holds back after a `/reload` when another Warlock's summon is waiting. Moving the Wuber window no longer makes it flicker away. The game's Key Bindings list has a "Key for the big button" entry in its "Wuber" section. **(full restart)**
5. **Crews and raid summons.** The crew offer card stays clear of the big summon button and its console. Leaving or ending a crew gives you back your own price, place and settings. A full crew says "Crew is full". "Raid summons" is no longer cut off in a narrow window on Drive.

What you still do yourself: click the big button for each summon, click the second time on "Oops, wrong invite", click the uncertain whisper leads Auto mode holds back, make your own trades, and open your own mail. If you switch on "Group Finder (preview)", you post with the game's own Post button.

**Titles.** Drivers earn a title from summons that riders confirm: Learner, Cabbie, Black Cab, Chauffeur and Has The Knowledge. Riders see it on the driver's row. **(full restart)** A summon counts when the rider's own Wuber reports the arrival. It only counts for a ride made through Wuber that included a summon, only once per rider per day, and never for crew rides. You start as Learner. Cabbie starts at 10 confirmed summons, Black Cab at 50, Chauffeur at 250 and Has The Knowledge at 1000.

Drive, Earnings and Trips have cleaner charts, a clearer "Best hours" grid and a "Your summons" time once enough summons are counted.

## 5. Simple mode and Advanced mode

Wuber now starts in Simple mode. Riders see the map, the drivers and one main button. Drivers see the big button and their queue.

Everything else is one switch away: Settings, "Advanced mode" (its description reads "Every setting, and Wuber's extra tools."), or type `/wuber advanced`. The command switches between the two modes each time you type it, and says "Advanced mode: on." or "Advanced mode: off." Settings are shorter and grouped in Simple mode. Related switches share one row, and the search box still finds the Advanced ones and tells you where they are.

Switching changes none of your settings, ends no ride and closes no driver. On Drive, the hero card and the big button sit in the same place in both modes, so switching modes in a fight moves nothing.

## 6. Paying and getting paid

Wuber never puts gold in a trade, and it never accepts a trade for you. You put the gold in and accept the trade yourself. Wuber also never opens or takes a mail.

- The pay card, the toast and the strip by the trade window name the same amount.
- If a stranger opens a trade with you, the pay card dims and warns you.
- After a part payment, the pay card asks only for what is still owed. When you give change in the trade, only what you keep counts as the fare.
- A payment that arrives after the rider has left the group still counts, once.
- Where a summon costs nothing, Wuber says "at no charge", "costs nothing" or "No charge", and a gift ride says "ride as a gift".
- A rain check from the driver of a failed ride still arrives after the failed-ride screen has closed, for 30 minutes. A later plain summon does not use it up. (Not yet proven in the real game.)
- If a rider left without paying, the Done screen says how to send the fare by mail. Mail from a rider who left owing is noted for the driver. **(full restart)**

## 7. Flying and the maps

- Flight times use one speed everywhere, so one Wuber window no longer shows two different "about" times for the same flight, and new characters no longer see times about 6% too short.
- The Fly or summon card and the Skip the bird card count with a driver's own time, once that driver has 3 timed summons, instead of the standard 30 seconds.
- The flight master's map shows a price tag by every place an open driver summons to. Click a tag to open that driver's booking page. **(full restart)**
- The offer card stays until you close it or take a flight. The Skip the bird card is never hidden under the What's new card, so a click on it opens the booking screen.
- In flight, Wuber may offer a faster summon once, if the summon would really beat the flight you have left. You can drag the card. **(full restart; not yet proven in the real game)** A flight in progress survives a `/reload`, and a summon taken while flying no longer teaches Wuber a flight time that is too short.
- On the World Map, open drivers wear a three-colour ring, and a "Wuber only" switch dims the rest of the map so the pins stand out. The switch moves to the bottom-left corner when Wuber's window covers its usual corner. A map pin's price tag stays clear of its own ring.
- Routes are violet and your own continent is tinted brighter. A route that crosses the sea says "continues by boat" or "continues by zeppelin". **(full restart)**
- When Wuber opens the World Map for you it uses the game's own safe way, and never in a fight. In a fight it says "Leave combat first, then open the map."

## 8. Settings worth knowing about

Settings are shorter and grouped. Resetting a window position, the big button's place or your Earnings stats shows an "Undo" button for a few seconds.

- **"Ask or search"** (the box at the top of Settings): understands a question. Type "how do I turn off sounds?" or "where is the minimap button?" and it finds the row. It also finds the Advanced settings and tells you where they are.
- **"Advanced mode"** (Settings, "This window"): see section 5.
- **"Reduce motion"** (Settings, Sound and effects): keeps everything still; pages and sheets fade in place instead of sliding.
- **"Flight offers"** (Settings, Riding): described there as "A summon that beats flying: beside the flight map, on it, and while you fly." Switching it off turns those offers off. Next to it, "Tips" turns the login tips on or off.
- **"Whisper back to public requests"** (Settings, Driving; on by default; you can turn it off): when someone in public chat clearly asks for a summon to your place, Wuber whispers them once to say how to ask you. It waits between whispers, never sends one in combat, in a raid, in an instance or during a ride, and never sends one to group members, other drivers or blocked players. The row "What Wuber sends" says "never in combat". If you run several game windows (your own crew), a stranger gets one whisper back, not one from each window. **(full restart; not yet proven in the real game)**
- **"Group Finder (preview)"** (Settings, Driving; off until you turn it on): a driver can list themselves in the game's Group Finder with a note, and a rider can search it for drivers. The driver posts with the game's own Post button, and "Remove my listing" takes it down again. Going offline in any other way shows a "still listed" reminder and never removes it by itself. Your own listing is never counted as another driver. **(full restart; not yet proven in the real game)**
- **"Badges over heads"** and **"Your badge"** (Settings): show the true state of overhead badges and of your own badge, including after `/wuber emblem off`.
- **"Open Wuber settings"**: a button under the game's Options, AddOns. **(full restart)**

## 9. Commands

- `/wuber` (also `/ride`): opens or closes the Wuber window. `/wuber help`, or any word Wuber does not know, opens Settings. With the game's Gamepad UI turned on, Wuber leaves out these commands (see section 10).
- `/wuber advanced`: switches Advanced mode on or off, without changing your settings, rides or shifts.
- `/wuber tips`: brings back a login tip. **(full restart)**
- `/wuber why`: says what Wuber is hiding right now and why, or "Nothing is hidden right now."
- `/wuber updates on` or `/wuber updates off`: turns the "a newer Wuber is out" note on or off. `/wuber updates` alone says which it is now. Wuber learns of newer versions from messages other Wuber players already send; it sends nothing extra for this.
- `/wuber emblem on` and `/wuber emblem off`: show or hide the overhead badges ("Badges over heads" in Settings follows). `/wuber emblem` alone lists the other choices.
- `/wuber minimap`: shows or hides the minimap button.
- `/wuber price 50s`: shows or sets your price as a driver.
- `/wuber bug`: opens "Report a bug".

## 10. Troubleshooting

**The back arrow or the Drive switch did not click.** The back arrow works again on Settings and on pushed pages such as Drive, Customers and the ride's confirm page. A hidden strip behind the header was taking the click. The Drive switch is fixed the same way. Every button has been checked with a real click, not only a pretend one.

**Escape does not close the window at once.** Escape closes the top sheet first (for example the rider menu or Report a bug), and the next Escape closes the window.

**A tip or offer card did not open.** Login tips, the first-open guide, Skip the bird and What's new never show in combat, in a cinematic or in the first seconds after login, and only one at a time. Type `/wuber why` to see what is hidden and why.

**"AddOn blocked" or "This account can't send addon messages".** With the game's Gamepad UI turned on, Wuber no longer causes "AddOn blocked" messages on the world map. In that mode Wuber also leaves out its `/wuber` command, its Escape-closes-the-window entry and its map opening, so the game does not blame it. If you play with the mouse you see no change. In a raid or boss fight, Wuber holds its hidden addon messages and sends them afterwards, so the game's "This account can't send addon messages" no longer appears.

**A text or a control looks cut off.** Long names and notes wrap instead of being cut off. A long toast message widens to fit a long word and stays on the screen. A cut-off label shows its whole text first in its tooltip. "Tell me when one opens" and "Raid summons" are no longer cut off.

**Report a bug.** Open it with `/wuber bug`. It closes on Escape and hides names. Nothing is sent: copy the report (Select all, Ctrl+C) and paste it in the comments on Wuber's CurseForge page. It lists the last few blocked actions and wrong invites, names which Wuber call the game blocked (instead of "from unknown"), your class and level, only the settings you changed, and the other addons you have loaded.

## 11. Not yet proven in the real game

These are built and pass their automatic tests, but may not have been seen in the real game yet, so please do not count on them:
- The crew and raid fixes, the rain check after a failed ride, the mid-flight offer and dragging its card, the whisper back to a public request, and the mail note.
- Group Finder, and Wuber with the game's Gamepad UI turned on.
- A new character on a client that does not name its realm does not see the founders' list yet, because the game no longer gives the realm name and Wuber does not guess one.
- Founder crowns and the gold portal on a character that has never logged in while the game gave its realm name.

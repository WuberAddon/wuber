# Wuber 2.4.2 (DRAFT: the wording is for the author to approve)

This is everything since Wuber 2.3.2, the last version players got. The versions in between (2.3.3, 2.3.4, 2.4.0, 2.4.1 and the draft 2.4.3) were never released, so their changes are in here too.

## For players

### Restart the game once after updating
Exit the game completely and start it again after you update. A `/reload` is not enough, because this version adds new addon files and a reload does not find them. If you only reload, Wuber shows "Restart the game to finish updating Wuber." instead of an error.

### Simple and Advanced mode
- Wuber now starts in Simple mode. Riders see the map, the drivers and one main button. Drivers see the big button and their queue.
- Everything else is one switch away: Settings, "Advanced mode" (or type `/wuber advanced`). Switching changes none of your settings, ends no ride and closes no driver.
- If you already used Wuber, you see a one-time note: "Wuber is simpler now. Everything else is in Settings: Advanced mode."
- Settings are shorter and grouped. Related switches share one row, and the search box still finds the Advanced ones and tells you where they are.
- Resetting a window position, the big button's place or your Earnings stats now shows an "Undo" button for a few seconds.

### A calmer look
- One typeface, flat cards, and one corner shape. Gold is for prices and for the one main button on a screen. Violet is for what you picked. Red is the only warning colour.
- Ride, Trips and Drive are tabs at the bottom. The Settings cog and the close button are at the top right.
- Pages slide in and out. "Reduce motion" in Settings, Sound and effects keeps everything still.
- During a ride a black pill at the top follows it ("Finding a driver", "Accepted", "Summoning", "Portal open", "Arrived"). Click it to get back to your ride from any tab.
- Long names and notes wrap instead of being cut off.
- Wuber's tooltips are small cards beside the control, and a cut-off label shows its whole text first.
- After an update, a "What's new" card shows once. Login tips show one short tip the first time you open Wuber after logging in, and `/wuber tips` brings the last one back.

### Riding
- Drivers sit in one card, with their picture, name, Founder badge, price and a heart. "Options" replaces the three dots.
- A driver's usual summon time shows once enough summons have been timed.
- If the driver summons to the place where you already stand, the page says so in plain words and tells you to go back and pick another driver.
- From a driver's page, the Ride tab takes you back to the list of drivers.
- Waiting for the portal says "Stay put" and "Accept the portal when it pops up."
- If a stranger opens a trade with you, the pay card dims and warns you. After a part payment, the pay card asks only for what is still owed.
- A rain check from the driver of a failed ride still arrives after the failed-ride screen has closed, for 30 minutes.
- If a rider left without paying, the Done screen says how to send the fare by mail.
- Typing a driver's whole name finds that driver.
- Founders show their Founder badge again on this game version, which no longer tells addons the realm name.

### Flight masters and flying
- The flight master's map shows a price tag by every place an open driver summons to. Click a tag to open that driver's booking page.
- The offer card stays until you close it or take a flight. It no longer disappears on its own.
- In flight, Wuber may offer a faster summon once, if the summon would really beat the flight you have left. You can drag the card, and "Flight offers" in Settings turns all of these off.
- A flight in progress survives a `/reload`, and a summon taken while flying no longer teaches Wuber a flight time that is too short.

### The world map
- Open drivers wear a three-colour ring. A "Wuber only" switch dims the rest of the map so the pins stand out.
- Routes are violet. Your own continent is tinted brighter. A route that crosses the sea says "continues by boat" or "continues by zeppelin".
- When Wuber opens the world map for you it uses the game's own safe way, and never in a fight. In a fight it says "Leave combat first, then open the map."

### Driving
- Auto mode is careful. It invites by itself only when a whisper clearly asks for a ride. Anything it is not sure about waits in your list as a lead you can click.
- A line that sounds like a seller's advert never invites anyone. A buyer line such as "WTB summon to Orgrimmar, whisper me" still counts as a buyer.
- "Whisper back to public requests" (Settings, Driving, on by default): when someone in public chat clearly asks for a summon to your place, Wuber whispers them once to say how to ask you. It waits between whispers, never sends one in combat, in a raid, in an instance or during a ride, and never sends one to group members, other drivers or blocked players. You can turn it off.
- "Oops, wrong invite" on a rider's row says sorry on your next click and removes them. Wuber remembers them on your own PC only.
- The big button never casts on a rider who already has a summon waiting, and it says why when there is nothing to do.
- Your riders are kept when you reload or log out and back in.
- Close asks "Close anyway?" while riders are still with you.
- Mail from a rider who left owing is noted. Wuber never opens or takes a mail.
- Drivers earn a title from summons that riders confirm: Learner, Cabbie, Black Cab, Chauffeur and Has The Knowledge. Riders see it on the driver's row.
- Drive, Earnings and Trips have cleaner charts, a clearer "Best hours" grid and a "Your summons" time once enough summons are counted.
- The founder crown shows on your own driver card. In Settings, "Your badge" shows what is really drawn.
- Moving the Wuber window no longer makes the big button flicker away.
- "Raid summons" is no longer cut off in a narrow window on Drive.
- In a raid or boss fight, Wuber holds its hidden addon messages and sends them afterwards, so the game's "This account can't send addon messages" no longer appears.

### Fixes since the last test build
- The back arrow works again on Settings and on pushed pages such as Drive, Customers and the ride's confirm page. A hidden strip behind the header was taking the click. The Drive switch is fixed the same way.
- The World Map's "Wuber only" switch moves to the bottom-left corner when Wuber's window covers its usual corner, so you can click it.
- On the Drive tab, the hero card and the big button sit in the same place in Simple and Advanced mode, so switching modes in a fight moves nothing.
- "Tell me when one opens" is no longer cut off on the ride search page.
- A driver who comes back after a pause shows as open sooner.
- Folded Trips no longer shows an empty "Milestones" card while no medal shows.
- The phone's ride pill takes a click only when the click shows something new.
- The live pill fits beside the clock at once when you fold the window.
- A map pin's price tag stays clear of its own ring.
- The "Post to party" button no longer lies below the window while the shift card moves.
- "Badges over heads" in Settings shows the true state after `/wuber emblem off`.

### Crews and raid summons
- Leaving or ending a crew gives you back your own price, place and settings. A full crew says "Crew is full".
- A crew window that reloads or joins in the middle of a raid gets the raiders, the rain checks and the block list again. A runner who leaves the group stops the raid queue with a clear line.
- A player in your group who is not in your crew can no longer change your crew's raid queue.
- A payment that arrives after the rider has left the group still counts, once.
- Words: where a summon costs nothing, Wuber now says "at no charge", "costs nothing" or "No charge", and a gift ride says "ride as a gift".

### Quieter changes
- Opening the window and opening Earnings do less work. You should notice nothing except that they feel smoother.

### Key bindings, commands and bug reports
- The game's Key Bindings list has a "Wuber" section: open or close Wuber, and a key for the big button. Options, AddOns has an "Open Wuber settings" button.
- New commands: `/wuber advanced`, `/wuber why` (what Wuber is hiding right now and why), `/wuber tips`, `/wuber updates on|off`.
- "Report a bug" closes on Escape, hides names, and lists the last few blocked actions and wrong invites.

## Not yet tried in the real game
These are built and pass their automatic tests, but nobody has seen them in the real game yet, so please do not count on them:
- The back arrow on Settings and on Drive and Customers (click it), and the "Wuber only" switch when Wuber's window covers the World Map corner.
- The crew and raid fixes, the rain check after a failed ride, the mid-flight offer and dragging its card, the whisper back to a public request, and the mail note.
- A new character on a client that does not name its realm does not see the founders' list yet, because the game no longer gives the realm name and Wuber does not guess one.
- Founder crowns and the gold portal on a character that has never logged in while the game gave its realm name.

## For testers: new files since 2.3.2
Twenty-three new files, so the restart above matters. Code: `Wuber/Bindings.xml`, `Wuber/Core/Words.lua`, `Wuber/Drive/AutoLines.lua`, `Wuber/Drive/AutoReply.lua`, `Wuber/Drive/Careful.lua`, `Wuber/Drive/Mail.lua`, `Wuber/Drive/Rank.lua`, `Wuber/UI/FlightPins.lua`, `Wuber/UI/InFlight.lua`, `Wuber/UI/Rider/SeaRoute.lua`, `Wuber/UI/TipTexts.lua`, `Wuber/UI/Tips.lua`, `Wuber/UI/WhatsNew.lua`. Three fonts and seven pictures, all under `Wuber/Media`.
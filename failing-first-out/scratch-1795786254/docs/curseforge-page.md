# CurseForge page text

The text of Wuber's CurseForge description, as a plain file so it can be reviewed in a pull request. The one-line HTML to paste into the CurseForge editor (Source view) is `release/curseforge-page.html`; keep the two in step. The text for the changelog box is in `docs/release-notes-2.4.3.md`.

Rules for this page: never describe Wuber's price and never call Wuber free (only the separate OpenMap addon is free); every claim must match the current release and the code; features listed under "Not yet tried in the real game" in the release notes are not promoted here; the pictures are uploaded on the project's Images tab and are retaken for each release.

## Title (the CurseForge project name)

Wuber - Warlock Summons

## Short description (the CurseForge summary box, under 60 words)

<!-- SHORT-DESCRIPTION-START -->
Wuber connects players who want a Warlock summon with players who sell them on WoW Forever, with rider and driver tools in one download, even when public chat channels miss each other. Riders see open drivers, prices and flight times in one window and on the maps; drivers get one big button that walks through each step.
<!-- SHORT-DESCRIPTION-END -->

## Description (paste from here down)

<!-- DESCRIPTION-START -->
Wuber connects players who want a Warlock summon with players who sell them on WoW Forever, even when public chat channels miss each other.

Riders see who is summoning, where to and for how much, and book from a window or the maps. Drivers get one big button that walks through each step.

Type `/wuber` or click the minimap button to open it; a short first-open guide shows the main screens.

## For riders

- **See open drivers:** who is summoning, where to, their listed price, their driver title (Learner, Cabbie, Black Cab, Chauffeur or Has The Knowledge) and, once enough summons have been timed, how long they usually take ("Usually about 45 sec").
- **Compare with flying:** Wuber shows how long flying there would take and cost, with "continues by boat" or "continues by zeppelin" where the route crosses the sea. Open drivers also show on the world map (a "Wuber only" switch dims the rest) and as price tags on the flight master's map.
- **Book and follow your ride:** press the main button. Wuber accepts your driver's group invite for you and shows where the ride is ("Finding a driver", "Accepted", "Summoning", "Portal open", "Arrived") on a bar at the top. While you wait it says "Stay put" and "Accept the portal when it pops up."
- **You stay in charge of your gold:** Wuber never trades for you. It shows what you owe while you type the amount into the trade window yourself, dims the pay card and warns you if a stranger opens a trade, and keeps track of part payments, change and trips.

## For drivers

- **One big button:** each click does the next step (invite, greet, summon, thank, remove from the group) and holds back when a rider already has a summon waiting. Wuber never casts or trades for you: every cast and trade is your own click. Summoning still needs a Warlock and people at the destination to click the portal.
- **Find buyers:** take bookings from riders, or pick up buyers from whispers and chat. Auto mode invites by itself only when a whisper clearly asks for a ride; anything it is not sure about waits in your list as a lead you can click, and "Oops, wrong invite" on a rider's row sorts out a mistake.
- **Run it your way:** alone, with Warlock friends, or with several game windows of your own as a crew. "Raid summons" lets you run summons for your own raid at no charge, with the Warlocks you pick.
- **See how you are doing:** the Drive tab shows your gold per open hour, a "Best hours" grid and, once enough summons are counted, your own average summon time ("Your summons"). Your driver title comes from summons that riders confirm.

## Simple mode and Advanced mode

Wuber now starts in Simple mode. Riders see the map, the drivers and one main button; drivers see the big button and their queue. Everything else is one switch away: Settings, "Advanced mode" (or type `/wuber advanced`). Switching changes none of your settings, ends no ride and closes no driver. On the Drive tab the hero card and the big button sit in the same place in both modes, so switching during a fight moves nothing. The Settings search box ("Ask or search") also understands plain questions such as "how do I turn off sounds?".

## Install and update

1. Install Wuber for the WoW Forever client (Interface 16001) from CurseForge, or put the `Wuber` folder in your game's `Interface/AddOns` folder.
2. In game, type `/wuber`, or bind a key under "Wuber" in the game's Key Bindings list. Options, AddOns also has an "Open Wuber settings" button.
3. **After updating, exit the game completely and start it again.** A `/reload` is not enough for new addon files; if you only reload, Wuber says "Restart the game to finish updating Wuber."

## What is new in 2.4.3

- Simple mode by default, with "Advanced mode" one switch away.
- A calmer look: Ride, Trips and Drive tabs at the bottom, flat cards, "Reduce motion", and a bar at the top that follows your ride.
- Price tags on the flight master's map, and a "Wuber only" view of the world map.
- Real summon times from drivers, and driver titles confirmed by riders.
- Key bindings, a more careful Auto mode, and rides that survive a `/reload`.

The full list is in the changelog.

## Not yet tried in the real game

Some 2.4.3 changes are built and pass their automatic tests but may not have been seen in the real game yet, so please do not count on them: the crew and raid fixes, the rain check after a failed ride, the offer of a faster summon during a flight, the whisper back to a public request, the mail note for riders who left owing, Group Finder (a preview, off by default) and Wuber with the game's Gamepad UI turned on. The changelog has the details.

## Good to know

- The game does not let an addon cast, trade or chat for you. Wuber lines up the next step and you click. The one chat line Wuber sends by itself is a whisper back to someone who clearly asks in public chat for a summon to your place (not yet tried in the real game; Settings, Driving, on by default; never in combat, in a raid, in an instance or during a ride; you can turn it off).
- On WoW Forever, custom chat channels do not always reach players on other realms, so Wuber also uses hidden addon messages and Wuber chat adverts. Hidden addon messages are held back during raids and boss fights and sent afterwards, so a driver may sometimes appear a little late.
- Wuber works on its own and is best with the separate OpenMap addon, which adds driver pins to the world map: [OpenMap](https://www.curseforge.com/wow/addons/openmap).
- To report a bug, use "Report a bug" in Wuber's Settings.

<!-- SOURCE-LINK-PLACEHOLDER-START -->
**PLACEHOLDER, FILL IN BEFORE PUBLISHING (docs/RELEASING.md, "Placeholders"):** the link to Wuber's public source code and issue tracker goes here once the maintainer has made the new public repository. Do not publish the page with this line still in it.
<!-- SOURCE-LINK-PLACEHOLDER-END -->
<!-- DESCRIPTION-END -->

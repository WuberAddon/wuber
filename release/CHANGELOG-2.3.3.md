# Wuber 2.3.3 (in progress)

This version adds new files: restart the game once after installing (a /reload is not enough).

## New
- Login tips: the first time you open Wuber after logging in, a small card inside the phone shows one short tip, each tip once, with Show me, Next tip and Don't show again. Never in combat or during a ride. Driver tips only show for Warlocks and players who have used Drive.
- Settings > Riding has a Login tips switch. /wuber tips turns tips on and shows one now; /wuber tips off turns them off.
- World map: each continent is cut to its land and the two sit close together, with the sea cut out. The continent you are on is brighter, with its name in gold, and gets more room on a narrow window. Pins, price tags and names are bigger, and price tags never cover a pin, your dot or a name.
- World map: a route that crosses the sea shows your side, then an arrow at the edge saying "continues by zeppelin" or "continues by boat".

## Fixed
- The "Skip the bird" card shows on every flight-map open where a summon beats flying, spells out the saving (the summon's price, what flying costs in gold and time, and what the summon really costs), stays up for 10 seconds, and its Don't show again says where to turn it back on (Settings > Riding > Flight master tip).
- Settings: "Check my game" scrolls its results into view whole, and a setting found by search opens with its row at the top instead of cutting the row above.
- "Invite public chat buyers" shows its real setting at once after Yes, Cancel or closing the warning, and can be clicked again.
- The "Skip the bird" card no longer puts Open Wuber on top of "Don't show again" or runs into the minimap, whatever the screen shape or UI scale.

## Behind the scenes
- The layout check now covers the login tip card (folded and unfolded, longest tip) and the World map with a sea route and its arrow.
- The layout check now covers the "Skip the bird" card on the flight map, and flags a label half over a button.
- The test game now ignores a texture's own fade change during an animation, as the game does. It found six lines to fix next round (tests/fixtures/alpha-known.txt).
- The Skip the bird card keeps its full message; the card grows to fit.

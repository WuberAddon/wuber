# Wuber 2.4.4 (DRAFT: the wording is for the maintainer to approve)

This is everything since Wuber 2.4.3, the version players have now. Nothing here is in 2.4.3.

No entry below adds a new addon file, so no **[FULL RESTART]** mark applies this time. Update, then type `/reload`.

## Words that changed
The maintainer answered a words page, and these lines now say what they mean:
- Settings, Driving: "Invite public chat buyers" is now "Invite public chat riders". Its tooltip now says Wuber "asks you once when you switch this on" (it used to say it "asks first", which sounded like before every invite). The `/wuber drive` line, the Advert button tooltip, Earnings ("n riders asked") and the `/wuber stats` line say "riders" too. So do the rest of Earnings (the heat-map square line, its help line, the "Try this hour" tooltip and the stats line) and the tooltip of the public channels Wuber reads. The older 2.4.3 What's new card is unchanged.
- The `/wuber why` line names "the Login tips row of Settings, Riding" (it said "the Tips row").
- The note tooltip, the note privacy line and the nearby tooltips say "your own windows" (they said "the crew windows you marked as your own accounts").
- The "Do nothing" choice for riders who don't pay says "you only get a toast" instead of "a note".
- The raid alert says "Raid summons stopped: the crew captain left the group." (it said "the runner", then "the raid leader").
- The Settings row "Tips" is now "Login tips", and the line shown when tips are off says "Tips are off. Turn Login tips back on in Settings > Riding, or type /wuber tips."
- The Skip the bird line says "Skip the bird: off. Turn Flight offers on in Settings, Riding."
- The "Crew is full" message says "Crew is full (8 players)".
- On the crew member card, "my account" is now "my window" (the tooltip title is "My own window").
- The reasons Wuber gives for not whispering back to a public request now say which switch is off: "Inviting riders who whisper you or ask in the app is off", "Listing people who ask for a summon in public chat is off" or "Whisper back to public requests is off".
- The "Reduce motion" tooltip now says "Nothing slides, grows, pulses or turns. Pages and sheets fade in place instead."

## For drivers
- Customers: a customer's line and the note sheet show the last ride's tip and the total tipped, for example "2 rides with you · last 12 Nov · Orgrimmar · tipped 5s (10%) · 7s 50c tipped in all", or "no tip" when the last ride had none. This comes from your own payment log; nothing new is saved.
- Advanced mode: a lead row says how many rides that person has had so far ("2 rides with you") instead of an ordinal.
- Advanced mode: the returning-rider chip now shows for a rider who paid, was dropped and came back. Before, it stayed hidden for them.
- Simple mode: "Your business" has one "My advert line" row. It opens the advert editor straight away, and Back leaves the screen. The other message screens stay in Advanced mode.
- You can type "WTS" in your own advert line and your own messages, for example "WTS summons to Ratchet". Wuber still refuses "WTB", gold amounts, digits and money words, and links, and it still reads someone else's "WTS" line as a seller.
- The default advert line now starts "Selling summons to <place>, <price>" (or "Selling summons, <price>") and ends ". Pay after you land. /w me or use my Wuber addon (on curse), you can also set it up and become a driver". The "[Wuber]" tag is still added for you.
- Group Finder, "List me" sheet: the game's Note box does not accept paste. The sheet now shows a short note in big letters to type by hand ("Wuber summons to <place>"), and the steps say "Open the Group Finder, go to List yourself, pick a Playstyle, click the Note box and type the note below by hand, then List me." The copy box and the Ctrl+C step are gone.
- Alert character: its tooltip adds a line when the game's "Sound in Background" setting is off ("Sound in Background is off in the game's sound settings, so the bell is silent while another window is in front").
- The big Drive button, when it is docked to the Wuber window, now follows the window while you drag it (not in combat). It goes back to its place when you let go.

## For riders
- If the driver removes you from the group while the summon box is up, Wuber now ends the ride at once and shows the "Ride ended" page with the line "Removed from the group". It no longer shows the "Drivers can block riders who don't pay" warning or the pay-by-mail line, because no summon was taken. Before, the page went back to "Waiting for the invite" and said nothing. Leaving the group yourself, a normal end, a cancel and a removal before the summon box is up work as before.
- Every map pulse is calmer: one soft ring every 3 seconds instead of one or two quicker, stronger ones. This covers the "Waiting for riders" ring, the Home map and world map "you" dot, a chosen driver's pin and the pin ring on the game's map. "Reduce motion" still stops them.
- Trips, folded view: the "Milestones" title and card appear only when a medal is shown. Before, an empty title could show.

## Text that was cut off or ran into something
No words were shortened or changed.
- The pay page: the instruction line can wrap to three lines, and it no longer runs under the "Accepted, Invite, Portal, Arrived, Pay" bar. The bar moves down by the room the line needs.
- The flight map's price tags: when no spot beside a pin is free, the tag takes the nearest clear spot on the screen and slides in as a last resort. Before, one could be drawn partly off the screen.
- Settings: the "Reset" button next to Wide pages is wider, so "Reset" fits at a big window scale.
- The What's new card steps aside the moment the Wuber window resizes or shows, and follows a moved window within a quarter of a second (it took up to a second). A flight-map price tag no longer sits under it.
- The Customers note sheet has a little more room for the tip line.

## Behind the scenes
- Scroll bars no longer re-measure their list on every frame. You should notice nothing except less work.

## Not yet tried in the real game
All of the above passes its automatic tests in the offline fake game, but none of 2.4.4 has been played in the real game yet, so please do not count on it. The ones most worth a look:
- Being removed from the group by the driver while the summon box is up: the "Removed from the group" page, and that the "You have been removed from the group." line is what the game really sends.
- Typing the Group Finder note by hand and listing yourself with it.
- The big button following the window while you drag it, and settling back when you let go.
- The calmer pulses on the Home map, the world map and the pin ring, at the real frame rate.
- The Alert character tooltip line (needs the Sound in Background setting off).
- Layout fixes (pay page, flight-map price tags, Settings Reset button, What's new card): each should be checked once with the game's real fonts.

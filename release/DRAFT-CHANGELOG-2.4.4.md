# Wuber 2.4.4 (DRAFT: the wording is for the author to approve)

This is everything since Wuber 2.4.2.

No entry below adds a new addon file, so no **[FULL RESTART]** mark applies this time. Update, then type `/reload`.

## Finding other Wuber drivers
- If someone says "wuber" in public chat (a channel, /say or /yell), in any spelling or case ("Wuber", "WUBER", "wuber's", "Wubers"), Wuber quietly asks that player's Wuber once, with the same hidden message it already uses between Wuber users. If they are a driver, they show in your list like any other driver. Because it is a hidden addon message, it also finds drivers on another layer. Nobody sees anything in chat.
- It is polite by design: one ask per name per hour, 12 an hour in all, at least 10 seconds apart, never in the first minute after login or a reload, never in combat or in a raid, and each one goes out a few seconds late at random so your several game windows do not all send at once.
- A line tagged "[Wuber]" works as before, and an advert still never invites anyone by itself.

## Clicks and buttons
- Group Finder, "List me" sheet: a click in the note box selects the whole note, so you can copy it with Ctrl+C. The box stays read-only and Escape still lets go of the keyboard.
- The big Drive button now picks its spot to stay off the clickable buttons of the open window, not only off its area. Before, on a small screen or at a large Wuber size it could sit on top of buttons on Earnings, Customers or Messages. It is never hidden or made smaller. On the smallest screens at the largest size on Messages, every spot covers something, so it takes the one that covers the least.

## Text that was cut off or ran into something
Wuber's own width table measures text a few percent narrower than the real game draws it. These places were made roomier. No words were shortened or changed.
- The "Don't show again" label on the Skip the bird card.
- Continent names in the World view.
- Names and "owes" amounts in the Drive queue rows and on the floating bar.
- The "Replay" and "Reset place" buttons in Settings.
- The "Summon to" choice ("Where I stand") on the Places sheet.
- The title on Home's driver search no longer runs under the bell button.
- The Earnings target value ("50g / hour") has more room.
- Settings' "Always narrow" choice.
- The four quick picks on the bounty card, including "Custom".
- Paragraphs now leave a little more room for a line the game may wrap: the "Founder (automatic)" line in Settings, Help's "Whispers are the backup" paragraph, the Messages lines and the group card's second line.

## Words that were wrong or out of date
Every help and tip text was read against the code. These now say what Wuber really does:
- Help: "every Wuber nearby" and "every layer and every copy of the world" now say "on your realm" and "every Wuber on your realm". "Nobody can fake a driver or a price" now says "A driver's price comes only from that driver's own character."
- First-open tips: the line "Cheaper drivers glow brighter" is gone (cards no longer glow), "then Request" says "then Request summon", and the Skip tips tooltip names the real way back: Settings, Riding, Tips, Replay.
- Login tips describe the Skip the bird card by what it shows, and "Drive setup" says "Set up driving".
- Settings tips: the Hidden drivers tip says right-click works in Advanced mode; the "Fit window" and keep-closed button tips and the bug report's "player 1" names are explained correctly.
- The `/wuber` check-in line, the not-on-network line and the driver setup card ("Yes or No thanks") say what happens.
- The no-click promise in Help and the driver intro now also names the Messages lines you switch on (greeting, pay reminder, "You're next"), not only the auto-reply.
- What's new: Auto mode invites by itself only when a whisper clearly asks; buyers in public chat only if you switch that on; unclear whispers wait as a lead.
- Help: "Wuber adds the [Wuber] tag to your advert for you."
- The tooltip on the old-summoning-addon card ("Switch it off") says it asks you to type /reload to finish, instead of saying it reloads for you.

## Behind the scenes
- Reading a public chat line for place names costs about 3.7 times fewer Lua instructions, with the same places found and the same typo allowance. You should notice nothing except less work in a busy chat.
- A small unused helper was removed from the World map code. Nothing you see changes.

## Not yet tried in the real game
All of the above passes its automatic tests in the offline fake game, but none of 2.4.4 has been played in the real game yet, so please do not count on it. The ones most worth a look:
- Clicking the Group Finder note box and pressing Ctrl+C (the order in which the real game places the cursor and runs the mouse scripts is not proven).
- Asking someone who says "wuber" in chat: that a driver on another account or another layer shows up, and that nothing appears in chat.
- The big button's new spot on a small screen at a large Wuber size, especially Messages.
- The wider text rooms: the game's text widths were measured only at font sizes 11, 14 and 22, so the sizes in between are estimated. A label may still be tight at an odd setting.
- The tooltip on the old-summoning-addon card: it only appears with that addon installed, which no test account has.
- Still known and not fixed: at the largest UI scale, a long-word toast can be 5 px wider than the room beside the window, with no free place when the What's new card is up.

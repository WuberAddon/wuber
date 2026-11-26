# CurseForge page draft for Wuber 2.4.3 (DRAFT: the wording is for the maintainer to approve)

Nothing is published or uploaded. The page goes up only when the project is public. Base: the live page and the 2.4 page words the maintainer approved, brought up to date for 2.4.3 (see `release/DRAFT-CHANGELOG-2.4.2.md` on PR 68 for the full changelog).

## How to use it
- `release/curseforge-page.html` is the page as ONE line, ready to paste into the CurseForge description editor (Source view).
- Tags used: a, br, code, div, h2, hr, img, li, p, strong, ul. This is the set the live page already uses (a limited inline-style `style="..."` only: colour, font, size, margins, border radius, width).
- The two pictures are the ones already uploaded to the project's Images tab (media.forgecdn.net). They show the older look; retake them from the 2.4.3 Photo tour before the page goes up.
- The GitHub link is https://github.com/WuberAddon/wuber. It works for visitors only once the repository is public.
- Wuber's price is never described and Wuber is never called free (CODE-RULES). The only "free" is for the separate OpenMap addon.

## What changed from the live page
- Headline section is now "What's new in 2.4.3", with the restart-the-game line (new files, a /reload is not enough).
- New "Auto mode, and it is careful" section, driver titles, bottom tabs, Simple mode.
- Removed: the flight price example, the "71 rows down to 15" size claim, "yellow for the main button" (the Drive big button is violet by design), and the maintainer's in-game name from the sign-off.
- Added: a source code and bug reports link to GitHub.
- Raid mode says "at no charge" instead of "free".

## The page as text

[picture: Wuber]

Wuber is basically Uber, but for Warlock summons. Riders get a little phone in their UI to find someone selling summons, see the price, and book. Sellers get one big button that walks them through the whole thing.

There are loads of Warlocks happy to sell summons, and loads of people who'd buy one. They just can't find each other, especially when the global channels bug out. Wuber fixes that, and the more people use it, the easier everyone is to find. It's made for WoW Forever.

**Sell summons?** Wuber finds you customers, runs the whole service with one big button and shows your gold per hour.

## If you want a summon

- Open Wuber and you'll see who's selling summons right now, where to, and for how much. The tabs at the bottom are Ride, Trips and Drive.
- It also tells you what flying there would cost, boats and zeppelins included.
- Hit the main button. Wuber accepts the group invite for you and tells you when to accept the summon.
- Pay in the trade window. Wuber shows you the exact amount, but you type it in yourself. Tipping is up to you.
- There's also a trip history, rider levels and a few medals if you like that sort of thing.

**Works with OpenMap.** If you've got the free [OpenMap](https://www.curseforge.com/wow/addons/openmap) addon, every driver shows up as a pin on your world map with their price, even zoomed right out to the whole continent. Click a pin to book, and Wuber draws your route. Click a driver in the app and the map glides over to them. You don't need OpenMap, though: without it you still see every driver in the app and on the game's own world map.

## Sell summons for gold

- See your gold per open hour (today, 7 days, 30 days) and a heatmap of your best hours to sell.
- One big button. It always says what the next click will do: invite, say hi, summon, say thanks, remove from group.
- It picks up buyers from whispers and public chat. You can edit all the messages it uses.
- You don't have to be a Warlock to run it. Pick a Warlock friend, or your own if you multibox.
- Raid mode does summons for your raid at no charge. If you've got Warlocks parked in different cities, it sends each person to the right one.
- Drivers earn a title from summons that riders confirm: Learner, Cabbie, Black Cab, Chauffeur, and Has The Knowledge at 1,000. Riders see it on your row.

Tip: put "Wuber" in your trade chat adverts. Wuber watches chat for it, so riders find you faster.

## Auto mode, and it is careful

- Wuber invites by itself only when a whisper clearly asks for a ride. Anything it isn't sure about waits in your list, and one click invites.
- A line that sounds like a seller's advert ("WTS", "whisper me", "pst") never invites anyone.
- If someone in public chat clearly asks for a summon to your place, Wuber whispers them once to say how to ask you. That one whisper is the only line Wuber ever sends by itself, at most once an hour per person. Never in combat, in a raid, in an instance or during a ride. Turn it off in Settings, Driving.
- Invited the wrong person? "Oops, wrong invite" on their row says sorry on your next click and takes them out. Wuber remembers them, on your PC only.

## What's new in 2.4.3

- Simple mode by default: riders see the map, the drivers and one button; drivers see the big button and their queue. Everything else is one switch away in Settings, Advanced mode.
- A calmer look: one typeface, flat cards, violet for what's chosen and gold for prices. Tooltips are Wuber's own small cards.
- Tabs at the bottom (Ride, Trips, Drive), pages that slide in and out, and a black pill at the top that follows your ride. "Reduce motion" keeps everything still.
- The portal on your ride screen is a new picture that turns slowly.
- The flight master's map shows a price tag by every place an open driver summons to. Mid-flight, Wuber may offer a faster summon once, and you can switch that off.
- The world map has a "Wuber only" switch that dims the rest of it so the pins stand out.
- Wuber is in the game's own Key Bindings list (open or close Wuber, and a key for the big button) and has a page in Options, AddOns.
- Settings are shorter and grouped, with the rest in Advanced mode. Settings search still finds everything.
- Drivers: riders' rows say what the game knows about their summon, and the big button never casts on a rider who already has one waiting. Mail from a rider who left owing is noted, and Wuber never opens or takes a mail.
- Text that wraps instead of being cut off, and a "What's new" card once after an update.
- Auto mode, crews, raid summons, the flight map, the world map and many small screen fixes are better in 2.4.3. The full list is in the file's changelog.
- **After updating, exit the game completely and start it again once.** A /reload does not find the new files.

## Things worth knowing

- **It never clicks for you.** The game doesn't let addons cast, chat or trade on their own, so every one of those is your click. Wuber just lines them up. The one exception is the single whisper-back above, which you can turn off.
- **It never touches your gold.** You always type the amount yourself, and only completed trades count.
- Not sure it's working? Settings has a "Check my game" button, or type `/wuber test`.

[picture: All of Wuber's features]

## Known issue: syncing isn't perfect yet

Behind the scenes, WoW Forever splits each server into a few hidden realms, and custom chat channels don't work between them. So if you're on one and a driver is on another, the channel Wuber uses can't carry messages between you. That's a bug on Blizzard's side, and it's [reported on the official forums here](https://us.forums.blizzard.com/en/wow/t/wow-forever-custom-chat-channels-not-working-crossrealm-not-game-mode/2370263).

For now, Wuber works around it in a few ways. Copies of Wuber's data also go out as hidden addon whispers, which do work across the split. These are background messages between addons, not chat, so they never show up in anyone's chat window and nobody sees them. In a raid or boss fight the game refuses them, so Wuber holds them and sends them afterwards. Drivers' copies of Wuber also pass on the names of other drivers they've heard about, the same hidden way. And Wuber picks up "Wuber" adverts in public chat. Most drivers still show up, but now and then one might be missing, or turn up a bit late.

When Blizzard fix their end, I'll update Wuber so syncing is instant and nobody gets missed.

---

Source code and bug reports: [https://github.com/WuberAddon/wuber](https://github.com/WuberAddon/wuber)

Found a bug or got an idea? Leave a comment and I'll have a look. You can also open an issue on GitHub.

# Wuber Module Guide

One short guide per folder under `Wuber/`, what to read first, which tests cover it, common pitfalls, and an entry for every file loaded by `Wuber/Wuber.toc`.

## `Wuber/` (root)

Holds `Wuber/Wuber.toc` (the addon load order) and `Wuber/Bindings.xml` (keybindings). Read `Wuber/Wuber.toc` first to see how layers load from `Core` up through `UI`. Covered by `tools/check.lua` and `tests/fixtures/toc-order.txt`. Easy to get wrong: adding a new `.lua` file requires updating both `Wuber/Wuber.toc` (with Windows `\` separators) and `tests/fixtures/toc-order.txt`, plus a full game restart (`/reload` does not load new files).

## `Wuber/Core/`

Foundation layer: addon constants, rulesets, module registry, event bus, place/flight data, and lifetime stats. Read `Wuber/Core/Registry.lua`, `Wuber/Core/Base.lua`, and `Wuber/Core/Runtime.lua` first. Covered by `tests/core/` (including `tests/core/registry_test.lua`, `tests/core/base_test.lua`, and `tests/core/flightpaths_test.lua`). Easy to get wrong: never copy `W.db` or `W.Char()` into a module-level local, never loosen `W.FOUNDER_RULESET` or `W.IsCreator` in `Wuber/Core/Base.lua`, and never hand-edit generated seed or flight blocks.

- `Wuber/Core/Registry.lua` (`Core.Registry`): module registry (`W.Module`, `W.Mod`, `W.CheckModules`).
- `Wuber/Core/Base.lua` (`Core.Base`): addon constants, rulesets (`W.FOUNDER_RULESET`), seed drivers (`W.SEEDS`), pioneers (`W.PIONEERS`), secret-value guards (`W.Plain`/`Str`/`Num`), and `W.InitDB`/`W.Char`/`W.Advanced`.
- `Wuber/Core/Stats.lua` (`Core.Stats`): trip history, lifetime totals (`W.Stats`), rider tiers (`W.TIERS`), ranks (`W.RANKS`), and milestones (`W.MILESTONES`).
- `Wuber/Core/Runtime.lua` (`Core.Runtime`): logging (`W.Print`/`Error`/`Safe`/`Debug`), timers (`W.After`/`Every`), event bus (`W.On`/`Listen`/`Fire`/`OnLogin`), name/money/text helpers, sounds, combat/group checks, and blocked-action guard.
- `Wuber/Core/Words.lua` (`Core.Words`): editable blocked-word and place-nickname data (`W.Words`, `W.SPAM_WORDS`).
- `Wuber/Core/Places.lua` (`Core.Places`): `W.PLACES` table, place search/matching, anti-spam checks (`W.SpamReason`, `W.SentenceSpam`), world positions, and travel time saved (`W.TravelSaved`).
- `Wuber/Core/Flights.lua` (`Core.Flights`): flight cost and duration lookups (`W.FlightCost`, `W.FlightTime`, `W.TAXI`) and learned-price store.
- `Wuber/Core/FlightPaths.lua` (`Core.FlightPaths`): generated flight route polylines (`W.TAXI_PATHS`) and continent bounds (`W.TAXI_BOUNDS`) for the world map.
- `Wuber/Core/FlightTimes.lua` (`Core.FlightTimes`): records real flight times (`TakeTaxiNode`), calibrates spline estimates (`W.FlightRoute`, `W.OnTaxi`, `W.FlightLeft`), and fits flight-map coordinates.
- `Wuber/Core/Wrapped.lua` (`Core.Wrapped`): pure monthly recap calculations for Azeroth Wrapped (`Core.Wrapped.Month`/`Range`/`MonthName`/`Key`).

## `Wuber/Net/`

Peer-to-peer addon messaging, discovery beacons, ride state protocol, community channels, bounties, and shared flight prices. Read `Wuber/Net/Transport.lua`, `Wuber/Net/Discovery.lua`, and `Wuber/Net/Rides.lua` first. Covered by `tests/net/` (including `tests/net/portal_test.lua`, `tests/net/bounty_test.lua`, and `tests/net/raincheck_test.lua`). Easy to get wrong: addon messages are capped at 250 bytes and throttled, so always send through `Wuber/Net/Transport.lua`'s outbox rather than `C_ChatInfo.SendAddonMessage` directly, and never call `SendChatMessage` from addon code.

- `Wuber/Net/Base.lua` (`Net.Base`): net constants (`NETK`, `W.STAGES`, `W.BADGES`), wire codec (`W.Encode`/`Decode`), hidden channel management, and whisper-fallback state (`W.fallback`).
- `Wuber/Net/Update.lua` (`Net.Update`): learns newer addon versions from incoming traffic and shows a quiet update toast once per session.
- `Wuber/Net/Community.lua` (`Net.Community`): WoW Community second-transport discovery (`W.CommunityAvailable`, `W.CommunityCheck`, `W.CommunityStatus`).
- `Wuber/Net/Transport.lua` (`Net.Transport`): single outgoing message queue with token bucket/priorities (`W.SendChannel`, `W.SendTo`, `W.FlushQueue`) and group/invite/summon actions.
- `Wuber/Net/Beacons.lua` (`Net.Beacons`): driver beacons (`D`/`X`/`Q`) both ways: rider-side driver list (`W.DriversSorted`, `W.Ping`) and driver-side broadcasting (`W.SendBeacon`, `W.SetDriving`).
- `Wuber/Net/Requests.lua` (`Net.Requests`): driver-side ride protocol (`W.AcceptRequest`, `W.DeclineRequest`, `W.SendStage`, `W.SendQueue`) and `/reload` restoration.
- `Wuber/Net/Rides.lua` (`Net.Rides`): rider-side ride lifecycle (`W.RequestRide`, `W.CancelRide`, `W.EndRide`, `W.Rate`), auto-accept, arrival, and trade-window payment tracking (`W.PayFare`, `W.FareLeft`).
- `Wuber/Net/Favourites.lua` (`Net.Favourites`): favourites, watched destinations, hidden drivers, "your usual" (`W.Usual`), and online/watch toasts.
- `Wuber/Net/Discovery.lua` (`Net.Discovery`): whisper rounds, gossip mesh (`K`), known drivers, contacts, founders' directory, and driver announces (`W.WhisperRound`, `W.KnownDrivers`).
- `Wuber/Net/Outreach.lua` (`Net.Outreach`): public chat `[Wuber]` adverts (`W.AdvertPlan`, `W.HeardChatLine`) and network status lines (`W.NetStatus`).
- `Wuber/Net/Flights.lua` (`Net.Flights`): shared flight prices between Wuber users (`W.FlyNet`, `W.AskFlight`, `F~` messages).
- `Wuber/Net/Inbox.lua` (`Net.Inbox`): incoming `CHAT_MSG_ADDON`/`CHAT_MSG_WHISPER` dispatchers, channel/club events, and the 1 s `W.NetTick`.
- `Wuber/Net/Portal.lua` (`Net.Portal`): live portal tracker wire (`W.SendRitual`), two-word passphrase (`W.Passphrase`), and founder gold-portal check (`W.FounderSummon`).
- `Wuber/Net/Raincheck.lua` (`Net.Raincheck`): lag-drop raincheck wire (`W.Raincheck.*`, `W.SendIOU`) and rider-side raincheck display copy.
- `Wuber/Net/Bounty.lua` (`Net.Bounty`): want-to-go bounties (`W.Bounty.Pin`/`Cancel`/`Mine`/`Demand`/`Place`, `W.bounties`).
- `Wuber/Net/Provider.lua` (`Net.Provider`): public `WuberAPI` for external driver addons (`WuberAPI.SetDriver`, `Accept`, `Decline`, `Beacon`, `Drivers`, `Queue`).
- `Wuber/Net/GroupFinder.lua` (`Net.GroupFinder`): optional Group Finder integration (`W.GroupFinder`) for rider searches and driver listing status.

## `Wuber/Theme/`

Visual tokens, fonts, animation helpers, and reusable widgets (pills, toggles, sliders, sheets, and edit boxes). Read `Wuber/Theme/Tokens.lua`, `Wuber/Theme/Widgets.lua`, and `Wuber/Theme/Anim.lua` first. Covered by `tests/theme/` (including `tests/theme/tokens_test.lua` and `tests/theme/widgets_test.lua`). Easy to get wrong: never `Scale`-animate a frame that holds text (use alpha, translation, or non-text container sizing instead).

- `Wuber/Theme/Tokens.lua` (`Theme.Tokens`): media paths, fonts, sizes, palette (`T.C`, `T.Hex`, `T.RGB`), text helpers (`T.SetFont`, `T.Fit`, `T.MeasureText`, `T.Text`), textures, and `T.Card`.
- `Wuber/Theme/Anim.lua` (`Theme.Anim`): `T.Animate` (`A.*`) fades, moves, slides, pops, pulses, spinners, `T.Tween`, `T.Glide`, Reduce Motion, and page push/pop (`A.Push`, `A.PopPage`).
- `Wuber/Theme/Widgets.lua` (`Theme.Widgets`): pills (`T.Pill`, `T.MainButton`), chips, badges, round buttons, tooltips (`T.Tip`), toggles, sliders, segmented controls, bars, glows, crowns, and tier colours.
- `Wuber/Theme/Forms.lua` (`Theme.Forms`): driver-screen and list building blocks (`T.Line`, `T.Field`, `T.EdgeFade`, `T.Scroll`, `T.Sheet`, `T.SheetCard`, `T.Para`, `T.AlertCard`, `T.WholeOnHover`, `T.RowGroup`, `T.RowHeading`).

## `Wuber/FX/`

Visual effects, driver crowns and badges, the pioneer emblem, nameplate overlays, and world-space effects. Read `Wuber/FX/Effects.lua`, `Wuber/FX/Nameplates.lua`, and `Wuber/FX/Emblem.lua` first. Covered by `tests/fx/` (including `tests/fx/emblem_test.lua` and `tests/fx/badge_test.lua`). Easy to get wrong: reading a nameplate's size, scale, or position from addon code (or touching a forbidden nameplate) is a client violation.

- `Wuber/FX/Effects.lua` (`FX.Effects`): effects engine (`W.FX`): flipbooks, crowns/badges (`FX.Crown`, `FX.Badge`), screen effects (`FX.Play`, `FX.Fullscreen`), and `FX.Goldify`.
- `Wuber/FX/Moments.lua` (`FX.Moments`): triggers screen moments and bursts on ride, payment, rating, and founder ritual events (`FX.OnRide`, `FX.OnPaid`, `FX.OnRating`).
- `Wuber/FX/Nameplates.lua` (`FX.Nameplates`): overhead crowns and badges on nameplates (`W.Plates`) and mouse-over tooltip lines.
- `Wuber/FX/Emblem.lua` (`FX.Emblem`): floating Pioneer emblem over listed Pioneers' nameplates (`W.Emblem`, `W.EmblemHeard`, `W.EmblemFlag`).

## `Wuber/Drive/`

Driver engine: service state, customer queue, raid summons, trade payment detection, crew coordination, and big-button macro planning. Read `Wuber/Drive/Plan.lua`, `Wuber/Drive/Button.lua`, and `Wuber/Drive/Trade.lua` first. Covered by `tests/drive/` (including `tests/drive/plan_test.lua`, `tests/drive/button_test.lua`, and `tests/drive/queue_test.lua`). Easy to get wrong: `Wuber/Drive/Button.lua` manages a secure button—never show, hide, move, or call `SetAttribute` on it in combat, and never put gold into a trade from addon code (`C_TradeInfo.SetTradeMoney` is forbidden).

- `Wuber/Drive/Core.lua` (`Drive.Core`): driver engine core (`W.Drive` / `DR.*`), constants, option defaults (`DR.Opt`), crew/runner/captain state, and public-warning helpers.
- `Wuber/Drive/Places.lua` (`Drive.Places`): driver place names, `WTB summon` public chat parsing (`DR.PublicWant`, `DR.AskedPlaces`), stations (`DR.Stations`), and arrival checks (`DR.ArrivedAt`).
- `Wuber/Drive/Careful.lua` (`Drive.Careful`): strict auto-invite gate (`DR.Careful`) and "oops, wrong invite" learning (`DR.CanOops`, `DR.Oops`, `DR.OopsLog`).
- `Wuber/Drive/AutoReply.lua` (`Drive.AutoReply`): auto-reply whispers for clear public summon requests (`DR.TryReply`, `DR.CanReply`, `DR.ReplyText`).
- `Wuber/Drive/Team.lua` (`Drive.Team`): crew coordination over `WUBERT` (`DR.OfferCrew`, `DR.AnswerOffer`, `DR.LeaveCrew`, `DR.SyncNow`, `DR.KeepOwnConfig`/`RestoreOwnConfig`).
- `Wuber/Drive/Queue.lua` (`Drive.Queue`): rider queue and state machine (`DR.customers`, `DR.Create`, `DR.SetState`, `DR.Sorted`, `DR.Lead`, `DR.Request`, `DR.Invite`, `DR.MarkPaid`).
- `Wuber/Drive/Chat.lua` (`Drive.Chat`): outgoing driver message templates, placeholders, and paced chat queue (`DR.TEMPLATES`, `DR.Template`, `DR.PumpChat`).
- `Wuber/Drive/Trade.lua` (`Drive.Trade`): trade-window payment detection (`DR.TradeUpdate`, `DR.TradeDone`, `DR.PumpTrade`).
- `Wuber/Drive/Service.lua` (`Drive.Service`): open/pause state, price, destination, service name, caster/summoners, soul shards, and advert scheduling (`DR.SetOpen`, `DR.SetPrice`, `DR.SetDest`).
- `Wuber/Drive/Ready.lua` (`Drive.Ready`): blocklist (`DR.Blacklist`, `DR.Unblacklist`), readiness checks (`DR.Readiness`), and the 1 s `DR.Tick`.
- `Wuber/Drive/Raid.lua` (`Drive.Raid`): raid summons engine: raid queue, claims, summoner picks, and sync (`DR.RaidQueue`, `DR.RaidTick`, `DR.RaidPick`, `DR.RaidSync`).
- `Wuber/Drive/Log.lua` (`Drive.Log`): earnings log, stats, 24 h / 7x24 heatmap data (`DR.BestHours`, `DR.Heatmap`), shift summaries, and summon average (`DR.SummonAvg`).
- `Wuber/Drive/Cast.lua` (`Drive.Cast`): big-button helpers, ritual watcher (`DR.CastWatch`), incoming-summon guard (`DR.SummonSeen`, `DR.SummonPending`), and `DR.NextSummon`.
- `Wuber/Drive/Plan.lua` (`Drive.Plan`): decides what the big button's next click does (`DR.Plan`).
- `Wuber/Drive/AutoLines.lua` (`Drive.AutoLines`): automatic whisper lines (greeting, pay reminder, "You're next": `DR.LineOn`, `DR.TryLine`, `DR.PumpLines`).
- `Wuber/Drive/Button.lua` (`Drive.Button`): secure `WuberDriveButton` (`DR.BuildButton`, `B.Place`, `B.Dock`, `DR.ApplyBinding`, `DR.Skip`).
- `Wuber/Drive/Net.lua` (`Drive.Net`): driver engine-to-network bridge (`DR.NetDriver`, `DR.NetBeacon`, `DR.NetAttach`, `DR.PassWire`).
- `Wuber/Drive/Bell.lua` (`Drive.Bell`): alert character / bell notifications (`DR.Ring`, `DR.BellAlert`, `DR.BellSet`).
- `Wuber/Drive/Danger.lua` (`Drive.Danger`): hot-drop PvP danger tracking at the summon spot (`DR.DangerLevel`, `DR.DangerPlate`, `DR.DangerCombat`).
- `Wuber/Drive/Kitchen.lua` (`Drive.Kitchen`): driver-side live portal tracker (`DR.KitchenSend`, `DR.RiderVersionOk`) forwarding `DRIVE_RITUAL` phases via `W.SendRitual`.
- `Wuber/Drive/Cut.lua` (`Drive.Cut`): clicker cut ledger (`DR.Cut`, `DR.CutSplit`, `DR.CutText`, `DR.CutLog`) for crew shift splits.
- `Wuber/Drive/Raincheck.lua` (`Drive.Raincheck`): authoritative driver raincheck book (`DR.RaincheckEligible`, `DR.GiveRaincheck`, `DR.RaincheckRedeem`, `DR.Rainchecks`).
- `Wuber/Drive/Rank.lua` (`Drive.Rank`): driver rank count from verified rider-reported summons (`DR.RankCount`, `DR.RankInfo`).
- `Wuber/Drive/Book.lua` (`Drive.Book`): driver customer book (`DR.BookEntry`, `DR.SetNote`, `DR.SetGifted`, `DR.CustomerFacts`) with crew-window sync.
- `Wuber/Drive/Mail.lua` (`Drive.Mail`): after-the-ride mail instructions and inbox header scan (`DR.MailLine`, `DR.MailScan`, `DR.MailNote`).
- `Wuber/Drive/Commands.lua` (`Drive.Commands`): `/wuber drive` subcommands (`DR.COMMANDS`, `DR.Command`).

## `Wuber/UI/`

Top-level app shell, handset frame, fold/unfold layout, toasts, secure rider buttons, flight-map offers, and slash commands. Read `Wuber/UI/Window.lua`, `Wuber/UI/Phone.lua`, and `Wuber/UI/Secure.lua` first. Covered by `tests/ui/` (including `tests/ui/window_test.lua`, `tests/ui/phone_test.lua`, and `tests/ui/fold_test.lua`). Easy to get wrong: secure buttons in `Wuber/UI/Secure.lua` can only be created at `PLAYER_LOGIN` and cannot be changed in combat; player-facing wording must not be changed without maintainer approval.

- `Wuber/UI/Kit.lua` (`UI.Kit`): shared rider UI state (`UI.state`), window constants (`UI.PHONE`), driver/ride view adapters (`UI.Drivers`, `UI.Ride`), `UI.FitOrWrap`, and `UI.MayOpen`.
- `Wuber/UI/Toasts.lua` (`UI.Toasts`): toast queue (`UI.Toast`, `UI.UndoToast`) and HUD/chat avoidance helpers (`UI.ClearOfChat`, `UI.ClearOfHud`).
- `Wuber/UI/Secure.lua` (`UI.Secure`): secure Request/Cancel macro buttons, advert/go overlays, and `WuberShareButton` (`UI.SyncSecure`).
- `Wuber/UI/Window.lua` (`UI.Window`): app window, scale, tabs (`UI.AddTab`, `UI.SelectTab`), screen routing, header layout (`UI.HeadPush`, `UI.HeadControl`), and `UI.Toggle`/`Show`/`Refresh`.
- `Wuber/UI/Moments.lua` (`UI.Moments`): ride toasts, minimap flash, milestone/level-up popups (`UI.Celebrate`, `UI.ShowNextPop`), and raincheck/rank cards.
- `Wuber/UI/Coach.lua` (`UI.Coach`): first-open coach marks (`UI.COACH`, `UI.CoachStep`, `UI.ReplayCoach`, `UI.EndCoach`, `Mod.Why`).
- `Wuber/UI/TipTexts.lua` (`UI.TipTexts`): the 14 login-tip texts and their "Show me" screen/target definitions (`TipTextsMod.list`, `Show`, `Target`).
- `Wuber/UI/Phone.lua` (`UI.Phone`): splash screen, handset bezel, status bar (`UI.SignalBars`, `UI.UpdateStatusBar`), and the top live-ride pill.
- `Wuber/UI/Fold.lua` (`UI.Fold`): two-pane 720-wide fold/unfold controller (`UI.Fold.Register`, `Page`, `Toggle`, `Apply`, `IsUnfolded`).
- `Wuber/UI/Share.lua` (`UI.Share`): share pill registration and macro/state sync (`UI.Share.Register`, `Target`, `Sync`) for `WuberShareButton`.
- `Wuber/UI/Minimap.lua` (`UI.Minimap`): minimap button placement, flash, and pause indicator (`UI.MayPause`, `UI.FlashMinimap`, `UI.RefreshMinimap`).
- `Wuber/UI/Bird.lua` (`UI.Bird`): "Skip the bird" card beside the flight map (`Mod.Pick`, `Show`, `Hide`, `Why`).
- `Wuber/UI/FlightPins.lua` (`UI.FlightPins`): summon price tags and markers on the flight master's map (`Mod.Refresh`, `Hide`, `Pins`, `Why`).
- `Wuber/UI/InFlight.lua` (`UI.InFlight`): mid-flight summon offer card `WuberInFlight` (`Mod.Check`, `Refresh`, `Show`/`Hide`, `Why`).
- `Wuber/UI/Tips.lua` (`UI.Tips`): login tip sheet `WuberTipCard` (`Mod.ShowNow`, `Next`, `IsOn`, `SetOn`, `Why`).
- `Wuber/UI/WhatsNew.lua` (`UI.WhatsNew`): per-version "What's new" card (`Mod.NOTES`, `Show`, `Expand`, `PlaceBeside`, `Why`).
- `Wuber/UI/Bug.lua` (`UI.Bug`): `/wuber bug` anonymised bug-report sheet (`UI.Bug.Open`, `Close`, `Report`).
- `Wuber/UI/Commands.lua` (`UI.Commands`): `/wuber` and `/ride` slash commands (`W.SlashCommand`), keybinding labels, `/wuber why`, and `W.SelfTest`.

## `Wuber/UI/Driver/`

Driver console screens, queue rows, sheets, crew wizard, raid view, and earnings/heatmap charts. Read `Wuber/UI/Driver/Build.lua`, `Wuber/UI/Driver/Rows.lua`, and `Wuber/UI/Driver/Sheets.lua` first. Covered by `tests/ui/driver/` (including `tests/ui/driver/build_test.lua`, `tests/ui/driver/rows_test.lua`, and `tests/ui/driver/sheets_test.lua`). Easy to get wrong: layout and text fit are checked across window sizes and scales by `tools/layout-check.lua`, so make frames fit the words rather than shortening text.

- `Wuber/UI/Driver/State.lua` (`UI.Driver.State`): Drive tab kit/state (`D.kit`, `D.FOLD`), online/pause transitions (`D.SetOnline`, `D.SetPaused`), and advert overlay hooks.
- `Wuber/UI/Driver/Rows.lua` (`UI.Driver.Rows`): queue and raid rows (`D.Row`, `D.PaintRow`, `D.Describe`, `D.RowAction`, `D.RowClick`, `D.OpenMenu`).
- `Wuber/UI/Driver/Build.lua` (`UI.Driver.Build`): builds the driver console, status strip, big-button slot, mode bar (`D.SetMode`), welcome/provider views, and "Your business" links.
- `Wuber/UI/Driver/Draw.lua` (`UI.Driver.Draw`): refreshes the driver console, status, fuel gauge (`D.PaintFuel`), queue, crew chips, and community strip.
- `Wuber/UI/Driver/Raid.lua` (`UI.Driver.Raid`): raid-summon console parts, summoners, not-here rows, and unfolded raid side pane (`D.DrawRaidSide`, `D.FOLD.raid`).
- `Wuber/UI/Driver/Console.lua` (`UI.Driver.Console`): Drive tab shell, screen/sheet switching (`D.ShowScreen`, `D.ShowSheet`), big-button dock (`D.SyncDock`), and unfolded side pane (`D.DrawConsoleSide`).
- `Wuber/UI/Driver/Screens.lua` (`UI.Driver.Screens`): shared builder kit (`D.screens`, `UI.drive`, `Screen`, `Pool`) for the driver's secondary screens.
- `Wuber/UI/Driver/Wizard.lua` (`UI.Driver.Wizard`): 3-step crew wizard, people rows, and summoner order (`D.SaveSummoners`, `D.screens.wizard`).
- `Wuber/UI/Driver/Crew.lua` (`UI.Driver.Crew`): Crew management screen (`D.screens.crew`).
- `Wuber/UI/Driver/Messages.lua` (`UI.Driver.Messages`): Messages editor with live preview, auto-line toggles, and Blocked list (`D.screens.messages`, `D.screens.blocked`).
- `Wuber/UI/Driver/Earnings.lua` (`UI.Driver.Earnings`): Earnings screen, 24 h chart, best hours, 7x24 heatmap (`D.HeatGrid`, `D.BuildHeatmap`), crew cut, and rainchecks (`D.screens.earnings`).
- `Wuber/UI/Driver/Demand.lua` (`UI.Driver.Demand`): rider bounty demand line, "Wanted nearby" card (`D.DemandCard`), and Demand screen (`D.screens.demand`).
- `Wuber/UI/Driver/Sheets.lua` (`UI.Driver.Sheets`): price/place sheet, raid summoner picker, row menu, retire card, and end-of-shift fair-split card (`D.screens.sheet`, `shift`, `menu`).
- `Wuber/UI/Driver/Customers.lua` (`UI.Driver.Customers`): customer book UI, Note sheet, "Get Wuber" / "Gifted" marks, and Customers screen (`D.CustomerMenu`, `D.PaintMarks`, `D.CrewOwnMark`).
- `Wuber/UI/Driver/Mini.lua` (`UI.Driver.Mini`): crew-offer card (`UI.CrewOffer`), floating mini console (`D.UpdateMini`), and driver toast/alert helpers (`UI.ShowDrive`).

## `Wuber/UI/Map/`

World map driver pins, route polylines, and map-based booking helpers. Read `Wuber/UI/Map/Base.lua`, `Wuber/UI/Map/Map.lua`, and `Wuber/UI/Map/Pins.lua` first. Covered by `tests/round15_a.lua` and `tests/layout/`. Easy to get wrong: `C_Map` and `WorldMapFrame` helpers must guard against nil/secret values and clients where `OpenMapAPI` is absent.

- `Wuber/UI/Map/Base.lua` (`UI.Map.Base`): world-map constants, colours, OpenMap/Blizzard map position helpers, and driver list for pins (`W.Map`).
- `Wuber/UI/Map/Pins.lua` (`UI.Map.Pins`): world-map pin widgets, tooltips, pulse, aura ring, crown/badge, and creator sparkle.
- `Wuber/UI/Map/Route.lua` (`UI.Map.Route`): route polylines on the world map and app map panel (`M.RouteOnPanel`, `M.HideRouteOnPanel`).
- `Wuber/UI/Map/Map.lua` (`UI.Map.Map`): pin pool layout, map hover/booking (`M.BookPlace`, `M.ShowDriver`), `M.Open`, `M.Veil`, `M.OnlyPill`, and `M.Refresh`.

## `Wuber/UI/Rider/`

Rider-facing screens: Home, Confirm/Booking, Ride progress, Payment/Tips, Done/Sorry, Trips, and Azeroth Wrapped. Read `Wuber/UI/Rider/Booking.lua`, `Wuber/UI/Rider/Ride.lua`, and `Wuber/UI/Rider/Pay.lua` first. Covered by `tests/ui/rider/` (including `tests/ui/rider/booking_test.lua`, `tests/ui/rider/trips_test.lua`, and `tests/ui/rider/wrapped_test.lua`). Easy to get wrong: only `[Wuber]` drivers appear in the rider's list, and payment UI must never claim one-click payment.

- `Wuber/UI/Rider/HomeMap.lua` (`UI.Rider.HomeMap`): rider map panel, player/driver/"You" pins, `UI.RouteOnMap`, and dock/undock into the unfolded side pane.
- `Wuber/UI/Rider/SeaRoute.lua` (`UI.Rider.SeaRoute`): splits sea-crossing routes and draws "continues by boat / zeppelin" arrows (`SeaRoute.Split`, `Arrow`, `Draw`).
- `Wuber/UI/Rider/WorldMap.lua` (`UI.Rider.WorldMap`): unfolded two-continent world map side pane (`WorldMap.Build`, `Show`, `Refresh`, `Project`).
- `Wuber/UI/Rider/Cards.lua` (`UI.Rider.Cards`): driver row/card builder, avatar/badge, heart/favourite/hide menu, and search filtering.
- `Wuber/UI/Rider/Home.lua` (`UI.Rider.Home`): Home screen, driver list (`UI.LayoutCards`), "Your usual", raid card, empty state, and bounty pin controls.
- `Wuber/UI/Rider/Booking.lua` (`UI.Rider.Booking`): shared booking widgets: Fly-vs-Summon dial (`Booking.Dial`, `Score`, `Verdict`) and route header (`Booking.RouteHeader`).
- `Wuber/UI/Rider/Confirm.lua` (`UI.Rider.Confirm`): Confirm booking screen and Finding screen (`UI.TierChip`, `UI.RaincheckCover`).
- `Wuber/UI/Rider/Pay.lua` (`UI.Rider.Pay`): tip selector (`UI.TIP_STOPS`, `UI.SetTipPct`, `UI.PayTotal`), `UI.OpenForPay`, and trade-window pay strip (`UI.TradePartnerOK`).
- `Wuber/UI/Rider/Ride.lua` (`UI.Rider.Ride`): Driver-found / live ride screen (`UI.DoAction`, `UI.FlexText`, `UI.RitualText`) from accepted through paying.
- `Wuber/UI/Rider/Done.lua` (`UI.Rider.Done`): Done and Sorry screens, unpaid mail instructions, and raincheck askability (`UI.RaincheckAskable`).
- `Wuber/UI/Rider/Trips.lua` (`UI.Rider.Trips`): Trips tab (`UI.BuildTrips`, `UI.UpdateTrips`, `UI.TripsHM`, `UI.RaincheckList`): time saved, level, milestones, and history.
- `Wuber/UI/Rider/Wrapped.lua` (`UI.Rider.Wrapped`): Azeroth Wrapped card, 5-slide story, share pill, and 6-month chip on the Trips tab (`Mod.Due`, `Open`, `Slides`).

## `Wuber/UI/Settings/`

Settings panel, search, page navigation, and option rows/toggles/sliders. Read `Wuber/UI/Settings/Panel.lua`, `Wuber/UI/Settings/Pages.lua`, and `Wuber/UI/Settings/Rows.lua` first. Covered by `tests/ui/settings/` (including `tests/ui/settings/pages_test.lua`, `tests/ui/settings/rows_test.lua`, and `tests/ui/settings/find_test.lua`). Easy to get wrong: rows must not clip or overlap their controls in either folded (narrow) or unfolded (wide) mode.

- `Wuber/UI/Settings/Rows.lua` (`UI.Settings.Rows`): Settings row builders (`UI.settings`), toggles, buttons, driving/riding options, and "Check my game".
- `Wuber/UI/Settings/Find.lua` (`UI.Settings.Find`): Settings "Ask or search" box, keyword matching (`Mod.match`), section summaries, and match highlight.
- `Wuber/UI/Settings/Pages.lua` (`UI.Settings.Pages`): pushed Settings/Help/section page container, Help text (`UI.HELP_TITLE`, `UI.HELP`), and Blizzard AddOns options page builder.
- `Wuber/UI/Settings/Panel.lua` (`UI.Settings.Panel`): Settings panel build/layout/update (`UI.BuildSettings`, `UI.OpenSettings`, `UI.CloseSettings`, `UI.LayoutSettings`) and `WuberOptionsPage`.

## `Wuber/Media/`

Packaged font and effect assets (`Wuber/Media/fonts/`, `Wuber/Media/fx/`), with no Lua code. Covered indirectly by `tests/harness.lua`, which fails `T.clean(w)` if any referenced texture or font is missing on disk. Easy to get wrong: adding or renaming a media file requires a full game restart, and every path referenced by `Wuber/Theme/Tokens.lua` must exist on disk.

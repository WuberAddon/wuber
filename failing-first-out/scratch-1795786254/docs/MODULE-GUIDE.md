# Wuber Module Guide

One short guide per folder under `Wuber/`, what to read first, which tests cover it, and common pitfalls.

## `Wuber/` (root)

Holds `Wuber/Wuber.toc` (the addon load order) and `Wuber/Bindings.xml` (keybindings). Read `Wuber/Wuber.toc` first to see how layers load from `Core` up through `UI`. Covered by `tools/check.lua` and `tests/fixtures/toc-order.txt`. Easy to get wrong: adding a new `.lua` file requires updating both `Wuber/Wuber.toc` (with Windows `\` separators) and `tests/fixtures/toc-order.txt`, plus a full game restart (`/reload` does not load new files).

## `Wuber/Core/`

Foundation layer: addon constants, rulesets, module registry, event bus, place/flight data, and lifetime stats. Read `Wuber/Core/Registry.lua`, `Wuber/Core/Base.lua`, and `Wuber/Core/Runtime.lua` first. Covered by `tests/core/` (including `tests/core/registry_test.lua`, `tests/core/base_test.lua`, and `tests/core/flightpaths_test.lua`). Easy to get wrong: never copy `W.db` or `W.Char()` into a module-level local, never loosen `W.FOUNDER_RULESET` or `W.IsCreator` in `Wuber/Core/Base.lua`, and never hand-edit generated seed or flight blocks.

## `Wuber/Net/`

Peer-to-peer addon messaging, discovery beacons, ride state protocol, community channels, bounties, and shared flight prices. Read `Wuber/Net/Transport.lua`, `Wuber/Net/Discovery.lua`, and `Wuber/Net/Rides.lua` first. Covered by `tests/net/` (including `tests/net/portal_test.lua`, `tests/net/bounty_test.lua`, and `tests/net/raincheck_test.lua`). Easy to get wrong: addon messages are capped at 250 bytes and throttled, so always send through `Wuber/Net/Transport.lua`'s outbox rather than `C_ChatInfo.SendAddonMessage` directly, and never call `SendChatMessage` from addon code.

## `Wuber/Theme/`

Visual tokens, fonts, animation helpers, and reusable widgets (pills, toggles, sliders, sheets, and edit boxes). Read `Wuber/Theme/Tokens.lua`, `Wuber/Theme/Widgets.lua`, and `Wuber/Theme/Anim.lua` first. Covered by `tests/theme/` (including `tests/theme/tokens_test.lua` and `tests/theme/widgets_test.lua`). Easy to get wrong: never `Scale`-animate a frame that holds text (use alpha, translation, or non-text container sizing instead).

## `Wuber/FX/`

Visual effects, driver crowns and badges, the pioneer emblem, nameplate overlays, and world-space effects. Read `Wuber/FX/Effects.lua`, `Wuber/FX/Nameplates.lua`, and `Wuber/FX/Emblem.lua` first. Covered by `tests/fx/` (including `tests/fx/emblem_test.lua` and `tests/fx/badge_test.lua`). Easy to get wrong: reading a nameplate's size, scale, or position from addon code (or touching a forbidden nameplate) is a client violation.

## `Wuber/Drive/`

Driver engine: service state, customer queue, raid summons, trade payment detection, crew coordination, and big-button macro planning. Read `Wuber/Drive/Plan.lua`, `Wuber/Drive/Button.lua`, and `Wuber/Drive/Trade.lua` first. Covered by `tests/drive/` (including `tests/drive/plan_test.lua`, `tests/drive/button_test.lua`, and `tests/drive/queue_test.lua`). Easy to get wrong: `Wuber/Drive/Button.lua` manages a secure button—never show, hide, move, or call `SetAttribute` on it in combat, and never put gold into a trade from addon code (`C_TradeInfo.SetTradeMoney` is forbidden).

## `Wuber/UI/`

Top-level app shell, handset frame, fold/unfold layout, toasts, secure rider buttons, flight-map offers, and slash commands. Read `Wuber/UI/Window.lua`, `Wuber/UI/Phone.lua`, and `Wuber/UI/Secure.lua` first. Covered by `tests/ui/` (including `tests/ui/window_test.lua`, `tests/ui/phone_test.lua`, and `tests/ui/fold_test.lua`). Easy to get wrong: secure buttons in `Wuber/UI/Secure.lua` can only be created at `PLAYER_LOGIN` and cannot be changed in combat; player-facing wording must not be changed without maintainer approval.

## `Wuber/UI/Driver/`

Driver console screens, queue rows, sheets, crew wizard, raid view, and earnings/heatmap charts. Read `Wuber/UI/Driver/Build.lua`, `Wuber/UI/Driver/Rows.lua`, and `Wuber/UI/Driver/Sheets.lua` first. Covered by `tests/ui/driver/` (including `tests/ui/driver/build_test.lua`, `tests/ui/driver/rows_test.lua`, and `tests/ui/driver/sheets_test.lua`). Easy to get wrong: layout and text fit are checked across window sizes and scales by `tools/layout-check.lua`, so make frames fit the words rather than shortening text.

## `Wuber/UI/Map/`

World map driver pins, route polylines, and map-based booking helpers. Read `Wuber/UI/Map/Base.lua`, `Wuber/UI/Map/Map.lua`, and `Wuber/UI/Map/Pins.lua` first. Covered by `tests/round15_a.lua` and `tests/layout/`. Easy to get wrong: `C_Map` and `WorldMapFrame` helpers must guard against nil/secret values and clients where `OpenMapAPI` is absent.

## `Wuber/UI/Rider/`

Rider-facing screens: Home, Confirm/Booking, Ride progress, Payment/Tips, Done/Sorry, Trips, and Azeroth Wrapped. Read `Wuber/UI/Rider/Booking.lua`, `Wuber/UI/Rider/Ride.lua`, and `Wuber/UI/Rider/Pay.lua` first. Covered by `tests/ui/rider/` (including `tests/ui/rider/booking_test.lua`, `tests/ui/rider/trips_test.lua`, and `tests/ui/rider/wrapped_test.lua`). Easy to get wrong: only `[Wuber]` drivers appear in the rider's list, and payment UI must never claim one-click payment.

## `Wuber/UI/Settings/`

Settings panel, search, page navigation, and option rows/toggles/sliders. Read `Wuber/UI/Settings/Panel.lua`, `Wuber/UI/Settings/Pages.lua`, and `Wuber/UI/Settings/Rows.lua` first. Covered by `tests/ui/settings/` (including `tests/ui/settings/pages_test.lua`, `tests/ui/settings/rows_test.lua`, and `tests/ui/settings/find_test.lua`). Easy to get wrong: rows must not clip or overlap their controls in either folded (narrow) or unfolded (wide) mode.

## `Wuber/Media/`

Packaged font and effect assets (`Wuber/Media/fonts/`, `Wuber/Media/fx/`), with no Lua code. Covered indirectly by `tests/harness.lua`, which fails `T.clean(w)` if any referenced texture or font is missing on disk. Easy to get wrong: adding or renaming a media file requires a full game restart, and every path referenced by `Wuber/Theme/Tokens.lua` must exist on disk.

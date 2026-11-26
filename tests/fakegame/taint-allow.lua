-- tests/fakegame/taint-allow.lua: what Wuber's code may do to the game's own things, and why (the taint guard, tests/harness.lua H.taint).
-- In the real game anything an addon writes into a Blizzard table, replaces in a Blizzard global, or hangs under a Blizzard window
-- can taint the game's own code ("AddOn blocked", a window that will not open in a fight). The fake game fails the test when the
-- addon does any of these and the case is not listed here. EVERY entry needs a reason; a line with no reason is an error.
-- Do not add an entry to make a test pass: find another way (SetParent later, hooksecurefunc, a table of your own).
-- The world map has its own, older rules: tests/lib/maptaint.lua with tests/fixtures/map-taint-known.txt.
return {
	-- A game table the addon may write into, by name: append = a Lua pattern the appended string values must match; keys = a Lua
	-- pattern a NEW string key must match (nothing else may be added, changed or removed).
	tables = {
		UISpecialFrames = { append = "^Wuber%a*$",
			replace = { "^Wuber%a*$", "^WuberSheet%d+$" },
			reason = "Esc closes our windows: the game's own list of frames Esc closes, the documented way; we only append our own frame names (Window.lua, Bug.lua, Console.lua). Escape closes the top sheet first (#99): while a sheet is open its name takes its own window's slot in place and gives it back when it hides; only our own entry swapped for our own sheet name, in either direction, list length unchanged (a slot we appended earlier in the run may therefore hold the sheet name too)" },
		SlashCmdList = { keys = "^WUBER",
			reason = "the documented way to register a slash command (SLASH_WUBER1 with SlashCmdList.WUBER); only keys named for us (WUBER, WUBERLAB)" },
		StaticPopupDialogs = { keys = "^WUBER",
			reason = "the documented way to define a confirm popup (StaticPopupDialogs.WUBER_*); only keys named for us" },
	},
	-- A game global the addon may replace (assign a new value to), by name.
	globals = {},
	-- A field of a game frame the addon may write, "FrameName.field".
	fields = {},
	-- A game frame our frames may be created under or moved under, by name. UIParent, WorldFrame and Minimap are the game's
	-- anchors for addon frames; a frame of our own (made after the game finished loading) is always fine.
	parents = {
		UIParent = "the game's root for addon frames",
		WorldFrame = "the game's 3D world frame: the other documented root",
		Minimap = "Wuber's minimap button and pulse are children of the minimap, as every minimap button addon does",
				TradeFrame = "not proven: a Wuber frame (the pay pill, UI/Rider/Pay.lua, T.Pill(tf, ...)) is parented under the game's trade window, so it hides with it. To prove it: /console taintLog 1 during a trade and look for blocked actions. Listed so the guard still catches every other case",
		WorldMapFrame = "the map pins: judged by the world-map rules (tests/lib/maptaint.lua, tests/fixtures/map-taint-known.txt), which list every line",
	},
}

-- Wuber Lab (developer only, never ship): the Auto check's extra screens (job 105c). AutoCheck.lua runs them
-- after the photo tour's own screens, with the same looks (cut text, overlaps, scroll bars, tooltips) and a
-- screenshot each. Each stands in for a manual step of the newest STEPS-*.md where it can:
--   covers = { any | folded | unfolded = { <kind> = { "HUNT-72", ... } } }    kind: cut, overlap, under, buttons,
--                                                                              scrollbar, tooltips, offscreen, verify
--   verify(W, view, X) -> "pass" | "look" | "skip", detail      or a list of { name, status, detail, steps }
-- tools/steps2lua.py --auto reads the step ids between the quotes in this file's covers / steps tables, and
-- L.AUTO_COVERS below, to leave those steps out of the tester's list. Keep an id here only while the check really
-- stands in for the whole step line.
--
-- The only clicks (X.press: the button's own insecure OnClick, never a secure button), all local to this
-- window and all put back by the tour's WuberDB snapshot at the end:
--   Settings > This window: Wide pages "Always narrow", "Wide or narrow, per page" Reset, Window position Reset,
--   Replay tips; Settings > Driving: the Share notes switch (off, then on again); the setup's "My friends help" card.
-- Nothing here opens the driver, invites, whispers, advertises, trades, summons or sends a report.

local _, L = ...

local K, P, X = L.PhotoKit, L.PhotoShotKit, L.AutoKit
local str, num = L.str, L.num
local stub, fn = K.stub, K.fn

local SCREENS = L.AUTO_SCREENS
local function screen(s)
	s.auto = true
	SCREENS[#SCREENS + 1] = s
	return s
end

local function settingsOf(W) return type(W.UI) == "table" and type(W.UI.settings) == "table" and W.UI.settings or nil end
local function control(W, key)
	local st = settingsOf(W)
	return st and type(st.controls) == "table" and st.controls[key] or nil
end
local function tourScreen(id)
	for _, s in ipairs(L.PHOTO_SCREENS or {}) do if s.id == id then return s end end
	return nil
end
-- the tour's own set-up of one of its screens
local function runOf(id)
	return function(W, view)
		local s = tourScreen(id)
		if not s then return "the tour has no screen " .. id end
		return s.run(W, view)
	end
end
local function readyOf(id)
	return function(W, view)
		local s = tourScreen(id)
		if s and type(s.ready) == "function" then return s.ready(W, view) end
		return true
	end
end
local function data()
	local t = K.tour()
	if not t then return {} end
	t.autoData = t.autoData or {}
	return t.autoData
end
local function closed(W)
	return P.console(W, { open = false, queue = {}, plan = { color = "off", title = "Closed", sub = "tap Open to take riders" } })
end
local function children(f)
	local out = {}
	if type(f) == "table" and fn(f, "GetChildren") then
		local kids = { pcall(f.GetChildren, f) }
		for i = 2, #kids do out[#out + 1] = kids[i] end
	end
	return out
end
local function textOf(fs)
	if type(fs) ~= "table" or not fn(fs, "GetText") then return nil end
	local ok, t = pcall(fs.GetText, fs)
	return ok and str(t) or nil
end

-- before every screen and at the end (with the tour's own reset): the first-open tips the Replay tips check started
do
	local base = L.PhotoReset
	L.PhotoReset = function(W)
		local t = K.tour()
		if t and t.auto and type(W) == "table" and type(W.UI) == "table" then
			local ui = W.UI.state
			if type(ui) == "table" and ui.coaching and fn(W.UI, "EndCoach") then pcall(W.UI.EndCoach) end
			local d = t.autoData and t.autoData.spent
			if d then -- (the Spent chip check's demo ride as it was)
				d.ride.price = d.price
				t.autoData.spent = nil
				if fn(W, "RebuildTotals") then pcall(W.RebuildTotals) end
			end
			local st = W.UI.settings
			if type(st) == "table" and st.capturing and type(st.cancelCapture) == "function" then pcall(st.cancelCapture) end
		end
		if base then return base(W) end
	end
end

-- Meant to be so (not findings)
local ALLOW = L.AUTO_ALLOW
ALLOW[#ALLOW + 1] = { kind = "under", text = 'half under .-"TIP %d+ OF %d+', reason = "the login tip card is a card over the page on purpose" }

-- The tour's own screens that stand in for a step (the generic looks on them)
local C = L.AUTO_COVERS
C["home+unfolded"] = { scrollbar = { "REV-r25-1" } }
C["worldmap+unfolded"] = { scrollbar = { "REV-r25-1" } }
C["settings+unfolded"] = { scrollbar = { "REV-r25-1" } }
C["help+unfolded"] = { scrollbar = { "REV-r26-1" } }
C["wuber_test"] = { cut = { "REV-r27-1" } }

---------------------------------------------------------------------------
-- Settings: every section, every row (the check scrolls each from top to bottom)
---------------------------------------------------------------------------

for _, sec in ipairs({ { "riding", "Riding" }, { "driving", "Driving" }, { "map", "Map" }, { "sound", "Sound and effects" }, { "window", "This window" } }) do
	screen({ id = "a_set_" .. sec[1], side = "settings", unfold = true,
		title = "Settings: " .. sec[2] .. ", every row (looked at from top to bottom)",
		run = function(W)
			return P.settings(W, function(UI)
				if not UI.OpenSettings(sec[1]) then return sec[2] .. " didn't open" end
				local st = settingsOf(W)
				if st and st.sec ~= sec[1] then return "this character's Settings shows no " .. sec[2] .. " section" end
				return true
			end)
		end })
end

-- (REV-r26-1) Help over a long Settings section: no Settings scroll bar through Help's cards; it is back after Help
screen({ id = "a_help_driving", side = "settings", only = "unfolded",
	title = "Help opened over Settings > Driving: Settings' scroll bar stays out of Help, and comes back after",
	covers = { unfolded = { scrollbar = { "REV-r26-1" }, verify = { "REV-r26-1" } } },
	run = function(W)
		return P.settings(W, function(UI)
			if not UI.OpenSettings("driving") then return "Driving didn't open" end
			if not (fn(UI, "OpenHelp") and UI.OpenHelp("settings")) then return "the help page didn't open" end
			return true
		end)
	end,
	verify = function(W)
		local UI, st = W.UI, settingsOf(W)
		local fd = st and type(st.clip) == "table" and st.clip.edgeFade
		if type(fd) ~= "table" or type(fd.holder) ~= "table" then return "skip", "Settings' list has no scroll bar of this kind" end
		local during = fd.holder:IsShown() and true or false
		UI.CloseHelp(true)
		local back = fd.holder:IsShown() and true or false
		UI.OpenHelp("settings") -- (the shot shows Help)
		if not back then return "look", "after Help closed, Settings' scroll bar stayed hidden" end
		return "pass", "Settings' scroll bar is " .. (during and "kept under Help" or "hidden under Help") .. " and back when Help closes"
	end })

-- (AUD-156) the search results' scroll bar and soft edges under Help, and back when Help closes
screen({ id = "a_search_help", side = "settings", only = "unfolded",
	title = "Help opened from Settings search results: no results scroll bar or soft edge over Help",
	covers = { unfolded = { scrollbar = { "AUD-156" }, verify = { "AUD-156" } } },
	run = function(W)
		return P.settings(W, function(UI, Pn)
			if not (Pn and fn(Pn, "search")) then return "no settings search" end
			Pn.search("e")
			if not (fn(UI, "OpenHelp") and UI.OpenHelp("settings")) then return "the help page didn't open" end
			return true
		end)
	end,
	verify = function(W)
		local UI, st = W.UI, settingsOf(W)
		local rs = st and type(st.find) == "table" and st.find.results
		local fd = type(rs) == "table" and rs.edgeFade
		if type(fd) ~= "table" or type(fd.holder) ~= "table" then return "skip", "the results list has no scroll bar of this kind" end
		UI.CloseHelp(true)
		local back = fd.holder:IsShown() and true or false
		UI.OpenHelp("settings")
		if not back then return "look", "after Help closed, the results' scroll bar and soft edges stayed hidden" end
		return "pass", "the results' scroll bar and soft edges are back when Help closes"
	end })

-- (REV-r27-1) Check my game pressed: the "summons on demand" line under the results is whole; the heading is noted
screen({ id = "a_checkgame", side = "settings", only = "unfolded", ready = readyOf("wuber_test"),
	title = "Check my game pressed (wide): the line under the results is whole",
	covers = { unfolded = { cut = { "REV-r27-1" } } },
	run = runOf("wuber_test"),
	verify = function(W)
		local S = X.scan(W)
		local out = {}
		local line = X.find(S, "summons on demand", true)
		if not line then
			out[#out + 1] = { name = "the line under the results", status = "look", detail = 'no "summons on demand" line on screen', steps = { "REV-r27-1" } }
		else
			local isCut = fn(line.obj, "IsTruncated") and line.obj:IsTruncated() == true
			out[#out + 1] = { name = "the line under the results", status = isCut and "look" or "pass",
				detail = (isCut and "cut: " or "whole: ") .. X.short(line.text, 80), steps = { "REV-r27-1" } }
		end
		local head = X.find(S, "game checks? passed") or X.find(S, "needs? a look")
		if head then
			local r, g, b = 1, 1, 1
			if fn(head.obj, "GetTextColor") then r, g, b = head.obj:GetTextColor() end
			out[#out + 1] = { name = "the heading (HUNT-108: read it here)", status = "info", steps = {},
				detail = ('"%s" in colour %.2f %.2f %.2f'):format(X.short(head.text, 120), num(r) or 0, num(g) or 0, num(b) or 0) }
		end
		return out
	end })

-- (AUD-172) Settings home: the Window card's "Size N%" is the Window size slider's number
screen({ id = "a_size", side = "settings", title = "Settings home: the Window card's size is the slider's",
	covers = { folded = { verify = { "AUD-172" } } },
	run = function(W) return P.settings(W) end,
	verify = function(W)
		local card = X.find(X.scan(W), "Size %d+%%")
		-- the Window card is in the "This window" section, below the fold of the home list: scroll that list (a T.Scroll) down, read it, put it back
		local st = settingsOf(W)
		local home = st and type(st.find) == "table" and st.find.home
		if not card and type(home) == "table" and fn(home, "ScrollTo") then
			local max, at = num(home.max) or 0, num(home.offset) or 0
			local page = math.max(40, num(fn(home, "GetHeight") and home:GetHeight()) or 0)
			local y = 0
			while not card and y < max do
				y = math.min(max, y + page * 0.8)
				pcall(home.ScrollTo, home, y, true)
				card = X.find(X.scan(W), "Size %d+%%")
			end
			pcall(home.ScrollTo, home, at, true)
		end
		if not card then return "look", 'no "Size N%" card on Settings home (looked from the top to the bottom of the list)' end
		local sl = control(W, "scale")
		local v = type(sl) == "table" and num(sl.value)
		if not v then return "skip", "the Window size slider has no value to read" end
		local want = math.floor(v * 100 + 0.5)
		local got = tonumber(card.text:match("Size (%d+)%%"))
		if got ~= want then return "look", ('the card says "Size %s%%", the slider is at %d%%'):format(tostring(got), want) end
		return "pass", ("both say %d%%"):format(want)
	end })

-- (HUNT-72) Wide pages: Always narrow, then Reset: the toast, the pill back on Auto, the page wide again
screen({ id = "a_wide_reset", side = "settings", only = "unfolded", maxWait = 2,
	title = "Settings > This window: Always narrow, then Reset (every page back to Auto)",
	covers = { unfolded = { verify = { "HUNT-72" } } },
	run = function(W)
		return P.settings(W, function(UI)
			if not UI.OpenSettings("window") then return "This window didn't open" end
			return true
		end)
	end,
	post = function(W)
		local seg, reset = control(W, "foldWide"), control(W, "foldReset")
		if type(seg) ~= "table" or type(seg.buttons) ~= "table" or type(reset) ~= "table" then return "no Wide pages controls" end
		local d = data()
		d.wide = { toasts = #X.toasts() }
		for _, b in ipairs(seg.buttons) do
			if b.value == "narrow" then d.wide.narrowOk, d.wide.narrowWhy = X.press(b) end
		end
		d.wide.wasNarrow = type(W.db.fold) == "table" and W.db.fold.narrow == true
		d.wide.resetOk, d.wide.resetWhy = X.press(reset)
		return true
	end,
	verify = function(W)
		local d = data().wide
		if not d then return "skip", "the buttons were not pressed" end
		if not d.narrowOk then return "look", "Always narrow: " .. tostring(d.narrowWhy or "no such choice") end
		if not d.resetOk then return "look", "Reset: " .. tostring(d.resetWhy) end
		local bad = {}
		if not d.wasNarrow then bad[#bad + 1] = "Always narrow did not save" end
		if not X.toasted({ "Every page is back to Auto", "setting reset.", "settings reset." }, d.toasts) then bad[#bad + 1] = 'no toast "Every page is back to Auto" or "N settings reset."' end
		local seg = control(W, "foldWide")
		if seg.value ~= "auto" then bad[#bad + 1] = "the pill shows " .. tostring(seg.value) .. ", not Auto" end
		if type(W.db.fold) == "table" and W.db.fold.narrow then bad[#bad + 1] = "the saved choice is still Always narrow" end
		local F = W.UI.Fold
		if fn(F, "Fits") and F.Fits() and fn(F, "IsUnfolded") and not F.IsUnfolded() then bad[#bad + 1] = "the page did not open wide again" end
		if #bad > 0 then return "look", table.concat(bad, "; ") end
		return "pass", "toast, pill on Auto, page wide again"
	end })

-- (HUNT-42) Replay tips on a wide screen: the first-open tips show on one narrow pane
screen({ id = "a_replay_tips", side = "settings", only = "unfolded", maxWait = 1.5,
	title = "Settings > This window: Replay tips (the tips show on the narrow window)",
	covers = { unfolded = { verify = { "HUNT-42" } } },
	run = function(W)
		P.homeBase(W, P.demoDrivers())
		return P.settings(W, function(UI)
			if not UI.OpenSettings("window") then return "This window didn't open" end
			return true
		end)
	end,
	post = function(W)
		local b = control(W, "coach")
		if type(b) ~= "table" then return "no Replay tips button" end
		local d = data()
		d.coachOk, d.coachWhy = X.press(b)
		return true
	end,
	verify = function(W)
		local d = data()
		if not d.coachOk then return "look", "Replay tips: " .. tostring(d.coachWhy) end
		local ui, F = W.UI.state, W.UI.Fold
		if not (type(ui) == "table" and ui.coaching) then return "look", "the first-open tips did not start" end
		if fn(F, "IsUnfolded") and F.IsUnfolded() then return "look", "the tips show on the wide (two pane) window" end
		return "pass", "the tips started, on the narrow window"
	end })

-- (AUD-148) Driving > Who summons: Change stays raised after the mouse goes over and off
screen({ id = "a_raised", side = "settings", ready = readyOf("settings_summoner"),
	title = "Settings > Driving > Who summons: the Change button stays raised",
	covers = { folded = { verify = { "AUD-148" } } },
	run = function(W)
		return P.settings(W, function(UI, Pn) return L.PhotoOpenSetting(UI, Pn, "Who summons") end)
	end,
	verify = function(W)
		local st = settingsOf(W)
		local pick
		for _, c in ipairs(children(st and st.casterRow)) do
			if type(c) == "table" and type(c.fill) == "table" and textOf(c.label) == "Change" then pick = c end
		end
		if not pick then return "skip", "no Change button on the Who summons row" end
		local before = pick.fill.colour
		X.hover(pick)
		if pick.fill.colour ~= "raised" then return "look", ("after the mouse left it is %s, not raised (it was %s)"):format(tostring(pick.fill.colour), tostring(before)) end
		if before ~= "raised" then return "look", "it was " .. tostring(before) .. " before the mouse went over, not raised" end
		return "pass", "raised before and after"
	end })

-- (step 14: HUNT-19, HUNT-29, HUNT-41, HUNT-43) four tooltips: their words, nothing cut
local TIP_WORDS = {
	{ key = "fx", words = "Only the minimap button still pulses", step = "HUNT-19", name = "Effects" },
	{ key = "drive.shareNotes", words = "Off: they stay on this account.", step = "HUNT-29", name = "Share notes with my own accounts" },
	{ key = "drive.adEvery", words = "The Advertise button turns violet and rings", step = "HUNT-41", name = "Advert reminder" },
	{ key = "advertOnline", words = "posts one advert line in public chat", step = "HUNT-43", name = "Post an advert when I go online" },
}
screen({ id = "a_tip_words", side = "settings", title = "Settings: four tooltips read (Effects, Share notes, Advert reminder, Post an advert)",
	run = function(W)
		return P.settings(W, function(UI)
			UI.OpenSettings("driving")
			return true
		end)
	end,
	steps = { "HUNT-19", "HUNT-29", "HUNT-41", "HUNT-43" },
	verify = function(W)
		local out = {}
		for _, w in ipairs(TIP_WORDS) do
			local c = control(W, w.key)
			local r = { name = w.name .. "'s tooltip", steps = { w.step } }
			if type(c) ~= "table" then
				r.status, r.detail = "skip", "this character's Settings has no such row"
			else
				local seen, found, bad = {}, false, nil
				local list = { c, c.row or false, fn(c, "GetParent") and c:GetParent() or false, type(c.holder) == "table" and fn(c.holder, "GetParent") and c.holder:GetParent() or false }
				for _, f in ipairs(list) do
					if type(f) == "table" and not found then
						local text, problems = X.tip(f)
						if text then
							seen[#seen + 1] = X.short(text, 60)
							if text:find(w.words, 1, true) then found, bad = true, problems end
						end
					end
				end
				if not found then
					r.status, r.detail = "look", ('no tooltip with "%s" (seen: %s)'):format(w.words, #seen > 0 and table.concat(seen, " | ") or "none")
				elseif bad and #bad > 0 then
					r.status, r.detail = "look", table.concat(bad, "; ")
				else
					r.status, r.detail = "pass", 'says "' .. w.words .. '", nothing cut'
				end
			end
			out[#out + 1] = r
		end
		return out
	end })

-- (HUNT-66) Share notes off: the Crew card no longer offers "my account"; on again: it is back
screen({ id = "a_share_notes", side = "driver", title = "Share notes switched off and on: Crew's \"my account\" goes and comes back",
	covers = { folded = { verify = { "HUNT-66" } } },
	run = function(W)
		local r = P.settings(W) -- (Settings built: its switch is the one pressed)
		if r ~= true then return r end
		W.UI.CloseSettings(true)
		return runOf("crew")(W)
	end,
	verify = function(W)
		local t = control(W, "drive.shareNotes")
		if type(t) ~= "table" or type(t.SetOn) ~= "function" then return "skip", "this character's Settings has no Share notes switch" end
		local was = t.on
		local function offered()
			P.driveRefresh(W)
			return X.find(X.scan(W), "my account", true) ~= nil
		end
		if not t.on then X.press(t) end
		local on1 = offered()
		X.press(t)
		local off = offered()
		X.press(t)
		local on2 = offered()
		if t.on ~= was then X.press(t) end
		P.driveRefresh(W)
		if not on1 then return "skip", 'with the switch on, the demo crew shows no "my account" here' end
		if off then return "look", 'with the switch off, Crew still offers "my account"' end
		if not on2 then return "look", 'switched on again, "my account" did not come back' end
		return "pass", "gone when off, back when on"
	end })

-- (HUNT-76) Blocked, nobody blocked, the self-block switch off: the note is whole
screen({ id = "a_blocked_empty", side = "driver", title = "Drive > Blocked, empty, with \"Block riders who leave without paying\" off",
	covers = { folded = { verify = { "HUNT-76" }, cut = { "HUNT-76" } } },
	run = function(W)
		local r = closed(W)
		if r ~= true then return r end
		local DR = W.Drive
		local opt = DR.Opt
		P.shotStub(DR, "BlockedList", function() return {} end)
		P.shotStub(DR, "Opt", function(k, ...)
			if k == "autoBlock" then return false end
			if type(opt) == "function" then return opt(k, ...) end
		end)
		return P.driveScreen(W, "blocked")
	end,
	verify = function(W)
		local note = X.find(X.scan(W), "that switch is off in Settings", true)
		if not note then return "look", 'the note "...that switch is off in Settings." is not on screen' end
		if fn(note.obj, "IsTruncated") and note.obj:IsTruncated() == true then return "look", "the note is cut" end
		if not note.text:find("Shift%-right%-click a rider to block them") then return "look", "the note reads: " .. X.short(note.text, 120) end
		return "pass", "the whole note shows"
	end })

-- (HUNT-49) the minimap button's tooltip while not open to drive: no "Shift-right-click pause" line
screen({ id = "a_minimap_tip", side = "rider", title = "The minimap button's tooltip while closed (no pause line)",
	covers = { folded = { verify = { "HUNT-49" } } },
	run = function(W)
		P.homeBase(W, P.demoDrivers())
		if type(W.Drive) == "table" then stub(W.Drive, "IsOpen", function() return false end) end
		return P.rider(W, "home")
	end,
	verify = function()
		local b = rawget(_G, "WuberMinimapButton")
		if type(b) ~= "table" or not (fn(b, "IsVisible") and b:IsVisible()) then return "skip", "the minimap button is switched off" end
		local text, bad, why = X.tip(b)
		if not text then return "look", "no tooltip: " .. tostring(why) end
		if text:find("Shift-right-click", 1, true) then return "look", "it says: " .. X.short(text, 160) end
		if bad and #bad > 0 then return "look", table.concat(bad, "; ") end
		return "pass", "no pause line: " .. X.short(text, 90)
	end })

-- (HUNT-09, HUNT-10) with OpenMap switched off, the map row's words
screen({ id = "a_openmap_words", side = "settings", title = "Settings > Map: the \"Drivers on the world map\" row's words without OpenMap",
	covers = { folded = { verify = { "HUNT-09", "HUNT-10" } } },
	run = function(W)
		return P.settings(W, function(UI)
			if not UI.OpenSettings("map") then return "Map didn't open" end
			return true
		end)
	end,
	verify = function(W)
		local UI, st = W.UI, settingsOf(W)
		if fn(UI, "HasOpenMap") and UI.HasOpenMap() then return "skip", "OpenMap is switched on for this character: the step is for OpenMap off" end
		local row = st and st.mapRow
		local text = type(row) == "table" and textOf(row.desc)
		if not text then return "look", "no Drivers on the world map row" end
		if text ~= "Pins with prices. Best with the OpenMap addon." then return "look", 'it reads "' .. text .. '"' end
		return "pass", text
	end })

-- (AUD-228) Key for the big button: Set reads "Press...", Clear puts "Set" back, and so does closing Settings.
-- (the key itself is never changed: Wuber's DR.SetKey is stubbed for this screen)
screen({ id = "a_key_capture", side = "settings", ready = readyOf("settings_summoner"),
	title = "Settings > Driving > Key for the big button: Set, Clear, Set, close",
	covers = { folded = { verify = { "AUD-228" } } },
	run = function(W)
		if type(W.Drive) == "table" then P.shotStub(W.Drive, "SetKey", function() end) end
		return P.settings(W, function(UI, Pn) return L.PhotoOpenSetting(UI, Pn, "Key for the big button") end)
	end,
	post = function(W)
		local st = settingsOf(W)
		local set, clear = control(W, "drive.key"), nil
		for _, c in ipairs(children(st and st.keyRow)) do
			if type(c) == "table" and textOf(c.label) == "Clear" then clear = c end
		end
		local d = data()
		d.key = nil
		if type(set) ~= "table" or not clear then return true end
		local k = { seen = {} }
		local function note() k.seen[#k.seen + 1] = textOf(set.label) or "?" end
		k.ok, k.why = X.press(set)
		note()
		X.press(clear)
		note()
		X.press(set)
		note()
		W.UI.CloseSettings(true)
		note()
		if st.cancelCapture then pcall(st.cancelCapture) end -- (whatever happened, the keyboard is never left captured)
		d.key = k
		return P.settings(W, function(UI, Pn) return L.PhotoOpenSetting(UI, Pn, "Key for the big button") end)
	end,
	verify = function()
		local k = data().key
		if not k then return "skip", "this character's Settings has no Key for the big button row" end
		if not k.ok then return "look", "Set: " .. tostring(k.why) end
		local want = { "Press...", "Set", "Press...", "Set" }
		local what = { "after Set", "after Clear", "after Set again", "after closing Settings" }
		for i = 1, 4 do
			if k.seen[i] ~= want[i] then return "look", ('%s the button reads "%s", not "%s"'):format(what[i], tostring(k.seen[i]), want[i]) end
		end
		return "pass", 'Set reads "Press...", then "Set" again after Clear and after closing Settings'
	end })

-- (HUNT-108) Check my game with one crossed driver line: the amber heading names it
local DEMO_LINE = "Crew: nobody added yet"
screen({ id = "a_checkgame_driver", side = "settings", ready = readyOf("wuber_test"),
	title = "Check my game with one driver line that needs a look: the amber heading",
	covers = { folded = { verify = { "HUNT-108" } } },
	run = function(W)
		local DR = W.Drive
		if type(DR) ~= "table" then return "no W.Drive" end
		P.shotStub(W, "IsWarlock", function() return true end)
		P.shotStub(DR, "Role", function() return "driver" end)
		P.shotStub(DR, "Readiness", function() return { { text = DEMO_LINE, ok = false } } end)
		return runOf("wuber_test")(W)
	end,
	verify = function(W)
		local S = X.scan(W)
		local head = X.find(S, "^All %d+ ")
		if not head then
			local other = X.find(S, "checks? ")
			return "skip", "a game check did not pass here, so the heading is about that" .. (other and (': "' .. X.short(other.text, 80) .. '"') or "")
		end
		local line = X.find(S, DEMO_LINE, true)
		if not line then return "skip", "the driver line did not show (this character's Check my game lists no driver lines)" end
		if not head.text:find("^All %d+ game checks passed%. 1 driver line needs a look: see your Drive tab%.$") then
			return "look", 'the heading reads "' .. X.short(head.text, 120) .. '"'
		end
		local function colour(fs)
			if not fn(fs, "GetTextColor") then return "?" end
			local r, g, b = fs:GetTextColor()
			return ("%.2f %.2f %.2f"):format(num(r) or 0, num(g) or 0, num(b) or 0)
		end
		if colour(head.obj) ~= colour(line.obj) then return "look", "the heading's colour (" .. colour(head.obj) .. ") is not the crossed line's amber (" .. colour(line.obj) .. ")" end
		if head.vis.b < line.vis.t - 1 then return "look", "the heading is not above the line" end
		return "pass", '"' .. head.text .. '" in the line\'s amber, above it'
	end })

---------------------------------------------------------------------------
-- Rider
---------------------------------------------------------------------------

-- (AUD-153) Trips: a long Spent amount is whole, in the chips' own letter size
screen({ id = "a_trips_spent", side = "rider", title = "Trips: the Spent chip with a long amount (12g 34s 50c)",
	covers = { folded = { verify = { "AUD-153" } } },
	run = function(W)
		local r = L.PhotoTrips(W)
		if r ~= true then return r end
		local rides = type(W.db) == "table" and W.db.rides
		if type(rides) ~= "table" or type(rides[1]) ~= "table" then return "no demo rides" end
		local total = 0
		for _, x in ipairs(rides) do total = total + (num(x.price) or 0) end
		local d = data()
		d.spent = { ride = rides[1], price = rides[1].price }
		rides[1].price = (num(rides[1].price) or 0) + (123450 - total)
		if fn(W, "RebuildTotals") then pcall(W.RebuildTotals) end
		P.refresh(W)
		return true
	end,
	verify = function(W)
		local d = data().spent
		local S = X.scan(W)
		local chip = X.find(S, "Spent %d+g %d+s %d+c")
		local other = X.find(S, "^Go%-to") or X.find(S, "streak")
		local size, size2
		if chip and fn(chip.obj, "GetFont") then size = num(select(2, chip.obj:GetFont())) end
		if other and fn(other.obj, "GetFont") then size2 = num(select(2, other.obj:GetFont())) end
		local isCut = chip and fn(chip.obj, "IsTruncated") and chip.obj:IsTruncated() == true
		-- the demo rides as they were
		if d then
			d.ride.price = d.price
			if fn(W, "RebuildTotals") then pcall(W.RebuildTotals) end
			data().spent = nil
		end
		if not chip then return "look", 'no "Spent 12g 34s 50c" chip on Trips' end
		if isCut then return "look", 'the chip is cut: "' .. chip.text .. '"' end
		if size and size2 and size < size2 - 0.01 then return "look", ("the chip's letters are smaller (%.1f) than the other chips' (%.1f)"):format(size, size2) end
		return "pass", '"' .. chip.text .. '" whole' .. ((size and size2) and ", the same letter size as the other chips" or "")
	end })


-- (REV-r47-1) a long place in the search: the heading keeps left of the count and the bell
screen({ id = "a_home_long", side = "rider", unfold = true, title = "Home, searching \"Feathermoon Stronghold\": the heading clear of the count and bell",
	covers = { any = { overlap = { "REV-r47-1" } } },
	run = function(W)
		P.homeBase(W, P.demoDrivers())
		if not fn(W.UI, "SetSearch") then return "W.UI.SetSearch is missing" end
		W.UI.SetSearch("Feathermoon Stronghold")
		return P.rider(W, "home")
	end })

-- (AUD-159) more drivers than fit: one thin scroll bar, not two
local MANY = { "Cara Dune", "Dex Holt", "Elle Marsh", "Finn Ashby", "Gwen Thorn", "Hal Brook", "Isla Reed", "Jon Pike", "Kit Vale", "Lena Frost", "Milo Crane", "Nell Hart" }
screen({ id = "a_home_many", side = "rider", unfold = true, title = "Home with more drivers than fit: one scroll bar",
	covers = { any = { scrollbar = { "AUD-159" } } },
	run = function(W)
		local ds = P.demoDrivers()
		local t0 = K.now()
		for i, n in ipairs(MANY) do
			local key = n:lower()
			ds[key] = { name = n, key = key, dest = (i % 2 == 0) and "Ratchet" or "Undercity", price = 5000 + i * 100, state = "open", team = 1 + i % 3,
				service = n:match("^(%S+)") .. "'s Rides", heard = t0, badge = "star" }
		end
		P.homeBase(W, ds)
		return P.rider(W, "home")
	end })

-- (HUNT-109, HUNT-114) a "Scroll for ..." cue is not drawn over Settings, and is back after Settings
local function cueScreens(id, title, step, base)
	screen({ id = id .. "_set", side = "settings", title = title .. ": the Scroll cue is not drawn over Settings",
		covers = { folded = { verify = { step } } },
		run = base,
		post = function(W)
			data().cue = X.find(X.scan(W), "^Scroll for") ~= nil
			if not W.UI.OpenSettings() then return "settings didn't open" end
			return true
		end,
		verify = function(W)
			if not data().cue then return "skip", 'no "Scroll for ..." cue on this page with the demo data at this window size' end
			local cue = X.find(X.scan(W), "^Scroll for")
			if cue then return "look", 'the cue "' .. cue.text .. '" shows over Settings' end
			return "pass", "no cue over Settings"
		end })
	screen({ id = id .. "_back", side = "settings", title = title .. ": the Scroll cue is back after Settings closes",
		covers = { folded = { verify = { step } } },
		run = base,
		post = function(W)
			data().cue = X.find(X.scan(W), "^Scroll for") ~= nil
			if not W.UI.OpenSettings() then return "settings didn't open" end
			W.UI.CloseSettings(true)
			return true
		end,
		verify = function(W)
			if not data().cue then return "skip", 'no "Scroll for ..." cue on this page with the demo data at this window size' end
			if not X.find(X.scan(W), "^Scroll for") then return "look", "the cue did not come back after Settings closed" end
			return "pass", "the cue is back"
		end })
end
cueScreens("a_trips_cue", "Trips", "HUNT-109", function(W) return L.PhotoTrips(W) end)
cueScreens("a_earn_cue", "Earnings (narrow)", "HUNT-114", function(W)
	local r, e = P.earningsBase(W, false)
	if r ~= true then return r end
	P.scrollTo(e, false)
	return true
end)

---------------------------------------------------------------------------
-- Driver
---------------------------------------------------------------------------

-- (HUNT-113) Messages > My advert line: the grey line whole, the box and chips below it, nothing overlaps
screen({ id = "a_msg_advert", side = "driver", unfold = true, title = "Messages: My advert line in the editor",
	covers = { any = { cut = { "HUNT-113" }, overlap = { "HUNT-113" }, under = { "HUNT-113" } } },
	run = function(W)
		local r = runOf("messages")(W)
		if r ~= true then return r end
		local ms = type(W.UI.drive) == "table" and type(W.UI.drive.screens) == "table" and W.UI.drive.screens.messages
		if not (type(ms) == "table" and type(ms.edit) == "function") then return "no message editor" end
		ms.edit("advert")
		return true
	end,
	post = function(W)
		local ms = W.UI.drive.screens.messages
		if type(ms.edit) == "function" then ms.edit("advert") end
		return true
	end })

-- (AUD-201) the "Ask a summoner" message's preview: "<name>: please summon Dan", no leading colon.
-- The list rows no longer show a preview: the editor does, so the check opens the editor.
screen({ id = "a_msg_callsum", side = "driver", unfold = true, title = "Messages: the Ask a summoner editor's preview",
	covers = { folded = { verify = { "AUD-201" } } },
	run = function(W)
		local r = runOf("messages")(W)
		if r ~= true then return r end
		local ms = type(W.UI.drive) == "table" and type(W.UI.drive.screens) == "table" and W.UI.drive.screens.messages
		if not (type(ms) == "table" and type(ms.edit) == "function") then return "no message editor" end
		ms.edit("callsum")
		return true
	end,
	post = function(W)
		local ms = W.UI.drive.screens.messages
		if type(ms.edit) == "function" then ms.edit("callsum") end
		return true
	end,
	verify = function(W)
		local ms = type(W.UI.drive) == "table" and type(W.UI.drive.screens) == "table" and W.UI.drive.screens.messages
		local row = X.find(X.scan(W), "please summon", true)
		local text = row and row.text
		if not text and type(ms) == "table" and type(ms.editor) == "table" and type(ms.editor.prev) == "table" and fn(ms.editor.prev, "GetText") then
			text = str(ms.editor.prev:GetText())
		end
		if not text or not text:find("please summon", 1, true) then return "look", 'no "please summon" preview in the editor' end
		if text:find("^%s*:") then return "look", 'it reads "' .. X.short(text, 80) .. '" (a leading colon)' end
		if not text:find("^[^:]+: please summon") then return "look", 'it reads "' .. X.short(text, 80) .. '"' end
		return "pass", '"' .. X.short(text, 80) .. '"'
	end })

-- (AUD-200) the setup's first step: "My friends help" clicked keeps its lighter look after the mouse leaves
screen({ id = "a_wizard_friends", side = "driver", title = "Drive setup, step 1: My friends help stays picked after the mouse leaves",
	covers = { folded = { verify = { "AUD-200" } } },
	run = function(W) return closed(W) end,
	post = function(W)
		local r = P.wizardAt(W, 1)
		if r ~= true then return r end
		local w = P.wizardScreen(W)
		local d = data()
		d.card = nil
		for _, b in ipairs(type(w.choices) == "table" and w.choices or {}) do
			if b.id == "friends" then d.card = b end
		end
		if d.card then
			d.cardOk, d.cardWhy = X.press(d.card)
			X.hover(d.card)
		end
		return true
	end,
	verify = function(W)
		local d = data()
		local b, w = d.card, P.wizardScreen(W)
		if not b then return "skip", "no My friends help card on this character's setup" end
		if not d.cardOk then return "look", "the card: " .. tostring(d.cardWhy) end
		local bad = {}
		if w and w.choice ~= "friends" then bad[#bad + 1] = "it is not the picked card" end
		-- the picked card uses the "glow" look (a violet fill and a tick; the edge draws nothing): read the colour, never the edge's methods
		if type(b.bg) == "table" and type(b.bg.colour) ~= "function" and b.bg.colour ~= "glow" then bad[#bad + 1] = "its background is " .. tostring(b.bg.colour) .. ", not the glow look" end
		if type(b.tick) == "table" and fn(b.tick, "IsShown") and not b.tick:IsShown() then bad[#bad + 1] = "its tick is not shown" end
		if #bad > 0 then return "look", table.concat(bad, "; ") end
		return "pass", "picked, glow fill and tick after the mouse left"
	end })

-- (HUNT-23, AUD-149) a character not set up as a driver: Drive's first screen, the grey "Just open the console",
-- and the gear opens Settings with the Driving section
screen({ id = "a_welcome", side = "driver", title = "Drive's first screen for a character not set up: the grey skip button, and the gear shows Driving",
	covers = { folded = { verify = { "HUNT-23", "AUD-149" } } },
	steps = { "HUNT-23", "AUD-149" },
	run = function(W)
		local r = closed(W)
		if r ~= true then return r end
		local DR, D = W.Drive, W.Driver
		local c = fn(W, "Char") and W.Char()
		if type(c) ~= "table" then return "no character settings" end
		c.wizard, c.welcomed = false, false -- (WuberDB is put back at the end)
		P.shotStub(DR, "Crew", function() return {} end)
		if fn(D, "CrewCount") then P.shotStub(D, "CrewCount", function() return 0 end) end
		P.driveRefresh(W)
		return true
	end,
	post = function(W)
		local D = W.Driver
		local v = type(D.ui) == "table" and D.ui.welcome
		local d = data()
		d.welcome = nil
		if type(v) ~= "table" or type(v.skip) ~= "table" or not (fn(v, "IsVisible") and v:IsVisible()) then return true end
		local function colour()
			local r, g, b = v.skip.label:GetTextColor()
			return ("%.2f %.2f %.2f"):format(num(r) or 0, num(g) or 0, num(b) or 0)
		end
		local k = { before = colour() }
		X.hover(v.skip)
		k.after = colour()
		k.words = textOf(v.skip.label)
		-- the gear, on the Drive tab
		local ui = W.UI.state
		k.gearOk, k.gearWhy = X.press(type(ui) == "table" and ui.gear or nil)
		d.welcome = k
		return true
	end,
	verify = function(W)
		local k = data().welcome
		local c = fn(W, "Char") and W.Char()
		if type(c) == "table" then c.wizard = true end -- (the next screens are a set-up driver's again)
		if not k then return "skip", "Drive's first screen did not show in this state" end
		local out = {}
		out[#out + 1] = { name = '"' .. tostring(k.words) .. '" stays grey', steps = { "AUD-149" }, status = k.before == k.after and "pass" or "look",
			detail = k.before == k.after and "the same grey before and after the mouse" or ("its colour went from " .. k.before .. " to " .. k.after) }
		local st = settingsOf(W)
		local shown = st and type(st.drive) == "table" and fn(st.drive, "IsShown") and st.drive:IsShown()
		local open = type(W.UI.state) == "table" and W.UI.state.settingsOpen
		local g = { name = "the gear shows the Driving section", steps = { "HUNT-23" } }
		if not k.gearOk then g.status, g.detail = "look", "the gear: " .. tostring(k.gearWhy)
		elseif not open then g.status, g.detail = "look", "Settings did not open"
		elseif not shown then g.status, g.detail = "look", "Settings opened without the Driving section"
		else g.status, g.detail = "pass", "Settings opened with the Driving section" end
		out[#out + 1] = g
		return out
	end })

-- (HUNT-64) not a Warlock, no crew: the Crew page's "Just you" card says "Clicks the portal"
screen({ id = "a_crew_justyou", side = "driver", title = "Crew for a character who isn't a Warlock: Just you, Clicks the portal",
	covers = { folded = { verify = { "HUNT-64" } } },
	run = function(W)
		local r = closed(W)
		if r ~= true then return r end
		local DR = W.Drive
		P.shotStub(W, "IsWarlock", function() return false end)
		P.shotStub(DR, "IsWarlock", function() return false end)
		P.shotStub(DR, "Crew", function() return {} end)
		P.shotStub(DR, "Summoners", function() return {} end)
		P.shotStub(DR, "Shards", function() return 0 end)
		return P.driveScreen(W, "crew")
	end,
	verify = function(W)
		local S = X.scan(W)
		if not X.find(S, "Just you", true) then return "skip", 'no "Just you" card on the Crew page in this state' end
		if not X.find(S, "Clicks the portal", true) then return "look", 'the Just you card does not say "Clicks the portal"' end
		return "pass", "Just you: Clicks the portal"
	end })

---------------------------------------------------------------------------
-- Last: the window's place (its Reset also takes the window size back to the default for a moment)
---------------------------------------------------------------------------

-- (HUNT-59, the out-of-combat half) Window position > Reset: the saved place is forgotten and Wuber says so
screen({ id = "a_pos_reset", side = "settings", title = "Settings > This window: Window position Reset",
	covers = { folded = { verify = { "HUNT-59" } } },
	run = function(W)
		return P.settings(W, function(UI)
			if not UI.OpenSettings("window") then return "This window didn't open" end
			return true
		end)
	end,
	post = function(W)
		local b = control(W, "resetPos")
		if type(b) ~= "table" then return "no Window position Reset button" end
		local d = data()
		local scale = W.db.scale
		d.pos = { toasts = #X.toasts() }
		W.db.pos = { "TOPLEFT", "TOPLEFT", 40, -40 } -- (a saved place to forget; the tour puts the real one back at the end)
		d.pos.ok, d.pos.why = X.press(b)
		d.pos.forgot = W.db.pos == nil
		-- the window's own size again (Reset also forgets the size; WuberDB is put back at the end, the look now)
		if scale ~= nil and W.db.scale ~= scale then
			W.db.scale = scale
			if fn(W.UI, "ApplyScale") then pcall(W.UI.ApplyScale) end
			local sl = control(W, "scale")
			if type(sl) == "table" and type(sl.Set) == "function" then pcall(sl.Set, sl, scale) end
		end
		return true
	end,
	verify = function()
		local d = data().pos
		if not d then return "skip", "Reset was not pressed" end
		if not d.ok then return "look", "Reset: " .. tostring(d.why) end
		if not d.forgot then return "look", "the saved place was not forgotten" end
		if not X.toasted({ "Window back in its usual place", "setting reset.", "settings reset." }, d.toasts) then return "look", 'no toast "Window back in its usual place" or "N settings reset."' end
		return "pass", "the saved place is forgotten and Wuber says the window is back"
	end })

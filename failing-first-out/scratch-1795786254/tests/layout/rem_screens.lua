-- Layout scenes for Simple mode, driver ranks and the merged Settings rows (the remaining-work round). Installed by
-- tests/layout/extra_screens.lua at its end (X.install calls this file's install), so they work alone
-- (--screen simple_) and inside a whole sweep. The tour's windows start in Advanced; the simple_ scenes are the lab's own
-- shots (their run, post and afterShot) with Simple mode switched on BEFORE they run, as a real player's game starts.
--   simple_home, simple_home_empty, simple_confirm, simple_ride, simple_pay, simple_done, simple_trips      the rider
--   simple_settings, simple_settings_driving                                                                  Settings
--   simple_console_open, simple_console_closed, simple_menu, simple_sheet, simple_earnings, simple_shift       the driver
--   rank_row   the rider's list: a driver at 73 verified summons (chip "Black Cab · 73"), and the Founder with a very
--              long name at 1,000 (Simple)
--   rank_card  the New title card with its "Tell the guild" pill, a driver in a guild (Simple)
--   rank_own   the wide Drive page with the driver's own title line and bar (Advanced, unfolded only)
--   settings_merged, settings_merged_big   Advanced, Settings > Driving scrolled to the merged rows (Group size and Chat
--              channels; then Big button on screen and Alert character)
-- Every change a scene makes (the mode, the saved rank, the guild answer, the New title card) is put back by a wrapper of
-- L.PhotoReset, which the tour calls before every screen and at its end (it never calls a scene's hide).
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

local state = {}

local function mod(w, name)
	local ok, m = pcall(w.Mod, name)
	if ok and type(m) == "table" then return m end
end

local function upvalue(f, name)
	if type(f) ~= "function" or not (debug and debug.getupvalue) then return nil end
	for i = 1, 60 do
		local n, v = debug.getupvalue(f, i)
		if not n then return nil end
		if n == name then return v end
	end
end

local function rankCardFrame(w)
	local f = w.UI and upvalue(w.UI.RankCard, "rankCard")
	if type(f) == "table" then return f end
end

-- everything the scenes changed, back as it was (the tour calls this before every screen and at its end)
local function putBack(w)
	if type(w) ~= "table" then return end
	if state.rank then
		local ch = type(w.Char) == "function" and w.Char()
		if type(ch) == "table" then ch.rank = state.rank.old end
		state.rank = nil
	end
	local f = rankCardFrame(w)
	if f and f.IsShown and f:IsShown() and f.Close then pcall(f.Close, f, true) end
	if state.guild then
		rawset(state.guild.env, "IsInGuild", state.guild.was)
		state.guild = nil
	end
	if state.button then
		local s = state.button
		if s.was == "nil" then s.db.shown = nil else s.db.shown = s.was end
		state.button = nil
	end
	if state.simple then
		state.simple = nil
		if type(w.SetAdvanced) == "function" then pcall(w.SetAdvanced, true) end
	end
end

local function refresh(w)
	if type(w.UI) == "table" and type(w.UI.RefreshNow) == "function" then pcall(w.UI.RefreshNow) end
	if type(w.Driver) == "table" and type(w.Driver.RefreshNow) == "function" then pcall(w.Driver.RefreshNow) end
end

-- earlier scenes leave their cards up (the What's new card is never hidden by the tour) and the driver shots before them
-- leave the big button and its mini list on the screen: the stage is cleared first. A rider scene is judged against the
-- phone alone: the big button is held away (its saved "shown" choice, put back by putBack) while the shot is up.
local function clearStage(w, rider)
	local WN = mod(w, "UI.WhatsNew")
	if WN and type(WN.Hide) == "function" then pcall(WN.Hide) end
	if not rider then return end
	local okc, Cast = pcall(w.Mod, "Drive.Cast")
	local b = okc and type(Cast) == "table" and type(Cast.btnDB) == "function" and Cast.btnDB() or nil
	if type(b) == "table" then
		if not state.button then state.button = { db = b, was = (b.shown == nil) and "nil" or b.shown } end
		b.shown = false
	end
	local DR, D = w.Drive, w.Driver
	if type(DR) == "table" and type(DR.Button) == "table" and type(DR.Button.Refresh) == "function" then pcall(DR.Button.Refresh) end
	if type(D) == "table" then
		if type(D.SyncMini) == "function" then pcall(D.SyncMini) end
		if type(D.UpdateMini) == "function" then pcall(D.UpdateMini) end
	end
	local btn = type(DR) == "table" and DR.button
	if type(btn) == "table" and type(btn.Hide) == "function" then pcall(btn.Hide, btn) end
end

local function setSaved(w, rank)
	local ch = type(w.Char) == "function" and w.Char()
	if type(ch) ~= "table" then return false end
	if not state.rank then state.rank = { old = ch.rank } end
	ch.rank = rank
	return true
end

function X.install(L, W)
	local added = {}
	if not (type(W) == "table" and type(W.SetAdvanced) == "function" and type(W.Advanced) == "function") then return added end
	local K = L.PhotoKit
	local function base(id)
		for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == id then return s end end
	end
	-- the wrapper of the tour's reset (installed once per client: the lab and its tables are new for each run)
	local reset = L.PhotoReset
	L.PhotoReset = function(w, ...)
		if type(reset) == "function" then reset(w, ...) end
		putBack(w)
	end
	-- a stub for this shot only, as the tour's own shotStub: L.PhotoReset puts it back before the next screen
	local function shotStub(tbl, key, value)
		local t = K and type(K.tour) == "function" and K.tour()
		if not (t and type(K.stub) == "function") then return false end
		t.shotStubs = t.shotStubs or {}
		t.shotStubs[#t.shotStubs + 1] = { tbl, key, tbl[key] }
		return K.stub(tbl, key, value)
	end

	-- o: base (a lab shot id), simple (true: Simple mode before it runs), side, unfold, only, title,
	--    before(w) after(w, view) -> true or why
	local function scene(id, o)
		local b = base(o.base)
		if not (b and type(b.run) == "function") then return end
		local e = { id = id, side = o.side or b.side, title = o.title, unfold = o.unfold, only = o.only,
			wait = b.wait, maxWait = b.maxWait, ready = b.ready, noChat = b.noChat, check = b.check, afterShot = b.afterShot }
		e.run = function(w, view)
			putBack(w)
			clearStage(w, (e.side or "") ~= "driver")
			if o.simple then
				state.simple = true
				w.SetAdvanced(false)
			end
			if o.before then
				local r0 = o.before(w, view)
				if r0 ~= true then return r0 end
			end
			local r = b.run(w, view)
			if r ~= true then return r end
			if o.after then
				local r2 = o.after(w, view)
				if r2 ~= true then return r2 end
			end
			refresh(w)
			-- the console's list starts at its top whatever an earlier shot scrolled it to (a whole sweep leaves it where it was)
			local v = type(w.Driver) == "table" and type(w.Driver.ui) == "table" and w.Driver.ui.console
			if o.top ~= false and type(v) == "table" and type(v.scroll) == "table" and type(v.scroll.ScrollTo) == "function" and (e.side or "") == "driver" then
				pcall(v.scroll.ScrollTo, v.scroll, 0, true)
			end
			return true
		end
		if type(b.post) == "function" or o.post then
			e.post = function(w, view)
				if type(b.post) == "function" and not o.post then
					local r = b.post(w, view)
					if r ~= true then return r end
				end
				if o.post then return o.post(w, view) end
				return true
			end
		end
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = e
		added[#added + 1] = id
	end

	local function S(id, baseId, title, extra)
		-- Simple is phone-sized by rule (UI.Fold narrow(): W.Advanced() false): no unfolded shot of these
		local o = { base = baseId, simple = true, title = title, unfold = false }
		for k, v in pairs(extra or {}) do o[k] = v end
		scene(id, o)
	end

	-- the rider
	S("simple_home", "home", "Simple: the rider's list, drivers listed")
	S("simple_home_empty", "home_empty", "Simple: nobody online, the quiet OpenMap line under Why?")
	S("simple_confirm", "confirm", "Simple: Confirm, the one line Summon ... Fly about ... in place of the dial")
	S("simple_ride", "pass_rider", "Simple: in the group, waiting for the portal")
	S("simple_pay", "pay", "Simple: time to pay, three tip keys")
	S("simple_done", "done_paid", "Simple: done, paid and rated")
	S("simple_trips", "trips", "Simple: Trips")
	-- Settings
	S("simple_settings", "settings", "Simple: Settings home, the Advanced mode switch on top")
	S("simple_settings_driving", "settings_driving", "Simple: Settings > Driving, a Warlock's four rows")
	-- the driver
	S("simple_console_open", "console_open", "Simple: the console, open, riders listed")
	S("simple_console_closed", "console_closed", "Simple: the console, closed")
	S("simple_menu", "menu_chat", "Simple: a rider row's menu, five choices")
	S("simple_sheet", "console_closed", "Simple: the price sheet without Also called or Name riders see", {
		after = function(w)
			local D = w.Driver
			if type(D) ~= "table" or type(D.ShowSheet) ~= "function" then return "W.Driver.ShowSheet is missing" end
			if not D.ShowSheet("sheet") then return "no price sheet" end
			return true
		end })
	S("simple_earnings", "earnings", "Simple: Earnings")
	S("simple_shift", "shift", "Simple: the end-of-shift card")

	-- ranks
	scene("rank_row", { base = "home", simple = true, unfold = false,
		title = "Rank chips in the rider's list: a driver at 73, and the Founder with a very long name at 1,000",
		before = function(w)
			local UI = w.UI
			if type(UI) ~= "table" or type(UI.Drivers) ~= "function" then return "no W.UI.Drivers" end
			local orig, origOne = UI.Drivers, UI.Driver
			local function list(...)
				local out, mia = {}, nil
				for i, d in ipairs(orig(...)) do
					local x = {}
					for k, v in pairs(d) do x[k] = v end
					if x.key == "mia runner" then x.rank, mia = 73, x end
					out[i] = x
				end
				local like = mia or out[1]
				if like then
					local x = {}
					for k, v in pairs(like) do x[k] = v end
					x.name, x.key, x.short = "Zebediah Wolfeschlegelsteinhausen", "zebediah wolfeschlegelsteinhausen", "Zebediah Wolfeschlegelsteinhausen"
					x.service, x.creator, x.rank = "Zebediah Wolfeschlegelsteinhausen's Grand Tours", true, 1000
					out[#out + 1] = x
				end
				return out
			end
			if not shotStub(UI, "Drivers", list) then return "the tour has no stub" end
			if type(origOne) == "function" then
				shotStub(UI, "Driver", function(key, ...)
					for _, d in ipairs(list()) do if d.key == key then return d end end
					return origOne(key, ...)
				end)
			end
			return true
		end,
		post = function(w)
			local cards = type(w.UI.state) == "table" and w.UI.state.cards
			for _, key in ipairs({ "mia runner", "zebediah wolfeschlegelsteinhausen" }) do
				local c = type(cards) == "table" and cards[key]
				if not (c and c.rankChip and c.rankChip.IsShown and c.rankChip:IsShown()) then return "no rank chip on the row of " .. key end
			end
			return true
		end })
	scene("rank_card", { base = "console_closed", simple = true, unfold = false,
		title = "The New title card with Tell the guild, a driver in a guild",
		after = function(w)
			local env = type(getfenv) == "function" and type(w.UI.RankCard) == "function" and getfenv(w.UI.RankCard)
			if type(env) ~= "table" then return "no game environment to put the guild in" end
			state.guild = { env = env, was = rawget(env, "IsInGuild") }
			rawset(env, "IsInGuild", function() return true end)
			if not setSaved(w, { n = 10, seen = {} }) then return "no saved character" end
			w.Fire("DRIVE_RANK", 10, 2, "Cabbie", true)
			local f = rankCardFrame(w)
			if not (f and f.IsShown and f:IsShown()) then return "the New title card did not show" end
			if not (f.pill and f.pill.IsShown and f.pill:IsShown()) then return "the card has no Tell the guild pill (guild answer not seen)" end
			return true
		end })
	scene("rank_own", { base = "console_open", simple = false, only = "unfolded",
		title = "The wide Drive page: the driver's own title line and bar (Advanced)",
		before = function(w)
			if not setSaved(w, { n = 73, seen = {} }) then return "no saved character" end
			return true
		end })

	-- merged Settings rows (Advanced)
	local function merged(id, label, title)
		scene(id, { base = "settings_driving", simple = false, unfold = true, title = title,
			after = function(w)
				local P = mod(w, "UI.Settings.Panel")
				if type(L.PhotoOpenSetting) ~= "function" then return "no L.PhotoOpenSetting" end
				return L.PhotoOpenSetting(w.UI, P, label)
			end })
	end
	merged("settings_merged", "Chat channels", "Settings > Driving (Advanced) scrolled to Group size and Chat channels")
	merged("settings_merged_big", "Big button on screen", "Settings > Driving (Advanced) scrolled to Big button on screen and Alert character")
	return added
end

return X

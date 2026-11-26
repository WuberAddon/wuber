-- Layout scenes for the game's word on a rider's summon (FIX3 group E: Drive.Cast's DR.SummonSeen and DR.SummonHeld, the
-- rows of UI.Driver.Rows, the big button's line of Drive.Plan). Installed by tests/layout/extra_screens.lua (X.install calls
-- this file's install), so the scenes work alone (--screen console_summon,float_summon) and inside a whole sweep.
--   console_summon_seen  the driver console (the lab's console_open): Dan's row reads "declined: summon again?", the
--                        longest of the new row words; the big button reads "Wolfgangbert has a summon waiting"
--                        with its second line (a 12-letter name: the longest line the guard can make)
--   console_summon_long  the same with a 12-letter rider name: the row takes a shorter form, never a cut one
--   float_summon_held    the floating button with the same two lines, and the mini console's rows (284 wide) under it
-- The stubs are the tour's own shot stubs (L.PhotoKit): L.PhotoReset puts everything back before the next screen.
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

X.TITLE = "Wolfgangbert has a summon waiting"
X.SUB = "no second summon while it is up: it would waste a Soul Shard"

function X.install(L, W)
	local added = {}
	local DR, D = W.Drive, W.Driver
	if not (type(DR) == "table" and type(D) == "table" and type(DR.SummonSeen) == "function" and type(DR.SummonHeld) == "function") then return added end
	local K = L.PhotoKit
	local function shotStub(tbl, key, value)
		local t = K and type(K.tour) == "function" and K.tour()
		if not (t and type(K.stub) == "function") then return false end
		t.shotStubs = t.shotStubs or {}
		t.shotStubs[#t.shotStubs + 1] = { tbl, key, tbl[key] }
		return K.stub(tbl, key, value)
	end
	local function screen(id)
		for i, s in ipairs(L.PHOTO_SCREENS) do if s.id == id then return s, i end end
	end
	-- A scene goes right after the lab's screen it builds on, not at the end of the tour: at the end it inherits
	-- what the screens in between left behind (a console scrolled a few pixels, the floating button's raid stubs),
	-- which the lab's own screen never sees. (Found in a sweep of console_,float_,button_,raid: alone it was clean.)
	local function addAfter(base, s)
		local _, at = screen(base)
		table.insert(L.PHOTO_SCREENS, (at or #L.PHOTO_SCREENS) + 1, s)
		added[#added + 1] = s.id
	end
	-- the game says every rider who is not here yet declined; the button holds its cast for a rider with a summon waiting
	local function dress(w, longName)
		local dr = w.Drive
		local now = type(w.Now) == "function" and w.Now() or 0
		if shotStub(dr, "SummonSeen", function(c)
			if type(c) == "table" and (c.state == "joined" or c.state == "waiting") then return "declined", now - 5 end
			return nil
		end) == false then return "no shot stub (L.PhotoKit)" end
		if longName then
			-- (the lab makes a fresh demo queue for every shot: the name needs no putting back)
			for _, c in ipairs(type(dr.Sorted) == "function" and dr.Sorted() or {}) do
				if type(c) == "table" and c.state == "joined" then c.name = "Wolfgangbert Rider" end
			end
		end
		shotStub(dr, "Plan", function() return { marks = {}, color = "wait", title = X.TITLE, sub = X.SUB } end)
		if type(dr.Button) == "table" and type(dr.Button.Refresh) == "function" then dr.Button.Refresh() end
		local d = w.Driver
		if type(d.RefreshNow) == "function" then d.RefreshNow() elseif type(d.Refresh) == "function" then d.Refresh(true) end
		-- the scene checks itself: the button shows the guard's line (a shot of something else would prove nothing)
		local b = dr.button
		local title = type(b) == "table" and type(b.title) == "table" and b.title:GetText() or nil
		if title ~= X.TITLE then return "the big button does not show the guard's line: " .. tostring(title) end
		return true
	end
	-- a console row that shows the declined words (whole or a shorter form), or nil
	local function declinedRow(w)
		local v = type(w.Driver.ui) == "table" and w.Driver.ui.console
		for _, r in ipairs(type(v) == "table" and type(v.rows) == "table" and v.rows or {}) do
			local t = r:IsShown() and r.what and r.what:GetText() or ""
			if t:find("declined", 1, true) then return t end
		end
		return nil
	end
	local console = screen("console_open")
	if console and type(console.run) == "function" then
		-- (the second is added first, so the two end up in this order after console_open)
		for _, v in ipairs({ { "console_summon_long", true, "Driver console: the same with a 12-letter rider name (the row's shorter form)" },
			{ "console_summon_seen", false, "Driver console: a rider declined the summon; the button holds its cast for a rider with a summon waiting" } }) do
			addAfter("console_open", { id = v[1], side = "driver", unfold = true, title = v[3],
				run = function(w)
					local r = console.run(w)
					if r ~= true then return r end
					r = dress(w, v[2])
					if r ~= true then return r end
					if not declinedRow(w) then return "no console row shows the declined words" end
					return true
				end })
		end
	end
	local float = screen("float_summon_sent")
	if float and type(float.run) == "function" then
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "float_summon_held", side = "driver", wait = float.wait, maxWait = float.maxWait,
			title = "Floating button + console: a rider has a summon waiting; a row that declined",
			run = function(w)
				-- the mid-flight card (an earlier scene's) can be left up; it is no part of this shot
				local okf, IF = pcall(w.Mod, "UI.InFlight")
				if okf and type(IF) == "table" and type(IF.Hide) == "function" then pcall(IF.Hide) end
				local r = float.run(w)
				if r ~= true then return r end
				return dress(w, false)
			end, post = float.post }
		added[#added + 1] = "float_summon_held"
	end
	return added
end

return X

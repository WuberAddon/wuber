-- Wuber Lab (developer only, never ship): more of the Auto check's own screens (job 144).
-- The in-game test of 21 Nov 2026 handed the tester 20 hand steps; he hated it ("so long-winded", "some of that could have been
-- automated"). These screens do, in the game and by themselves, what those steps asked of him and a machine can do:
--   a_search_escape   the Settings search box, clicked and left with Escape, says "Search settings" again      (AUD-204)
--   a_bug_report      Report a bug: Escape closes it from the box and from nowhere; a player's name is left
--                     out of the report; the word "unknown" stays                          (HUNT-40, HUNT-56, HUNT-57, AUD-217, AUD-218)
--   a_pause_closed    Drive while closed: the dimmed Pause, clicked, still says Pause   (no step id: it cannot tell a fixed
--                     Wuber from an unfixed one under the tour's stand-in state; AUD-195 stays proved by its own test)
--   a_msg_toolong     Messages, the greeting: over 190 letters the counter is red and Save is refused with a red
--                     line ABOVE the two buttons; an empty box previews Wuber's own words            (AUD-167, HUNT-74, HUNT-75)
--   a_addbyname       Crew, Add by name: your own name and "---" are refused, no new row                          (AUD-224)
--   a_home_rings      the empty Home: the rings run again after a search is cleared, and how often they are
--                     started again while letters are typed (Tester: "it resets the pulse every time you type a letter").
--                     No step id (it passes on a Wuber of before AUD-208's mend too); the count is what it is for.
--   a_plates          nameplates in view: who should wear a crown or a badge, and who does (Tester: "only above my own
--                     head, not my other character"). Read only; no step id: it answers a question of the test.
--   a_font           (job 135) the font: its files load, the game's widths match Wuber's width table, digits line up, every label
--                     is on the size scale (L.AutoFontCheck; no step id)
-- Same rules as AutoSteps.lua: only a button's own insecure OnClick or an edit box's own handlers, everything local to
-- this window, WuberDB put back by the tour's snapshot. Nothing here opens the driver, invites, whispers (the crew
-- offer's whisper is stubbed for that one screen, and reported if Wuber asks for one), advertises, trades or summons.
-- tools/steps2lua.py --auto reads the quoted step ids in every Auto*.lua of this folder.

local _, L = ...

local K, P, X = L.PhotoKit, L.PhotoShotKit, L.AutoKit
local str, num = L.str, L.num
local fn = K.fn

local SCREENS = L.AUTO_SCREENS
local function screen(s)
	s.auto = true
	SCREENS[#SCREENS + 1] = s
	return s
end

local function tourScreen(id)
	for _, s in ipairs(L.PHOTO_SCREENS or {}) do if s.id == id then return s end end
	return nil
end
local function runOf(id)
	return function(W, view)
		local s = tourScreen(id)
		if not s then return "the tour has no screen " .. id end
		return s.run(W, view)
	end
end
local function data()
	local t = K.tour()
	if not t then return {} end
	t.autoData = t.autoData or {}
	return t.autoData
end
local function settingsOf(W) return type(W.UI) == "table" and type(W.UI.settings) == "table" and W.UI.settings or nil end
local function driveScreens(W)
	local d = type(W.UI) == "table" and W.UI.drive
	return type(d) == "table" and type(d.screens) == "table" and d.screens or nil
end
local function script(f, name)
	if type(f) ~= "table" or not fn(f, "GetScript") then return nil end
	local ok, h = pcall(f.GetScript, f, name)
	return ok and type(h) == "function" and h or nil
end
local function textOf(fs)
	if type(fs) ~= "table" or not fn(fs, "GetText") then return nil end
	local ok, t = pcall(fs.GetText, fs)
	return ok and str(t) or nil
end
local function shown(f)
	if type(f) ~= "table" or not fn(f, "IsShown") then return false end
	local ok, v = pcall(f.IsShown, f)
	return ok and v == true
end
-- one edge of a region, or nil (the game gives NO value for a region it has not placed yet: never tonumber(f:GetTop()))
local function edge(f, name)
	if type(f) ~= "table" or not fn(f, name) then return nil end
	local ok, v = pcall(f[name], f)
	return ok and num(v) or nil
end
-- the button a drawn label belongs to (the label, its parent or its grandparent has the click)
local function buttonOf(obj)
	local f = obj
	for _ = 1, 4 do
		if type(f) ~= "table" then return nil end
		if script(f, "OnClick") then return f end
		if not fn(f, "GetParent") then return nil end
		local ok, p = pcall(f.GetParent, f)
		f = ok and p or nil
	end
	return nil
end
L.AutoButtonOf = buttonOf

---------------------------------------------------------------------------
-- Settings: the search box and Escape (old hand step 5)
---------------------------------------------------------------------------

-- the placeholder is the longest of these that fits the box (UI/Settings/Find.lua)
local SEARCH_TEXTS = { "Ask or search: how do I mute sounds?", "Ask or search settings", "Search settings" }
local SEARCH_WORDS = "the search placeholder"
local function searchShown(W)
	local S = X.scan(W)
	for _, t in ipairs(SEARCH_TEXTS) do
		if X.find(S, t, true) then return true end
	end
	return false
end
screen({ id = "a_search_escape", side = "settings",
	title = 'Settings: the search box, clicked and left with Escape, says "' .. SEARCH_WORDS .. '" again',
	covers = { folded = { verify = { "AUD-204" } } },
	run = function(W)
		return P.settings(W, function(UI)
			if not UI.OpenSettings() then return "settings didn't open" end
			return true
		end)
	end,
	post = function(W)
		local d = data()
		d.esc = nil
		local st = settingsOf(W)
		local box = st and type(st.find) == "table" and st.find.box
		local eb = type(box) == "table" and box.edit
		if type(eb) ~= "table" then return true end
		local e = { before = searchShown(W) }
		-- the click: the box takes the keyboard; then Escape with nothing typed (the box's own handler), keyboard let go
		if fn(eb, "SetFocus") then pcall(eb.SetFocus, eb) end
		local esc = script(eb, "OnEscapePressed")
		if esc then e.ok, e.err = pcall(esc, eb) else e.noEsc = true end
		if fn(eb, "ClearFocus") then pcall(eb.ClearFocus, eb) end
		e.typed = fn(eb, "GetText") and (str(eb:GetText()) or "") or ""
		d.esc = e
		return true
	end,
	verify = function(W)
		local e = data().esc
		if not e then return "skip", "this Settings has no search box the check knows" end
		if e.noEsc then return "look", "the search box has no Escape handler of its own" end
		if e.ok == false then return "look", "Escape in the search box broke: " .. tostring(e.err) end
		if e.typed ~= "" then return "look", 'after Escape the box still holds "' .. X.short(e.typed, 40) .. '"' end
		if not searchShown(W) then
			return "look", 'after a click and Escape with nothing typed the box does not say "' .. SEARCH_WORDS .. '"'
		end
		return "pass", '"' .. SEARCH_WORDS .. '" shows again after a click and Escape'
	end })

---------------------------------------------------------------------------
-- Report a bug (old hand step 7)
---------------------------------------------------------------------------

local BUG_NAME, BUG_WORD = "Quinn-Argent hurt me", "an unknown thing went wrong"
screen({ id = "a_bug_report", side = "settings",
	title = "Report a bug: Escape closes it, a player's name is left out of the report, the word unknown stays",
	covers = { folded = { verify = { "HUNT-40", "HUNT-56", "HUNT-57", "AUD-217", "AUD-218" } } },
	run = runOf("bug_window"),
	post = function(W)
		local d = data()
		d.bug = nil
		local B = type(W.UI) == "table" and W.UI.Bug
		if type(B) ~= "table" or not (fn(B, "Open") and fn(B, "Shown") and fn(B, "Report")) then return true end
		local b = {}
		local f = B.frame
		local note = type(f) == "table" and type(f.note) == "table" and f.note.edit
		-- Escape with the keyboard in "What happened?": once is enough
		local esc = script(note, "OnEscapePressed")
		if esc then
			pcall(esc, note)
			b.escBox = not B.Shown()
			B.Open()
		end
		-- Escape with the keyboard nowhere: the game hides the windows named in UISpecialFrames
		local holder = type(f) == "table" and (f.holder or f)
		local name = type(holder) == "table" and fn(holder, "GetName") and str(holder:GetName())
		local special = rawget(_G, "UISpecialFrames")
		if name and type(special) == "table" then
			b.listed = false
			-- an open sheet takes its window's slot (Wuber/Theme/Forms.lua escTake): the sheet's name counts too, and the sheet is what Escape hides
			local sheetName = type(f) == "table" and fn(f, "GetName") and str(f:GetName())
			local target = holder
			for _, n in ipairs(special) do
				if n == name then b.listed = true end
				if sheetName and n == sheetName then b.listed, target = true, f end
			end
			if b.listed then
				pcall(target.Hide, target)
				b.escGame = not B.Shown()
				B.Open()
			end
		end
		local okN, textN = pcall(B.Report, BUG_NAME)
		local okW, textW = pcall(B.Report, BUG_WORD)
		b.name = okN and str(textN) or nil
		b.word = okW and str(textW) or nil
		d.bug = b
		return true
	end,
	verify = function()
		local b = data().bug
		if not b then return "skip", "this Wuber has no UI.Bug.Open / Shown / Report" end
		local out = {}
		local function add(name, status, detail, steps) out[#out + 1] = { name = name, status = status, detail = detail, steps = steps } end
		if b.escBox == nil then add("Escape in What happened?", "skip", "no What happened? box found", { "HUNT-56", "HUNT-57" })
		else add("Escape in What happened?", b.escBox and "pass" or "look", b.escBox and "one Escape closes the report" or "the report is still open after Escape in the box", { "HUNT-56", "HUNT-57" }) end
		if b.listed == nil then add("Escape with the keyboard free", "skip", "the report's frame has no name", { "HUNT-40" })
		elseif not b.listed then add("Escape with the keyboard free", "look", "the report is not among the windows the game closes with Escape", { "HUNT-40" })
		else add("Escape with the keyboard free", b.escGame and "pass" or "look", b.escGame and "the game's Escape closes the report" or "hidden by the game's Escape, Wuber still counts the report as open", { "HUNT-40" }) end
		if not b.name then add("a player's name", "look", "the report could not be made", { "AUD-217" })
		elseif b.name:find("Quinn", 1, true) or b.name:find("Argent", 1, true) then add("a player's name", "look", '"' .. BUG_NAME .. '" is in the report with the name', { "AUD-217" })
		elseif not b.name:find("player 1 hurt me", 1, true) then add("a player's name", "look", 'the report has no "player 1 hurt me" for "' .. BUG_NAME .. '"', { "AUD-217" })
		else add("a player's name", "pass", '"' .. BUG_NAME .. '" reads "player 1 hurt me", no realm', { "AUD-217" }) end
		if not b.word then add("the word unknown", "look", "the report could not be made", { "AUD-218" })
		else add("the word unknown", b.word:find(BUG_WORD, 1, true) and "pass" or "look",
			b.word:find(BUG_WORD, 1, true) and "kept as typed" or ('"' .. BUG_WORD .. '" is not in the report as typed'), { "AUD-218" }) end
		return out
	end })

---------------------------------------------------------------------------
-- Drive while closed: the dimmed Pause (old hand step 9)
---------------------------------------------------------------------------

-- No step id: with the tour's stand-in state on screen this passes on a Wuber without the fix too (tried on 2.3.3), so it
-- does not stand in for the old step; it only says the button did not flip here.
screen({ id = "a_pause_closed", side = "driver", title = "Drive while closed: the dimmed Pause, clicked, still says Pause",
	run = function(W)
		return P.console(W, { open = false, queue = {}, plan = { color = "off", title = "Closed", sub = "tap Open to take riders" } })
	end,
	post = function(W)
		local d = data()
		d.pause = nil
		local t = X.find(X.scan(W), "^Pause$")
		local b = t and buttonOf(t.obj)
		if not b then return true end
		local p = {}
		p.ok, p.why = X.press(b)
		local S = X.scan(W)
		p.pause, p.resume = X.find(S, "^Pause$") ~= nil, X.find(S, "^Resume$") ~= nil
		d.pause = p
		return true
	end,
	verify = function()
		local p = data().pause
		if not p then return "skip", 'no "Pause" button on the closed Drive screen' end
		if not p.ok then return "look", "Pause: " .. tostring(p.why) end
		if p.resume or not p.pause then return "look", 'after a click on the dimmed Pause the button reads "Resume"' end
		return "pass", 'clicked while closed, it still reads "Pause"'
	end })

---------------------------------------------------------------------------
-- Messages: the greeting, too long, and empty (old hand step 10)
---------------------------------------------------------------------------

local LONG = ("please take the summon and open trade when you land "):rep(4) -- 208 letters, plain words
screen({ id = "a_msg_toolong", side = "driver", unfold = true,
	title = "Messages, the greeting: too long is refused with a red line above the buttons; empty shows Wuber's own words",
	covers = { any = { verify = { "AUD-167", "HUNT-74", "HUNT-75" } } },
	run = runOf("messages"),
	post = function(W)
		local d = data()
		d.msg = nil
		local sc = driveScreens(W)
		local ms = sc and sc.messages
		local e = type(ms) == "table" and ms.editor
		if not (type(e) == "table" and type(e.field) == "table" and fn(e.field, "SetText") and type(e.save) == "table"
			and type(ms.edit) == "function" and type(ms.preview) == "function") then return true end
		ms.edit("greet")
		local m = {}
		-- empty: the preview shows Wuber's own words, not a blank
		e.field:SetText("")
		ms.preview()
		m.emptyPreview = textOf(e.prev)
		-- too long: the counter is red, Save is refused, the red line sits above Reset and Save
		e.field:SetText(LONG)
		ms.preview()
		if type(e.meter) == "table" and fn(e.meter, "GetTextColor") then
			local r, g, b = e.meter:GetTextColor()
			m.meter, m.r, m.g, m.b = textOf(e.meter), num(r), num(g), num(b)
		end
		m.saved, m.saveWhy = X.press(e.save)
		m.why = shown(e.why) and textOf(e.why) or nil
		m.whyBottom = edge(e.why, "GetBottom")
		m.resetTop, m.saveTop = edge(e.reset, "GetTop"), edge(e.save, "GetTop")
		d.msg = m
		return true
	end,
	verify = function()
		local m = data().msg
		if not m then return "skip", "this Wuber's Messages editor is not the one the check knows" end
		local out = {}
		local function add(name, status, detail, steps) out[#out + 1] = { name = name, status = status, detail = detail, steps = steps } end
		if not m.emptyPreview or m.emptyPreview == "" then add("an empty box", "look", "the preview is blank", { "HUNT-75" })
		else add("an empty box", "pass", 'the preview shows "' .. X.short(m.emptyPreview, 50) .. '"', { "HUNT-75" }) end
		if not m.r then add("the counter", "skip", "no counter found", { "HUNT-74" })
		else
			local red = m.r > 0.7 and m.g < 0.55 and m.b < 0.6
			add("the counter", red and "pass" or "look", ('"%s" is %s over the limit'):format(tostring(m.meter), red and "red" or "not red"), { "HUNT-74" })
		end
		if not m.saved then add("Save, too long", "look", "Save: " .. tostring(m.saveWhy), { "AUD-167" })
		elseif not m.why then add("Save, too long", "look", 'no red "Not saved" line after Save with ' .. #LONG .. " letters", { "AUD-167" })
		elseif not m.why:find("^Not saved") then add("Save, too long", "look", 'the line reads "' .. X.short(m.why, 60) .. '"', { "AUD-167" })
		elseif m.whyBottom and ((m.resetTop and m.whyBottom < m.resetTop - 0.5) or (m.saveTop and m.whyBottom < m.saveTop - 0.5)) then
			add("Save, too long", "look", '"' .. X.short(m.why, 40) .. '" is drawn over Reset to default or Save', { "AUD-167" })
		else add("Save, too long", "pass", '"' .. X.short(m.why, 60) .. '" above the two buttons', { "AUD-167" }) end
		return out
	end })

---------------------------------------------------------------------------
-- Crew: Add by name with a name that is refused (old hand step 12)
---------------------------------------------------------------------------

screen({ id = "a_addbyname", side = "driver", title = 'Crew, Add by name: your own name and "---" are refused, no new row',
	covers = { folded = { verify = { "AUD-224" } } },
	run = function(W)
		-- whatever Wuber decides, no crew offer leaves this window during the check
		if type(W.Drive) == "table" then
			local asked = {}
			data().offerAsked = asked
			P.shotStub(W.Drive, "Whisper", function(target) asked[#asked + 1] = tostring(target) end)
		end
		return runOf("crew")(W)
	end,
	post = function(W)
		local d = data()
		d.add = nil
		local sc = driveScreens(W)
		local cs = sc and sc.crew
		local ad = type(cs) == "table" and cs.adder
		if not (type(ad) == "table" and type(ad.field) == "table" and fn(ad.field, "SetText") and type(ad.add) == "table") then return true end
		local me = str(W.myName) or (fn(W, "Me") and str(W.Me())) or nil
		if not me then return true end
		local a = { toasts = #X.toasts(), rows = type(cs.extra) == "table" and #cs.extra or 0, tries = {} }
		for _, name in ipairs({ me, "---" }) do
			ad.field:SetText(name)
			local ok, why = X.press(ad.add)
			a.tries[#a.tries + 1] = { name = name == me and "your own name" or '"---"', ok = ok, why = why }
		end
		a.rowsAfter = type(cs.extra) == "table" and #cs.extra or 0
		a.asked = d.offerAsked and #d.offerAsked or 0
		d.add = a
		return true
	end,
	verify = function()
		local a = data().add
		if not a then return "skip", "this Wuber's Crew screen has no Add by name box the check knows" end
		for _, t in ipairs(a.tries) do
			if not t.ok then return "look", "Add with " .. t.name .. ": " .. tostring(t.why) end
		end
		local bad = {}
		if a.asked > 0 then bad[#bad + 1] = a.asked .. " crew offer(s) would have been whispered" end
		if a.rowsAfter > a.rows then bad[#bad + 1] = (a.rowsAfter - a.rows) .. " new row(s) listed" end
		local n = 0
		for i = a.toasts + 1, #X.toasts() do
			-- "---" is refused before the offer ("That isn't a player's name"); your own name at the offer ("Couldn't send the offer")
			local say = X.toasts()[i]
			if say:find("Couldn't send the offer", 1, true) or say:find("That isn't a player's name", 1, true) then n = n + 1 end
		end
		if n < #a.tries then bad[#bad + 1] = ('"Couldn\'t send the offer" said %d times for %d refused names'):format(n, #a.tries) end
		if #bad > 0 then return "look", table.concat(bad, "; ") end
		return "pass", "both refused: the note \"Couldn't send the offer\", no new row, nothing whispered"
	end })

---------------------------------------------------------------------------
-- The empty Home's rings (old hand step 15, and what the tester saw while typing)
---------------------------------------------------------------------------

local RING_WORD = "qxqxq" -- five letters that are no place and no driver
local RING_PLACE = "Gadgetzan"
screen({ id = "a_home_rings", side = "rider", title = "Home with nobody online: the rings run after a search is cleared, and are not started again by each letter",
	-- No step id: it passes on a Wuber of before the mend too (tried on 2.3.3), so it does not stand in for the old step
	-- (AUD-208 stays proved by its own test). It is here for the count of starts while typing, which only the game can give.
	run = function(W, view)
		-- a rider with no usual place: the empty Home then shows its ring disc (with one, it offers that place instead)
		if fn(W, "Usual") then P.shotStub(W, "Usual", function() return nil end) end
		return runOf("home_empty")(W, view)
	end,
	post = function(W)
		local d = data()
		d.rings = nil
		local st = type(W.UI) == "table" and W.UI.state
		local hs = type(st) == "table" and type(st.screens) == "table" and st.screens.home
		local e = type(hs) == "table" and hs.empty
		local p = type(e) == "table" and e.pulse
		if not (type(p) == "table" and fn(p, "Start") and fn(W.UI, "SetSearch")) then return true end
		local r = { starts = 0, per = {}, discBefore = shown(e.disc), runBefore = p.running == true }
		local real = p.Start
		p.Start = function(self, ...)
			r.starts = r.starts + 1
			return real(self, ...)
		end
		local okT, errT = pcall(function()
			for i = 1, #RING_WORD do
				local before = r.starts
				W.UI.SetSearch(RING_WORD:sub(1, i))
				r.per[i] = r.starts - before
			end
			r.typing = r.starts
			-- then a place nobody serves (the bounty layout hides the disc), and the search cleared: the rings must run again
			W.UI.SetSearch(RING_PLACE)
			r.placeDisc = shown(e.disc)
			W.UI.SetSearch("")
		end)
		p.Start = nil -- (the handle's own Start again)
		if not okT then r.err = tostring(errT) end
		r.disc, r.running = shown(e.disc), p.running == true
		local ring = type(p.rings) == "table" and p.rings[1]
		if type(ring) == "table" and type(ring.ag) == "table" and fn(ring.ag, "IsPlaying") then
			local okP, v = pcall(ring.ag.IsPlaying, ring.ag)
			if okP then r.playing = v == true end
		end
		d.rings = r
		return true
	end,
	verify = function()
		local r = data().rings
		if not r then return "skip", "this Wuber's Home has no ring pulse the check knows" end
		if r.err then return "look", "typing in the search broke: " .. r.err end
		local out = {}
		local per = table.concat(r.per, " ")
		if not r.discBefore then
			out[#out + 1] = { name = "after clearing a search", status = "skip", detail = "this Home shows no ring disc when the search is empty (a usual place is offered instead)", steps = {} }
		elseif not r.disc then
			out[#out + 1] = { name = "after clearing a search", status = "look", detail = "the ring disc did not come back", steps = {} }
		elseif not r.running or r.playing == false then
			out[#out + 1] = { name = "after clearing a search", status = "look", detail = "the disc is back but its rings stand still", steps = {} }
		else
			out[#out + 1] = { name = "after clearing a search", status = "pass", detail = "the disc is back and its rings run", steps = {} }
		end
		-- the rings may start once when the disc first shows; a start on most letters is what the tester saw
		local many = (r.typing or 0) > 1
		out[#out + 1] = { name = "while typing", status = many and "look" or "info", steps = {},
			detail = ("the rings were started %d time(s) while %d letters were typed (per letter: %s)"):format(r.typing or 0, #RING_WORD, per) }
		return out
	end })

---------------------------------------------------------------------------
-- Nameplates in view: who should wear a crown or a badge, and who does (read only)
---------------------------------------------------------------------------

local function gameCall(name, ...)
	local f = rawget(_G, name)
	if type(f) ~= "function" then return nil end
	local ok, a = pcall(f, ...)
	return ok and K.plain and K.plain(a) or (ok and a or nil)
end

screen({ id = "a_plates", side = "rider", title = "Nameplates in view: who should wear a crown or a badge, and who does",
	run = runOf("home"),
	verify = function(W)
		local Pl = W.Plates
		if type(Pl) ~= "table" or not fn(Pl, "LookFor") then return "skip", "this Wuber has no W.Plates.LookFor" end
		local realm = str(gameCall("GetRealmName")) or "?"
		local ruleset = fn(W, "Ruleset") and str(W.Ruleset()) or "?"
		local founders = fn(W, "OnFounderRuleset") and W.OnFounderRuleset() == true
		local friendly = fn(Pl, "FriendlyPlatesOn") and Pl.FriendlyPlatesOn() == true
		local seen, want, got, missing, listed = 0, 0, 0, {}, {}
		for i = 1, 40 do
			local unit = "nameplate" .. i
			if gameCall("UnitExists", unit) == true and gameCall("UnitIsPlayer", unit) == true and gameCall("UnitIsUnit", unit, "player") ~= true then
				seen = seen + 1
				local name = fn(W, "UnitName") and str(W.UnitName(unit)) or nil
				local key = name and fn(W, "Key") and W.Key(name) or nil
				local okL, kind = pcall(Pl.LookFor, key)
				kind = okL and str(kind) or nil
				-- on the founder list but refused (another ruleset, or the check says no)
				if not kind and key and type(W.CREATOR) == "table" and W.CREATOR[key] then listed[#listed + 1] = name end
				if kind then
					want = want + 1
					local plate = fn(Pl, "GetPlate") and Pl.GetPlate(unit) or nil
					local has = false
					if type(plate) == "table" and fn(plate, "GetChildren") then
						local kids = { pcall(plate.GetChildren, plate) }
						for j = 2, #kids do
							local c = kids[j]
							if type(c) == "table" and c.plateKind and shown(c) then has = true end
						end
					end
					if has then got = got + 1
					else missing[#missing + 1] = name .. " (" .. kind .. (plate and "" or ", the game gave no nameplate frame") .. ")" end
				end
			end
		end
		local count = fn(Pl, "Count") and num(Pl.Count()) or 0
		local facts = ('friendly nameplates %s; realm "%s", ruleset %s, the founders\' ruleset here: %s; %d other players\' nameplates in view, %d should wear a crown or badge, %d do (Wuber counts %d drawn)')
			:format(friendly and "on" or "off", realm, ruleset, founders and "yes" or "no", seen, want, got, count)
		if seen == 0 then return "skip", facts .. ". Nobody else's nameplate is in view: stand next to your other characters with friendly nameplates on" end
		if #listed > 0 then return "look", facts .. ". On the founder list but given nothing: " .. table.concat(listed, ", ") end
		if want == 0 then return "skip", facts .. ". Nobody in view should wear one" end
		if got < want and count < want then return "look", facts .. ". Nothing drawn over: " .. table.concat(missing, ", ") end
		return "pass", facts
	end })


---------------------------------------------------------------------------
-- The font: the game really draws the file Wuber names, at the widths Wuber's width table expects (job 135, design round 3)
-- Reads the paths, the sizes and the width table from Wuber (W.Theme.FONTS, SCALE, MeasureText, FONT_WAIT), never a font's
-- name, so it runs on a Wuber of either font. Builds its one hidden font string on first use (nothing at load).
-- No step id: it stands in for no hand step. A fail starts its words with "fail:".
---------------------------------------------------------------------------

local FONT_WEIGHTS = { "regular", "medium", "bold" }
local FONT_SIZES = { 11, 14, 22 }
local FONT_PROBES = { "abcdefghijklmnopqrstuvwxyz", "The quick brown fox jumps over the lazy dog", "0123456789", "123g 45s", "Warlock summon", 
	"Wuber finds you a Warlock who will summon you to Feathermoon Stronghold, so you can skip the long bird ride and be there in about half a minute" }
local FONT_DIGITS = { "1111", "0000", "8888" }
-- (#317) sizes above 11: 4% was the table's room; the game's widths at 14 and 22 were measured at 4.0 to 4.2% over the raw table
-- (job 2885, FONT-WIDTHS-REPORT, and run 4 saw +4.2% at 14), so the line is 5%: widened only to what was measured, not further
local FONT_TOL = 0.05
local FONT_TOL_SMALL = 0.08 -- size 11: the game snaps its text to whole pixels (run 3 saw +4.5% to +6.4%)
local FONT_DIGIT_TOL = 1 -- digits: within a pixel (run 3 saw 0.5 px)
local fontString = nil

local function fontFs()
	if fontString then return fontString end
	local mk = rawget(_G, "CreateFrame")
	if type(mk) ~= "function" then return nil end
	local okF, f = pcall(mk, "Frame", nil, rawget(_G, "UIParent"))
	if not okF or type(f) ~= "table" then return nil end
	pcall(f.Hide, f)
	local okS, fs = pcall(f.CreateFontString, f, nil, "OVERLAY")
	if not okS or type(fs) ~= "table" then return nil end
	fontString = fs
	return fs
end

-- the game's width of text in a file at a size ("" flags, empty text first so the width is of this text alone)
local function drawnWidth(fs, path, size, text)
	if not pcall(fs.SetFont, fs, path, size, "") then return nil end
	pcall(fs.SetText, fs, "")
	pcall(fs.SetText, fs, text)
	local ok, w = pcall(fs.GetStringWidth, fs)
	return ok and num(w) or nil
end
local function slashes(p) return (tostring(p or ""):gsub("\\", "/"):lower()) end
local function short(s) s = tostring(s); return #s > 24 and (s:sub(1, 21) .. "...") or s end

-- the game may need a moment to load a font file the first time a string asks for it (Wuber's own late-font probe waits for
-- the same): the screen's run asks for all three files, and the verdict comes after the screen has settled
L.AutoFontWarm = function(W)
	local T = type(W) == "table" and type(W.Theme) == "table" and W.Theme or nil
	local fs = T and type(T.FONTS) == "table" and fontFs() or nil
	if not fs then return end
	for _, wt in ipairs(FONT_WEIGHTS) do
		if T.FONTS[wt] then
			for _, size in ipairs(FONT_SIZES) do
				pcall(fs.SetFont, fs, T.FONTS[wt], size, "")
				pcall(fs.SetText, fs, FONT_PROBES[2])
			end
		end
	end
	if type(T.FONT_WAIT) == "table" and T.FONTS.regular then pcall(fs.SetFont, fs, T.FONTS.regular, T.FONT_WAIT.size or 22, "") end
end

L.AutoFontCheck = function(W)
	local T = type(W) == "table" and type(W.Theme) == "table" and W.Theme or nil
	if not (T and type(T.FONTS) == "table" and type(T.MeasureText) == "function") then
		return { { name = "font", status = "skip", detail = "this Wuber has no W.Theme.FONTS and MeasureText" } }
	end
	local fs = fontFs()
	if not fs then return { { name = "font", status = "skip", detail = "the game gave no font string to try with" } } end
	local out = {}
	local function add(name, bad, okWords, failWords)
		out[#out + 1] = { name = name, status = #bad == 0 and "pass" or "look",
			detail = #bad == 0 and okWords or ("fail: " .. failWords .. table.concat(bad, "; ", 1, math.min(#bad, 4)) .. (#bad > 4 and ("; and " .. (#bad - 4) .. " more") or "")) }
	end

	-- 1. each file loads: a font string given the file answers the same path
	local bad, files = {}, 0
	for _, wt in ipairs(FONT_WEIGHTS) do
		local path = T.FONTS[wt]
		if path then
			files = files + 1
			pcall(fs.SetFont, fs, path, 14, "")
			local okG, got = pcall(fs.GetFont, fs)
			if not okG or slashes(got) ~= slashes(path) then bad[#bad + 1] = ("%s: asked %s, the game answers %s"):format(wt, tostring(path), tostring(okG and got or nil)) end
		end
	end
	add("files load", bad, files .. " font files, each answered by its own path", "")

	-- 2. the width the game draws is the width Wuber's table expects (MeasureText adds 3% of room to spare)
	bad = {}
	local n = 0
	for _, wt in ipairs(FONT_WEIGHTS) do
		local path = T.FONTS[wt]
		if path then
			for _, size in ipairs(FONT_SIZES) do
				for _, text in ipairs(FONT_PROBES) do
					n = n + 1
					local got = drawnWidth(fs, path, size, text)
					local okM, m = pcall(T.MeasureText, text, size, wt)
					local want = okM and num(m) and m / 1.03 or nil
					if not got or got <= 0 or not want or want <= 0 then
						bad[#bad + 1] = ('"%s" %s %d: no width (game %s, table %s)'):format(short(text), wt, size, tostring(got), tostring(want))
					elseif math.abs(got - want) > want * (size <= 11 and FONT_TOL_SMALL or FONT_TOL) then
						bad[#bad + 1] = ('"%s" %s %d: game %.1f, table %.1f (%+.1f%%)'):format(short(text), wt, size, got, want, (got - want) / want * 100)
					end
				end
			end
		end
	end
	add("widths", bad, n .. " strings at sizes 11, 14 and 22 in each weight: the game's widths are within 5% (8% at size 11, where the game snaps to whole pixels) of Wuber's table", n .. " tried, off by more than 5% (8% at size 11): ")

	-- 3. digits line up: 1111, 0000 and 8888 are as wide as each other
	bad = {}
	for _, wt in ipairs(FONT_WEIGHTS) do
		local path = T.FONTS[wt]
		if path then
			local ws, lo, hi = {}, nil, nil
			for i, d in ipairs(FONT_DIGITS) do
				local w = drawnWidth(fs, path, 14, d)
				ws[i] = w and ("%.2f"):format(w) or "?"
				if w then lo, hi = math.min(lo or w, w), math.max(hi or w, w) end
			end
			if not lo or #ws < #FONT_DIGITS or hi - lo > FONT_DIGIT_TOL or ws[1] == "?" or ws[2] == "?" or ws[3] == "?" then
				bad[#bad + 1] = ("%s: 1111 %s, 0000 %s, 8888 %s"):format(wt, ws[1], ws[2], ws[3])
			end
		end
	end
	add("digits", bad, "1111, 0000 and 8888 are within 1 px of each other in each weight", "")

	-- 4. every visible label is on the scale
	if type(T.SCALE) ~= "table" or type(T.allText) ~= "table" then
		out[#out + 1] = { name = "sizes", status = "skip", detail = "this Wuber has no W.Theme.SCALE: skipped" }
	else
		local onScale = {}
		for _, s in ipairs(T.SCALE) do onScale[s] = true end
		bad = {}
		local seen = 0
		for label in pairs(T.allText) do
			if type(label) == "table" and label ~= fs then
				local vis = false
				local f = label.IsVisible or label.IsShown
				if type(f) == "function" then local okV, v = pcall(f, label); vis = okV and v == true end
				local okG, _, size = pcall(label.GetFont, label)
				size = okG and num(size) or nil
				if vis and size then
					seen = seen + 1
					local r = math.floor(size + 0.5)
					if not onScale[r] then
						local okT, words = pcall(label.GetText, label)
						bad[#bad + 1] = ('"%s" is size %s'):format(short(okT and words or "?"), tostring(size))
					end
				end
			end
		end
		add("sizes", bad, seen .. " visible labels, each at one of the sizes " .. table.concat(T.SCALE, ", "), "labels off the scale: ")
	end

	-- 5. the late-font probe now: Wuber's own test of "is the font here" (WatchFont itself cannot be asked twice)
	local wait = T.FONT_WAIT
	if type(wait) ~= "table" or not wait.probe then
		out[#out + 1] = { name = "arrived", status = "skip", detail = "this Wuber has no W.Theme.FONT_WAIT probe: skipped" }
	else
		local got = drawnWidth(fs, T.FONTS.regular, wait.size or 22, wait.probe)
		local okM, m = pcall(T.MeasureText, wait.probe, wait.size or 22, "regular")
		local want = okM and num(m) and m / 1.03 or nil
		local near = tonumber(wait.near) or FONT_TOL
		if got and want and math.abs(got - want) <= want * near then
			out[#out + 1] = { name = "arrived", status = "pass", detail = ("the probe is %.1f wide, Wuber expects %.1f: the font was there"):format(got, want) }
		else
			out[#out + 1] = { name = "arrived", status = "look", detail = ("fail: the probe is %s wide, Wuber expects %s: the font is not (yet) the one drawn"):format(got and ("%.1f"):format(got) or "?", want and ("%.1f"):format(want) or "?") }
		end
	end
	-- 6. line heights (fact-finder): one line, and two lines at width 120 with Wuber's spacing, against the fake game's
	-- rule, which is Wuber's own layout rule (one line is as tall as its size; n lines are n x size + (n - 1) x T.Spacing)
	if type(T.Spacing) ~= "function" or type(T.FONTS.regular) ~= "string" then
		out[#out + 1] = { name = "line heights", status = "skip", detail = "this Wuber has no W.Theme.Spacing or regular font: skipped" }
	else
		local function call(obj, name, ...)
			local f = obj[name]
			if type(f) ~= "function" then return nil end
			local okC, v = pcall(f, obj, ...)
			return okC and num(v) or nil
		end
		local parts, bad = {}, {}
		local function within(got, want) return got and want and want > 0 and math.abs(got - want) <= want * 0.12 end
		for _, size in ipairs(FONT_SIZES) do
			pcall(fs.SetFont, fs, T.FONTS.regular, size, "")
			pcall(fs.SetWordWrap, fs, false)
			pcall(fs.SetSpacing, fs, 0)
			pcall(fs.SetWidth, fs, 0)
			pcall(fs.SetText, fs, "")
			pcall(fs.SetText, fs, "Warlock")
			local h1, lh = call(fs, "GetStringHeight"), call(fs, "GetLineHeight")
			local want1 = 1.0 * size
			-- two lines: words added until the text is taller than one and a half lines (it wraps to exactly two)
			local sp = num(select(2, pcall(T.Spacing, size))) or 0
			pcall(fs.SetWordWrap, fs, true)
			pcall(fs.SetSpacing, fs, sp)
			pcall(fs.SetWidth, fs, 120)
			local h2, lines, text = nil, nil, ""
			for _, word in ipairs({ "Warlock", "summon", "to", "the", "far", "inn", "now", "please", "thank", "you", "very", "much", "friend" }) do
				text = text == "" and word or (text .. " " .. word)
				pcall(fs.SetText, fs, "")
				pcall(fs.SetText, fs, text)
				local h = call(fs, "GetStringHeight")
				if h1 and h and h1 > 0 and h > h1 * 1.5 then h2, lines = h, call(fs, "GetNumLines") break end
			end
			local want2 = 2 * want1 + sp
			local bits = {}
			bits[#bits + 1] = ("%d: one line %s (fake %.1f), line height %s, two lines %s (fake %.1f), lines %s"):format(size,
				h1 and ("%.1f"):format(h1) or "?", want1, lh and ("%.1f"):format(lh) or "n/a", h2 and ("%.1f"):format(h2) or "?", want2, lines and tostring(lines) or "n/a")
			parts[#parts + 1] = bits[1]
			if not within(h1, want1) or not within(h2, want2) or (lh and not within(lh, want1)) or (lines and lines ~= 2) then bad[#bad + 1] = bits[1] end
		end
		pcall(fs.SetSpacing, fs, 0)
		pcall(fs.SetWordWrap, fs, true)
		pcall(fs.SetWidth, fs, 0)
		out[#out + 1] = { name = "line heights", status = #bad == 0 and "pass" or "look",
			detail = (#bad == 0 and "within 12% of the fake game: " or ("fail: " .. #bad .. " of " .. #FONT_SIZES .. " sizes off by more than 12% (or not two lines): ")) .. table.concat(parts, "; ") }
	end
	return out
end

screen({ id = "a_font", side = "rider", title = "Font: the files load, the game draws Wuber's widths, digits line up, every label is on the size scale",
	run = function(W, view)
		pcall(L.AutoFontWarm, W)
		return runOf("home")(W, view)
	end,
	verify = function(W) return L.AutoFontCheck(W) end })


---------------------------------------------------------------------------
-- Design round 4 (job 136): the portal's turn, the hidden tabs, Wuber's own tip card, the World view's shape
--   a_portal   the Ride page's portal is the still picture portal_still, loaded, turned anticlockwise by the game, one turn in
--              8 s (read twice, 1 s apart); with Reduce motion on it does not move (the setting is put back)
--   a_tabs     on the live ride page UI.TabsHidden() is true and the tab bar is not on screen; the back chevron leads Home
--              with the tabs; the ride page is put back (the pill)
--   a_tip      T.TipShow on a visible Wuber button: WuberTip shows, alpha 1, clear of its owner, on the screen, GameTooltip
--              not shown; hidden again
--   a_world    the World view's two continent boxes: width, height, "tall" (answers the open note REC-G07; never fails)
-- No step id. Each also runs in Wuber's fake game (test/autocheck_test.lua). Not part of any of these: the look of the turn
-- (smooth or not), which only a person can judge: the Lab bar's "Portal turn" button (L.PortalTurn) holds it up for 12 s.
---------------------------------------------------------------------------

local TWO_PI = 2 * math.pi
local function clock() return L.Now() end
local function vis(f)
	if type(f) ~= "table" or not fn(f, "IsVisible") then return false end
	local ok, v = pcall(f.IsVisible, f)
	return ok and v == true
end
local function uiState(W) return type(W.UI) == "table" and type(W.UI.state) == "table" and W.UI.state or nil end
local function foundScreen(W)
	local st = uiState(W)
	return st and type(st.screens) == "table" and type(st.screens.found) == "table" and st.screens.found or nil
end
local function rotOf(tex) return edge(tex, "GetRotation") end

-- one rectangle in the screen's own units (the frame's size times its effective scale over UIParent's): { l, b, r, t } or nil
local function srect(f)
	local es = edge(f, "GetEffectiveScale") or 1
	local up = edge(rawget(_G, "UIParent"), "GetEffectiveScale") or 1
	local l, b, w, h = edge(f, "GetLeft"), edge(f, "GetBottom"), edge(f, "GetWidth"), edge(f, "GetHeight")
	if not (l and b and w and h) or up <= 0 then return nil end
	local k = es / up
	return { l = l * k, b = b * k, r = (l + w) * k, t = (b + h) * k }
end

-- a file's loaded-ness, as far as the game can say: Texture:IsObjectLoaded, else a file id; otherwise nothing (-> "skip")
local function textureLoaded(tex)
	if fn(tex, "IsObjectLoaded") then
		local ok, v = pcall(tex.IsObjectLoaded, tex)
		if ok and v == true then return "pass", "the game says the file is loaded (IsObjectLoaded)" end
		if ok and v == false then return "look", "fail: the game says the file is not loaded (IsObjectLoaded false): the green missing-texture square" end
	end
	if fn(tex, "GetTextureFileID") then
		local ok, id = pcall(tex.GetTextureFileID, tex)
		id = ok and num(id) or nil
		if id and id ~= 0 then return "pass", "the game gave it file id " .. id end
	end
	return "skip", "this game cannot say whether a loose file loaded (no IsObjectLoaded, no file id): the screenshot shows it"
end

---------------------------------------------------------------------------
-- The portal
---------------------------------------------------------------------------

local PORTAL_SECS = 8
local function portalArt(W)
	local s = foundScreen(W)
	local h = s and s.hero
	return type(h) == "table" and type(h.art) == "table" and h.art or nil
end
-- the setting put back, always (also when the screen ran out of time)
local function portalPut(W, p)
	if p and p.changed and type(W.db) == "table" then
		W.db.reduceMotion = p.old
		p.changed = false
	end
end
-- the screen's ready(): the four readings, one after the other, polled every 0.15 s (the clock decides, not the polls)
local function portalReady(W)
	local p = data().portal
	if not p or p.phase == 4 then return true end
	local t = clock()
	local art = portalArt(W)
	if p.phase == 0 then
		if not art or not fn(art, "GetRotation") then
			p.noArt, p.phase = not art, 4
			p.noRot = art ~= nil
			return true
		end
		p.old = type(W.db) == "table" and W.db.reduceMotion or nil
		p.wasOn = p.old and true or false
		p.a0, p.t0, p.phase = rotOf(art), t, 1
		return false
	elseif p.phase == 1 then
		if t - p.t0 < 1 then return false end
		p.a1, p.t1 = rotOf(art), t
		if type(W.db) == "table" and not p.wasOn then
			W.db.reduceMotion = true
			p.changed = true
		end
		p.t2, p.phase = t, 2
		return false
	elseif p.phase == 2 then
		if t - p.t2 < 0.6 then return false end -- the turn stops within a frame; this is slack
		p.b0, p.tb0, p.phase = rotOf(art), t, 3
		return false
	end
	if t - p.tb0 < 1 then return false end
	p.b1, p.tb1 = rotOf(art), t
	portalPut(W, p)
	p.phase = 4
	return true
end

screen({ id = "a_portal", side = "rider", maxWait = 10,
	title = "Ride page: the portal is the still picture, turned anticlockwise by the game, one turn in 8 s; Reduce motion stops it",
	run = function(W, view)
		data().portal = { phase = 0 }
		return runOf("portal")(W, view)
	end,
	ready = function(W) return portalReady(W) end,
	verify = function(W)
		local p = data().portal
		local out = {}
		if not p then return "skip", "the portal screen did not set up" end
		if p.phase ~= 4 then portalPut(W, p) end
		local art = portalArt(W)
		if not art then return "skip", "this Wuber's Ride page has no portal picture (s.hero.art)" end
		local path = str(art.GetTextureFilePath and art:GetTextureFilePath() or art.GetTexture and art:GetTexture())
		local fileId = num(art.GetTextureFilePath and art:GetTextureFilePath() or art.GetTexture and art:GetTexture())
		if path and path:find("portal_still", 1, true) then
			out[#out + 1] = { name = "portal file", status = "pass", detail = "the portal's picture is " .. path }
		elseif fileId and fileId ~= 0 then
			-- the game gives a file id number, not the path: any non-zero id is a picture that is set
			out[#out + 1] = { name = "portal file", status = "pass", detail = "the portal's picture is file id " .. fileId }
		else
			out[#out + 1] = { name = "portal file", status = "look", detail = "fail: the portal's picture is " .. tostring(path) .. ", not portal_still" }
		end
		local st, why = textureLoaded(art)
		local w, h = edge(art, "GetWidth"), edge(art, "GetHeight")
		if st == "pass" and not (vis(art) and w and w > 0 and h and h > 0) then
			st, why = "look", "fail: the file loaded but the picture is not drawn (shown " .. tostring(vis(art)) .. ", " .. tostring(w) .. " x " .. tostring(h) .. ")"
		elseif st == "pass" then
			why = why .. "; drawn " .. ("%.0f x %.0f"):format(w, h)
		end
		out[#out + 1] = { name = "portal loaded", status = st, detail = why }
		if p.noRot or not (p.a0 and p.a1) then
			out[#out + 1] = { name = "portal turn", status = "skip", detail = "this game has no Texture:GetRotation (or gave no angle): the turn cannot be read" }
		elseif p.wasOn then
			out[#out + 1] = { name = "portal turn", status = "skip", detail = "Reduce motion was already on, so the turn cannot be measured; run it again with Reduce motion off" }
		else
			local dt = (p.t1 or 0) - (p.t0 or 0)
			local want = TWO_PI / PORTAL_SECS
			local fwd, back = ((p.a1 - p.a0) % TWO_PI) / dt, ((p.a0 - p.a1) % TWO_PI) / dt
			local words = ("%.3f rad in %.2f s (angles %.3f, %.3f), wanted %.3f rad per second plus or minus 30%% (one turn in %d s, anticlockwise)"):format(
				(p.a1 - p.a0) % TWO_PI, dt, p.a0, p.a1, want, PORTAL_SECS)
			if dt > 0 and math.abs(fwd - want) <= 0.3 * want then
				out[#out + 1] = { name = "portal turn", status = "pass", detail = ("turned %.3f rad per second anticlockwise: %s"):format(fwd, words) }
			elseif dt > 0 and math.abs(back - want) <= 0.3 * want then
				out[#out + 1] = { name = "portal turn", status = "look", detail = "fail: it turns clockwise, " .. words }
			else
				out[#out + 1] = { name = "portal turn", status = "look", detail = ("fail: it turns %.3f rad per second, %s"):format(fwd, words) }
			end
		end
		if not (p.b0 and p.b1) then
			out[#out + 1] = { name = "portal reduce motion", status = "skip", detail = "no angle read with Reduce motion on" }
		else
			local moved = math.abs(((p.b1 - p.b0 + math.pi) % TWO_PI) - math.pi)
			local dt = (p.tb1 or 0) - (p.tb0 or 0)
			local words = ("moved %.4f rad in %.2f s (angles %.3f, %.3f) with Reduce motion on%s"):format(moved, dt, p.b0, p.b1, p.wasOn and " (it was on already)" or ", the setting put back")
			out[#out + 1] = { name = "portal reduce motion", status = moved < 0.02 and "pass" or "look", detail = (moved < 0.02 and "stood still: " or "fail: it still turns: ") .. words }
		end
		return out
	end })

---------------------------------------------------------------------------
-- The tab bar on the live ride page
---------------------------------------------------------------------------

local function tabsFacts(W)
	local st, UI = uiState(W), W.UI
	local bar = st and st.tabbar
	local n, total = 0, 0
	for _, tab in ipairs(st and type(st.tabs) == "table" and st.tabs or {}) do
		total = total + 1
		if vis(tab.button) then n = n + 1 end
	end
	local okH, hidden = false, nil
	if fn(UI, "TabsHidden") then okH, hidden = pcall(UI.TabsHidden) end
	if not okH then hidden = nil end
	return { screen = st and st.screen, hidden = hidden, bar = vis(bar), alpha = edge(bar, "GetAlpha"), buttons = n, total = total }
end
local function tabsWords(f)
	return ("screen %s, UI.TabsHidden() %s, tab bar %s (alpha %s), %d of %d tab buttons visible"):format(tostring(f.screen), tostring(f.hidden),
		f.bar and "on screen" or "not on screen", f.alpha and ("%.2f"):format(f.alpha) or "?", f.buttons, f.total)
end

screen({ id = "a_tabs", side = "rider", maxWait = 5,
	title = "Ride page: no tab bar while the live ride shows; the back chevron leads Home with the tabs; the ride page is put back",
	run = function(W, view)
		data().tabs = {}
		return runOf("portal")(W, view)
	end,
	post = function(W)
		local d = data().tabs
		local s = foundScreen(W)
		if not d then return "the tabs screen did not set up" end
		if not (s and fn(W.UI, "TabsHidden")) then d.noApi = true return true end
		d.before = tabsFacts(W)
		if type(s.back) ~= "table" then d.noBack = true return true end
		d.pressed, d.err = X.press(s.back)
		d.at = clock()
		return true
	end,
	-- after the click: 0.6 s for the bar's slide (0.28 s); read Home; press the pill (the way back in); 0.6 s; read the page
	ready = function(W)
		local d = data().tabs
		if not d or not d.at or d.done then return true end
		local t = clock()
		if not d.pillAt then
			if t - d.at < 0.6 then return false end
			d.after = tabsFacts(W)
			local st = uiState(W)
			local pill = st and type(st.phone) == "table" and st.phone.island
			if type(pill) == "table" then d.pilled = X.press(pill) end
			d.pillAt = t
			return false
		end
		if t - d.pillAt < 0.6 then return false end
		d.back = tabsFacts(W)
		d.done = true
		return true
	end,
	verify = function(W)
		local d = data().tabs
		if not d then return "skip", "the tabs screen did not set up" end
		if d.noApi then return "skip", "this Wuber has no UI.TabsHidden or no ride page (older than 2.4)" end
		if d.noBack then return "skip", "the ride page has no back chevron (s.back)" end
		local out = {}
		local b = d.before
		if b.hidden == true and not b.bar and b.buttons == 0 then
			out[#out + 1] = { name = "tabs hidden on the ride page", status = "pass", detail = tabsWords(b) }
		else
			out[#out + 1] = { name = "tabs hidden on the ride page", status = "look", detail = "fail: " .. tabsWords(b) }
		end
		local a = d.after or tabsFacts(W)
		if not d.pressed then
			out[#out + 1] = { name = "back chevron", status = "look", detail = "fail: the back chevron's click broke: " .. tostring(d.err) }
		elseif a.screen == "home" and a.bar and a.hidden == false and (a.alpha or 1) > 0.9 and a.buttons == a.total then
			out[#out + 1] = { name = "back chevron", status = "pass", detail = "Home with the tabs after the click: " .. tabsWords(a) }
		else
			out[#out + 1] = { name = "back chevron", status = "look", detail = "fail: after the click, " .. tabsWords(a) }
		end
		-- the ride page back: the black pill in the window's header leads in again
		if d.pilled ~= nil and d.back then
			local good = d.pilled and d.back.screen == "found" and d.back.hidden == true
			out[#out + 1] = { name = "ride page back", status = good and "pass" or "look",
				detail = (good and "" or "fail: ") .. ("the pill pressed (%s): %s"):format(d.pilled and "ok" or "broke", tabsWords(d.back)) }
		else
			out[#out + 1] = { name = "ride page back", status = "skip", detail = "the window has no pill (phone.island) to press" }
		end
		return out
	end })

---------------------------------------------------------------------------
-- Wuber's own tip card
---------------------------------------------------------------------------

local function tipOwner(W)
	local st = uiState(W)
	if not st then return nil end
	local list = { st.gear }
	for _, tab in ipairs(type(st.tabs) == "table" and st.tabs or {}) do list[#list + 1] = tab.button end
	for _, f in ipairs(list) do
		if type(f) == "table" and vis(f) and (edge(f, "GetWidth") or 0) >= 8 and (edge(f, "GetHeight") or 0) >= 8 then return f end
	end
	return nil
end

-- The card is shown and read in the screen's ready() (before the looks, whose tooltip pass opens and closes every tooltip, this one
-- among them), then put away; verify only reports what was read.
-- the game's tooltip: every call that would draw a tip on it counted while the card shows (the fake game copies the card into the
-- game tooltip's state, so IsShown alone cannot tell; no method of the game tooltip's own is called by that copy)
local GT_DRAW = { "SetOwner", "AddLine", "AddDoubleLine", "SetText", "Show", "SetUnit", "SetHyperlink" }
local function gtWatch(d)
	local gt = rawget(_G, "GameTooltip")
	d.calls, d.saved = {}, {}
	if type(gt) ~= "table" then return end
	for _, name in ipairs(GT_DRAW) do
		if type(gt[name]) == "function" then
			d.saved[name] = { rawget(gt, name) }
			local real = gt[name]
			rawset(gt, name, function(...)
				d.calls[#d.calls + 1] = name
				return real(...)
			end)
		end
	end
end
local function gtUnwatch(d)
	local gt = rawget(_G, "GameTooltip")
	if type(gt) ~= "table" then return end
	for name, had in pairs(d.saved or {}) do rawset(gt, name, had[1]) end
	d.saved = nil
end

local function tipRead(W, d)
	local T = W.Theme
	local out = {}
	local card = rawget(_G, "WuberTip")
	local owner = d.owner
	if type(card) ~= "table" or not vis(card) then
		d.fail = "after T.TipShow the card WuberTip is " .. (type(card) == "table" and "not shown" or "not there")
		return
	end
	d.title = str(card.title and card.title.GetText and card.title:GetText()) or "?"
	d.alpha = edge(card, "GetAlpha")
	d.c, d.o = srect(card), srect(owner)
	local up = rawget(_G, "UIParent")
	d.sw, d.sh = edge(up, "GetWidth"), edge(up, "GetHeight")
	gtUnwatch(d)
	d.game = #d.calls > 0
	d.gameWords = table.concat(d.calls, ", ")
	pcall(T.TipHide, owner)
	d.hidden = not vis(card) and (not fn(T, "TipOwner") or T.TipOwner() == nil)
end

screen({ id = "a_tip", side = "rider", maxWait = 6,
	title = "Wuber's own tip card: T.TipShow on a Wuber button shows WuberTip, whole, beside the button, on the screen; the game's tooltip is not used",
	run = function(W, view)
		data().tip = { phase = 0 }
		return runOf("home")(W, view)
	end,
	ready = function(W)
		local d = data().tip
		if not d or d.phase == 2 then return true end
		local T = W.Theme
		if d.phase == 0 then
			d.calls = {}
			if not fn(T, "TipShow") then d.old, d.phase = true, 2 return true end
			local owner = tipOwner(W)
			if not owner then d.noOwner, d.phase = true, 2 return true end
			L.Tip.hide()
			local gt = rawget(_G, "GameTooltip")
			if type(gt) == "table" then pcall(gt.Hide, gt) end
			d.owner = owner
			gtWatch(d)
			local ok, card = pcall(T.TipShow, owner, "Lab tip check", { "One plain line, to look at." })
			d.ok = ok
			if not ok then gtUnwatch(d) d.err, d.phase = card, 2 return true end
			d.at, d.phase = clock(), 1
			return false
		end
		if clock() - d.at < 0.4 then return false end -- the fade is 0.12 to 0.16 s
		if not pcall(tipRead, W, d) then gtUnwatch(d) end
		d.phase = 2
		L.Tip.hide()
		return true
	end,
	verify = function(W)
		local d = data().tip
		if not d then return "skip", "the tip screen did not set up" end
		if d.old then return "skip", "this Wuber has no T.TipShow (older than 2.4): its tips are on the game's tooltip" end
		if d.noOwner then return "skip", "no visible Wuber button to point at" end
		if d.ok == false then return "look", "fail: T.TipShow broke: " .. tostring(d.err) end
		if d.fail then return "look", "fail: " .. d.fail end
		if d.phase ~= 2 or not d.title then gtUnwatch(d) L.Tip.hide() return "look", "fail: the card was not read in time" end
		local out = {}
		out[#out + 1] = { name = "tip card shows", status = "pass", detail = "WuberTip shows: " .. d.title }
		local alpha = d.alpha
		out[#out + 1] = { name = "tip alpha", status = (alpha and alpha >= 0.999) and "pass" or "look",
			detail = (alpha and alpha >= 0.999 and "alpha 1: " or "fail: alpha ") .. (alpha and ("%.3f"):format(alpha) or "?") .. " after the fade" }
		local c, o = d.c, d.o
		if c and o then
			local ow = math.min(c.r, o.r) - math.max(c.l, o.l)
			local oh = math.min(c.t, o.t) - math.max(c.b, o.b)
			local over = ow > 0.5 and oh > 0.5
			out[#out + 1] = { name = "tip beside its owner", status = over and "look" or "pass",
				detail = (over and ("fail: the card lies on its button by %.0f x %.0f; "):format(ow, oh) or "no overlap; ") ..
					("card %.0f..%.0f x %.0f..%.0f, button %.0f..%.0f x %.0f..%.0f"):format(c.l, c.r, c.b, c.t, o.l, o.r, o.b, o.t) }
			if d.sw and d.sh then
				local on = c.l >= -0.5 and c.b >= -0.5 and c.r <= d.sw + 0.5 and c.t <= d.sh + 0.5
				out[#out + 1] = { name = "tip on screen", status = on and "pass" or "look",
					detail = (on and "" or "fail: off the screen; ") .. ("card %.0f..%.0f x %.0f..%.0f on a %.0f x %.0f screen"):format(c.l, c.r, c.b, c.t, d.sw, d.sh) }
			end
		else
			out[#out + 1] = { name = "tip beside its owner", status = "skip", detail = "the game gave no rectangle for the card or the button" }
		end
		out[#out + 1] = { name = "game tooltip unused", status = d.game and "look" or "pass",
			detail = d.game and ("fail: Wuber drew on GameTooltip as well (" .. tostring(d.gameWords) .. ")") or "no call on GameTooltip: Wuber's card is the only tip" }
		out[#out + 1] = { name = "tip hides", status = d.hidden and "pass" or "look",
			detail = d.hidden and "T.TipHide put the card away" or "fail: after T.TipHide the card still shows or has an owner" }
		return out
	end })

---------------------------------------------------------------------------
-- The World view's shape (open fake-game note REC-G07: the real game's continents are tall; one screenshot said so)
---------------------------------------------------------------------------

screen({ id = "a_world", side = "rider", only = "unfolded",
	title = "World view: the two continent boxes' width and height, tall or not (answers REC-G07; only reports)",
	run = runOf("worldmap"),
	post = function(W)
		local s = tourScreen("worldmap")
		if s and type(s.post) == "function" then return s.post(W) end
		return "the tour has no worldmap screen"
	end,
	verify = function(W)
		local WM = P.mod(W, "UI.Rider.WorldMap")
		if not (WM and fn(WM, "Box")) then return "skip", "this Wuber's World view has no Box(cont)" end
		local function box(name, cont)
			local ok, x, y, w, h = pcall(WM.Box, cont)
			w, h = ok and num(w) or nil, ok and num(h) or nil
			if not (w and h) then return nil, name .. " has no box" end
			return { x = num(x), y = num(y), w = w, h = h }, ("%s %.0f x %.0f (%s)"):format(name, w, h, h > w and "tall" or "not tall")
		end
		local k, kw = box("Kalimdor", 1)
		local e, ew = box("Eastern Kingdoms", 0)
		local probe = fn(WM, "Probe") and select(2, pcall(WM.Probe)) or nil
		local area = type(WM.WM) == "table" and type(WM.WM.AREA) == "table" and WM.WM.AREA or nil
		local words = (kw or "?") .. "; " .. (ew or "?") .. "; art " .. tostring(probe)
		if k and e and area and num(area.w) and num(area.h) then
			local top, bottom = math.min(k.y or 0, e.y or 0), math.max((k.y or 0) + k.h, (e.y or 0) + e.h)
			words = words .. ("; together %.0f%% of the pane's width and %.0f%% of its height"):format(100 * (k.w + e.w) / area.w, 100 * (bottom - top) / area.h)
		end
		return "info", words .. (k and e and (k.h > k.w and e.h > e.w and ": both tall" or ": not both tall") or "")
	end })

---------------------------------------------------------------------------
-- The one thing only a person can judge: does the portal turn smoothly? (the Lab bar's "Portal turn", /lab portal)
-- It is a tour of one screen that waits 12 s, so Wuber stays up on the Ride page's portal; then the tour puts everything back.
-- No Auto check results are written (the last Auto check's stay as they are).
---------------------------------------------------------------------------

L.PORTAL_HOLD = 12
local portalTurnScreen = { id = "portal_turn", side = "rider", wait = L.PORTAL_HOLD, maxWait = L.PORTAL_HOLD + 1,
	title = "Portal turn: the Ride page's portal, held up for 12 seconds",
	run = runOf("portal") }
function L.PortalTurn()
	if L.Touring and L.Touring() then
		L.Say("Portal turn: the photo tour or Auto check is running (/lab tour stop)")
		return false
	end
	local ok, why = L.TourStart({ screens = { portalTurnScreen }, subset = "portal turn" })
	if ok then L.Say(("Portal turn: Wuber shows the ride's portal for %d seconds. Watch it turn; then everything goes back by itself."):format(L.PORTAL_HOLD)) end
	return ok, why
end

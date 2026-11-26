-- Wuber Lab tests: the developer-only test mode (lab/WuberLab), loaded on
-- top of Wuber (and Ritual Rides) in the harness. Loaded by run.lua with its helpers; skipped
-- with one passing note when the lab isn't there. Wuber Lab is never shipped.

local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, settle, clean, rideState, requestVia = T.newWorld, T.settle, T.clean, T.rideState, T.requestVia
local HAVE_UI, HAVE_RR = T.HAVE_UI, T.HAVE_RR

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/WuberLab.toc") then
	test("lab: Wuber Lab not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local ANITA, FARRA, HAYLEY, ROCKS = "Anita Lift", "Farra Way", "Hayley Cab", "Wuber Rocks"

local function labOf(c) return c.ns.WuberLab end

local function lines(c, name)
	local db = c.env.WuberLabDB
	local ch = db and db.chars and db.chars[name or c.player.name]
	return ch and ch.lines or {}
end

-- lines of a kind (and matching a plain text, if given)
local function find(c, kind, textPart)
	local out = {}
	for _, l in ipairs(lines(c)) do
		local k, rest = l:match("^[%d%.]+|[^|]*|([^|]*)|(.*)$")
		if k == kind and (not textPart or rest:find(textPart, 1, true)) then out[#out + 1] = rest end
	end
	return out
end

local function checked(c, id)
	local L = labOf(c)
	local rec = L.Result(id)
	return rec and rec.r or nil
end

-- WoW's SavedVariables format (for a sample the report tool's test reads): LAB_DUMP=<dir>
local function serialize(v, indent, out)
	local t = type(v)
	if t == "string" then
		out[#out + 1] = string.format("%q", v):gsub("\\\n", "\\n")
	elseif t == "number" or t == "boolean" then
		out[#out + 1] = tostring(v)
	elseif t == "table" then
		out[#out + 1] = "{\n"
		local n = #v
		for i = 1, n do
			out[#out + 1] = indent .. "\t"
			serialize(v[i], indent .. "\t", out)
			out[#out + 1] = ", -- [" .. i .. "]\n"
		end
		local keys = {}
		for k in pairs(v) do
			if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then keys[#keys + 1] = k end
		end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, k in ipairs(keys) do
			out[#out + 1] = indent .. "\t[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "] = "
			serialize(v[k], indent .. "\t", out)
			out[#out + 1] = ",\n"
		end
		out[#out + 1] = indent .. "}"
	else
		out[#out + 1] = "nil"
	end
end

local function dumpSaved(c, account, dir)
	dir = dir or os.getenv("LAB_DUMP")
	if not dir or not c.env.WuberLabDB then return end
	local path = dir .. "/WTF/Account/" .. account .. "/SavedVariables"
	os.execute('mkdir -p "' .. path .. '"')
	local out = { "\n" }
	out[#out + 1] = "WuberLabDB = "
	serialize(c.env.WuberLabDB, "", out)
	out[#out + 1] = "\n"
	local f = assert(io.open(path .. "/WuberLab.lua", "wb"))
	f:write(table.concat(out))
	f:close()
end

local function labRider(w, opts)
	opts = opts or {}
	return w:addClient(opts.name or ROCKS, { spot = opts.spot or "Orgrimmar", class = "MAGE", money = opts.money or 100000,
		addons = opts.addons or { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI, prepare = opts.prepare, saved = opts.saved })
end

local function labTeam(w)
	local cs = {}
	for i, n in ipairs({ ANITA, FARRA, HAYLEY }) do
		cs[i] = w:addClient(n, { spot = "Ratchet", class = "WARLOCK", addons = { "Wuber", "RitualRides", "WuberLab" }, allowMissing = not HAVE_UI })
	end
	w:group({ ANITA, FARRA, HAYLEY })
	w:advance(1)
	for _, c in ipairs(cs) do c:slash("/rr team") end
	w:advance(1)
	cs[1]:slash("/rr on")
	return cs
end

---------------------------------------------------------------------------

test("lab: loads and logs with neither Wuber nor Ritual Rides", function()
	local w = newWorld()
	local c = w:addClient(ROCKS, { spot = "Orgrimmar", class = "MAGE", money = 5000, addons = { "WuberLab" }, allowMissing = true })
	local L = labOf(c)
	ok(L and L.Log, "the lab loaded")
	w:advance(10)
	ok(#find(c, "login", "char=Wuber Rocks") == 1, "login line: " .. list(lines(c), "\n"))
	ok(#find(c, "login", "Wuber=off") == 1, "Wuber shown as not loaded")
	eq(L.Role(), "rider", "role by name")
	-- game events still logged
	c:fire("PARTY_INVITE_REQUEST", "Anita")
	c:fire("CHAT_MSG_WHISPER", "WTB summon to Ratchet", "Bob Stone")
	c:fire("CHAT_MSG_SYSTEM", "No player named 'Bob Stone' is currently playing.")
	c:fire("ADDON_ACTION_BLOCKED", "Wuber", "AcceptTrade()")
	w:advance(1)
	ok(#find(c, "ev", "inviter='Anita'") == 1, "raw inviter name logged")
	ok(#find(c, "probe", "invite 0.6s later") == 1, "invite probe")
	ok(#find(c, "whsp", "WTB summon") == 1, "whisper logged")
	ok(#find(c, "sys", "No player named") == 1, "system line")
	ok(#find(c, "block", "AcceptTrade") == 1, "blocked action")
	-- every tool says no without Wuber, and nothing breaks
	for _, line in ipairs({ "/lab", "/lab fakes on", "/lab fx", "/lab check", "/lab mark hello there", "/lab book cheap", "/lab role driver", "/lab", "/lab nonsense" }) do
		c:slash(line)
	end
	eq(L.FreshRiderNow(), false, "no fresh rider without Wuber")
	eq(L.fakesOn, false, "no fakes without Wuber")
	ok(#find(c, "mark", "hello there") == 1, "mark line")
	eq(L.Role(), "driver", "role override")
	ok(#find(c, "laberr") == 0, "no lab faults: " .. list(find(c, "laberr"), "\n"))
	clean(w)
end)

test("lab: Wuber without Ritual Rides, panel, tabs, pass/fail and notes", function()
	local w = newWorld()
	local c = labRider(w)
	local L = labOf(c)
	settle(w)
	c:slash("/lab")
	local panel = c.env.WuberLabPanel
	ok(panel and panel:IsShown(), "panel shown")
	w:advance(1)
	-- the first tab is Basics; click Pass on the first row, Fail on the second with a note
	local P = L.panel
	eq(P.tab, "Plan", "the plan is the first tab")
	for _, t in ipairs(P.tabs) do if t.name == "Basics" then c:clickOn(t) end end
	w:advance(0.6)
	eq(P.tab, "Basics")
	c:clickOn(P.rows[3].pass)
	eq(checked(c, "r_tips"), "pass", "Pass by hand")
	c:clickOn(P.rows[4].fail)
	eq(checked(c, "r_slider"), "fail", "Fail by hand")
	eq(P.selected, "r_slider", "Fail selects the row for a note")
	c:type(P.note, "knob sticks at 10g")
	eq(L.Result("r_slider").note, "knob sticks at 10g", "note kept")
	ok(#find(c, "check", "r_slider;fail") == 1, "fail logged")
	-- tabs
	for _, t in ipairs(P.tabs) do
		c:clickOn(t)
		w:advance(0.6)
		eq(P.tab, t.name, "tab " .. t.name)
	end
	ok(P.tools:IsShown() == false, "Log tab hides tools")
	-- the app opening ticks r_open; Check my game ticks r_check
	if HAVE_UI then
		c.W.UI.Toggle(true)
		w:advance(2)
		eq(checked(c, "r_open"), "auto", "app open ticked")
	end
	c.W.SelfTest()
	eq(checked(c, "r_check"), "auto", "Check my game ticked")
	-- the Tools tab: every button, then the effects one by one
	for _, t in ipairs(P.tabs) do if t.name == "Tools" then c:clickOn(t) end end
	w:advance(0.6)
	c:clickOn(P.toolButtons.checks)
	ok(#find(c, "self", "[Run checks]") == 1, "Run checks logged")
	c:clickOn(P.toolButtons.fakes)
	eq(L.fakesOn, true, "fakes on from the button")
	c:clickOn(P.toolButtons.fakes)
	eq(L.fakesOn, false, "and off")
	c:type(P.note, "before effects")
	ok(#find(c, "mark", "before effects") == 1, "Enter in the box on Tools marks")
	c:clickOn(P.toolButtons.role)
	eq(L.Role(), "rider", "role set by hand")
	c:clickOn(P.toolButtons.role)
	eq(L.Role(), "driver")
	c:slash("/lab role auto")
	eq(L.Role(), "rider")
	c:clickOn(P.toolButtons.fx)
	w:advance(45)
	ok(#find(c, "fx", "done") == 1, "every effect played: " .. list(find(c, "fx"), " / "))
	ok(#find(c, "fx", "portal_open -> shown") == 1, "portal shown")
	ok(#find(c, "fx", "crown -> shown") == 1, "crown shown")
	ok(#find(c, "fx", "badge_skull -> shown") == 1, "badges shown")
	c:clickOn(P.toolButtons.fx)
	w:advance(45)
	eq(#find(c, "fx", "done"), 2, "a second run reuses the crown and badges")
	c:pressEscape()
	ok(not panel:IsShown(), "Esc closes the panel")
	-- login self-test stored after 8 s
	local ch = c.env.WuberLabDB.chars[ROCKS]
	ok(ch.selftest and #ch.selftest.list > 0, "self-test stored")
	ok(#find(c, "self", "[login]") == 1, "login self-test logged")
	ok(#find(c, "probe", "font Poppins") == 1, "font probe")
	ok(#find(c, "laberr") == 0, "no lab faults: " .. list(find(c, "laberr"), "\n"))
	-- the lab's only globals
	local allowed = { WuberLab = true, WuberLabDB = true, SLASH_WUBERLAB1 = true, SLASH_WUBERLAB2 = true,
		BINDING_HEADER_WUBERLAB = true, BINDING_NAME_WUBERLAB_HUH = true }
	for k, who in pairs(c.globalWrites) do
		if tostring(who):find("WuberLab/", 1, true) then
			ok(allowed[k] or tostring(k):match("^WuberLab"), "stray global " .. tostring(k) .. " from " .. tostring(who))
		end
	end
	clean(w)
end)

test("lab: fake drivers stay inside the rider's window and answer locally", function()
	if not HAVE_UI then error("needs the UI") end
	local w = newWorld()
	local r = labRider(w)
	local L = labOf(r)
	settle(w)
	local sentBefore = #w.addonLog
	r:slash("/lab fakes on")
	w:advance(1)
	local n = 0
	for k in pairs(r.W.drivers) do if k:match(" labfake$") then n = n + 1 end end
	eq(n, 5, "five fakes listed")
	ok(r.W.drivers["spam labfake"].serviceRefused, "spammy service refused by Wuber's filter")
	eq(checked(r, "r_spam"), "auto", "spam step ticked")
	eq(r.W.drivers["busy labfake"].state, "busy")
	-- the real Request button: no macro (so no whisper), the lab books it locally
	requestVia(r, "cheap labfake")
	w:advance(0.5)
	eq(rideState(r), "requesting", "booked through the button")
	w:advance(2)
	eq(rideState(r), "accepted", "the fake accepts")
	w:advance(2)
	eq(r.W.ride.position, 2, "queue position")
	w:advance(12)
	eq(rideState(r), "declined", "then declines")
	eq(checked(r, "r_decline"), "auto", "decline step")
	eq(checked(r, "r_accepted"), nil, "a fake doesn't tick the real ride steps")
	eq(checked(r, "r_booked"), nil, "a fake doesn't tick booking")
	r.W.ClearRide()
	-- no answer -> timeout (with Wuber's own resend, also kept local)
	ok(L.BookFake("spam"), "booked spam")
	w:advance(45)
	eq(rideState(r), "timeout", "timed out")
	eq(checked(r, "r_timeout"), "auto")
	r.W.ClearRide()
	-- busy: queue 3, 2, 1, then declined; cancel on another
	ok(L.BookFake("busy"))
	w:advance(9)
	eq(r.W.ride.position, 2, "busy fake queue")
	ok(r.W.CancelRide(), "cancel")
	r.W.ClearRide()
	-- hide and favourite a fake: purged when fakes are cleared
	r.W.HideDriver("mid labfake", true)
	r.W.ToggleFav("dear labfake")
	ok(r.W.db.hidden["mid labfake"], "hidden")
	eq(checked(r, "r_hide"), "auto")
	r:slash("/lab fakes off")
	w:advance(1)
	for k in pairs(r.W.drivers) do ok(not k:match("labfake"), "fake left: " .. k) end
	ok(not r.W.db.hidden["mid labfake"] and not r.W.db.favs["dear labfake"], "purged from saved settings")
	-- nothing ever left the window for a fake
	for i = sentBefore + 1, #w.addonLog do
		local e = w.addonLog[i]
		ok(not tostring(e.target):lower():find("labfake"), "addon message to a fake: " .. tostring(e.target))
		ok(not tostring(e.text):lower():find("labfake"), "fake in a message: " .. e.text)
	end
	for _, m in ipairs(w.macros) do ok(not m.text:lower():find("labfake"), "macro to a fake: " .. m.text) end
	for _, x in ipairs(w.whispers) do ok(not x.to:lower():find("labfake"), "whisper to a fake") end
	eq(w.failedWhispers, nil, "no whisper to a missing player")
	ok(#find(r, "fake", "kept local: R") >= 3, "requests kept local")
	ok(#find(r, "err") == 0, "no FAKE LEAK or errors: " .. list(find(r, "err"), "\n"))
	ok(#find(r, "laberr") == 0, "no lab faults: " .. list(find(r, "laberr"), "\n"))
	clean(w)
end)

test("lab: fresh rider and restore round-trip the history", function()
	local w = newWorld()
	local r = labRider(w)
	local L = labOf(r)
	settle(w)
	local W = r.W
	for i = 1, 4 do
		W.AddTrip({ at = 1763400000 + i * 3600, driver = ANITA, driverKey = "anita lift", dest = i % 2 == 0 and "Ratchet" or "Undercity", price = 5000, stars = 5 })
	end
	W.CheckMilestones(true)
	local function snap()
		local out = {}
		for _, k in ipairs({ "rides", "totals", "milestones", "tierSeen" }) do out[k] = L.DeepCopy(W.db[k]) end
		return out
	end
	local function same(a, b, path)
		if type(a) ~= type(b) then error(path .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
		if type(a) ~= "table" then
			if a ~= b then error(path .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
			return
		end
		for k, v in pairs(a) do same(v, b[k], path .. "." .. tostring(k)) end
		for k in pairs(b) do if a[k] == nil then error(path .. "." .. tostring(k) .. " extra") end end
	end
	local before = snap()
	ok(W.db.milestones.first, "has First Ride")
	ok(L.FreshRiderNow(), "fresh rider")
	eq(#W.db.rides, 0, "trips cleared")
	eq(W.db.milestones.first, nil, "milestones cleared")
	eq(W.Stats().rides, 0, "stats cleared")
	eq(W.Tier(), 0, "level cleared")
	local again, why = L.FreshRiderNow()
	eq(again, false, "a second fresh is refused (the backup stays)")
	ok(why:find("Restore"), why)
	-- a test ride earns First Ride again
	W.AddTrip({ at = 1763500000, driver = ANITA, driverKey = "anita lift", dest = "Gadgetzan", price = 5000 })
	local new = W.CheckMilestones()
	ok(#new >= 1 and new[1] == "first" or new[2] == "first", "First Ride earned again: " .. list(new))
	ok(L.RestoreRiderNow(), "restore")
	same(before, snap(), "W.db")
	eq(L.db.riderBackup, nil, "backup gone")
	eq(L.RestoreRiderNow(), false, "nothing to restore twice")
	-- the dialog path (StaticPopup) runs the same
	L.FreshRider()
	local dlg = r.env.StaticPopupDialogs.WUBERLAB_CONFIRM
	ok(dlg and dlg.OnAccept, "confirm dialog")
	dlg.OnAccept()
	eq(#W.db.rides, 0, "cleared through the dialog")
	L.RestoreRider()
	r.env.StaticPopupDialogs.WUBERLAB_CONFIRM.OnAccept()
	same(before, snap(), "W.db after the dialogs")
	ok(#find(r, "laberr") == 0, "no lab faults")
	clean(w)
end)

test("lab: Lua errors are logged and the error handler chain keeps working (and BugGrabber)", function()
	local w = newWorld()
	local handled, current = {}, nil
	local bgCallbacks = {}
	local r = labRider(w, { prepare = function(env)
		local base = function(msg) handled[#handled + 1] = msg return "base" end
		current = base
		env.geterrorhandler = function() return current end
		env.seterrorhandler = function(fn) current = fn end
		env.BugGrabber = { RegisterCallback = function(obj, event, fn) bgCallbacks[#bgCallbacks + 1] = { obj = obj, event = event, fn = fn } end }
	end })
	local L = labOf(r)
	settle(w)
	ok(current == L.errorHandler, "the lab's handler is installed")
	eq(current("boom at line 3"), "base", "the old handler still runs and returns")
	eq(handled[1], "boom at line 3", "the old handler got the error")
	ok(#find(r, "err", "boom at line 3") == 1, "logged")
	eq(#bgCallbacks, 1, "BugGrabber callback registered")
	eq(bgCallbacks[1].event, "BugGrabber_BugGrabbed")
	bgCallbacks[1].fn("BugGrabber_BugGrabbed", { message = "grabbed thing" })
	ok(#find(r, "err", "grabbed thing") == 1, "BugGrabber error logged")
	-- the same error twice within 2 s is logged once
	current("boom at line 3")
	eq(#find(r, "err", "boom at line 3"), 1, "deduplicated")
	-- Wuber's own caught errors
	r.W.Error("test", "caught thing")
	ok(#find(r, "werr", "caught thing") == 1, "W.Error logged")
	r.W.lastError = nil
	ok(#find(r, "login", "errhandler=chained") == 1, "login says chained")
	clean(w)
end)

test("lab: the timeline is capped per character", function()
	local w = newWorld()
	local r = labRider(w)
	local L = labOf(r)
	settle(w)
	for i = 1, L.CAP + 700 do L.Log("mark", "line " .. i) end
	local ls = lines(r)
	ok(#ls <= L.CAP, "at most CAP lines: " .. #ls)
	ok(#ls >= L.CAP - 250, "most kept: " .. #ls)
	ok(ls[#ls]:find("line " .. (L.CAP + 700), 1, true), "newest last")
	ok(r.env.WuberLabDB.chars[ROCKS].dropped > 0, "dropped counted")
	-- lines are "epoch.ms|char|kind|text", no line breaks or pipes in the text
	L.Log("mark", "a|b\nc")
	local last = lines(r)[#lines(r)]
	ok(last:match("^%d+%.%d%d%d|Wuber Rocks|mark|a/b c$"), "format: " .. last)
	clean(w)
end)

test("lab: a /reload keeps the timeline and the checklist, and fake leftovers are purged", function()
	local w = newWorld()
	local r = labRider(w)
	settle(w)
	labOf(r).MarkStep("r_crown", "pass")
	r:slash("/lab fakes on")
	r.W.ToggleFav("cheap labfake")
	local n = #lines(r)
	local r2 = w:reload(r)
	w:advance(10)
	ok(#lines(r2) > n, "timeline kept and growing")
	eq(checked(r2, "r_crown"), "pass", "checklist kept")
	eq(r2.W.db.favs["cheap labfake"], nil, "fake favourite purged")
	for k in pairs(r2.W.drivers) do ok(not k:match("labfake"), "fakes gone after reload") end
	clean(w)
end)

test("lab plan: the data loads, every auto-tick names a signal the lab sends, the Plan tab draws", function()
	local w = newWorld()
	local c = labRider(w)
	local L = labOf(c)
	settle(w)
	eq(#L.PLAN, 9, "nine sections (the 2.3.2 release checklist first, then the 2.2 tests)")
	eq(L.PLAN[1].id, "r232", "the 2.3.2 release checklist is the first section")
	local ids, n = {}, 0
	local src = ""
	for _, f in ipairs({ "Log.lua", "Hooks.lua", "Checklist.lua", "Plan.lua", "Tools.lua" }) do
		local fh = assert(io.open(LAB_DIR .. "/" .. f, "rb"))
		src = src .. fh:read("*a")
		fh:close()
	end
	for _, sec in ipairs(L.PLAN) do
		ok(sec.title and #sec.steps > 0, "section " .. tostring(sec.id))
		for _, s in ipairs(sec.steps) do
			n = n + 1
			ok(not ids[s.id], "unique id " .. s.id)
			ids[s.id] = true
			ok(type(s.text) == "string" and #s.text > 5, "text " .. s.id)
			for _, sg in ipairs(s.sig or {}) do
				ok(src:find('"' .. sg .. '"', 1, true) or sg:match("^fx_") or sg:match("^stage_") or sg:match("^ride_"), "unknown signal " .. sg .. " in " .. s.id)
			end
			for _, sg in ipairs(s.all or {}) do
				ok(src:find('"' .. sg .. '"', 1, true) or sg:match("^fx_") or sg:match("^ride_"), "unknown signal " .. sg .. " in " .. s.id)
			end
			if s.probe then ok(L.PROBES[s.probe], "probe " .. s.probe) end
		end
	end
	ok(n >= 50, "every step of TESTPLAN.md: " .. n)
	ok(L.PLAN_STEP.s1_1.text:find("start4.ps1", 1, true), "the current Windows section")
	eq(#c.env.WuberLabDB.planSteps, n, "step list saved for the report")
	-- the Plan tab: the section with the next step is open, the rest closed
	c:slash("/lab")
	w:advance(1)
	local P = L.panel
	eq(P.tab, "Plan")
	ok(P.expanded[L.PlanNext().sec], "next step's section open")
	local open = 0
	for _ in pairs(P.expanded) do open = open + 1 end
	eq(open, 1, "the rest collapsed")
	-- tick the first step's box; a header click opens another section
	local first
	for _, r in ipairs(P.planRows) do if r.pstep and not first then first = r end end
	ok(first, "a step row drawn")
	local id = first.pstep.id
	c:clickOn(first.tick)
	eq(L.PlanRec(id).r, "pass", "ticked by hand")
	c:clickOn(first.tick)
	eq(L.PlanRec(id).r, nil, "and unticked")
	-- long steps fill the view: collapse the open section, then every header shows
	for _, r in ipairs(P.planRows) do if r.psec and P.expanded[r.psec.id] and r:IsShown() then c:clickOn(r) break end end
	local head
	for _, r in ipairs(P.planRows) do if r.psec and r.psec.id == "s5" and r:IsShown() then head = r end end
	ok(head, "Test 4 header shown")
	c:clickOn(head)
	ok(P.expanded.s5, "Test 4 opened")
	-- a note on the selected plan step
	for _, r in ipairs(P.planRows) do if r.pstep and r.pstep.id == "s5_2" then c:clickOn(r) end end
	eq(P.planSel, "s5_2")
	c:type(P.note, "tooltip says Wuber founder twice")
	eq(L.PlanRec("s5_2").note, "tooltip says Wuber founder twice")
	-- the Now strip's Done ticks the next step
	local nxt = L.PlanNext()
	c:clickOn(P.now.done)
	eq(L.PlanRec(nxt.id).r, "pass", "Done ticks the Now step")
	ok(L.PlanNext() ~= nxt, "Now moved on")
	-- bigger for a 4K screen
	local before = L.Scale()
	c:clickText("A+")
	ok(L.Scale() > before, "A+ scales up")
	c:slash("/lab resetplan")
	c.env.StaticPopupDialogs.WUBERLAB_CONFIRM.OnAccept()
	eq(L.PlanRec(nxt.id), nil, "reset plan")
	ok(#find(c, "laberr") == 0, "no lab faults: " .. list(find(c, "laberr"), "\n"))
	clean(w)
end)

test("lab plan: sync takes only the tester's four characters, last write wins, reset clears", function()
	local w = newWorld()
	local c = labRider(w)
	local L = labOf(c)
	-- (fga B) the Lab's Run module whispers its version to the other windows, offline or not, without the Plan's 5 s hiding
	-- (the lab's own business, the fake now fires the version check); those names are left out of the Plan check below
	local runTo, sam = {}, c.env.C_ChatInfo.SendAddonMessage
	c.env.C_ChatInfo.SendAddonMessage = function(p, tx, ch, tg)
		if type(tx) == "string" and tx:sub(1, 4) == "RUN~" and tg then runTo[tg] = true end
		return sam(p, tx, ch, tg)
	end
	settle(w)
	local now = c.env.time()
	local function U(id, at, r, who, note) return ("U~%s~%.3f~%s~%s~hand~%s"):format(id, at, r, who, note or "") end
	w:inject("Bob Stone", U("s5_1", now + 50, "pass", "Bob Stone"), "WHISPER", c, "WLAB")
	eq(L.PlanRec("s5_1"), nil, "a stranger is ignored")
	w:inject("Anita Lift-Forever", U("s5_1", now + 50, "pass", "Anita Lift", "fine"), "CHANNEL", c, "WLAB")
	eq(L.PlanRec("s5_1"), nil, "not from a channel")
	w:inject("Anita Lift", U("s5_1", now + 50, "pass", "Anita Lift", "looks fine"), "WHISPER", c, "WLAB")
	eq(L.PlanRec("s5_1").r, "pass", "Anita's tick taken")
	eq(L.PlanRec("s5_1").note, "looks fine")
	w:inject("Farra Way", U("s5_1", now + 40, "fail", "Farra Way"), "PARTY", c, "WLAB")
	eq(L.PlanRec("s5_1").r, "pass", "an older write loses")
	w:inject("Farra Way", U("s5_1", now + 60, "fail", "Farra Way", "crown missing"), "PARTY", c, "WLAB")
	eq(L.PlanRec("s5_1").r, "fail", "a newer write wins")
	eq(L.PlanRec("s5_1").who, "Farra Way")
	-- batches
	w:inject("Hayley Cab", ("B~s5_2,%.3f,pass,Hayley Cab,hand~s5_3,%.3f,auto,Hayley Cab,fx"):format(now + 70, now + 70), "WHISPER", c, "WLAB")
	eq(L.PlanRec("s5_2").r, "pass")
	eq(L.PlanRec("s5_3").r, "auto")
	-- a local change later than all of them wins and is sent to the teammates heard from
	w:advance(1)
	L.PlanMark("s5_1", "pass")
	eq(L.PlanRec("s5_1").r, "pass")
	ok((L.PlanRec("s5_1").at or 0) > now + 60, "stamped after the newest")
	w:advance(30)
	local sent = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WLAB" and e.from == ROCKS then sent[#sent + 1] = e end
	end
	ok(#sent > 0, "sent to the teammates")
	for _, e in ipairs(sent) do
		ok(e.chatType == "WHISPER" and ({ [ANITA] = 1, [FARRA] = 1, [HAYLEY] = 1 })[e.target], "only to the team: " .. tostring(e.target))
	end
	-- their "No player named" lines are kept out of chat and the log
	local noisy = {}
	for _, s in ipairs(find(c, "sys", "No player named")) do
		local who = s:match("named '(.-)'")
		if not (who and runTo[who]) then noisy[#noisy + 1] = s end
	end
	ok(#noisy == 0, "own offline whispers not logged: " .. table.concat(noisy, "; "))
	-- reset from a teammate clears everything older
	w:inject("Anita Lift", ("R~%.3f"):format(c.env.time() + 100), "WHISPER", c, "WLAB")
	eq(L.PlanRec("s5_1"), nil, "reset")
	eq(L.PlanRec("s5_2"), nil, "reset")
	ok(#find(c, "plan", "reset;who=Anita Lift;src=sync") == 1, "reset logged")
	clean(w)
end)

test("lab plan: probes, the mini Now strip toggles and is remembered", function()
	local w = newWorld()
	local r = labRider(w, { prepare = function(env) env.GetBindingAction = function(k) return k == "F1" and "" or "JUMP" end end })
	r.cvars.Sound_EnableSoundWhenGameIsInBG = "1"
	local L = labOf(r)
	settle(w)
	eq(L.PlanRec("s0_3").r, "auto", "sound in background on Wuber Rocks ticked")
	eq(L.PlanRec("s0_4@wuber rocks").r, "ok", "F1 unbound here")
	eq(L.PlanRec("s0_4"), nil, "F1 not ticked until all four said so")
	ok(#find(r, "probe", "plan s0_3 (sound) on Wuber Rocks: ok") == 1, "probe logged")
	ok(L.SetMini(true), "mini on")
	local m = r.env.WuberLabMini
	ok(m and m:IsShown(), "mini shown")
	ok(m.now.big:GetText():find(L.PlanNext().text, 1, true), "mini shows the next step")
	local nxt = L.PlanNext()
	r:clickOn(m.now.done)
	eq(L.PlanRec(nxt.id).r, "pass", "Done in the mini strip")
	r:drag(m, 40, -30)
	local r2 = w:reload(r)
	w:advance(12)
	local m2 = r2.env.WuberLabMini
	ok(m2 and m2:IsShown(), "mini remembered after a reload")
	ok(type(r2.env.WuberLabDB.miniPos) == "table", "position remembered")
	r2:slash("/lab mini")
	ok(not m2:IsShown(), "mini off")
	eq(r2.env.WuberLabDB.miniShown, false)
	clean(w)
end)

test("lab: the community is logged as found and used for whisper seeds only (SPEC5: no community transport)", function()
	local w = newWorld({ clubs = true })
	w:addClub({ id = 77, name = "Wuber", members = { [ANITA] = 1, [ROCKS] = 4 } })
	local d = w:addClient(ANITA, { spot = "Ratchet", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local r = w:addClient(ROCKS, { spot = "Orgrimmar", class = "MAGE", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI,
		channelCopy = "realm5" })
	settle(w, 25)
	ok(#find(r, "comm", "found: club 77") == 1, "found logged: " .. list(lines(r), "\n"))
	ok(d.W.Driver.SetOnline(true), "online")
	w:advance(5)
	-- review #7: the community carries no addon messages on Forever, so nothing is sent there
	eq(#find(d, "comm", "first send"), 0, "no community send")
	eq(d.W.community.sent or 0, 0, "nothing sent on the community")
	-- no community: one "not available" line, no errors
	local w2 = newWorld()
	local c = labRider(w2)
	settle(w2, 25)
	ok(#find(c, "comm", "not available (no C_Club)") == 1, "not available logged: " .. list(lines(c), "\n"))
	clean(w)
	clean(w2)
end)

test("lab: adverts are logged (posted with channel and text, tagged lines heard, the sender confirmed)", function()
	local w = newWorld()
	local d = w:addClient("Bob Stone", { spot = "Ratchet", class = "WARLOCK", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local r = w:addClient("Wuber TestCharacter", { spot = "Orgrimmar", class = "MAGE", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	w:splitChannel(d, "other")
	settle(w, 20)
	ok(d.W.Driver.SetOnline(true), "online")
	w:advance(3)
	local plan = d.W.AdvertPlan("Ratchet", 5000)
	ok(plan, "a plan")
	d.W.AdvertPosted(plan) -- (the click itself is tested in discovery.lua)
	ok(#find(d, "advert", "posted in Trade: [Wuber] Selling summons to Ratchet, 50s") == 1, "posted logged: " .. list(lines(d), "\n"))
	w:chatFrom("Bob Stone", plan.text, "CHANNEL", "Trade")
	w:advance(8)
	ok(#find(r, "advert", "heard from Bob Stone in Trade: [Wuber]") == 1, "heard logged")
	ok(#find(r, "advert", "confirmed Bob Stone") == 1, "confirmed logged: " .. list(find(r, "advert"), "\n"))
	clean(w)
end)

---------------------------------------------------------------------------
-- Shard-free test mode ("Pretend to summon (no shards)", SPEC5)
---------------------------------------------------------------------------

local SIM_SPOT = "Undercity"
local function lkey(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function DRof(c) return c.W.Drive end
local function cust(c, name) return DRof(c).customers[lkey(name)] end

-- the harness's macro runner does not know /stopmacro (the lab's no-op line): drop those lines
local function simWorld()
	local w = newWorld()
	local orig = w.runMacro
	w.runMacro = function(self, client, text)
		local keep = {}
		for line in (text .. "\n"):gmatch("(.-)\n") do
			if not line:match("^%s*/stopmacro") then keep[#keep + 1] = line end
		end
		return orig(self, client, table.concat(keep, "\n"))
	end
	return w
end

local function simSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { Wuber = { chars = { [lkey(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } } }
end

local function bigClick(c)
	local b = c.env.WuberDriveButton
	ok(b and H.visible(b), c.player.name .. ": the big button is shown")
	return c:click(b)
end

local function simWlab(w, kind)
	local n = 0
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WLAB" and e.result == 0 and e.text:sub(1, 4) == "SIM~" and (not kind or e.text:match("^SIM~([^~]*)") == kind) then n = n + 1 end
	end
	return n
end

local function noShardsTeam(simOn)
	local w = simWorld()
	local names = { ANITA, FARRA, HAYLEY }
	local cs = {}
	for i, n in ipairs(names) do
		cs[i] = w:addClient(n, { spot = SIM_SPOT, class = "WARLOCK", shards = 0, addons = { "Wuber", "WuberLab" },
			allowMissing = not HAVE_UI, saved = simSaved(n, names, ANITA) })
	end
	local r = labRider(w, { spot = "Orgrimmar" })
	w:group(names)
	w:advance(2)
	if simOn then
		for _, c in ipairs(cs) do labOf(c).SimSet(true) end
		labOf(r).SimSet(true)
	end
	DRof(cs[1]).SetOpen(true)
	w:advance(3)
	return w, cs, r
end

test("lab sim: a full paid ride with zero Soul Shards - the fake cast flows to the crew, the rider accepts the card, pays by trade", function()
	local w, cs, r = noShardsTeam(true)
	local an, fa, ha = cs[1], cs[2], cs[3]
	eq(w:player(ANITA).shards, 0, "no shards at all")
	ok(DRof(an).SimHooks, "Wuber's hook table is set while on")
	eq(DRof(an).Shards(), 20, "shard checks pass")
	ok(an.env.WuberLabSimBanner:IsShown() and r.env.WuberLabSimBanner:IsShown(), "banner on both windows")
	ok(H.visible(an.env.WuberLabSimBanner), "banner drawn")
	-- the rider asks
	ok(requestVia(r, lkey(ANITA)), "the rider books Anita")
	w:advance(10)
	eq(cust(an, ROCKS) and cust(an, ROCKS).state, "joined", "in the group")
	local p = an.W.Drive.Plan()
	ok(p.macrotext and p.macrotext:find("/target", 1, true), "target kept: " .. tostring(p.macrotext))
	ok(not p.macrotext:find("/cast", 1, true), "no cast line: " .. tostring(p.macrotext))
	ok(p.title and not p.title:find("Soul Shard", 1, true), "ready, not dry: " .. tostring(p.title))
	bigClick(an)
	w:advance(1.5)
	eq(cust(fa, ROCKS).state, "summoning", "the crew sees the cast")
	eq(cust(ha, ROCKS).state, "summoning")
	eq(fa.W.Drive.Plan().title, "CLICK THE PORTAL", "helper's alert")
	ok(labOf(fa).SimHelperClick(), "Pretend I clicked (Farra)")
	ok(labOf(ha).SimHelperClick(), "Pretend I clicked (Hayley)")
	w:advance(4)
	ok(cust(an, ROCKS).helps and next(cust(an, ROCKS).helps), "HELP facts arrived")
	eq(cust(an, ROCKS).state, "waiting", "END: summon went")
	-- nothing real happened
	eq(w.casts, 0, "no real cast")
	eq(#w.summons, 0, "nobody was really summoned")
	eq(w.failedCasts or 0, 0, "no failed cast either")
	eq(w:player(ANITA).shards, 0)
	eq(w:player(ROCKS).zone ~= SIM_SPOT, true, "the rider stayed where they were")
	-- the rider's fake card
	local card = r.env.WuberLabSimCard
	ok(card and card:IsShown(), "the summon card shows on the rider's window")
	ok(list(r:visibleTexts()):find("Anita Lift is summoning you to", 1, true), "card text: " .. list(r:visibleTexts()))
	eq(simWlab(w, "summon"), 1, "one WLAB message")
	r:clickOn(card.accept)
	w:advance(4)
	ok(simWlab(w, "accept") >= 1, "accept sent (whisper, relayed to the group)")
	eq(cust(an, ROCKS).state, "arrived", "Wuber treats the rider as arrived")
	-- pay by trade as normal (real gold). The game only trades next to each other: the player walks up.
	w:move(ROCKS, SIM_SPOT)
	w:advance(2)
	if not w:player(ROCKS).trade then ok(w:openTrade(an, r), "trade opened") end
	local before = w:player(ANITA).money
	local price = an.W.Char().price
	w:typeTradeMoney(w:player(ROCKS), math.floor(price / 10000), math.floor(price % 10000 / 100), price % 100)
	w:tradeAccept(w:player(ROCKS))
	w:advance(0.5)
	local tp = an.W.Drive.Plan()
	ok(tp.title and tp.title:find("^Accept"), "the button offers the trade: " .. tostring(tp.title))
	bigClick(an)
	w:advance(2)
	eq(cust(an, ROCKS) and cust(an, ROCKS).state, "paid", "paid")
	ok(w:player(ANITA).money > before, "real gold changed hands")
	bigClick(an)
	w:advance(4)
	eq(cust(an, ROCKS), nil, "the ride is done")
	ok(#find(an, "sim", "pretend cast on Wuber Rocks") == 1, "logged")
	-- switching off: everything back to normal
	for _, c in ipairs({ an, fa, ha, r }) do labOf(c).SimSet(false) end
	eq(DRof(an).SimHooks, nil, "hook table gone")
	eq(DRof(an).Shards(), 0, "real shards again")
	ok(not an.env.WuberLabSimBanner:IsShown(), "banner off")
	clean(w)
end)

test("lab sim: the card can be declined, and an accepted rider counts as here until they move or five minutes pass", function()
	local w, cs, r = noShardsTeam(true)
	local an = cs[1]
	local L = labOf(r)
	ok(requestVia(r, lkey(ANITA)), "the rider books Anita")
	w:advance(10)
	bigClick(an)
	w:advance(1.5)
	labOf(cs[2]).SimHelperClick()
	labOf(cs[3]).SimHelperClick()
	w:advance(4)
	local card = r.env.WuberLabSimCard
	ok(card:IsShown(), "card")
	r:clickOn(card.decline)
	w:advance(2)
	ok(not card:IsShown(), "declined: card gone")
	ok(not labOf(an).SimArrived(lkey(ROCKS)), "declined is not arrived")
	-- a second card, accepted; the rider moves: forgotten
	L.SimSet(false)
	L.SimSet(true)
	labOf(an).SimSet(true)
	w:advance(1)
	-- (the driver's lab says it again by hand)
	w:sendAddon(an, "WLAB", "SIM~summon~Anita Lift~Undercity", "WHISPER", ROCKS)
	w:advance(1)
	ok(card:IsShown(), "second card")
	r:clickOn(card.accept)
	w:advance(1)
	ok(labOf(an).SimArrived(lkey(ROCKS)), "accepted: arrived")
	r:fire("PLAYER_STARTED_MOVING")
	w:advance(1)
	ok(not labOf(an).SimArrived(lkey(ROCKS)), "moved: not arrived any more")
	-- five minutes
	w:sendAddon(an, "WLAB", "SIM~summon~Anita Lift~Undercity", "WHISPER", ROCKS)
	w:advance(1)
	r:clickOn(card.accept)
	w:advance(1)
	local DR = DRof(an)
	local u
	for k, unitToken in pairs(DR.units or {}) do if k == lkey(ROCKS) then u = unitToken end end
	ok(u, "the rider has a unit")
	eq(DR.Here(u), true, "here while fresh")
	w:advance(301)
	eq(DR.Here(u) and DR.Visible(u) and DR.SameMap(u) or false, false, "five minutes later: not here by the lab's word")
	clean(w)
end)

local function raidWorld()
	local w = simWorld()
	local lead = "Lea Dorn"
	w:addBot(lead, { spot = "Blackrock Mountain", class = "WARRIOR" })
	local dru = w:addClient("Dru Oak", { spot = "Blackrock Mountain", class = "DRUID", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local cal = w:addClient("Cal Brown", { spot = "Blackrock Mountain", class = "WARLOCK", shards = 0, addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local ray = w:addClient("Ray Ash", { spot = "Orgrimmar", class = "ROGUE", addons = { "Wuber", "WuberLab" }, allowMissing = not HAVE_UI })
	local names = { lead, "Dru Oak", "Cal Brown", "Ray Ash" }
	for i = 1, 12 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Blackrock Mountain", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist("Dru Oak", true)
	w:advance(15)
	return w, dru, cal, ray
end

test("lab sim: a raid-mode summon completes with zero shards (summoner's click, fake cast, card, arrived and counted)", function()
	local w, dru, cal, ray = raidWorld()
	local DD, DC = DRof(dru), DRof(cal)
	for _, c in ipairs({ dru, cal, ray }) do labOf(c).SimSet(true) end
	eq(w:player("Cal Brown").shards, 0)
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick("Cal Brown", true))
	w:advance(1)
	cal.W.Drive.AnswerOffer("Dru Oak", true)
	w:advance(3)
	ok(DD.SetOpen(true), "Start")
	w:advance(5)
	ok(DC.RaidOn(), "Cal follows")
	ok(ray.W.Drive.RaidAsk(), "Ray asks")
	w:advance(4)
	ok(DD.raidRows[lkey("Ray Ash")], "queued")
	local p = DC.Plan()
	ok(p.macrotext and p.macrotext:find("/target Ray Ash", 1, true), "targets by name: " .. tostring(p.macrotext))
	ok(not p.macrotext:find("/cast", 1, true), "no cast: " .. tostring(p.macrotext))
	bigClick(cal)
	w:advance(1.5)
	eq(DD.raidRows[lkey("Ray Ash")].state, "summoning", "the runner sees the claim hold")
	w:advance(5)
	eq(w.casts, 0, "no real cast")
	eq(#w.summons, 0, "nobody really summoned")
	local card = ray.env.WuberLabSimCard
	ok(card and card:IsShown(), "Ray's card")
	ok(list(ray:visibleTexts()):find("Cal Brown is summoning you to", 1, true), list(ray:visibleTexts()))
	local done = 0
	for _, f in ipairs(dru.fired) do if f.name == "DRIVE_RAID_DONE" then done = done + 1 end end
	ray:clickOn(card.accept)
	w:advance(4)
	eq(DD.raidRows[lkey("Ray Ash")], nil, "arrived: off the list")
	local done2 = 0
	for _, f in ipairs(dru.fired) do if f.name == "DRIVE_RAID_DONE" then done2 = done2 + 1 end end
	eq(done2 - done, 1, "DRIVE_RAID_DONE once")
	clean(w)
end)

test("lab sim: with the mode off nothing changes (no hooks, the cast line stays, shards are real, no card, no banner)", function()
	local w, cs, r = noShardsTeam(false)
	local an = cs[1]
	eq(DRof(an).SimHooks, nil, "no hook table")
	eq(DRof(an).Shards(), 0, "real shards")
	ok(not an.env.WuberLabSimBanner or not an.env.WuberLabSimBanner:IsShown(), "no banner")
	ok(requestVia(r, lkey(ANITA)), "the rider books Anita")
	w:advance(10)
	local p = an.W.Drive.Plan()
	ok(p.title and p.title:find("Soul Shard", 1, true), "dry as ever: " .. tostring(p.title))
	ok(not (p.macrotext or ""):find("stopmacro", 1, true), "no lab line")
	-- on, then off again: back to the same
	labOf(an).SimSet(true)
	ok(DRof(an).SimHooks)
	labOf(an).SimSet(false)
	eq(DRof(an).SimHooks, nil)
	local p2 = an.W.Drive.Plan()
	eq(p2.title, p.title, "the same plan as before")
	-- a stray message does nothing while off
	w:sendAddon(an, "WLAB", "SIM~summon~Anita Lift~Undercity", "WHISPER", ROCKS)
	w:advance(1)
	ok(not (r.env.WuberLabSimCard and r.env.WuberLabSimCard:IsShown()), "no card with the mode off")
	eq(labOf(an).SimHelperClick(), false, "no pretend click either")
	eq(w.casts, 0)
	eq(#w.summons, 0)
	eq(simWlab(w, "summon"), 1, "only the stray test message (the switch says hello and bye, nothing else)")
	clean(w)
end)

---------------------------------------------------------------------------
-- REVIEW-2.2 #3 / #15: sim mode never touches a player who doesn't run the lab with it on
---------------------------------------------------------------------------

local function wlog(w, from, pattern, chatType, target)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.from == from and e.prefix == "WUBER" and e.result == 0 and e.text:find(pattern)
			and (not chatType or e.chatType == chatType) and (not target or lkey(tostring(e.target)) == lkey(target)) then
			out[#out + 1] = e
		end
	end
	return out
end

test("lab sim (review 2.2 #3): the sim driver is off the public network; only a lab rider with the mode on finds and books it", function()
	local w, cs, r = noShardsTeam(true)
	local an = cs[1]
	-- a plain Wuber rider (no lab)
	local dan = w:addClient("Dan Plain", { spot = "Orgrimmar", class = "MAGE", money = 100000, allowMissing = not HAVE_UI })
	w:advance(20)
	local since = #w.addonLog
	w:advance(90)
	local chanD = 0
	for i = since + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.from == ANITA and e.prefix == "WUBER" and e.text:match("^D~") and e.chatType ~= "WHISPER" then chanD = chanD + 1 end
	end
	eq(chanD, 0, "no public beacon while the mode is on")
	eq(dan.W.drivers[lkey(ANITA)], nil, "the plain rider never sees the sim driver")
	ok(r.W.drivers[lkey(ANITA)], "the lab rider does (its D by whisper)")
	ok(#wlog(w, ANITA, "^D~", "WHISPER", ROCKS) >= 1, "D whispered to the peer")
	eq(#wlog(w, ANITA, "^D~", "WHISPER", "Dan Plain"), 0, "never to the plain rider")
	-- a request from the plain rider anyway: refused, never queued
	w:inject("Dan Plain", "R~1~danrid~Undercity~5000~1~3", "WHISPER", an)
	w:advance(3)
	eq(cust(an, "Dan Plain"), nil, "not a customer")
	ok(#wlog(w, ANITA, "^N~1~danrid", "WHISPER") >= 1, "declined (closed)")
	-- a whispered keyword from a non-lab player: no invite either
	eq(DRof(an).Request("Dan Plain", "whisper", "123"), nil, "the request filter refuses non-peers")
	-- no advert while private
	local plan, why = an.W.AdvertPlan("Undercity", 5000)
	eq(plan, nil, "no public advert")
	eq(why, "test")
	-- the lab rider books as before
	ok(requestVia(r, lkey(ANITA)), "the lab rider books Anita")
	w:advance(10)
	eq(cust(an, ROCKS) and cust(an, ROCKS).state, "joined", "in the group")
	-- off: the driver is public again
	for _, c in ipairs(cs) do labOf(c).SimSet(false) end
	w:advance(30)
	ok(#wlog(w, ANITA, "^D~", "CHANNEL") >= 1, "public beacons again")
	clean(w)
end)

test("lab sim (review 2.2 #3): a non-lab rider in the sim driver's group gets no pretend summon, no whisper; the button says a real cast is needed", function()
	local w, cs = noShardsTeam(false)
	local an = cs[1]
	local dan = w:addClient("Dan Plain", { spot = "Orgrimmar", class = "MAGE", money = 100000, allowMissing = not HAVE_UI })
	w:advance(20)
	ok(requestVia(dan, lkey(ANITA)), "the plain rider books Anita (mode off)")
	w:advance(10)
	eq(cust(an, "Dan Plain") and cust(an, "Dan Plain").state, "joined", "in the group")
	for _, c in ipairs(cs) do labOf(c).SimSet(true) end
	w:advance(3)
	local p = an.W.Drive.Plan()
	ok(not (p.macrotext or ""):find("stopmacro", 1, true), "no pretend cast line: " .. tostring(p.macrotext))
	ok(not (p.macrotext or ""):find("/w ", 1, true), "no greeting whisper: " .. tostring(p.macrotext))
	eq(p.title, "No Soul Shards on this Warlock", "dry, as without the lab")
	ok(tostring(p.sub):find("isn't in test mode", 1, true), "says a real summon is needed: " .. tostring(p.sub))
	eq(DRof(an).Shards("Dan Plain"), 0, "real shards for a non-peer")
	eq(DRof(an).Shards(), 20, "the pretend count otherwise")
	local whispers = #w.whispers
	bigClick(an)
	w:advance(5)
	eq(labOf(an).simCasts, 0, "no pretend cast")
	eq(#w.whispers, whispers, "no whisper to the plain rider")
	eq(#wlog(w, ANITA, "^S~1~[^~]*~summoning"), 0, "no 'summoning' stage to the plain rider")
	eq(labOf(an).SimCast("Dan Plain"), false, "SimCast refuses a non-peer")
	eq(cust(an, "Dan Plain").state, "joined", "nothing happened")
	clean(w)
end)

test("lab sim (review 2.2 #3): raid mode: a non-lab raider gets no pretend summon; the lab raider's pretend summon posts no /ra line", function()
	local w, dru, cal, ray = raidWorld()
	local DD, DC = DRof(dru), DRof(cal)
	for _, c in ipairs({ dru, cal, ray }) do labOf(c).SimSet(true) end
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick("Cal Brown", true))
	w:advance(1)
	cal.W.Drive.AnswerOffer("Dru Oak", true)
	w:advance(3)
	ok(DD.SetOpen(true), "Start")
	w:advance(5)
	-- a raider without the lab asks first
	DD.RaidAdd("Raider Ra")
	w:advance(2)
	local p = DC.Plan()
	ok(not (p.macrotext or ""):find("Raider Ra", 1, true), "no pretend summon (or whisper) for a non-lab raider: " .. tostring(p.macrotext))
	ok(not (p.macrotext or ""):find("/ra ", 1, true), "no raid line: " .. tostring(p.macrotext))
	DD.RaidDrop("Raider Ra")
	w:advance(2)
	ok(ray.W.Drive.RaidAsk(), "Ray asks")
	w:advance(4)
	p = DC.Plan()
	ok(p.macrotext and p.macrotext:find("/target Ray Ash", 1, true), "Ray gets the pretend summon: " .. tostring(p.macrotext))
	ok(not p.macrotext:find("/ra ", 1, true), "no /ra line: the raid has players without the lab: " .. tostring(p.macrotext))
	clean(w)
end)

test("lab sim (review 2.2 #15): an accept speaks for its sender, not field 3; a mode switched off mid-cast ends the cast; the hook waits out combat", function()
	local w, cs, r = noShardsTeam(true)
	local an, fa = cs[1], cs[2]
	-- Farra's lab (a peer) whispers an accept naming the rider: it counts for Farra only
	w:sendAddon(fa, "WLAB", "SIM~accept~Wuber Rocks", "WHISPER", ANITA)
	w:advance(1)
	ok(not labOf(an).SimArrived(lkey(ROCKS)), "the rider is not marked by someone else's word")
	-- a pretend cast, then the mode off within 0.5 s: Wuber's cast ends at once
	ok(requestVia(r, lkey(ANITA)), "booked")
	w:advance(10)
	bigClick(an)
	w:advance(0.2)
	ok(DRof(an).cast, "the pretend cast is under way")
	labOf(an).SimSet(false)
	w:advance(1)
	eq(DRof(an).cast, nil, "no cast left hanging (CastWatch's 330 s)")
	-- the PreClick hook is never set in combat
	local src = assert(io.open(LAB_DIR .. "/Sim.lua")):read("*a")
	local guard = src:find("if L.InCombat and L.InCombat() then return false end", 1, true)
	local hookAt = src:find("pcall(b.HookScript", 1, true)
	ok(guard and hookAt and guard < hookAt, "combat check before HookScript")
	clean(w)
end)

test("lab (review 2.2 #13 note): the lab's TOC never names the old summoning addon in its Notes", function()
	local toc = assert(io.open(LAB_DIR .. "/WuberLab.toc")):read("*a")
	local notes = toc:match("## Notes: ([^\n]*)")
	ok(notes, "Notes")
	ok(not notes:lower():find("ritual", 1, true), "Notes: " .. notes)
end)

---------------------------------------------------------------------------
-- the author's 18 Nov raid: the runner is the only summoner; party -> raid; a raider left and rejoined
---------------------------------------------------------------------------

local function testcharRaid(simOn)
	local w = simWorld()
	local names = { ANITA, FARRA, HAYLEY }
	local cs = {}
	for i, n in ipairs(names) do
		cs[i] = w:addClient(n, { spot = SIM_SPOT, class = "WARLOCK", shards = i == 1 and 20 or 0, addons = { "Wuber", "WuberLab" },
			allowMissing = not HAVE_UI, saved = simSaved(n, names, ANITA) })
	end
	local r = labRider(w, { spot = "Orgrimmar" })
	local g = w:group({ ANITA, FARRA, HAYLEY, ROCKS })
	w:advance(2)
	if simOn then
		for _, c in ipairs(cs) do labOf(c).SimSet(true) end
		labOf(r).SimSet(true)
	end
	w:advance(10)
	-- the party becomes a raid
	g.raid = true
	for _, n in ipairs({ ANITA, FARRA, HAYLEY, ROCKS }) do w:player(n).client:fire("CHAT_MSG_SYSTEM", "Party converted to Raid") end
	w:rosterChanged(g)
	w:advance(5)
	-- Wuber Rocks leaves and is invited back
	w:leave(ROCKS)
	w:advance(20)
	w:join(w:player(ANITA), w:player(ROCKS))
	w:advance(10)
	return w, cs, r
end

-- The tester's clicks: on the console first (Start, the queue row, the Summoners sheet...), each a
-- mouse-down in the toplevel window, which the game raises over its strata; then the big button
local function busyWindow(c, n)
	local win = c.env.WuberFrame
	for _ = 1, n do
		c:click(win)
		c.world:advance(0.3)
	end
	return win
end

local function testcharRaidClick(simOn)
	local w, cs, r = testcharRaid(simOn)
	local an = cs[1]
	local DR = DRof(an)
	ok(DR.SetMode("raid"))
	w:advance(1)
	ok(DR.SetOpen(true), "Start")
	w:advance(3)
	T.openDrive(an)
	w:advance(2)
	w:groupSay(ROCKS, "123")
	w:advance(3)
	local row = DR.raidRows[lkey(ROCKS)]
	ok(row, "queued")
	eq(row and row.name, ROCKS, "the row has the full name")
	local B, b = DR.Button, an.env.WuberDriveButton
	ok(B.Docked(), "docked over the console's slot")
	local p = b.plan
	eq(p.title, "Summon Wuber", "the button says it")
	ok(p.macrotext and p.macrotext:find("/target " .. ROCKS .. "\n", 1, true), "targets the full name: " .. tostring(p.macrotext))
	-- a click in the window, then the big button at once: the window is raised, the button stays on top
	local win = busyWindow(an, 1)
	local slot = an.W.Driver.ui.console.slot
	local r0 = H.rect(slot)
	eq(an:frameAt(r0.l + r0.w / 2, r0.b + r0.h / 2), b, "right after a click in the window the button is still over its slot")
	ok(H.STRATA_RANK(b:GetFrameStrata()) > H.STRATA_RANK(win:GetFrameStrata()), "a strata above the toplevel window: "
		.. b:GetFrameStrata() .. " over " .. win:GetFrameStrata())
	-- an evening of clicks in the window: levels climb, the button still gets the click
	busyWindow(an, 120)
	ok(win:GetFrameLevel() <= 10000 and b:GetFrameLevel() <= 10000, "levels within 0..10000")
	local hit = an:clickOn(slot)
	eq(hit, b, "the click on the slot's place lands on WuberDriveButton")
	w:advance(1)
	return w, an, r, DR, b
end

test("lab sim (the author 18 Nov): raid summons, runner = only summoner, party->raid, a raider left and rejoined: the docked big button's click casts (pretend)", function()
	local w, an, r, DR = testcharRaidClick(true)
	eq(#find(an, "sim", "pretend cast on " .. ROCKS), 1, "pretend cast logged")
	eq(labOf(an).simCasts, 1)
	ok(#find(an, "whsp", "> " .. ROCKS .. ":") >= 1, "the raider's whisper went")
	local posts = 0
	for _, g in ipairs(w.groupPosts or {}) do if g.from == ANITA and g.kind == "RAID" and g.how == "macro" then posts = posts + 1 end end
	eq(posts, 1, "the /ra line (everyone runs the test mode)")
	eq(DR.raidRows[lkey(ROCKS)].state, "summoning", "claimed")
	-- the lab logged the click: plan, macro, marks
	ok(#find(an, "click", "big button: 'Summon Wuber'") == 1, list(find(an, "click"), "\n"))
	ok(#find(an, "click", "docked FULLSCREEN_DIALOG/") == 1, "where the button was")
	ok(#find(an, "click", "macro: /w Wuber-Rocks") == 1 and #find(an, "click", "; /target Wuber Rocks ; /stopmacro") == 1, list(find(an, "click"), "\n"))
	ok(#find(an, "click", "noted: raidsum Wuber Rocks, cast Wuber Rocks") == 1, list(find(an, "click"), "\n"))
	eq(#find(an, "click", "MISSED"), 0, "no missed click")
	w:advance(10)
	eq(w.casts, 0, "nothing really cast")
	clean(w)
end)

test("lab (the author 18 Nov): the same raid with the test mode off: the docked big button's click really casts", function()
	local w, an, r, DR = testcharRaidClick(false)
	eq(w.casts, 1, "Ritual of Summoning cast")
	ok(DR.cast and DR.cast.name == ROCKS, "on Wuber Rocks")
	eq(#find(an, "sim", "pretend cast"), 0)
	ok(#find(an, "click", "macro: /w Wuber-Rocks") == 1 and #find(an, "click", "; /target Wuber Rocks ; /cast Ritual of Summoning") == 1, list(find(an, "click"), "\n"))
	ok(#find(an, "click", "noted: raidsum Wuber Rocks, cast Wuber Rocks") == 1, list(find(an, "click"), "\n"))
	w:advance(10)
	clean(w)
end)

test("lab (the author 18 Nov): a click that falls on the slot under the big button is logged as missed", function()
	local w, cs = testcharRaid(false)
	local an = cs[1]
	ok(DRof(an).SetOpen(true))
	T.openDrive(an)
	w:advance(3)
	local b = an.env.WuberDriveButton
	b:Hide() -- (as if something kept the button off its slot)
	an:clickOn(an.W.Driver.ui.console.slot)
	ok(#find(an, "click", "MISSED: the click fell on the slot") == 1, list(find(an, "click"), "\n"))
	b:Show()
	w:advance(2)
end)

---------------------------------------------------------------------------
-- The test run, self-marking checks, the pretend rider, login checks (tests/lab_run.lua)
---------------------------------------------------------------------------

do
	local here = (debug.getinfo(1, "S").source or ""):match("^@(.*)/[^/]*$") or "tests"
	local chunk = loadfile(here .. "/lab_run.lua")
	if chunk and not H.exists(LAB_DIR .. "/Run.lua") then
		chunk = nil -- (an older lab, without the test run: WUBER_LAB_DIR names the newer one)
		test("lab run: this Wuber Lab has no test run (Run.lua) - skipped", function() end)
	end
	if chunk then
		chunk({ T = T, LAB_DIR = LAB_DIR, labOf = labOf, find = find, lines = lines, labRider = labRider, simWorld = simWorld,
			simSaved = simSaved, bigClick = bigClick, dumpSaved = dumpSaved, lkey = lkey, DRof = DRof, cust = cust, simWlab = simWlab,
			ANITA = ANITA, FARRA = FARRA, HAYLEY = HAYLEY, ROCKS = ROCKS, SIM_SPOT = SIM_SPOT })
	end
end

-- Wuber Lab (developer only, never ship): the test run's checks for Wuber 2.3.0's fix round (REPORT9
-- "The tester, in game"). Same rules as Checks.lua (README "How to add a check"): each check judges itself
-- from what the lab can see - Wuber's state (the customer book, the queue, Settings' search, the
-- passphrase flag, the driver's screen), its visible texts (L.J.textShown), the game's tooltip, the
-- big button's clicks and the whispers that went - and asks one short Yes/No only where only the tester can
-- judge (how it looks). Every Wuber name is looked up at run time and nil-guarded.
--
-- Scenes, in this order in a run (each "after" the one before; prio 0: before the older scenes, so a
-- run takes the fix round first and leaves what doesn't fit for the next run; the photo tour still
-- ends it):
--   fix9home  loose   the empty Home's wording (Yes/No), on Wuber Rocks with nobody open
--   fix9book  whole   "My own account" marks (Anita, Farra), Anita open, the coin icons on Confirm
--                     (Yes/No), Wuber Rocks whispers by hand,
--                     Send "Get Wuber" (queued, then out on the next big-button click only), a note
--                     that reaches Farra's window, Gifted, the row's marks and tooltip, off the list
--   fix9drv   loose   the Customers list folded and unfolded, raid summons outside a raid ("Ready to
--                     summon?" / "Make or join a raid first."), small text and greyed
--                     buttons, list fades, the header's fold button (Yes/No)
--   fix9set   loose   Settings search (volume, price, passphrase), a match opens highlighted, Esc
--                     clears the box without closing the window
--   fix9pass  whole   the ride passphrase: off by default, on in Settings > Driving, Wuber Rocks' Wuber
--                     hears it, off again
-- Nothing here sends anything: the lab only watches (the tester's own clicks and whispers do the work).

local _, L = ...

local str, num, call = L.str, L.num, L.call
local J = L.J

local F9 = { clicks = 0 } -- this session: the big button's clicks, the "Get Wuber" whisper seen
L.fix9 = F9

local function fn(t, name) return type(t) == "table" and type(t[name]) == "function" end
local function DRx() return J.DR() end
local function Dx()
	local W = L.W()
	return W and type(W.Driver) == "table" and W.Driver or nil
end
local function UIx()
	local W = L.W()
	return W and type(W.UI) == "table" and W.UI or nil
end
local function fold()
	local U = UIx()
	return U and type(U.Fold) == "table" and U.Fold or nil
end
local function mod(name)
	local W = L.W()
	if not fn(W, "Mod") then return nil end
	local m = call(W.Mod, name)
	return type(m) == "table" and m or nil
end
local function riderName() return L.RunName("rider") end
local function entry(name)
	local rec = J.call(DRx(), "BookEntry", name)
	return type(rec) == "table" and rec or nil
end
local function short(s, n)
	s = tostring(s or "")
	n = n or 40
	return #s > n and (s:sub(1, n - 3) .. "...") or s
end

---------------------------------------------------------------------------
-- Watchers: the big button's clicks; the "Get Wuber" whisper (with how long after a click)
---------------------------------------------------------------------------

local function hookClicks()
	if F9.hooked then return true end
	if L.InCombat() then return false end -- (a secure button: never touched in combat)
	local b = rawget(_G, "WuberDriveButton")
	if type(b) ~= "table" or type(b.HookScript) ~= "function" then return false end
	F9.hooked = pcall(b.HookScript, b, "PreClick", function(_, _, down)
		if down then return end
		F9.clicks = F9.clicks + 1
		F9.clickAt = L.Now()
	end)
	return F9.hooked
end
L.Fix9HookClicks = hookClicks

-- the start of the driver's "Get Wuber" text (to its first placeholder), lower case
local function getappHead()
	local DR = DRx()
	local t = str(J.call(DR, "Template", "getapp")) or (DR and type(DR.TEMPLATES) == "table" and str(DR.TEMPLATES.getapp)) or nil
	if not t then return nil end
	t = t:match("^([^{%%]*)") or t
	t = t:gsub("^%s+", ""):sub(1, 24):lower()
	return t ~= "" and t or nil
end

function L.Fix9Whisper(text, target)
	text, target = str(text), str(target)
	if not (text and target) or L.Key(target) ~= J.key("rider") then return end
	local head = getappHead()
	local low = text:lower()
	if not ((head and low:find(head, 1, true)) or (low:find("wuber", 1, true) and low:find("curseforge", 1, true))) then return end
	local t = L.Now()
	F9.getapp = { at = t, clickAge = F9.clickAt and (t - F9.clickAt) or nil, clicks = F9.clicks, text = text }
	L.Log("run", ("Get Wuber whisper to %s, %s"):format(target, F9.getapp.clickAge and ("%.1f s after a big-button click"):format(F9.getapp.clickAge) or "with no big-button click"))
end

L.On("CHAT_MSG_WHISPER_INFORM", function(text, target) pcall(L.Fix9Whisper, text, target) end)
L.OnLogin(function() L.Every(2, function() hookClicks() end) end)

-- (a whisper that went with a click: the click's macro sends it at once)
local CLICK_SLACK = 3

---------------------------------------------------------------------------
-- 1. Home, empty (rider)
---------------------------------------------------------------------------

L.AddScene({ id = "fix9home", title = "2.3.0 fix round: empty Home", linked = false, prio = 0 })

local EMPTY_TITLES = { "No drivers online", "No drivers to ", "Nobody summons to ", "No drivers match that" } -- "No drivers online" also matches the older "No drivers online right now" (2.4 shortened the title)
local EMPTY_SUBS = { "usually around", "last saw a driver", "show up here", "Pin a bounty", "Your bounty is up", "Can't reach the Wuber network" }

local function shownAny(list)
	for _, part in ipairs(list) do
		local t = J.textShown(part)
		if t then return t end
	end
	return nil
end

L.AddCheck({ id = "f9_home_empty", title = "Empty Home wording", scene = "fix9home", who = "rider", secs = 30, timeout = 180,
	click = "Anita: Close (Drive tab) if open. Wuber Rocks: /wuber, Home with no driver open: read it, then answer",
	poll = function(ctx)
		if not J.appOpen() then ctx.data.waitWhy = "Wuber's window isn't open on Wuber Rocks" return end
		local title = shownAny(EMPTY_TITLES)
		if not title then ctx.data.waitWhy = "Home isn't empty (a driver is open?)" return end
		local sub = shownAny(EMPTY_SUBS)
		ctx.data.auto = "'" .. short(title, 40) .. "'" .. (sub and (" / '" .. short(sub, 70) .. "'") or "")
	end,
	ask = function(ctx) return ctx.data.auto and "Empty Home's wording right for your ride history?" or nil end,
	answer = function(ctx, yes)
		return yes and "pass" or "fail", (yes and "Tester: right; " or "Tester: wording wrong; ") .. tostring(ctx.data.auto)
	end,
	onTimeout = function(ctx)
		if not ctx.data.auto then return "skip", "Home never showed its empty state (" .. tostring(ctx.data.waitWhy) .. ")" end
	end })

---------------------------------------------------------------------------
-- 2. The customer book and "Get Wuber" (whole, in order)
---------------------------------------------------------------------------

L.AddScene({ id = "fix9book", title = "2.3.0 fix round: notes, Gifted, Get Wuber", prio = 0, after = "fix9home",
	intro = "customer notes between Anita and Farra, Gifted, and \"Get Wuber\" for a rider who whispers by hand" })

local function ownCheck(id, title, who, other)
	L.AddCheck({ id = id, title = title, scene = "fix9book", who = who, secs = 20, timeout = 120,
		click = "Drive tab > Crew: on " .. L.RunShort(other) .. "'s card switch on \"my account\"",
		begin = function(ctx)
			if not fn(DRx(), "BookOwn") then return "skip", "DR.BookOwn is missing (an older Wuber)" end
			if J.call(DRx(), "BookOwn", J.key(other)) == true then return "pass", L.RunShort(other) .. " is marked \"My own account\" already" end
		end,
		poll = function(ctx)
			if J.call(DRx(), "BookOwn", J.key(other)) == true then return "pass", L.RunShort(other) .. " marked \"My own account\"" end
			ctx.data.waitWhy = L.RunShort(other) .. " isn't marked \"My own account\" on this window"
		end })
end
ownCheck("f9_own_driver", "Anita marks Farra", "driver", "crew1")
ownCheck("f9_own_crew1", "Farra marks Anita", "crew1", "driver")

L.AddCheck({ id = "f9_open", title = "Anita open", scene = "fix9book", who = "driver", secs = 15, timeout = 90,
	click = "Drive tab: choose Sell summons and press Open",
	begin = function() if J.selling() then return "pass", "already open, selling" end end,
	poll = function(ctx)
		if J.call(ctx.DR, "Mode") == "raid" then ctx.data.waitWhy = "still on Raid summons: choose Sell summons" end
		if J.selling() then return "pass", "open, selling" end
	end })

L.AddCheck({ id = "f9_coins", title = "Coin icons line up", scene = "fix9book", who = "rider", secs = 30, timeout = 180,
	click = "/wuber, tap Anita's card (Confirm, don't Request): the coins (also on the pay card and Done in a ride); answer",
	poll = function(ctx)
		local s = ctx.UI and ctx.UI.state
		if type(s) == "table" and s.manual == "confirm" then ctx.data.auto = "the Confirm screen" return end
		ctx.data.waitWhy = ctx.data.auto and nil or "the Confirm screen isn't open"
	end,
	ask = function(ctx) return ctx.data.auto and "Coin icons in line with their numbers?" or nil end })

L.AddCheck({ id = "f9_whisper", title = "A rider by whisper", scene = "fix9book", who = "rider", judge = "driver", secs = 20, timeout = 90,
	click = "type /w Anita Lift WTB summon (by hand, not Wuber's Request)",
	poll = function(ctx)
		local c = J.cust("rider")
		if not c then ctx.data.waitWhy = "Wuber Rocks isn't in Anita's queue" return end
		local state = str(J.call(ctx.DR, "GetAppState", c)) or "?"
		if state == "app" then return "fail", "Wuber Rocks came through the app: cancel it and whisper by hand" end
		return "pass", "Wuber Rocks is in Anita's queue by whisper (" .. tostring(c.state) .. ", Get Wuber: " .. state .. ")"
	end })

local GETAPP_WHY = { sent = "\"Get Wuber\" already went to Wuber Rocks today (once a day): try tomorrow",
	off = "whispers are off (or the Get Wuber message is empty): Messages", raid = "raid summons are on", app = "Wuber Rocks came through the app",
	none = "Wuber Rocks isn't a rider in Anita's queue" }

L.AddCheck({ id = "f9_getapp_pick", title = "Send \"Get Wuber\" picked", scene = "fix9book", who = "driver", secs = 20, timeout = 90,
	click = "open Wuber Rocks' row menu (... on his row), pick Send \"Get Wuber\" (don't click the big button yet)",
	when = function(ctx)
		F9.queuedAt, F9.queuedClicks = nil, nil
		local c = J.cust("rider")
		local state = c and str(J.call(ctx.DR, "GetAppState", c)) or "none"
		if state == "sent" then return "skip", GETAPP_WHY.sent end
		return true
	end,
	poll = function(ctx)
		local g = F9.getapp
		if g and g.at >= ctx.started and not (g.clickAge and g.clickAge <= CLICK_SLACK) then
			return "fail", "\"Get Wuber\" went out with no big-button click"
		end
		local c = J.cust("rider")
		local state = c and str(J.call(ctx.DR, "GetAppState", c)) or "none"
		if state == "queued" then
			F9.queuedAt, F9.queuedClicks = L.Now(), F9.clicks
			return "pass", "queued: it waits for the next big-button click"
		end
		ctx.data.waitWhy = GETAPP_WHY[state] or ("not picked (Get Wuber: " .. state .. ")")
	end })

L.AddCheck({ id = "f9_getapp_click", title = "\"Get Wuber\" on the click", scene = "fix9book", who = "driver", secs = 15, timeout = 90,
	click = "click the big button (it says {button})", buttonText = "Invite Wuber Rocks",
	when = function() if not F9.queuedAt then return "skip", "\"Get Wuber\" wasn't queued (the step before)" end return true end,
	poll = function(ctx)
		local g = F9.getapp
		if g and g.at >= F9.queuedAt then
			if not (g.clickAge and g.clickAge <= CLICK_SLACK) then return "fail", "\"Get Wuber\" went out with no big-button click" end
			local n = g.clicks - (F9.queuedClicks or 0)
			return "pass", "whispered on big-button click " .. n .. " after picking it: '" .. short(g.text, 50) .. "'"
		end
		if not hookClicks() then ctx.data.waitWhy = "the lab can't see the big button's clicks" return end
		local c = J.cust("rider")
		local state = c and str(J.call(ctx.DR, "GetAppState", c)) or "none"
		local n = F9.clicks - (F9.queuedClicks or 0)
		if state == "sent" and n > 0 then return "pass", "sent with big-button click " .. n .. " (stamped for today)" end
		ctx.data.waitWhy = n > 0 and ("not sent after " .. n .. " big-button click" .. (n == 1 and "" or "s") .. " (Get Wuber: " .. state .. ")")
			or "no big-button click yet"
	end })

L.AddCheck({ id = "f9_note", title = "A customer note", scene = "fix9book", who = "driver", secs = 30, timeout = 120,
	click = "Wuber Rocks' row menu: Note..., type a few words, Save",
	poll = function(ctx)
		local rec = entry(riderName())
		local at = rec and num(rec.noteAt) or 0
		if rec and str(rec.note) and at >= L.Epoch() - ctx.t - 2 then return "pass", "note saved: '" .. short(rec.note) .. "'" end
		ctx.data.waitWhy = "no new note for Wuber Rocks (press Save)"
	end })

local function noteHere(ctx, fresh)
	local rec = entry(riderName())
	local note = rec and str(rec.note)
	if note and (num(rec.noteAt) or 0) >= L.Epoch() - fresh and (rec.noteBy == nil or rec.noteBy == J.key("driver")) then
		return "pass", "Farra's book has Anita's note: '" .. short(note) .. "'"
	end
	if J.call(DRx(), "BookOwn", J.key("driver")) ~= true then ctx.data.waitWhy = "Farra hasn't marked Anita \"My own account\"" return end
	ctx.data.waitWhy = "the note didn't reach Farra's window" .. (ctx.data.peers and (" (Anita sends to: " .. ctx.data.peers .. ")") or "")
end

L.AddCheck({ id = "f9_note_reach", title = "The note reaches Farra", scene = "fix9book", who = "crew1", secs = 10, timeout = 90,
	say = "the note reaches Farra's window by itself",
	also = { "driver" },
	observe = function(o)
		local names = {}
		for _, p in ipairs(J.call(DRx(), "BookPeers") or {}) do names[#names + 1] = tostring(p.name) end
		o.Tell(#names > 0 and table.concat(names, ", ") or "nobody")
	end,
	watch = { "fact" },
	test = function(ctx, _, _, text) ctx.data.peers = tostring(text) end,
	poll = function(ctx) return noteHere(ctx, 600) end })

L.AddCheck({ id = "f9_gift", title = "Gifted", scene = "fix9book", who = "driver", secs = 15, timeout = 90,
	click = "Wuber Rocks' row menu: Gifted",
	poll = function(ctx)
		local rec = entry(riderName())
		local at = rec and num(rec.gift)
		if at then
			local day = date and date("%d %b", math.floor(at)) or tostring(at)
			if at >= L.Epoch() - ctx.t - 2 then return "pass", "stamped gifted " .. day end
			return "pass", "stamped gifted on " .. day .. " (before; a stamp is never removed)"
		end
		ctx.data.waitWhy = "Wuber Rocks isn't stamped gifted"
	end })

-- the queue row showing customer c (Wuber's row frames keep it as .c), visible
local function rowOf(c)
	local win = rawget(_G, "WuberFrame")
	if type(win) ~= "table" or call(win.IsVisible, win) ~= true then return nil end
	local found, n = nil, 0
	local function walk(f, depth)
		if found or depth > 12 or n > 3000 then return end
		n = n + 1
		if call(f.IsVisible, f) ~= true then return end
		if f.c == c then found = f return end
		local ok, kids = pcall(function() return { f:GetChildren() } end)
		for _, k in ipairs(ok and kids or {}) do walk(k, depth + 1) end
	end
	walk(win, 0)
	return found
end
L.Fix9RowOf = rowOf

local function tipLines()
	-- Wuber's tip: its own card in 2.4, the game's tooltip before (L.Tip, Log.lua)
	local s, kind = L.Tip.surface()
	if not s then return nil end
	local out = {}
	for _, l in ipairs(L.Tip.lines(s, kind)) do out[#out + 1] = str(l.text) or l.text end
	return table.concat(out, "\n")
end

L.AddCheck({ id = "f9_marks", title = "Row marks and tooltip", scene = "fix9book", who = "driver", secs = 20, timeout = 90,
	click = "point at Wuber Rocks' row in the queue (its tooltip)",
	poll = function(ctx)
		local c = J.cust("rider")
		if not c then ctx.data.waitWhy = "Wuber Rocks isn't in Anita's queue" return end
		local r = rowOf(c)
		if not r then ctx.data.waitWhy = "Wuber Rocks' row isn't on screen (Drive tab, the queue)" return end
		local nm, gm = r.noteMark, r.giftMark
		local marks = (type(nm) == "table" and call(nm.IsVisible, nm) == true) and (type(gm) == "table" and call(gm.IsVisible, gm) == true)
		local tip = tipLines()
		if not tip then ctx.data.waitWhy = "no tooltip yet: point at his row" return end
		local hasNote, hasGift = tip:find("Note:", 1, true) ~= nil, tip:find("Gifted on", 1, true) ~= nil
		if not (hasNote and hasGift) then
			ctx.data.waitWhy = "the tooltip lacks " .. (hasNote and "" or "'Note: ...'") .. ((not hasNote and not hasGift) and " and " or "") .. (hasGift and "" or "'Gifted on ...'")
			return
		end
		if not marks then return "fail", "the tooltip has the note and the stamp, but the row's note or gift mark is hidden" end
		return "pass", "note and gift marks on his row; the tooltip says the note and 'Gifted on'"
	end })

L.AddCheck({ id = "f9_clear", title = "Off the list", scene = "fix9book", who = "driver", secs = 12, timeout = 90,
	click = "Wuber Rocks' row menu: Take off the list",
	poll = function(ctx)
		if not J.cust("rider") then return "pass", "Wuber Rocks is off Anita's list" end
		ctx.data.waitWhy = "Wuber Rocks is still in Anita's queue"
	end })

---------------------------------------------------------------------------
-- 3. The driver's pages and the look (loose: each stands alone)
---------------------------------------------------------------------------

L.AddScene({ id = "fix9drv", title = "2.3.0 fix round: driver pages and the look", linked = false, prio = 0, after = "fix9book" })

L.AddCheck({ id = "f9_customers", title = "Customers folded and unfolded", scene = "fix9drv", who = "driver", secs = 40, timeout = 180,
	click = "Drive tab: Customers (link at the bottom); look, press the fold button (unfold), look again, then answer",
	poll = function(ctx)
		local D, F = Dx(), fold()
		if not fn(D, "CurrentScreen") then return "skip", "W.Driver.CurrentScreen is missing (an older Wuber)" end
		if not (J.appOpen() and call(D.CurrentScreen) == "customers") then ctx.data.waitWhy = "the Customers page isn't open" return end
		local d = ctx.data
		local unfolded = fn(F, "IsUnfolded") and call(F.IsUnfolded) == true
		if unfolded then d.wide = true else d.narrow = true end
		local n = #(J.call(DRx(), "Customers") or {})
		local fits = fn(F, "Fits") and call(F.Fits) == true
		if d.narrow and (d.wide or not fits) then
			d.auto = n .. " customer" .. (n == 1 and "" or "s") .. (d.wide and ", seen folded and unfolded" or ", folded (this window can't unfold)")
		else
			d.waitWhy = d.narrow and "seen folded: press the fold button to unfold it" or "seen unfolded: fold it too"
		end
	end,
	ask = function(ctx) return ctx.data.auto and "Customers list right, folded and unfolded?" or nil end,
	answer = function(ctx, yes)
		return yes and "pass" or "fail", (yes and "Tester: right; " or "Tester: looks wrong; ") .. tostring(ctx.data.auto)
	end })

L.AddCheck({ id = "f9_raid_ready", title = "Raid summons outside a raid", scene = "fix9drv", who = "driver", secs = 40, timeout = 150,
	click = "leave the group; Drive tab: Close if open, choose Raid summons and press Start (afterwards: Stop, Sell summons)",
	poll = function(ctx)
		if J.inGroup() then ctx.data.waitWhy = "Anita is in a group: leave it first" return end
		if J.call(ctx.DR, "Mode") ~= "raid" then ctx.data.waitWhy = "not on Raid summons" return end
		local head, line = J.textShown("Ready to summon?"), J.textShown("Make or join a raid first")
		if head and line then return "pass", "'Ready to summon?' with '" .. short(line, 50) .. "'" end
		ctx.data.waitWhy = head and "'Ready to summon?' but no 'Make or join a raid first.'" or "no 'Ready to summon?' card on the Drive tab"
	end })

-- (a look: Wuber's window must be open before the question comes; once seen, it stays asked)
local function appShown(ctx)
	if ctx.data.auto or J.appOpen() then return true end
	ctx.data.waitWhy = "Wuber's window isn't open"
	return nil
end

L.AddCheck({ id = "f9_text", title = "Small text and greyed buttons", scene = "fix9drv", who = "driver", secs = 25, timeout = 180,
	click = "look over the Drive tab and Settings: small grey lines, greyed buttons; then answer",
	poll = function(ctx) ctx.data.auto = appShown(ctx) end,
	ask = function(ctx) return ctx.data.auto and "Small text and greyed buttons easy to read?" or nil end })

L.AddCheck({ id = "f9_fades", title = "List fades", scene = "fix9drv", who = "driver", secs = 40, timeout = 180,
	click = "scroll Trips, Earnings, the queue and Raid summons' list: their edges fade; then answer",
	poll = function(ctx) ctx.data.auto = appShown(ctx) end,
	ask = function(ctx) return ctx.data.auto and "Do the lists fade softly at top and bottom?" or nil end })

L.AddCheck({ id = "f9_foldbtn", title = "Header fold button", scene = "fix9drv", who = "driver", secs = 15, timeout = 180,
	click = "look at the header: the fold button beside the tabs; then answer",
	poll = function(ctx) ctx.data.auto = appShown(ctx) end,
	ask = function(ctx) return ctx.data.auto and "Fold button clear of the tabs (not crowding them)?" or nil end })

---------------------------------------------------------------------------
-- 4. Settings: the search (loose)
---------------------------------------------------------------------------

L.AddScene({ id = "fix9set", title = "2.3.0 fix round: Settings search", linked = false, prio = 0, after = "fix9drv" })

-- Settings' search state (UI.Settings.Rows' st: st.find, st.query), or nil and why
local function findState()
	local U = UIx()
	if not fn(U, "SettingsShown") then return nil, "UI.SettingsShown is missing (an older Wuber)" end
	local R = mod("UI.Settings.Rows")
	local st = R and type(R.st) == "table" and R.st or nil
	if not (st and type(st.find) == "table") then return nil, "Settings' search isn't built yet: open Settings" end
	if call(U.SettingsShown) ~= true then return nil, "Settings isn't open" end
	return st
end

local function labels(list, n)
	local out = {}
	for i = 1, math.min(#list, n) do out[#out + 1] = tostring(list[i].label) end
	return table.concat(out, ", ")
end

local function searchCheck(id, word, want)
	L.AddCheck({ id = id, title = "Settings search: " .. word, scene = "fix9set", who = "driver", secs = 15, timeout = 90,
		click = "Settings (gear): click the search box and type " .. word,
		poll = function(ctx)
			local st, why = findState()
			if not st then ctx.data.waitWhy = why return end
			local q = tostring(st.query or ""):lower()
			if not q:find(word, 1, true) then ctx.data.waitWhy = "the box says '" .. q .. "'" return end
			local f = st.find
			local list = type(f.list) == "table" and f.list or {}
			if (num(f.count) or 0) == 0 or #list == 0 then return "fail", "No settings match '" .. q .. "'" end
			if want then
				local hit = false
				for _, m in ipairs(list) do if m.label == want then hit = true end end
				if not hit then return "fail", "'" .. want .. "' isn't among " .. #list .. " matches: " .. labels(list, 4) end
			end
			return "pass", #list .. " match" .. (#list == 1 and "" or "es") .. ": " .. labels(list, 3)
		end })
end
searchCheck("f9_find_volume", "volume")
searchCheck("f9_find_price", "price")
searchCheck("f9_find_pass", "passphrase", "Show ride passphrase")

L.AddCheck({ id = "f9_find_open", title = "A match opens, highlighted", scene = "fix9set", who = "driver", secs = 15, timeout = 90,
	click = "Settings: search a word, tap a match",
	poll = function(ctx)
		local st, why = findState()
		if not st then ctx.data.waitWhy = why return end
		local fl = st.find.flashing
		if type(fl) == "table" then
			local lbl = type(fl.frame) == "table" and fl.frame.label
			local text = type(lbl) == "table" and str(call(lbl.GetText, lbl)) or nil
			return "pass", "opened " .. tostring(st.view or "?") .. (text and (" at '" .. short(text) .. "'") or "") .. ", highlighted"
		end
		ctx.data.waitWhy = "no match opened with its highlight"
	end })

-- Esc in the box: heard on the box itself (HookScript), then the box is empty and the window open
local function hookEsc(st)
	local box = st.find and st.find.box
	local eb = type(box) == "table" and box.edit or nil
	if type(eb) ~= "table" or type(eb.HookScript) ~= "function" then return false end
	if F9.escBox == eb then return true end
	if pcall(eb.HookScript, eb, "OnEscapePressed", function() F9.escAt = L.Now() end) then F9.escBox = eb end
	return F9.escBox == eb
end

L.AddCheck({ id = "f9_find_esc", title = "Esc clears the search", scene = "fix9set", who = "driver", secs = 15, timeout = 90,
	click = "Settings: type a word in the search box, then press Esc",
	poll = function(ctx)
		local d = ctx.data
		local U = UIx()
		-- (heard first: an Esc that closes the window also closes Settings)
		if not d.escAt and d.word and F9.escAt and F9.escAt >= ctx.started then d.escAt = F9.escAt end
		if d.escAt then
			if L.Now() - d.escAt < 0.6 then return end
			local win = rawget(_G, "WuberFrame")
			if not (type(win) == "table" and call(win.IsVisible, win) == true) then return "fail", "Esc in the search box closed Wuber's window" end
			if not (fn(U, "SettingsShown") and call(U.SettingsShown) == true) then return "fail", "Esc in the search box closed Settings" end
			local R = mod("UI.Settings.Rows")
			local q = R and type(R.st) == "table" and tostring(R.st.query or "") or "?"
			if q ~= "" then return "fail", "Esc left '" .. q .. "' in the box" end
			return "pass", "Esc cleared '" .. tostring(d.word) .. "', the window and Settings stayed open"
		end
		local st, why = findState()
		if not st then d.waitWhy = why return end
		if not hookEsc(st) then d.waitWhy = "the lab can't hear the search box" return end
		local q = tostring(st.query or "")
		if q ~= "" then d.word = q end
		d.waitWhy = d.word and "no Esc yet" or "type a word in the search box first"
	end })

---------------------------------------------------------------------------
-- 5. The ride passphrase: hidden by default, shown when turned on (whole)
---------------------------------------------------------------------------

L.AddScene({ id = "fix9pass", title = "2.3.0 fix round: the ride passphrase", prio = 0, after = "fix9set",
	intro = "the ride passphrase: off by default, on in Settings > Driving, back off" })

local function passOn()
	local W = L.W()
	if not fn(W, "PassphraseOn") then return nil end
	return call(W.PassphraseOn) == true
end

L.AddCheck({ id = "f9_pass_open", title = "Anita open", scene = "fix9pass", who = "driver", secs = 10, timeout = 90,
	click = "Drive tab: Sell summons, Open",
	begin = function() if J.selling() then return "pass", "already open, selling" end end,
	poll = function() if J.selling() then return "pass", "open, selling" end end })

L.AddCheck({ id = "f9_pass_default", title = "Passphrase off by default", scene = "fix9pass", who = "driver", secs = 3, timeout = 10,
	say = "the ride passphrase is off unless turned on",
	begin = function(ctx)
		local on = passOn()
		if on == nil then return "skip", "W.PassphraseOn is missing (an older Wuber)" end
		local opts = J.call(ctx.DR, "opts")
		local saved = type(opts) == "table" and opts.showPass or nil
		if on then return "skip", "it is on here already (turned on before): the default can't be seen" end
		return "pass", saved == nil and "off (never set: the default)" or "off"
	end })

L.AddCheck({ id = "f9_pass_on", title = "Show ride passphrase on", scene = "fix9pass", who = "driver", secs = 20, timeout = 90,
	click = "Settings > Driving: turn on \"Show ride passphrase\"",
	poll = function(ctx)
		if passOn() then return "pass", "on: riders who book through Wuber see the two words" end
		ctx.data.waitWhy = "\"Show ride passphrase\" is still off"
	end })

L.AddCheck({ id = "f9_pass_rider", title = "Rider's Wuber hears it", scene = "fix9pass", who = "rider", secs = 10, timeout = 120,
	say = "Anita's beacon tells Wuber Rocks' Wuber she shows the passphrase",
	poll = function(ctx)
		local W = ctx.W
		local d = W and type(W.drivers) == "table" and W.drivers[J.key("driver")]
		if type(d) ~= "table" then ctx.data.waitWhy = "Anita isn't on Wuber Rocks' list (is she open?)" return end
		if d.showPass == true then return "pass", "Anita's entry says riders see the passphrase" end
		ctx.data.waitWhy = "Anita's entry doesn't say she shows the passphrase"
	end })

L.AddCheck({ id = "f9_pass_off", title = "Passphrase off again", scene = "fix9pass", who = "driver", secs = 15, timeout = 90,
	click = "Settings > Driving: turn \"Show ride passphrase\" off again (the default)",
	poll = function(ctx)
		if passOn() == false then return "pass", "off again: no passphrase" end
		ctx.data.waitWhy = "\"Show ride passphrase\" is still on"
	end })

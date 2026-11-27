-- Round 46 j: HUNT-19 (Effects Off says the minimap button still pulses), HUNT-43 (the advert tip says which
-- channel it really uses), HUNT-23 (Settings from the Drive tab's gear shows Driving to anyone).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function tipText(f)
	local t = f and f.wuberTip
	if type(t) == "table" then
		return (type(t.title) == "string" and t.title or "") .. " " .. (type(t.text) == "string" and t.text or "")
	end
	return ""
end
local function walk(f, out, depth)
	out = out or {}
	depth = depth or 0
	if type(f) ~= "table" or depth > 12 then return out end
	out[#out + 1] = tipText(f)
	if f.GetChildren then
		for _, c in ipairs({ f:GetChildren() }) do walk(c, out, depth + 1) end
	end
	return out
end

local function open(where)
	local w = T.newWorld()
	local r = T.rider(w)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	if where then r.W.UI.SelectTab("Drive") w:advance(1) end
	return w, r
end

test("r46 j: HUNT-19 the Effects tip says the minimap button still pulses", function()
	local w, r = open()
	r.W.UI.OpenSettings()
	w:advance(1)
	local all = table.concat(walk(r.W.UI.settings.panel), "\n")
	ok(all:find("Off: no effects at all. Only the minimap button still pulses, while your summon is up or the big button has a click for you.", 1, true), "new Off line")
	ok(not all:find("nothing moves", 1, true), "old words gone")
end)

test("r46 j: HUNT-43 the advert tip names the real channels and the own advert", function()
	local w, r = open()
	r.W.UI.OpenSettings()
	w:advance(1)
	local all = table.concat(walk(r.W.UI.settings.panel), "\n")
	-- (word rule) the advert tip is short; the channels are named on the row "Chat channels" (its box and tooltip)
	ok(all:find("Opening also posts one advert line in public chat. At most once every 15 minutes. Never in combat, never without your click. Change the words in Messages.", 1, true), "the short advert tip")
	ok(all:find("Where your adverts go, in turn: the one posted to longest ago first. Usually services, trade, lookingforgroup.", 1, true), "the channels' tooltip names the real channels")
	ok(not all:find("else Trade, else", 1, true), "old promise gone")
end)

test("r46 j: HUNT-23 the Drive tab's gear shows the Driving section to a rider", function()
	local w, r = open("Drive")
	local ui = r.W.UI.state
	ok(ui.gear, "the gear")
	ui.gear:GetScript("OnClick")(ui.gear)
	w:advance(1)
	ok(ui.settingsOpen, "Settings open")
	ok(r.W.UI.settings.drive:IsShown(), "Driving section shown")
end)

test("r46 j: HUNT-23 the gear from another tab still hides Driving from a rider", function()
	local w, r = open()
	r.W.UI.OpenSettings()
	w:advance(1)
	ok(not r.W.UI.settings.drive:IsShown(), "Driving hidden")
end)

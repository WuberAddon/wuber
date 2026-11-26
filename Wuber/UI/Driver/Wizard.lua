-- Module: UI.Driver.Wizard
-- Purpose: The crew wizard (3 steps), people rows reused by Crew, summoner order (D.SaveSummoners).
--   (design 2, N) the next step is pushed in from the right, a step back popped (A.Push, A.PopPage).
-- API: D.SaveSummoners, D.screens.wizard
-- Internals: ROLE_TEXT, classRole, addByName, indexOf, isWarlock, offer, paintPerson, personRow, rosterNotCrew,
--   saveOrder
-- Uses: UI.Driver.Screens
-- Later: (none)
-- Events: (none)
-- Standalone: no
-- Test: tests/ui/driver/wizard_test.lua
-- From: UI_Drive.lua 164-878 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Driver.Wizard", { "UI.Driver.Screens" })
local ScreensMod = W.Mod("UI.Driver.Screens")
local Char, INNER, PAD, Pool = ScreensMod.Char, ScreensMod.INNER, ScreensMod.PAD, ScreensMod.Pool
local Screen, call, dr, nameOf = ScreensMod.Screen, ScreensMod.call, ScreensMod.dr, ScreensMod.nameOf
local para, plural, safeScript, setShown = ScreensMod.para, ScreensMod.plural, ScreensMod.safeScript, ScreensMod.setShown
local short, st, toast = ScreensMod.short, ScreensMod.st, ScreensMod.toast
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

local DR = W.Drive
local D = W.Driver

local K = D.kit or {}

local S, N = W.Str, W.Num

---------------------------------------------------------------------------
-- The crew wizard: 1 Who summons with you? 2 Pick your crew 3 Caster and checks
---------------------------------------------------------------------------

local CHOICES = {
	{ id = "solo", title = "Just me", glyph = "summon",
		text = "Riders bring two to click.",
		tip = "You summon alone. Riders bring two friends to click the portal." },
	{ id = "friends", title = "My friends help", glyph = "ride",
		text = "They click the portal. Warlocks can summon too.",
		tip = "Friends in your group click the portal (any class). Warlock friends can summon too." },
	{ id = "multi", title = "My other characters", glyph = "star",
		text = "Each window says yes once.",
		tip = "You multibox. Your other windows summon and click; each says yes once." },
}

-- a runner who isn't a Warlock needs one to cast (SPEC4 1.1): step 1 says so
local CHOICES_OTHER = {
	{ id = "solo", title = "Just me", glyph = "summon", off = true,
		tip = "You need a Warlock to cast: pick one in the next step." },
	{ id = "friends", title = "A Warlock friend", glyph = "ride",
		text = "You invite and take the gold.",
		tip = "A Warlock friend in your group casts. You invite, set the price and look after riders." },
	{ id = "multi", title = "My other account", glyph = "star",
		text = "Each window says yes once.",
		tip = "Your own Warlock in another window casts; each window says yes once." },
}

local function isWarlock() return K.IsWarlock and K.IsWarlock() == true end

local function classRole(class)
	return S(class) == "WARLOCK" and "lock" or "helper"
end

local ROLE_TEXT = { lock = "Summons and clicks", helper = "Clicks the portal" }

local function unitClass(unit)
	if not unit then return nil end
	local ok, _, class = pcall(UnitClass, unit)
	return ok and S(class) or nil
end

-- the people a crew list can offer: in my group, not yet in my crew
local function rosterNotCrew()
	local crewKeys = {}
	local crew = dr("Crew")
	if type(crew) == "table" then for _, m in ipairs(crew) do if m.key then crewKeys[m.key] = m end end end
	local out = {}
	local roster = dr("Roster")
	if type(roster) == "table" then
		for _, p in ipairs(roster) do
			if type(p) == "table" and p.key and not crewKeys[p.key] then
				out[#out + 1] = { name = S(p.name) or p.key, key = p.key, class = S(p.class) or unitClass(p.unit) }
			end
		end
	end
	return out
end

-- what an offer row says now: text, colour, and whether "Add anyway" shows
local function offerState(key, name)
	local crew = dr("Crew")
	if type(crew) == "table" then
		for _, m in ipairs(crew) do
			if m.key == key and not m.me then
				if m.app == false then return short(name) .. " doesn't have Wuber: added as a helper without it", "muted" end
				return short(name) .. " joined", "glow"
			end
		end
	end
	local o = type(DR.offers) == "table" and DR.offers[key] or nil
	if type(o) ~= "table" then return nil end
	if o.state == "no" then return short(name) .. " said no", "red" end
	if o.state == "noapp" then return "No answer: " .. short(name) .. " may not have Wuber", "red", true end
	if o.state == "yes" then return short(name) .. " joined", "glow" end
	return "Waiting for " .. short(name) .. " to tap Yes", "muted"
end

-- a person row: name, role line or live offer state, a toggle (pick) or a button
local function personRow(parent)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(INNER, 50)
	r.bg = T.Rounded(r, "card", 12, "BACKGROUND", 0)
	r.disc = T.Circle(r, 30, "panel", "ARTWORK")
	r.disc:SetPoint("LEFT", r, "LEFT", 10, 0)
	r.icon = T.Icon(r, "summon", 15, "glow", "OVERLAY")
	r.icon:SetPoint("CENTER", r.disc, "CENTER")
	r.name = T.Text(r, "body", "white", "LEFT", "bold")
	r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 50, -9)
	r.name:SetPoint("RIGHT", r, "RIGHT", -100, 0)
	r.sub = T.Text(r, "caption", "muted", "LEFT", "regular")
	r.subTop = 9 + T.DrawnSize("body") + 4 -- under the name's line (it sits 9 down), 4 clear
	r.sub:SetPoint("TOPLEFT", r, "TOPLEFT", 50, -r.subTop)
	r.sub:SetPoint("RIGHT", r, "RIGHT", -12, 0)
	r.toggle = T.Toggle(r, true, function(on)
		r.picked = on
		if r.picks and r.person and r.person.key then r.picks[r.person.key] = on end -- (AUD-193) kept by person, not by pooled row
	end)
	r.toggle:SetPoint("RIGHT", r, "RIGHT", -12, 0)
	T.Tip(r.toggle, "In my crew", "On: this person gets a crew offer when you tap Send offers. They must tap Yes on their side.")
	r.btn = T.Pill(r, "Add", "dark", 84, 28)
	r.btn:SetPoint("RIGHT", r, "RIGHT", -10, 0)
	r.btn.fill:SetColor("raised")
	r.btn:HookScript("OnLeave", function(self) if not self.inactive then self.fill:SetColor("raised") end end)
	r:EnableMouse(true)
	T.Tip(r, function() return S(r.person and r.person.name) or "Crew" end, function() return r.tipText end)
	return r
end

local function paintPerson(r, p, mode, picks)
	r.person = p
	r.picks = picks
	r.name:SetText(S(p.name) or "?")
	local role = p.role or classRole(p.class)
	r.icon:SetTexture(T.MEDIA .. (role == "lock" and "summon" or "ride"))
	r.icon:SetVertexColor(T.RGB(role == "lock" and "glow" or "white"))
	local live, colour, anyway = offerState(p.key, p.name)
	-- (AUD-147) the line stops left of the button when one shows; it shrinks, then wraps, never runs behind it
	local btnShown = mode == "add" or mode == "member" or (mode == "pick" and live and anyway and true or false)
	-- "Add anyway" is the longest label: its pill is wider so the words are whole (AUD-147, found by the layout scene)
	local wide = btnShown and (anyway == true) and mode ~= "member"
	r.btn:SetWidth(wide and 104 or 84)
	local right = btnShown and (wide and -120 or -100) or -12
	r.name:SetPoint("RIGHT", r, "RIGHT", btnShown and right or -100, 0)
	r.sub:SetPoint("RIGHT", r, "RIGHT", right, 0)
	r.sub.wuberRoom = INNER - 50 + right
	r.sub:SetText(live or ROLE_TEXT[role])
	UI.FitOrWrap(r.sub)
	-- a line that wraps to two (or more) is taller by the spacing: the row grows with it, never cuts it
	local subLines = r.sub.wuberWrapped and math.max(2, N(r.sub.wuberLines) or 2) or 1
	r:SetHeight(math.max(50, r.subTop + subLines * T.DrawnSize("caption") + (subLines - 1) * T.Spacing("caption") + 2))
	r.sub:SetTextColor(T.RGB(colour or "muted"))
	r.tipText = role == "lock" and "A Warlock: summons and clicks the portal." or "Any other class: clicks the portal."
	r.toggle:Hide()
	r.btn:Hide()
	r.anyway = anyway
	if mode == "pick" then
		if live then
			if anyway then
				r.btn:SetLabel("Add anyway")
				r.btn:Show()
			end
		else
			if picks and p.key then r.picked = picks[p.key] else r.picked = nil end
			if r.picked == nil then r.picked = true end
			r.toggle:SetOn(r.picked)
			r.toggle:Show()
		end
	elseif mode == "add" then
		r.btn:SetLabel(anyway and "Add anyway" or (live and "Ask again" or "Add"))
		r.btn:Show()
	elseif mode == "member" then
		r.btn:SetLabel("Remove")
		r.btn:Show()
	end
	r:Show()
end

-- "Add by name": a field and an Add pill; onAdd(name)
local function addByName(parent, onAdd)
	local box = CreateFrame("Frame", nil, parent)
	box:SetSize(INNER, 36)
	local function submit()
		-- (the ends are trimmed for the player; a double space inside is still refused, so ValidName gets the text as typed)
		local typed = tostring(box.field:Text() or ""):gsub("^%s+", ""):gsub("%s+$", "")
		local name = W.Clean(typed, 48)
		if name == "" then toast("Type a name first", "warn") return end
		if dr("ValidName", typed) == false then
			toast("That isn't a player's name. Type the name as the game shows it (each part 2 to 12 letters), with -Realm for another realm.", "warn")
			return
		end
		box.field:SetText("")
		pcall(box.field.edit.ClearFocus, box.field.edit)
		onAdd(name)
	end
	box.field = T.Field(box, INNER - 92, 34, { placeholder = "Name or Name-Realm", max = 48, onEnter = submit })
	box.field:SetPoint("LEFT", box, "LEFT", 0, 0)
	box.add = T.Pill(box, "Add", "dark", 84, 34)
	box.add:SetPoint("RIGHT", box, "RIGHT", 0, 0)
	safeScript(box.add, "OnClick", submit)
	T.Tip(box.add, "Add by name", "Sends a crew offer to this player. They tap Yes in their Wuber. Someone without Wuber can be added anyway as a helper.")
	T.Tip(box.field.edit, "Add by name", "A player who isn't in your group yet: type their name (with -Realm if they're on another realm).")
	return box
end

local function offer(name)
	local ok, why = dr("OfferCrew", name)
	if ok then
		toast("Crew offer sent to " .. short(name), "info")
	elseif why == "badname" then
		toast("That isn't a player's name. Type the name as the game shows it (each part 2 to 12 letters), with -Realm for another realm.", "warn")
	elseif why == "member" then
		toast("Only your crew's captain can add people", "warn")
	else
		toast("Couldn't send the offer to " .. short(name), "warn")
	end
	D.Refresh(true)
	return ok and true or false
end

local function stepOne(w, c)
	local y = 4
	w.q1 = T.Text(c, "title", "white", "LEFT", "bold")
	w.q1:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
	w.q1:SetText("Who summons with you?")
	y = y + 30
	local sub = para(c, "caption", "muted", INNER - 8, 2)
	sub:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
	sub:SetText("You and two who click the portal. You can change this later.")
	w.q1sub = sub
	y = y + 40
	w.choices = {}
	for i, ch in ipairs(CHOICES) do
		local b = T.ListButton(c, INNER, 78, ch.title, nil, ch.glyph, i == 2 and "glow" or "glow")
		b:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		b.sub2 = para(b, "caption", "muted", INNER - 66, 2)
		b.sub2:SetPoint("TOPLEFT", b, "TOPLEFT", 50, -38)
		b.sub2:SetText(ch.text)
		b.label:ClearAllPoints()
		b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 50, -16)
		b.label:SetPoint("RIGHT", b, "RIGHT", -40, 0)
		b.disc:ClearAllPoints()
		b.disc:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -12)
		b.edge = T.EdgeGlow(b, "glow", 0)
		b.tick = T.Icon(b, "check", 14, "ink", "OVERLAY")
		b.tick:SetPoint("TOPRIGHT", b, "TOPRIGHT", -14, -16)
		b.tick:Hide()
		b.id = ch.id
		safeScript(b, "OnClick", function(self)
			if self.off then
				toast(self.offText or "Pick another one", "info")
				return
			end
			w.choice = self.id
			w.paint()
		end)
		T.Tip(b, function(self) return self.label.wuberText end, function(self) return self.offText or self.tipText end)
		-- the card's own OnLeave goes back to plain; a picked card keeps its lighter colour
		b:HookScript("OnLeave", function(self) if self.id == w.choice then self.bg:SetColor("glow") end end)
		b:HookScript("OnEnter", function(self) if self.id == w.choice then self.bg:SetColor("glow") end end)
		w.choices[i] = b
		y = y + 86
	end
	-- the words for this character's class (any class can run a service)
	function w.paintOne()
		local lock = isWarlock()
		w.q1:SetText(lock and "Who summons with you?" or "Who casts?")
		w.q1sub:SetText(lock and "You and two who click the portal. You can change this later."
			or "One Warlock casts. Two more click the portal.")
		local y = 74
		for i, b in ipairs(w.choices) do
			local ch = lock and CHOICES[i] or CHOICES_OTHER[i]
			b.label:SetText(ch.title)
			local sub = ch.text or ""
			b.sub2:SetText(sub)
			setShown(b.sub2, sub ~= "")
			local bh = sub == "" and 54 or 78
			b:SetHeight(bh)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
			b.tipText = ch.tip or ch.text
			b.off = ch.off == true
			b.offText = ch.off and (ch.tip or ch.text) or nil
			b:SetAlpha(b.off and 0.45 or 1)
			y = y + bh + 8
		end
		if w.choice and not lock and w.choice == "solo" then w.choice = nil end
		return y
	end
	return y
end

local function stepTwo(w, c)
	local y = 4
	local q = T.Text(c, "title", "white", "LEFT", "bold")
	q:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
	q:SetText("Pick your crew")
	y = y + 30
	w.q2sub = para(c, "caption", "muted", INNER - 8, 2)
	w.q2sub:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
	y = y + 40
	w.top2 = y
	w.people = Pool(c, personRow)
	w.none = para(c, "sub", "muted", INNER - 8, 3)
	w.adder = addByName(c, function(name)
		if offer(name) then -- (AUD-224) a refused name is not listed
			w.extra = w.extra or {}
			w.extra[#w.extra + 1] = { name = name, key = W.Key(name) }
			w.sent = true
		end
		w.paint()
	end)
	-- (Design 2) on the page's bar, not in the scrolling step: the main button's place until the offers are sent, then a link above Next
	w.send = T.MainButton(w.bar, "Send offers")
	w.send:Hide()
	safeScript(w.send, "OnClick", function()
		local n = 0
		for _, r in ipairs(w.people.list) do
			if r:IsShown() and r.person and r.toggle:IsShown() and r.picked then
				offer(r.person.name)
				n = n + 1
			end
		end
		-- (AUD-207) those who have not answered (waiting, or no answer) get the offer again, as Crew's Ask again does
		for _, r in ipairs(w.people.list) do
			local p = r:IsShown() and r.person or nil
			local o = p and p.key and type(DR.offers) == "table" and DR.offers[p.key] or nil
			if type(o) == "table" and o.state ~= "yes" and o.state ~= "no" and not r.toggle:IsShown() then
				offer(p.name)
				n = n + 1
			end
		end
		if n == 0 then toast("Pick someone first, or add a name", "warn") return end
		w.sent = true
		w.paint()
	end)
	T.Tip(w.send, "Send offers", "Each person you picked gets one card: \"Join your summoning crew?\" They tap Yes or No thanks. Nobody joins without their own click.")
end

-- the people step 2 lists: my group (not yet crew), the names added, and the crew so far
local function wizardPeople(w)
	local out, seen = {}, {}
	local crew = dr("Crew")
	if type(crew) == "table" then
		for _, m in ipairs(crew) do
			if not m.me and m.key then
				seen[m.key] = true
				out[#out + 1] = { name = m.name, key = m.key, role = m.role }
			end
		end
	end
	for _, p in ipairs(rosterNotCrew()) do
		if not seen[p.key] then
			seen[p.key] = true
			out[#out + 1] = p
		end
	end
	for _, p in ipairs(w.extra or {}) do
		if p.key and not seen[p.key] then
			seen[p.key] = true
			out[#out + 1] = p
		end
	end
	return out
end

local function paintTwo(w, c)
	local multi = w.choice == "multi"
	w.q2sub:SetText(multi and "Your other characters in this group. Each window shows a card: tap Yes there once."
		or "People in your group now. Warlocks summon and click; anyone else clicks the portal.")
	local y = w.top2
	local list = wizardPeople(w)
	for i, p in ipairs(list) do
		local r = w.people.get(i)
		w.picked = w.picked or {}
		paintPerson(r, p, "pick", w.picked)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		if r.anyway and not r.wired then
			r.wired = true
			safeScript(r.btn, "OnClick", function()
				if r.person then
					if dr("AddPlainHelper", r.person.name, (r.person.role or classRole(r.person.class)) == "lock" and "lock" or nil) then
						toast(short(r.person.name) .. " added as a helper (without Wuber)", "info")
					else
						toast("Crew is full (" .. (tonumber(DR.CREW_MAX) or 8) .. ")", "warn")
					end
					D.Refresh(true)
					w.paint()
				end
			end)
			T.Tip(r.btn, "Add anyway", "Trusts them on this window only: they're never treated as a rider. They don't get the portal call.")
		end
		-- a row that grew for a wrapped status line moves the next one down with it (the usual 50 px row still steps 56)
		y = y + math.max(56, (N(r:GetHeight()) or 50) + 6)
	end
	w.people.hideFrom(#list)
	if #list == 0 then
		w.none:ClearAllPoints()
		w.none:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
		w.none:SetText(multi and "Nobody in your group yet. Invite your other characters, then they show here."
			or "Nobody in your group yet. Invite your friends, then they show here. Or add a name below.")
		w.none:Show()
		y = y + 50
	else
		w.none:Hide()
	end
	w.adder:ClearAllPoints()
	w.adder:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -(y + 4))
	y = y + 48
	w.send:SetLabel(w.sent and "Send offers again" or "Send offers")
	return y + 10
end

-- Step 3, "Who summons?" (SPEC4 4): the crew's Warlocks (and me, if I am one) with a tick
-- each and arrows for the order; the first ticked is the main caster. Then the checks.

-- who can summon: me (a Warlock) and the crew's Warlocks, with or without Wuber
local function summonerChoices()
	local out, seen = {}, {}
	if isWarlock() and W.myKey then
		out[1] = { key = W.myKey, name = W.Me and W.Me() or "Me", me = true, app = true, shards = dr("Shards") }
		seen[W.myKey] = true
	end
	local crew = dr("Crew")
	if type(crew) == "table" then
		for _, m in ipairs(crew) do
			if type(m) == "table" and m.key and not m.me and not seen[m.key] and m.role == "lock" then
				seen[m.key] = true
				out[#out + 1] = { key = m.key, name = S(m.name) or nameOf(m.key), app = m.app ~= false, shards = m.shards, silent = m.silent }
			end
		end
	end
	return out
end

-- the chosen order: the engine's, else the saved one, else me (a Warlock alone)
local function summonerOrder()
	local list = dr("Summoners")
	if type(list) ~= "table" then
		local c = Char()
		list = c and type(c.summoners) == "table" and c.summoners or {}
	end
	local out = {}
	for _, k in ipairs(list) do if S(k) then out[#out + 1] = S(k) end end
	return out
end

local function saveOrder(order)
	local copy = {}
	for i, k in ipairs(order) do copy[i] = k end
	if type(DR.SetSummoners) == "function" then
		dr("SetSummoners", copy)
	else
		local c = Char()
		if c then c.summoners = copy end
	end
	call(DR.Changed)
	D.Refresh(true)
end
D.SaveSummoners = saveOrder

local function indexOf(list, v)
	for i, x in ipairs(list) do if x == v then return i end end
	return nil
end

-- an arrow button (the "back" chevron turned up or down)
local function arrow(parent, up)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(24, 24)
	b:RegisterForClicks("LeftButtonUp")
	b.bg = T.Circle(b, 22, "panel", "BACKGROUND")
	b.bg:SetPoint("CENTER", b, "CENTER")
	b.icon = T.Icon(b, "back", 10, "white", "OVERLAY")
	b.icon:SetPoint("CENTER", b, "CENTER")
	Try(b.icon, "SetRotation", up and (-math.pi / 2) or (math.pi / 2))
	safeScript(b, "OnEnter", function(self) self.bg:SetVertexColor(T.RGB("hover")) end)
	safeScript(b, "OnLeave", function(self) self.bg:SetVertexColor(T.RGB("panel")) end)
	T.Press(b, { fill = b.bg })
	return b
end

-- one summoner row: order number, name, what we know, the tick, up / down
local function summonerRow(parent, onTick, onMove)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(INNER, 50)
	r.bg = T.Rounded(r, "card", 12, "BACKGROUND", 0)
	r.disc = T.Circle(r, 30, "panel", "ARTWORK")
	r.disc:SetPoint("LEFT", r, "LEFT", 10, 0)
	r.num = T.Text(r, "body", "white", "CENTER", "bold")
	r.num:SetPoint("CENTER", r.disc, "CENTER", 0, 0)
	r.icon = T.Icon(r, "summon", 15, "muted", "OVERLAY")
	r.icon:SetPoint("CENTER", r.disc, "CENTER")
	r.name = T.Text(r, "body", "white", "LEFT", "bold")
	r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 50, -9)
	r.name:SetPoint("RIGHT", r, "RIGHT", -112, 0)
	r.sub = T.Text(r, "caption", "muted", "LEFT", "regular")
	r.sub:SetPoint("TOPLEFT", r, "TOPLEFT", 50, -27)
	r.sub:SetPoint("RIGHT", r, "RIGHT", -112, 0)
	r.toggle = T.Toggle(r, false, function(on) onTick(r, on) end)
	r.toggle:SetPoint("RIGHT", r, "RIGHT", -10, 0)
	T.Tip(r.toggle, "Summons", function()
		return (r.p and r.p.me) and "On: you cast summons too (first in the list = the main caster)."
			or "On: this Warlock casts summons. The first in the list casts; when they can't (no shard, away), the next one does."
	end)
	r.up = arrow(r, true)
	r.up:SetPoint("RIGHT", r.toggle, "LEFT", -6, 0)
	safeScript(r.up, "OnClick", function() onMove(r, -1) end)
	T.Tip(r.up, "Earlier", "Move up the order: the first one casts first.")
	r.down = arrow(r, false)
	r.down:SetPoint("RIGHT", r.up, "LEFT", -2, 0)
	safeScript(r.down, "OnClick", function() onMove(r, 1) end)
	T.Tip(r.down, "Later", "Move down the order: casts only when the ones above can't.")
	r:EnableMouse(true)
	T.Tip(r, function() return S(r.p and r.p.name) or "Warlock" end, function() return r.tipText end)
	return r
end

local function stepThree(w, c)
	local q = T.Text(c, "title", "white", "LEFT", "bold")
	q:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -4)
	q:SetText("Who summons?")
	w.q3sub = para(c, "caption", "muted", INNER - 8, 2)
	w.q3sub:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -34)
	w.q3sub:SetText("Tick the Warlocks who cast. The first one is the main caster; when they can't, the next one does.")
	w.order = {}
	local function onTick(r, on)
		if not r.p then return end
		local i = indexOf(w.order, r.p.key)
		if on and not i then w.order[#w.order + 1] = r.p.key end
		if not on and i then table.remove(w.order, i) end
		saveOrder(w.order)
		w.paint()
	end
	local function onMove(r, d)
		local i = r.p and indexOf(w.order, r.p.key)
		if not i or not w.order[i + d] then return end
		w.order[i], w.order[i + d] = w.order[i + d], w.order[i]
		saveOrder(w.order)
		w.paint()
	end
	w.summoners = Pool(c, function(parent) return summonerRow(parent, onTick, onMove) end)
	w.noLock = para(c, "caption", "red", INNER - 8, 3)
	w.any = T.ListButton(c, INNER, 44, "Whoever clicks first", nil, "ride", "glow")
	w.any.tick = T.Icon(w.any, "check", 14, "ink", "OVERLAY")
	w.any.tick:SetPoint("RIGHT", w.any, "RIGHT", -16, 0)
	safeScript(w.any, "OnClick", function()
		local cv = S((Char() or {}).caster) or ""
		if cv == "-" then
			local first = w.order[1]
			dr("SetCaster", (not first or first == W.myKey) and "" or nameOf(first))
		else
			dr("SetCaster", "-")
		end
		w.paint()
	end)
	w.any:HookScript("OnLeave", function(self)
		if S((Char() or {}).caster) == "-" then self.bg:SetColor("glow") end
	end)
	w.any:HookScript("OnEnter", function(self)
		if S((Char() or {}).caster) == "-" then self.bg:SetColor("glow") end
	end)
	T.Tip(w.any, "Whoever clicks first", "On: no main caster. Any ticked Warlock casts when they click their big button first. Click again for the order above.")
	w.checkHead = T.Text(c, "caption", "glow", "LEFT", "bold")
	w.checkHead:SetText("Ready to drive")
	w.checks = Pool(c, function(parent)
		local l = CreateFrame("Frame", nil, parent)
		l:SetSize(INNER - 8, 30)
		l.icon = T.Icon(l, "check", 13, "glow", "OVERLAY")
		l.icon:SetPoint("LEFT", l, "LEFT", 0, 0)
		l.text = T.Text(l, "caption", "white", "LEFT", "regular")
		l.text:SetPoint("LEFT", l, "LEFT", 22, 0)
		l.text:SetWidth(INNER - 32)
		T.Lines(l.text, 2)
		l:EnableMouse(true)
		T.Tip(l, "Ready to drive", function(self) return self.tipText end)
		return l
	end)
	w.bell = T.Pill(c, "I have a second account to alert", "ghost", INNER, 30)
	w.bell.label:SetTextColor(T.RGB("glow"))
	safeScript(w.bell, "OnClick", function()
		if UI.OpenSettings then call(UI.OpenSettings, "bell") end
	end)
	T.Tip(w.bell, "Alert character", "A character on another account that flashes and beeps when one of your windows needs a click. Set it in Settings.")
end

-- keep Step 3 true to the engine: when the summoners change while it is open (a Warlock
-- says Yes, someone leaves), take over what changed in the engine's order; drop keys that can no longer summon
local function syncOrder(w, list)
	local now = summonerOrder()
	local seen = table.concat(now, ",")
	if seen ~= w.orderSeen then
		-- take over only what changed in the engine since the last read; the captain's own
		-- unsaved ticks and order stay as they are
		local was, isNow = {}, {}
		for k in string.gmatch(w.orderSeen or "", "[^,]+") do was[k] = true end
		for _, k in ipairs(now) do isNow[k] = true end
		for i = #w.order, 1, -1 do
			if was[w.order[i]] and not isNow[w.order[i]] then table.remove(w.order, i) end
		end
		for _, k in ipairs(now) do
			if not was[k] and indexOf(w.order, k) == nil then w.order[#w.order + 1] = k end
		end
		w.orderSeen = seen
	end
	local can = {}
	for _, p in ipairs(list) do can[p.key] = true end
	for i = #w.order, 1, -1 do
		if not can[w.order[i]] then table.remove(w.order, i) end
	end
end

local function paintThree(w, c)
	local y = 34 + (w.q3sub.paraH or 30) + 10
	local list = summonerChoices()
	syncOrder(w, list)
	-- the ticked ones first, in their order, then the others
	local pos = {}
	for i, k in ipairs(w.order) do pos[k] = i end
	table.sort(list, function(a, b)
		local pa, pb = pos[a.key] or 99, pos[b.key] or 99
		if pa ~= pb then return pa < pb end
		return (a.name or "") < (b.name or "")
	end)
	for i, p in ipairs(list) do
		local r = w.summoners.get(i)
		r.p = p
		local n = pos[p.key]
		r.name:SetText(p.me and ("You (" .. short(p.name) .. ")") or short(p.name))
		local bits = {}
		if n == 1 then bits[#bits + 1] = "main caster" elseif n then bits[#bits + 1] = "casts " .. (({ "", "second", "third" })[n] or (n .. "th")) end
		if not p.app then bits[#bits + 1] = "no Wuber" end
		if N(p.shards) and p.app then bits[#bits + 1] = plural(p.shards, "shard") end
		if p.silent and p.app then bits[#bits + 1] = "not heard lately" end
		r.sub:SetText(#bits > 0 and table.concat(bits, " · ") or "Tick to summon")
		r.sub:SetTextColor(T.RGB(n and "glow" or "muted"))
		r.num:SetText(n and tostring(n) or "")
		setShown(r.icon, not n)
		r.toggle:SetOn(n ~= nil)
		setShown(r.up, n ~= nil and n > 1)
		setShown(r.down, n ~= nil and w.order[n + 1] ~= nil)
		r.tipText = p.app and "A Warlock with Wuber: their big button casts when it's their turn."
			or "A Warlock without Wuber: when it's their turn, your big button asks them in party chat to summon the rider."
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		r:Show()
		y = y + 56
	end
	w.summoners.hideFrom(#list)
	if #list == 0 or (#w.order == 0 and not isWarlock()) then
		w.noLock:ClearAllPoints()
		w.noLock:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
		w.noLock:SetText(#list == 0 and "No Warlock in your crew yet. Go Back and add your Warlock friend (or your own Warlock), then tick them here."
			or "Tick at least one Warlock: someone has to cast.")
		w.noLock:Show()
		y = y + (w.noLock.paraH or 30) + 8
	else
		w.noLock:Hide()
	end
	-- "Whoever clicks first": with two or more ticked
	local cv = S((Char() or {}).caster) or ""
	if #w.order >= 2 then
		w.any:ClearAllPoints()
		w.any:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		setShown(w.any.tick, cv == "-")
		w.any.bg:SetColor(cv == "-" and "glow" or "card")
		w.any.label:SetTextColor(T.RGB(cv == "-" and "ink" or "white"))
		w.any:Show()
		y = y + 52
	else
		w.any:Hide()
	end
	y = y + 6
	w.checkHead:ClearAllPoints()
	w.checkHead:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
	y = y + 22
	local lines = dr("Readiness")
	local i = 0
	if type(lines) == "table" then
		for _, l in ipairs(lines) do
			if type(l) == "table" and S(l.text) then
				i = i + 1
				local row = w.checks.get(i)
				local bad = l.ok == false
				row.icon:SetTexture(T.MEDIA .. (bad and "close" or (l.ok and "check" or "star")))
				row.icon:SetVertexColor(T.RGB(bad and "red" or (l.ok and "glow" or "muted")))
				row.text:SetText(l.text)
				row.tipText = bad and (l.text .. " Fix it on your console's Ready card.") or l.text
				row.text:SetTextColor(T.RGB(bad and "red" or "white"))
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
				row:Show()
				y = y + 32
			end
		end
	end
	w.checks.hideFrom(i)
	w.bell:ClearAllPoints()
	w.bell:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -(y + 6))
	return y + 44
end

D.screens.wizard = function(parent)
	local w = Screen(parent, "Set up driving", 64)
	st.wizard = w
	w.step = 1
	w.dots = {}
	for i = 1, 3 do
		local d = T.Circle(w.frame, 8, "line", "OVERLAY")
		d:SetPoint("RIGHT", w.frame, "TOPRIGHT", -16 - (3 - i) * 14, -24)
		w.dots[i] = d
	end
	w.right:Hide()
	w.pages = {}
	for i = 1, 3 do
		local pg = CreateFrame("Frame", nil, w.content)
		pg:SetAllPoints(w.content)
		pg:Hide()
		w.pages[i] = pg
	end
	stepOne(w, w.pages[1])
	stepTwo(w, w.pages[2])
	stepThree(w, w.pages[3])
	-- (Design 2) one main button at the bottom: Next (Send offers on step 2 until they are sent); the way back is the
	-- chevron at the top (Screen's s.back, which asks w.onBack), so there is no Back button here any more
	w.next = T.MainButton(w.bar, "Next")
	w.skip = T.Pill(w.bar, "Skip for now", "ghost", 200, 30)
	w.skip:SetPoint("BOTTOM", w.bar, "BOTTOM", 0, T.MAIN.foot + T.MAIN.h + 6)
	w.skip.label:SetTextColor(T.RGB("muted"))
	w.skip:Hide()
	T.Tip(w.skip, "Skip for now", "The next step.")
	-- step 3 starts from the saved order (a Warlock alone: just me)
	local function loadOrder()
		w.order = summonerOrder()
		w.orderSeen = table.concat(w.order, ",")
		if #w.order == 0 and isWarlock() and W.myKey then w.order = { W.myKey } end
	end
	-- (design 2, N) the next step comes in from the right over the one before, a step back is the mirror (A.Push,
	-- A.PopPage), cut off by the scroll area. Only one step is on screen during the move (opts.single): the step that goes is
	-- hidden when it starts. (w.leaving stays nil: w.paint shows the current step only.)
	local function go(step)
		local from = w.pages[w.step]
		local back = step < w.step
		local clip = Try(w.content, "GetParent") or w.scroll
		A.StopPage(clip)
		w.step = step
		if step == 3 then loadOrder() end
		w.scroll:ScrollTo(0, true)
		local leaving = from ~= w.pages[step] and from or nil
		w.leaving = nil
		w.paint()
		local opts = { clip = clip, secure = true, single = true, onDone = function()
			w.leaving = nil
			w.paint()
		end }
		if not leaving then
			A.Push(w.pages[step], nil, opts)
		elseif back then
			A.PopPage(from, w.pages[step], opts)
		else
			A.Push(w.pages[step], from, opts)
		end
	end
	w.onBack = function()
		if w.step > 1 then
			go((w.step == 3 and w.choice == "solo") and 1 or w.step - 1)
			return true
		end
		return false
	end
	safeScript(w.skip, "OnClick", function() go(3) end)
	safeScript(w.next, "OnClick", function()
		if w.step == 1 then
			if not w.choice then toast("Pick one of the three first", "warn") return end
			go(w.choice == "solo" and 3 or 2)
		elseif w.step == 2 then
			go(3)
		else
			local c = Char()
			if c then c.wizard = true end
			if w.choice == "solo" then dr("SetCaster", "") end
			if #w.order == 0 and isWarlock() and W.myKey then w.order = { W.myKey } end
			saveOrder(w.order)
			call(DR.Changed)
			W.Sound("found")
			toast("You're set up. Press Open when you're ready.", "found")
			D.ShowScreen("console")
		end
	end)
	T.Tip(w.next, function() return w.step == 3 and "Done" or "Next" end, function()
		if w.step == 3 then
			if #w.order == 0 and not isWarlock() then return "Finish the setup. Nobody is ticked to summon yet: your console will ask you to choose." end
			return "Finish the setup and go back to your console. Press Open there to take riders."
		end
		return "The next step."
	end)
	function w.paint()
		for i = 1, 3 do
			setShown(w.pages[i], i == w.step or (w.leaving ~= nil and w.pages[i] == w.leaving))
			w.dots[i]:SetVertexColor(T.RGB(i == w.step and "glow" or (i < w.step and "muted" or "line")))
		end
		local h = 300
		local pre2 = w.step == 2 and not w.sent -- step 2, nobody asked yet: Send offers is the main button
		local room = pre2 and 98 or (w.step == 2 and 98 or 64)
		w.bar:SetHeight(room)
		w.scroll:ClearAllPoints()
		w.scroll:SetPoint("TOPLEFT", w.frame, "TOPLEFT", 0, -50)
		w.scroll:SetPoint("BOTTOMRIGHT", w.frame, "BOTTOMRIGHT", 0, room)
		setShown(w.next, not pre2)
		setShown(w.skip, pre2)
		setShown(w.send, w.step == 2)
		if w.step == 2 and w.sent then
			-- already asked: "Send offers again" is a link above Next
			w.send:SetStyle("ghost")
			w.send:ClearAllPoints()
			w.send:SetPoint("BOTTOM", w.bar, "BOTTOM", 0, T.MAIN.foot + T.MAIN.h + 6)
			w.send:SetSize(200, 30)
		elseif w.step == 2 then
			w.send:SetStyle("primary")
			w.send:ClearAllPoints()
			w.send:SetPoint("BOTTOMLEFT", w.bar, "BOTTOMLEFT", T.MAIN.side, T.MAIN.foot)
			w.send:SetPoint("BOTTOMRIGHT", w.bar, "BOTTOMRIGHT", -T.MAIN.side, T.MAIN.foot)
			w.send:SetHeight(T.MAIN.h)
		end
		w.next:SetStyle("primary")
		if w.step == 1 then
			h = w.paintOne()
			for _, b in ipairs(w.choices) do
				local on = b.id == w.choice
				b.edge:SetColor("glow", on and 0.9 or 0)
				b.bg:SetColor(on and "glow" or "card")
				b.label:SetTextColor(T.RGB(on and "ink" or "white"))
				b.sub2:SetTextColor(T.RGB(on and "ink" or "muted"))
				setShown(b.tick, on)
			end
			w.next:SetLabel("Next")
			w.next:SetActive(w.choice ~= nil)
		elseif w.step == 2 then
			h = paintTwo(w, w.pages[2])
			w.next:SetLabel("Next")
			w.next:SetActive(true)
		else
			h = paintThree(w, w.pages[3])
			w.next:SetLabel("Done")
			w.next:SetActive(true)
		end
		w.scroll:SetContentHeight(h + 10)
	end
	-- enter(3): straight to "Who summons?" (the console's "Choose who summons" fix)
	w.enter = function(arg)
		w.step = 1
		w.sent = nil
		w.picked = {}
		local c = Char()
		local n = 0
		local crew = dr("Crew")
		if type(crew) == "table" then for _, m in ipairs(crew) do if not m.me then n = n + 1 end end end
		w.choice = n > 0 and "friends" or ((c and c.wizard and isWarlock()) and "solo" or nil)
		if tonumber(arg) == 3 then
			w.step = 3
			w.choice = w.choice or "friends"
		end
		loadOrder()
		w.scroll:ScrollTo(0, true)
	end
	w.update = function() w.paint() end
	return w
end

-- for other modules (REFACTOR-MAP section 2): set at the end, when every local holds its final value
Mod.ROLE_TEXT = ROLE_TEXT
Mod.classRole = classRole
Mod.addByName = addByName
Mod.indexOf = indexOf
Mod.isWarlock = isWarlock
Mod.offer = offer
Mod.paintPerson = paintPerson
Mod.personRow = personRow
Mod.rosterNotCrew = rosterNotCrew
Mod.saveOrder = saveOrder

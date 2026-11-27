-- Module: UI.Driver.Crew
-- Purpose: The Crew screen.
-- API: D.screens.crew
-- Internals: (none)
-- Uses: UI.Driver.Screens, UI.Driver.Wizard
-- Later: UI.Driver.Customers (D.CrewOwnMark: the "My own account" switch on member cards, round 9)
-- Events: SETTINGS
-- Standalone: no
-- Test: tests/ui/driver/crew_test.lua
-- From: UI_Drive.lua 879-1120 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Driver.Crew", { "UI.Driver.Screens", "UI.Driver.Wizard" })
local ScreensMod = W.Mod("UI.Driver.Screens")
local WizardMod = W.Mod("UI.Driver.Wizard")
local INNER, PAD, Pool, Screen = ScreensMod.INNER, ScreensMod.PAD, ScreensMod.Pool, ScreensMod.Screen
local call, dr, nameOf, opts, para, plural = ScreensMod.call, ScreensMod.dr, ScreensMod.nameOf, ScreensMod.opts, ScreensMod.para, ScreensMod.plural
local safeScript, setShown, short, st = ScreensMod.safeScript, ScreensMod.setShown, ScreensMod.short, ScreensMod.st
local toast = ScreensMod.toast
local ROLE_TEXT, addByName, offer, paintPerson = WizardMod.ROLE_TEXT, WizardMod.addByName, WizardMod.offer, WizardMod.paintPerson
local personRow, rosterNotCrew = WizardMod.personRow, WizardMod.rosterNotCrew
local T = W.Theme

local D = W.Driver

local S, N = W.Str, W.Num

local function adv() return type(W.Advanced) == "function" and W.Advanced() == true end

local function setOpt(key, v)
	local d = W.Drive
	if type(d) == "table" and type(d.SetOpt) == "function" then call(d.SetOpt, key, v) else opts()[key] = v end
	W.Fire("SETTINGS", "drive." .. key)
end

local function splitCard(parent, title, desc, tip, h)
	local r = T.Card(parent, INNER, h, { colour = "card", radius = 14, shadow = false })
	r.title = T.Text(r, "body", "white", "LEFT", "bold")
	r.title:SetPoint("TOPLEFT", r, "TOPLEFT", 14, -10)
	r.title:SetWidth(INNER - 28)
	r.title:SetText(title)
	r.desc = T.Text(r, "caption", "muted", "LEFT", "regular")
	r.desc:SetPoint("TOPLEFT", r, "TOPLEFT", 14, -27)
	r.desc:SetWidth(INNER - 28)
	r.desc:SetText(desc)
	r:EnableMouse(true)
	T.Tip(r, title, tip)
	return r
end

---------------------------------------------------------------------------
-- Crew: who is in it (remove), who could be (add), add by name, leave (members)
---------------------------------------------------------------------------

-- The Stations card (SPEC4 2.1, only with 2+): each place a crew summoner stands, who is
-- there, a ready dot, and (for the captain) a switch to stop summoning there.
local function stationRow(parent)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(INNER - 24, 44)
	r.dot = T.Circle(r, 10, "glow", "ARTWORK")
	r.dot:SetPoint("TOPLEFT", r, "TOPLEFT", 2, -9)
	r.place = T.Text(r, "body", "white", "LEFT", "bold")
	r.place:SetPoint("TOPLEFT", r, "TOPLEFT", 20, -5)
	r.place:SetPoint("RIGHT", r, "RIGHT", -56, 0)
	r.who = T.Text(r, "caption", "muted", "LEFT", "regular")
	r.who:SetPoint("TOPLEFT", r, "TOPLEFT", 20, -23)
	r.who:SetPoint("RIGHT", r, "RIGHT", -56, 0)
	r.toggle = T.Toggle(r, true, function(on)
		if r.placeName then
			dr("SetStation", r.placeName, on)
			toast(on and ("Summoning at " .. r.placeName .. " again") or ("No more riders for " .. r.placeName), "info")
			D.Refresh(true)
		end
	end)
	r.toggle:SetPoint("RIGHT", r, "RIGHT", 0, 0)
	T.Tip(r.toggle, "Summon here", function()
		return "On: riders who want " .. tostring(r.placeName) .. " are summoned there. Off: they're told the places you do summon to."
	end)
	r:EnableMouse(true)
	T.Tip(r, function() return r.placeName or "Station" end, function() return r.tipText end)
	return r
end

local function whoText(st)
	local names = {}
	for _, k in ipairs(type(st.summoners) == "table" and st.summoners or {}) do names[#names + 1] = short(nameOf(k)) end
	local helpers = type(st.helpers) == "table" and #st.helpers or 0
	local t = #names > 0 and table.concat(names, ", ") or "no summoner"
	if helpers > 0 then t = t .. " + " .. plural(helpers, "helper") end
	return t
end

-- the "my account" switch and its label on a member card: the card is a little taller so the
-- label clears the bottom edge, and the pair sits 8 px further left so the label clears Remove.
local CARD_H, CARD_STEP = 60, 66
local EXTRA_H = 12 -- a news line too long for one row wraps to a second line and the card grows by this
local function fitSub(r)
	local extra = 0
	local room = r.sub:GetWidth() or 0
	local text = r.sub.wuberText or ""
	local long = room > 0 and T.MeasureText(text, "caption", "regular") > room
	r.sub:SetWordWrap(long and true or false)
	if long then
		local lines, cur = 1, ""
		for word in text:gmatch("%S+") do
			local try = cur == "" and word or (cur .. " " .. word)
			if cur ~= "" and T.MeasureText(try, "caption", "regular") > room * 0.9 then lines, cur = lines + 1, word else cur = try end
		end
		extra = EXTRA_H * (lines - 1)
		r.sub:SetHeight(EXTRA_H * lines + 2)
	else
		r.sub:SetHeight(12)
	end
	return extra
end
local function spaceOwn(r)
	r:SetHeight(CARD_H + fitSub(r))
	if not (r.own and r.ownLabel and r.own:IsShown()) then return end
	local right = (r.btn and r.btn:IsShown()) and 110 or 20
	r.own:ClearAllPoints()
	r.own:SetPoint("RIGHT", r, "RIGHT", -right, 8)
	r.ownLabel:SetWidth(72) -- (design 3) "my account" measures 65 at the smallest size
	r.ownLabel:ClearAllPoints()
	r.ownLabel:SetPoint("TOP", r.own, "BOTTOM", 0, -4)
end

local function drawStations(s, c, y, captain)
	local list = D.Stations and D.Stations() or {}
	if #list < 2 then
		if s.stCard then s.stCard:Hide() end
		return y
	end
	if not s.stCard then
		local card = T.Card(c, INNER, 60, { colour = "card", radius = 14, shadow = false, border = "line" })
		card.head = T.Text(card, "caption", "glow", "LEFT", "bold")
		card.head:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
		card.head:SetText("Stations")
		card.note = T.Text(card, "caption", "muted", "RIGHT", "regular")
		card.note:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -12)
		card.note:SetWidth(200)
		card.rows = Pool(card, stationRow)
		card:EnableMouse(true)
		T.Tip(card, "Stations", "Your crew's summoners stand in different places. Each Warlock summons riders who want the place they stand in.")
		s.stCard = card
	end
	local card = s.stCard
	card.note:SetText("one price for all")
	local ry = 32
	for i, st in ipairs(list) do
		local r = card.rows.get(i)
		local ready = D.StationReady and D.StationReady(st)
		local on = st.open ~= false
		r.placeName = S(st.place)
		r.place:SetText(S(st.place))
		r.place:SetTextColor(T.RGB(on and "white" or "muted"))
		r.who:SetText(whoText(st) .. (on and (ready and " · ready" or " · riders bring a friend") or " · off"))
		r.dot:SetVertexColor(T.RGB(not on and "off" or (ready and "glow" or "muted")))
		r.toggle:SetOn(on)
		setShown(r.toggle, captain)
		r.tipText = ready and "A summoner and two more to click the portal are there."
			or "Fewer than three there: riders are asked to bring a friend to click the portal."
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -ry)
		r:Show()
		ry = ry + 46
	end
	card.rows.hideFrom(#list)
	card:SetHeight(ry + 6)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
	card:Show()
	return y + ry + 6 + 12
end

D.screens.crew = function(parent)
	local s = Screen(parent, "Your crew")
	st.screens.crew = s
	local c = s.content
	s.intro = para(c, "caption", "muted", INNER - 8, 2)
	s.intro:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -4)
	s.head1 = T.Text(c, "caption", "glow", "LEFT", "bold")
	s.head1:SetText("In your crew")
	s.members = Pool(c, function(p)
		local r = personRow(p)
		safeScript(r.btn, "OnClick", function()
			if not r.person then return end
			dr("RemoveCrew", r.person.name)
			toast(short(r.person.name) .. " is out of your crew", "info")
			D.Refresh(true)
		end)
		T.Tip(r.btn, "Remove", "Takes them out of your crew. They're told, and are treated like anyone else again.")
		return r
	end)
	s.head2 = T.Text(c, "caption", "glow", "LEFT", "bold")
	s.head2:SetText("In your group")
	s.others = Pool(c, function(p)
		local r = personRow(p)
		safeScript(r.btn, "OnClick", function()
			if not r.person then return end
			if r.anyway then
				if dr("AddPlainHelper", r.person.name, (r.person.role or WizardMod.classRole(r.person.class)) == "lock" and "lock" or nil) then
					toast(short(r.person.name) .. " added as a helper (without Wuber)", "info")
				else
					toast("Crew is full (" .. (tonumber(W.Drive.CREW_MAX) or 8) .. " players)", "warn")
				end
				D.Refresh(true)
			else
				offer(r.person.name)
			end
		end)
		T.Tip(r.btn, "Add", "Sends them a crew offer. They tap Yes in their Wuber. No answer? You can add them anyway as a helper.")
		return r
	end)
	s.adder = addByName(c, function(name)
		if offer(name) then -- (AUD-224) a refused name is not listed
			s.extra = s.extra or {}
			s.extra[#s.extra + 1] = { name = name, key = W.Key(name) }
		end
	end)
	s.splitHead = T.Text(c, "caption", "glow", "LEFT", "bold")
	s.splitHead:SetText("Fair split")
	local ruleTip = "By clicks: the Warlocks who cast share their part by casts, everyone else by portal clicks. Equal: everyone who cast or "
		.. "clicked gets the same. Wuber never moves gold: pay your helpers by trade."
	local rr = splitCard(c, "How the shift's gold is split", "Shown on the end-of-shift card.", ruleTip, 84)
	s.cutSeg = T.Segmented(rr, {
		{ value = "clicks", label = "By clicks", tip = "Casters share their part by casts; the rest by clicks." },
		{ value = "equal", label = "Equal", tip = "Everyone who cast or clicked gets the same." },
	}, S(opts().cutRule) or "clicks", function(v)
		setOpt("cutRule", v)
		s.update()
	end, INNER - 28, 30)
	s.cutSeg:SetPoint("BOTTOMLEFT", rr, "BOTTOMLEFT", 14, 12)
	s.cutRuleRow = rr
	local casterTip = "How much of the shift's gold goes to the Warlocks who cast (shared by casts); the rest goes to the clickers."
	local function getCaster() return N(opts().cutCaster) or 40 end
	local cr = splitCard(c, "Casters' part", "with the By clicks rule", casterTip, 94)
	local csl = T.Slider(cr, INNER - 28, {
		min = 0, max = 100, step = 5, value = 40, get = getCaster,
		format = function(v) return math.floor(v + 0.5) .. "%" end,
		onChange = function(v) setOpt("cutCaster", v) end,
	})
	csl.holder:SetPoint("TOPLEFT", cr, "TOPLEFT", 14, -44)
	T.Tip(csl, "Casters' part", casterTip)
	csl.get = getCaster
	cr:SetHeight(44 + (N(csl.holder:GetHeight()) or 40) + 10)
	s.cutCaster = csl
	s.cutCasterRow = cr
	s.wizard = T.Pill(c, "Run the setup again", "ghost", INNER, 32)
	s.wizard.label:SetTextColor(T.RGB("glow"))
	safeScript(s.wizard, "OnClick", function() D.ShowScreen("wizard") end)
	T.Tip(s.wizard, "Run the setup again", "The three-step setup: who summons with you, your crew, the caster and a check.")
	s.leave = T.Pill(c, "Leave this crew", "danger", INNER, 40)
	safeScript(s.leave, "OnClick", function()
		if not s.sure then
			s.sure = true
			s.leave:SetLabel("Click again to leave")
			W.After(4, function() s.sure = nil s.update() end)
			return
		end
		s.sure = nil
		dr("LeaveCrew")
		toast("You left the crew", "info")
		D.ShowScreen("console")
	end)
	T.Tip(s.leave, "Leave this crew", "You stop helping this captain: no more portal calls, their invites aren't accepted for you. Click twice.")
	s.update = function()
		local captain = dr("IsCaptain") ~= false
		local capName = S(dr("Captain"))
		local y = 4
		s.intro:SetText(captain and "Your crew. Warlocks cast and click; others click the portal. Each says yes once."
			or ("You're in " .. nameOf(capName) .. "'s crew: you get the call to click the portal, and their invites are accepted for you."))
		y = y + 40
		y = drawStations(s, c, y, captain)
		s.head1:ClearAllPoints()
		s.head1:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
		y = y + 20
		local i = 0
		local crew = dr("Crew")
		if type(crew) == "table" then
			for _, m in ipairs(crew) do
				if not m.me then
					i = i + 1
					local r = s.members.get(i)
					paintPerson(r, m, captain and "member" or nil)
					local bits = { ROLE_TEXT[m.role] or ROLE_TEXT.helper }
					if m.captain then bits[#bits + 1] = "captain" end
					if m.app == false then bits[#bits + 1] = "no Wuber"
					elseif m.silent then bits[#bits + 1] = "not heard lately" end
					if m.here == false then bits[#bits + 1] = "not in your group" end
					if m.role == "lock" and N(m.shards) then bits[#bits + 1] = plural(m.shards, "shard") end
					-- (round 13, I18) with news to give, the role words go (the icon and the tooltip say the role):
					-- 'Summons and clicks · not in your ...' was cut
					if #bits > 1 then table.remove(bits, 1) end
					r.sub:SetText(table.concat(bits, " · "))
					r.sub:SetTextColor(T.RGB((m.silent or m.here == false) and "red" or "muted"))
					if D.CrewOwnMark then D.CrewOwnMark(r, m) end -- round 9: who gets my customer notes
					spaceOwn(r)
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
					y = y + CARD_STEP + (r:GetHeight() - CARD_H)
				end
			end
		end
		s.members.hideFrom(i)
		if i == 0 then
			i = 1
			local r = s.members.get(1)
			local lock = dr("IsWarlock") ~= false
			paintPerson(r, { name = "Just you", key = W.myKey, role = lock and "lock" or "helper" }, nil)
			r.sub:SetText(lock and "Riders bring two friends to click the portal" or ROLE_TEXT.helper)
			if D.CrewOwnMark then D.CrewOwnMark(r, nil) end
			spaceOwn(r)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
			y = y + CARD_STEP
		end
		local j = 0
		if captain then
			local list = rosterNotCrew()
			for _, p in ipairs(s.extra or {}) do
				local dup = false
				for _, q in ipairs(list) do if q.key == p.key then dup = true end end
				for _, m in ipairs(type(crew) == "table" and crew or {}) do if m.key == p.key then dup = true end end
				if not dup then list[#list + 1] = p end
			end
			if #list > 0 then
				s.head2:ClearAllPoints()
				s.head2:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -(y + 6))
				s.head2:Show()
				y = y + 26
				for _, p in ipairs(list) do
					j = j + 1
					local r = s.others.get(j)
					paintPerson(r, p, "add")
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
					y = y + 56
				end
			else
				s.head2:Hide()
			end
			s.adder:ClearAllPoints()
			s.adder:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -(y + 6))
			s.adder:Show()
			y = y + 50
			if adv() then
				local rule = S(opts().cutRule) or "clicks"
				if rule ~= "equal" then rule = "clicks" end
				if s.cutSeg.value ~= rule then s.cutSeg:SetValue(rule) end
				s.splitHead:ClearAllPoints()
				s.splitHead:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -(y + 6))
				s.splitHead:Show()
				y = y + 26
				s.cutRuleRow:ClearAllPoints()
				s.cutRuleRow:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
				s.cutRuleRow:Show()
				y = y + (N(s.cutRuleRow:GetHeight()) or 84) + 8
				if rule == "clicks" then
					s.cutCasterRow:ClearAllPoints()
					s.cutCasterRow:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
					s.cutCasterRow:Show()
					y = y + (N(s.cutCasterRow:GetHeight()) or 94) + 8
				else
					s.cutCasterRow:Hide()
				end
			else
				s.splitHead:Hide()
				s.cutRuleRow:Hide()
				s.cutCasterRow:Hide()
			end
			s.wizard:ClearAllPoints()
			s.wizard:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -(y + 4))
			s.wizard:Show()
			s.leave:Hide()
			y = y + 44
		else
			s.head2:Hide()
			s.adder:Hide()
			s.splitHead:Hide()
			s.cutRuleRow:Hide()
			s.cutCasterRow:Hide()
			s.wizard:Hide()
			s.leave:ClearAllPoints()
			s.leave:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -(y + 10))
			if not s.sure then s.leave:SetLabel("Leave this crew") end
			s.leave:Show()
			y = y + 56
		end
		s.others.hideFrom(j)
		s.scroll:SetContentHeight(y + 10)
	end
	return s
end

W.Listen("SETTINGS", function(key)
	if key ~= nil and key ~= "advanced" and key ~= "drive.cutRule" and key ~= "drive.cutCaster" then return end
	local s = st.screens.crew
	if s and s.update then call(s.update) end
end)

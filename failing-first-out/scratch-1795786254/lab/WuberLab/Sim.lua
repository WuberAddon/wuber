-- Wuber Lab (developer only, never ship): the shard-free test mode, "Pretend to summon (no shards)".
--
-- Off by default, per session only (never saved). While it is on:
--   driver side  the shard checks pass (DR.SimHooks.shards), the big button's macro keeps /target and
--                has no cast (DR.SimHooks.castLine returns L.SIM_NOOP in its place), and the lab fakes the cast: it feeds
--                UNIT_SPELLCAST_SENT / START / SUCCEEDED / CHANNEL_START, 3 s later CHANNEL_STOP, to
--                Wuber's own event handler (so the CAST / HELP / END facts flow to the crew exactly as
--                for a real cast). A helper's click is faked by the "Pretend I clicked" button.
--   rider side   when the driver's fake cast ends, the driver's lab whispers the rider's lab a hidden
--                addon message (prefix WLAB, kind "SIM"); the rider's lab (it must be on there too)
--                shows "X is summoning you to Y - Accept / Decline". Accept tells the driver's lab, and
--                DR.SimHooks.here then says that rider is here (until they move or 5 minutes).
--   both         a banner "TEST MODE - nobody is really summoned".
--   peers        (review 2.2 #3) the mode only ever touches players whose lab has it on too: a WLAB
--                handshake (SIM~hello / SIM~hi) to the group and to the tester's four characters finds them.
--                Only a peer gets the pretend cast (castLine, shards); anyone else needs a real cast
--                (the button says so). While on, the driver is off the public network (SimHooks.peers:
--                no channel beacon, answers, adverts or requests from anyone else; its peers get its D by
--                whisper); a pretend raid summon posts no /ra line unless the whole group are peers.
-- Nothing here calls a protected function. With the mode off DR.SimHooks is nil: Wuber is untouched.
--
-- Messages (prefix WLAB, fields joined by "~"):
--   SIM~hello                   anyone -> group / the tester's four   the mode is on here: answer if yours is
--   SIM~hi                      the answer (both are peers now)
--   SIM~bye                     the mode went off here: not a peer any more
--   SIM~summon~driver~place     driver -> rider   the fake summon card
--   SIM~accept~rider            rider  -> driver  accepted: treat as arrived (a whisper: the sender
--                                                 is the rider; field 3 only in the driver's relay)
--   SIM~moved~rider             rider  -> driver  declined, or moved after accepting: not arrived any more

local _, L = ...

local show, str, num, call, plain = L.show, L.str, L.num, L.call, L.plain

L.sim = false
if type(L.KINDS) == "table" and not L.KINDS.sim then L.KINDS.sim = "pretend summon (test mode)" end
L.SIM_CHANNEL = 3        -- seconds the fake channel runs
L.SIM_HERE_SECS = 300    -- an accepted rider counts as arrived this long
L.SIM_CARD_SECS = 120    -- the fake card goes away by itself (as the game's does)
L.SIM_SHARDS = 20

local arrived = {}       -- [rider key] = GetTime when they accepted (driver side)
local peers = {}         -- [key] = { name, at }: players whose lab answered the handshake with the mode on
L.SIM_PEER_SECS = 600    -- a peer not heard from for this long is forgotten (the hello repeats every minute)
L.SIM_HELLO_EVERY = 60
local simCasting         -- the pretend cast under way: { guid, id, channel }
local card               -- the rider's fake card frame
local cardFrom           -- the driver named on the card
local acceptedFrom       -- driver key the rider accepted from (rider side)
local banner
local fakeGuid = 0

local function W_() return L.W() end
local function DR_() local W = W_() return W and W.Drive or nil end

local function ritualId()
	local DR = DR_()
	return DR and DR.RITUAL_ID or 698
end

-- One event through Wuber's own handler (never to anything else).
local function feed(event, ...)
	local W = W_()
	local f = W and W.frame
	if type(f) ~= "table" or type(f.GetScript) ~= "function" then return false end
	local handler = call(f.GetScript, f, "OnEvent")
	if type(handler) ~= "function" then return false end
	local ok, err = pcall(handler, f, event, ...)
	if not ok then L.Bug("sim event", err) end
	return ok
end

---------------------------------------------------------------------------
-- The hooks Wuber checks (DR.SimHooks)
---------------------------------------------------------------------------

local hooks = {}

-- Whether `name` runs the lab with the mode on (answered our handshake lately).
local function isPeer(name)
	local k = str(name) and L.Key(name)
	local p = k and peers[k]
	if not p then return false end
	if L.Now() - p.at > L.SIM_PEER_SECS then
		peers[k] = nil
		return false
	end
	return true
end
L.SimPeer = isPeer

-- The shard count Wuber sees; for summoning `name` only when that player is a peer (anyone else
-- needs a real cast, so real shards: nil = Wuber reads the bags).
function hooks.shards(name)
	if not L.sim then return nil end
	if name ~= nil and not isPeer(name) then return nil end
	return L.SIM_SHARDS
end

-- Who may see this driver while the mode is on: the peers ({ [key] = name }, maybe empty).
function hooks.peers()
	if not L.sim then return nil end
	local out = {}
	for k, p in pairs(peers) do
		if L.Now() - p.at <= L.SIM_PEER_SECS then out[k] = p.name end
	end
	return out
end

-- Whether everyone else in the group is a peer (a pretend raid summon may then post its raid line).
function hooks.groupChat()
	if not L.sim then return false end
	local W = W_()
	if not (W and type(W.UnitName) == "function") then return false end
	for _, unit in ipairs({ "party1", "party2", "party3", "party4" }) do
		local n = str(call(W.UnitName, unit))
		if n and not isPeer(n) then return false end
	end
	for i = 1, 40 do
		local n = str(call(W.UnitName, "raid" .. i))
		if n and L.Key(n) ~= L.myKey and not isPeer(n) then return false end
	end
	return true
end

-- A line that does nothing (a /stopmacro whose conditions can never be true), so the click's other
-- lines (the raid's call, the rider's whisper) still run and no spell is cast.
L.SIM_NOOP = "/stopmacro [combat,nocombat]"

function hooks.castLine(line, name)
	if not L.sim or not isPeer(name) then return nil end -- (a real cast for anyone else)
	return L.SIM_NOOP
end

local function simHere(unit, c)
	if not L.sim then return nil end
	local W = W_()
	local key
	if type(c) == "table" and c.key then key = c.key end
	if not key and unit and W and type(W.UnitName) == "function" then
		local n = call(W.UnitName, unit)
		key = str(n) and L.Key(n)
	end
	local at = key and arrived[key]
	if not at then return nil end
	if L.Now() - at > L.SIM_HERE_SECS then
		arrived[key] = nil
		return nil
	end
	return true
end
hooks.here = simHere

-- A request from anyone but a peer is refused while the mode is on (the driver is not open to them).
local function requestFilter(name)
	if L.sim and not isPeer(name) then return true end
	return false
end

local function installHooks()
	local DR = DR_()
	if not DR then return false end
	DR.SimHooks = L.sim and hooks or nil
	if type(DR.requestFilters) == "table" and not L.simFilterAdded then
		L.simFilterAdded = true
		table.insert(DR.requestFilters, requestFilter)
	end
	return true
end

---------------------------------------------------------------------------
-- Driver side: the fake cast
---------------------------------------------------------------------------

L.simCasts = 0

-- The rider the click is about: the macro's last /target line ("[@party3]" or a name).
local function targetOf(macro)
	local W = W_()
	local who
	for line in (macro .. "\n"):gmatch("(.-)\n") do
		local t = line:match("^%s*/tar[get]*%s+(.-)%s*$")
		if t and t ~= "" then who = t end
	end
	if not who then return nil end
	local unit = who:match("^%[@([%w]+)%]$")
	if unit and W and type(W.UnitName) == "function" then return str(call(W.UnitName, unit)) end
	return (who:gsub("%-", " "))
end

local function send(target, text)
	local fn = type(C_ChatInfo) == "table" and C_ChatInfo.SendAddonMessage or rawget(_G, "SendAddonMessage")
	if type(fn) ~= "function" or not str(target) then return false end
	local ok = pcall(fn, L.PLAN_PREFIX or "WLAB", text, "WHISPER", target)
	L.Log("sim", "send " .. target .. ": " .. text)
	return ok
end

local function placeOf(name)
	local DR = DR_()
	local W = W_()
	local c = DR and DR.customers and W and DR.customers[W.Key(name)]
	if type(c) == "table" then
		local p = str(c.station) or str(c.dest)
		if p then return p end
	end
	local d = DR and type(DR.Dest) == "function" and call(DR.Dest)
	return str(d) or "the summoning stone"
end

-- The fake ritual of the click on `name`: events now, the channel for L.SIM_CHANNEL seconds, then the end
-- and the card for the rider.
function L.SimCast(name)
	local W = W_()
	if not (L.sim and W and str(name)) then return false end
	local DR = DR_()
	if DR and DR.cast then return false end -- one ritual at a time, as in the game
	fakeGuid = fakeGuid + 1
	local guid = "LabSim-" .. fakeGuid
	local id = ritualId()
	if not isPeer(name) then return false end -- never a pretend summon for anyone without the mode
	L.simCasts = L.simCasts + 1
	L.Log("sim", "pretend cast on " .. name)
	local mine = { guid = guid, id = id }
	simCasting = mine
	feed("UNIT_SPELLCAST_SENT", "player", name, guid, id)
	feed("UNIT_SPELLCAST_START", "player", guid, id)
	L.After(0.5, function()
		if not L.sim or simCasting ~= mine then return end
		feed("UNIT_SPELLCAST_SUCCEEDED", "player", guid, id)
		feed("UNIT_SPELLCAST_CHANNEL_START", "player", guid, id)
		mine.channel = true
		L.After(L.SIM_CHANNEL, function()
			if simCasting ~= mine then return end
			simCasting = nil
			feed("UNIT_SPELLCAST_CHANNEL_STOP", "player", guid, id)
			local me = W.Me and call(W.Me) or L.me
			send(name, ("SIM~summon~%s~%s"):format(str(me) or "?", placeOf(name)))
		end)
	end)
	return true
end

-- The mode went off mid-cast: end the pretend cast in Wuber now (no 330 s stuck cast).
local function endSimCast()
	local c = simCasting
	simCasting = nil
	if not c then return end
	if c.channel then
		feed("UNIT_SPELLCAST_CHANNEL_STOP", "player", c.guid, c.id)
	else
		feed("UNIT_SPELLCAST_FAILED", "player", c.guid, c.id)
	end
	L.Log("sim", "pretend cast ended (mode off)")
end

local function onBigClick(btn)
	if not L.sim then return end
	local macro = call(btn.GetAttribute, btn, "macrotext")
	macro = str(macro)
	if not macro or not macro:find(L.SIM_NOOP, 1, true) then return end -- no cast in this click
	local name = targetOf(macro)
	if name then L.SimCast(name) end
end

local hooked
local function hookButton()
	if hooked then return true end
	if L.InCombat and L.InCombat() then return false end -- (a secure button: never touched in combat)
	local b = rawget(_G, "WuberDriveButton")
	if type(b) ~= "table" or type(b.HookScript) ~= "function" then return false end
	hooked = pcall(b.HookScript, b, "PreClick", function(self, _, down)
		if down then return end
		local ok, err = pcall(onBigClick, self)
		if not ok then L.Bug("sim click", err) end
	end)
	return hooked
end

-- A helper's click on the portal (their own window): Wuber's own handler tells the caster (HELP).
function L.SimHelperClick()
	if not L.sim then return false end
	local DR = DR_()
	if not DR then return false end
	local busy = type(DR.RitualBusy) == "function" and call(DR.RitualBusy)
	if not busy then
		L.Say("nobody is casting a pretend summon to click")
		return false
	end
	fakeGuid = fakeGuid + 1
	local guid = "LabSimHelp-" .. fakeGuid
	local id = ritualId()
	feed("UNIT_SPELLCAST_CHANNEL_START", "player", guid, id)
	L.After(2, function() feed("UNIT_SPELLCAST_CHANNEL_STOP", "player", guid, id) end)
	L.Log("sim", "pretend portal click")
	L.Signal("sim_click")
	return true
end

---------------------------------------------------------------------------
-- Rider side: the fake summon card
---------------------------------------------------------------------------

local function fill(frame, r, g, b, a)
	local t = frame:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints(frame)
	t:SetColorTexture(r, g, b, a or 1)
	return t
end

local function label(parent, size, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, "")
	pcall(fs.SetJustifyH, fs, justify or "CENTER")
	pcall(fs.SetTextColor, fs, 1, 1, 1, 1)
	fs:SetText("")
	return fs
end

local function plainButton(parent, text, w, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, 24)
	fill(b, 0.18, 0.1, 0.28, 1)
	local fs = label(b, 12)
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	fs:SetText(text)
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", function() local ok, err = pcall(onClick) if not ok then L.Bug("sim button", err) end end)
	return b
end

local function hideCard()
	cardFrom = nil
	if card then card:Hide() end
end

local function buildCard()
	if card then return card end
	local f = CreateFrame("Frame", "WuberLabSimCard", UIParent)
	f:SetSize(360, 96)
	f:SetPoint("TOP", UIParent, "TOP", 0, -120)
	pcall(f.SetFrameStrata, f, "DIALOG")
	fill(f, 0.12, 0.06, 0.2, 0.97)
	f.text = label(f, 13)
	f.text:SetPoint("TOP", f, "TOP", 0, -14)
	f.text:SetWidth(340)
	f.sub = label(f, 10)
	f.sub:SetPoint("TOP", f, "TOP", 0, -40)
	f.sub:SetText("test mode: nobody is really summoned")
	f.accept = plainButton(f, "Accept", 110, function() L.SimAccept() end)
	f.accept:SetPoint("BOTTOMLEFT", f, "BOTTOM", -118, 10)
	f.decline = plainButton(f, "Decline", 110, function() L.SimDecline() end)
	f.decline:SetPoint("BOTTOMLEFT", f, "BOTTOM", 8, 10)
	f:Hide()
	card = f
	L.simCard = f
	return f
end

local function showCard(driver, place)
	local f = buildCard()
	cardFrom = driver
	f.text:SetText(("%s is summoning you to %s"):format(driver, place))
	f:Show()
	local mine = driver
	L.After(L.SIM_CARD_SECS, function()
		if cardFrom == mine and card and card:IsShown() then hideCard() end
	end)
	L.Log("sim", "card: " .. driver .. " -> " .. place)
	L.Signal("sim_card", driver)
end

function L.SimAccept()
	local driver = cardFrom
	if not driver then return false end
	hideCard()
	local me = L.me
	acceptedFrom = driver
	L.simAccepted = L.Now()
	send(driver, "SIM~accept~" .. (str(me) or "?"))
	L.Log("sim", "accepted " .. driver)
	return true
end

function L.SimDecline()
	local driver = cardFrom
	if not driver then return false end
	hideCard()
	send(driver, "SIM~moved~" .. (str(L.me) or "?"))
	L.Log("sim", "declined " .. driver)
	return true
end

-- Accepted, then moved: the driver forgets it (rider side).
L.On("PLAYER_STARTED_MOVING", function()
	if not (L.sim and acceptedFrom) then return end
	local driver = acceptedFrom
	acceptedFrom = nil
	send(driver, "SIM~moved~" .. (str(L.me) or "?"))
	L.Log("sim", "moved: told " .. driver)
end)

-- The summoner tells the rest of the group (the runner's window and the crew follow the same word).
local function relay(text)
	local DR = DR_()
	local fn = type(C_ChatInfo) == "table" and C_ChatInfo.SendAddonMessage or rawget(_G, "SendAddonMessage")
	if type(fn) ~= "function" then return end
	local inGroup = type(IsInGroup) == "function" and plain(call(IsInGroup)) == true
	if not inGroup then return end
	local raid = type(IsInRaid) == "function" and plain(call(IsInRaid)) == true
	pcall(fn, L.PLAN_PREFIX or "WLAB", text, raid and "RAID" or "PARTY")
end

-- The handshake: who else has the mode on (the group, and the tester's four characters by whisper).
local function cleanSender(name)
	name = str(name)
	if not name then return nil end
	local W = W_()
	if W and type(W.CleanName) == "function" then return str(call(W.CleanName, name)) or name end
	return name
end

local function addPeer(sender)
	local name = cleanSender(sender)
	local k = name and L.Key(name)
	if not k or k == L.myKey then return end
	local new = peers[k] == nil
	peers[k] = { name = name, at = L.Now() }
	if new then
		L.Log("sim", "peer (test mode on there too): " .. name)
		local DR = DR_()
		if DR and type(DR.Changed) == "function" then pcall(DR.Changed) end
	end
end

-- Whether `key` is in our party or raid (they hear our group messages: no whisper needed).
local function grouped(key)
	local W = W_()
	if not (key and W and type(W.UnitName) == "function") then return false end
	for i = 1, 4 do
		local n = str(call(W.UnitName, "party" .. i))
		if n and L.Key(n) == key then return true end
	end
	for i = 1, 40 do
		local n = str(call(W.UnitName, "raid" .. i))
		if n and L.Key(n) == key then return true end
	end
	return false
end

-- Hello (or bye) to the group in one message, and by whisper to `names` ({ [key] = name }) out of it.
local function tellAll(text, names)
	relay(text)
	for k, name in pairs(names or {}) do
		if k ~= L.myKey and not grouped(k) then send(type(name) == "table" and name.name or name, text) end
	end
end

local function simHello() tellAll("SIM~hello", L.CAST_NAMES) end
L.SimHello = simHello

local answeredAt = {} -- [key] = when we last said hi to them (one answer per 30 s)

L.On("CHAT_MSG_ADDON", function(prefix, text, chan, sender)
	if str(prefix) ~= (L.PLAN_PREFIX or "WLAB") then return end
	text, sender = str(text), str(sender)
	if not text or not sender or text:sub(1, 4) ~= "SIM~" then return end
	chan = plain(chan)
	if chan ~= "WHISPER" and chan ~= "PARTY" and chan ~= "RAID" then return end
	if L.Key(cleanSender(sender) or sender) == L.myKey then return end -- our own group message
	local fields = {}
	for f in (text .. "~"):gmatch("(.-)~") do fields[#fields + 1] = f end
	local kind = fields[2]
	if kind == "bye" then
		local k = L.Key(cleanSender(sender) or sender)
		peers[k], answeredAt[k] = nil, nil
		return
	end
	if not L.sim then return end -- both sides must have the mode on
	if kind == "hello" then
		addPeer(sender)
		local k = L.Key(cleanSender(sender) or sender)
		if k and not (answeredAt[k] and L.Now() - answeredAt[k] < 30) then
			answeredAt[k] = L.Now()
			send(cleanSender(sender), "SIM~hi")
		end
		return
	elseif kind == "hi" then
		addPeer(sender)
		return
	end
	if not isPeer(cleanSender(sender)) then return end -- only a lab with the mode on is heard
	-- whose word: a whisper speaks for its sender; a group relay (the driver's lab) for field 3
	local who = cleanSender(sender)
	if chan ~= "WHISPER" and fields[3] and fields[3] ~= "" then who = fields[3] end
	if kind == "summon" then
		if chan ~= "WHISPER" then return end
		showCard(fields[3] ~= "" and fields[3] or sender, fields[4] ~= "" and fields[4] or "the summoning stone")
	elseif kind == "accept" then
		local key = L.Key(who)
		arrived[key] = L.Now()
		L.Log("sim", "arrived (pretend): " .. key)
		if chan == "WHISPER" then relay("SIM~accept~" .. who) end
	elseif kind == "moved" then
		arrived[L.Key(who)] = nil
		if chan == "WHISPER" then relay("SIM~moved~" .. who) end
	end
end)

-- New faces in the group (and every minute, below): say hello again while the mode is on.
local lastGroup, helloDue = {}, false
L.On("GROUP_ROSTER_UPDATE", function()
	local W = W_()
	if not (W and type(W.UnitName) == "function") then return end
	local now, fresh = {}, false
	for _, unit in ipairs({ "party1", "party2", "party3", "party4" }) do
		local n = str(call(W.UnitName, unit))
		if n then now[L.Key(n)] = true end
	end
	for i = 1, 40 do
		local n = str(call(W.UnitName, "raid" .. i))
		if n then now[L.Key(n)] = true end
	end
	for k in pairs(now) do
		if k ~= L.myKey and not lastGroup[k] and not peers[k] then fresh = true end
	end
	lastGroup = now
	if not (L.sim and fresh) or helloDue then return end
	helloDue = true
	L.After(1, function()
		helloDue = false
		if L.sim then relay("SIM~hello") end
	end)
end)

if type(C_ChatInfo) == "table" and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
	pcall(C_ChatInfo.RegisterAddonMessagePrefix, L.PLAN_PREFIX or "WLAB")
end

---------------------------------------------------------------------------
-- The banner and the switch
---------------------------------------------------------------------------

local BANNER = "TEST MODE \226\128\148 nobody is really summoned"

local function buildBanner()
	if banner then return banner end
	local f = CreateFrame("Frame", "WuberLabSimBanner", UIParent)
	f:SetHeight(22)
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
	pcall(f.SetFrameStrata, f, "FULLSCREEN_DIALOG")
	fill(f, 0.75, 0.12, 0.12, 0.95)
	f.text = label(f, 13)
	f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.text:SetText(BANNER)
	f:Hide()
	banner = f
	L.simBanner = f
	return f
end

function L.SimSet(on)
	on = on and true or false
	if on == L.sim then return L.sim end
	L.sim = on
	if not on then
		endSimCast()
		arrived = {}
		acceptedFrom = nil
		hideCard()
		tellAll("SIM~bye", peers)
		peers, answeredAt = {}, {}
	end
	installHooks()
	if on then simHello() end
	hookButton()
	local b = buildBanner()
	if on then b:Show() else b:Hide() end
	L.Log("sim", on and "pretend-to-summon ON (no shards needed; nobody is really summoned)" or "pretend-to-summon off")
	local DR = DR_()
	if DR and type(DR.Changed) == "function" then pcall(DR.Changed) end
	if L.RefreshPanel then L.RefreshPanel() end
	return L.sim
end

function L.SimToggle() return L.SimSet(not L.sim) end

function L.SimArrived(key) return key and arrived[key] ~= nil end

L.OnLogin(function()
	-- the big button may be built a little after login
	local tries = 0
	local ticker
	ticker = L.Every(2, function()
		tries = tries + 1
		if hookButton() or tries > 30 then
			if ticker and ticker.Cancel then pcall(ticker.Cancel, ticker) end
		end
	end)
	hookButton()
	L.Every(L.SIM_HELLO_EVERY, function() if L.sim then simHello() end end)
end)

L.On("PLAYER_LOGOUT", function() L.sim = false end) -- never carried over (it is not saved anyway)

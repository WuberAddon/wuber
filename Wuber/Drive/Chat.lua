-- Module: Drive.Chat
-- Purpose: What riders are told and how it leaves (was Drive_Chat.lua).
-- API: W.Drive, DR.TEXT_MAX, DR.ADVERT_MAX, DR.MACRO_MAX, DR.TEMPLATES, DR.PAYTO_TEMPLATES,
--   DR.TEMPLATE_ORDER, DR.PLACEHOLDERS, DR.RAID_TEMPLATES, DR.chat, DR.attempts, DR.Keyword,
--   DR.ServiceName, DR.Guild, DR.Template, DR.PayeeKey, DR.KeyHasApp, DR.IsPlainSummoner,
--   DR.PayeeBlind, DR.PayeeHasApp, DR.ShortOf, DR.PlacesText, DR.Text, DR.TemplateSpam, DR.SetTemplate,
--   DR.ChatMode, DR.Speaks, DR.RunnerWindow, DR.ModeNow, DR.Pending, DR.MarkSent, DR.PumpChat,
--   DR.WatchEcho, DR.ResetChat, DR.ChatBox, DR.OpenBox
-- Internals: (none)
-- Uses: (none)
-- Later: (none) (Drive.Book's DR.GetAppOwed / DR.GetAppSent and Drive.Mail's DR.MailOwed / DR.MailSent are
--   reached through DR at run time, from DR.Pending and DR.MarkSent)
-- Events: listens On CHAT_MSG_WHISPER_INFORM; fires DRIVE_ALERT
-- Standalone: no
-- Test: tests/drive/chat_test.lua
-- From: Drive_Chat.lua 1-563 (Wuber 2.2.1)
--
-- Wuber Drive: what riders are told, and how it leaves this client (agent B).
-- Ported from Ritual Rides 1.4.1's Chat.lua.
--
-- Three ways a whisper can go out (DR.ChatMode):
--
--   macro   it rides as a "/w" line in the big button's macro: your click sends it.
--   box     it is put into the chat box: your Enter sends it.
--   off     nothing is whispered (and "paid" is the end of the ride).
--
-- "auto" (the default) is macro. A macro whisper is checked by its echo (the "To X: ..."
-- line the game shows you); when three in a row show none, auto falls back to the chat box.
-- The client forbids addons to post chat by themselves, so there is no "direct" mode.

local ADDON, W = ...
local Mod = W.Module("Drive.Chat", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local plain, str = W.Plain, W.Str

DR.TEXT_MAX = 190   -- what one whisper may hold, so that its macro line still fits
DR.ADVERT_MAX = 200 -- the advert line (W.AdvertPlan adds the [Wuber] tag)
DR.MACRO_MAX = 255  -- what one macro may hold

-- {service} {guild} {dest} {price} {keyword} {name} {paid} {due} {reason} {payto} {places}
-- {summoner} {caster}
DR.TEMPLATES = {
	advert = "{service} - instant summons to {dest} for {price}! Whisper me \"{keyword}\" for an invite.",
	greet = "{service}: summoning you to {dest} now - please accept the summon! The ride is {price}; just open trade with any of us when you land.",
	price = "{service}: a summon to {dest} is {price}. Whisper me \"{keyword}\" and your invite is on its way.",
	pay = "Welcome to {dest}, {name}! Your ride was {price} - please open trade with any of us. Thank you!",
	thanks = "Thank you, {name}! Enjoy {dest} - {service} is here whenever you need a lift.",
	tip = "Thank you for the tip, {name}! Enjoy {dest} - {service} is here whenever you need a lift.",
	short = "Thanks {name}! That was {paid} of {price} - could you trade the remaining {due}? Much appreciated.",
	busy = "{service}: you are already in a group - leave it and whisper me \"{keyword}\" again for your invite.",
	offer = "{service}: saw you need a summon to {dest} - it's {price}. Accept the invite and we'll bring you right over!",
	refuse = "Sorry {name}, {service} won't be summoning you: {reason}.",
	oops = "Sorry {name}, that invite was my mistake. Have a good one!",
	-- 2.1
	where = "{service}: we summon to {places}. Where would you like to go? Whisper me the place.",
	callsum = "{summoner}: please summon {name}",
	raidsum = "Summon coming from {caster} - accept it when it pops",
	raidclick = "Summoning {name} - click the portal please",
	-- round 9 (Y1): only when the driver picks "Get Wuber" for a rider who came without the app (Drive.Book)
	getapp = "Book me in one tap next time: get the Wuber addon on CurseForge (search \"Wuber\").",
	-- to a rider we told something, dropped because the driver left the place they asked for
	-- (not in TEMPLATE_ORDER: not edited in Messages; {from} is the place they asked for)
	moved = "Sorry {name}, I've moved to {dest} - no summon to {from} right now.",
	-- decisions round (payment by mail, Drive.Mail): to a rider who left owing; the driver's click sends it.
	-- Not in TEMPLATE_ORDER: not edited in Messages. {due} is what they owe, {payto} the whole name to mail
	mailpay = "You can still pay by mail, {name}: send {due} to {payto} by mail, subject Wuber.",
	-- 2.4 (the decisions round): sent only by itself (Drive.AutoLines, its switch in Messages, off by default), to a
	-- rider without the app who is first in the line and waits for room. The big button never offers it.
	next = "You're next, {name}. I'll invite you as soon as there is room.",
}
-- The defaults when the rider pays somebody else than the one speaking (a Warlock friend
-- summons for a runner, or a crew mate casts): "trade Bea" instead of "any of us". A message
-- the driver wrote is used as written ({payto} works in it either way).
DR.PAYTO_TEMPLATES = {
	greet = "{service}: summoning you to {dest} now - please accept the summon! The ride is {price}; please open a trade with {payto} when you land.",
	pay = "Thanks for riding {service}! Please open a trade with {payto} and type {price}.",
	offer = "{service}: saw you need a summon to {dest} - it's {price}, paid to {payto} by trade. Accept the invite and we'll bring you right over!",
	thanks = "Thank you, {name}! {payto} got your {paid} - enjoy {dest}, {service} is here whenever you need a lift.",
	tip = "Thank you for the tip, {name}! {payto} got your {paid} - enjoy {dest}, {service} is here whenever you need a lift.",
}
DR.TEMPLATE_ORDER = { "advert", "greet", "price", "offer", "pay", "thanks", "tip", "short", "busy", "refuse", "oops", "where", "callsum",
	"raidsum", "raidclick", "getapp", "next" }
DR.PLACEHOLDERS = { "name", "price", "dest", "service", "guild", "keyword", "paid", "due", "reason", "payto", "places", "summoner",
	"caster" }
-- kinds only a raid (or the summoner call) uses: no price, no {payto}
DR.RAID_TEMPLATES = { raidsum = true, raidclick = true, callsum = true }

DR.chat = DR.chat or { confirms = 0, misses = 0, failed = false }
DR.attempts = DR.attempts or {} -- [customer key] = { at, confirmed }: whispers waiting for their echo

local function now() return W.Now() end

local function call(name, ...)
	local fn = DR[name]
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		W.Error("drive " .. name, a)
		return nil
	end
	return a, b
end

local function opts()
	local o = call("opts")
	return type(o) == "table" and o or {}
end

local function driveDB()
	local db = W.db
	local d = type(db) == "table" and db.drive or nil
	return type(d) == "table" and d or nil
end

local function templates()
	local d = driveDB()
	if not d then return {} end
	if type(d.templates) ~= "table" then d.templates = {} end
	return d.templates
end

local function changed() call("Changed") end

---------------------------------------------------------------------------
-- The text of a message
---------------------------------------------------------------------------

-- The first request word ("summon"): opts.keywords is a space separated text or a list.
function DR.Keyword()
	local k = opts().keywords
	if type(k) == "table" then
		if type(k[1]) == "string" and k[1] ~= "" then return k[1] end
	elseif type(k) == "string" then
		local first = k:match("([%w]+)")
		if first then return first end
	end
	return "summon"
end

-- The service name riders are told: the character's (spam-checked), else their name.
function DR.ServiceName()
	local s = W.Char().service
	if W.CleanService then
		return (W.CleanService(s, W.Me()))
	end
	if type(s) == "string" and s ~= "" then return s end
	return W.Me()
end

-- {guild}: the guild's name in brackets ("<Moo>"), as 2.0 wrote it; "" without a guild. A
-- message that writes the brackets itself ("<{guild}>") gets them once, not "<<Moo>>". The one
-- DR.Guild (2.2, review #25: two copies disagreed about the brackets).
local function guildName()
	if type(GetGuildInfo) ~= "function" then return "" end
	local ok, g = pcall(GetGuildInfo, "player")
	g = ok and str(g) or nil
	g = g and g:gsub("^<(.*)>$", "%1") or ""
	return g ~= "" and ("<" .. g .. ">") or ""
end
DR.Guild = guildName

local function fill(template, vars)
	template = template:gsub("<{guild}>", "{guild}")
	return (template:gsub("{(%a+)}", function(k)
		local v = vars[k]
		if v == nil then return nil end
		return tostring(v)
	end))
end

local function money(c) return W.Money(c) end

-- The text a template kind uses now: the driver's own, else the default.
function DR.Template(kind)
	local t = templates()[kind]
	if type(t) ~= "string" or t == "" then t = DR.TEMPLATES[kind] or "" end
	return t
end

---------------------------------------------------------------------------
-- Who a rider pays (2.1: the summoner who cast them)
---------------------------------------------------------------------------

local function str1(v) return type(v) == "string" and v ~= "" and v or nil end

-- The key of the crew member a rider pays: the one who cast them (c.caster), else the engine's
-- DR.Payee / DR.NextCaster (the one the queue expects to cast them). nil when nobody is known.
function DR.PayeeKey(c)
	if type(c) ~= "table" then return nil end
	local k = str1(c.payee) or str1(c.caster) or str1(call("Payee", c.name))
	if not k then k = str1(call("NextCaster", c.name)) end
	return k and (W.Key(k) or k) or nil
end

-- Whether the crew member `key` runs Wuber (a summoner added with "Add anyway", or a raid
-- Warlock without the app, does not: nobody can watch their trades or casts).
function DR.KeyHasApp(key)
	if type(key) ~= "string" or key == "" or key == W.myKey then return true end
	local v = call("SummonerHasApp", key)
	if v ~= nil then return v == true end
	local m = call("CrewEntry", key)
	if type(m) == "table" then return m.app ~= false end
	local raid = call("RaidWarlocks")
	if type(raid) == "table" then
		for _, r in ipairs(raid) do
			if type(r) == "table" and r.key == key then return r.app ~= false end
		end
	end
	return true
end

-- A crew summoner without Wuber (role lock, app false): the runner's button calls them.
function DR.IsPlainSummoner(key)
	if type(key) ~= "string" or key == "" or key == W.myKey then return false end
	if DR.KeyHasApp(key) then return false end
	local m = call("CrewEntry", key)
	if type(m) == "table" then return m.role == "lock" or m.role == "L" end
	local list = call("Summoners")
	for _, k in ipairs(type(list) == "table" and list or {}) do
		if k == key then return true end
	end
	return false
end

-- The rider pays somebody whose trades no Wuber window can see.
function DR.PayeeBlind(c)
	local k = DR.PayeeKey(c)
	return k ~= nil and k ~= W.myKey and not DR.KeyHasApp(k)
end

-- Spec 1.2: false when the rider's payee has no Wuber (no auto-block for them).
function DR.PayeeHasApp(name)
	local c = call("Find", name)
	if type(c) ~= "table" then return true end
	return not DR.PayeeBlind(c)
end

-- A short name for a crew key ("Bea").
function DR.ShortOf(key)
	if type(key) ~= "string" or key == "" then return nil end
	local n = call("WhoIs", key)
	if type(n) == "string" and n ~= "" and n ~= "?" then return n end
	return (key:match("^(%S+)") or key):gsub("^%l", string.upper)
end

-- Who a thanks names: the crew member the gold reached (a rider may trade the wrong one), or
-- the payee when this window marked it paid for them (a payee without Wuber).
local function thankedKey(c)
	local cash, p = str1(c.cashier), DR.PayeeKey(c)
	if cash and cash ~= W.myKey then return cash end
	if cash == W.myKey and p and p ~= W.myKey and DR.KeyHasApp(p) then return cash end
	return p or cash
end

-- {payto}: "me" when the speaker is paid, the payee's short name, or "any of us".
local function payto(c, kind)
	if type(c) ~= "table" then return "any of us", false end
	if str1(c.payto) then return c.payto, true end
	local thanks = kind == "thanks" or kind == "tip"
	local k
	if thanks then k = thankedKey(c) else k = DR.PayeeKey(c) end
	if not k then return "any of us", false end
	if k == W.myKey then
		-- 2.0 crews keep "any of us"; a 2.1 service (summoners chosen) names the summoner, even
		-- when the summoner speaks ("trade me", "Bea got your 50s")
		local list = call("Summoners")
		local chosen = type(list) == "table" and #list > 0
		if not chosen then return "me", false end
		if thanks then return DR.ShortOf(k) or "me", true end
		return "me", true
	end
	return DR.ShortOf(k) or "any of us", true
end

-- {places}: where this crew summons to ("Undercity and Orgrimmar").
function DR.PlacesText()
	local list = call("Stations")
	local names = {}
	for _, s in ipairs(type(list) == "table" and list or {}) do
		if type(s) == "table" and s.open ~= false and str1(s.place) then names[#names + 1] = s.place end
	end
	if #names == 0 then
		local d = call("Dest")
		return str1(d) or ""
	end
	if #names == 1 then return names[1] end
	return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

-- The filled-in text of one message. `c` is the customer (none for the advert), or for the
-- raid kinds { name, caster, summoner } (keys or names). A blocked player's refusal
-- (DR.refusals) carries name and reason. `draft` (optional): unsaved text to fill instead of
-- the template (the Messages editor's live preview).
function DR.Text(kind, c, draft)
	local template = DR.Template(kind)
	local to, other = payto(c, kind)
	if other and DR.PAYTO_TEMPLATES[kind] and template == DR.TEMPLATES[kind] then template = DR.PAYTO_TEMPLATES[kind] end
	if type(draft) == "string" and draft ~= "" then template = draft end
	local price = (c and tonumber(c.price)) or tonumber(W.Char().price) or W.MIN_PRICE
	local paid = (c and tonumber(c.paid)) or 0
	-- marked paid by hand (no amount seen): the thanks says the fare
	if paid <= 0 and (kind == "thanks" or kind == "tip") then paid = price end
	local dest = call("Dest")
	if type(dest) ~= "string" or dest == "" then dest = (W.DestHere and W.DestHere()) or "" end
	local function who(v)
		if not str1(v) then return "" end
		return DR.ShortOf(W.Key(v) or v) or W.Short(v)
	end
	local text = fill(template, {
		service = DR.ServiceName(),
		guild = guildName(),
		dest = str1(c and c.movedTo) or (call("MultiStation") == true and str1(c and c.station)) or dest,
		from = c and str1(c.from) or nil,
		price = money(price),
		keyword = DR.Keyword(),
		name = c and c.name and W.Short(c.name) or "",
		reason = c and c.reason or "",
		paid = money(paid),
		due = money(math.max(0, price - paid)),
		payto = to,
		places = DR.PlacesText(),
		summoner = who(c and c.summoner),
		caster = who(c and c.caster) ~= "" and who(c and c.caster) or W.Short(W.Me()),
	})
	-- (HUNT-74) an unsaved draft keeps its real length (up to what a message can carry) so the editor's
	-- counter shows it over the limit; Save refuses it. Saved wording is cut at DR.TEXT_MAX as before.
	local max = kind == "advert" and DR.ADVERT_MAX or DR.TEXT_MAX
	if type(draft) == "string" and draft ~= "" and kind ~= "advert" then max = 255 end
	return W.Clean(text, max)
end

-- Why a message text is refused, or nil: the anti-spam filter on the words the driver wrote
-- (placeholders left out). Short words like "a" and "I" are fine in a sentence (only
-- W.SpamReason's "letters" rule, made for service names, is not applied).
function DR.TemplateSpam(text)
	text = str(text)
	if not text then return nil end
	local words = text:gsub("{%a+}", " ")
	local why = W.SentenceSpam and W.SentenceSpam(words) -- (no "letters" rule; a place nickname like Org passes)
	if why == "letters" then why = nil end
	return why
end

local SPAM_WHY = {
	word = "it has a word Wuber doesn't allow (gold selling, links)",
	digits = "it has a long number in it",
	link = "it has a web address in it",
}

-- Changes one message; nil or "" puts the default back. Shared with the crew (TPL).
-- Returns true, or false and why in plain words.
function DR.SetTemplate(kind, text)
	if type(kind) ~= "string" or not DR.TEMPLATES[kind] then return false, "no such message" end
	local list = templates()
	text = plain(text)
	if text == nil or (type(text) == "string" and text:gsub("%s", "") == "") then
		list[kind] = nil
		call("Send", "TPL", kind, DR.TEMPLATES[kind])
		changed()
		return true
	end
	if type(text) ~= "string" then return false, "not a text" end
	local clean = W.Clean(text, kind == "advert" and DR.ADVERT_MAX or 255)
	-- whispers are cut at DR.TEXT_MAX (and the crew stores that much): a longer one is refused,
	-- so what is saved is what riders read
	-- (ING-06) counted as the rider reads it (names and prices filled in, as the editor's counter does)
	if kind ~= "advert" then
		local price = tonumber(W.Char().price) or W.MIN_PRICE or 5000
		local paid = kind == "tip" and math.floor(price * 1.2) or (kind == "short" and math.floor(price * 0.6)) or price
		local okT, read = pcall(DR.Text, kind, { name = "Dan Rider", key = "dan rider", price = price, paid = paid,
			state = "arrived", reason = "you left without paying last time", summoner = W.Me() }, clean)
		local n = (okT and type(read) == "string") and #read or #clean
		if n > DR.TEXT_MAX then
			return false, "it is " .. n .. " letters long: whispers are " .. DR.TEXT_MAX .. " at most"
		end
	end
	local why = DR.TemplateSpam(clean)
	if why then return false, SPAM_WHY[why] or "the spam filter refused it" end
	if kind == "advert" and W.AdvertOwnText then
		local line, bad = W.AdvertOwnText(clean)
		if not line then return false, bad == "spam" and "the spam filter refused it" or "it is empty" end
	end
	if clean == DR.TEMPLATES[kind] then list[kind] = nil else list[kind] = clean end
	call("Send", "TPL", kind, clean)
	changed()
	return true
end

---------------------------------------------------------------------------
-- Who speaks, and what is owed
---------------------------------------------------------------------------

function DR.ChatMode()
	local mode = opts().whisperMode
	if mode == "off" or mode == "macro" or mode == "box" then return mode end
	if DR.chat.failed then return "box" end
	return "macro"
end

local function isLeader()
	local v = call("IsLeader")
	if v == nil then return true end
	return v == true
end

-- Is it this window that speaks for a customer? `who` is the crew member the customer dealt
-- with (the caster, the one who was paid); when that one is not around, the leader does.
-- A crew summoner without Wuber can't whisper for us: the runner's window speaks for them
-- (the leader's, when the runner is not in the group).
function DR.Speaks(who)
	if who ~= nil and who == W.myKey then return true end
	if who and DR.units and DR.units[who] and call("IsCrewKey", who) and DR.KeyHasApp(who) then return false end
	if who and not DR.KeyHasApp(who) then return DR.RunnerWindow() end
	return isLeader()
end

-- This window speaks and calls for the runner: the runner's own (A's DR.IsRunner), or the
-- leader's while the runner is not in the group.
function DR.RunnerWindow()
	if call("IsRunner") == true then return true end
	local k = call("CaptainKey")
	if type(k) == "string" and k ~= W.myKey and DR.units and DR.units[k] then return false end
	return isLeader()
end

local function mode()
	local m = call("Mode")
	return m == "raid" and "raid" or "sell"
end
DR.ModeNow = mode

local function sorted()
	local list = call("Sorted")
	return type(list) == "table" and list or {}
end

local function due(c)
	return tonumber(call("Due", c)) or 0
end

-- The whispers this window owes right now, most pressing first: { {c, kind} }.
function DR.Pending()
	local out, t, o = {}, now(), opts()
	if mode() == "raid" then return out end -- a raid hears only raidsum (the button's own step)
	for _, c in ipairs(sorted()) do
		local kind
		if c.oops then
			-- oops step handles this player (whisper + uninvite in Drive.Plan)
		elseif call("PlaceStale", c) == true then
			-- a rider for a place we left: nothing until DR.PlaceSweep drops them
		elseif (c.askWhere or c.noStation or c.elsewhere) and not c.whereTold and not c.elsewhereTold
			and c.state ~= "paid" and c.state ~= "done"
			and (c.heardBy == W.myKey or (c.heardBy == nil and isLeader())) then
			-- a place we don't know, or no station for it: "We summon to Undercity and Orgrimmar"
			kind = "where"
		elseif c.state == "paid" then
			if not c.thanked and DR.Speaks(c.cashier) then kind = (c.paid or 0) > (c.price or 0) and "tip" or "thanks" end
		elseif c.state == "arrived" then
			if c.short and not c.shortTold then
				if DR.Speaks(c.cashier) then kind = "short" end
			elseif o.remindPay ~= false and (c.tries or 0) > 0 and not c.reminded and due(c) > 0
				and not c.walked and t - (c.arrivedAt or t) >= 25 and DR.Speaks(c.caster) then
				kind = "pay"
			end
		elseif c.state == "invited" and c.offer and not c.offerTold and isLeader() then
			-- invited from Trade or LookingForGroup: why, and what it costs
			kind = "offer"
		elseif c.state == "lead" and c.heardBy == W.myKey then
			if c.wantsPrice and not c.priceTold then
				kind = "price"
			elseif c.busy and not c.busyTold then
				kind = "busy"
			end
		end
		if kind then out[#out + 1] = { c = c, kind = kind } end
	end
	-- riders dropped because we left the place they asked for, who were told something
	local moved = DR.moved
	if type(moved) == "table" then
		local list = {}
		for _, m in pairs(moved) do
			if type(m) == "table" and not m.told and m.name then list[#list + 1] = m end
		end
		table.sort(list, function(a, b) return (a.at or 0) < (b.at or 0) end)
		for _, m in ipairs(list) do out[#out + 1] = { c = m, kind = "moved" } end
	end
	-- round 9 (Y1): "Get Wuber", only where the driver asked for it in the row menu (Drive.Book)
	if DR.GetAppOwed then DR.GetAppOwed(out) end
	-- blocked players who asked again: told why not
	local refusals = DR.refusals
	if type(refusals) == "table" then
		local list = {}
		for _, r in pairs(refusals) do
			if type(r) == "table" and not r.told and r.name then list[#list + 1] = r end
		end
		table.sort(list, function(a, b) return (a.at or 0) < (b.at or 0) end)
		for _, r in ipairs(list) do out[#out + 1] = { c = r, kind = "refuse" } end
	end
	-- decisions round (payment by mail): riders who left owing a moment ago, "you can still pay by mail" (Drive.Mail)
	if DR.MailOwed then DR.MailOwed(out) end
	return out
end

-- The whisper went out (or was handed to you to send).
function DR.MarkSent(c, kind)
	if type(c) ~= "table" then return end
	if kind == "thanks" or kind == "tip" then
		call("Do", "THX", c.name)
	elseif kind == "greet" then
		call("Do", "GR", c.name)
	elseif kind == "pay" then
		c.reminded = true
	elseif kind == "price" then
		c.priceTold = true
	elseif kind == "offer" then
		c.offerTold = true
	elseif kind == "refuse" or kind == "moved" then
		c.told = true
	elseif kind == "short" then
		c.shortTold = true
	elseif kind == "busy" then
		c.busyTold = true
	elseif kind == "getapp" then
		if DR.GetAppSent then DR.GetAppSent(c) end
	elseif kind == "mailpay" then
		if DR.MailSent then DR.MailSent(c) end
	elseif kind == "where" then
		c.whereTold = true
		if c.elsewhere then c.elsewhereTold = true end
	end
	changed()
end

-- Once a second. Without whispers ("off") nobody is thanked, so "paid" ends the ride.
-- Everything else waits for a click (the button) or an Enter (the chat box).
function DR.PumpChat()
	if DR.ChatMode() ~= "off" then return end
	for _, w in ipairs(DR.Pending()) do
		if w.kind == "thanks" or w.kind == "tip" then DR.MarkSent(w.c, w.kind) end
	end
end

---------------------------------------------------------------------------
-- macro: the echo tells whether a whisper really left
---------------------------------------------------------------------------

function DR.WatchEcho(list)
	if type(list) ~= "table" then return end
	local entry = { at = now() }
	for _, c in ipairs(list) do
		if type(c) == "table" and c.key then DR.attempts[c.key] = entry end
	end
	W.After(6, function()
		if entry.confirmed then return end
		local chat = DR.chat
		chat.misses = chat.misses + 1
		local mode = opts().whisperMode
		if chat.confirms == 0 and chat.misses >= 3 and not chat.failed and (mode == nil or mode == "auto") then
			chat.failed = true
			W.Fire("DRIVE_ALERT", "No whisper sent by the button showed up in your chat. From now on a whisper goes into the chat box and your Enter sends it.", "info")
			changed()
		end
	end)
end

-- "Send whispers by the button again" (Settings, /wuber drive mode).
function DR.ResetChat()
	DR.chat.failed = false
	DR.chat.confirms, DR.chat.misses = 0, 0
	changed()
end

local function resolve(name)
	local k = call("ResolveKey", name)
	if type(k) == "string" then return k end
	return W.Key(name)
end

W.On("CHAT_MSG_WHISPER_INFORM", function(text, target)
	target = str(target)
	if not target then return end
	local key = resolve(target)
	if not key then return end
	local entry = DR.attempts[key]
	if entry and now() - entry.at < 10 and not entry.confirmed then
		entry.confirmed = true
		DR.chat.confirms = DR.chat.confirms + 1
		DR.chat.misses = 0
	end
	-- the reminder counts as sent only when the whisper IS its line (same words), however
	-- long the line waited in the box; a different whisper to the same rider is not it
	local b = DR.boxed
	if b and b.key == key and b.text and str(text) == b.text then
		DR.boxed = nil
		DR.MarkSent(b.c, b.kind)
	end
end)

---------------------------------------------------------------------------
-- box: the line waits in the chat box for your Enter
---------------------------------------------------------------------------

-- Puts a line into the chat box, one frame later (a slash command runs inside the box's
-- own send, which empties the box right after). Returns whether a chat box was there.
function DR.ChatBox(text)
	local open = (type(ChatFrameUtil) == "table" and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
	if type(open) ~= "function" then
		W.Print("type this in chat: " .. tostring(text))
		return false
	end
	W.After(0, function() pcall(open, text, DEFAULT_CHAT_FRAME) end)
	return true
end

-- The whisper `kind` for customer c, into the chat box (twice at most, then given up).
function DR.OpenBox(c, kind)
	if type(c) ~= "table" then return false end
	c.boxed = c.boxed or {}
	if (c.boxed[kind] or 0) >= 2 then
		-- offered twice and not sent: not asked a third time
		DR.boxed = nil
		DR.MarkSent(c, kind)
		return false
	end
	c.boxed[kind] = (c.boxed[kind] or 0) + 1
	local line = DR.Text(kind, c)
	DR.boxed = { c = c, kind = kind, key = c.key or W.Key(c.name), at = now(), text = str(line) }
	return DR.ChatBox("/w " .. W.Tell(c.name) .. " " .. line)
end

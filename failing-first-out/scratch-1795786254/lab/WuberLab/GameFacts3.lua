-- Wuber Lab (developer only, never ship): GameFacts3.lua - the passive Game facts check SECRETS, "Secrets census" (job 2630, item 01, DRAFT).
--
-- Joins GameFacts.lua / GameFacts2.lua as one more passive check, because the question is "WHEN is each secret-value predicate on in the real game?", which only
-- a long session of ordinary play can answer: fights, dungeons, bosses, whispers. An Auto check cannot enter a dungeon or start a boss, and a recorder snapshot
-- (WuberRec) is timed, not event-driven, so it would miss the moment a restriction turns on. GameFacts is where a passive check that waits for events
-- already lives, with its saved list (WuberLabDB.facts.SECRETS), its summary and its place in tools\labreport.cmd.
--
-- READ ONLY. No frame, no event and no timer at load (Wuber's own tests load the Lab on every branch): everything is wired by G.StartPassive, as in GameFacts2.
-- It talks to nobody, sends nothing, types nothing, calls no protected function (so it is safe in combat), and every game call goes through pcall.
-- Nothing secret is ever written down: only "secret" / a Lua type name / a boolean / a small state number. Never a name, text, GUID or time.
--
-- WHEN IT WRITES (one saved entry, one log line of kind "facts", id SECRETS):
--   PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED, ENCOUNTER_START / ENCOUNTER_END, PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA (enter and leave an instance),
--   CHALLENGE_MODE_START / _COMPLETED, PVP_MATCH_ACTIVE / _COMPLETE, ADDON_RESTRICTION_STATE_CHANGED (with its type and state): each now, and again 1 s later
--   (a restriction goes Activating -> Active after the event has been dispatched);
--   the first CHAT_MSG_WHISPER / SAY / PARTY / CHANNEL / SYSTEM / ADDON seen in each situation (lockdown, instance, combat) with the same argument shapes;
--   the login (7 s after the passive checks start) and every press of "Game facts".
-- WHAT EACH ENTRY HOLDS (a = the saved answers):
--   a.has      which of issecretvalue, canaccessvalue, canaccesstable, issecrettable, secretwrap, scrub, C_Secrets, C_RestrictedActions exist
--   a.where    InCombatLockdown, UnitAffectingCombat("player"), IsInInstance (flag, type word)
--   a.restrict [0..5] = { state, active }  C_RestrictedActions.GetAddOnRestrictionState(t) and IsAddOnRestrictionActive(t); 0 Combat, 1 Encounter, 2 ChallengeMode,
--              3 PvPMatch, 4 Map, 5 Chat. a.inDispatch is true inside ADDON_RESTRICTION_STATE_CHANGED (the documentation says IsAddOnRestrictionActive is false there)
--   a.chat     C_ChatInfo.InChatMessagingLockdown() and AreOutgoingAddonChatMessagesRestricted()
--   a.C        the C_Secrets answers (booleans, and the SecrecyLevel numbers): HasSecretRestrictions, ShouldAurasBeSecret, ShouldCooldownsBeSecret,
--              ShouldUnitStatsBeSecret, ShouldSpellCooldownBeSecret(698), GetSpellCooldownSecrecy(698), GetSpellCastSecrecy(698), ShouldUnitIdentityBeSecret(player, party1,
--              target, nameplate1), ShouldUnitComparisonBeSecret + CanCompareUnitTokens (player/target, nameplate1/player), ShouldUnitSpellCastingBeSecret(player, party1),
--              ShouldUnitSpellCastBeSecret(party1, 698); and a.C.exists = the documented names this client really has (27 are documented)
--   a.unit     kinds (secret / string / nil ...) of UnitName and UnitGUID for player, party1, target, nameplate1; and of the three UnitClass returns for party1
--   a.cd       C_Spell.GetSpellCooldown for 698 (Ritual of Summoning), 686 (Shadow Bolt), 8690 (Hearthstone): kind of startTime and duration, flag of isActive, isEnabled, isOnGCD
--   a.cast     select("#") and the kind of each return of UnitCastingInfo and UnitChannelInfo for "player" and "party1"
--   a.args     for a chat event: the kind of args 1 (text), 2 (sender), 5, 12 (guid), 13 (bnSenderID) and the lockdown flag at that moment
-- HOW IT BECOMES A FIXTURE: tools\labreport.cmd prints "== Game facts" with these lines; a reviewer copies the first line per situation into
-- tests/fixtures/rec/secrets-census.lua as rows { id = ..., value = ... } (the ids the proof test fgp 01 reads: "hasSecretRestrictions", "whisper.text.secret.in_lockdown",
-- "cooldown698.secret.in_combat", "lockdown.in_dungeon", "lockdown.in_raid_boss", "restriction.combat.active_in_fight", "unitname.party1.secret.in_dungeon" ...).

local _, L = ...

local G = L.GameFacts
if type(G) ~= "table" or type(G.Put) ~= "function" or type(G.ask) ~= "function" then return end

local secret = L.IsSecret
local S = { wired = false, seenChat = {}, chatPuts = 0, CHAT_CAP = 30 }
G.Secrets = S -- (for the offline test)

for _, row in ipairs({
	{ "RULER", "Text ruler", "auto", "not run yet (Auto check)" },
	{ "CENSUS", "Game census", "auto", "not run yet (Auto check)" },
	{ "ANIM", "Animation facts", "auto", "not run yet (Auto check)" },
}) do G.IDS[#G.IDS + 1] = row end
G.IDS[#G.IDS + 1] = { "SECRETS", "Secrets census", "passive", "no census row yet (fight, enter a dungeon, meet a boss, get a whisper there)" }

local function gfn(name) return rawget(_G, name) end
local function tfn(tname, name)
	local t = rawget(_G, tname)
	return type(t) == "table" and t[name] or nil
end
local function pack(...) return { n = select("#", ...), ... } end

-- the state of one value, never the value: "secret", or its Lua type name
local function kind(v)
	if secret(v) then return "secret" end
	return type(v)
end
-- a boolean or a small number as it is; "secret" if hidden; otherwise the type name
local function flag(v)
	if secret(v) then return "secret" end
	local t = type(v)
	if t == "boolean" or t == "number" then return v end
	return t
end
-- a short plain word (an instance type such as "party"), or the kind
local function word(v)
	if secret(v) then return "secret" end
	if type(v) == "string" and v:match("^%a+$") and #v <= 12 then return v end
	return type(v)
end

-- fn(...) under pcall: the pack of its results (r[2..] are the values), or nil, "no such call" / "error"
local function call(fn, ...)
	if type(fn) ~= "function" then return nil, "no such call" end
	local r = pack(pcall(fn, ...))
	if not r[1] then return nil, "error" end
	return r
end
-- the first result of a call as a flag
local function first(fn, ...)
	local r, why = call(fn, ...)
	if not r then return why end
	if r.n < 2 then return "nothing" end
	if r[2] == nil then return "nil" end
	return flag(r[2])
end
-- how many values a call returned, and the kind of each (up to 12)
local function shape(fn, ...)
	local r, why = call(fn, ...)
	if not r then return why end
	local out = { n = r.n - 1 }
	for i = 2, math.min(r.n, 13) do out[i - 1] = kind(r[i]) end
	return out
end

local CS_NAMES = { "CanCompareUnitTokens", "GetPowerTypeSecrecy", "GetSpellAuraSecrecy", "GetSpellCastSecrecy", "GetSpellCooldownSecrecy",
	"HasSecretRestrictions", "ShouldActionCooldownBeSecret", "ShouldAurasBeSecret", "ShouldCooldownsBeSecret", "ShouldSpellAuraBeSecret",
	"ShouldSpellBookItemCooldownBeSecret", "ShouldSpellCooldownBeSecret", "ShouldTotemSlotBeSecret", "ShouldTotemSpellBeSecret",
	"ShouldUnitAuraIndexBeSecret", "ShouldUnitAuraInstanceBeSecret", "ShouldUnitAuraSlotBeSecret", "ShouldUnitComparisonBeSecret",
	"ShouldUnitHealthMaxBeSecret", "ShouldUnitIdentityBeSecret", "ShouldUnitPowerBeSecret", "ShouldUnitPowerMaxBeSecret",
	"ShouldUnitSpellCastBeSecret", "ShouldUnitSpellCastingBeSecret", "ShouldUnitStatsBeSecret", "ShouldUnitThreatStateBeSecret",
	"ShouldUnitThreatValuesBeSecret" }

local function secretsApi()
	local C = {}
	local ex, missing = 0, {}
	for _, name in ipairs(CS_NAMES) do
		if type(tfn("C_Secrets", name)) == "function" then ex = ex + 1 else missing[#missing + 1] = name end
	end
	C.exists = ex .. " of " .. #CS_NAMES
	if #missing > 0 and #missing <= 8 then C.missing = table.concat(missing, ",") end
	local function c(name, ...) return first(tfn("C_Secrets", name), ...) end
	C.HasSecretRestrictions = c("HasSecretRestrictions")
	C.ShouldAurasBeSecret = c("ShouldAurasBeSecret")
	C.ShouldCooldownsBeSecret = c("ShouldCooldownsBeSecret")
	C.ShouldUnitStatsBeSecret = c("ShouldUnitStatsBeSecret")
	C.cooldown698 = c("ShouldSpellCooldownBeSecret", 698)
	C.cooldownSecrecy698 = c("GetSpellCooldownSecrecy", 698)
	C.castSecrecy698 = c("GetSpellCastSecrecy", 698)
	for _, u in ipairs({ "player", "party1", "target", "nameplate1" }) do C["identity_" .. u] = c("ShouldUnitIdentityBeSecret", u) end
	C.compare_player_target = c("ShouldUnitComparisonBeSecret", "player", "target")
	C.canCompare_player_target = c("CanCompareUnitTokens", "player", "target")
	C.compare_plate1_player = c("ShouldUnitComparisonBeSecret", "nameplate1", "player")
	C.canCompare_plate1_player = c("CanCompareUnitTokens", "nameplate1", "player")
	C.casting_player = c("ShouldUnitSpellCastingBeSecret", "player")
	C.casting_party1 = c("ShouldUnitSpellCastingBeSecret", "party1")
	C.cast_party1_698 = c("ShouldUnitSpellCastBeSecret", "party1", 698)
	return C
end

local function cooldowns()
	local out = {}
	local fn = tfn("C_Spell", "GetSpellCooldown")
	for _, id in ipairs({ 698, 686, 8690 }) do
		local r, why = call(fn, id)
		if not r then out[id] = why
		elseif r.n < 2 or r[2] == nil then out[id] = "nothing"
		elseif secret(r[2]) then out[id] = "table secret"
		elseif type(r[2]) ~= "table" then out[id] = "type " .. type(r[2])
		else
			local info = r[2]
			out[id] = { startTime = kind(info.startTime), duration = kind(info.duration), isActive = flag(info.isActive),
				isEnabled = flag(info.isEnabled), isOnGCD = flag(info.isOnGCD) }
		end
	end
	return out
end

local function identity()
	local out = {}
	for _, u in ipairs({ "player", "party1", "target", "nameplate1" }) do
		out[u] = { name = shape(gfn("UnitName"), u), guid = shape(gfn("UnitGUID"), u) }
	end
	out.party1class = shape(gfn("UnitClass"), "party1")
	return out
end

local function census(why, extra)
	local a = { why = why, extra = extra, has = {} }
	for _, n in ipairs({ "issecretvalue", "canaccessvalue", "canaccesstable", "issecrettable", "secretwrap", "scrub" }) do a.has[n] = type(gfn(n)) == "function" end
	a.has.C_Secrets = type(rawget(_G, "C_Secrets")) == "table"
	a.has.C_RestrictedActions = type(rawget(_G, "C_RestrictedActions")) == "table"
	local inst = call(gfn("IsInInstance"))
	a.where = { combatLockdown = first(gfn("InCombatLockdown")), affecting = first(gfn("UnitAffectingCombat"), "player"),
		inInstance = inst and flag(inst[2]) or "no answer", instanceType = inst and word(inst[3]) or "no answer" }
	a.restrict = {}
	for t = 0, 5 do
		a.restrict[t] = { state = first(tfn("C_RestrictedActions", "GetAddOnRestrictionState"), t), active = first(tfn("C_RestrictedActions", "IsAddOnRestrictionActive"), t) }
	end
	a.chat = { lockdown = first(tfn("C_ChatInfo", "InChatMessagingLockdown")), outgoingRestricted = first(tfn("C_ChatInfo", "AreOutgoingAddonChatMessagesRestricted")) }
	a.C = secretsApi()
	a.unit = identity()
	a.cd = cooldowns()
	a.cast = { player = { casting = shape(gfn("UnitCastingInfo"), "player"), channel = shape(gfn("UnitChannelInfo"), "player") },
		party1 = { casting = shape(gfn("UnitCastingInfo"), "party1") } }
	local cd = a.cd[698]
	local line = ("%s: has C_Secrets %s, HasSecretRestrictions %s; restrict combat %s/enc %s/key %s/pvp %s/map %s/chat %s; chat lockdown %s; combat %s, instance %s (%s); "
		.. "ritual cd start %s dur %s active %s; name(party1) %s"):format(why, tostring(a.has.C_Secrets), tostring(a.C.HasSecretRestrictions),
		tostring(a.restrict[0].state), tostring(a.restrict[1].state), tostring(a.restrict[2].state), tostring(a.restrict[3].state), tostring(a.restrict[4].state),
		tostring(a.restrict[5].state), tostring(a.chat.lockdown), tostring(a.where.combatLockdown), tostring(a.where.inInstance), tostring(a.where.instanceType),
		type(cd) == "table" and cd.startTime or tostring(cd), type(cd) == "table" and cd.duration or "-", type(cd) == "table" and tostring(cd.isActive) or "-",
		type(a.unit.party1.name) == "table" and tostring(a.unit.party1.name[1]) or tostring(a.unit.party1.name))
	return G.Put("SECRETS", line, a)
end
G.SecretsCensus = census

-- a boundary of a restriction: the census now, and again 1 s later
local function mark(ev, extra)
	census(ev, extra)
	L.After(1, function() census(ev .. "+1s", extra) end)
end

-- a chat event: shapes only, once per situation
local function chat(ev, ...)
	local args = pack(...)
	local lockdown = first(tfn("C_ChatInfo", "InChatMessagingLockdown"))
	local inst = call(gfn("IsInInstance"))
	local a = { ev = ev, n = args.n, lockdown = lockdown, inInstance = inst and flag(inst[2]) or "no answer", combat = first(gfn("InCombatLockdown")),
		text = kind(args[1]), sender = kind(args[2]), sender2 = kind(args[5]), guid = kind(args[12]), bnSender = kind(args[13]) }
	local sig = table.concat({ ev, tostring(a.lockdown), tostring(a.inInstance), tostring(a.combat), a.text, a.sender, a.guid }, "|")
	if S.seenChat[sig] or S.chatPuts >= S.CHAT_CAP then return end
	S.seenChat[sig] = true
	S.chatPuts = S.chatPuts + 1
	G.Put("SECRETS", ("%s: lockdown %s, instance %s, combat %s: text %s, sender %s, guid %s (%d args)"):format(ev, tostring(a.lockdown), tostring(a.inInstance),
		tostring(a.combat), a.text, a.sender, a.guid, a.n), a)
end

local function wire()
	if S.wired then return end
	S.wired = true
	for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
		"CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "PVP_MATCH_ACTIVE", "PVP_MATCH_COMPLETE" }) do
		L.On(ev, function() mark(ev) end) -- (L.On skips an event this client lacks)
	end
	-- the payload (type, state) is two small numbers; IsAddOnRestrictionActive is documented to be false while this event is dispatched
	L.On("ADDON_RESTRICTION_STATE_CHANGED", function(rtype, rstate)
		mark("ADDON_RESTRICTION_STATE_CHANGED", { type = flag(rtype), state = flag(rstate), inDispatch = true })
	end)
	for _, ev in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_SAY", "CHAT_MSG_PARTY", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM", "CHAT_MSG_ADDON" }) do
		L.On(ev, function(...) chat(ev, ...) end)
	end
end
G.WireSecrets = wire

-- with the passive checks of GameFacts.lua (the saved flag at login, or the first press); never at load
local startPassive = G.StartPassive
function G.StartPassive(pressed)
	local started = startPassive(pressed)
	wire()
	if started then L.After(7, function() census(pressed and "switched on" or "login") end) end
	return started
end

-- every press of "Game facts", and the end of an Auto check once Game facts is on
local instant = G.Instant
function G.Instant(why)
	if why ~= "auto" or (type(L.db) == "table" and L.db.factsOn == true) then pcall(census, why == "auto" and "auto" or "press") end
	return instant(why)
end
L.GameFactsInstant = G.Instant

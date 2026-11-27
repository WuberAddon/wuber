-- fga b2: tools/apidocs-check.lua learns the fake's chat padding and the Nilable tail of a payload (job 2611, hand-back items 1, 2, 4).
-- The documented shapes: ChatInfoDocumentation.lua CHAT_MSG_* (18 values); UnitDocumentation.lua UNIT_SPELLCAST_START and others
-- (unitTarget, castGUID, spellID, castBarID with castBarID Nilable); UnitCastingInfo and UnitChannelInfo (11 values).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function tool()
	local f = loadfile(T.dir .. "/../tools/apidocs-check.lua")
	ok(f, "tools/apidocs-check.lua is missing or does not compile")
	return f("--lib")
end

local DOC = [[
local Demo =
{
	Name = "Demo",
	Type = "System",
	Events =
	{
		{ Name = "Chat", Type = "Event", LiteralName = "DEMO_CHAT", Payload = { { Name = "a", Type = "string", Nilable = false }, { Name = "b", Type = "string", Nilable = false }, { Name = "c", Type = "number", Nilable = false } } },
		{ Name = "Cast", Type = "Event", LiteralName = "DEMO_CAST", Payload = { { Name = "unit", Type = "string", Nilable = false }, { Name = "guid", Type = "string", Nilable = false }, { Name = "bar", Type = "number", Nilable = true } } },
		{ Name = "TwoTail", Type = "Event", LiteralName = "DEMO_TWOTAIL", Payload = { { Name = "x", Type = "string", Nilable = false }, { Name = "y", Type = "number", Nilable = true }, { Name = "z", Type = "number", Nilable = true } } },
	},
};
APIDocumentation:AddDocumentationTable(Demo);]]

local function keys(findings)
	local out = {}
	for _, f in ipairs(findings) do out[#out + 1] = f.key end
	table.sort(out)
	return table.concat(out, " ")
end

-- guard: infra, failed before because the tool counted the literal call sites of a padded chat event
test("fga b2 apidocs: scanPadded reads the padded events and their length from the harness text; the real harness is read the same way", function()
	local M = tool()
	local p = M.scanPadded("H.CHAT18_EVENTS = { DEMO_A = true, DEMO_B = true }\nlocal function padChat(event, ...)\n\tif H.CHAT18_EVENTS[event] then\n\t\tfor i = a.n + 1, 18 do a[i] = 0 end")
	eq(p.DEMO_A, 18, "length 18")
	eq(p.DEMO_B, 18, "second name")
	eq(next(M.scanPadded("nothing here")), nil, "nothing found: nothing padded (the literal counts then show)")
	local f = assert(io.open(T.dir .. "/harness.lua", "rb"))
	local real = M.scanPadded(f:read("*a"))
	f:close()
	eq(real.CHAT_MSG_SYSTEM, 18, "the fake's CHAT_MSG_SYSTEM is padded to 18")
	eq(real.CHAT_MSG_WHISPER, 18, "and CHAT_MSG_WHISPER")
end)

-- guard: infra, failed before because the tool counted the literal call sites of a padded chat event
test("fga b2 apidocs: a padded event counts at its padded length: a short literal call is no finding, a literal longer than the docs still is", function()
	local M = tool()
	local m = assert(M.loadText(DOC, "d"))
	local model = M.index(m)
	local fires = { DEMO_CHAT = { counts = { [1] = true, [3] = true } } }
	local plain = {}
	M.checkEvents(model, fires, {}, {}, plain)
	eq(keys(plain), "events:DEMO_CHAT", "without the padding the 1-argument call is a finding")
	local padded = {}
	M.checkEvents(model, fires, {}, {}, padded, { DEMO_CHAT = 3 })
	eq(#padded, 0, "with the padding: nothing")
	local over = {}
	M.checkEvents(model, { DEMO_CHAT = { counts = { [4] = true } } }, {}, {}, over, { DEMO_CHAT = 3 })
	eq(keys(over), "events:DEMO_CHAT", "four arguments are still too many")
end)

-- guard: infra, failed before because a fire without the trailing Nilable castBarID was a finding
test("fga b2 apidocs: a fire that leaves out only trailing Nilable slots is no finding; a missing non-Nilable slot still is", function()
	local M = tool()
	local model = M.index(assert(M.loadText(DOC, "d")))
	eq(M.minPayload(model.events.DEMO_CAST.payload), 2, "the last non-Nilable slot")
	eq(M.minPayload(model.events.DEMO_TWOTAIL.payload), 1, "two Nilable slots after it")
	eq(M.minPayload(nil), 0, "no payload")
	local out = {}
	M.checkEvents(model, { DEMO_CAST = { counts = { [2] = true } }, DEMO_TWOTAIL = { counts = { [1] = true, [2] = true } } }, {}, {}, out)
	eq(#out, 0, "the castBarID left out, one or both trailing slots left out: nothing")
	local bad = {}
	M.checkEvents(model, { DEMO_CAST = { counts = { [1] = true } }, DEMO_TWOTAIL = { counts = { [0] = true } } }, {}, {}, bad)
	eq(keys(bad), "events:DEMO_CAST events:DEMO_TWOTAIL", "a slot before the last non-Nilable one is missing")
end)

-- guard: infra, failed before because the samples called UnitCastingInfo and UnitChannelInfo while nothing was cast (0 values)
test("fga b2 apidocs: a sample's setup runs before the call, and the cast samples cast first so the fake gives the documented 11 values", function()
	local samples = dofile(T.dir .. "/../tools/apidocs-samples.lua")
	ok(type(samples.UnitCastingInfo.setup) == "function" and type(samples.UnitChannelInfo.setup) == "function", "both samples cast first")
	for name, want in pairs({ UnitCastingInfo = 11, UnitChannelInfo = 11 }) do
		local w = T.newWorld()
		local c = w:addClient("Apidocs", { spot = "Orgrimmar", class = "WARLOCK", addons = {}, allowMissing = true })
		eq(select("#", c.env[name]("player")), 0, name .. ": nothing before the setup")
		samples[name].setup(w, c)
		eq(select("#", c.env[name]("player")), want, name .. ": the documented count after the setup")
		T.clean(w)
	end
end)

-- guard: infra, failed before because the harness fired PARTY_INVITE_CANCEL with the inviter's name (the docs have no payload)
test("fga b2 apidocs: the harness fires PARTY_INVITE_CANCEL with no argument", function()
	local f = assert(io.open(T.dir .. "/harness.lua", "rb"))
	local text = f:read("*a")
	f:close()
	ok(text:find('fire("PARTY_INVITE_CANCEL")', 1, true), "no argument in the call")
	ok(not text:find('fire("PARTY_INVITE_CANCEL",', 1, true), "none with an argument")
end)

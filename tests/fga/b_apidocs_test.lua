-- fga b apidocs: tools/apidocs-check.lua (the fake game against Blizzard's API documentation): its pure functions, on two tiny inline
-- documentation samples. Copy to tests/r49/zz_fgp_05_test.lua, and the tool (tools-apidocs-check.lua here) to tools/apidocs-check.lua.
-- Run: lua5.1 tests/run.lua "fgp 05"   -- fails today only because tools/apidocs-check.lua does not exist yet.
-- The samples copy the shape of Blizzard_APIDocumentationGenerated (e.g. PartyInfoDocumentation.lua#L650-L680: Events with LiteralName
-- and Payload; Tables of Type "Enumeration" with Fields { Name, EnumValue }; Functions with Returns, MayReturnNothing,
-- IsProtectedFunction), https://github.com/Gethe/wow-ui-source/blob/734f065/Interface/AddOns/Blizzard_APIDocumentationGenerated/
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local DOC_A = [[
local Demo =
{
	Name = "Demo",
	Type = "System",
	Namespace = "C_Demo",
	Functions =
	{
		{ Name = "Two", Type = "Function", Returns = { { Name = "a", Type = "number", Nilable = false }, { Name = "b", Type = "number", Nilable = false } } },
		{ Name = "Maybe", Type = "Function", MayReturnNothing = true, Returns = { { Name = "x", Type = "number", Nilable = false } } },
		{ Name = "Reg", Type = "Function", Returns = { { Name = "result", Type = "DemoResult", Nilable = false } } },
	},
	Events =
	{
		{ Name = "Fired", Type = "Event", LiteralName = "DEMO_FIRED", Payload = { { Name = "p", Type = "number", Nilable = false }, { Name = "q", Type = "bool", Nilable = false } } },
		{ Name = "Quiet", Type = "Event", LiteralName = "DEMO_QUIET" },
	},
	Tables =
	{
		{ Name = "DemoResult", Type = "Enumeration", NumValues = 3, MinValue = 0, MaxValue = 2,
			Fields = { { Name = "Ok", Type = "DemoResult", EnumValue = 0 }, { Name = "Busy", Type = "DemoResult", EnumValue = 1 }, { Name = "Gone", Type = "DemoResult", EnumValue = 2 } } },
	},
};

APIDocumentation:AddDocumentationTable(Demo);]]

local DOC_B = [[
local SimpleDemoAPI =
{
	Name = "SimpleDemoAPI",
	Type = "ScriptObject",
	Functions =
	{
		{ Name = "Show", Type = "Function", IsProtectedFunction = true },
		{ Name = "Hide", Type = "Function", IsProtectedFunction = true },
		{ Name = "GetLeft", Type = "Function", MayReturnNothing = true, Returns = { { Name = "left", Type = "uiUnit", Nilable = false } } },
	},
};

APIDocumentation:AddDocumentationTable(SimpleDemoAPI);]]

local function tool()
	local f = loadfile(T.dir .. "/../tools/apidocs-check.lua")
	ok(f, "tools/apidocs-check.lua is missing or does not compile")
	local M = f("--lib")
	ok(type(M) == "table" and type(M.loadText) == "function", "loaded with --lib it returns its functions")
	return M
end
local function model(M)
	local a = assert(M.loadText(DOC_A, "a"))
	local b = assert(M.loadText(DOC_B, "b"))
	local all = {}
	for _, t in ipairs(a) do all[#all + 1] = t end
	for _, t in ipairs(b) do all[#all + 1] = t end
	return M.index(all)
end
local function keys(findings)
	local out = {}
	for _, f in ipairs(findings) do out[#out + 1] = f.key end
	table.sort(out)
	return table.concat(out, " ")
end

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: a documentation file is run in an empty sandbox: its tables come back, a file that reaches for the real game does not", function()
	local M = tool()
	local found = assert(M.loadText(DOC_A, "a"))
	eq(#found, 1, "one table handed over")
	eq(found[1].Namespace, "C_Demo", "its data")
	for _, evil in ipairs({ "os.exit(1)", "io.open('x', 'w')", "print('hi')", "require('harness')" }) do
		local got, err = M.loadText("local X = { Name = 'x' }; " .. evil .. "; APIDocumentation:AddDocumentationTable(X)", "evil")
		eq(got, nil, "refused: " .. evil)
		ok(tostring(err):find("nil value", 1, true) or tostring(err):find("attempt to", 1, true), "an error, not an effect: " .. tostring(err))
	end
	-- a file that sets a global sets it in its own sandbox only
	eq(#assert(M.loadText("local X = { Name = 'x' }; HACKED = true; APIDocumentation:AddDocumentationTable(X)", "set")), 1, "loads")
	eq(rawget(_G, "HACKED"), nil, "no global leaked")
	local looping, err = M.loadText("local X = {}; while true do end", "loop")
	eq(looping, nil, "an endless file is stopped")
	ok(tostring(err):find("too long", 1, true), "and says so: " .. tostring(err))
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: the index reads functions, widget methods, events (LiteralName, payload length) and enumerations", function()
	local m = model(tool())
	eq(m.funcs["C_Demo.Two"].nret, 2, "Two returns 2")
	eq(m.funcs["C_Demo.Maybe"].mrn, true, "Maybe may return nothing")
	eq(m.methods.Show.protected, true, "Show is protected")
	eq(m.methods.GetLeft.mrn, true, "a widget method keeps its MayReturnNothing")
	eq(m.events.DEMO_FIRED.n, 2, "payload length 2")
	eq(m.events.DEMO_QUIET.n, 0, "no payload: 0")
	eq(m.enums.DemoResult.fields.Gone, 2, "an enum field")
	eq(m.enums.DemoResult.n, 3, "NumValues")
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: returns and mrn: a different number of values is a finding, nothing from a MayReturnNothing function is allowed, a value for its empty sample is a finding", function()
	local M = tool()
	local m = model(M)
	local samples = { ["C_Demo.Two"] = { args = {} }, ["C_Demo.Maybe"] = { args = {}, empty = { 0 } } }
	local out = {}
	M.checkReturns(m, samples, function(name, args)
		if name == "C_Demo.Two" then return 1 end -- the fake gives one value, the docs say two
		if args == samples["C_Demo.Maybe"].empty then return 1 end -- an answer where the game answers nothing
		return 0 -- no answer is allowed for MayReturnNothing
	end, out)
	eq(keys(out), "mrn:C_Demo.Maybe returns:C_Demo.Two", "exactly these two")
	local clean = {}
	M.checkReturns(m, samples, function(name, args) if name == "C_Demo.Two" then return 2 end return 0 end, clean)
	eq(#clean, 0, "the right counts: nothing to report")
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: fire calls: the argument count is read from the text, '...' and unpack make it unknown", function()
	local M = tool()
	local fires = M.scanFires([[
		client:fire("DEMO_FIRED", 1, false)
		c:fire("DEMO_QUIET")
		w:fireAll("DEMO_FIRED", f(1, 2), { 1, 2 }, "a,b)")
		fire("DEMO_DYN", ...)
		fire("DEMO_DYN2", unpack(t))
		-- fire("DEMO_COMMENT", 1)
	]])
	eq(fires.DEMO_FIRED.counts[2], true, "two arguments")
	eq(fires.DEMO_FIRED.counts[3], true, "and three with a call, a table and a string holding a comma and a bracket")
	eq(fires.DEMO_QUIET.counts[0], true, "none")
	eq(fires.DEMO_DYN.dynamic, true, "... is dynamic")
	eq(fires.DEMO_DYN2.dynamic, true, "unpack is dynamic")
	eq(fires.DEMO_COMMENT, nil, "a comment is not a call")
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: events: a fire with another argument count, an event the docs lack, and a registered event the fake does not know or never fires", function()
	local M = tool()
	local m = model(M)
	local out = {}
	M.checkEvents(m, { DEMO_FIRED = { counts = { [1] = true } }, DEMO_QUIET = { counts = { [0] = true } }, DEMO_OLD = { counts = { [0] = true } }, DEMO_DYN = { counts = {}, dynamic = true } },
		{ DEMO_FIRED = true, DEMO_QUIET = true, DEMO_NEW = true }, { DEMO_FIRED = true }, out)
	eq(keys(out), "events:DEMO_DYN events:DEMO_FIRED events:DEMO_NEW events:DEMO_OLD events:DEMO_QUIET",
		"fired but not in the docs (two); fired 1 against 2; registered but not in the docs; registered, in the docs, unknown to the fake")
	local good = {}
	M.checkEvents(m, { DEMO_FIRED = { counts = { [2] = true } }, DEMO_QUIET = { counts = { [0] = true } } }, { DEMO_FIRED = true }, { DEMO_FIRED = true }, good)
	eq(#good, 0, "matching counts, known, fired: nothing")
	local known = M.scanKnownEvents('H.KNOWN_EVENTS = {}\nfor _, e in ipairs({ "A_B", "C_D" }) do\n\tH.KNOWN_EVENTS[e] = true')
	eq(known.A_B and known.C_D, true, "the fake's own list of events is read from its text")
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: enums: missing values, extra keys and other numbers are findings", function()
	local M = tool()
	local m = model(M)
	local out = {}
	M.checkEnums(m, { DemoResult = { Ok = 0, Busy = 1 }, NotThere = { A = 1 }, Plain = 5 }, out)
	eq(keys(out), "enums:DemoResult enums:NotThere", "two values of three: one finding; an Enum the docs lack; a non-table is skipped")
	ok(out[1].text:find("docs 3 values, the fake 2", 1, true) and out[1].text:find("Gone", 1, true), out[1].text)
	local out2 = {}
	M.checkEnums(m, { DemoResult = { Ok = 0, Busy = 5, Gone = 2, Extra = 9 } }, out2)
	eq(keys(out2), "enums:DemoResult.Busy enums:DemoResult.Extra", "another number; a key the docs do not have")
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: protected: a documented protected method the fake defines but never guards is a finding", function()
	local M = tool()
	local m = model(M)
	local harness = [[
local function setShown(self, on, method)
	if blocked(self, method) then return end
end
function Frame:Show() setShown(self, true, "Show") end
function Frame:Hide() local s = 1 end
function Frame:GetLeft() return 1 end
]]
	local guarded, defined = M.scanGuarded(harness), M.scanDefined(harness)
	eq(guarded.Show, true, "Show goes through a helper that calls blocked()")
	eq(guarded.Hide, nil, "Hide does not")
	local out = {}
	M.checkProtected(m, guarded, defined, out)
	eq(keys(out), "protected:Hide", "only Hide: GetLeft is not protected, Show is guarded")
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: the allow file: known findings are not new, an allow line with no finding is stale, the first column is the key", function()
	local M = tool()
	local known = M.parseKnown("# comment\nenums:A\tbecause\n\nenums:B\tbecause too\n")
	eq(known["enums:A"], "because", "a line")
	local v = M.verdict({ { key = "enums:A", text = "x" }, { key = "events:C", text = "y" } }, known)
	eq(#v.fresh, 1, "one new")
	eq(v.fresh[1].key, "events:C", "the new one")
	eq(v.known, 1, "one known")
	eq(v.stale[1], "enums:B", "one stale")
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: calls and constants: C_ names and bare calls are found, comments are not, a constant that differs is a finding", function()
	local M = tool()
	local m = model(M)
	local calls = M.scanCalls("local a = C_Demo.Two() ; pcall(C_Demo.Gone, 1) ; Foo(1) ; x:Bar() ; t.Baz(); -- C_Demo.Commented()\n")
	eq(calls.c["C_Demo.Two"], true, "a call")
	eq(calls.c["C_Demo.Gone"], true, "a use passed to pcall")
	eq(calls.c["C_Demo.Commented"], nil, "a comment")
	eq(calls.bare.Foo, true, "a bare call")
	eq(calls.bare.Bar, nil, "a method call is not a global")
	local out = {}
	M.checkExists(m, calls, { Foo = true }, out)
	eq(keys(out), "exists:C_Demo.Gone exists:Foo", "the missing C_ function and the global the fake defines that the docs lack")
	local c = {}
	M.checkConstants("WOW_PROJECT_ID\t18\tthe real client\n", { WOW_PROJECT_ID = 2 }, c)
	eq(keys(c), "constants:WOW_PROJECT_ID", "2 against 18")
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: returns: the first value must be the documented kind (RegisterAddonMessagePrefix gives a result number, the fake gives true)", function()
	local M = tool()
	local m = model(M)
	eq(M.docType(m, "DemoResult"), "number", "an enumeration is a number")
	eq(M.docType(m, "bool"), "boolean", "bool")
	eq(M.docType(m, "WOWGUID"), "string", "a GUID is text")
	eq(M.docType(m, "SomeStruct"), nil, "a struct is not judged")
	local out = {}
	M.checkReturns(m, { ["C_Demo.Reg"] = { args = {} } }, function() return 1, "boolean" end, out)
	eq(keys(out), "returns:C_Demo.Reg", "a boolean where the docs say a result number")
	ok(out[1].text:find("boolean", 1, true) and out[1].text:find("DemoResult", 1, true), out[1].text)
	local good = {}
	M.checkReturns(m, { ["C_Demo.Reg"] = { args = {} } }, function() return 1, "number" end, good)
	eq(#good, 0, "a number is right")
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: events: a literal in a slot of another kind than the documented payload is a finding (PARTY_INVITE_REQUEST slots 7 and 8)", function()
	local M = tool()
	local m = model(M)
	local fires = M.scanFires([[client:fire("DEMO_FIRED", sender, "x-1")]])
	eq(fires.DEMO_FIRED.lits[2][1], "sender", "the argument texts are kept")
	local out = {}
	M.checkEvents(m, fires, {}, {}, out)
	eq(keys(out), "events:DEMO_FIRED#2", "slot 2 is documented as a bool (q); the fake fires a string; slot 1 is not a literal, so it is not judged")
	local good = {}
	M.checkEvents(m, M.scanFires([[client:fire("DEMO_FIRED", 5, false)]]), {}, {}, good)
	eq(#good, 0, "number and bool: right")
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: Enum and Constants in a documentation file are stand-ins: the file loads, a leaf names its path, a marker is an unknown value and never a mismatch", function()
	local M = tool()
	local found = assert(M.loadText([==[
local X = { Name = "X",
	Functions = { { Name = "F", Type = "Function", SecretReturnsForAspect = { Enum.SecretAspect.Cooldown } } },
	Tables = {
		{ Name = "DemoResult", Type = "Enumeration", NumValues = Constants.Demo.Count, Fields = {
			{ Name = "Ok", Type = "DemoResult", EnumValue = 0 },
			{ Name = "Busy", Type = "DemoResult", EnumValue = Enum.Demo.Busy + 1 } } },
		{ Name = "K", Type = "Constants", Values = { { Name = "A", Type = "number", Value = Constants.Demo.Last - Constants.Demo.First + 1 } } },
	} };
APIDocumentation:AddDocumentationTable(X);]==], "stand-in"))
	local t = found[1]
	local leaf = t.Functions[1].SecretReturnsForAspect[1]
	ok(M.isMarker(leaf), "a leaf is a marker")
	eq(tostring(leaf), "Enum.SecretAspect.Cooldown", "it names its path")
	eq(M.isMarker(5), false, "a real number is not a marker")
	eq(tostring(t.Tables[1].Fields[2].EnumValue), "(Enum.Demo.Busy+1)", "arithmetic on a marker is a marker")
	eq(tostring(t.Tables[2].Values[1].Value), "((Constants.Demo.Last-Constants.Demo.First)+1)", "also a chain of them")
	local m = M.index(found)
	eq(m.enums.DemoResult.n, 2, "a marker NumValues is replaced by the number of fields")
	local out = {}
	M.checkEnums(m, { DemoResult = { Ok = 0, Busy = 7 } }, out)
	eq(#out, 0, "Busy is unknown in the docs (a marker): not a mismatch")
	local out2 = {}
	M.checkEnums(m, { DemoResult = { Ok = 5, Busy = 7 } }, out2)
	eq(keys(out2), "enums:DemoResult.Ok", "a real number still is")
	eq(M.loadText("local X = {}; Enum.A.B.x(); APIDocumentation:AddDocumentationTable(X)", "call"), nil, "a stand-in is data only: calling it is an error, not an effect")
end)

-- guard: infra, failed before because tools/apidocs-check.lua did not exist
test("fga b apidocs: the fake's Enum proxy is read through, and a name ending in an underscore (CHAT_MSG_ .. kind) is not an event", function()
	local M = tool()
	local inner = { SendResult = { Success = 0 } }
	local proxy = setmetatable({}, { __index = function(_, f) return inner[f] end })
	eq(M.plainTable(proxy), inner, "the table behind the proxy")
	eq(M.plainTable({ A = 1 }).A, 1, "a plain table is itself")
	local fires = M.scanFires([[
		c:chatEvent("CHAT_MSG_" .. kind, text)
		c:chatEvent("CHAT_MSG_SYSTEM", text)
	]])
	eq(fires["CHAT_MSG_"], nil, "a prefix is skipped")
	eq(fires.CHAT_MSG_SYSTEM.counts[1], true, "a whole name is read")
	eq(M.scanRegistered('f:RegisterEvent("FOO_")\nf:RegisterEvent("BAR_BAZ")').FOO_, nil, "also when registered")
	eq(M.scanRegistered('f:RegisterEvent("BAR_BAZ")').BAR_BAZ, true, "a whole name")
end)

-- guard: infra, failed before because tools/apidocs-known.txt did not exist
test("fga b apidocs: the allow file: every line is key TAB reason, the reason is not empty, and nothing a fake-game fix owns is accepted", function()
	local f = assert(io.open(T.dir .. "/../tools/apidocs-known.txt", "r"), "tools/apidocs-known.txt is missing")
	local n = 0
	for line in f:lines() do
		if line:match("%S") and not line:match("^#") then
			n = n + 1
			local key, reason = line:match("^([^\t]+)\t(.+)$")
			ok(key and #reason > 10, "key TAB reason: " .. line:sub(1, 60))
			ok(not key:match("^mrn:") and not key:match("^returns:") and not key:match("^constants:") and not key:match("^exists:"),
				"a finding another group fixes is not accepted: " .. key)
			ok(not key:match("^events:CHAT_MSG") and not key:match("^events:UNIT_SPELLCAST") and key ~= "enums:SendAddonMessageResult", "not accepted: " .. key)
		end
	end
	f:close()
	ok(n >= 30, "the protected widget methods, TooltipDataType and PARTY_INVITE_REQUEST slots are listed with reasons: " .. n)
end)

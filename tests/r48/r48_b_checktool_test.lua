-- Round 48, group B: REV-r48-1 (tools/check.lua), the twin of BRK-01 in the checking tool. Its TOC rule fails a
-- module whose dependency comes later in the TOC; a module file that lists ITSELF as a dependency used to pass
-- (the same place in the TOC is not "later"). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, CHECK = T.test, T.eq, T.ok, T.CHECK

test("r48 b: REV-r48-1 tools/check.lua fails a module file that lists itself as a dependency", function()
	local HEAD = "local _, W = ...\n"
	local src = {
		["Net/Base.lua"] = HEAD .. "local Mod = W.Module(\"Net.Base\")\n",
		["Net/Self.lua"] = HEAD .. "local Mod = W.Module(\"Net.Self\", { \"Net.Base\", \"Net.Self\" })\n",
		["Net/Fine.lua"] = HEAD .. "local Mod = W.Module(\"Net.Fine\", { \"Net.Base\", \"Net.Self\" })\n",
	}
	local res = CHECK.check({ files = { "Net/Base.lua", "Net/Self.lua", "Net/Fine.lua" }, read = function(p) return src[p] end,
		globals = { read = { print = true }, write = {} }, owner = {}, legacy = {}, allow = {} })
	local all = table.concat(res.fails, "\n")
	ok(all:find("FAIL Net/Self.lua:0 Net.Self loads before its dependency Net.Self (TOC order)", 1, true),
		"the self-dependency fails the check, in:\n" .. all)
	local n = 0
	for _ in all:gmatch("loads before its dependency") do n = n + 1 end
	eq(n, 1, "only the self-dependency: a dependency earlier in the TOC still passes, in:\n" .. all)
end)

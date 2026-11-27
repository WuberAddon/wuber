-- Round 25 T2: the "Login tips" switch (Settings > Riding), its search words, /wuber tips and /wuber tips off.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = r.W
	local calls = {}
	local m = W.Mod("UI.Tips")
	m.SetOn = function(on) calls[#calls + 1] = "on:" .. tostring(on); W.db.tipsOn = on end
	m.ShowNow = function() calls[#calls + 1] = "show" end
	m.IsOn = function() return W.db.tipsOn ~= false end
	return w, r, W, calls
end

test("r25 B: /wuber tips turns tips on and shows one; /wuber tips off turns them off", function()
	local w, r, W, calls = setup()
	W.SlashCommand("tips")
	eq(calls[1], "on:true"); eq(calls[2], "show")
	W.SlashCommand("tips off")
	eq(calls[3], "on:false"); eq(#calls, 3)
	eq(W.db.tipsOn, false)
end)

test("r25 B: without UI.Tips the flag is set directly", function()
	local w, r, W = setup()
	local m = W.Mod("UI.Tips")
	m.SetOn = nil; m.ShowNow = nil; m.IsOn = nil
	W.SlashCommand("tips off")
	eq(W.db.tipsOn, false)
	W.SlashCommand("tips")
	eq(W.db.tipsOn, true)
end)

test("r25 B: Login tips switch is on the Riding page, searchable by tips, hints, help", function()
	local w, r, W, calls = setup()
	r.env.SlashCmdList.WUBER("settings")
	w:advance(1)
	local st = r.W.UI.settings
	local t = st.controls.tips
	ok(t, "switch exists")
	eq(t.get(), true)
	local indexed = false
	for _, e in ipairs(st.index or {}) do if e.label == "Login tips" then indexed = true end end
	ok(indexed, "indexed")
	local found = r.W.Mod("UI.Settings.Rows").KEYWORDS["Login tips"]
	ok(found, "keywords")
	for _, word in ipairs({ "tips", "hints", "help" }) do ok(found:find(word, 1, true), word) end
end)

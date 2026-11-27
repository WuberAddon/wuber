-- Design round 1, group F: gold is for prices, amber warnings are red, section labels are not violet or gold.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function same(a, b)
	return math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01
end

local function walk(f, fn, seen)
	seen = seen or {}
	if seen[f] then return end
	seen[f] = true
	if f.GetRegions then for _, r in ipairs({ f:GetRegions() }) do fn(r) end end
	if f.GetChildren then for _, c in ipairs({ f:GetChildren() }) do walk(c, fn, seen) end end
end

-- section labels are sentence case now, so they are found by name
local LABELS = { ["Driving: most used"] = true, ["Driving: your card"] = true, ["Riding"] = true, ["Map"] = true,
	["Sound"] = true, ["Effects"] = true, ["This window"] = true }
test("d1 f: Settings section labels are not gold or violet", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(2)
	local W = c.W
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.OpenSettings("drive")
	w:advance(1)
	local TH = W.Mod("Theme.Tokens") and nil
	local ui = W.UI.settings
	ok(ui, "settings open")
	local gold, glow = { W.Theme.RGB("gold") }, { W.Theme.RGB("glow") }
	local n, bad = 0, {}
	for _, r in ipairs(c:findText("%S")) do
		do
			local t = r:GetText()
			if type(t) == "string" and LABELS[t] then
				n = n + 1
				local col = { r:GetTextColor() }
				if same(col, gold) or same(col, glow) then bad[#bad + 1] = t end
			end
		end
	end
	ok(n > 0, "control: found section labels (" .. n .. ")")
	eq(#bad, 0, "no gold or violet capitals: " .. table.concat(bad, ", "))
	T.clean(w)
end)

test("d1 f: a warning toast is red, a price toast is gold, a request toast is violet, away is grey", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, {})
	w:advance(2)
	local W = c.W
	local function col(kind)
		local t = W.UI.Toast("Hello", kind)
		ok(t and t.icon, kind .. " toast made")
		local got = { t.icon:GetVertexColor() }
		w:advance(6)
		return got
	end
	local R = W.Theme.RGB
	ok(same(col("warn"), { R("red") }), "warn is red")
	ok(same(col("shards"), { R("red") }), "shards is red")
	ok(same(col("paid"), { R("gold") }), "a paid toast stays gold")
	ok(same(col("request"), { R("glow") }), "request is violet")
	ok(same(col("away"), { R("muted") }), "away is grey")
	T.clean(w)
end)

-- Polestar lesson 18: the Settings search understands a question ("how do I turn off sounds?"):
-- question and filler words are ignored, the rest must match as before; the box says it takes a question.
-- One-word searches behave exactly as before.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function open()
	local w = T.newWorld()
	local c = T.driver(w, T.BOB)
	T.settle(w)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings()
	w:advance(1)
	return w, c, c.W.UI.settings, c.W.Mod("UI.Settings.Find")
end

local function labels(list)
	local out = {}
	for i, m in ipairs(list) do out[i] = m.label end
	return out
end
local function has(list, label)
	for _, m in ipairs(list) do
		if m.label == label then return true end
	end
	return false
end

test("polestar p18: a question finds the setting its content words name", function()
	local w, c, st, Find = open()
	local list = Find.match("how do I turn off sounds?")
	ok(has(list, "Sounds"), "'how do I turn off sounds?' should find Sounds, got: " .. T.list(labels(list), ", "))
	ok(has(Find.match("Where is the minimap button?"), "Minimap button"), "'Where is the minimap button?' finds Minimap button")
	ok(has(Find.match("can I stop the sound"), "Sounds"), "'can I stop the sound' finds Sounds")
	T.clean(w)
end)

-- guard: passes on main by design; it keeps one-word and plain searches exactly as they were
test("polestar p18: one-word and plain searches are unchanged", function()
	local w, c, st, Find = open()
	eq(labels(Find.match("sounds"))[1], "Sounds", "one word: Sounds first")
	-- a word that is only filler still searches for itself
	for _, q in ipairs({ "stop", "the", "off" }) do
		for _, m in ipairs(Find.match(q)) do
			local rec = m.rec
			local hay = ((rec.label or "") .. " " .. (rec.desc or "") .. " " .. (rec.tip or "") .. " " .. (c.W.Mod("UI.Settings.Rows").KEYWORDS[rec.label] or "") .. " " .. m.section):lower()
			ok(hay:find(q, 1, true), "'" .. q .. "' matches " .. m.label .. " only by holding the word")
		end
	end
	eq(#Find.match("zzzz qqqq"), 0, "no match stays no match")
	eq(#Find.match("   "), 0, "blank")
	T.clean(w)
end)

local TEXTS = { ["Ask or search: how do I mute sounds?"] = true, ["Ask or search settings"] = true, ["Search settings"] = true }

local function openWide()
	local w = T.newWorld()
	local c = T.rider(w)
	T.settle(w)
	c.W.db.coach = true
	c.wide = true
	c.W.db.fold = { v = 1, pages = {}, narrow = false }
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings()
	w:advance(1)
	return w, c, c.W.UI.settings
end

local function room(box) return box:GetWidth() - 70 end

test("polestar p18: the placeholder is the longest of three that fits on one line (folded box)", function()
	local w, c, st = open()
	local box = st.find.box
	eq(box.hint:GetText(), "Ask or search: how do I mute sounds?", "the wide box shows the long question")
	ok(c.W.Theme.TextWidth(box.hint) <= room(box), "not cut: " .. c.W.Theme.TextWidth(box.hint) .. " in " .. room(box))
	T.clean(w)
end)

test("polestar p18: the placeholder in the narrow unfolded column is one of the three and not cut", function()
	local w, c, st = openWide()
	local box = st.find.box
	local text = box.hint:GetText()
	ok(TEXTS[text], "one of the three texts: " .. tostring(text))
	ok(c.W.Theme.TextWidth(box.hint) <= room(box), "not cut: " .. c.W.Theme.TextWidth(box.hint) .. " in " .. room(box))
	-- the longest that fits: nothing longer would have fitted
	local order = c.W.Mod("UI.Settings.Find").HINTS
	for _, longer in ipairs(order) do
		if longer == text then break end
		ok(c.W.Theme.TextWidth(box.hint, longer) > room(box), "a longer text did not fit: " .. longer)
	end
	T.clean(w)
end)

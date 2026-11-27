-- Tests of the word rule of the layout sweep (tests/layout/words.lua, E.countWords, Run.wordHit). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local S = H.state
local root = T.root or H.root
local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)
local Words = assert(loadfile(root .. "/tests/layout/words.lua"))()

-- a client with no addon and one Wuber-tagged window holding the given texts, each on its own line
local function shot(texts)
	local w = T.newWorld()
	local c = w:addClient("Word Count", { spot = "Orgrimmar", class = "MAGE", addons = {}, allowMissing = true, screenW = 1000, screenH = 800 })
	local env = c.env
	local win = env.CreateFrame("Frame", nil, env.UIParent)
	win:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 100, 100)
	win:SetSize(600, 600)
	S[win].lcTag = "Wuber"
	for i, s in ipairs(texts) do
		local fs = win:CreateFontString(nil, "OVERLAY")
		fs:SetFont("Fonts\\FRIZQT__.TTF", 12)
		fs:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 10, 560 - (i - 1) * 20)
		fs:SetWidth(500)
		fs:SetWordWrap(false)
		fs:SetJustifyH("LEFT")
		fs:SetText(s)
	end
	return c
end

local function words(texts)
	local _, _, n = E.check(shot(texts))
	return n
end

test("v24 words rule: a number like 50s is one word, and a colour-coded text counts its words only", function()
	eq(words({ "Mia summons for 50s" }), 4, "four words")
	eq(words({ "|cffff0000Red|r and |cff00ff00green|r words" }), 4, "colour codes are not words")
	eq(E.countWords("50s"), 1, "50s")
end)

test("v24 words rule: a text of only symbols counts 0", function()
	eq(E.countWords("- . ! ? ..."), 0, "punctuation")
	eq(E.countWords("\226\128\162 \194\183 \226\134\146"), 0, "bullets and arrows")
	eq(words({ "->", "Go" }), 1, "only the Go shows as a word")
end)

test("v24 words rule: 13 words against a budget of 12 is one words hit, 12 words is none", function()
	local twelve = "one two three four five six seven eight nine ten eleven twelve"
	eq(words({ twelve }), 12, "twelve counted")
	eq(words({ twelve, "thirteen" }), 13, "thirteen counted")
	local WR = {}
	WR.budget = Words.budget
	local kind, budget = Words.budget("tipcard/folded")
	eq(kind, "Card", "the tip card is a Card")
	eq(budget, 12, "a Card has 12 words")
	local Run = assert(loadfile(root .. "/tests/layout/run.lua"))(H, E, root)
	local hit = Run.wordHit("tipcard/folded", 13)
	ok(hit, "13 words is a hit")
	eq(hit.kind, "words", "kind")
	eq(hit.key, "words", "key")
	eq(hit.detail, "13 words, budget 12 (Card)", "detail")
	eq(Run.wordHit("tipcard/folded", 12), nil, "12 words is none")
end)

test("v24 words rule: Working is the default, 70 folded and 120 unfolded; the floating button is 40", function()
	local k, b = Words.budget("settings/folded")
	eq(k, "Working", "default kind") eq(b, 70, "folded")
	k, b = Words.budget("settings/unfolded")
	eq(b, 120, "unfolded")
	k, b = Words.budget("float_open/folded")
	eq(k, "Float", "float kind") eq(b, 40, "float budget")
	k, b = Words.budget("confirm_dial/unfolded")
	eq(k, "Action", "confirm is an Action") eq(b, 40, "action budget")
	k, b = Words.budget("help/folded")
	eq(k, "Reading", "help reads") eq(b, 150, "reading budget")
end)

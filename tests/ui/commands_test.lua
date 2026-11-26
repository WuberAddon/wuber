-- Tests of UI.Commands: W.SelfTest's font check (the author's test of 2.2.3, 18 Nov: "Check my game"
-- said the addon's regular font wasn't working when it was). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local BROKEN = "Interface\\AddOns\\Wuber\\Media\\fonts\\NoSuchFont.ttf"

local function fontsRow(W)
	for _, x in ipairs(W.SelfTest()) do
		if x.name == "Fonts" then return x end
	end
end

-- This client: SetFont says false for an addon's font files even when they load.
local function saysFalse(env)
	local real = env.CreateFrame
	env.CreateFrame = function(...)
		local f = real(...)
		if type(f) == "table" and type(f.CreateFontString) == "function" then
			local make = f.CreateFontString
			f.CreateFontString = function(self, ...)
				local fs = make(self, ...)
				local set = fs.SetFont
				fs.SetFont = function(s, path, ...)
					local res = set(s, path, ...)
					if type(path) == "string" and path:find("^Interface") then return false end
					return res
				end
				return fs
			end
		end
		return f
	end
end

test("ui.commands: contract (registered, deps, header, public names)", function()
	local W, w = T.contract("UI.Commands", "tests/ui/commands_test.lua", {
		["W.SelfTest"] = "function", ["W.SlashCommand"] = "function", ["W.MissingParts"] = "function",
	})
	ok(W, "loaded")
	T.clean(w)
end)

test("ui.commands: Check my game: a font that loads works even when SetFont says false; one that never loads isn't working", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { prepare = saysFalse })
	T.settle(w)
	w:advance(10)
	local W = r.W
	-- the world is this client's: SetFont says false for the addon font, and the text keeps its width
	local probe = r.env.CreateFrame("Frame"):CreateFontString(nil, "OVERLAY")
	eq(probe:SetFont(W.Theme.FONTS.regular, 14, ""), false, "SetFont says false for the addon font")
	eq(probe:GetFont(), W.Theme.FONTS.regular, "but the font is set")
	-- a font that loads: works (GetFont gives the file back), also once the first ask's few
	-- seconds of grace are over
	local row = fontsRow(W)
	ok(row, "a Fonts row")
	eq(row.ok, true, "Fonts work: " .. tostring(row.detail))
	w:advance(6)
	row = fontsRow(W)
	eq(row.ok, true, "Fonts still work after the grace: " .. tostring(row.detail))
	-- a font file that isn't there: asked for just now it may still be loading, so not a fail yet;
	-- still nothing 6 s later: not working, and the row names it
	W.Theme.FONTS.zzBroken = BROKEN
	row = fontsRow(W)
	eq(row.ok, true, "first asked just now: still loading")
	w:advance(6)
	row = fontsRow(W)
	eq(row.ok, false, "a font that never loads: not working")
	eq(row.detail, "NoSuchFont.ttf", "the row names the file")
	W.Theme.FONTS.zzBroken = nil
	eq(fontsRow(W).ok, true, "the game's and Wuber's own fonts all work")
	w.missingFiles[BROKEN] = nil -- (on purpose)
	T.clean(w)
end)

test("ui.commands: Check my game in a plain client: every font works", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	w:advance(10)
	local row = fontsRow(r.W)
	eq(row and row.ok, true, "Fonts work: " .. tostring(row and row.detail))
	T.clean(w)
end)

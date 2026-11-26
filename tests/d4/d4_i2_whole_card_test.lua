-- Design round 4, group I2: the whole-text hover on Wuber's own tip card (WuberTip), no game tooltip.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local LONG = "Aaaaaaaaaaaaaaa-Bbbbbbbbbbbbbbbbbbb of the Very Long Realm Name"

local CUR
local function setup()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local f = a.env.CreateFrame("Button", nil, a.env.UIParent)
	f:SetSize(120, 30)
	f:SetPoint("CENTER")
	f:Show()
	f:EnableMouse(true)
	f.wuberWorld = w
	CUR = w
	return w, a, a.W, f
end

local function label(W, f, text, width)
	local fs = W.Theme.Text(f, "body", "white", "LEFT", "bold")
	fs:SetPoint("LEFT", f, "LEFT", 4, 0)
	fs:SetWidth(width or 100)
	fs:SetText(text)
	local world = f.wuberWorld or CUR
	world:advance(1)
	return fs
end

test("d4 i2 whole: the card carries the whole text first, then the owner's title and words, and no game tooltip", function()
	local w, a, W, f = setup()
	label(W, f, LONG)
	W.Theme.Tip(f, "Open the profile", "Shows who this is.")
	f:GetScript("OnEnter")(f)
	eq(W.Theme.TipOwner(), f, "the card is up for the owner")
	local card = a.env.WuberTip
	eq(card.title:GetText(), LONG, "the whole text is the card's title")
	eq(card.lines[1]:GetText(), "Open the profile", "then the owner's own title")
	eq(card.lines[2]:GetText(), "Shows who this is.", "then its words")
	f:GetScript("OnLeave")(f)
	ok(not a.env.WuberTip:IsShown(), "gone on leave")
	T.clean(w)
end)

test("d4 i2 whole: an owner with no tip of its own gets the card for the whole text only, and nothing when the label fits", function()
	local w, a, W, f = setup()
	label(W, f, LONG)
	f:GetScript("OnEnter")(f)
	eq(a.env.WuberTip.title:GetText(), LONG, "only the whole text")
	f:GetScript("OnLeave")(f)
	local g = a.env.CreateFrame("Button", nil, a.env.UIParent)
	g:SetSize(120, 30) g:SetPoint("CENTER") g:EnableMouse(true) g.wuberWorld = w
	label(W, g, "Anita", 100)
	local on = g:GetScript("OnEnter")
	if on then on(g) end
	ok(W.Theme.TipOwner() ~= g, "a label that fits shows no card")
	T.clean(w)
end)

test("d4 i2 whole: the whole text is not repeated when it is the owner's title", function()
	local w, a, W, f = setup()
	label(W, f, LONG)
	W.Theme.Tip(f, LONG, "Same words.")
	f:GetScript("OnEnter")(f)
	local card = a.env.WuberTip
	eq(card.title:GetText(), LONG)
	eq(card.lines[1]:GetText(), "Same words.", "the title once, then the words")
	T.clean(w)
end)

test("d4 i2 whole: the hover rides on the nearest mouse-taking ancestor (up to 3 up), no hover-only frame", function()
	local w, a, W, f = setup()
	f:EnableMouse(true)
	local mid = a.env.CreateFrame("Frame", nil, f)
	mid:SetAllPoints(f)
	local fs = label(W, mid, LONG)
	eq(fs.wuberWhole, f, "two up, the control that already takes the mouse")
	for _, c in ipairs({ f:GetChildren() }) do ok(not c.wuberWholeMouse, "no hover-only frame") end
	-- a window-sized mouse-taking frame is no owner for a label
	local big = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	big:SetSize(600, 500) big:SetPoint("CENTER") big:EnableMouse(true) big.wuberWorld = w
	local fs2 = label(W, big, LONG)
	ok(fs2.wuberWhole ~= big, "not the whole window")
	T.clean(w)
end)

test("d4 i2 whole: the Messages chips ask no side for their tip (the card's own order applies, never under the chips)", function()
	local fh = io.open("Wuber/UI/Driver/Messages.lua", "r")
	ok(fh, "Messages.lua reads")
	local src = fh:read("*a")
	fh:close()
	ok(not src:find("Tap to put it where the cursor is.\"\n\t\tend, \"ANCHOR_BOTTOM\"", 1, true), "the chip's T.Tip has no ANCHOR_BOTTOM")
end)

-- the tour: how many labels end up with a hover-only frame (a parent chain with no mouse-taking control)
local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if H.exists(LAB_DIR .. "/Photo.lua") and T.HAVE_UI then
	H.ADDONS.WuberLab = LAB_DIR
	test("d4 i2 whole: tour-wide, the labels that get a hover-only frame are counted and few", function()
		local w = T.newWorld()
		w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
		local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" }, screenW = 1920, screenH = 1080 })
		T.settle(w)
		local Th = c.W.Theme
		local seen, only, all = {}, {}, 0
		local real = Th.WholeOnHover
		Th.WholeOnHover = function(fs, owner)
			local r = real(fs, owner)
			if type(fs) == "table" and fs.wuberWhole and not seen[fs] then
				seen[fs] = true
				all = all + 1
				if fs.wuberWhole.wuberWholeMouse then only[#only + 1] = fs end
			end
			return r
		end
		c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
		local L = c.ns.WuberLab
		ok(L.TourStart(), "the tour started")
		for _ = 1, 900 do
			if not L.Touring() then break end
			w:advance(1)
		end
		Th.WholeOnHover = real
		local names = {}
		for _, fs in ipairs(only) do names[#names + 1] = tostring(fs:GetText()) end
		print("d4 i2: labels with a hover: " .. all .. ", with a hover-only frame: " .. #only .. " [" .. table.concat(names, " | ") .. "]")
		ok(#only <= 12, "hover-only frames in the whole tour: " .. #only)
		T.clean(w)
	end)
end

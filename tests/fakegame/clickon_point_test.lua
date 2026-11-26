-- Client:clickOn hits the frame on top at the REGION's centre and clicks it there (job 2833, #132 follow-up): the strict check of a direct
-- Client:click must not test that frame's own centre, which is another point. Before: a sheet frame whose body takes the click at the
-- sheet's centre, with a button over the body's own centre, made clickOn fail on a click a player's mouse makes.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function mk(env, parent, level, l, b, wd, ht)
	local f = env.CreateFrame("Button", nil, parent or env.UIParent)
	f:SetFrameLevel(level)
	f:SetSize(wd, ht)
	f:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", l, b)
	f:EnableMouse(true)
	return f
end

test("clickOn: a frame on top at the region's centre takes the click even when another frame covers that frame's own centre", function()
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "MAGE", addons = {}, allowMissing = true })
	local env = c.env
	local sheet = mk(env, nil, 3, 100, 100, 200, 100) -- centre (200,150)
	local body = mk(env, sheet, 4, 100, 100, 120, 100) -- covers the sheet's centre; its own centre is (160,150)
	local cover = mk(env, nil, 9, 150, 140, 20, 20) -- over the body's centre only
	local n = { 0, 0 }
	body:SetScript("OnClick", function() n[1] = n[1] + 1 end)
	cover:SetScript("OnClick", function() n[2] = n[2] + 1 end)
	local hit = c:clickOn(sheet)
	ok(hit == body, "the body took the click at the sheet's centre")
	eq(n[1] .. n[2], "10", "the body's OnClick ran, the cover's did not")
	ok(not pcall(c.click, c, body), "a direct click on the body is still strict: the cover is on top of its centre")
end)

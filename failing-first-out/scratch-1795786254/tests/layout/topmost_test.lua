-- The covered kind (tests/layout/topmost.lua) on small made-up screens; loaded by tools/layout-check.lua --selftest.
local T = ...
local H = T.H
local root = T.root

T.test("topmost: a button under a mouse-taking card drawn above it is covered; one beside it, or under a mouse-off dim, is not", function()
	local w = T.newWorld({})
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", addons = { "Wuber" } })
	local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)
	local Top = dofile(root .. "/tests/layout/topmost.lua")
	local env = c.env
	-- (nothing here is made by Wuber's code, so tag by hand: the engine's tag is what the check asks)
	local function mk(kind, name, strata, level, mouse, x)
		local f = H.createFrame(c, kind, name, env.UIParent)
		f:SetSize(100, 40)
		f:SetPoint("CENTER", env.UIParent, "CENTER", x or 0, 0)
		f:SetFrameStrata(strata)
		f:SetFrameLevel(level)
		f:EnableMouse(mouse)
		H.state[f].lcTag, H.state[f].lcSrc = "Wuber", name
		return f
	end
	local btn = mk("Button", "TopBtn", "MEDIUM", 5, true)
	mk("Button", "TopFar", "MEDIUM", 5, true, 300)
	mk("Frame", "TopDim", "MEDIUM", 20, false)       -- over it, takes no mouse: not covered
	local hits = Top.hits(H, E, c)
	T.eq(#hits, 0, "a mouse-off dim above is not a cover")
	mk("Frame", "TopCard", "FULLSCREEN_DIALOG", 1, true) -- over it, takes the mouse: covered
	hits = Top.hits(H, E, c)
	T.eq(#hits, 1, "the card covers the button under it, not the one beside it: " .. #hits)
	T.eq(hits[1].kind, "covered", "kind")
	T.ok(hits[1].detail:find("TopCard", 1, true), "names the card: " .. tostring(hits[1].detail))
	H.state[env.TopCard].shown = false
	T.eq(#Top.hits(H, E, c), 0, "hidden card: clear")
end)

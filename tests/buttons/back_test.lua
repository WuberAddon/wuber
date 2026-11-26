-- "Every button works": the back arrows (#36). From a page pushed over Home the arrow, clicked the real way (the frame on top at its
-- centre takes it), must land on that arrow and return to the exact screen before; the screen after must still take a click.
local T = ...
local Lib = assert(loadfile(T.dir .. "/buttons/lib.lua"))(T)
local ARROW_FILES = { ["Panel.lua"] = true, ["Confirm.lua"] = true, ["Ride.lua"] = true, ["Screens.lua"] = true }
local PAGES = { { "settings", "home" }, { "confirm", "home" }, { "customers", "console_open" } }

local function arrows(ctx)
	local out = {}
	for _, ctl in ipairs(Lib.controls(ctx)) do
		local file = ctl.id:match("@(%S+)$")
		if ctl.id:find("^%[circle%]") and ARROW_FILES[file or ""] then out[#out + 1] = ctl end
	end
	return out
end

for _, p in ipairs(PAGES) do
	local page, from = p[1], p[2]
	T.test("buttons back: the arrow of " .. page .. " takes the click and returns to the exact screen before, still usable", function()
		local ctx = Lib.newWorld()
		local byId = {}
		for _, s in ipairs(Lib.screens(ctx)) do byId[s.id] = s end
		T.ok(byId[from] and byId[page], "no tour screen " .. page)
		T.ok(Lib.show(ctx, byId[from]), from .. " can't be shown")
		local before = Lib.signature(ctx)
		if page == "settings" then -- the route the player takes: a real click on the cog (never W.UI.OpenSettings)
			local cog = ctx.W.UI.state.gear
			T.ok(cog and cog:IsShown(), "the cog is not showing on " .. from)
			T.eq(ctx.c:clickOn(cog) == cog, true, "the real click on the cog landed on another frame")
			ctx.w:advance(2)
			T.ok(ctx.W.UI.SettingsShown(), "the cog did not open Settings")
		else T.ok(Lib.show(ctx, byId[page]), page .. " can't be shown") end
		local list = arrows(ctx)
		T.ok(#list > 0, "no back arrow is drawn on " .. page)
		for _, a in ipairs(list) do
			local ok, taker = Lib.judgeTaker(ctx, a)
			T.ok(ok, page .. ": the click on the back arrow went to " .. Lib.describe(taker))
		end
		local res = Lib.click(ctx, list[1])
		T.ok(res.changed, page .. ": the back arrow changed nothing")
		-- the same words and states; frames Settings made on first open are new indexes in the id part, not a different screen
		local function clockless(s) return (s:gsub("%d+:%d+", ""):match("^(.-)\2") or s) end
		T.eq(clockless(Lib.signature(ctx)), clockless(before), page .. ": the screen after the back arrow is not the screen before")
		local usable
		for _, ctl in ipairs(Lib.controls(ctx)) do
			if ctl.id:find("^Trips <") then usable = ctl break end
		end
		T.ok(usable, "no tab to click after going back")
		T.ok(Lib.click(ctx, usable).changed, "the screen after the back arrow did not react to a click on " .. usable.id)
	end)
end

T.test("buttons back: Settings opened by a real click on the Drive cog: the arrow returns to the Drive console, still usable", function()
	local ctx = Lib.newWorld()
	local byId = {}
	for _, s in ipairs(Lib.screens(ctx)) do byId[s.id] = s end
	T.ok(Lib.show(ctx, byId.console_open), "console_open can't be shown")
	local before = Lib.signature(ctx)
	local cog = ctx.W.UI.state.gear
	T.ok(cog and cog:IsShown(), "the cog is not showing on the Drive console")
	T.eq(ctx.c:clickOn(cog) == cog, true, "the real click on the Drive cog landed on another frame")
	ctx.w:advance(2)
	T.ok(ctx.W.UI.SettingsShown(), "the Drive cog did not open Settings")
	local list = arrows(ctx)
	T.ok(#list > 0, "no back arrow is drawn on Settings")
	local ok, taker = Lib.judgeTaker(ctx, list[1])
	T.ok(ok, "the click on the back arrow went to " .. Lib.describe(taker))
	T.ok(Lib.click(ctx, list[1]).changed, "the back arrow changed nothing")
	local function same(s) return (s:gsub("%d+:%d+", ""):match("^(.-)\2") or s) end
	-- Settings from Drive opens at the Driving section: one arrow press may step back to Settings' home first
	if ctx.W.UI.SettingsShown() then
		local again = arrows(ctx)
		T.ok(#again > 0, "Settings still shows and has no back arrow")
		Lib.click(ctx, again[1])
	end
	T.ok(not ctx.W.UI.SettingsShown(), "Settings is still up after the back arrow")
	T.eq(same(Lib.signature(ctx)), same(before), "the screen after the back arrow is not the Drive console before")
	T.ok(ctx.c:clickOn(cog) == cog, "the cog does not take the next real click")
end)

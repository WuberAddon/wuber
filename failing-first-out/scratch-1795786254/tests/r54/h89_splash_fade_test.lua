-- #89: the hunt's universal.layout promise judged the page while the splash ("Summons, on demand") was still fading out.
-- UI.EndSplash clears ui.splashing at the START of a 0.4 s fade of a frame that covers the whole window, so the promise's
-- "the splash is up" guard let a look taken in the fade report page elements as lying under the splash frame (Phone.lua:52).
-- Proof: a look taken inside the fade reports nothing; a real overlap after the fade has ended is still reported.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- the situation of the hunt's finding (repro 80b642): the phone is opened on Trips right as the splash ends
local SIT = { day = "midnight_soon", phone = "trips_direct", place = "fm_known", ride = "paid" }

local U = dofile(T.dir .. "/hunt/lib/universal_util.lua")

-- what the promise says about the state now: nil when it passes, else its plain line
local function look(ctx, p)
	-- every look is judged (the promise judges only every Nth look otherwise)
	U.world(ctx).huntU.steps.layout = U.EVERY - 1
	ctx._failed, ctx._cannot, ctx._na = nil, nil, nil
	local okc, err = pcall(function() p.check(ctx) end)
	local f = ctx._failed
	ctx._failed, ctx._cannot, ctx._na = nil, nil, nil
	if f then return f.seen end
	if not okc and not (type(err) == "table" and err.hunt) then error(err, 0) end
	return nil
end

-- guard: none (fails on base: a look inside the 0.4 s fade is judged and reports the page as under the splash frame)
test("#89: universal.layout reports nothing while the splash fades out, and still reports a real overlap after", function()
	local Hunt = dofile(T.dir .. "/hunt/lib.lua")
	Hunt.init({})
	Hunt.loadAll()
	local p = Hunt.promises["universal.layout"]
	ok(p, "control: the promise exists")
	local ctx = Hunt.build(Hunt.full(SIT), 1090210571)
	local ui = ctx:mod("UI.Kit").ui
	ok(ui and ui.splash, "control: the window has a splash frame")
	-- the build ends inside the fade: the addon says the splash is over, the frame is still on screen
	ok(not ui.splashing, "control: the splash is over for the addon (splashing is false)")
	ok(ui.splash:IsShown(), "control: the splash frame is still fading")
	eq(look(ctx, p), nil, "a look inside the fade reports no layout finding")
	-- the fade ends: the frame is hidden, so the promise judges the page again
	ctx:advance(1.5)
	ok(not ui.splash:IsShown(), "control: the splash frame is hidden once the fade has ended")
	eq(look(ctx, p), nil, "control: the settled page is clean")
	-- a real overlap after the fade: one page text moved onto another
	local c = ctx.me
	local texts = {}
	for _, fs in ipairs(U.shown(c, { "FontString" })) do
		local so = U.S[fs]
		if so and type(so.text) == "string" and so.text:match("%S") and U.isWuber(fs) then texts[#texts + 1] = fs end
	end
	ok(#texts >= 2, "control: the page has texts to move")
	local a, b = texts[1], texts[#texts]
	b:ClearAllPoints()
	b:SetPoint("CENTER", a, "CENTER", 0, 0)
	ctx:advance(1.5)
	ok(look(ctx, p), "a real overlap after the fade is still reported")
end)

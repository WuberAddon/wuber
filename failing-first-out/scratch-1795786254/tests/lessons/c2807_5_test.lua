-- c2807 #5: the promise "never in chat without your click" must name the auto-reply exception while the auto-reply is on by default.
-- The maintainer approved these words (wording page of 24 Nov, Q1).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local EXC = "except the short auto-reply to riders who ask in public and the Messages lines you switch on (Settings can turn the auto-reply off)"

local function read(rel)
	local f = assert(io.open(T.dir .. "/../" .. rel, "rb"))
	local s = f:read("*a")
	f:close()
	return s
end

test("c2807 #5 the Help footer and the driver intro carry the auto-reply exception", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	eq(c.W.UI.HELP_FOOTER, "Nothing here is shared outside the game, and Wuber never sends anything in chat without your click, " .. EXC .. ".", "the Help footer")
	local build = read("Wuber/UI/Driver/Build.lua")
	ok(build:find("\"Nothing goes in chat without your click, " .. EXC .. "\"", 1, true), "the driver intro point")
	T.clean(w)
end)

test("c2807 #5 the no-click promise exists only with the exception while the auto-reply is on by default", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	eq(c.W.Drive.OPT_DEFAULTS.autoReply, true, "the auto-reply is on by default")
	local n = 0
	for _, rel in ipairs({ "Wuber/UI/Driver/Build.lua", "Wuber/UI/Settings/Panel.lua", "Wuber/UI/Settings/Pages.lua" }) do
		for line in read(rel):gmatch("[^\n]+") do
			if line:find("in chat without your click", 1, true) and not line:find("^%s*%-%-") then
				n = n + 1
				ok(line:find(EXC, 1, true), rel .. " promises no chat without a click but omits the exception: " .. line)
			end
		end
	end
	ok(n >= 2, "both promise texts were found, n=" .. n)
	T.clean(w)
end)

test("c2807 #5 the driver intro shows the whole longer point, wrapped, above the main button", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	a.W.UI.Toggle(true)
	w:advance(1)
	a.W.UI.SelectTab("Drive")
	w:advance(1)
	local hit = a:findText("Nothing goes in chat without your click")
	ok(#hit > 0, "the intro point is shown")
	local fs = hit[1]
	ok((fs:GetText() or ""):find(EXC, 1, true), "the shown point carries the exception")
	ok(not (fs.IsTruncated and fs:IsTruncated()), "the point is not cut short")
	ok((fs:GetHeight() or 0) > 30, "the long point wraps onto several lines, height " .. tostring(fs:GetHeight()))
	local go = a:findText("Set up driving")[1]
	ok(go, "the main button is shown")
	local goTop = go:GetParent():GetTop()
	ok(fs:GetBottom() > goTop, "the point ends above the main button: bottom " .. tostring(fs:GetBottom()) .. " button top " .. tostring(goTop))
	T.clean(w)
end)

-- the reviewer's gap: the points stack from the top, the button sits at a fixed foot: no clip or overlap at the smallest and largest window and scale
test("c2807 #5 the driver intro points stay whole, apart and above the buttons at the smallest and largest window and scale", function()
	local cfgs = { { 1920, 1080, 2 }, { 1920, 1080, 1 }, { 3840, 2160, 2 }, { 3840, 2160, 1 } }
	for _, cfg in ipairs(cfgs) do
		local label = cfg[1] .. "x" .. cfg[2] .. " scale " .. cfg[3]
		local w = T.newWorld()
		local a = T.driver(w, T.ANITA, { spot = "Undercity", screenW = cfg[1], screenH = cfg[2] })
		w:advance(15)
		a.W.db.scale = cfg[3]
		a.W.UI.Toggle(true)
		w:advance(1)
		a.W.UI.SelectTab("Drive")
		w:advance(3)
		local go = a:findText("Set up driving")[1]
		local skip = a:findText("Just open the console")[1]
		ok(go and skip, label .. ": the button and the link are shown")
		local pts = { a:findText("You set your own price")[1], a:findText("Drive alone, with friends")[1], a:findText("Nothing goes in chat without your click")[1] }
		local top = go:GetParent():GetTop()
		for i, fs in ipairs(pts) do
			ok(fs, label .. ": point " .. i .. " is shown")
			ok(not (fs.IsTruncated and fs:IsTruncated()), label .. ": point " .. i .. " is whole")
			ok(fs:GetBottom() > top, label .. ": point " .. i .. " ends above the button: " .. tostring(fs:GetBottom()) .. " vs " .. tostring(top))
			if i > 1 then ok(pts[i - 1]:GetBottom() > fs:GetTop() - 0.01, label .. ": point " .. i .. " does not overlap point " .. (i - 1)) end
		end
		ok(go:GetParent():GetBottom() >= skip:GetParent():GetTop() - 0.01, label .. ": the link sits under the button")
		T.clean(w)
	end
end)

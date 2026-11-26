local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local function setup(w)
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.Heatmap = function()
		return { { wday = 3, hour = 20, copper = 29000, rides = 5, open = 60, asks = 6 },
		         { wday = 4, hour = 9, copper = 1000, rides = 1, open = 60, asks = 0 } }
	end
	W.UI.WindowWide(false)
	T.openDrive(a)
	W.UI.ShowDrive("earnings")
	w:advance(1)
	local hm = W.UI.drive.screens.earnings.heat
	local function cell(wd, h) for _, b in ipairs(hm.cells) do if b.wday == wd and b.hour == h then return b end end end
	return a, W, hm, cell
end

test("r47 b4: C58r-2 tapping a dark square on an empty heatmap flashes a white frame and a 'nothing yet' pill over the note", function()
	local w = T.newWorld()
	local a, W, hm, cell = setup(w)
	a:click(cell(3, 20)) w:advance(0.5)
	ok(hm.sel:IsShown() and hm.pill:IsShown(), "control: a tap with data shows frame and pill")
	W.Drive.Heatmap = function() return nil end   -- a new driver: nothing logged yet
	W.UI.drive.screens.earnings.update() w:advance(1)
	ok(hm.empty:IsShown(), "control: the empty note is up")
	ok(not hm.sel:IsShown() and not hm.pill:IsShown(), "control: frame and pill are gone when empty")
	a:click(cell(1, 0))                          -- no time passes: what the player sees at the tap
	ok(not hm.sel:IsShown(), "the player sees a white selection frame on a square of an empty heatmap")
	ok(not hm.pill:IsShown(), "the player sees a pill reading '" .. tostring(hm.info:GetText()) .. "' under the 'open for a few hours' note")
	T.clean(w)
end)

test("r47 b4: C58r-4 after the frame is hidden mid-glide, the next tap's frame jumps back to the old square", function()
	local w = T.newWorld()
	local a, W, hm, cell = setup(w)
	local e = W.UI.drive.screens.earnings
	local function data() return { { wday = 3, hour = 20, copper = 29000, rides = 5, open = 60, asks = 6 },
		{ wday = 4, hour = 9, copper = 1000, rides = 1, open = 60, asks = 0 } } end
	local A_, B_ = cell(3, 20), cell(4, 9)
	a:click(cell(1, 0)) w:advance(0.5)                 -- the frame rests on Mon 00:00
	a:click(A_) w:advance(0.03)                        -- gliding to Wed 20:00 ...
	W.Drive.Heatmap = function() return nil end         -- ... the log goes empty (scope switch, reset): the frame hides
	e.update() w:advance(0.05)
	ok(not hm.sel:IsShown(), "control: frame hidden")
	W.Drive.Heatmap = data
	e.update() w:advance(0.5)
	a:click(B_) w:advance(0.5)                          -- tap Thu 09:00, wait for the glide
	local want = 36 + B_.hour * hm.cw - 1
	local gotx = hm.sel.x
	ok(math.abs(gotx - want) < 0.5, "the white frame sits at x=" .. tostring(gotx) .. " (Wed 20:00 is " .. (36 + A_.hour * hm.cw - 1) .. ") but the pill describes Thu 09:00 (x=" .. want .. ")")
	T.clean(w)
end)

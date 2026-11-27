local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- the fare line must fit its room at the size drawn: no "..." for a badge and a day's take, nor a 50000g price
local function fits(W, fs)
	local room = fs:GetRight() - fs:GetLeft()
	local need = W.Theme.MeasureText(fs.wuberText or "", fs.wuberPx, fs.wuberWeight)
	return need <= room + 1, ("%q needs %.1f, has %.1f"):format(fs.wuberText or "", need, room)
end

local function strip(price, badge)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Thunder Bluff" })
	w:advance(15)
	local W = a.W
	W.Drive.Shards = function() return 10 end
	if badge then W.PIONEERS = { riders = { ["EU-PvE"] = {} }, drivers = { ["EU-PvE"] = { W.myKey } } } end
	W.Drive.Price = function() return price end
	W.Driver.Price = W.Driver.Price and function() return price end or nil
	W.Drive.Today = function() return 16, 46055 end
	if W.Driver then W.Driver.Today = W.Drive.Today end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	return w, W, W.Driver.ui.console
end

for _, c in ipairs({ { "a badge and a day's take", 5000, true }, { "a 50000g price", 500000000, false }, { "both", 500000000, true } }) do
	test("r30 e: the fare line fits its room with " .. c[1], function()
		local w, W, v = strip(c[2], c[3])
		ok(v.fare.text.wuberText:find("to Thunder Bluff", 1, true), "the fare names the place: " .. tostring(v.fare.text.wuberText))
		local f, msg = fits(W, v.fare.text)
		msg = msg .. " px " .. tostring(v.fare.text.wuberPx) .. " base " .. tostring(v.fare.text.wuberBase) .. " fare w " .. tostring(v.fare:GetWidth()) .. " gold px " .. tostring(v.status.gold.wuberPx)
		ok(f or v.fare.text.wuberWrapped, msg)
		T.clean(w)
	end)
end

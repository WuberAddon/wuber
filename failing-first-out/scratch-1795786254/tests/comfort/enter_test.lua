-- Comfort and accessibility (job 2903): Enter confirms in every input box of the "Price and place" sheet, as it does in the price box.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- the edit box whose placeholder is `hint` (T.Field: the box's grandparent holds .hint)
local function boxByHint(c, hint)
	for _, f in ipairs(c.frames) do
		if f.GetObjectType and f:GetObjectType() == "EditBox" then
			local field = f:GetParent() and f:GetParent():GetParent()
			if field and field.hint and field.hint.GetText and field.hint:GetText() == hint then return f end
		end
	end
end

local function sheetWorld()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	ok(W.Driver.ShowSheet("sheet"), "control: the price sheet opens")
	w:advance(1)
	return w, a, W
end

test("comfort.enter: Enter in the place search box saves the sheet like Save", function()
	local w, a, W = sheetWorld()
	local D = W.Driver
	local box = boxByHint(a, "Search places (Undercity, Ratchet...)")
	ok(box, "control: the place box exists")
	a:type(box, "Ratchet", true)
	w:advance(1)
	ok(not D.SheetOpen(), "Enter in the place box closed the sheet (it saved)")
	T.clean(w)
end)

test("comfort.enter: Enter in the Also called box saves the sheet like Save", function()
	local w, a, W = sheetWorld()
	local D = W.Driver
	local box = boxByHint(a, "uc, under city")
	ok(box, "control: the box exists")
	a:type(box, "rat, ratchet", true)
	w:advance(1)
	ok(not D.SheetOpen(), "Enter in the Also called box closed the sheet (it saved)")
	T.clean(w)
end)

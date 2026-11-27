-- Fix round group d: Price and place sheet (ING-04 caption under the place box, ING-05 match chips keep one text size).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function open()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	T.openDrive(a)
	W.Driver.ShowSheet("sheet") w:advance(2)
	local s = W.UI.drive.screens.sheet
	s.mode = "choose" s.layout() w:advance(1)
	return w, a, s
end

test("fr d: ING-05 every place chip draws its name at the same text size, none shrunk", function()
	local w, a, s = open()
	a:type(s.search.edit, "ea", false)
	local n, size = 0, nil
	for _, h in ipairs(s.hits) do
		if h:IsShown() then
			n = n + 1
			size = size or h.label.wuberPx
			eq(h.label.wuberPx, h.label.wuberBase, h.place .. " is drawn at its normal size")
			eq(h.label.wuberPx, size, h.place .. " is the same size as the first chip")
			ok(h.label:IsTruncated() ~= true, h.place .. " is not cut")
		end
	end
	ok(n >= 2, "chips shown")
	T.clean(w)
end)

test("fr d: ING-04 the place box says an empty box means where you stand", function()
	local w, a, s = open()
	ok(s.emptyNote, "the caption exists")
	eq(s.emptyNote:GetText(), "Leave it empty to use where you stand.")
	ok(s.emptyNote:IsShown(), "shown under the place box in Choose")
	local sb, nb = H.rect(s.search), H.rect(s.emptyNote)
	ok(nb.b + nb.h <= sb.b + 1, "below the search box")
	ok(nb.l >= sb.l - 1 and nb.l + nb.w <= sb.l + sb.w + 4, "inside the box's width")
	for _, h in ipairs(s.hits) do if h:IsShown() then ok(H.rect(h).b + H.rect(h).h <= nb.b + 1, "chips sit below the caption") end end
	s.mode = "here" s.layout()
	ok(not s.emptyNote:IsShown(), "hidden when Where I stand")
	T.clean(w)
end)

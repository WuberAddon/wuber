
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function console(wide)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Sorted = function() return {} end
	DR.customers = {}
	DR.IsOpen = function() return true end
	if wide then a.wide = true W.db.coach = true W.UI.WindowWide(true)
	else W.UI.WindowWide(false) end
	T.openDrive(a)
	if W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	W.Driver.RefreshNow()
	return w, a, W, DR
end

local function overlaps(a, b)
	return a.l < b.l + b.w - 0.5 and b.l < a.l + a.w - 0.5 and a.b < b.b + b.h - 0.5 and b.b < a.b + a.h - 0.5
end
test("r47 d2: a refused save keeps its red reason clear of the Reset and Save buttons", function()
	local w, a, W = console(false)
	W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = W.UI.drive.screens.messages
	s.edit("greet")
	local e = s.editor
	-- control: a spam refusal (flagged by the preview) reserves room, no overlap
	e.field:SetText(string.rep("word ", 41))  -- 205 letters, over the 190 a whisper may carry
	s.preview()
	ok(not e.why:IsShown(), "control: the preview does not flag a plain long whisper")
	a:clickOn(e.save)
	w:advance(0.5)
	ok(e.why:IsShown(), "the refusal text shows: " .. tostring(e.why:GetText()))
	local rw, rs, rr = H.rect(e.why), H.rect(e.save), H.rect(e.reset)
	ok(not (rw and rs and overlaps(rw, rs)) and not (rw and rr and overlaps(rw, rr)),
		"the red '" .. tostring(e.why:GetText()) .. "' sits on top of the Reset/Save buttons (why bottom " .. tostring(rw and rw.b) .. " h " .. tostring(rw and rw.h) .. ", save bottom " .. tostring(rs and rs.b) .. " h " .. tostring(rs and rs.h) .. ")")
	T.clean(w)
end)

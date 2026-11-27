local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean = T.clean

local function editor()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	a.W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = a.W.UI.drive.screens.messages
	s.edit("greet")
	w:advance(0.5)
	return w, a, s, s.editor
end

test("r34 i2: a whisper over the limit previews its real length, so it shows as too long before Save", function()
	local w, a, s, e = editor()
	local long = string.rep("word ", 60) -- 299 letters
	e.field:SetText(long)
	s.preview()
	local n = tonumber(tostring(e.meter.wuberText or e.meter:GetText()):match("^(%d+)"))
	ok(n and n > 190, "the counter shows the real length, got " .. tostring(n))
	local okSave = a.W.Drive.SetTemplate("greet", long)
	eq(okSave, false, "and Save refuses it")
	clean(w)
end)

test("r34 i2: an emptied box previews the default wording that Save goes back to", function()
	local w, a, s, e = editor()
	local DR = a.W.Drive
	ok(DR.SetTemplate("greet", "custom hello {name} zzq"), "a custom wording saved")
	s.edit("greet") w:advance(0.5)
	e = s.editor
	e.field:SetText("")
	local text = s.preview()
	ok(not tostring(text):find("zzq", 1, true), "the old custom wording is not previewed: " .. tostring(text))
	local def = DR.Text("greet", { name = "Dan Rider", key = "dan rider" }, DR.TEMPLATES.greet)
	eq(text, def, "it previews the default")
	clean(w)
end)

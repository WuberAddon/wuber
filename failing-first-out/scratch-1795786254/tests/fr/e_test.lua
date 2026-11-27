-- Group e (fix round): the Messages counter and the Save refusal count the same text (ING-06).
local T = ...
local test, eq, ok, clean = T.test, T.eq, T.ok, T.clean

test("fx.e: a greeting the counter shows over the limit is refused with the same number", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	a.W.Driver.ShowScreen("messages")
	w:advance(1)
	local s = a.W.UI.drive.screens.messages
	s.edit("greet")
	w:advance(0.5)
	local e = s.editor
	local DR = a.W.Drive
	-- short as typed, long once {name} and {service} are filled in
	local txt = string.rep("{service} ", 18)
	ok(#txt < DR.TEXT_MAX, "typed length is under the limit: " .. #txt)
	e.field:SetText(txt)
	s.preview()
	local shown = tonumber(tostring(e.meter.wuberText or e.meter:GetText()):match("^(%d+)"))
	ok(shown and shown > DR.TEXT_MAX, "the counter is over the limit: " .. tostring(shown))
	local okSave, why = DR.SetTemplate("greet", txt)
	eq(okSave, false, "Save refuses it")
	eq(tonumber(tostring(why):match("it is (%d+) letters")), shown, "the refusal counts the same: " .. tostring(why))
	clean(w)
end)

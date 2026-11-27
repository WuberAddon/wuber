local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- Promise (r52 F013, hunt universal.layout): on Settings pages the title ends before the header buttons (close, cog,
-- fold), however the page believes the window is laid out: its frame and its words stop short of the leftmost one.
local function clear(UI, title, label)
	local ui = UI.state
	local left = math.huge
	for _, b in ipairs({ ui.close, ui.gear, ui.phone and ui.phone.fold }) do
		if b and H.visible(b) and b:GetLeft() then left = math.min(left, b:GetLeft()) end
	end
	local tl = title:GetLeft()
	local frameRight = tl + title:GetWidth()
	local textRight = tl + math.min(title:GetWidth(), title:GetStringWidth() or title:GetWidth())
	ok(left < math.huge, label .. ": a header button shows")
	ok(frameRight <= left + 0.5, label .. ": the title's frame ends (" .. frameRight .. ") before the buttons (" .. left .. ")")
	ok(textRight <= left + 0.5, label .. ": the title's words end before the buttons")
end

local function open()
	local w = T.newWorld()
	local r = T.driver(w, T.ANITA, { spot = "Undercity" })
	T.settle(w)
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI
end

test("r52 q: the Help title does not run under the header buttons, even when Help believes the window is unfolded", function()
	local w, r, UI = open()
	UI.OpenHelp() w:advance(1)
	local title = r:findText("^" .. UI.HELP_TITLE:gsub("%p", "%%%0") .. "$", true)[1]
	ok(title, "Help's title shows")
	clear(UI, title, "Help, as opened")
	-- the state the bug hunt found: the page lays itself out for the unfolded pane while the window stays 360 wide
	ok((UI.state.win:GetWidth() or 0) < 400, "control: the window is narrow")
	r.W.Mod("UI.Settings.Panel").helpWide(true) w:advance(1)
	clear(UI, title, "Help, laid out wide in a narrow window")
	T.clean(w)
end)

-- guard: the Settings page's own title keeps clear of the buttons the same way
test("r52 q guard: the Settings title does not run under the header buttons", function()
	local w, r, UI = open()
	UI.OpenSettings() w:advance(1)
	local title = r.W.Mod("UI.Settings.Rows").st.title
	ok(title, "Settings has a title")
	if title then clear(UI, title, "Settings") end
	T.clean(w)
end)

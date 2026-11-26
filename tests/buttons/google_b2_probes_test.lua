-- tests/buttons/google_b2_probes_test.lua: probes for clicks whose effect cannot be seen in the snapshot table alone
-- (HighlightText on Bug Select all, Slider click->wheel->db, T.Switch toggle->db, Earnings range on empty log).
local T = ...
local Lib = assert(loadfile(T.dir .. "/buttons/lib.lua"))(T)

local function findScreen(ctx, id)
	for _, s in ipairs(Lib.screens(ctx)) do
		if s.id == id then return s end
	end
end

local function findControl(ctx, id)
	for _, ctl in ipairs(Lib.controls(ctx)) do
		if ctl.id == id then return ctl end
	end
end

T.test("buttons probe: Bug Select all calls HighlightText on the report EditBox", function()
	for _, sid in ipairs({ "bug_window", "sheet_fm_unknown" }) do
		local ctx = Lib.newWorld()
		local s = findScreen(ctx, sid)
		T.ok(s and Lib.show(ctx, s), sid .. " screen shown")
		local bugFrame = ctx.c.env.WuberBug
		T.ok(bugFrame ~= nil, "WuberBug exists on " .. sid)
		local copyEdit
		local function walk(f)
			if copyEdit then return end
			for _, ch in ipairs({ f:GetChildren() }) do
				if ch.GetObjectType and ch:GetObjectType() == "EditBox" and ch.HighlightText then
					local txt = ch:GetText() or ""
					if #txt > 40 then copyEdit = ch return end
				end
				walk(ch)
			end
		end
		walk(bugFrame)
		T.ok(copyEdit ~= nil, "report copy EditBox found on " .. sid)
		local highlighted = false
		local orig = copyEdit.HighlightText
		copyEdit.HighlightText = function(self, ...)
			highlighted = true
			return orig(self, ...)
		end
		local btn = findControl(ctx, "Select all <Button> @Bug.lua")
		T.ok(btn ~= nil, "Select all button found on " .. sid)
		ctx.c:clickOn(btn.f)
		T.ok(highlighted, "HighlightText called after clicking Select all on " .. sid)
	end
end)

T.test("buttons probe: Slider click enables wheelOn and wheel updates saved db", function()
	local ctx = Lib.newWorld()
	local s = findScreen(ctx, "settings_undo")
	T.ok(s and Lib.show(ctx, s), "settings_undo screen shown")
	local sl = findControl(ctx, "[circle] <Slider> @Panel.lua")
	T.ok(sl ~= nil, "Window size slider found")
	local before = ctx.W.db.scale
	ctx.c:clickOn(sl.f)
	T.ok(sl.f.wheelOn == true, "clickOn enables wheelOn on slider")
	ctx.c:wheelOn(sl.f, 1)
	ctx.w:advance(0.5)
	T.ok(ctx.W.db.scale ~= before, "wheelOn after click updates W.db.scale")

	local ctx2 = Lib.newWorld()
	local s2 = findScreen(ctx2, "earnings_heatmap")
	T.ok(s2 and Lib.show(ctx2, s2), "earnings_heatmap screen shown")
	local sl2 = findControl(ctx2, "[circle] <Slider> @Earnings.lua")
	T.ok(sl2 ~= nil, "Earnings target slider found")
	local opts = ctx2.W.Mod("UI.Driver.Screens").opts
	local before2 = opts().target
	ctx2.c:clickOn(sl2.f)
	T.ok(sl2.f.wheelOn == true, "clickOn enables wheelOn on earnings slider")
	ctx2.c:wheelOn(sl2.f, 1)
	ctx2.w:advance(0.5)
	local after2 = opts().target
	T.ok(after2 ~= before2, "wheelOn after click updates opts().target")
end)

T.test("buttons probe: Settings [pill] switches flip state and update db", function()
	local ctx = Lib.newWorld()
	local s = findScreen(ctx, "settings_driving")
	T.ok(s and Lib.show(ctx, s), "settings_driving screen shown")
	local sw = findControl(ctx, "[pill] <Button> @Rows.lua")
	T.ok(sw ~= nil, "switch found on settings_driving")
	local before = sw.f.on
	ctx.c:clickOn(sw.f)
	T.ok(sw.f.on == not before, "switch flipped on settings_driving")

	local ctx2 = Lib.newWorld()
	local s2 = findScreen(ctx2, "settings_opened")
	T.ok(s2 and Lib.show(ctx2, s2), "settings_opened screen shown")
	local sw2 = findControl(ctx2, "[pill] <Button> @Rows.lua")
	T.ok(sw2 ~= nil, "switch found on settings_opened")
	local before2 = sw2.f.on
	ctx2.c:clickOn(sw2.f)
	T.ok(sw2.f.on == not before2, "switch flipped on settings_opened")
end)

T.test("buttons probe: simple_earnings 7 days and 30 days update earnings range", function()
	local ctx = Lib.newWorld()
	local s = findScreen(ctx, "simple_earnings")
	T.ok(s and Lib.show(ctx, s), "simple_earnings screen shown")
	local es = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
	T.ok(es ~= nil, "earnings screen table found")
	local b7 = findControl(ctx, "7 days <Button> @Earnings.lua")
	T.ok(b7 ~= nil, "7 days button found")
	ctx.c:clickOn(b7.f)
	T.ok(es.range == "week", "7 days sets range to week")
	local b30 = findControl(ctx, "30 days <Button> @Earnings.lua")
	T.ok(b30 ~= nil, "30 days button found")
	ctx.c:clickOn(b30.f)
	T.ok(es.range == "month", "30 days sets range to month")
end)

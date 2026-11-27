-- Promises about the Report a bug sheet (and the sheets that share its header handling) in 2.4.1:
-- H24-02 (the card starts under a big page title that straddles the header foot), E1-07 / r49 B (header buttons lifted over the dim, put back),
-- R49-7 (the dim stays under the lifted big Drive button), r49 (the words never cut at any width), E1-01 (Settings X over the game's Options).
return function(Hunt)
	local Top = dofile("tests/lib/topmost.lua")
	local function noCombat(ctx) if ctx.me.player.combat then ctx:na("in combat") end end
	local function UIof(ctx) return ctx.W.UI end
	local function openWindow(ctx)
		noCombat(ctx)
		local UI = UIof(ctx)
		if not (UI and UI.Bug and UI.Toggle and UI.state) then ctx:cannot("no UI.Bug") end
		if not UI.IsShown() then UI.Toggle(true) ctx:advance(3) end
		if not UI.IsShown() then ctx:cannot("the window would not open") end
		return UI
	end
	local function openBug(ctx, UI)
		ctx:note("open Report a bug")
		UI.Bug.Open()
		ctx:advance(1.5)
		if not UI.Bug.Shown() then ctx:fail("You ask for Report a bug and no sheet comes up.") end
		return UI.Bug.frame
	end
	local function promise(p)
		p.area = "Sheets"
		p.kind = "scenario"
		p.needs = p.needs or { phone = "closed" }
		p.when = p.when or function(sit) return sit.role == nil or sit.role == "rider" end
		Hunt.promise(p)
	end
	local function strataOf(f) return f:GetFrameStrata() end

	promise{
		id = "v241.sheets.card_clears_title",
		text = "With a page's big title on the screen (Settings), Report a bug opens with its card starting below the title: the sheet's edge never cuts the title in two.",
		source = "H24-02 (Bug.lua titleDrop)",
		check = function(ctx)
			local UI = openWindow(ctx)
			ctx:note("open Settings")
			UI.OpenSettings() ctx:advance(3)
			local H = ctx.H
			local bigs = {}
			local seen = {}
			local function walk(f)
				if seen[f] then return end
				seen[f] = true
				for _, r in ipairs({ f:GetRegions() }) do
					if r.GetText and r:GetText() == "Settings" and H.visible(r) then bigs[#bigs + 1] = r end
				end
				for _, c in ipairs({ f:GetChildren() }) do walk(c) end
			end
			walk(UI.state.win)
			if #bigs == 0 then ctx:na("no big Settings title on this screen") end
			local f = openBug(ctx, UI)
			local card = H.rect(f.card)
			local cardTop = card.b + card.h
			for _, t in ipairs(bigs) do
				local tr = H.rect(t)
				local top, bot = tr.b + tr.h, tr.b
				if top > cardTop + 0.5 and bot < cardTop - 0.5 then
					ctx:fail("You open Report a bug over Settings and the sheet's top edge cuts the big Settings title in two.", ("title %.1f to %.1f, card top %.1f"):format(bot, top, cardTop))
				end
			end
		end,
	}

	promise{
		id = "v241.sheets.header_buttons_over_dim",
		text = "With Report a bug up, the x, the cog and the fold button are drawn over the dim and can be clicked; when you close the sheet they are back in the window's own layer.",
		source = "E1-07 / r49 B (UI.HeadAbove)",
		check = function(ctx)
			local UI = openWindow(ctx)
			local ui = UI.state
			local win = ui.win:GetFrameStrata()
			local list = { { "x", ui.close }, { "cog", ui.gear } }
			if ui.phone and ui.phone.fold then list[#list + 1] = { "fold", ui.phone.fold } end
			local f = openBug(ctx, UI)
			local ignore = {}
			for _, fr in ipairs(ctx.me.frames) do
				if fr.GetFrameStrata and fr:GetFrameStrata() == win then ignore[fr] = true end
			end
			for _, e in ipairs(list) do
				local b = e[2]
				if b and b:IsShown() then
					local res = Top.checkButton(ctx.H, ctx.me, b, { ignore = ignore })
					if not res.ok then ctx:fail("With Report a bug up, the " .. e[1] .. " button in the header is covered by the dim or the sheet.", tostring(res.reason)) end
				end
			end
			ctx:note("close Report a bug")
			UI.Bug.Close() ctx:advance(2)
			if UI.Bug.Shown() then ctx:fail("You close Report a bug and the sheet is still up.") end
			for _, e in ipairs(list) do
				if e[2] and strataOf(e[2]) ~= win then
					ctx:fail("You closed Report a bug and the " .. e[1] .. " button stays lifted above the window (a game dialog over Wuber would not cover it).", strataOf(e[2]) .. " vs " .. win)
				end
			end
		end,
	}

	promise{
		id = "v241.sheets.dim_under_drive_button",
		text = "The Report a bug dim and sheet sit under the big Drive button's layer, so the dim never lies over that button; and the sheet is still over the window itself.",
		source = "R49-7",
		check = function(ctx)
			local UI = openWindow(ctx)
			local f = openBug(ctx, UI)
			local rank = ctx.H.STRATA_RANK
			for _, fr in ipairs({ f.holder, f, f.card }) do
				if rank(strataOf(fr)) >= rank("FULLSCREEN_DIALOG") then
					ctx:fail("With Report a bug up, its dim lies over the big Drive button's layer, so the button is dimmed and blocked.", strataOf(fr))
				end
			end
			if rank(strataOf(f.holder)) <= rank(UI.state.win:GetFrameStrata()) then
				ctx:fail("With Report a bug up, the sheet is not above the Wuber window.", strataOf(f.holder))
			end
		end,
	}

	promise{
		id = "v241.sheets.words_whole_after_fold",
		text = "The words at the top of Report a bug are never cut with '...' and the first box starts under them, whichever width the window has; folding or unfolding the window under the sheet keeps that.",
		source = "r49 B (the words take what their lines need)",
		check = function(ctx)
			local UI = openWindow(ctx)
			local f = openBug(ctx, UI)
			local H = ctx.H
			local function whole(what)
				local tr = H.truncation(f.how, true)
				if tr then ctx:fail("The words on Report a bug are cut short with dots (" .. what .. ").", tr.lines .. " lines, room for " .. tostring(tr.max)) end
				local hr, lr = H.rect(f.how), H.rect(f.noteLbl)
				if lr.b + lr.h > hr.b + 0.5 then ctx:fail("On Report a bug the 'What happened?' label starts inside the words (" .. what .. ").") end
			end
			whole("at first")
			local ui = UI.state
			local btn = ui.phone and ui.phone.fold
			if btn and btn:IsShown() then
				ctx:note("click the fold button under the sheet")
				pcall(ctx.me.clickOn, ctx.me, btn)
				ctx:advance(3)
				if not UI.Bug.Shown() then ctx:na("the fold click closed the sheet") end
				whole("after the window folded or unfolded")
			end
		end,
	}

	promise{
		id = "v241.sheets.close_and_escape",
		text = "Report a bug always lets you out: its x closes the sheet and Wuber stays; Escape closes it too; both leave the header as it was.",
		source = "E1-07 / r49 B (the x is lifted over the dim and still clickable); Escape closes WuberBug",
		check = function(ctx)
			local UI = openWindow(ctx)
			local f = openBug(ctx, UI)
			local x = f.close
			if not (x and x:IsShown()) then ctx:fail("Report a bug has no x to close it.") end
			ctx:note("click the sheet's x")
			ctx.me:clickOn(x) ctx:advance(1.5)
			if UI.Bug.Shown() then ctx:fail("You click the x on Report a bug and the sheet stays up.") end
			if not UI.IsShown() then ctx:fail("You close Report a bug with its x and Wuber closes as well.") end
			openBug(ctx, UI)
			ctx:note("press Escape")
			ctx.me:pressEscape() ctx:advance(1.5)
			if UI.Bug.Shown() then ctx:fail("You press Escape on Report a bug and the sheet stays up.") end
			if UI.state.close:GetFrameStrata() ~= UI.state.win:GetFrameStrata() then
				ctx:fail("After Escape closed Report a bug, the window's x stays lifted above the window.")
			end
			-- and the header x still hides Wuber with no sheet up (Escape may have closed the window as well: open it again)
			if not UI.IsShown() then UI.Toggle(true) ctx:advance(3) end
			if not UI.state.close:IsVisible() then ctx:na("no x on this page") end
			ctx.me:clickOn(UI.state.close) ctx:advance(1.5)
			if UI.IsShown() then ctx:fail("With no sheet up you click Wuber's own x and the window stays open.") end
		end,
	}

	promise{
		id = "v241.sheets.settings_x_guard",
		text = "With Settings opened by the cog (not from the game's Options), Wuber's own x hides Wuber.",
		source = "E1-01 guard (the X closes Settings only when it was opened over the game Options)",
		check = function(ctx)
			local UI = openWindow(ctx)
			local ui = UI.state
			if not ui.gear:IsVisible() then ctx:na("no cog on this page") end
			ctx:note("click the cog")
			ctx.me:clickOn(ui.gear) ctx:advance(2)
			if not (UI.SettingsShown and UI.SettingsShown()) then ctx:na("the cog did not open Settings here") end
			if not ui.close:IsVisible() then ctx:na("no x on this page") end
			ctx:note("click the x")
			ctx.me:clickOn(ui.close) ctx:advance(2)
			if UI.IsShown() then ctx:fail("Settings is open from the cog; you click Wuber's x and the window stays open.") end
		end,
	}
end

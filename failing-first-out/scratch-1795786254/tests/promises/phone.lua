-- Promises about the phone itself (owner SHELL): opening and closing, the splash, tabs, where the window stands, the fold,
-- toasts, slash words, the bug report. From what the player sees and is told: Settings (Wide pages: "Some pages open out to
-- two panes"; Window position: "Back to its usual place"), tooltips (the tabs, the minimap button, the fold button),
-- Help ("/wuber opens this app"), CHANGELOG 2.3.x (the fold; the window keeps clear of chat), BRIEF20 B4.
return function(Hunt)
	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end
	local function ui(ctx)
		local K = ctx:mod("UI.Kit")
		return K and K.ui or {}
	end
	local function shown(ctx)
		local U = ctx.W.UI
		return U and type(U.IsShown) == "function" and U.IsShown() == true
	end
	local function onScreen(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end
	local function inCombat(ctx) return ctx.me.player.combat == true end
	local function rideOn(ctx)
		local K = ctx:mod("UI.Kit")
		if K and type(K.rideActive) == "function" then
			local ok, a = pcall(K.rideActive)
			return ok and a == true
		end
		return false
	end

	-- the player types /wuber (what the minimap button's click does too)
	local function slash(ctx, line, wait)
		ctx.me:slash(line)
		ctx:advance(wait or 0.4)
		ctx:note(line)
	end
	local function ensureOpen(ctx)
		if not shown(ctx) then slash(ctx, "/wuber", 0.4) end
		return shown(ctx)
	end
	local function settle(ctx) ctx:advance(2.4) end

	-- a box { l, r, b, t } in the screen's own units
	local function box(ctx, obj)
		local P = ctx.me.env.UIParent
		local l, r, b, t = obj:GetLeft(), obj:GetRight(), obj:GetBottom(), obj:GetTop()
		if not (l and r and b and t) then return nil end
		local sc = obj:GetEffectiveScale() / P:GetEffectiveScale()
		return { l = l * sc, r = r * sc, b = b * sc, t = t * sc }
	end
	local function overlap(a, b, slack)
		slack = slack or 1
		return a.l < b.r - slack and b.l < a.r - slack and a.b < b.t - slack and b.b < a.t - slack
	end
	local function chatBox(ctx)
		local U = ctx.W.UI
		if not (U and type(U.ChatBox) == "function") then return nil end
		local ok, c = pcall(U.ChatBox)
		if ok and type(c) == "table" and c[1] and c[2] and c[3] and c[4] then return { l = c[1], r = c[2], b = c[3], t = c[4] } end
		return nil
	end
	local function inside(obj, top)
		local cur, n = obj, 0
		while cur and n < 40 do
			if cur == top then return true end
			local ok, p = pcall(cur.GetParent, cur)
			if not ok then return false end
			cur, n = p, n + 1
		end
		return false
	end
	local function press(ctx, obj)
		local okc, cx, cy = pcall(obj.GetCenter, obj)
		-- GetCenter is in the frame's own scale, frameAt in the screen's
		local ratio = okc and cx and obj:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale() or 1
		local hit = okc and cx and ctx.me:frameAt(cx * ratio, cy * ratio) or nil
		if hit and inside(hit, obj) and pcall(ctx.me.clickOn, ctx.me, obj) then return end
		ctx.me:click(obj)
	end

	-- is this control what a click on it lands on (nothing drawn over it)? true, or false and what is over it
	local function reachable(ctx, obj)
		local okc, cx, cy = pcall(obj.GetCenter, obj)
		if not (okc and cx) then return true end
		local ratio = obj:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale()
		local hit = ctx.me:frameAt(cx * ratio, cy * ratio)
		if not hit or inside(hit, obj) then return true end
		return false, "the open Wuber window is drawn over the button"
	end

	---------------------------------------------------------------------------
	-- Opening and closing
	---------------------------------------------------------------------------
	Hunt.promise{
		id = "phone.slash_toggles",
		area = "Phone",
		text = "Typing /wuber opens Wuber, typing it again closes it, and /ride does the same.",
		source = "Help (\"/wuber opens this app\"); Commands.lua header", kind = "scenario",
		needs = { phone = "closed" },
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			for _, word in ipairs({ "/wuber", "/ride" }) do
				slash(ctx, word, 0.5)
				if not shown(ctx) then ctx:fail(("You type %s and Wuber does not open."):format(word), onScreen(ctx)) end
				slash(ctx, word, 0.8)
				if shown(ctx) then ctx:fail(("You type %s with Wuber open and it does not close."):format(word), onScreen(ctx)) end
			end
		end,
	}

	Hunt.promise{
		id = "phone.escape_closes_keeps_ride",
		area = "Phone",
		text = "Escape closes Wuber, and a ride you have going carries on.",
		source = "Window.lua header (Escape or the close button hides the window; the ride continues)", kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			ensureOpen(ctx)
			ctx:advance(2.4)
			if not shown(ctx) then ctx:cannot("the phone would not open") end
			local before = rideOn(ctx)
			local ride0 = ctx.W.ride and ctx.W.ride.state
			-- a card standing over the page (the login tip, the What's new card) takes the first Escape ALONE and the window stays
			-- (Forms.lua escTake, job 2767: the first Escape closes the sheet, the next the window): the player presses Escape again
			local function cardUp()
				for _, n in ipairs({ "WuberTipCard", "WuberNewsCard" }) do
					local c = rawget(ctx.me.env, n)
					if type(c) == "table" and ctx:visible(c) then return true end
				end
				return false
			end
			for _ = 1, 3 do
				local card = cardUp()
				ctx.me:pressEscape()
				ctx:advance(1)
				ctx:note("press Escape" .. (card and " (a card was up: it closes first)" or ""))
				if not (card and shown(ctx)) then break end
			end
			if shown(ctx) then ctx:fail("You press Escape with Wuber open and it stays open.", onScreen(ctx)) end
			if before and not rideOn(ctx) then
				ctx:fail("You have a ride going, press Escape to close Wuber, and the ride is gone.", tostring(ride0) .. " -> " .. tostring(ctx.W.ride and ctx.W.ride.state))
			end
		end,
	}

	Hunt.promise{
		id = "phone.minimap_button_toggles",
		area = "Phone",
		text = "Clicking the Wuber button by the minimap opens Wuber, and clicking it again closes it.",
		source = "Minimap.lua; Settings > Map > Minimap button", kind = "scenario",
		needs = { phone = "closed" },
		when = function(sit) return is(sit, "combat", "no") and sit.minimapHidden ~= "on" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local b = ctx.me.env.WuberMinimapButton
			if not b then ctx:cannot("no minimap button in this game") end
			if not ctx:visible(b) then
				if ctx.W.db.minimapHidden == true then ctx:na("the minimap button is switched off") end
				ctx:fail("The Minimap button switch is on and there is no Wuber button by the minimap.")
			end
			ctx.me:clickOn(b)
			ctx:advance(0.6)
			ctx:note("click the minimap button")
			if not shown(ctx) then ctx:fail("You click the Wuber button by the minimap and Wuber does not open.", onScreen(ctx)) end
			ctx:advance(2)
			local reach = reachable(ctx, b)
			if not reach then ctx:na("the open Wuber window covers the minimap button at this size, so a click on it lands on the window (the player closes with Escape)") end
			ctx.me:clickOn(b)
			ctx:advance(0.8)
			ctx:note("click the minimap button again")
			if shown(ctx) then ctx:fail("You click the Wuber button by the minimap with Wuber open and it does not close.") end
		end,
	}

	Hunt.promise{
		id = "phone.splash_ends",
		area = "Phone",
		text = "The splash is over within a couple of seconds of opening Wuber, and the page behind it can be used.",
		source = "Phone.lua header (the splash fades out after 1.2 s)", kind = "scenario",
		needs = { phone = "closed" },
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			slash(ctx, "/wuber", 0.2)
			if not shown(ctx) then ctx:cannot("the phone did not open") end
			ctx:advance(2.5)
			local sp = ui(ctx).splash
			if sp and ctx:visible(sp) then ctx:fail("You open Wuber and the splash is still covering it two and a half seconds later.", onScreen(ctx)) end
			if ui(ctx).splashing then ctx:fail("You open Wuber and, two and a half seconds later, it still thinks the splash is playing.") end
		end,
	}

	---------------------------------------------------------------------------
	-- Where the window stands
	---------------------------------------------------------------------------
	-- where the window is on the screen (its left edge and top, in screen units, whole numbers) and how it is anchored
	local function point(ctx)
		local b = box(ctx, ui(ctx).win)
		local p, _, rp, x, y = ui(ctx).win:GetPoint(1)
		return ("left %d top %d (anchor %s/%s %s,%s, width %d)"):format(b.l + 0.5, b.t + 0.5, tostring(p), tostring(rp), tostring(x), tostring(y), b.r - b.l + 0.5)
	end
	local function spot(ctx)
		local b = box(ctx, ui(ctx).win)
		return b and { math.floor(b.l + 0.5), math.floor(b.t + 0.5), (b.r - b.l) } or { 0, 0, 0 }
	end
	local function sameSpot(a, b) return math.abs(a[1] - b[1]) <= 2 and math.abs(a[2] - b[2]) <= 2 end
	local function topBar(ctx) return ui(ctx).top end

	Hunt.promise{
		id = "phone.place_remembered",
		area = "Phone",
		text = "Where you drag Wuber is where it opens next time, after closing it and after a /reload.",
		source = "Window.lua header (a saved place is never moved); BRIEF19 R6", kind = "scenario",
		needs = { pos = "usual", phone = "closed" },
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			slash(ctx, "/wuber", 0.3)
			settle(ctx)
			local top = topBar(ctx)
			if not (top and ctx:visible(top)) then ctx:cannot("no top bar to drag") end
			ctx.me:drag(top, -140, 70)
			ctx:advance(0.5)
			ctx:note("drag the window by its top bar")
			local dragged, dspot = point(ctx), spot(ctx)
			ctx.me:pressEscape()
			ctx:advance(0.8)
			slash(ctx, "/wuber", 0.3)
			settle(ctx)
			if not sameSpot(spot(ctx), dspot) then
				ctx:fail("You drag Wuber to a new place, close it, open it again and it is somewhere else.", "dragged to " .. dragged .. ", reopened at " .. point(ctx))
			end
			ctx:reload()
			ctx:advance(1)
			slash(ctx, "/wuber", 0.3)
			settle(ctx)
			if not sameSpot(spot(ctx), dspot) then
				ctx:fail("You drag Wuber to a new place, /reload, open it and it is somewhere else.", "dragged to " .. dragged .. ", after the reload " .. point(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "phone.opens_on_screen",
		area = "Phone", gap = "the fake game does not clamp a frame that asks to stay on screen, so an off-screen saved place is not tested",
		text = "Wuber always opens inside the game window, whatever place it was left in or how the window is sized.",
		source = "Window.lua header; Settings > Window position", kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			ensureOpen(ctx)
			ctx:advance(2.4)
			local win = ui(ctx).win
			if not (win and shown(ctx)) then ctx:cannot("the phone did not open") end
			local b, P = box(ctx, win), ctx.me.env.UIParent
			if not b then ctx:cannot("the window has no place") end
			local sw, sh = P:GetWidth(), P:GetHeight()
			if b.l < -1 or b.b < -1 or b.r > sw + 1 or b.t > sh + 1 then
				ctx:fail("You open Wuber and part of it is off the edge of the game window.",
					("window %.0f..%.0f x %.0f..%.0f in a %.0f x %.0f screen, saved place %s"):format(b.l, b.r, b.b, b.t, sw, sh, ctx.W.db.pos and table.concat(ctx.W.db.pos, ",") or "none"))
			end
		end,
	}

	Hunt.promise{
		id = "phone.default_place_clear_of_chat", gap = "the fake game's chat frame has no size: the check places one like the game's",
		area = "Phone",
		text = "When you have never moved Wuber it opens clear of your chat window, not on top of it.",
		source = "CHANGELOG 2.3.2 / BRIEF19 R6 (the window keeps clear of the chat box)", kind = "scenario",
		needs = { pos = "usual", phone = "closed" },
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			-- the fake game's chat frame has no size: stand in for the game's own (bottom left, about 430 x 180)
			local cf = ctx.me.env.DEFAULT_CHAT_FRAME
			if cf and not chatBox(ctx) then
				cf:SetSize(430, 180) cf:ClearAllPoints() cf:SetPoint("BOTTOMLEFT", ctx.me.env.UIParent, "BOTTOMLEFT", 35, 100) cf:Show()
				ctx:note("the chat frame is given a place (stand-in for the game's)")
			end
			slash(ctx, "/wuber", 0.3)
			ctx:advance(2.4)
			local chat, win = chatBox(ctx), ui(ctx).win
			if ctx.W.db.pos ~= nil then ctx:na("this player's saved data already holds a place for the window") end
			if not chat then ctx:cannot("no chat box position in this game") end
			if not (win and shown(ctx)) then ctx:cannot("the phone did not open") end
			local b = box(ctx, win)
			if b and overlap(b, chat, 2) then
				ctx:fail("You have never moved Wuber, open it, and it sits on top of your chat window.",
					("window %.0f..%.0f x %.0f..%.0f, chat %.0f..%.0f x %.0f..%.0f"):format(b.l, b.r, b.b, b.t, chat.l, chat.r, chat.b, chat.t))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- Tabs
	---------------------------------------------------------------------------
	Hunt.promise{
		id = "phone.tabs_open_their_pages",
		area = "Phone",
		text = "Clicking Ride, Trips and Drive at the top of the phone opens that tab, and Ride brings you back.",
		source = "tooltips of the tabs (Window.lua TAB_TIPS)", kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			ensureOpen(ctx)
			ctx:advance(2.4)
			local s = ui(ctx)
			if not (s.tabs and shown(ctx)) then ctx:cannot("no tabs") end
			for _, name in ipairs({ "Trips", "Drive", "Ride" }) do
				local tab
				for _, t in ipairs(s.tabs) do if t.name == name then tab = t end end
				if tab and tab.button and ctx:visible(tab.button) then
					press(ctx, tab.button)
					ctx:advance(1)
					ctx:note("click the " .. name .. " tab")
					if s.tab ~= name then
						ctx:fail(("You click the %s tab and the phone shows the %s tab."):format(name, tostring(s.tab)), onScreen(ctx))
					end
				end
			end
		end,
	}

	---------------------------------------------------------------------------
	-- The fold
	---------------------------------------------------------------------------
	local function foldMod(ctx)
		local F = ctx.W.UI and ctx.W.UI.Fold
		if not (F and type(F.IsUnfolded) == "function") then ctx:cannot("this Wuber has no fold") end
		return F
	end
	local function widthOf(ctx) return ui(ctx).win:GetWidth() end

	Hunt.promise{
		id = "phone.fold_button_remembered",
		area = "Phone",
		text = "On a page that can open out to two panes, the fold button folds and unfolds it, and Wuber remembers your choice for that page after a /reload.",
		source = "Settings > Wide pages (\"Wide or narrow, per page\"; Forget what you chose on each page)", kind = "scenario",
		needs = { phone = "closed", fold = "unfolded" },
		when = function(sit) return is(sit, "combat", "no") and is(sit, "ride", "none") and sit.session ~= "first" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local F = foldMod(ctx)
			slash(ctx, "/wuber", 0.3)
			settle(ctx)
			local btn = ui(ctx).phone and ui(ctx).phone.fold
			if ui(ctx).coaching then ctx:na("the first-open tips are showing (phone.narrow_while_coaching covers that)") end
			if not (btn and ctx:visible(btn)) then ctx:cannot("no fold button on this page") end
			if not F.IsUnfolded() then ctx:cannot("this page is not unfolded here (no room, or a rule keeps it narrow)") end
			local w0 = widthOf(ctx)
			press(ctx, btn)
			ctx:advance(1.2)
			ctx:note("click the fold button")
			if F.IsUnfolded() or widthOf(ctx) >= w0 then
				ctx:fail("You press the fold button on an open-out page and it does not fold up.", ("width %.0f -> %.0f"):format(w0, widthOf(ctx)))
			end
			ctx:reload()
			ctx:advance(1)
			slash(ctx, "/wuber", 0.3)
			settle(ctx)
			local F2 = foldMod(ctx)
			if F2.IsUnfolded() then ctx:fail("You fold the page up, /reload, open Wuber and the page has opened out again.") end
		end,
	}

	Hunt.promise{
		id = "phone.always_narrow",
		area = "Phone",
		text = "With Wide pages set to Always narrow, no page opens out to two panes.",
		source = "Settings > This window > Wide pages (Auto / Always narrow)", kind = "scenario",
		needs = { phone = "closed", fold = "narrow" },
		when = function(sit) return is(sit, "combat", "no") and sit.session ~= "first" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local F = foldMod(ctx)
			slash(ctx, "/wuber", 0.3)
			settle(ctx)
			if F.IsUnfolded() then ctx:fail("Wide pages is on Always narrow and Wuber opens out to two panes.", ("width %.0f"):format(widthOf(ctx))) end
			ctx.me:slash("/wuber help")
			ctx:advance(2)
			ctx:note("/wuber help")
			if F.IsUnfolded() then ctx:fail("Wide pages is on Always narrow and Settings opens out to two panes.", ("width %.0f"):format(widthOf(ctx))) end
		end,
	}


	Hunt.promise{
		id = "phone.narrow_while_coaching",
		area = "Phone",
		text = "While the first-open tips are showing, Wuber stays one narrow pane and does not open out.",
		source = "SPEC7 section 2.1 (splash and coach running: always folded); Fold.lua header", kind = "scenario",
		needs = { coach = "not_done", phone = "closed" },
		when = function(sit) return is(sit, "combat", "no") and is(sit, "ride", "none") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local F = foldMod(ctx)
			slash(ctx, "/wuber", 0.3)
			ctx:advance(3)
			if not ui(ctx).coaching then ctx:na("the first-open tips are not showing here") end
			if F.IsUnfolded() or widthOf(ctx) > 400 then
				ctx:fail("You open Wuber for the first time, the first-open tips show, and the window is already opened out to two panes.",
					("width %.0f, tips showing %s"):format(widthOf(ctx), tostring(ui(ctx).coaching)))
			end
		end,
	}

	-- always: the window is never wider than the game window, and on a never-moved window it never unfolds over the chat
	Hunt.promise{
		id = "phone.unfold_has_room",
		area = "Phone",
		text = "Wuber only opens out to two panes where the game window has room: it is never wider than the screen, and a window you never moved does not open out over your chat.",
		source = "Fold.lua header; BRIEF19 R6", kind = "always",
		check = function(ctx)
			local win = ui(ctx).win
			if not (win and shown(ctx)) then ctx:na("closed") end
			local b = box(ctx, win)
			if not b then ctx:na("no place") end
			local P = ctx.me.env.UIParent
			if (b.r - b.l) > P:GetWidth() + 1 then
				ctx:fail("Wuber opens out wider than your game window.", ("window %.0f wide, screen %.0f"):format(b.r - b.l, P:GetWidth()))
			end
			local F = ctx.W.UI.Fold
			if F and type(F.IsUnfolded) == "function" and F.IsUnfolded() and ctx.W.db.pos == nil then
				local chat = chatBox(ctx)
				if chat and overlap(b, chat, 2) then
					ctx:fail("You never moved Wuber, it opens out to two panes and covers your chat window.",
						("window %.0f..%.0f x %.0f..%.0f, chat %.0f..%.0f x %.0f..%.0f"):format(b.l, b.r, b.b, b.t, chat.l, chat.r, chat.b, chat.t))
				end
			end
		end,
	}

	Hunt.promise{
		id = "phone.fold_frozen_in_combat",
		area = "Phone",
		text = "Once a fight starts Wuber keeps its width: the fold button does not change it mid-fight.",
		source = "Fold.lua header (in combat the width never changes: the game blocks it)", kind = "scenario",
		needs = { phone = "closed" },
		when = function(sit) return is(sit, "combat", "no") and sit.session ~= "first" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			slash(ctx, "/wuber", 0.3)
			settle(ctx)
			local btn = ui(ctx).phone and ui(ctx).phone.fold
			if not (btn and ctx:visible(btn)) then ctx:cannot("no fold button on this page") end
			local w0 = widthOf(ctx)
			ctx.w:enterCombat(ctx.me)
			ctx:advance(1)
			ctx:note("combat starts")
			local w1 = widthOf(ctx)
			if math.abs(w1 - w0) > 0.5 then ctx:fail("A fight starts while Wuber is open and its width changes.", ("%.0f -> %.0f"):format(w0, w1)) end
			pcall(function() ctx.me:click(btn) end)
			ctx:advance(1)
			ctx:note("click the fold button in combat")
			if math.abs(widthOf(ctx) - w0) > 0.5 then
				ctx:fail("You press the fold button in a fight and Wuber changes width.", ("%.0f -> %.0f"):format(w0, widthOf(ctx)))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- Toasts
	---------------------------------------------------------------------------
	local function toastFrames(ctx)
		local out = {}
		for _, obj in ipairs(ctx.me.widgets or {}) do
			if type(obj) == "table" and obj.card and obj.icon and obj.mark and ctx:visible(obj) then out[#out + 1] = obj end
		end
		return out
	end

	Hunt.promise{
		id = "phone.toast_clear_of_phone_and_chat",
		area = "Phone",
		text = "A pop-up note (toast) never covers Wuber's tabs, the open window or your chat.",
		source = "Toasts.lua header (clear of the open window and the chat box); BRIEF19 R6", kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			ensureOpen(ctx)
			ctx:advance(2.4)
			if not (ui(ctx).win and shown(ctx)) then ctx:cannot("the phone did not open") end
			ctx.W.UI.Toast("Hunt test note", "info")
			ctx:advance(1)
			ctx:note("a toast shows")
			local toasts = toastFrames(ctx)
			if #toasts == 0 then ctx:cannot("no toast frame found") end
			local wb, chat = box(ctx, ui(ctx).win), chatBox(ctx)
			do -- the window can fill the screen: Toasts.lua phonePlace then has no spot (72 above or below, 336 beside) and falls back to the top
				local P = ctx.me.env.UIParent
				local ph = box(ctx, ui(ctx).phone or ui(ctx).win)
				local sw, sh = P:GetWidth(), P:GetHeight()
				if ph and sw and sh and not (sh - ph.t >= 72 or sw - ph.r >= 336 or ph.l >= 336 or ph.b >= 72 or ph.r < sw / 2 - 160 or ph.l > sw / 2 + 160) then
					ctx:na("the Wuber window leaves no room on screen for a toast")
				end
			end
			for _, t in ipairs(toasts) do
				local tb = box(ctx, t)
				if tb and wb and overlap(tb, wb, 1) then
					ctx:fail("A pop-up note shows while Wuber is open and it sits over the Wuber window.",
						("toast %.0f..%.0f x %.0f..%.0f, window %.0f..%.0f x %.0f..%.0f"):format(tb.l, tb.r, tb.b, tb.t, wb.l, wb.r, wb.b, wb.t))
				end
				if tb and chat and overlap(tb, chat, 1) then ctx:fail("A pop-up note shows over your chat window.") end
			end
		end,
	}

	---------------------------------------------------------------------------
	-- Typed words
	---------------------------------------------------------------------------
	local function chatSaw(ctx, pattern) return ctx.me:said(pattern) end

	Hunt.promise{
		id = "phone.slash_words",
		area = "Phone",
		text = "/wuber help, /wuber settings and a word Wuber does not know open Settings; /wuber bug opens the bug report; /wuber drive opens the Drive tab; /wuber test says how the check went.",
		source = "Commands.lua header (what /wuber, help, bug, drive, test do)", kind = "scenario",
		needs = { phone = "closed", tipsOn = "off" }, -- (the first-open tip moves a first open to Home on purpose: Tips.lua header)
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local U = ctx.W.UI
			for _, word in ipairs({ "help", "settings", "options", "gibberish" }) do
				if shown(ctx) then ctx.me:pressEscape() ctx:advance(0.8) end
				slash(ctx, "/wuber " .. word, 2.5)
				if not (ui(ctx).settingsOpen and shown(ctx)) then
					ctx:fail(("You type /wuber %s and Settings does not open."):format(word), onScreen(ctx))
				end
			end
			if shown(ctx) then ctx.me:pressEscape() ctx:advance(0.8) end
			slash(ctx, "/wuber bug", 1.5)
			if not (U.Bug and U.Bug.Shown and U.Bug.Shown()) then ctx:fail("You type /wuber bug and the bug report does not open.", onScreen(ctx)) end
			if U.Bug and U.Bug.Close then U.Bug.Close() ctx:advance(0.5) end
			if shown(ctx) then ctx.me:pressEscape() ctx:advance(0.8) end
			slash(ctx, "/wuber drive", 2.5)
			if not (shown(ctx) and ui(ctx).tab == "Drive") then
				ctx:fail("You type /wuber drive and the Drive tab does not open.", "tab " .. tostring(ui(ctx).tab) .. "; " .. onScreen(ctx))
			end
			local n = #ctx.me.chatLines
			slash(ctx, "/wuber test", 0.5)
			if #ctx.me.chatLines == n then ctx:fail("You type /wuber test and nothing is said in chat.") end
			if not (chatSaw(ctx, "checks passed") or chatSaw(ctx, "checks failed")) then
				ctx:fail("You type /wuber test and chat does not say how many checks passed.", tostring(ctx.me.chatLines[#ctx.me.chatLines]))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- The bug report
	---------------------------------------------------------------------------
	-- another player Wuber has really dealt with (it holds the name in its lists, the ride or the queue)
	local function holds(ctx, name)
			local W = ctx.W
			local low = name:lower()
			local seen = {}
			local function look(t, depth)
				if type(t) ~= "table" or seen[t] or depth < 0 then return false end
				seen[t] = true
				for k, v in pairs(t) do
					if type(k) == "string" and k:lower():gsub("%-", " ") == low then return true end
					if type(v) == "string" and v:lower():gsub("%-", " ") == low then return true end
					if type(v) == "table" and look(v, depth - 1) then return true end
				end
				return false
			end
			local okc, char = pcall(W.Char)
			return look(W.drivers, 1) or look(W.incoming, 1) or look(W.ride, 1) or look(W.db and W.db.rides, 1)
				or look(okc and char or nil, 2) or look(W.Drive and W.Drive.customers, 1)
		end
	Hunt.promise{
		id = "phone.bug_report_hides_names",
		area = "Phone",
		text = "The bug report is a ready text to copy: your own name shows as me and another player's name as player 1, and nothing is sent.",
		source = "Settings > Report a bug (\"Other players' names are left out and nothing is sent\"); CHANGELOG 2.3.2", kind = "scenario",
		needs = { phone = "closed" },
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local U = ctx.W.UI
			if not (U.Bug and U.Bug.Open) then ctx:cannot("no bug report in this Wuber") end
			local peerName
			for _, key in ipairs({ "driver", "rider", "captain", "helper" }) do
				local p = ctx.peers and ctx.peers[key]
				if type(p) == "table" and p.player and p.player.name and holds(ctx, p.player.name) then peerName = p.player.name break end
			end
			slash(ctx, "/wuber bug", 1.5)
			local f = U.Bug.frame
			if not (f and f.note and f.copy) then ctx:cannot("the report window has no boxes") end
			local note = "I am " .. ctx.name .. (peerName and (" and " .. peerName .. " saw it") or " and it broke")
			ctx.me:type(f.note.edit, note, false)
			ctx:advance(0.6)
			ctx:note("type a note with names in it (" .. ctx.name .. (peerName and (", " .. peerName) or "") .. ")")
			local report = f.copy.edit:GetText() or ""
			if report == "" then ctx:fail("You type /wuber bug and the report box is empty.") end
			if report:find(ctx.name, 1, true) then
				ctx:fail("You type your own name into the bug report note and your name is in the report you would copy.", report:sub(1, 300))
			end
			if peerName and report:find(peerName, 1, true) then
				ctx:fail("You type another player's name into the bug report note and their name is in the report you would copy.", report:sub(1, 300))
			end
			if not report:find(" me ", 1, true) and not report:find("me ", 1, true) then
				ctx:fail("Your own name in the bug report note is not changed to me.", report:sub(1, 300))
			end
		end,
	}

	Hunt.promise{
		id = "phone.bug_report_fresh",
		area = "Phone",
		text = "Each time you open the bug report the note starts empty and the report is made again from now.",
		source = "Bug.lua header; Help (Report a bug)", kind = "scenario",
		needs = { phone = "closed" },
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local U = ctx.W.UI
			if not (U.Bug and U.Bug.Open) then ctx:cannot("no bug report in this Wuber") end
			slash(ctx, "/wuber bug", 1.5)
			local f = U.Bug.frame
			if not (f and f.note) then ctx:cannot("the report window has no note box") end
			ctx.me:type(f.note.edit, "first words", false)
			ctx:advance(0.5)
			U.Bug.Close()
			ctx:advance(0.8)
			if shown(ctx) then ctx.me:pressEscape() ctx:advance(0.8) end
			slash(ctx, "/wuber bug", 1.5)
			f = U.Bug.frame
			if (f.note.edit:GetText() or "") ~= "" then
				ctx:fail("You type a note in the bug report, close it, open it again and your old note is still there.", f.note.edit:GetText())
			end
			if (f.copy.edit:GetText() or ""):find("first words", 1, true) then
				ctx:fail("You close the bug report and open it again and the report still holds your old note.")
			end
		end,
	}
	---------------------------------------------------------------------------
	-- The share pill
	---------------------------------------------------------------------------
	Hunt.promise{
		id = "phone.share_pill_after_combat",
		area = "Phone",
		text = "When a Share button is showing, a fight turns it into \"Share after combat\" that cannot post, and it comes back when the fight ends.",
		source = "Share.lua header (in combat: \"Share after combat\", dimmed, no overlay)", kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "combat", "no") and (sit.ride == "arrived" or sit.ride == "paid" or sit.ride == "ended") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local Share = ctx.W.UI and ctx.W.UI.Share
			if not (Share and type(Share.Target) == "function") then ctx:cannot("this Wuber has no share pills") end
			ensureOpen(ctx)
			ctx:advance(2.6)
			local pill = Share.Target()
			if not pill then ctx:na("no Share button is showing on the screen the ride dial left the phone on") end
			ctx.w:enterCombat(ctx.me)
			ctx:advance(1)
			ctx:note("combat starts")
			local saw = false
			for _, t in ipairs(ctx:texts()) do if t == "Share after combat" then saw = true end end
			if not saw then ctx:fail("A Share button is showing, a fight starts, and it does not say \"Share after combat\".", onScreen(ctx)) end
			if Share.Target() then ctx:fail("A Share button is showing, a fight starts, and the button can still be clicked to post.") end
			ctx.w:leaveCombat(ctx.me)
			ctx:advance(2)
			ctx:note("combat ends")
			if not Share.Target() then
				local okS, state = pcall(Share.State, pill)
				if okS and state == "solo" then ctx:na("you left the group meanwhile (Leave the group after the ride), so there is nobody to share with") end
				ctx:fail("A fight ends and the Share button does not come back.",
					("pill state %s, shown %s, visible %s, tab %s screen %s; %s"):format(tostring(okS and state), tostring(pill:IsShown()), tostring(ctx:visible(pill)), tostring(ui(ctx).tab), tostring(ui(ctx).screen), onScreen(ctx)))
			end
		end,
	}
	Hunt.promise{
		id = "phone.bug_report_hides_realm_names",
		area = "Phone",
		text = "A player's name written with a realm (Name-Realm) in an error is left out of the bug report whole: neither the name nor the realm shows.",
		source = "Settings > Report a bug (\"Other players' names are left out\"); BRIEF19 R3; Bug.lua header", kind = "scenario",
		needs = { phone = "closed" },
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local U = ctx.W.UI
			if not (U.Bug and U.Bug.Open and type(ctx.W.Error) == "function") then ctx:cannot("no bug report / error log in this Wuber") end
			local first
			for _, key in ipairs({ "driver", "rider", "captain", "helper" }) do
				local p = ctx.peers and ctx.peers[key]
				local n = type(p) == "table" and p.player and p.player.name
				if n and holds(ctx, n) then first = n:match("^(%S+)") break end
			end
			if not first then ctx:na("Wuber holds no other player's name here") end
			-- an error whose text names the player with a realm, as the game writes names
			ctx.W.Error("hunt", "could not send to " .. first .. "-Argentdawn")
			ctx:note("an error names " .. first .. "-Argentdawn")
			slash(ctx, "/wuber bug", 1.5)
			local report = U.Bug.frame and U.Bug.frame.copy and U.Bug.frame.copy.edit:GetText() or ""
			-- the error was put there by this check: take it out again so the universal "no Lua error" promise does not count it
			local log = ctx.W.errorLog
			if type(log) == "table" then
				for i = #log, 1, -1 do if type(log[i]) == "table" and log[i].where == "hunt" then table.remove(log, i) end end
			end
			if type(ctx.W.lastError) == "string" and ctx.W.lastError:find("hunt", 1, true) then ctx.W.lastError = nil end
			if report:find("Argentdawn", 1, true) or report:find(first, 1, true) then
				ctx:fail("An error that names another player with a realm is in the bug report and part of the name (" .. (report:find(first, 1, true) and first or "Argentdawn") .. ") still shows.", report:match("Errors.-\n\n") or report:sub(1, 400))
			end
		end,
	}
end

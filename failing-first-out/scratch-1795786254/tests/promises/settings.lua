-- Promises about Settings (owner SHELL). Written from what the player is told: every switch's label and tooltip,
-- the search box ("Click and type a word ... to find a setting"), "No settings match", "Check my game", the Help rows,
-- "Report a bug" ("A report to copy. Nothing is sent."), "Window position: Back to its usual place".
-- Switches are clicked where they are drawn (a real click); a promise looks at what the switch face says, what Wuber
-- then does (the effect the label names) and what is still true after a /reload.
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

	local function settingsUp(ctx)
		local st = ctx.W.UI and ctx.W.UI.settings
		return st and st.controls and ui(ctx).settingsOpen == true and st or nil
	end

	-- the bug report (phone=bug) is a window over everything: a player closes it before looking at Settings
	local function closeBug(ctx)
		local B = ctx.W.UI and ctx.W.UI.Bug
		if type(B) == "table" and type(B.Shown) == "function" and B.Shown() and type(B.Close) == "function" then
			B.Close()
			ctx:note("close the bug report")
			ctx:advance(0.5)
		end
	end

	-- the player types /wuber help: Wuber opens on its Settings (what Help says)
	-- the section: the player taps its card in the folded Settings (it is one long page when the phone is open out)
	local function openSettings(ctx, section)
		if not settingsUp(ctx) then
			ctx.me:slash("/wuber help")
			ctx:note("/wuber help")
			ctx:advance(2.4)
		end
		local st = settingsUp(ctx)
		if not st then ctx:cannot("/wuber help did not open Settings") end
		-- the rain check offer is a deliberate modal sheet (UI/Moments.lua buildOffer, FULLSCREEN_DIALOG) over the window until it is answered
		local offer
		pcall(function() offer = ui(ctx).rcOffer end)
		if offer and offer.IsShown and offer:IsShown() then ctx:na("the rain check offer card is up over Settings until the player answers it") end
		if section and type(ctx.W.UI.OpenSettings) == "function" then
			ctx.W.UI.OpenSettings(section)
			ctx:advance(1)
			ctx:note("open the " .. section .. " section of Settings")
			st = settingsUp(ctx) or st
		end
		return st
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

	-- a click on the control: where it is drawn when that spot is the control, else on the control itself
	-- (it is scrolled out of the list: the player scrolls to it)
	local function press(ctx, obj)
		local okc, cx, cy = pcall(obj.GetCenter, obj)
		-- GetCenter is in the frame's own scale, frameAt in the screen's
		local ratio = okc and cx and obj:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale() or 1
		local hit = okc and cx and ctx.me:frameAt(cx * ratio, cy * ratio) or nil
		if hit and inside(hit, obj) and pcall(ctx.me.clickOn, ctx.me, obj) then return end
		ctx.me:click(obj)
	end

	-- is this control the thing a click on it lands on (nothing is drawn over it)? returns true, or false and what is over it
	local function reachable(ctx, obj)
		local okc, cx, cy = pcall(obj.GetCenter, obj)
		if not (okc and cx) then return true end
		local ratio = obj:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale() -- GetCenter is in the frame's own scale, frameAt in the screen's
		local hit = ctx.me:frameAt(cx * ratio, cy * ratio)
		if not hit or inside(hit, obj) then return true end
		local lvl = pcall(hit.GetFrameLevel, hit) and hit:GetFrameLevel() or "?"
		local chain, f = {}, hit
		while f and #chain < 6 do chain[#chain + 1] = tostring(f) .. "@" .. tostring(f:GetFrameLevel()) f = f:GetParent() end
		return false, ("a click there lands on another frame (level %s, the control is level %s; hit %s; control at %s,%s)"):format(tostring(lvl), tostring(obj:GetFrameLevel()), table.concat(chain, " < "), tostring(cx), tostring(cy))
	end

	local function labelOf(t)
		local ok, s = pcall(function() return t.row.label:GetText() end)
		if ok and type(s) == "string" and s ~= "" then return s end
		return nil
	end

	-- every switch on screen in the section keys wanted: { key, control, label }
	local function switches(ctx, st, want)
		local list = {}
		for key, t in pairs(st.controls) do
			if type(t) == "table" and type(t.get) == "function" and t.row and not t.holder and key ~= "drive.autoPublic" and want(key) then
				-- a switch that says it follows someone else's setting (a crew window's "Show ride passphrase" follows the captain) is not clicked
				local okd, desc = pcall(function() return t.row.desc:GetText() end)
				local follows = okd and type(desc) == "string" and desc:find("Follows your captain", 1, true)
				if ctx:visible(t) and not follows then list[#list + 1] = { key = key, t = t, label = labelOf(t) or key } end
			end
		end
		table.sort(list, function(a, b) return a.key < b.key end)
		return list
	end

	local function face(t) return t.on == true end
	local function val(t) return t.get() == true end

	-- flip every switch of a family with a real click and look at the face and the saved value; then /reload and look again
	local function family(ctx, want, name, section)
		local st = openSettings(ctx, section)
		local list = switches(ctx, st, want)
		if #list == 0 then ctx:na("no " .. name .. " switch is on screen for this player") end
		for _, s in ipairs(list) do
			local before = val(s.t)
			press(ctx, s.t)
			ctx:advance(0.6)
			ctx:note("click " .. s.label)
			local st2 = settingsUp(ctx)
			if not st2 then ctx:fail(("You click the \"%s\" switch in Settings and Settings closes."):format(s.label)) end
			if face(s.t) == before then
				ctx:fail(("You click the \"%s\" switch in Settings and its knob does not move: it still says %s."):format(s.label, before and "on" or "off"))
			end
			if val(s.t) == before then
				ctx:fail(("You click the \"%s\" switch in Settings: it shows %s but Wuber still treats it as %s."):format(s.label, face(s.t) and "on" or "off", before and "on" or "off"))
			end
		end
		-- the state now: each switch the opposite of what it was
		local expect = {}
		for _, s in ipairs(list) do expect[s.key] = val(s.t) end
		ctx:reload()
		ctx:advance(1)
		local st3 = openSettings(ctx, section)
		for _, s in ipairs(list) do
			local t = st3.controls[s.key]
			if not (t and type(t.get) == "function") then
				ctx:fail(("You switch \"%s\" and /reload, and the switch is gone from Settings."):format(s.label))
			end
			if t.get() ~= expect[s.key] then
				ctx:fail(("You switch \"%s\" %s in Settings, /reload, and it is back %s."):format(s.label, expect[s.key] and "on" or "off", expect[s.key] and "off" or "on"))
			end
			if face(t) ~= expect[s.key] then
				ctx:fail(("You switch \"%s\" %s in Settings, /reload, and the switch looks %s."):format(s.label, expect[s.key] and "on" or "off", face(t) and "on" or "off"))
			end
		end
	end

	local FAMILIES = {
		{ id = "settings.riding_switches", name = "Riding", section = "riding", text = "Each Riding switch (Login tips, Auto-accept my driver's invite, Leave the group after the ride, Flight master tip) changes when you click it, and keeps that after a /reload.",
			want = function(k) return k == "tips" or k == "autoAccept" or k == "autoLeave" or k == "birdTip" end },
		{ id = "settings.driving_switches", name = "Driving", section = "driving", text = "Each Driving switch changes when you click it, and keeps that after a /reload.",
			want = function(k) return k == "advertOnline" or k == "starter" or k:sub(1, 6) == "drive." end,
			needs = nil },
		{ id = "settings.map_switches", name = "Map", section = "map", text = "Each Map switch (Drivers on the world map, Crowns and badges over heads, the Pioneer emblems, Minimap button) changes when you click it, and keeps that after a /reload.",
			want = function(k) return k == "mapPins" or k == "plates" or k == "emblems" or k == "myEmblem" or k == "minimap" end },
		{ id = "settings.sound_switch", name = "Sound", section = "sound", text = "The Sounds switch changes when you click it, and keeps that after a /reload.",
			want = function(k) return k == "sound" end },
		{ id = "settings.window_switches", name = "This window", section = "window", text = "The Tell me about updates switch changes when you click it, and keeps that after a /reload.",
			want = function(k) return k == "updateNotes" end },
	}
	for _, f in ipairs(FAMILIES) do
		Hunt.promise{
			id = f.id, area = "Settings", text = f.text,
			source = "tooltip (Settings rows); round 26 item 1", kind = "scenario",
			when = function(sit) return is(sit, "combat", "no") end,
			check = function(ctx)
				if ctx.me.player.combat then ctx:na("in combat") end
				family(ctx, f.want, f.name, f.section)
			end,
		}
	end
	local function onScreen(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end
	local function typeInto(ctx, st, word)
		local box = st.find and st.find.box and st.find.box.edit
		if not box then ctx:cannot("no search box in Settings") end
		ctx.me:type(box, word, false)
		ctx:advance(0.6)
		ctx:note("type \"" .. word .. "\" in the settings search")
	end
	-- the matches showing now: { label, ... }
	local function matches(ctx, st)
		local out = {}
		for _, b in ipairs(st.find.items or {}) do
			if b.m and ctx:visible(b) then out[#out + 1] = b.m.label end
		end
		return out
	end

	Hunt.promise{
		id = "settings.search_finds", area = "Settings",
		text = "Typing a word the search box suggests (sound, invite, map, price) into the Settings search lists at least one setting about it.",
		source = "tooltip (Search settings: \"Click and type a word (sound, invite, map, price)\")", kind = "scenario",
		check = function(ctx)
			closeBug(ctx)
			local st = openSettings(ctx)
			ctx.W.UI.OpenSettings() -- back to the Settings home (the phone may have been left on Help), where the search box is
			ctx:advance(1)
			for _, word in ipairs({ "sound", "invite", "map", "price" }) do
				typeInto(ctx, st, word)
				if #matches(ctx, st) == 0 then
					ctx:fail(("You type \"%s\" in the Settings search, as its tooltip suggests, and no setting is listed."):format(word), onScreen(ctx))
				end
				for _, b in ipairs(st.find.items or {}) do
					if b.m and ctx:visible(b) then
						local reach, over = reachable(ctx, b)
						if not reach then
							ctx:fail(("You type \"%s\" in the Settings search and the matches are drawn under something else, so you cannot click them."):format(word),
								over .. "; Help showing: " .. tostring(ctx.W.UI.HelpShown and ctx.W.UI.HelpShown()))
						end
						break
					end
				end
			end
		end,
	}

	Hunt.promise{
		id = "settings.search_none", area = "Settings",
		text = "Typing a word no setting has shows \"No settings match\" and a Clear button, and Clear brings the settings back.",
		source = "Settings search (round 9 G1)", kind = "scenario",
		check = function(ctx)
			closeBug(ctx)
			local st = openSettings(ctx)
			ctx.W.UI.OpenSettings() -- back to the Settings home (the phone may have been left on Help), where the search box is
			ctx:advance(1)
			typeInto(ctx, st, "qzxwv")
			local f = st.find
			if not (f.none and ctx:visible(f.none)) then
				ctx:fail("You type nonsense in the Settings search and \"No settings match\" does not show.", onScreen(ctx))
			end
			if #matches(ctx, st) > 0 then
				ctx:fail("You type nonsense in the Settings search and it still lists settings.", table.concat(matches(ctx, st), ", "))
			end
			local reach, over = reachable(ctx, f.none.clear)
			ctx.me:clickOn(f.none.clear)
			ctx:advance(0.6)
			ctx:note("click Clear")
			if ctx:visible(f.none) then
				ctx:fail("You type nonsense in the Settings search, press Clear under \"No settings match\", and the message and your typing stay.",
					(reach and "" or (over .. "; ")) .. "Help showing: " .. tostring(ctx.W.UI.HelpShown and ctx.W.UI.HelpShown()) .. "; " .. onScreen(ctx))
			end
			if f.box.edit:GetText() ~= "" then ctx:fail("You press Clear under \"No settings match\" and your typed word stays in the search box.") end
		end,
	}

	Hunt.promise{
		id = "settings.check_my_game", area = "Settings",
		text = "Check my game shows a list of what your game supports, each line passed or failed, and never says the check is not available.",
		source = "Settings > This window > Check my game (\"See what your game supports.\")", kind = "scenario",
		check = function(ctx)
			local st = openSettings(ctx, "window")
			local b = st.controls.check
			if not b then ctx:cannot("no Check my game button") end
			press(ctx, b)
			ctx:advance(1.5)
			ctx:note("click Check my game")
			local res = st.results
			if not (res and ctx:visible(res)) then ctx:fail("You press Check in Check my game and no result shows.", onScreen(ctx)) end
			local texts = ctx:texts()
			for _, t in ipairs(texts) do
				if t:find("isn't available", 1, true) then ctx:fail("You press Check in Check my game and it says the check is not available.", onScreen(ctx)) end
			end
			local n = 0
			for _, l in ipairs(res.lines or {}) do if ctx:visible(l) then n = n + 1 end end
			if n == 0 then ctx:fail("You press Check in Check my game and the card lists no checks.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "settings.driving_for_drivers", area = "Settings",
		text = "The Driving settings are there for Warlocks and their crews and not for a plain rider.",
		source = "Settings > Driving (Warlocks and crews only)", kind = "scenario",
		check = function(ctx)
			local st = openSettings(ctx, "driving")
			local drivers = ctx.sit.role ~= "rider" and ctx.sit.role ~= nil
			local seen = false
			for _, t in ipairs(ctx:texts()) do
				if t == "Invite riders who whisper me" then seen = true end
			end
			if drivers and not seen then
				ctx:fail("You are a driver, open the Driving part of Settings and there is no Driving setting (Invite riders who whisper me).", onScreen(ctx))
			elseif not drivers and seen then
				ctx:fail("You are a plain rider, open Settings and the Driving settings are there.", onScreen(ctx))
			end
		end,
	}

	-- the phone's window frame and its top bar, the one a player drags
	local function topBar(ctx) return ui(ctx).top end
	-- where the window is: its centre and its left edge (a window that widens keeps its left edge, one that is
	-- placed afresh is centred, so the usual place is either)
	local function centre(ctx)
		local win = ui(ctx).win
		local x, y = win:GetCenter()
		return x, y, win:GetLeft()
	end

	Hunt.promise{
		id = "settings.reset_position", area = "Settings",
		text = "Window position > Reset puts the window back in its usual place after you moved it.",
		source = "Settings > This window > Window position (\"Back to its usual place\")", kind = "scenario",
		needs = { pos = "usual", phone = "closed" },
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			ctx.me:slash("/wuber")
			ctx:advance(2.4)
			local x0, y0, l0 = centre(ctx)
			local top = topBar(ctx)
			if not (top and ctx:visible(top)) then ctx:cannot("no top bar to drag") end
			ctx.me:drag(top, 120, -90)
			ctx:advance(0.5)
			ctx:note("drag the window by its top bar")
			local x1, y1 = centre(ctx)
			if math.abs(x1 - x0) < 1 and math.abs(y1 - y0) < 1 then ctx:cannot("the drag did not move the window") end
			local st = openSettings(ctx, "window")
			local b = st.controls.resetPos
			if not b then ctx:cannot("no Window position Reset button") end
			press(ctx, b)
			ctx:advance(1)
			ctx:note("click Reset (Window position)")
			local x2, y2, l2 = centre(ctx)
			-- (the usual place is worked out for the window's width at that moment, so the exact spot differs between the
			-- narrow first open and the wide Settings: the promise is that the dragged place is forgotten and the window is
			-- back in the screen, away from where it was dragged)
			local win = ui(ctx).win
			local P = ctx.me.env.UIParent
			local sc = win:GetEffectiveScale() / P:GetEffectiveScale()
			local left, right, bottom, top2 = win:GetLeft() * sc, win:GetRight() * sc, win:GetBottom() * sc, win:GetTop() * sc
			local onScreen2 = left >= -1 and bottom >= -1 and right <= P:GetWidth() + 1 and top2 <= P:GetHeight() + 1
			local moved = math.abs(x2 - x1) > 20 or math.abs(y2 - y1) > 20
			if ctx.W.db.pos ~= nil or not moved or not onScreen2 then
				ctx:fail("You drag the window away, press Window position > Reset and it does not go back to its usual place.",
					("usual %.0f,%.0f (left %.0f); moved %.0f,%.0f; after Reset %.0f,%.0f (left %.0f); saved place %s; on screen %s"):format(x0, y0, l0, x1, y1, x2, y2, l2, tostring(ctx.W.db.pos), tostring(onScreen2)))
			end
		end,
	}

	Hunt.promise{
		id = "settings.public_buyers_asks", area = "Settings", gap = "the fake game's popups have no buttons: Cancel is answered through the dialog's OnCancel",
		text = "Turning on Invite public chat riders asks you first, and the switch stays off if you say no.",
		source = "Settings > Driving (BRIEF19 R4; \"it asks first\" in the tooltip)", kind = "scenario",
		needs = { role = "warlock" },
		when = function(sit) return is(sit, "combat", "no") and sit.opt_autoPublic ~= "on" end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			local st = openSettings(ctx, "driving")
			local t = st.controls["drive.autoPublic"]
			if not (t and ctx:visible(t)) then ctx:cannot("the switch is not on screen") end
			if t.get() == true then ctx:na("already on") end
			press(ctx, t)
			ctx:advance(0.6)
			ctx:note("click Invite public chat riders")
			if t.get() == true then
				ctx:fail("You turn on Invite public chat riders and it is on at once, without asking.")
			end
			local find = ctx.me.env.StaticPopup_FindVisible
			local D = ctx.W.Drive
			local asked = type(find) == "function" and D and D.PUBLIC_POPUP and find(D.PUBLIC_POPUP)
			if not asked then
				ctx:fail("You turn on Invite public chat riders and no question comes up.", onScreen(ctx))
			end
			-- the fake game's popups have no buttons: the player's Cancel is the dialog's own OnCancel, then the popup hides
			local dlg = ctx.me.env.StaticPopupDialogs and ctx.me.env.StaticPopupDialogs[D.PUBLIC_POPUP]
			if not (dlg and type(dlg.OnCancel) == "function") then ctx:cannot("the warning has no Cancel answer") end
			pcall(dlg.OnCancel)
			if type(ctx.me.env.StaticPopup_Hide) == "function" then ctx.me.env.StaticPopup_Hide(D.PUBLIC_POPUP) end
			ctx:advance(0.8)
			ctx:note("answer No")
			if t.get() == true or face(t) then
				ctx:fail("You turn on Invite public chat riders, answer No, and the switch is on.")
			end
		end,
	}
	Hunt.promise{
		id = "settings.minimap_switch_hides_button", area = "Settings",
		text = "Turning the Minimap button switch off hides the Wuber button by the minimap, and on shows it again.",
		source = "tooltip (Minimap button: \"Shows the Wuber button by the minimap\")", kind = "scenario",
		check = function(ctx)
			local st = openSettings(ctx, "map")
			local t = st.controls.minimap
			if not t then ctx:cannot("no Minimap button switch") end
			local b = ctx.me.env.WuberMinimapButton
			if not b then ctx:cannot("this game has no Wuber minimap button") end
			if t.get() ~= true then press(ctx, t) ctx:advance(0.6) end -- make sure it starts on
			ctx:advance(0.5)
			if not ctx:visible(b) then ctx:fail("The Minimap button switch says on and the Wuber button by the minimap is not there.") end
			press(ctx, t)
			ctx:advance(0.6)
			ctx:note("click Minimap button (off)")
			if ctx:visible(b) then ctx:fail("You turn the Minimap button switch off and the Wuber button is still by the minimap.") end
			press(ctx, t)
			ctx:advance(0.6)
			ctx:note("click Minimap button (on)")
			if not ctx:visible(b) then ctx:fail("You turn the Minimap button switch back on and the Wuber button does not come back.") end
		end,
	}

	Hunt.promise{
		id = "settings.sound_switch_silences", area = "Settings",
		text = "With the Sounds switch off Wuber plays no sound when you click, and with it on a click plays one.",
		source = "tooltip (Sounds: \"Plays a sound when a driver accepts, when the summon is up, and on milestones\"; Settings > Sound)", kind = "scenario",
		check = function(ctx)
			local st = openSettings(ctx, "sound")
			local snd, other = st.controls.sound, st.controls.tips
			if not (snd and other) then ctx:cannot("no Sounds / Login tips switch") end
			if snd.get() ~= true then press(ctx, snd) ctx:advance(0.6) end
			openSettings(ctx, "riding")
			local n0 = #ctx.me.sounds
			press(ctx, other) ctx:advance(0.6) press(ctx, other) ctx:advance(0.6)
			ctx:note("click Login tips twice with Sounds on")
			if #ctx.me.sounds == n0 then ctx:fail("With Sounds on you click a switch in Settings and no sound plays.") end
			openSettings(ctx, "sound")
			press(ctx, snd) ctx:advance(0.6)
			ctx:note("click Sounds (off)")
			openSettings(ctx, "riding")
			local n1 = #ctx.me.sounds
			press(ctx, other) ctx:advance(0.6) press(ctx, other) ctx:advance(0.6)
			ctx:note("click Login tips twice with Sounds off")
			if #ctx.me.sounds ~= n1 then
				ctx:fail("You turn Sounds off and clicking a switch in Settings still plays a sound.", tostring(ctx.me.sounds[#ctx.me.sounds]))
			end
		end,
	}

	-- the typed words that change a switch (older words still work, quietly; Help does not list them, but they work)
	local TYPED = {
		{ line = "/wuber minimap", key = "minimap", what = "the Minimap button" },
		{ line = "/wuber map", key = "mapPins", what = "Drivers on the world map" },
	}
	Hunt.promise{
		id = "settings.typed_words_move_switch", area = "Settings",
		text = "When you type /wuber minimap or /wuber map while Settings is open, the matching switch in Settings changes with it.",
		source = "inferred (Commands.lua: the words change the same setting the switch shows)", kind = "scenario",
		check = function(ctx)
			local st = openSettings(ctx, "map")
			for _, c in ipairs(TYPED) do
				local t = st.controls[c.key]
				if not t then ctx:cannot("no " .. c.key .. " switch") end
				local before = val(t)
				ctx.me:slash(c.line)
				ctx:advance(0.6)
				ctx:note(c.line)
				if val(t) == before then ctx:fail(("You type %s and the setting does not change."):format(c.line)) end
				if face(t) ~= val(t) then
					ctx:fail(("You type %s with Settings open and the %s switch still looks %s while it is %s."):format(c.line, c.what, face(t) and "on" or "off", val(t) and "on" or "off"))
				end
			end
		end,
	}

	Hunt.promise{
		id = "settings.replay_tips", area = "Settings",
		text = "Replay tips shows the first-open tips again from the first one.",
		source = "tooltip (Replay tips: \"Shows the first-open tips again, from the first\")", kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") and is(sit, "ride", "none") end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			local st = openSettings(ctx, "window")
			local b = st.controls.coach
			if not b then ctx:cannot("no Replay tips button") end
			press(ctx, b)
			ctx:advance(2.5)
			ctx:note("click Replay tips")
			local seen = false
			for _, t in ipairs(ctx:texts()) do if t == "Where to?" then seen = true end end
			if not seen then ctx:fail("You press Replay tips in Settings and the first tip (Where to?) does not show.", onScreen(ctx)) end
		end,
	}
end

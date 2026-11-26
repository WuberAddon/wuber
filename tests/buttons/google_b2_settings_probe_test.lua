-- Tests: every setting control in Settings (Rows.lua / Panel.lua) is probed:
-- saved in saved variables, shown on screen, kept over a /reload, and restored;
-- plus a gate that fails if a setting control has no probe row (or a probe row's control is gone).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local Lib = assert(loadfile(T.dir .. "/buttons/lib.lua"))(T)

-- Every control in UI.settings.controls (plus st.badges).
-- Controls that send to other players, need a second account, or are action/reset buttons have skip = "<why>".
local PROBES = {
	-- Riding (Simple)
	{ key = "tips", sec = "riding", adv = false, kind = "toggle",
		get = function(W) return W.db.tipsOn ~= false end },
	{ key = "flightOffers", sec = "riding", adv = false, kind = "toggle",
		get = function(W) return W.db.birdTip ~= false and W.db.flightOffers ~= false end },
	{ key = "coach", sec = "riding", adv = false,
		skip = "action button: starts coach tip replay, no saved setting" },
	{ key = "hidden", sec = "riding", adv = false,
		skip = "action button: clears hidden drivers list; only active when drivers are hidden" },

	-- Riding (Advanced)
	{ key = "autoAccept", sec = "riding", adv = true, kind = "toggle",
		get = function(W) return W.db.autoAccept ~= false end },
	{ key = "autoLeave", sec = "riding", adv = true, kind = "toggle",
		get = function(W) return W.db.autoLeave ~= false end },
	{ key = "timeValue", sec = "riding", adv = true, kind = "slider", alt = 250000,
		get = function(W) return W.db.timeValue or 100000 end,
		shown = function(ctl) return ctl.value end,
		label = function(ctl) return ctl.label:GetText() end },

	-- Driving (Simple)
	{ key = "drive.autoInvite", sec = "driving", adv = false, kind = "toggle",
		get = function(W) return W.Drive.opts().autoInvite == true end },
	{ key = "advertOnline", sec = "driving", adv = false, kind = "toggle",
		get = function(W) return W.db.advertOnline ~= false end },
	{ key = "badges", sec = "driving", adv = false, kind = "badges",
		get = function(W) local ch = W.Char(); return ch and ch.badge or "" end },
	{ key = "drive.key", sec = "driving", adv = false, kind = "key",
		get = function(W) local b = W.db.drive and W.db.drive.button; return b and b.key or nil end },

	-- Driving (Advanced)
	{ key = "drive.autoPublic", sec = "driving", adv = true, kind = "toggle", confirm = "Yes",
		get = function(W) return W.Drive.opts().autoPublic == true end },
	{ key = "starter", sec = "driving", adv = true, kind = "toggle",
		get = function(W) local ch = W.Char(); return ch and ch.starter ~= false end },
	{ key = "groupFinder", sec = "driving", adv = true, kind = "toggle",
		get = function(W) return W.db.groupFinder == true end },
	{ key = "drive.maxGroup", sec = "driving", adv = true, kind = "slider", alt = 10,
		get = function(W)
			local o = W.Drive.opts()
			if o.oneAtATime == true then return 1 end
			local v = tonumber(o.maxGroup) or 0
			return v < 3 and 2 or math.min(40, math.floor(v))
		end,
		shown = function(ctl) return ctl.value end,
		label = function(ctl) return ctl.label:GetText() end },
	{ key = "drive.autoReply", sec = "driving", adv = true, kind = "toggle",
		get = function(W) return W.Drive.opts().autoReply == true end },
	{ key = "drive.watchChannels", sec = "driving", adv = true, kind = "field", alt = "trade world",
		get = function(W)
			local v = W.Drive.opts().watchChannels
			return type(v) == "table" and table.concat(v, " ") or tostring(v or "")
		end },
	{ key = "drive.adChannels", sec = "driving", adv = true, kind = "field", alt = "services trade",
		get = function(W)
			local v = W.Drive.opts().adChannels
			return type(v) == "table" and table.concat(v, " ") or tostring(v or "")
		end },
	{ key = "drive.keywords", sec = "driving", adv = true, kind = "field", alt = "summon taxi",
		get = function(W)
			local v = W.Drive.opts().keywords
			return type(v) == "table" and table.concat(v, " ") or tostring(v or "")
		end },
	{ key = "drive.whisperMode", sec = "driving", adv = true, kind = "segmented", alt = "box",
		get = function(W) return W.Drive.opts().whisperMode or "auto" end },
	{ key = "drive.acceptUnder", sec = "driving", adv = true, kind = "toggle",
		get = function(W) return W.Drive.opts().acceptUnder == true end },
	{ key = "drive.kickAfter", sec = "driving", adv = true, kind = "toggle",
		get = function(W) return W.Drive.opts().kickAfter == true end },
	{ key = "drive.leavers", sec = "driving", adv = true, kind = "segmented", alt = "off",
		get = function(W)
			local o = W.Drive.opts()
			if o.autoBlock ~= true then return "off" end
			return o.tellBlocked == true and "tell" or "quiet"
		end },
	{ key = "drive.lowShards", sec = "driving", adv = true, kind = "slider", alt = 6,
		get = function(W) return W.Drive.opts().lowShards or 3 end,
		shown = function(ctl) return ctl.value end,
		label = function(ctl) return ctl.label:GetText() end },
	{ key = "drive.ritual", sec = "driving", adv = true, kind = "field", alt = "Ritual of Summoning",
		get = function(W) return tostring(W.Drive.opts().ritual or "") end },
	{ key = "drive.adEvery", sec = "driving", adv = true, kind = "slider", alt = 30,
		get = function(W) return W.Drive.opts().adEvery or 15 end,
		shown = function(ctl) return ctl.value end,
		label = function(ctl) return ctl.label:GetText() end },
	{ key = "drive.scale", sec = "driving", adv = true, kind = "slider", alt = 1.5, tol = 0.01,
		get = function(W) return W.Drive.Scale() end,
		shown = function(ctl) return ctl.value end,
		label = function(ctl) return ctl.label:GetText() end },
	{ key = "drive.fit", sec = "driving", adv = true,
		skip = "action button: resets Big button size to Fit" },
	{ key = "drive.locked", sec = "driving", adv = true, kind = "toggle",
		get = function(W) return W.db.drive.button.locked == true end },
	{ key = "drive.resetPos", sec = "driving", adv = true,
		skip = "action button: resets Big button position" },
	{ key = "drive.onScreen", sec = "driving", adv = true, kind = "segmented", alt = "always",
		get = function(W)
			local b = W.db.drive.button
			if b.shown == false then return "wuber" end
			return b.keepClosed == true and "always" or "waiting"
		end },
	{ key = "drive.bell", sec = "driving", adv = true,
		skip = "needs a second account: BellSet sends hello to the alert character" },
	{ key = "drive.bellTest", sec = "driving", adv = true,
		skip = "needs a second account: BellTest sends a test alert to the alert character" },
	{ key = "drive.bellForget", sec = "driving", adv = true,
		skip = "needs a second account: clears alert character's learned drivers" },
	{ key = "drive.alertWindow", sec = "driving", adv = true, kind = "toggle",
		get = function(W) return W.Drive.AlertWindow() == true end },
	{ key = "drive.showPass", sec = "driving", adv = true, kind = "toggle",
		get = function(W) return W.Drive.opts().showPass == true end },

	-- Map (Simple + Pioneer Advanced)
	{ key = "mapPins", sec = "map", adv = false, kind = "toggle",
		get = function(W) return W.db.mapPins ~= false end },
	{ key = "minimap", sec = "map", adv = false, kind = "toggle",
		get = function(W) return not W.db.minimapHidden end },
	{ key = "myEmblem", sec = "map", adv = true, optional = true,
		skip = "Pioneer-only: only built when W.Emblem.Mine() is true" },

	-- Sound and effects (Simple)
	{ key = "sound", sec = "sound", adv = false, kind = "toggle",
		get = function(W) return W.db.sound ~= false end },
	{ key = "fx", sec = "sound", adv = false, kind = "segmented", alt = "light",
		get = function(W) return W.db.fx or "full" end },
	{ key = "reduceMotion", sec = "sound", adv = false, kind = "toggle",
		get = function(W) return W.db.reduceMotion == true end },
	{ key = "plates", sec = "sound", adv = false, kind = "toggle",
		get = function(W) return W.db.plates ~= false and W.db.emblems ~= false end },
	{ key = "nameplates", sec = "sound", adv = false,
		skip = "game CVar button: turns on WoW friendly nameplates CVar, not a Wuber saved setting" },

	-- This window (Simple)
	{ key = "advanced", sec = "window", adv = false, kind = "toggle",
		get = function(W) return W.Advanced() == true end },
	{ key = "scale", sec = "window", adv = false, kind = "slider", alt = 1.25, tol = 0.01,
		get = function(W) return W.db.scale or 1 end,
		shown = function(ctl) return ctl.value end,
		label = function(ctl) return ctl.label:GetText() end },
	{ key = "resetPos", sec = "window", adv = false,
		skip = "action button: resets window position and size" },
	{ key = "check", sec = "window", adv = false,
		skip = "action button: runs Check my game diagnostics, no saved setting" },

	-- This window (Advanced)
	{ key = "foldWide", sec = "window", adv = true, kind = "segmented", alt = "narrow",
		get = function(W)
			return (type(W.db.fold) == "table" and W.db.fold.narrow == true) and "narrow" or "auto"
		end },
	{ key = "foldReset", sec = "window", adv = true,
		skip = "action button: resets per-page wide/narrow choices" },
}

local function openSection(ctx, sec, adv)
	local W = ctx.W
	if adv ~= nil then W.SetAdvanced(adv and true or false) end
	if not W.UI.state or not W.UI.state.win or not W.UI.state.win:IsShown() then
		W.UI.Toggle(true)
		ctx.w:advance(1)
	end
	W.UI.OpenSettings(sec)
	ctx.w:advance(1)
	return W.UI.settings
end

local function closeOpenPopup(c, W)
	local which = W.Drive and W.Drive.PUBLIC_POPUP
	if which and c.popups and c.popups[which] then
		local dlg = c.env.StaticPopupDialogs and c.env.StaticPopupDialogs[which]
		c.popups[which] = nil
		if dlg and dlg.OnAccept then dlg.OnAccept() end
		return true
	end
	return false
end

local function closeTo(a, b, tol)
	if tol then return math.abs((tonumber(a) or 0) - (tonumber(b) or 0)) <= tol end
	return a == b
end

local function probeOne(p)
	local ctx = Lib.newWorld()
	local w, c, W = ctx.w, ctx.c, ctx.W
	local st = openSection(ctx, p.sec, p.adv)
	local saved0 = p.get(W)

	local function getCtl(s)
		if p.kind == "badges" then return s.badges and s.badges[1] end
		return s.controls[p.key]
	end

	local ctl = getCtl(st)
	ok(ctl ~= nil, p.key .. ": control exists on " .. p.sec .. " (adv=" .. tostring(p.adv) .. ")")

	if p.kind == "toggle" then
		c:scrollIntoView(ctl)
		local beforeOn = ctl.on
		eq(beforeOn, saved0, p.key .. ": initial shown state matches saved")
		c:clickOn(ctl)
		w:advance(0.6)
		if p.confirm then
			ok(closeOpenPopup(c, W), p.key .. ": confirmation popup appeared and Yes was clicked")
			w:advance(0.6)
		end
		local saved1 = p.get(W)
		eq(saved1, not saved0, p.key .. ": (a) saved value changed")
		eq(ctl.on, saved1, p.key .. ": (b) row on screen shows new state")

		c = w:reload(c)
		ctx.c, ctx.W = c, c.W
		W = c.W
		local advArg = p.adv
		if p.key == "advanced" then advArg = nil end
		st = openSection(ctx, p.sec, advArg)
		ctl = getCtl(st)
		eq(p.get(W), saved1, p.key .. ": (c) saved value kept after reload")
		eq(ctl.on, saved1, p.key .. ": (c) shown state kept after reload")

		c:scrollIntoView(ctl)
		c:clickOn(ctl)
		w:advance(0.6)
		if p.confirm and p.get(W) ~= saved0 then closeOpenPopup(c, W) w:advance(0.6) end
		eq(p.get(W), saved0, p.key .. ": (d) saved value restored")
		eq(ctl.on, saved0, p.key .. ": (d) shown state restored")

	elseif p.kind == "slider" then
		c:scrollIntoView(ctl)
		ok(closeTo(p.shown(ctl), saved0, p.tol), p.key .. ": initial shown value matches saved")
		c:clickOn(ctl)
		ctl:SetValue(p.alt)
		w:advance(0.6)
		local saved1 = p.get(W)
		ok(closeTo(saved1, p.alt, p.tol), p.key .. ": (a) saved value changed to " .. tostring(p.alt) .. " (got " .. tostring(saved1) .. ")")
		ok(closeTo(p.shown(ctl), p.alt, p.tol), p.key .. ": (b) slider shows new value")

		c = w:reload(c)
		ctx.c, ctx.W = c, c.W
		W = c.W
		st = openSection(ctx, p.sec, p.adv)
		ctl = getCtl(st)
		ok(closeTo(p.get(W), p.alt, p.tol), p.key .. ": (c) saved value kept after reload")
		ok(closeTo(p.shown(ctl), p.alt, p.tol), p.key .. ": (c) shown value kept after reload")

		c:scrollIntoView(ctl)
		c:clickOn(ctl)
		ctl:SetValue(saved0)
		w:advance(0.6)
		ok(closeTo(p.get(W), saved0, p.tol), p.key .. ": (d) saved value restored")
		ok(closeTo(p.shown(ctl), saved0, p.tol), p.key .. ": (d) shown value restored")

	elseif p.kind == "field" then
		c:scrollIntoView(ctl.edit)
		eq(ctl:Text(), saved0, p.key .. ": initial field text matches saved")
		c:clickOn(ctl.edit)
		ctl.edit:SetFocus()
		ctl.edit:SetText(p.alt)
		ctl.edit:ClearFocus()
		w:advance(0.3)
		local saved1 = p.get(W)
		eq(saved1, p.alt, p.key .. ": (a) saved value changed")
		eq(ctl:Text(), p.alt, p.key .. ": (b) field shows new text")

		c = w:reload(c)
		ctx.c, ctx.W = c, c.W
		W = c.W
		st = openSection(ctx, p.sec, p.adv)
		ctl = getCtl(st)
		eq(p.get(W), p.alt, p.key .. ": (c) saved value kept after reload")
		eq(ctl:Text(), p.alt, p.key .. ": (c) field text kept after reload")

		c:scrollIntoView(ctl.edit)
		c:clickOn(ctl.edit)
		ctl.edit:SetFocus()
		ctl.edit:SetText(saved0)
		ctl.edit:ClearFocus()
		w:advance(0.3)
		eq(p.get(W), saved0, p.key .. ": (d) saved value restored")
		eq(ctl:Text(), saved0, p.key .. ": (d) field text restored")

	elseif p.kind == "segmented" then
		local origBtn, altBtn
		for _, b in ipairs(ctl.buttons) do
			if b.value == saved0 then origBtn = b end
			if b.value == p.alt then altBtn = b end
		end
		ok(origBtn and altBtn, p.key .. ": found original and alt segment buttons")
		eq(ctl.value, saved0, p.key .. ": initial segmented value matches saved")
		c:scrollIntoView(altBtn)
		c:clickOn(altBtn)
		w:advance(0.3)
		eq(p.get(W), p.alt, p.key .. ": (a) saved value changed")
		eq(ctl.value, p.alt, p.key .. ": (b) segmented shows new value")
		ok(altBtn.chosen and altBtn.chosen.parts and altBtn.chosen.parts[1]:IsShown(), p.key .. ": (b) new segment is lit")

		c = w:reload(c)
		ctx.c, ctx.W = c, c.W
		W = c.W
		st = openSection(ctx, p.sec, p.adv)
		ctl = getCtl(st)
		eq(p.get(W), p.alt, p.key .. ": (c) saved value kept after reload")
		eq(ctl.value, p.alt, p.key .. ": (c) segmented value kept after reload")

		local restoreBtn
		for _, b in ipairs(ctl.buttons) do if b.value == saved0 then restoreBtn = b end end
		c:scrollIntoView(restoreBtn)
		c:clickOn(restoreBtn)
		w:advance(0.3)
		eq(p.get(W), saved0, p.key .. ": (d) saved value restored")
		eq(ctl.value, saved0, p.key .. ": (d) segmented value restored")

	elseif p.kind == "badges" then
		local origBtn, altBtn
		for _, b in ipairs(st.badges) do
			if b.chosen then origBtn = b end
			if not b.chosen and not b.founder and b.id ~= "" and not altBtn then altBtn = b end
		end
		ok(origBtn and altBtn, "badges: found original and alt badge buttons")
		c:scrollIntoView(altBtn)
		c:clickOn(altBtn)
		w:advance(0.4)
		eq(p.get(W), altBtn.id, "badges: (a) saved badge changed")
		ok(altBtn.ring:IsShown(), "badges: (b) picked badge ring is shown")
		eq(st.badgeName:GetText(), altBtn.badgeName, "badges: (b) badge name updated")

		c = w:reload(c)
		ctx.c, ctx.W = c, c.W
		W = c.W
		st = openSection(ctx, p.sec, p.adv)
		eq(p.get(W), altBtn.id, "badges: (c) saved badge kept after reload")
		local reloadedAlt
		for _, b in ipairs(st.badges) do if b.id == altBtn.id then reloadedAlt = b end end
		ok(reloadedAlt and reloadedAlt.ring:IsShown(), "badges: (c) badge ring kept after reload")

		local restoreBtn
		for _, b in ipairs(st.badges) do if b.id == origBtn.id then restoreBtn = b end end
		c:scrollIntoView(restoreBtn)
		c:clickOn(restoreBtn)
		w:advance(0.4)
		eq(p.get(W), origBtn.founder and "" or origBtn.id, "badges: (d) saved badge restored")

	elseif p.kind == "key" then
		c:scrollIntoView(ctl)
		eq(st.keyRow.desc:GetText(), "None set", "drive.key: initial desc is None set")
		c:clickOn(ctl)
		ok(st.capturing == true, "drive.key: Set button starts key capture")
		-- Find the capture frame (child of st.keyRow with OnKeyDown)
		local cap
		for _, ch in ipairs({ st.keyRow:GetChildren() }) do
			if ch:GetScript("OnKeyDown") then cap = ch break end
		end
		ok(cap ~= nil, "drive.key: capture frame found")
		cap:GetScript("OnKeyDown")(cap, "F9")
		w:advance(0.3)
		eq(p.get(W), "F9", "drive.key: (a) saved key changed to F9")
		eq(st.keyRow.desc:GetText(), "On F9", "drive.key: (b) row desc shows On F9")

		c = w:reload(c)
		ctx.c, ctx.W = c, c.W
		W = c.W
		st = openSection(ctx, p.sec, p.adv)
		eq(p.get(W), "F9", "drive.key: (c) saved key kept after reload")
		eq(st.keyRow.desc:GetText(), "On F9", "drive.key: (c) row desc kept after reload")

		local clearBtn
		for _, ch in ipairs({ st.keyRow:GetChildren() }) do
			if ch.label and ch.label.GetText and ch.label:GetText() == "Clear" then clearBtn = ch break end
		end
		ok(clearBtn ~= nil, "drive.key: Clear button found")
		c:scrollIntoView(clearBtn)
		c:clickOn(clearBtn)
		w:advance(0.3)
		eq(p.get(W), nil, "drive.key: (d) saved key cleared")
		eq(st.keyRow.desc:GetText(), "None set", "drive.key: (d) row desc restored to None set")
	end

	eq(#w.errors, 0, p.key .. ": no Lua errors (" .. table.concat(w.errors, "; ") .. ")")
end

for _, p in ipairs(PROBES) do
	if not p.skip then
		test("settings probe: " .. p.key .. " (saved, shown, reload, restore)", function()
			probeOne(p)
		end)
	end
end

test("settings probe gate: every built setting control has a probe row and every probe row has its control", function()
	local ctx = Lib.newWorld()
	openSection(ctx, "riding", true)
	local st = ctx.W.UI.settings
	local byKey = {}
	for _, p in ipairs(PROBES) do byKey[p.key] = p end

	local missing, stale = {}, {}
	for k in pairs(st.controls) do
		if not byKey[k] then missing[#missing + 1] = k end
	end
	if #(st.badges or {}) > 0 and not byKey.badges then
		missing[#missing + 1] = "badges"
	end
	for _, p in ipairs(PROBES) do
		if not p.optional then
			if p.key == "badges" then
				if #(st.badges or {}) == 0 then stale[#stale + 1] = p.key end
			elseif not st.controls[p.key] then
				stale[#stale + 1] = p.key
			end
		end
	end
	table.sort(missing)
	table.sort(stale)
	ok(#missing == 0, #missing .. " setting control(s) with no probe row: " .. table.concat(missing, ", "))
	ok(#stale == 0, #stale .. " probe row(s) whose control is gone: " .. table.concat(stale, ", "))

	-- Also verify the buttons walk on settings groups produces zero Lua errors across Simple and Advanced
	for _, g in ipairs({ "settings1", "settings2", "settings3" }) do
		for _, s in ipairs(Lib.screens(ctx)) do
			if Lib.groupOf(s.id) == g then
				Lib.show(ctx, s)
			end
		end
	end
	eq(#ctx.w.errors, 0, "no Lua errors during walk")
end)

-- Promises the lead of the 2.4.1 bug hunt (job 2680) wrote from judged long-session findings.
return function(Hunt)
	local function press(ctx, obj)
		if not pcall(ctx.me.clickOn, ctx.me, obj) then ctx.me:click(obj) end
	end

	-- (job 2680, deep22 F030) Check my game lists the driver's readiness lines on one line each (Rows.lua runCheck
	-- extra lines, INNER - 52 wide); a Warlock in a group someone else leads gets the longest one
	Hunt.promise{
		id = "v241.lead.check_lines_whole",
		area = "Settings",
		text = "Check my game, in a group someone else leads: the line that says who leads the group is shown whole, never cut with dots.",
		source = "Ready.lua:271 (\"<name> leads the group: only the leader can invite. Ask <name> to make you leader.\"); Settings, Check my game",
		kind = "scenario",
		needs = { role = "warlock", group = "solo", ride = "none", phone = "closed" },
		check = function(ctx)
			local W = ctx.W
			local lead = ctx.w:addBot("Danfield", { spot = "Orgrimmar", class = "MAGE" })
			ctx.w:group({ lead.name, ctx.me.player.name })
			ctx:advance(2)
			ctx:note("join a party Danfield leads")
			if W.Drive and W.Drive.IsLeader and W.Drive.IsLeader() then ctx:na("the fake group made me the leader") end
			ctx.me:slash("/wuber help")
			ctx:advance(2.4)
			local st = W.UI and W.UI.settings
			if not (st and st.controls) then ctx:cannot("/wuber help did not open Settings") end
			if W.UI.OpenSettings then W.UI.OpenSettings("window") ctx:advance(1) end
			local b = st.controls.check
			if not b then ctx:cannot("no Check my game button") end
			press(ctx, b)
			ctx:advance(1.5)
			ctx:note("click Check my game")
			local found
			for _, l in ipairs((st.results and st.results.lines) or {}) do
				if ctx:visible(l) and l.text then
					local t = tostring(l.text:GetText() or "")
					if t:find("leads the group", 1, true) then
						found = true
						local w, sw = l.text:GetWidth(), l.text:GetStringWidth()
						local cut = (l.text.IsTruncated and l.text:IsTruncated()) or (w and sw and sw > w + 1)
						if cut then
							ctx:fail("You press Check my game in a group Danfield leads and the line about who leads is cut short.", t .. " (" .. tostring(sw) .. " wide in " .. tostring(w) .. ")")
						end
					end
				end
			end
			if not found then ctx:na("Check my game shows no line about who leads the group") end
		end,
	}
end

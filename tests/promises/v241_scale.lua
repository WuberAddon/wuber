-- Promises about the big button's size command in 2.4.1 (AU24-22, "scale range check"; Drive/Commands.lua C.scale, Drive/Button.lua DR.Scale).
-- /wuber drive scale <n>: 0.5 to 3, or 50 to 300 percent (a number of 10 or more is a percent), or auto; anything else changes nothing and says so.
return function(Hunt)
	local function canDrive(sit) return sit.saved == nil or sit.saved == "fresh" end
	local function pct(ctx) return math.floor(ctx.W.Drive.Scale() * 100 + 0.5) end
	local function listen(ctx)
		local out = {}
		local old = ctx.W.Print
		ctx.W.Print = function(t, ...) out[#out + 1] = tostring(t) if old then return old(t, ...) end end
		return out
	end
	local function setup(ctx)
		if not (ctx.W.Drive and ctx.W.Drive.SetScale and ctx.W.Drive.Command) then ctx:cannot("no Drive scale") end
		if ctx.me.player.combat then ctx:na("in combat") end
	end
	local function type_(ctx, arg)
		ctx.me:slash("/wuber drive scale " .. arg)
		ctx:note("/wuber drive scale " .. arg)
		ctx:advance(0.5)
	end
	local function promise(p)
		p.area = "Big button size"
		p.kind = "scenario"
		p.needs = p.needs or { role = "warlock" }
		p.when = p.when or canDrive
		Hunt.promise(p)
	end

	promise{
		id = "v241.scale.percent_typed",
		text = "You type /wuber drive scale 80 and the big button becomes 80 percent, and Wuber says 80%.",
		source = "AU24-22 (a number of 10 or more is a percent)",
		check = function(ctx)
			setup(ctx)
			local out = listen(ctx)
			type_(ctx, "150")
			type_(ctx, "80")
			if pct(ctx) ~= 80 then ctx:fail("You type /wuber drive scale 80 and the big button is at " .. pct(ctx) .. " percent, not 80.", table.concat(out, " | ")) end
			if not table.concat(out, " "):find("80%", 1, true) then ctx:fail("You type /wuber drive scale 80 and Wuber never says 80%.", table.concat(out, " | ")) end
		end,
	}

	promise{
		id = "v241.scale.too_big_refused",
		text = "You type a size above the biggest (3.5, 4, 5, 400, 301): the big button keeps its size and Wuber says the allowed range.",
		source = "AU24-22 (scale range check)",
		check = function(ctx)
			setup(ctx)
			for _, arg in ipairs({ "3.5", "4", "5", "400", "301" }) do
				type_(ctx, "150")
				local out = listen(ctx)
				type_(ctx, arg)
				if pct(ctx) ~= 150 then ctx:fail("The big button is at 150 percent, you type /wuber drive scale " .. arg .. " and it becomes " .. pct(ctx) .. " percent.", table.concat(out, " | ")) end
				local say = table.concat(out, " ")
				if not (say:find("300", 1, true) or say:find("3", 1, true)) then ctx:fail("You type /wuber drive scale " .. arg .. " and Wuber does not say what sizes are allowed.", say) end
			end
		end,
	}

	promise{
		id = "v241.scale.too_small_refused",
		text = "You type a size below the smallest (0.3, 0.1, 10, 49, 0, -2): the big button keeps its size and Wuber says so; it never shrinks to a sliver.",
		source = "AU24-22 (scale range check)",
		check = function(ctx)
			setup(ctx)
			for _, arg in ipairs({ "0.3", "0.1", "10", "49", "0", "-2" }) do
				type_(ctx, "150")
				local out = listen(ctx)
				type_(ctx, arg)
				if pct(ctx) ~= 150 then ctx:fail("The big button is at 150 percent, you type /wuber drive scale " .. arg .. " and it becomes " .. pct(ctx) .. " percent.", table.concat(out, " | ")) end
				if #out == 0 then ctx:fail("You type /wuber drive scale " .. arg .. " and Wuber says nothing.") end
			end
		end,
	}

	promise{
		id = "v241.scale.edges_accepted",
		text = "The ends of the range work: 0.5 and 50 give 50 percent, 3 and 300 give 300 percent.",
		source = "AU24-22 (range is 0.5 to 3 or 50 to 300 percent)",
		check = function(ctx)
			setup(ctx)
			local want = { ["0.5"] = 50, ["50"] = 50, ["3"] = 300, ["300"] = 300 }
			for _, arg in ipairs({ "0.5", "50", "3", "300" }) do
				type_(ctx, "100")
				type_(ctx, arg)
				if pct(ctx) ~= want[arg] then ctx:fail("You type /wuber drive scale " .. arg .. " and the big button is at " .. pct(ctx) .. " percent, not " .. want[arg] .. ".") end
			end
		end,
	}

	promise{
		id = "v241.scale.survives_reload",
		text = "A size you typed (/wuber drive scale 120) is still the size after /reload, and the answer you get when you type /wuber drive scale alone says the same percent.",
		source = "AU24-22 (the stored size and the words agree)",
		needs = { role = "warlock", session = "login" },
		check = function(ctx)
			setup(ctx)
			type_(ctx, "120")
			ctx:reload()
			setup(ctx)
			local out = listen(ctx)
			if pct(ctx) ~= 120 then ctx:fail("You typed /wuber drive scale 120, reloaded, and the big button is at " .. pct(ctx) .. " percent.") end
			type_(ctx, "")
			if not table.concat(out, " "):find("120%", 1, true) then ctx:fail("After a reload /wuber drive scale says a different percent than 120.", table.concat(out, " | ")) end
		end,
	}

	promise{
		id = "v241.scale.auto_guard",
		text = "After you chose a size, /wuber drive scale auto gives the size that fits the window again, and Wuber says that percent.",
		source = "neighbouring path of AU24-22",
		check = function(ctx)
			setup(ctx)
			type_(ctx, "250")
			local out = listen(ctx)
			type_(ctx, "auto")
			local say = table.concat(out, " ")
			if not say:find(pct(ctx) .. "%", 1, true) then ctx:fail("You type /wuber drive scale auto and Wuber's answer does not match the button's " .. pct(ctx) .. " percent.", say) end
			if pct(ctx) == 250 then ctx:fail("You type /wuber drive scale auto and the button stays at 250 percent.") end
		end,
	}
end

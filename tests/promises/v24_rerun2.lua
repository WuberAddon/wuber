-- Promises, rerun 2 (tests/promises/v24_rerun2.lua; job 097). Every id starts with "rerun2.".
return function(Hunt)
	local U = dofile("tests/hunt/lib/universal_util.lua")
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

	local function openWin(ctx)
		local f = ctx.me.env.WuberFrame
		if not (f and f:IsShown()) then ctx.W.UI.Toggle(true) end
		ctx:advance(1)
		f = ctx.me.env.WuberFrame
		if not (f and f:IsShown()) then ctx:cannot("the window would not open") end
	end
	-- the visible font string whose text is exactly the words; the measure is the layout check's own (H.truncation)
	local function findWords(ctx, words)
		local list = U.shown(ctx.me, { "FontString" })
		for _, o in ipairs(list) do
			local ok, t = pcall(function() return o:GetText() end)
			if ok and t == words then return o end
		end
	end
	local function judge(ctx, words, seen)
		local o = findWords(ctx, words)
		if not o then ctx:fail("The new-title card shows no button reading " .. words .. ".") end
		local cut = ctx.H.truncation(o)
		if cut then
			ctx:fail(seen, ("needs %.0f px, has %.0f"):format(cut.need or 0, cut.room or 0))
		end
	end

	local function setup(ctx)
		local n = ctx.W.Drive.RankCount()
		if n ~= 10 then ctx:na("the count did not reach 10 here (" .. n .. ")") end
		ctx:advance(2)
	end

	local function pre(ctx)
		ctx.clientOpts.simple = true
		local s = ctx.saved
		if type(s) ~= "table" then s = {} ctx.saved = s end
		s.Wuber = s.Wuber or {}
		s.Wuber.chars = s.Wuber.chars or {}
		local k = key(ctx.name)
		s.Wuber.chars[k] = s.Wuber.chars[k] or {}
		s.Wuber.chars[k].rank = { n = 9, seen = {} }
	end

	Hunt.promise{
		id = "rerun2.title_share_fits_in_combat",
		area = "Titles",
		kind = "scenario",
		text = "In a fight, the New title card's button says Share after combat in full.",
		source = "UI/Share.lua header (Share after combat in combat); CHANGELOG 2.4.0 (new-title card, Tell the guild)",
		needs = { role = "warlock", ride = "arrived", session = "login", combat = "no" },
		when = function(sit) return sit.fold ~= "folded_click" end,
		pre = pre,
		check = function(ctx)
			setup(ctx)
			openWin(ctx)
			ctx:advance(2)
			if not U.shown or not ctx.H.truncation then ctx:cannot("no truncation measure") end
			-- out of combat first: the plain words are whole
			if ctx.me.player.combat then ctx:na("already in combat") end
			judge(ctx, "Tell the guild", "The New title card's Tell the guild button is cut off.")
			ctx.w:enterCombat(ctx.me)
			ctx:advance(2)
			judge(ctx, "Share after combat", "In a fight the New title card's button reads Share af... instead of Share after combat.")
		end,
	}
end

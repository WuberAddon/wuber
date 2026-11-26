-- Tests of UI.Share and the WuberShareButton overlay (SPEC7 5.0; owner A). Loaded by tests/run.lua
-- with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local LINE = "Summoned to Undercity by Anita with Wuber - 9 min saved."

-- a rider with the window open on Home and a share pill on the Ride tab, as Done's will be
local function setup(opts)
	opts = opts or {}
	local w = T.newWorld()
	local r = T.rider(w)
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	W.db.coach = true
	W.UI.Toggle(true)
	w:advance(3)
	local T_ = W.Theme
	local pill = T_.Pill(W.UI.GetTab("Ride"), "Share", "dark", 140, 40)
	pill:SetPoint("BOTTOM", W.UI.GetTab("Ride"), "BOTTOM", 0, 20)
	pill:SetFrameLevel(W.UI.GetTab("Ride"):GetFrameLevel() + 50)
	local st = { line = opts.line or LINE, shared = {} }
	W.UI.Share.Register(pill, function() return st.line end, {
		label = "Share", onShared = function(line) st.shared[#st.shared + 1] = line st.line = nil end })
	return w, r, W, pill, st
end

local function group(w, raid)
	local names = { "Wuber TestCharacter", "Sly Fox" }
	if raid then
		for i = 1, 4 do
			w:addBot("Raider " .. i, { spot = "Orgrimmar" })
			names[#names + 1] = "Raider " .. i
		end
	end
	w:group(names)
	w:advance(1.5)
end

test("ui.share: contract (registered, deps, header, public names); WuberShareButton made at login, hidden", function()
	local W, w, r, Mod = T.contract("UI.Share", "tests/ui/share_test.lua", {
		["UI.Share"] = "table",
		["UI.Share.Register"] = "function",
		["UI.Share.Target"] = "function",
		["UI.Share.Sync"] = "function",
		["UI.Share.State"] = "function",
		["UI.Share.Macro"] = "function",
		["UI.Share.Shared"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Share\")")
	eq(W.UI.Share.Target(), nil, "nothing registered: no target")
	local b = r.env.WuberShareButton
	ok(b, "WuberShareButton exists (UI.Secure, at login)")
	ok(H.state[b].secure, "secure")
	ok(not b:IsShown(), "hidden")
	eq(b:GetAttribute("macrotext"), "", "no macro text")
	eq(W.UI.Share.Register(nil, function() end), false, "a pill is needed")
	T.clean(w)
end)

test("ui.share: hidden when not grouped; in a group the overlay docks on the pill and a click posts /p", function()
	local w, r, W, pill, st = setup()
	local b = r.env.WuberShareButton
	W.UI.RefreshNow()
	ok(not pill:IsShown(), "no pill when not in a group")
	eq(W.UI.Share.State(pill), "solo", "state solo")
	eq(W.UI.Share.Target(), nil, "no target")
	ok(not b:IsShown(), "no overlay")
	group(w)
	W.UI.RefreshNow()
	ok(pill:IsVisible(), "the pill shows in a group")
	eq(pill.label:GetText(), "Share", "its words")
	eq(W.UI.Share.Target(), pill, "the overlay's target")
	ok(b:IsVisible(), "the overlay shows")
	eq(("%.1f,%.1f"):format(b:GetCenter()), ("%.1f,%.1f"):format(pill:GetCenter()), "over the pill")
	eq(b:GetAttribute("macrotext"), "", "no macro text before the click")
	-- the macro is set in the click only, and emptied after
	local seen
	local pre = H.state[b].scripts.PreClick
	H.state[b].scripts.PreClick = function(self, ...)
		pre(self, ...)
		seen = self:GetAttribute("macrotext")
	end
	r:click(b)
	eq(seen, "/p " .. LINE, "the macro in the click")
	eq(b:GetAttribute("macrotext"), "", "emptied after")
	local posts = w.groupPosts or {}
	eq(#posts, 1, "one party post")
	eq(posts[1].text, LINE, "the line")
	eq(posts[1].kind, "PARTY", "to the party")
	eq(posts[1].how, "macro", "from the secure macro")
	eq(#st.shared, 1, "onShared called")
	-- the page's own limit (once per ride): textFn now gives nil -> the pill goes
	W.UI.RefreshNow()
	ok(not pill:IsShown(), "gone after sharing")
	eq(W.UI.Share.Target(), nil, "no target")
	ok(not b:IsShown(), "the overlay goes")
	T.clean(w)
end)

test("ui.share: in combat the pill reads 'Share after combat', no overlay; a raid posts /ra", function()
	local w, r, W, pill, st = setup()
	local b = r.env.WuberShareButton
	group(w)
	W.UI.RefreshNow()
	ok(b:IsVisible(), "overlay out of combat")
	w:enterCombat(r)
	w:advance(1.2)
	eq(W.UI.Share.State(pill), "combat", "state combat")
	ok(pill:IsVisible(), "the pill stays")
	eq(pill.label:GetText(), "Share after combat", "its words in combat")
	eq(W.UI.Share.Target(), nil, "no target in combat")
	eq(W.UI.Share.Macro(pill), nil, "no macro in combat")
	w:leaveCombat(r)
	w:advance(1.5)
	eq(pill.label:GetText(), "Share", "words back after combat")
	ok(b:IsVisible(), "overlay back")
	-- a raid
	w:leave("Sly Fox")
	w:advance(1)
	group(w, true)
	W.UI.RefreshNow()
	local macro = W.UI.Share.Macro(pill)
	eq(macro, "/ra " .. LINE, "raid macro")
	r:click(b)
	local posts = w.groupPosts or {}
	eq(posts[#posts].kind, "RAID", "to the raid")
	T.clean(w)
end)

test("ui.share: the line is one line of at most 240 characters; spam, links and 'gold' are never posted", function()
	local w, r, W, pill, st = setup()
	group(w)
	local S = W.UI.Share
	st.line = string.rep("Summoned to Undercity ", 20)
	local m, line = S.Macro(pill)
	ok(m and #line <= 240, "cut to 240: " .. tostring(line and #line))
	ok(#m <= 255, "macro fits")
	st.line = "Summoned\nto Undercity | by Anita"
	m, line = S.Macro(pill)
	ok(m and not line:find("[\r\n|]"), "one line, no pipes: " .. tostring(line))
	st.line = "Cheap gold at our site"
	eq(S.Macro(pill), nil, "'gold' refused")
	-- (round 9, C1) the whole word only, and no letters rule over Wuber's own sentences
	st.line = "Summoned to Goldshire by Marigold with Wuber - about 1 h 5 min saved."
	m, line = S.Macro(pill)
	eq(line, st.line, "Goldshire, Marigold and '1 h 5 min' pass")
	st.line = "Buy GOLD here"
	eq(S.Macro(pill), nil, "'GOLD' refused")
	eq(W.SentenceSpam("My October on Wuber: 14 summons, 3 h 20 min saved."), nil, "SentenceSpam: short words fine")
	eq(W.SpamReason("My October on Wuber: 14 summons, 3 h 20 min saved."), "letters", "SpamReason keeps its letters rule (service names)")
	eq(W.SentenceSpam("g o l d for you"), "word", "SentenceSpam: split spam words still caught")
	st.line = "Visit www.example.com now"
	eq(S.Macro(pill), nil, "a link refused")
	st.line = nil
	eq(S.Macro(pill), nil, "nothing to share")
	W.UI.RefreshNow()
	ok(not pill:IsShown(), "the pill hides with nothing to share")
	eq(#(w.groupPosts or {}), 0, "nothing posted")
	T.clean(w)
end)

test("ui.share: the short form Register(pill, textFn, onShared): onShared runs once, after the post, with the line", function()
	local w = T.newWorld()
	local r = T.rider(w)
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	W.db.coach = true
	W.UI.Toggle(true)
	w:advance(3)
	local tab = W.UI.GetTab("Ride")
	local pill = W.Theme.Pill(tab, "Share", "dark", 140, 40)
	pill:SetPoint("BOTTOM", tab, "BOTTOM", 0, 20)
	pill:SetFrameLevel(tab:GetFrameLevel() + 50)
	local line, calls, postsAtCall = LINE, {}, {}
	local asked = 0
	eq(W.UI.Share.Register(pill, function() asked = asked + 1 return line end, function(l)
		calls[#calls + 1] = l
		postsAtCall[#postsAtCall + 1] = #(w.groupPosts or {})
		line = nil -- the page's own limit: once per ride
	end), true, "registered with a function as the third argument")
	-- solo: no pill, no post, no onShared
	W.UI.RefreshNow()
	eq(W.UI.Share.State(pill), "solo", "solo")
	eq(#calls, 0, "no onShared before a post")
	group(w)
	W.UI.RefreshNow()
	eq(W.UI.Share.State(pill), "ok", "state ok in a group")
	ok(asked > 0, "textFn asked for the line")
	eq(#calls, 0, "still no onShared (only shown)")
	r:click(r.env.WuberShareButton)
	eq(#(w.groupPosts or {}), 1, "one post")
	eq(#calls, 1, "onShared once")
	eq(calls[1], LINE, "with the line")
	eq(postsAtCall[1], 1, "after the post (PostClick)")
	W.UI.RefreshNow()
	ok(not pill:IsShown(), "textFn nil now: the pill hides")
	ok(not r.env.WuberShareButton:IsShown(), "no overlay to click again")
	eq(W.UI.Share.Macro(pill), nil, "no macro either")
	eq(#calls, 1, "onShared not called again")
	T.clean(w)
end)

-- UI.Toasts lives in the window's files (owner A); its raincheck kind is for D's DR.Alert
-- raincheck alert (UI.Driver.Mini).
test("ui.toasts: the raincheck kind is gold with the clock glyph, stays 10 s and runs its click", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local W = r.W
	local TH = W.Theme
	local clicked = 0
	local t = W.UI.Toast("Ana asks for a raincheck", "raincheck", function() clicked = clicked + 1 end)
	ok(type(t) == "table", "a toast")
	eq(t.kind, "raincheck", "its kind")
	ok(t.glyph:IsShown() and not t.mark:IsShown(), "a glyph, no mark")
	eq(t.glyph:GetTextureFilePath(), TH.MEDIA .. "clock", "the clock glyph")
	local gr, gg, gb = TH.RGB("glow")
	local ir, ig, ib = t.icon:GetVertexColor()
	eq(("%.3f %.3f %.3f"):format(ir, ig, ib), ("%.3f %.3f %.3f"):format(gr, gg, gb), "a violet circle")
	local kr, kg, kb = TH.RGB("ink")
	local cr, cg, cb = t.glyph:GetVertexColor()
	eq(("%.3f %.3f %.3f"):format(cr, cg, cb), ("%.3f %.3f %.3f"):format(kr, kg, kb), "ink glyph on violet")
	-- not the info look (an unknown kind falls back to info)
	local u = W.UI.Toast("Something else", "no-such-kind")
	ok(u.glyph:GetTextureFilePath() ~= TH.MEDIA .. "clock", "an unknown kind is not the raincheck look")
	-- the raincheck toast stays 10 s (a new toast replaces it, so show it again)
	t = W.UI.Toast("Bea asks for a raincheck", "raincheck", function() clicked = clicked + 1 end)
	w:advance(9)
	ok(t:IsShown() and t.message == "Bea asks for a raincheck", "still there after 9 s")
	r:click(t)
	eq(clicked, 1, "its click ran")
	t = W.UI.Toast("Cal asks for a raincheck", "raincheck", function() end)
	w:advance(11)
	ok(not t:IsShown(), "gone after 10 s")
	-- not sticky: a lesser toast replaces it
	t = W.UI.Toast("Dan asks for a raincheck", "raincheck")
	local n = W.UI.Toast("Hello", "info")
	ok(n and n.message == "Hello", "an info toast replaces it")
	T.clean(w)
end)

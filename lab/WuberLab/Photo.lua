-- Wuber Lab (developer only, never ship): screenshots of every Wuber screen, for the CurseForge
-- page and videos (the tester has no Print Screen key).
--
--   L.Snap()        one screenshot now (the lab's own panel steps aside for it). The Snap button
--                   and /lab snap: a click / typed command, so it works even where the game only
--                   lets a hardware event take one.
--   L.TourStart()   the photo tour (/lab tour): every 2.3.0 rider, driver and Settings screen in
--                   turn (the list and its demo data: PhotoShots.lua; the driving log behind every
--                   driver number: PhotoDemo.lua), filled with DEMO data. Each
--                   page that unfolds is shot folded, then unfolded (720 wide). The Wuber window
--                   stands at one place for every shot (centred for the unfolded width), and each
--                   shot waits until the screen has settled (the Fold's width tween done, no fade
--                   running, no text still changing such as a number counting up; at most
--                   L.PHOTO_MAX_WAIT s). The next screen waits until the game has saved the last
--                   shot (SCREENSHOT_SUCCEEDED, at most L.PHOTO_SAVE_WAIT s), and every shot is at
--                   least L.PHOTO_APART s after it, in another clock second (one file per second). At the end (or on combat, a click
--                   anywhere, /lab tour stop, logout) everything is put back, the window's place too.
--
-- The shot list (for the reviewer to match the screenshot files): at each Screenshot() the timeline gets
--   "tour shot <n>/<total> <id> <folded|unfolded> | <title>"   (the log stores "|" as "/")
-- and WuberLabDB.photoTour = { started, ended, shots = { { n, id, title, view, at }, ... } } (the
-- last tour only; at = L.Epoch(), the timeline's own epoch.ms clock).
--
-- The demo data is local only:
--   * never sent: while the tour runs, Wuber's senders and actions (W.SendTo, W.SendChannel,
--     W.SendBeacon, W.Ping, invites, DR.Send / DR.Whisper, the engine's tick...) do nothing, its
--     two outgoing queues are held (W.FlushQueue / DR.FlushComm; released after, with only the
--     real messages in them), and incoming chat / addon messages, invites and summons are not
--     passed to Wuber (so nobody real can mix into a shot or be answered from demo state);
--   * never saved: WuberDB is snapshotted at the start and put back exactly at the end, in
--     place (every table keeps its identity), also on logout / reload mid-tour;
--   * nothing on screen says "DEMO": the lab's own flag L.photo marks the tour. While it is on,
--     the lab logs only "photo" lines and errors, and sends no signals (no checklist or plan
--     step ticks itself from demo data, no plan sync goes out).
-- Only Wuber's public names are used (W.UI.*, W.Driver.*, W.Drive.*, the table-held W.* that
-- tests replace too); each is checked first, and a screen whose names moved is skipped.
--
-- Hiding the rest of the game UI is not offered: Wuber's phone is a child of UIParent (hiding
-- UIParent hides the phone too), and moving Wuber's frames, which hold secure buttons, to
-- another parent is not something an addon should do. Close other windows before the tour.

local _, L = ...

local show, str, num, call = L.show, L.str, L.num, L.call

L.photo = false            -- the tour is running (the lab's own flag; nothing is drawn for it)
L.PHOTO_WAIT = 0.5         -- seconds a screen settles at least before its shot
L.PHOTO_MAX_WAIT = 3       -- at most this long, then the shot is taken anyway (and the log says so)
L.PHOTO_POLL = 0.15        -- how often a settling screen is looked at
L.PHOTO_GAP = 0.3          -- seconds after a shot before the next screen is set up
L.AUTO_NOSHOT_GAP = 0.05    -- (job 2880) the Auto check's pause after a screen it did not photograph
L.PHOTO_APART = 1.1        -- seconds between two shots at least, and never in the same clock second:
                           -- the game names the file by the second, so a second shot would overwrite it
L.PHOTO_SAVE_WAIT = 2      -- (round 13) at most this long for the game to say it saved the last shot; the
                           -- next one is counted from then (the file is named when it is saved)
L.photoShots = 0           -- shots taken this session (Snap and tours)
L.photoClick = false       -- learned: this client takes screenshots only from a click
L.PHOTO_CLICK_ONLY = "this client needs a click per shot" -- (review) why a passive tour can't run / ended

local PHOTO_KEEP = { photo = true, err = true, werr = true, laberr = true, block = true, auto = true } -- (job 105c) auto: the Auto check's lines

---------------------------------------------------------------------------
-- While the tour runs: the lab logs only its own lines, and sends no signals
---------------------------------------------------------------------------

do
	local baseLog, baseSignal = L.Log, L.Signal
	L.Log = function(kind, text)
		if L.photo and not PHOTO_KEEP[tostring(kind)] then return end
		return baseLog(kind, text)
	end
	L.Signal = function(name, info)
		if L.photo then return end
		return baseSignal(name, info)
	end
end

local function W_() return L.W() end
local function now() return L.Now() end

local function fn(t, k) return type(t) == "table" and type(t[k]) == "function" end

-- WoW's screenshot file name for "now" (WoWScrnShot_MMDDYY_HHMMSS); the game picks .jpg or .tga
local function fileName()
	local d = type(date) == "function" and call(date, "%m%d%y_%H%M%S")
	return "WoWScrnShot_" .. (str(d) or "?")
end

local function clock()
	return (type(date) == "function" and str(call(date, "%H:%M:%S"))) or "?"
end

---------------------------------------------------------------------------
-- The lab's own frames step aside for a shot
---------------------------------------------------------------------------

local LAB_FRAMES = { "WuberLabPanel", "WuberLabMini", "WuberLabSimBanner", "WuberLabSimCard", "WuberLabFxStage", "WuberLabRunPrompt" }

local function hideLab()
	L.labHiddenUntil = L.Now() + 1.5 -- (the run's prompt stays away meanwhile)
	local was = {}
	for _, name in ipairs(LAB_FRAMES) do
		local f = rawget(_G, name)
		if type(f) == "table" and fn(f, "IsShown") and f:IsShown() then
			was[#was + 1] = f
			pcall(f.Hide, f)
		end
	end
	return was
end

local function showLab(was)
	for _, f in ipairs(was or {}) do pcall(f.Show, f) end
	L.labHiddenUntil = nil
	if not L.photo and L.RunPromptUpdate then pcall(L.RunPromptUpdate) end
end

---------------------------------------------------------------------------
-- (job 042) The chat frames step aside for a shot that asks it (a screen's noChat: the OpenMap shots,
-- where real players' lines showed), the way the Lab Bar does for every shot: alpha 0 as the shot is
-- taken, each frame's own alpha back once the game has saved it (at most 1.5 s later)
---------------------------------------------------------------------------

local CHAT_NAMES = { "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton",
	"ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "ChatAlertFrame", "DaylightUIChat", "DaylightUIChatSide" }
local chatHidden          -- { { frame, alpha }, ... } while the chat is out of a shot
local chatGen = 0

local function chatFrames()
	local out, seen = {}, {}
	local function add(f)
		if type(f) == "table" and not seen[f] and fn(f, "GetAlpha") and fn(f, "SetAlpha") and fn(f, "IsShown") then
			seen[f] = true
			out[#out + 1] = f
		end
	end
	for i = 1, num(rawget(_G, "NUM_CHAT_WINDOWS")) or 10 do
		for _, suffix in ipairs({ "", "Tab", "EditBox", "ButtonFrame" }) do add(rawget(_G, "ChatFrame" .. i .. suffix)) end
	end
	for _, name in ipairs(CHAT_NAMES) do add(rawget(_G, name)) end
	return out
end

function L.PhotoChatOn()
	local list = chatHidden
	chatHidden = nil
	for _, e in ipairs(list or {}) do pcall(e[1].SetAlpha, e[1], e[2]) end
end

-- -> how many frames stepped aside
function L.PhotoChatOff()
	if chatHidden then return #chatHidden end
	chatHidden = {}
	for _, f in ipairs(chatFrames()) do
		local okS, shown = pcall(f.IsShown, f)
		local okA, a = pcall(f.GetAlpha, f)
		a = okA and num(a) or nil
		if okS and shown and a and a > 0 then
			chatHidden[#chatHidden + 1] = { f, a }
			pcall(f.SetAlpha, f, 0)
		end
	end
	chatGen = chatGen + 1
	local my = chatGen
	L.After(1.5, function() if chatGen == my then L.PhotoChatOn() end end)
	return #chatHidden
end

---------------------------------------------------------------------------
-- One screenshot
---------------------------------------------------------------------------

local snapping = false     -- inside our Screenshot() call (a block event then is ours)
local blockedNow = false
local lastShot             -- { at = now(), sec = time(), pending } of the last screenshot the game took;
                           -- pending until the game says it saved it (at and sec are then that moment)
local savedHook            -- the tour's "on to the next shot", once the game has saved this one

local function clockSec() return num(call(rawget(_G, "time"))) end

-- Seconds to wait before the next shot may be taken (0: now): at least L.PHOTO_APART after the
-- last one, and in another clock second (WoWScrnShot_MMDDYY_HHMMSS: one file per second).
local function apartWait()
	if not lastShot then return 0 end
	local gap = L.PHOTO_APART - (now() - lastShot.at)
	if gap > 0 then return gap end
	local sec = clockSec()
	if sec and lastShot.sec and sec == lastShot.sec then return 0.1 end
	return 0
end
L.PhotoApartWait = apartWait

local function onBlocked(addon, func)
	if not snapping then return end
	if str(addon) ~= L.ADDON then return end
	local f = str(func) or ""
	if f == "" or f:find("Screenshot", 1, true) or f:find("UNKNOWN", 1, true) then blockedNow = true end
end
L.On("ADDON_ACTION_BLOCKED", onBlocked)
L.On("ADDON_ACTION_FORBIDDEN", onBlocked)
-- The game has saved (or failed) the last shot: the next one is counted from now.
local function savedNow()
	if lastShot and lastShot.pending then
		lastShot.pending = nil
		lastShot.at, lastShot.sec = now(), clockSec()
	end
	local h = savedHook
	savedHook = nil
	if h then h() end
end
-- (job 042) the chat back a moment after the game has saved the shot (as the Lab Bar comes back)
local function chatBackSoon()
	if not chatHidden then return end
	local my = chatGen
	L.After(0.2, function() if chatGen == my then L.PhotoChatOn() end end)
end
L.On("SCREENSHOT_SUCCEEDED", function()
	L.Log("photo", "the game saved the screenshot (" .. clock() .. ")")
	chatBackSoon()
	savedNow()
end)
L.On("SCREENSHOT_FAILED", function()
	L.Log("photo", "the game says the screenshot FAILED (" .. clock() .. ")")
	chatBackSoon()
	savedNow()
end)

-- Takes one screenshot now. Returns true, nil, epoch (L.Epoch() at the Screenshot() call) when
-- the game took it; false, why otherwise ("missing", "blocked", "error").
local function shoot(label)
	local take = rawget(_G, "Screenshot")
	if type(take) ~= "function" then
		L.Log("photo", "no Screenshot() in this client")
		return false, "missing"
	end
	snapping, blockedNow = true, false
	local at = L.Epoch and L.Epoch() or now()
	local ok, err = pcall(take)
	snapping = false
	if blockedNow then
		L.photoClick = true
		if L.db then L.db.photoClick = true end
		L.Log("photo", "the game refused Screenshot() from the lab: it now needs a click per shot")
		return false, "blocked"
	end
	if not ok then
		L.Log("photo", "Screenshot() failed: " .. show(err))
		return false, "error"
	end
	L.photoShots = L.photoShots + 1
	lastShot = { at = now(), sec = clockSec(), pending = true }
	L.Log("photo", ("shot %d %s at %s -> Screenshots\\%s"):format(L.photoShots, show(label or "snap"), clock(), fileName()))
	return true, nil, at
end
L.PhotoShoot = shoot

-- The Snap button and /lab snap: the lab steps aside, one shot, the lab comes back.
function L.Snap()
	if L.photo then
		L.Say("the photo tour is running: it takes its own shots")
		return false
	end
	local was = hideLab()
	local ok, why = shoot("snap")
	L.After(1, function() showLab(was) end)
	if ok then
		L.Say(("screenshot %d saved (%s): World of Warcraft\\_forever_\\Screenshots\\%s"):format(L.photoShots, clock(), fileName()))
	else
		L.Say("no screenshot: " .. (why == "missing" and "this client has no Screenshot()" or tostring(why)))
	end
	return ok
end

---------------------------------------------------------------------------
-- Tour state: stubs (table fields, put back in reverse), the DB snapshot
---------------------------------------------------------------------------

local NIL = {}
local tour = nil -- { gen, saved = { {tbl, key, old} }, seen = { [tbl] = { [key] = true } }, ... }
local gen = 0

local function stub(tbl, key, value)
	if type(tbl) ~= "table" or not tour then return false end
	tour.seen[tbl] = tour.seen[tbl] or {}
	if not tour.seen[tbl][key] then
		tour.seen[tbl][key] = true
		local old = tbl[key]
		tour.saved[#tour.saved + 1] = { tbl, key, old == nil and NIL or old }
	end
	tbl[key] = value
	return true
end

local function unstubAll()
	if not tour then return end
	for i = #tour.saved, 1, -1 do
		local s = tour.saved[i]
		local v = s[3]
		if v == NIL then v = nil end
		local ok = pcall(function() s[1][s[2]] = v end)
		if not ok then L.Bug("photo unstub", show(s[2])) end
	end
	tour.saved, tour.seen = {}, {}
end

-- A snapshot of a table tree that remembers each table's identity, so it can be put back in
-- place: every table that existed is the same table again, with exactly the same contents.
local function snapshot(t, seen)
	if type(t) ~= "table" then return t end
	seen = seen or {}
	if seen[t] then return seen[t] end
	local node = { ref = t, kv = {} }
	seen[t] = node
	for k, v in pairs(t) do node.kv[k] = snapshot(v, seen) end
	return node
end
L.PhotoSnapshot = snapshot

local function restore(node, done)
	local t = node.ref
	done = done or {}
	if done[t] then return t end
	done[t] = true
	local gone = {}
	for k in pairs(t) do
		if node.kv[k] == nil then gone[#gone + 1] = k end
	end
	for _, k in ipairs(gone) do t[k] = nil end
	for k, v in pairs(node.kv) do
		if type(v) == "table" then
			t[k] = restore(v, done)
		elseif t[k] ~= v then
			t[k] = v
		end
	end
	return t
end
L.PhotoRestore = restore

---------------------------------------------------------------------------
-- While the tour runs: nothing leaves, nothing comes in
---------------------------------------------------------------------------

local function sink() return false end

-- dropped while the tour runs
local W_SINKS = { "SendChannel", "SendTo", "SendBeacon", "Ping", "Invite", "AcceptInvite", "AcceptSummon", "LeaveGroup",
	"PayFare", "CheckRide", "CheckArrival", "AutoLeave", "RequestRide", "CancelRide", "Rate", "EndRide", "AddTrip",
	"CheckMilestones", "CommunityInvite", "CommunityAccept", "CommunityCheck", "CheckChannel", "SetDriving", "RiderBooked" }
local DR_SINKS = { "Send", "Whisper", "Ring", "BellAlert", "Tick", "QueueTick", "RaidTick", "OwingTick", "OfferTick", "PumpInvites",
	"PumpChat", "PumpTrade", "Invite", "HandLead", "LeadFix", "SyncNow", "SyncOut", "SyncStates", "Hello", "SendConfig",
	"SendService", "SendBlocklist", "SendCrew", "OfferCrew", "AnswerOffer", "CheckAdvert", "MarkAdvert", "RaidAsk", "RaidCancel",
	"MarkPaid", "LogRide", "LogTeamRide", "LogRaid", "LogAsk", "LogNet", "LogRivals", "SetOpen", "SetPaused", "OpenBox", "Alert",
	"Request", "Lead", "Apply", "SyncRoster", "Do", "StartTeam", "ShardsChanged" }
-- held while the tour runs (real messages already queued go after it)
local W_HOLD = { "FlushQueue" }
local DR_HOLD = { "FlushComm" }
-- no toasts or celebration cards over the shots
local UI_SINKS = { "Toast", "Celebrate", "ShowNextPop" }

-- game events Wuber does not hear while the tour runs
-- (review) and a real trade or summon: Wuber holds demo data while the tour runs, so it must not see
-- a real trade's events (or a summon being cancelled) until the tour has put its own data back
local DROP = { CHAT_MSG_ADDON = true, CHAT_MSG_WHISPER = true, CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true,
	CHAT_MSG_YELL = true, CHAT_MSG_WHISPER_INFORM = true, PARTY_INVITE_REQUEST = true, CONFIRM_SUMMON = true,
	CANCEL_SUMMON = true, TRADE_SHOW = true, TRADE_UPDATE = true, TRADE_ACCEPT_UPDATE = true, TRADE_MONEY_CHANGED = true,
	TRADE_PLAYER_ITEM_CHANGED = true, TRADE_TARGET_ITEM_CHANGED = true, TRADE_CLOSED = true, TRADE_REQUEST_CANCEL = true,
	PLAYER_TRADE_MONEY = true }
L.PHOTO_DROP = DROP

local function quiet(W)
	local DR = W.Drive
	for _, n in ipairs(W_SINKS) do if fn(W, n) then stub(W, n, sink) end end
	for _, n in ipairs(W_HOLD) do if fn(W, n) then stub(W, n, sink) end end
	if type(DR) == "table" then
		for _, n in ipairs(DR_SINKS) do if fn(DR, n) then stub(DR, n, sink) end end
		for _, n in ipairs(DR_HOLD) do if fn(DR, n) then stub(DR, n, sink) end end
	end
	if type(W.UI) == "table" then
		for _, n in ipairs(UI_SINKS) do if fn(W.UI, n) then stub(W.UI, n, function() end) end end
	end
	-- incoming: Wuber's one event frame skips chat, addon messages, invites and summons
	local f = W.frame
	if type(f) == "table" and fn(f, "GetScript") and fn(f, "SetScript") then
		local orig = f:GetScript("OnEvent")
		if type(orig) == "function" then
			tour.frameScript = orig
			f:SetScript("OnEvent", function(self, event, ...)
				if L.photo and DROP[event] then
					-- (passive play, Passive.lua) a real player wants this window - a whisper, an addon
					-- whisper, an invite, a summon: the tour stops (Wuber is put back) and Wuber hears it
					local real = L.PhotoRealEvent
					if not (real and real(event, ...) == true and not L.photo) then return end
				end
				return orig(self, event, ...)
			end)
		end
	end
end

local function unquiet(W)
	local f = W and W.frame
	if tour and tour.frameScript and type(f) == "table" and fn(f, "SetScript") then
		f:SetScript("OnEvent", tour.frameScript)
	end
end


---------------------------------------------------------------------------
-- For PhotoShots.lua (the shot list): the stubs, the tour
---------------------------------------------------------------------------

L.PhotoKit = { stub = stub, fn = fn, now = now, tour = function() return tour end }

---------------------------------------------------------------------------
-- The window: one place for every shot, folded or unfolded, and settled
---------------------------------------------------------------------------

local function modOf(W, name)
	if not fn(W, "Mod") then return nil end
	local ok, m = pcall(W.Mod, name)
	return ok and type(m) == "table" and m or nil
end

local function winOf(W)
	local st = type(W) == "table" and type(W.UI) == "table" and W.UI.state
	local win = type(st) == "table" and st.win
	return (type(win) == "table" and fn(win, "GetWidth")) and win or nil
end

-- the folded and unfolded widths (UI.Kit's WIN_W, WIDE_W)
local function widths(W)
	local K = modOf(W, "UI.Kit")
	return num(K and K.WIN_W) or 360, num(K and K.WIDE_W) or 720
end

local function lockdown()
	local f = rawget(_G, "InCombatLockdown")
	if type(f) ~= "function" then return false end
	local ok, v = pcall(f)
	return ok and v == true
end

-- the window's anchor points, to put it back
local function points(win)
	local out = {}
	local n = fn(win, "GetNumPoints") and num(select(2, pcall(win.GetNumPoints, win))) or 1
	for i = 1, math.max(1, n or 1) do
		local ok, p, rel, rp, x, y = pcall(win.GetPoint, win, i)
		if ok and p then out[#out + 1] = { p, rel, rp, x, y } end
	end
	return out
end

local function setPoints(W, pts)
	local win = winOf(W)
	if not (win and type(pts) == "table" and #pts > 0) then return false end
	win:ClearAllPoints()
	for _, p in ipairs(pts) do win:SetPoint(p[1], p[2] or UIParent, p[3] or p[1], p[4] or 0, p[5] or 0) end
	if fn(W.UI, "SyncSecure") then pcall(W.UI.SyncSecure) end
	return true
end

-- The window's top left where the unfolded (720 wide) window is centred on the screen (the
-- folded one then stands at the same left edge): the same place for every shot.
local function centre(W)
	local win = winOf(W)
	if not win or lockdown() then return false end
	-- (BRIEF20, B4) Wuber's own default place: no saved position (W.db.pos is put back after the tour), then
	-- UI.PlaceWindow, so every shot shows where a new player's phone really stands. The old centring stays
	-- only for a Wuber without PlaceWindow.
	if fn(W.UI, "PlaceWindow") and type(W.db) == "table" then
		stub(W.db, "pos", nil)
		if W.UI.PlaceWindow() then return true end
	end
	local narrowW, wideW = widths(W)
	local s = 1
	local ue, we = num(UIParent:GetEffectiveScale()), num(win:GetEffectiveScale())
	if ue and we and ue > 0 then s = we / ue end
	local uw, uh = num(UIParent:GetWidth()) or 1024, num(UIParent:GetHeight()) or 768
	local F = W.UI.Fold
	local room = type(F) == "table" and fn(F, "Fits") and F.Fits()
	local w = room and wideW or narrowW
	local x = math.floor((uw / s - w) / 2 + 0.5)
	local y = -math.floor((uh / s - (num(win:GetHeight()) or 0)) / 2 + 0.5)
	return setPoints(W, { { "TOPLEFT", UIParent, "TOPLEFT", x, y } })
end

-- the page choices for the shot: every page folded by choice (the fold button shows), or none
local FOLD_PAGES = { "ride", "confirm", "trips", "settings", "console", "raid", "earnings", "messages", "customers" }
local function foldFor(W, view)
	if type(W.db) ~= "table" then return end
	local F = modOf(W, "UI.Fold")
	local list = {}
	if F and type(F.PAGES) == "table" then
		for p in pairs(F.PAGES) do list[#list + 1] = p end
	else
		list = FOLD_PAGES
	end
	local pages = {}
	if view ~= "unfolded" then for _, p in ipairs(list) do pages[p] = "closed" end end
	stub(W.db, "fold", { v = 1, pages = pages, narrow = false })
end

local function applyFold(W, instant)
	local F = type(W.UI) == "table" and W.UI.Fold
	if fn(F, "Apply") then F.Apply(instant) end
end

-- the alphas of the window's shown frames (three levels down): a fade still running changes it
local function alphas(frame, depth, out)
	if depth > 3 or not fn(frame, "GetChildren") then return end
	local kids = { frame:GetChildren() }
	for i = 1, #kids do
		local k = kids[i]
		if type(k) == "table" and fn(k, "IsShown") and k:IsShown() and fn(k, "GetAlpha") then
			out[#out + 1] = math.floor((num(k:GetAlpha()) or 1) * 100 + 0.5)
			alphas(k, depth + 1, out)
		end
	end
end

local function alphaSig(W)
	local win = winOf(W)
	if not win then return "" end
	local out = {}
	local ok = pcall(alphas, win, 1, out)
	return ok and table.concat(out, ",") or ""
end

-- (round 13, I34) the shown texts of the window, deep: a number still counting up (Trips' time saved)
-- changes it between two looks
local TEXT_DEPTH, TEXT_MAX = 12, 3000
local function texts(frame, depth, out)
	if depth > TEXT_DEPTH or #out > TEXT_MAX then return end
	if fn(frame, "GetRegions") then
		local regs = { frame:GetRegions() }
		for i = 1, #regs do
			local r = regs[i]
			if type(r) == "table" and fn(r, "GetText") and fn(r, "IsShown") and r:IsShown() then
				local s = r:GetText()
				if type(s) == "string" and s ~= "" then out[#out + 1] = s end
			end
		end
	end
	if not fn(frame, "GetChildren") then return end
	local kids = { frame:GetChildren() }
	for i = 1, #kids do
		local k = kids[i]
		if type(k) == "table" and fn(k, "IsShown") and k:IsShown() then texts(k, depth + 1, out) end
	end
end

local function textSig(W)
	local win = winOf(W)
	if not win then return "" end
	local out = {}
	local ok = pcall(texts, win, 1, out)
	return ok and table.concat(out, "\n") or ""
end
L.PhotoTextSig = textSig

-- Whether the window has settled for a shot of this view: the Fold's tween done and the width
-- final, no window animation running, the window fully shown. false, what is still moving.
local function calm(W, view)
	local win = winOf(W)
	if not win then return true end
	local F = modOf(W, "UI.Fold")
	if F and type(F.state) == "table" and F.state.tween then return false, "the fold" end
	local narrowW, wideW = widths(W)
	local want = view == "unfolded" and wideW or narrowW
	if math.abs((num(win:GetWidth()) or want) - want) > 0.5 then return false, "the width" end
	local st = W.UI.state
	if type(st) == "table" and num(st.animUntil) and st.animUntil > now() then return false, "an animation" end
	if fn(win, "GetAlpha") and (num(win:GetAlpha()) or 1) < 0.99 then return false, "the window's fade" end
	return true
end
L.PhotoCalm = calm

---------------------------------------------------------------------------
-- The click mode (only where the game refuses Screenshot() from a timer)
---------------------------------------------------------------------------

local clicker
local function buildClicker()
	if clicker then return clicker end
	local b = CreateFrame("Button", "WuberLabPhotoSnap", UIParent)
	b:SetSize(130, 30)
	b:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -12)
	pcall(b.SetFrameStrata, b, "TOOLTIP")
	pcall(b.SetFrameLevel, b, 50)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(b)
	bg:SetColorTexture(0.18, 0.1, 0.28, 1)
	b.label = b:CreateFontString(nil, "OVERLAY")
	if not pcall(b.label.SetFont, b.label, "Fonts\\ARIALN.TTF", 13, "") then
		pcall(b.label.SetFontObject, b.label, GameFontHighlightSmall or GameFontNormal)
	end
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label:SetText("Snap")
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", function(self)
		local ok, err = pcall(function()
			self:Hide() -- (gone before the shot: the game draws the frame after this click)
			local go = self.go
			self.go = nil
			if go then go() end
		end)
		if not ok then L.Bug("photo click", err) end
	end)
	b:Hide()
	clicker = b
	return b
end

---------------------------------------------------------------------------
-- The tour
---------------------------------------------------------------------------

local catcher -- an invisible full-screen frame: nothing under it can be clicked; a click stops the tour
local function buildCatcher()
	if catcher then return catcher end
	local f = CreateFrame("Frame", "WuberLabPhotoCatcher", UIParent)
	f:SetAllPoints(UIParent)
	-- (above Wuber's secure overlays, FULLSCREEN_DIALOG: a click meant to stop the tour never
	-- reaches a share or summon button over a demo screen; under the Snap button)
	pcall(f.SetFrameStrata, f, "TOOLTIP")
	pcall(f.SetFrameLevel, f, 1)
	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function() L.TourStop("a click") end)
	f:Hide()
	catcher = f
	return f
end

local function say(text)
	if L.Say then L.Say(text) end
end

-- (review) A trade window open or a summon waiting: the tour holds Wuber's trade and summon events
-- back (TRADE_CLOSED, CANCEL_SUMMON...), so a tour started now could leave Wuber's trade or summon
-- state stale. Why not, or nil. Every name is looked up and called guarded.
local function tradeOrSummon()
	local tf = rawget(_G, "TradeFrame")
	if type(tf) == "table" and fn(tf, "IsShown") and L.plain(call(tf.IsShown, tf)) == true then
		return "a trade window is open: finish or close it first"
	end
	local si = rawget(_G, "C_SummonInfo")
	local left = fn(si, "GetSummonConfirmTimeLeft") and si.GetSummonConfirmTimeLeft or rawget(_G, "GetSummonConfirmTimeLeft")
	local t = num(call(left))
	if t and t > 0 then return "a summon is waiting: accept or decline it first" end
	return nil
end

-- Whether the tour may start now (and why not).
function L.TourCan()
	if L.photo then return false, "the tour is already running" end
	if L.InCombat() then return false, "not in combat" end
	local busy = tradeOrSummon()
	if busy then return false, busy end
	local W = W_()
	if not W then return false, "Wuber isn't loaded" end
	if not (type(W.UI) == "table" and fn(W.UI, "Show") and fn(W.UI, "Toggle")) then return false, "Wuber's window isn't there" end
	if type(W.db) ~= "table" then return false, "Wuber's settings aren't loaded yet" end
	if fn(W, "RideActive") and call(W.RideActive) then return false, "a ride is under way: finish it first" end
	local DR = W.Drive
	if type(DR) == "table" and fn(DR, "IsOpen") and call(DR.IsOpen) == true then
		return false, "you're open as a driver: close first (real riders would mix with the demo)"
	end
	return true
end

local finish

-- The shot list (the contract labreport.js reads): a timeline line and WuberLabDB.photoTour.
local function record(e, n, at)
	local total = #tour.plan
	L.Log("photo", ("tour shot %d/%d %s %s | %s"):format(n, total, e.s.id, e.view, tostring(e.s.title)))
	local pt = L.db and L.db.photoTour
	if type(pt) == "table" and type(pt.shots) == "table" then
		pt.shots[#pt.shots + 1] = { n = n, id = e.s.id, title = tostring(e.s.title), view = e.view, at = at }
	end
	-- (job 105c) the Auto check notes which shot shows the screen it looked over
	if tour.auto and type(tour.auto.shot) == "function" then pcall(tour.auto.shot, e, n, at) end
end

-- Waits until the screen has settled (calm and no frame's alpha still changing; and the shot's own
-- ready(), if any), at least s.wait or L.PHOTO_WAIT, at most s.maxWait or L.PHOTO_MAX_WAIT; then go(settled, why).
local function settle(myGen, W, e, go)
	local s = e.s
	local t0 = now()
	local maxWait = num(s.maxWait) or L.PHOTO_MAX_WAIT
	local last
	local function poll()
		if not tour or tour.gen ~= myGen then return end
		if L.InCombat() then return finish("combat") end
		local okCalm, isCalm, why = pcall(calm, W, e.view)
		if not okCalm then isCalm, why = true, nil end
		-- (job 041) a shot of the game's own maps with Wuber's window shut: its window is not in the shot
		if s.noWin then isCalm, why = true, nil end
		local sig = alphaSig(W) .. "\n#\n" .. textSig(W)
		local ready = true
		if type(s.ready) == "function" then
			local ok, r = pcall(s.ready, W, e.view)
			ready = not ok or r == true
			if not ready then why = "the screen" end
		end
		if isCalm and ready and sig == last then return go(true) end
		if not why and sig ~= last then why = "a fade or a number still counting" end
		last = sig
		if now() - t0 >= maxWait then return go(false, why) end
		L.After(L.PHOTO_POLL, poll)
	end
	L.After(num(s.wait) or L.PHOTO_WAIT, poll)
end

-- The next shot: set it up (folded or unfolded), wait until it has settled, shoot, on to the next.
local function step(myGen, i)
	if not tour or tour.gen ~= myGen then return end
	if L.InCombat() then return finish("combat") end
	local W = W_()
	local plan = tour.plan
	local e = plan[i]
	if not e then return finish(nil) end
	if not W then return finish("Wuber went away") end
	local s = e.s
	local function skip(why)
		tour.failed[s.id] = true
		tour.skipped[#tour.skipped + 1] = e.key
		L.Log("photo", ("skip %d/%d %s %s: %s"):format(i, #plan, s.id, e.view, tostring(why)))
		if tour.auto and type(tour.auto.skipped) == "function" then pcall(tour.auto.skipped, e, why) end -- (job 105c)
		return L.After(0.1, function() step(myGen, i + 1) end)
	end
	if e.twin and tour.failed[s.id] then return skip("its folded shot was skipped") end
	if L.PhotoReset then pcall(L.PhotoReset, W) end
	pcall(centre, W)
	pcall(foldFor, W, e.view)
	local ok, res = pcall(s.run, W, e.view)
	if ok and res == true then
		ok, res = pcall(applyFold, W)
		if ok then res = true end
	end
	if not ok or res ~= true then
		return skip(not ok and ("error: " .. show(res)) or (type(res) == "string" and res or "skipped"))
	end
	if e.view == "unfolded" then
		local F = W.UI.Fold
		if not (fn(F, "IsUnfolded") and F.IsUnfolded()) then
			local why
			if fn(F, "Fits") then
				local _, w = F.Fits()
				why = w
			end
			return skip("this page doesn't unfold here" .. (why == "small" and " (the screen is too small at this window size)" or ""))
		end
	end
	tour.visited[#tour.visited + 1] = e.key
	local function shot(settled, why)
		if not tour or tour.gen ~= myGen then return end
		-- (job 105c) Auto check: the settled screen is looked over first (cut text, overlaps, tooltips...: AutoCheck.lua),
		-- then the shot a moment later, once the hover looks its tooltip pass left have faded
		if tour.auto and not e.audited then
			e.audited = true
			if type(tour.auto.audit) == "function" then
				local okA, errA = pcall(tour.auto.audit, W, e, settled, why)
				if not okA then L.Log("auto", ("%s %s: the check itself broke: %s"):format(s.id, e.view, show(errA))) end
			end
			if not tour or tour.gen ~= myGen then return end
			-- (job 2880) the Auto check takes a screenshot only where the check failed, needs a look, or the screen is new
			-- (hooks.wantShot, AutoCheck.lua): otherwise on to the next screen at once (no wait, no file, no save pause)
			if type(tour.auto.wantShot) == "function" then
				local okW, want = pcall(tour.auto.wantShot, e)
				if okW and want == false then
					tour.unshot = (tour.unshot or 0) + 1
					return L.After(num(L.AUTO_NOSHOT_GAP) or 0.05, function() step(myGen, i + 1) end)
				end
			end
			return L.After(num(L.AUTO_SHOT_WAIT) or 0.35, function() shot(settled, why) end)
		end
		if not settled then L.Log("photo", ("%s %s: still moving after %.1f s (%s); shot anyway"):format(s.id, e.view,
			num(s.maxWait) or L.PHOTO_MAX_WAIT, tostring(why or "?"))) end
		local function after(took, at)
			if took then
				tour.shots = tour.shots + 1
				tour.shot[#tour.shot + 1] = e.key
				record(e, tour.shots, at)
				-- (job 042) after the shot: e.g. the flight map closed when more shots follow
				if type(s.afterShot) == "function" then
					local okA, errA = pcall(s.afterShot, W, i < #plan)
					if not okA then L.Log("photo", s.id .. " after its shot: error: " .. show(errA)) end
				end
			else
				tour.missed[#tour.missed + 1] = e.key
			end
			local function onward() L.After(L.PHOTO_GAP, function() step(myGen, i + 1) end) end
			if not took then return onward() end
			-- (round 13, I34) the game names and saves the file a moment later: the next screen waits
			-- for that (at most L.PHOTO_SAVE_WAIT s), so its shot is a second after this one was saved
			local done = false
			local function go()
				if done then return end
				done = true
				if savedHook == go then savedHook = nil end
				onward()
			end
			savedHook = go
			L.After(L.PHOTO_SAVE_WAIT, go)
		end
		-- (job 042) the shot: the chat frames out of it when the screen asks (noChat), and the screen's own
		-- check of what it shows (check: a line for the tour log) at the moment it is taken
		local function take()
			if s.noChat and L.PhotoChatOff then L.PhotoChatOff() end
			local took, why2, at = shoot(e.key)
			if not took then
				if s.noChat and L.PhotoChatOn then L.PhotoChatOn() end
			elseif type(s.check) == "function" then
				local okC, line = pcall(s.check, W, e.view)
				line = okC and line or ("check: error: " .. show(line))
				if line then L.Log("photo", ("%s %s: %s"):format(s.id, e.view, tostring(line))) end
			end
			return took, why2, at
		end
		local function byClick()
			local b = buildClicker()
			b.label:SetText(("Snap %d/%d"):format(i, #plan))
			b.go = function()
				if not tour or tour.gen ~= myGen then return end
				local took, _, at = take()
				after(took, at)
			end
			b:Show()
		end
		-- never two shots in one clock second (the second file would overwrite the first)
		local wait = apartWait()
		if wait > 0 then return L.After(wait, function() shot(true) end) end
		-- (review) a passive tour (passive play, by itself) never asks for clicks: any click stops it
		if tour.passive and (L.photoClick or tour.click) then return finish(L.PHOTO_CLICK_ONLY) end
		-- (job 105c) an Auto check never asks for a click per shot: where the game refuses Screenshot() from the
		-- lab, its checks run without pictures
		if tour.auto and (L.photoClick or tour.click) then return after(false) end
		if L.photoClick or tour.click then return byClick() end
		local took, why2, at = take()
		if not took and why2 == "blocked" then
			if tour.passive then return finish(L.PHOTO_CLICK_ONLY) end
			if tour.auto then return after(false) end -- (job 105c)
			return byClick()
		end
		after(took, at)
	end
	if type(s.post) ~= "function" then return settle(myGen, W, e, shot) end
	-- a shot with a post (a tooltip, the World view, Wrapped's story): once the page has settled
	settle(myGen, W, e, function()
		if not tour or tour.gen ~= myGen then return end
		local okPost, resPost = pcall(s.post, W, e.view)
		if not okPost or resPost ~= true then
			tour.visited[#tour.visited] = nil
			return skip(not okPost and ("error: " .. show(resPost)) or (type(resPost) == "string" and resPost or "skipped"))
		end
		settle(myGen, W, e, shot)
	end)
end

-- the window's place before the tour, put back once out of combat lockdown
local function putBack(W, pts)
	if not pts then return end
	if lockdown() then
		L.photoPlace = pts
		return
	end
	L.photoPlace = nil
	local ok, err = pcall(setPoints, W, pts)
	if not ok then L.Bug("photo window place", err) end
end

finish = function(reason)
	if not tour then return end
	local t = tour
	local W = W_()
	gen = gen + 1
	t.gen = -1
	if clicker then clicker.go = nil clicker:Hide() end
	if catcher then catcher:Hide() end
	L.PhotoChatOn() -- (job 042) never left out of sight
	-- Wuber's overlays and screens closed while the demo is still in place
	if W then
		if L.PhotoReset then pcall(L.PhotoReset, W) end
		if L.PhotoCloseSheets then pcall(L.PhotoCloseSheets, W) end
		if L.PhotoCloseOverlays then pcall(L.PhotoCloseOverlays, W) end
		if type(W.UI) == "table" and fn(W.UI, "ShowDrive") and type(W.Driver) == "table" and fn(W.Driver, "ShowScreen") then
			pcall(W.Driver.ShowScreen, "console")
		end
		local fs = type(W.UI) == "table" and type(W.UI.state) == "table" and type(W.UI.state.screens) == "table" and W.UI.state.screens.found
		if type(fs) == "table" then fs.picking = false end
	end
	-- everything put back: incoming events, the stubbed names and swapped tables, then WuberDB
	pcall(unquiet, W)
	savedHook = nil
	unstubAll()
	local okDb, errDb = pcall(function()
		restore(t.db)
		if rawget(_G, "WuberDB") ~= t.db.ref then _G.WuberDB = t.db.ref end
		if W and W.db ~= t.wdb then W.db = t.wdb end
	end)
	if not okDb then L.Bug("photo db restore", errDb) end
	-- (round 13) the demo driving log is gone: Wuber's caches of it (the queue's ride counts) forget it
	if t.demoLog and W and fn(W, "Fire") then pcall(W.Fire, "DRIVE_LOG") end
	L.photo = false
	if t.fakes then L.fakesOn = true end
	-- the window as it was
	if W and type(W.UI) == "table" then
		local UI = W.UI
		local st = UI.state
		if type(st) == "table" then
			st.manual, st.confirmKey = t.ui.manual, t.ui.confirmKey
			if type(st.dismissed) == "table" then for id in pairs(t.rides) do st.dismissed[id] = nil end end
			if st.peek and t.rides[st.peek] then st.peek = nil end
		end
		if fn(UI, "SetSearch") then pcall(UI.SetSearch, t.ui.search or "") end
		if t.ui.tab and fn(UI, "SelectTab") then pcall(UI.SelectTab, t.ui.tab) end
		if fn(UI, "Refresh") then pcall(UI.Refresh, true) end
		if not t.ui.shown and fn(UI, "IsShown") and UI.IsShown() then pcall(UI.Toggle, false) end
		-- the Fold as the player's own choices say (at once), then the window's own place
		if not lockdown() then pcall(applyFold, W, true) end
		putBack(W, t.pos)
	end
	if W then
		local DR, D = W.Drive, W.Driver
		if fn(D, "Refresh") then pcall(D.Refresh, true) end
		if type(DR) == "table" and type(DR.Button) == "table" and fn(DR.Button, "Refresh") and not L.InCombat() then
			pcall(DR.Button.Refresh)
		end
		if type(W.Map) == "table" and fn(W.Map, "Refresh") then pcall(W.Map.Refresh) end
		if type(W.FX) == "table" and fn(W.FX, "StopAll") then pcall(W.FX.StopAll, true) end
		-- the held queues: only real messages are in them
		if fn(W, "FlushQueue") then pcall(W.FlushQueue) end
		if type(DR) == "table" and fn(DR, "FlushComm") then pcall(DR.FlushComm) end
	end
	showLab(t.lab)
	tour = nil
	local pt = L.db and L.db.photoTour
	if type(pt) == "table" then pt.ended = math.floor(L.Epoch and L.Epoch() or 0) end
	local msg = ("photo tour %s: %d screenshot%s taken (%d planned%s%s)"):format(reason and ("stopped (" .. reason .. ")") or "done",
		t.shots, t.shots == 1 and "" or "s", #t.plan, #t.skipped > 0 and (", skipped: " .. table.concat(t.skipped, ", ")) or "",
		#t.missed > 0 and (", no shot: " .. table.concat(t.missed, ", ")) or "")
	if (t.unshot or 0) > 0 then msg = msg .. (", %d checked without a screenshot"):format(t.unshot) end
	L.Log("photo", msg .. " in " .. ("%.0f"):format(now() - t.started) .. " s; WuberDB and Wuber put back")
	L.lastTour = { shots = t.shots, planned = #t.plan, visited = t.visited, shot = t.shot, skipped = t.skipped, missed = t.missed, reason = reason }
	if t.auto then
		-- (job 105c) the Auto check says its own last line (how many passed, how many need a look)
		if type(t.auto.done) == "function" then
			local okD, errD = pcall(t.auto.done, reason, L.lastTour)
			if not okD then L.Bug("auto check done", errD) end
		end
	else
		say(msg .. (t.shots > 0 and ". They are in World of Warcraft\\_forever_\\Screenshots." or "")
			.. (reason == nil and not t.passive and t.shots > 0 and " Tour done: type /reload now so the list is saved and the review can start." or ""))
	end
	if L.RefreshPanel then L.RefreshPanel() end
	return L.lastTour
end

-- The tour's plan: each screen folded, then (unfold = true) unfolded; only = "unfolded": one shot.
-- Keys in L.lastTour: "home" (folded), "home+unfolded".
local function planOf(list)
	local plan = {}
	for _, s in ipairs(list) do
		if s.only ~= "unfolded" then plan[#plan + 1] = { s = s, view = "folded", key = s.id } end
		if s.unfold or s.only == "unfolded" then
			plan[#plan + 1] = { s = s, view = "unfolded", key = s.id .. "+unfolded", twin = s.only ~= "unfolded" }
		end
	end
	return plan
end
L.PhotoPlan = planOf

-- seconds the tour takes, about (per shot: the least wait, a settling poll or two, the gap)
function L.PhotoEstimate(n)
	return math.ceil(n * math.max(L.PHOTO_WAIT + 2 * L.PHOTO_POLL + L.PHOTO_GAP + 0.1, L.PHOTO_APART + 0.2))
end

-- (job 041) Every screen in tour order: L.PHOTO_SCREENS with the gated shots (L.PHOTO_GATED, PhotoShots.lua)
-- each after the screen its "after" names (job 042: or first, with first = true). A gated shot needs something outside Wuber (OpenMap loaded, the
-- game's flight map open): need(W) returns true or why not, and a tour leaves it out then (one log line per
-- reason). They are kept out of L.PHOTO_SCREENS, whose every shot the offline harness takes.
function L.PhotoScreens()
	local out, after, placed = {}, {}, {}
	for _, g in ipairs(L.PHOTO_GATED or {}) do
		if g.first then -- (job 042) the tour's first shot (the bird: while the flight map is surely open)
			out[#out + 1] = g
			placed[g] = true
		else
			local k = tostring(g.after or "")
			after[k] = after[k] or {}
			after[k][#after[k] + 1] = g
		end
	end
	for _, s in ipairs(L.PHOTO_SCREENS or {}) do
		out[#out + 1] = s
		for _, g in ipairs(after[s.id] or {}) do
			out[#out + 1] = g
			placed[g] = true
		end
	end
	for _, g in ipairs(L.PHOTO_GATED or {}) do if not placed[g] then out[#out + 1] = g end end
	return out
end

-- Partial tours (/lab tour ride | drive | float | settings | earnings | video | <shot ids or prefixes>).
-- Groups are sets of screen ids: ride = every rider screen (the OpenMap and "Skip the bird" shots too),
-- drive = driver screens except the floating-button and earnings ones, float = float_* and chat_float,
-- settings = Settings, Help and the bug window, earnings = earnings*, video = the launch video's shots
-- (video = true), openmap = OpenMap's two shots (job 042; "bird" is the bird shot's own id). A word that is neither a group nor an id is an id prefix.
L.TOUR_GROUPS = {
	ride = function(s) return s.side == "rider" end,
	drive = function(s) return s.side == "driver" and not s.id:find("^float_") and s.id ~= "chat_float" and not s.id:find("^earnings") end,
	float = function(s) return s.id:find("^float_") ~= nil or s.id == "chat_float" end,
	settings = function(s) return s.side == "settings" end,
	earnings = function(s) return s.id:find("^earnings") ~= nil end,
	video = function(s) return s.video == true end,
	openmap = function(s) return s.id:find("^openmap") ~= nil end, -- (job 042) OpenMap's two shots
}

-- words (a list of strings) -> list of screen ids in tour order, subset label, unknown words
function L.TourResolve(words)
	local want, unknown, used = {}, {}, {}
	for _, w in ipairs(words or {}) do
		w = tostring(w):lower()
		local g = L.TOUR_GROUPS[w]
		local hit = false
		for _, s in ipairs(L.PhotoScreens()) do
			local id = s.id:lower()
			if (g and g(s)) or (not g and (id == w or id:sub(1, #w) == w)) then want[s.id] = true hit = true end
		end
		if not hit then unknown[#unknown + 1] = w else used[#used + 1] = w end
	end
	local ids = {}
	for _, s in ipairs(L.PhotoScreens()) do if want[s.id] then ids[#ids + 1] = s.id end end
	return ids, table.concat(used, ","), unknown
end

-- (job 2880) The Photo tour button and /lab tour with no words: ALWAYS the full tour (never a partial one, whatever the
-- last run or the flight map did). The bird shot is part of it when the game's flight map is open, left out with a note
-- when not (PhotoShots.lua L.PHOTO_GATED).
function L.TourFull(opts)
	opts = opts or {}
	opts.full = true
	return L.TourStart(opts)
end

-- (job 105c) opts.auto: the Auto check's hooks { audit(W, e, settled, why), shot(e, n, at), skipped(e, why), done(reason, lastTour) }
-- and opts.screens: its screen list. The tour is the same (nothing sent, nothing saved, a click stops it).
-- Starts the photo tour. opts.subset: a label for a partial tour (saved with the shot list). opts.click: a click per shot (where the game refuses Screenshot()
-- from a timer; learned by itself the first time it is refused). opts.only: a list of screen ids.
-- opts.passive: passive play's own tour (never a click per shot: a refused shot ends it).
function L.TourStart(opts)
	opts = opts or {}
	if opts.full then opts.only, opts.subset = nil, nil end -- (job 2880) the full tour, whatever else was passed
	local can, why = L.TourCan()
	if not can then
		say("photo tour: " .. why)
		L.Log("photo", "tour refused: " .. why)
		return false, why
	end
	local W = W_()
	local list = {}
	local only
	if type(opts.only) == "table" then
		only = {}
		for _, id in ipairs(opts.only) do only[id] = true end
	end
	-- (job 041) a gated shot whose need isn't met is left out: one line per reason, never an error
	local out, why = {}, {}
	-- (job 105c) opts.screens: the Auto check's own list (the tour's screens and its extra ones) in place of L.PhotoScreens()
	for _, s in ipairs(type(opts.screens) == "table" and opts.screens or L.PhotoScreens()) do
		if not only or only[s.id] then
			local need = true
			if type(s.need) == "function" then
				if opts.passive then
					need = "passive play never opens the game's maps"
				else
					local okN, r = pcall(s.need, W)
					need = okN and r or ("error: " .. show(r))
				end
			end
			if need == true then
				list[#list + 1] = s
			else
				need = tostring(need)
				if not out[need] then
					out[need] = {}
					why[#why + 1] = need
				end
				out[need][#out[need] + 1] = s.id
			end
		end
	end
	local leftOut = {}
	for _, w in ipairs(why) do
		local line = table.concat(out[w], ", ") .. ": " .. w
		leftOut[#leftOut + 1] = line
		L.Log("photo", "left out " .. line)
	end
	if opts.full and #leftOut > 0 then
		say("photo tour: the full tour; left out here: " .. table.concat(leftOut, "; "))
	end
	if #list == 0 and #leftOut > 0 then
		say("photo tour: nothing to shoot (left out " .. table.concat(leftOut, "; ") .. ")")
		return false, "nothing to shoot"
	end
	local plan = planOf(list)
	gen = gen + 1
	local UI = W.UI
	local st = type(UI.state) == "table" and UI.state or {}
	local win = winOf(W)
	tour = {
		gen = gen, saved = {}, seen = {}, list = list, plan = plan, shots = 0, visited = {}, shot = {}, skipped = {}, missed = {},
		rides = {}, failed = {}, click = opts.passive ~= true and (opts.click == true or (L.db and L.db.photoClick == true)) or false,
		passive = opts.passive == true, started = now(), auto = type(opts.auto) == "table" and opts.auto or nil,
		db = snapshot(rawget(_G, "WuberDB") or W.db), wdb = W.db, pos = win and points(win) or nil,
		ui = { shown = fn(UI, "IsShown") and UI.IsShown() or false, tab = st.tab, manual = st.manual, confirmKey = st.confirmKey,
			search = st.filter },
		fakes = L.fakesOn,
	}
	if L.db then
		L.db.photoTour = { started = math.floor(L.Epoch and L.Epoch() or 0), shots = {}, subset = opts.subset,
			ui = (type(UIParent) == "table" and fn(UIParent, "GetWidth")) and { w = num(UIParent:GetWidth()), h = num(UIParent:GetHeight()) } or nil, -- (job 2858) for the exporter's card crop
			leftOut = #leftOut > 0 and leftOut or nil }
	end
	L.Log("photo", ("tour start: %d shots of %d screens, %s%s"):format(#plan, #list, tour.click and "a click per shot" or "automatic shots",
		opts.subset and (", partial tour: " .. opts.subset) or ""))
	L.photo = true
	L.fakesOn = false -- (the fake drivers' beacons wait)
	tour.lab = hideLab()
	local ok, err = pcall(quiet, W)
	if not ok then
		L.Bug("photo quiet", err)
		finish("could not quiet Wuber")
		return false, "could not quiet Wuber"
	end
	buildCatcher():Show()
	local secs = L.PhotoEstimate(#plan)
	say(("%s: %d shots, about %d min %02d s. Hands off (a click anywhere stops it)%s.%s"):format(tour.auto and "Auto check" or "photo tour", #plan,
		math.floor(secs / 60), secs % 60, tour.click and "; click Snap (top right) for each shot" or "",
		#leftOut > 0 and (" Left out " .. table.concat(leftOut, "; ") .. ".") or ""))
	local myGen = gen
	L.After(0.3, function() step(myGen, 1) end)
	return true
end

function L.TourStop(reason)
	if not tour then return nil end
	return finish(reason or "stopped")
end

function L.Touring() return tour ~= nil end

-- The tour never outlives a fight, a logout or a reload (WuberDB is put back before it is saved).
L.On("PLAYER_REGEN_DISABLED", function() if tour then finish("combat") end end)
L.On("PLAYER_LOGOUT", function() if tour then finish("logout") end end)
-- (a tour stopped by a fight puts the window back where it was once the fight is over)
L.On("PLAYER_REGEN_ENABLED", function()
	if L.photoPlace and not tour then
		local pts = L.photoPlace
		L.After(0.3, function() if not tour then putBack(W_(), pts) end end)
	end
end)

L.OnLogin(function()
	if L.db and L.db.photoClick then L.photoClick = true end
end)

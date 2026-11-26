-- Layout scenes for the three messages that can go by themselves (Drive.AutoLines; the decisions round, group R).
-- Installed by tests/layout/extra_screens.lua at its end (X.install calls this file's install), so they work alone
-- (--screen messages_line) and inside a whole sweep.
--   messages_line_greet  the Greeting's editor scrolled to its switch "Send the greeting by itself", switched on
--   messages_line_pay    the editor of Welcome, please pay scrolled to "Send the pay reminder by itself", off
--   messages_line_next   the editor of You're next scrolled to "Send You're next by itself", on
-- Returns install(L, W): adds the screens, returns the ids it added.
local X = {}

local function editorOf(w)
	local m = type(w.UI.drive) == "table" and type(w.UI.drive.screens) == "table" and w.UI.drive.screens.messages
	if type(m) == "table" and type(m.edit) == "function" then return m end
end

-- the message's editor with its switch in view (the switch sits under the preview: the editor is scrolled to its end)
local function show(w, kind, on, scroll)
	local m = editorOf(w)
	if not m then return "no message editor" end
	if not (type(w.Drive) == "table" and type(w.Drive.SetLineOn) == "function") then return "no DR.SetLineOn" end
	w.Drive.SetLineOn(kind, on)
	m.edit(kind)
	local e = m.editor
	local au = type(e) == "table" and e.auto
	if not (au and au:IsShown()) then return "the switch does not show" end
	if (au.toggle.on == true) ~= (on == true) then return "the switch does not follow the saved choice" end
	if not scroll then return true end
	local sc = e:GetParent() and e:GetParent():GetParent()
	-- unfolded, the editor has its own scroll in the side pane: the list beside it starts at its top (the folded
	-- shot before this one left the page's scroll at the editor's end)
	if type(m.scroll) == "table" and sc ~= m.scroll and type(m.scroll.ScrollTo) == "function" then pcall(m.scroll.ScrollTo, m.scroll, 0, true) end
	if type(sc) == "table" and type(sc.ScrollTo) == "function" then pcall(sc.ScrollTo, sc, tonumber(sc.max) or 0, true) end
	return true
end

function X.install(L, W)
	local added = {}
	local ok, M = pcall(W.Mod, "Drive.AutoLines")
	if not (ok and type(M) == "table") then return added end
	local base
	for _, s in ipairs(L.PHOTO_SCREENS) do if s.id == "messages" then base = s end end
	if not (base and type(base.run) == "function") then return added end
	local function scene(id, kind, on, title)
		L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = id, side = "driver", unfold = true, title = title,
			run = function(w)
				local r = base.run(w)
				if r ~= true then return r end
				return show(w, kind, on, false)
			end,
			-- (the tour applies the fold after run: the editor may have moved into the side pane)
			post = function(w) return show(w, kind, on, true) end,
			hide = function()
				if type(W.Drive) == "table" and type(W.Drive.SetLineOn) == "function" then W.Drive.SetLineOn(kind, false) end
			end }
		added[#added + 1] = id
	end
	scene("messages_line_greet", "greet", true, "Messages: the Greeting's editor, its switch Send the greeting by itself, on")
	scene("messages_line_pay", "pay", false, "Messages: the editor of Welcome, please pay, its switch Send the pay reminder by itself, off")
	scene("messages_line_next", "next", true, "Messages: the editor of You're next, its switch Send You're next by itself, on")
	return added
end

return X

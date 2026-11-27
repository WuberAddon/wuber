-- Design round 3, group K, guard 1: tools/check.lua check 10 "text sizes": a number (or an old size name) in the size
-- argument of T.Text, T.SetFont or T.MeasureText, and a font set outside Theme/Tokens.lua (SetFont, SetFontObject,
-- GameFont...) except in C.FONT_ALLOW. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local S = H.state
local root = T.root or H.root
local C = T.CHECK

local function sizes(src, file) return C.scanTextSizes(file or "UI/X.lua", src) end

test("d3 guard: check 10 fails a number in the size argument, anywhere in it", function()
	eq(#sizes('local fs = T.Text(f, 13, "white")'), 1, "a plain number")
	eq(#sizes('T.SetFont(eb, opts.size or 13, "medium")'), 1, "opts.size or 13")
	eq(#sizes('T.SetFont(a, on and 12 or 13, "bold")'), 1, "a conditional of numbers")
	eq(#sizes('T.MeasureText(t, h >= 48 and 16 or "body", "bold")'), 1, "a number beside a name")
	eq(#sizes('T.Text(f,\n\t\t12.5,\n\t\t"white")'), 1, "on its own line")
	eq(#sizes('pcall(T.SetFont, fs, 11, "bold")'), 1, "through pcall")
	eq(sizes('T.Text(f,\n\t12,\n\t"white")')[1].line, 2, "the line of the size")
end)

test("d3 guard: check 10 fails a size name outside the seven (small, price, anything else)", function()
	for _, bad in ipairs({ "small", "price", "huge" }) do
		eq(#sizes('T.Text(f, "' .. bad .. '", "white")'), 1, bad)
	end
	eq(#sizes('T.SetFont(fs, on and "body" or "small", "bold")'), 1, "one bad name in a conditional")
	for _, good in ipairs({ "hero", "display", "title", "heading", "body", "sub", "caption" }) do
		eq(#sizes('T.Text(f, "' .. good .. '", "white", "LEFT", "bold")'), 0, good)
	end
end)

test("d3 guard: check 10 leaves alone what is not a size: other arguments, other calls, comments, the theme file", function()
	eq(#sizes('T.Text(f, "body", "white", "LEFT", "bold", 3)'), 0, "a number in another argument")
	eq(#sizes('T.Text(f, size, "white")'), 0, "a plain variable")
	eq(#sizes('T.Text(f, SIZE.body, "white")'), 0, "a field")
	eq(#sizes('T.Text(f, row.sizes[k2], "white")'), 0, "a name that ends in a digit is no literal")
	eq(#sizes('T.Other(f, 13)  X.Text(f, 13)'), 0, "other calls")
	eq(#sizes('-- T.Text(f, 13, "white")\n--[[ T.Text(f, 13) ]]'), 0, "comments")
	eq(#C.scanTextSizes("Theme/Tokens.lua", 'T.SetFont(fs, 13, "bold")'), 0, "Theme/Tokens.lua is exempt")
end)

test("d3 guard: check 10 fails a font set past the theme, within the allowance of C.FONT_ALLOW", function()
	local function fonts(src, file, allow) return C.scanFonts(file or "UI/X.lua", src, allow or {}) end
	eq(#fonts('fs:SetFont("Fonts\\FRIZQT__.TTF", 13, "")'), 1, ":SetFont")
	eq(#fonts('pcall(fs.SetFont, fs, path, 14)'), 1, "fs.SetFont")
	eq(#fonts('fs:SetFontObject(GameFontNormal)'), 2 - 1, "SetFontObject and GameFontNormal on one line is one line")
	eq(#fonts('local fs = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")'), 1, "a GameFont name")
	eq(#fonts('T.SetFont(fs, "body", "bold")'), 0, "T.SetFont is the way")
	eq(#fonts('pcall(T.SetFont, fs, "body", "bold")'), 0, "T.SetFont through pcall")
	eq(#fonts('-- fs:SetFont(a, 1)\nlocal x = "GameFontNormal"'), 1, "a comment is free, a string is code")
	eq(#fonts('fs:SetFont(a, 1)', "Theme/Tokens.lua"), 0, "Theme/Tokens.lua is the owner")
	eq(#fonts('fs:SetFont(a, 1)', "UI/X.lua", { ["UI/X.lua"] = 1 }), 0, "inside its allowance")
	eq(#fonts('fs:SetFont(a, 1)\nfs:SetFont(b, 2)', "UI/X.lua", { ["UI/X.lua"] = 1 }), 1, "one line over it")
	for file, n in pairs(C.FONT_ALLOW) do ok(type(n) == "number" and n >= 1 and file:match("%.lua$"), "FONT_ALLOW entry " .. file) end
end)

test("d3 guard: check 10 reads through the whole check (a size number and a raw font each fail a made-up file)", function()
	local files = { "Wuber/Load.lua" }
	local src = { ["Wuber/Load.lua"] = 'local _, W = ...\nlocal fs = W.Theme.Text(nil, 13)\nlocal T = W.Theme\nT.Text(nil, 13, "white")\nfs:SetFont("x", 12)\n' }
	local res = C.check({ files = files, read = function(p) return src[p] end, globals = nil, owner = {}, forbidden = {}, root = root })
	local n = 0
	for _, f in ipairs(res.fails) do if f:find("text size:", 1, true) or f:find("font:", 1, true) then n = n + 1 end end
	eq(n, 2, "two failures: " .. table.concat(res.fails, " | "))
end)


local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local N = { "Ana Smith", "Bea Jones", "Cal Brown" }
local function saved(me)
  local crew, own = {}, {}
  for _, n in ipairs(N) do if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true }; own[key(n)] = true end end
  return { chars = { [key(me)] = { crew = crew, captain = (me == N[1]) and "" or N[1], wizard = true, bookOwn = own } } }
end
test("r34 g2: AUD-140 a 100-customer book reaches a crew window once, not twice, when two windows ask together", function()
  local w = H.NewWorld({})
  local cs = {}
  for i, n in ipairs(N) do cs[i] = w:addClient(n, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = saved(n) } }) end
  local ana, bea, cal = cs[1], cs[2], cs[3]
  w:advance(2)
  for i = 1, 100 do ok(ana.W.Drive.SetNote("Customer" .. string.char(64 + i % 26 + 1) .. string.char(97 + i % 7) .. i, "note " .. i), "note " .. i) end
  w:group(N)
  -- Ana's records only: Bea and Cal number what they receive in their own books (by design), so each
  -- later offers its copy to the other; that relay is not Ana whispering her book again
  local function recordsTo(name)
    local n = 0
    for _, e in ipairs(w.addonLog) do
      if e.prefix == "WUBERT" and e.from == N[1] and e.target == name and e.text:match("^BKR~") then n = n + 1 end
    end
    return n
  end
  for _ = 1, 40 do w:advance(10) end
  local nb, nc = #bea.W.Drive.Customers(), #cal.W.Drive.Customers()
  ok(nb == 100 and nc == 100, "control: both windows end with all 100 customers (Bea " .. nb .. ", Cal " .. nc .. ")")
  local rb, rc = recordsTo(N[2]), recordsTo(N[3])
  ok(rb <= 110, "control: Ana sent Bea her 100 records once (" .. rb .. " sent)")
  ok(rc <= 110, "Ana sent Cal " .. rc .. " record whispers for a 100-record book: his open ask timed out (90 s) while Bea's 100 drained first, his end-marker was dropped, and Ana sent everything again")
  T.clean(w)
end)
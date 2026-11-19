-- Dropamine 3.5.15 — textes des toasts toujours lisibles en entier.
-- Après création (et mise à jour) d'un toast, chaque ligne de texte est
-- mesurée (GetUnboundedStringWidth, sinon GetStringWidth). Si elle dépasse la
-- place disponible : retour à la ligne (2 lignes au plus) et le toast grandit
-- en hauteur ; la pile est remise en place. Largeur, style et police inchangés.
-- Rien au repos : une mesure à la création, une autre à la frame suivante
-- (les thèmes peuvent changer la police juste après).
local ADDON, ns = ...
local UI = ns.UI
local TF = {}
ns.ToastFit = TF
TF.MAX_LINES = 2
TF.stats = { fitted = 0, wrapped = 0, cut = 0 }

local function N(v) return ns.N and ns.N(v) or tonumber(v) end
local function Get(o, m, ...)
  if type(o) ~= "table" or type(o[m]) ~= "function" then return nil end
  local ok, a, b = pcall(o[m], o, ...)
  if ok then return a, b end
  return nil
end

local function TextWidth(fs)
  local w = N(Get(fs, "GetUnboundedStringWidth"))
  if not w or w <= 0 then w = N(Get(fs, "GetStringWidth")) end
  return w or 0
end
local function LineHeight(fs)
  local _, size = Get(fs, "GetFont")
  size = N(size) or 10
  local sp = N(Get(fs, "GetSpacing")) or 0
  return math.floor(size + sp + 2 + 0.5)
end
-- place disponible : du bord gauche du texte au bord droit du toast, moins 8
local function Avail(f, fs)
  local fl, fw = N(Get(f, "GetLeft")), N(Get(f, "GetWidth"))
  local sl = N(Get(fs, "GetLeft"))
  if fl and fw and sl and fw > 0 then return fw - (sl - fl) - 8 end
  local w = N(Get(fs, "GetWidth"))
  if w and w > 0 then return w end
  -- repli : largeur du toast moins icône et marges
  local dw = (UI and UI.DropWidth and N(select(2, pcall(UI.DropWidth, UI)))) or N(fw) or 260
  local icon = (f._light and 20) or 32
  return dw - (7 + icon + 7) - 8
end

function TF.Fit(f)
  if type(f) ~= "table" or not f.titleFS then return false end
  f._tfBaseH = f._tfBaseH or N(f._h) or N(Get(f, "GetHeight"))
  if not f._tfBaseH then return false end
  local extra, notes = 0, {}
  for _, key in ipairs({ "titleFS", "subFS", "hintFS" }) do
    local fs = f[key]
    if type(fs) == "table" and Get(fs, "IsShown") ~= false then
      local txt = Get(fs, "GetText")
      -- état de départ : une ligne
      if fs._tfWrapped then
        pcall(fs.SetWordWrap, fs, false)
        if fs.SetMaxLines then pcall(fs.SetMaxLines, fs, 1) end
        if fs._tfH then pcall(fs.SetHeight, fs, fs._tfH) end
        fs._tfWrapped = nil
      end
      if type(txt) == "string" and txt ~= "" then
        local need, room = TextWidth(fs), Avail(f, fs)
        if room and room > 20 and need > room + 1 then
          local lh = LineHeight(fs)
          fs._tfH = fs._tfH or N(Get(fs, "GetHeight"))
          pcall(fs.SetWordWrap, fs, true)
          if fs.SetMaxLines then pcall(fs.SetMaxLines, fs, TF.MAX_LINES) end
          if fs.SetNonSpaceWrap then pcall(fs.SetNonSpaceWrap, fs, false) end
          pcall(fs.SetHeight, fs, lh * TF.MAX_LINES)
          fs._tfWrapped = true
          extra = extra + lh
          TF.stats.wrapped = TF.stats.wrapped + 1
          if need > room * TF.MAX_LINES then TF.stats.cut = TF.stats.cut + 1 end
          notes[#notes + 1] = string.format("%s %.0f/%.0f", key, need, room)
        end
      end
    end
  end
  local h = f._tfBaseH + extra
  if h ~= f._h then
    f._h = h
    pcall(f.SetHeight, f, h)
    if UI and UI.PackDrops then pcall(UI.PackDrops, UI) end
  end
  TF.stats.fitted = TF.stats.fitted + 1
  if #notes > 0 then TF.last = table.concat(notes, ", ") .. " → hauteur " .. tostring(h) end
  return true
end
local function FitSoon(f)
  pcall(TF.Fit, f)
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
    _G.C_Timer.After(0, function() pcall(TF.Fit, f) end)
  end
end

if UI and UI.SpawnDrop then
  local base = UI.SpawnDrop
  function UI:SpawnDrop(...)
    local f = base(self, ...)
    if f then FitSoon(f) end
    return f
  end
end
-- titre changé ensuite (cumul « +1 » → « +2 ») : nouvelle mesure
if UI and UI.BumpDropTitle then
  local baseBump = UI.BumpDropTitle
  function UI:BumpDropTitle(o, ...)
    local r = { baseBump(self, o, ...) }
    if o then FitSoon(o) end
    return unpack(r)
  end
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local s = TF.stats
  return { string.format("— Textes des toasts (3.5.15) — mesurés %d, passés à la ligne %d, encore trop longs (coupés à %d lignes) %d%s",
    s.fitted, s.wrapped, TF.MAX_LINES, s.cut, TF.last and (" ; dernier : " .. TF.last) or "") }
end

-- Dropamine — Tip.lua (3.3.8)
-- Infobulle de créature COMPACTE : au plus 3 lignes ajoutées, une par métier.
--   vert  « Secourisme +1 : Anti-venin, Cataplasme »  (recettes connues qui montent)
--   vert  « Dépeçage +1 · requis 115 »
--   gris  « Cuisine : 4 recettes à apprendre »         (aucun gain possible)
--   rouge « Dépeçage : rang 115 requis »
-- Pas de nom de créature (déjà en titre), pas de flèche (absente de la police),
-- pas de « source inconnue ». Détail complet seulement tant que Maj est
-- enfoncée (MODIFIER_STATE_CHANGED → l'infobulle est reconstruite).
local ADDON, ns = ...
local Tip = {}
ns.Tip = Tip
Tip.active = true      -- = option « infobulle compacte » (/drop infobulle compacte|detail)
function Tip.Sync() Tip.active = ns.Opt("tipCompact") and true or false return Tip.active end
Tip.MAX = 3            -- lignes ajoutées en mode compact
Tip.NAMES = 2          -- recettes citées sur une ligne verte
Tip.DETAIL_CAP = 6     -- par métier, en mode Maj
Tip.stats = { builds = 0, refresh = 0 }
Tip.GREEN, Tip.GREY, Tip.RED = { 0.25, 1, 0.25 }, { 0.6, 0.6, 0.6 }, { 0.8, 0.4, 0.4 }
local GAIN = { optimal = true, medium = true, easy = true }
local ORDER = { skinning = 1, cooking = 2, firstaid = 3 }

local function Call(fn, ...) if type(fn) ~= "function" then return nil end local ok, a, b = pcall(fn, ...) if ok then return a, b end end
local function InCombat() return Call(_G.InCombatLockdown) and true or false end
local function SkillName(id) local e = ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[id] return e and e.name or tostring(id) end
local function Clean(s) s = tostring(s or "") s = s:gsub("%s*→%s*", " : ") return s end
function Tip.Shift() return Call(_G.IsShiftKeyDown) and true or false end

-- Groupes par métier : { skill, color, text, detail = { {text, color} } }
function Tip.Groups(tt, unit)
  local groups = {}
  local G, S, L = ns.Gather, ns.Scanner, ns.Links
  -- Dépeçage
  local st = G and G.UnitState and G.UnitState(tt, unit)
  if st then
    local g = { skill = "skinning", detail = { { Clean(st.text), st.color or Tip.GREY } } }
    if G.GivesPoints(st) then
      g.gain, g.color, g.text = true, Tip.GREEN, "Dépeçage +1" .. (st.req and (" · requis " .. st.req) or "")
    elseif st.diff == "locked" then
      g.color, g.text = Tip.RED, "Dépeçage : rang " .. tostring(st.req or "?") .. " requis"
    elseif st.diff == "capped" then
      g.color, g.text = Tip.GREY, "Dépeçage : plafond atteint"
    else
      g.color, g.text = Tip.GREY, "Dépeçage : gris (aucun point)"
    end
    groups[#groups + 1] = g
  end
  -- Recettes (tous métiers) qui utilisent le butin / les peaux de la créature
  if S and S.Enabled and S.Enabled() and L and L.Lines and ns.Opt("links") then
    local id = S.UnitNpcID(unit)
    if id then
      local _, seen = S.NoteUnit(unit)
      local info = { name = seen and seen.name, family = seen and seen.family, ctype = seen and seen.ctype, alive = not Call(_G.UnitIsDead, unit) }
      local c = S.CreatureFor(id, info)
      if c then
        local _, all = L.Lines(L.CreatureItems(c), { cap = 999 })
        local by = {}
        for _, e in ipairs(all or {}) do
          local b = by[e.skill]
          if not b then b = { gain = {}, grey = {}, learn = {} } by[e.skill] = b end
          if e.learned == true then
            if GAIN[e.diff] then b.gain[#b.gain + 1] = e else b.grey[#b.grey + 1] = e end
          else b.learn[#b.learn + 1] = e end
        end
        for skill, b in pairs(by) do
          local fr = SkillName(skill)
          local g = { skill = skill, detail = {} }
          if #b.gain > 0 then
            local names = {}
            for i = 1, math.min(Tip.NAMES, #b.gain) do names[i] = b.gain[i].name end
            g.gain, g.color = true, Tip.GREEN
            g.text = fr .. " +1 : " .. table.concat(names, ", ") .. ((#b.gain > Tip.NAMES) and (" (+" .. (#b.gain - Tip.NAMES) .. ")") or "")
          elseif #b.learn > 0 then
            g.color, g.text = Tip.GREY, string.format("%s : %d recette%s à apprendre", fr, #b.learn, #b.learn > 1 and "s" or "")
          else
            g.color, g.text = Tip.GREY, fr .. " : recettes grises (aucun point)"
          end
          local function add(e, txt)
            local col = (e.diff == "locked") and Tip.RED or ((S.DiffColor and S.DiffColor(e.diff)) or Tip.GREY)
            g.detail[#g.detail + 1] = { txt, col }
          end
          local list = {}
          for _, e in ipairs(b.gain) do list[#list + 1] = e end
          for _, e in ipairs(b.learn) do list[#list + 1] = e end
          for _, e in ipairs(b.grey) do list[#list + 1] = e end
          for i, e in ipairs(list) do
            if i > Tip.DETAIL_CAP then
              g.detail[#g.detail + 1] = { "… et " .. (#list - Tip.DETAIL_CAP) .. " autres", Tip.GREY }
              break
            end
            if e.learned == true then add(e, e.name .. ((e.req and (" · rang " .. e.req)) or ""))
            else add(e, e.name .. " · à apprendre, rang " .. tostring(e.req or "?") .. (e.learn and (" · " .. e.learn) or "")) end
          end
          -- 3.3.14 : une seule ligne par métier (le Dépeçage a déjà la sienne) :
          -- la ligne « gain » l'emporte, la ligne grise est abandonnée.
          local ex
          for _, og in ipairs(groups) do if og.skill == skill then ex = og end end
          if ex then
            if g.gain and not ex.gain then ex.gain, ex.color, ex.text = true, g.color, g.text end
            for _, dl in ipairs(g.detail) do ex.detail[#ex.detail + 1] = dl end
          else
            groups[#groups + 1] = g
          end
        end
      end
    end
  end
  table.sort(groups, function(a, b)
    if (a.gain and true or false) ~= (b.gain and true or false) then return a.gain and true or false end
    local oa, ob = ORDER[a.skill] or 9, ORDER[b.skill] or 9
    if oa ~= ob then return oa < ob end
    return tostring(a.skill) < tostring(b.skill)
  end)
  return groups
end

-- Lignes à ajouter : compact (≤ 3) ou détail (Maj).
function Tip.Lines(groups, shift)
  local out = {}
  if not shift then
    for i = 1, math.min(Tip.MAX, #groups) do out[#out + 1] = { groups[i].text, groups[i].color } end
  else
    for _, g in ipairs(groups) do
      out[#out + 1] = { g.text, g.color }
      for _, d in ipairs(g.detail) do out[#out + 1] = { "   " .. d[1], d[2] } end
    end
  end
  return out
end

local function HasLine(tt, text)
  local name = tt.GetName and tt:GetName()
  local n = (tt.NumLines and tt:NumLines()) or 0
  for i = 1, n do
    local fs = name and _G[name .. "TextLeft" .. i]
    local t = fs and fs.GetText and fs:GetText()
    if t == text then return true end
  end
  return false
end

function Tip.UnitTooltip(tt, unit)
  if InCombat() or type(tt) ~= "table" then return nil end
  unit = unit or "mouseover"
  if not Call(_G.UnitName, unit) or Call(_G.UnitIsPlayer, unit) then return nil end
  Tip.stats.builds = Tip.stats.builds + 1
  if ns.Gather then ns.Gather.stats.tooltips = ns.Gather.stats.tooltips + 1 end
  local groups = Tip.Groups(tt, unit)
  local shift = Tip.Shift()
  local lines = Tip.Lines(groups, shift)
  Tip.lastMore = (#Tip.Lines(groups, true) > #Tip.Lines(groups, false))
  Tip.last = { n = #lines, shift = shift, groups = #groups }
  if #lines == 0 or HasLine(tt, lines[1][1]) then return #lines end
  for _, l in ipairs(lines) do
    local c = l[2] or Tip.GREY
    pcall(tt.AddLine, tt, l[1], c[1], c[2], c[3])
  end
  if tt.Show then pcall(tt.Show, tt) end
  return #lines
end

function Tip.Hook()
  if Tip._hooked then return end
  local tt = _G.GameTooltip
  if type(tt) ~= "table" then return end
  Tip._hooked = true
  if type(_G.TooltipDataProcessor) == "table" and type(_G.TooltipDataProcessor.AddTooltipPostCall) == "function"
    and _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Unit then
    pcall(_G.TooltipDataProcessor.AddTooltipPostCall, _G.Enum.TooltipDataType.Unit, function(t) if t == tt then pcall(Tip.UnitTooltip, t) end end)
    Tip.ttMode = "TooltipDataProcessor"
  elseif tt.HookScript then
    pcall(tt.HookScript, tt, "OnTooltipSetUnit", function(t) pcall(Tip.UnitTooltip, t) end)
    Tip.ttMode = "OnTooltipSetUnit"
  end
end

-- Maj enfoncée / relâchée pendant que l'infobulle d'une créature est affichée :
-- on la reconstruit (SetUnit) pour passer du compact au détail et inversement.
function Tip.OnModifier(key)
  if key ~= "LSHIFT" and key ~= "RSHIFT" then return false end
  local tt = _G.GameTooltip
  if type(tt) ~= "table" or not (tt.IsShown and tt:IsShown()) or not Tip.lastMore then return false end
  local _, unit = Call(tt.GetUnit, tt)
  if not unit or InCombat() then return false end
  Tip.stats.refresh = Tip.stats.refresh + 1
  pcall(tt.SetUnit, tt, unit)
  return true
end

if ns.On then
  ns.On("PLAYER_LOGIN", function() Tip.Sync() Tip.Hook() end)
  ns.On("MODIFIER_STATE_CHANGED", function(_, key) pcall(Tip.OnModifier, key) end)
end
ns.DebugExt = ns.DebugExt or {}
do
  ns.DebugExt[#ns.DebugExt + 1] = function()
    return { string.format("infobulle créature : compacte (≤ %d lignes, détail avec Maj) ; %d constructions, %d rafraîchissements Maj ; accroche %s",
      Tip.MAX, Tip.stats.builds, Tip.stats.refresh, tostring(Tip.ttMode or "non accrochée")) }
  end
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "Infobulle de créature : une ligne par métier (3 max) ; maintenir Maj pour le détail"

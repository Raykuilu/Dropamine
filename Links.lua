-- Dropamine 3.3.5 — liens entre métiers, poussés au maximum AVEC LES
-- DONNÉES PRÉSENTES DANS L'ADDON (aucune donnée inventée) :
--   * pour un objet (infobulle d'objet, de créature, de cadavre) : TOUTES les
--     recettes qui l'utilisent, apprises (fenêtres de métier lues : tous les
--     métiers du personnage) et non apprises (base Forever : Cuisine,
--     Secourisme), avec rang requis, couleur de difficulté à ton rang et où
--     l'apprendre quand la base le dit (« t » = maître ; sinon « source
--     inconnue ») ;
--   * lien inverse dans l'infobulle d'une case de métier : prochaines recettes
--     non apprises à portée (rang requis ≤ ton rang + 25), où les apprendre et
--     d'où viennent leurs composants (dépeçage / butin de N créatures de la
--     base / créatures apprises en jeu).
-- Les fournisseurs (nom + zone) et les recettes non apprises des autres
-- métiers ne sont PAS dans la base de l'addon : affichés « source inconnue ».
local ADDON, ns = ...
local S = ns.Scanner
local Craft = ns.Craft
local L = {}
ns.Links = L

L.CAP = 6
L.REACH = 25
local SKILL_FR = { cooking = "Cuisine", firstaid = "Secourisme" }
-- 3.3.8 : source absente de la base → rien d'affiché (plus de « source inconnue »)
local LEARN_FR = { t = "maître" }

local function SkillName(id)
  local e = ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[id]
  return (e and e.name) or SKILL_FR[id] or tostring(id)
end
local function Fold(s) return ns.Fold(s or "") end

-- Base Forever : toutes les recettes (Cuisine / Secourisme), index par nom et
-- par composant ; source d'apprentissage (dernier champ).
function L.DB()
  if L._db then return L._db end
  local db = ns.ScannerDB
  local byName, byItem, bySkill = {}, {}, {}
  local CODE = { c = "cooking", f = "firstaid" }
  for spell, raw in pairs(db and db.recipes or {}) do
    local p = {}
    for part in string.gmatch(raw, "[^|]+") do p[#p + 1] = part end
    local skill = CODE[p[1] or ""]
    if skill and p[2] and tonumber(p[2]) then
      local col = {}
      for v in string.gmatch(p[3] or "", "[^,]+") do col[#col + 1] = tonumber(v) end
      local r = { spell = spell, skill = skill, req = tonumber(p[2]), colors = col, en = p[5], fr = p[6], name = p[6] or p[5],
        learn = LEARN_FR[p[7] or "-"], reagents = {} }
      for id, n in string.gmatch(p[4] or "", "(%d+)x(%d+)") do r.reagents[#r.reagents + 1] = { id = tonumber(id), count = tonumber(n) } end
      if r.fr then byName[Fold(r.fr)] = r end
      if r.en then byName[Fold(r.en)] = r end
      for _, rg in ipairs(r.reagents) do byItem[rg.id] = byItem[rg.id] or {} table.insert(byItem[rg.id], r) end
      bySkill[skill] = bySkill[skill] or {}
      table.insert(bySkill[skill], r)
    end
  end
  L._db = { byName = byName, byItem = byItem, bySkill = bySkill }
  return L._db
end

local function Known(skill)
  local rec = ns.CharDB().recipes and ns.CharDB().recipes[skill]
  return rec and rec.list or nil
end
local function IsLearned(skill, r)
  local list = Known(skill)
  if not list then return nil end   -- inconnu : fenêtre jamais lue
  for _, k in ipairs(list) do
    local f = Fold(k.name)
    if f == Fold(r.fr) or f == Fold(r.en) then return true end
  end
  return false
end

-- Caches (par objet) vidés quand les recettes lues ou un rang changent :
-- aucune recherche répétée à chaque infobulle.
L.stats = { uses = 0, usesMiss = 0, origin = 0, originMiss = 0 }
L._rankVer = 0
local function CacheKey() return tostring(Craft._ver or 0) .. ":" .. tostring(L._rankVer) .. ":" .. tostring(S._learnVer or 0) end
local function Cache()
  local k = CacheKey()
  if L._ck ~= k then L._ck, L._uses, L._origin = k, {}, {} end
  return L._uses, L._origin
end
function L.Invalidate() L._rankVer = L._rankVer + 1 end
if ns.On then ns.On("CHAT_MSG_SKILL", function() L.Invalidate() end) end

function L.UsesOf(itemID)
  if not itemID then return {} end
  local uc = Cache()
  L.stats.uses = L.stats.uses + 1
  local hit = uc[itemID]
  if hit then return hit end
  L.stats.usesMiss = L.stats.usesMiss + 1
  local out = L.UsesOfRaw(itemID)
  uc[itemID] = out
  return out
end
function L.UsesOfRaw(itemID)
  local out, seen = {}, {}
  local D = L.DB()
  -- 1) recettes lues dans les fenêtres de métier (tous les métiers)
  for skill, rec in pairs(ns.CharDB().recipes or {}) do
    local rank = S.RankOf(skill)
    if rank and rank > 0 then
      for _, r in ipairs(rec.list or {}) do
        for _, rg in ipairs(r.reagents or {}) do
          if rg.id == itemID then
            local dbr = D.byName[Fold(r.name)]
            local key = skill .. "|" .. Fold(r.name)
            if not seen[key] then
              seen[key] = true
              out[#out + 1] = { name = r.name, skill = skill, req = dbr and dbr.req or nil, learned = true,
                diff = Craft.Diff(dbr and { colors = dbr.colors, diff = r.diff } or r, rank) or r.diff, rank = rank }
            end
            break
          end
        end
      end
    end
  end
  -- 2) base Forever : recettes non apprises (ou statut inconnu)
  for _, r in ipairs(D.byItem[itemID] or {}) do
    local rank = S.RankOf(r.skill)
    local key = r.skill .. "|" .. Fold(r.name)
    if rank and rank > 0 and not seen[key] then
      local learned = IsLearned(r.skill, r)
      if learned ~= true then
        seen[key] = true
        local diff = (rank >= r.req) and Craft.Diff(r, rank) or "locked"
        out[#out + 1] = { name = r.name, skill = r.skill, req = r.req, learned = learned, diff = diff, rank = rank, learn = r.learn }
      end
    end
  end
  local ORD = { optimal = 4, medium = 3, easy = 2, trivial = 1, locked = 0 }
  table.sort(out, function(a, b)
    if (a.learned == true) ~= (b.learned == true) then return a.learned == true end
    local oa, ob = ORD[a.diff or ""] or 0, ORD[b.diff or ""] or 0
    if oa ~= ob then return oa > ob end
    return tostring(a.name) < tostring(b.name)
  end)
  return out
end

local function Paint(diff, txt, dim)
  local c
  if diff == "locked" then c = { 0.70, 0.38, 0.38 }
  else c = (S.DiffColor and S.DiffColor(diff)) or { 1, 1, 1 } end
  local k = dim and 0.75 or 1
  return string.format("|cff%02x%02x%02x%s|r", math.floor(c[1] * 255 * k), math.floor(c[2] * 255 * k), math.floor(c[3] * 255 * k), txt)
end
function L.EntryText(e)
  if e.learned == true then
    return Paint(e.diff, string.format("%s — %s%s", e.name, SkillName(e.skill), e.req and (" " .. e.req) or ""))
  end
  local status = (e.learned == false) and "recette non apprise" or "apprise ? (ouvre la fenêtre du métier)"
  return Paint(e.diff, string.format("%s (%s, rang %s) — %s%s", e.name, status, tostring(e.req or "?"), SkillName(e.skill), e.learn and (" · " .. e.learn) or ""), true)
end

-- Lignes plafonnées (6 + « … et N autres ») pour un ou plusieurs objets.
function L.Lines(items, opts)
  opts = opts or {}
  local all, seen = {}, {}
  local ex = opts.exclude or {}
  for _, id in ipairs(items or {}) do
    for _, e in ipairs(L.UsesOf(id)) do
      local key = e.skill .. "|" .. Fold(e.name)
      -- 3.3.8 : option « recettes non apprises » (/drop nonapprises)
      local hide = (e.learned ~= true) and ns.Opt and not ns.Opt("unlearned")
      if not seen[key] and not ex[Fold(e.name)] and not hide then
        seen[key] = true
        all[#all + 1] = e
      end
    end
  end
  local cap = opts.cap or L.CAP
  local lines = {}
  for i = 1, math.min(cap, #all) do lines[i] = L.EntryText(all[i]) end
  if #all > cap then lines[#lines + 1] = "|cff999999… et " .. (#all - cap) .. " autres|r" end
  return lines, all
end

-- Objets d'une créature (butin + dépeçage), triés pour un affichage stable.
function L.CreatureItems(c)
  local out, seen = {}, {}
  for id in pairs(c and c.items or {}) do if not seen[id] then seen[id] = true out[#out + 1] = id end end
  for _, id in ipairs(c and c.skinItems or {}) do if not seen[id] then seen[id] = true out[#out + 1] = id end end
  table.sort(out)
  return out
end

-- Origine d'un composant : dépeçage, butin de créatures (base + appris).
function L.ItemOrigin(itemID)
  local _, oc = Cache()
  L.stats.origin = L.stats.origin + 1
  if oc[itemID] then return oc[itemID] end
  L.stats.originMiss = L.stats.originMiss + 1
  local v = L.ItemOriginRaw(itemID)
  oc[itemID] = v
  return v
end
function L.ItemOriginRaw(itemID)
  local db = ns.ScannerDB
  local parts = {}
  local nSkin, nDrop = 0, 0
  if not L._skinIdx then
    local idx = {}
    for _, raw in pairs(db and db.skin or {}) do
      for id in string.gmatch(raw, "%d+") do id = tonumber(id) idx[id] = (idx[id] or 0) + 1 end
    end
    L._skinIdx = idx
  end
  nSkin = L._skinIdx[itemID] or 0
  if not L._dropIdx then
    local idx = {}
    for npc, raw in pairs(db and db.drops or {}) do
      for id in string.gmatch(raw, "(%d+):%d+") do id = tonumber(id) idx[id] = (idx[id] or 0) + 1 end
    end
    L._dropIdx = idx
  end
  nDrop = L._dropIdx[itemID] or 0
  local names = {}
  for _, c in pairs(S.DB().creatures or {}) do
    if c.items and c.items[itemID] and c.name and #names < 2 then names[#names + 1] = c.name end
  end
  if nSkin > 0 then parts[#parts + 1] = "dépeçage (" .. nSkin .. " créatures)" end
  if nDrop > 0 then parts[#parts + 1] = "butin de " .. nDrop .. " créature" .. (nDrop > 1 and "s" or "") end
  if #names > 0 then parts[#parts + 1] = "vu sur " .. table.concat(names, ", ") end
  if #parts == 0 then return "origine inconnue (marchand ou autre)" end
  return table.concat(parts, " ; ")
end
local function ItemName(id)
  local it = S.StaticItem and S.StaticItem(id)
  if it and (it.fr or it.en) then return it.fr or it.en end
  local ok, nm = pcall(_G.GetItemInfo or function() end, id)
  if ok and type(nm) == "string" then return nm end
  return "objet " .. tostring(id)
end

-- Lien inverse : prochaines recettes à apprendre pour un métier.
function L.NextToLearn(skill)
  local D = L.DB()
  local rank = S.RankOf(skill)
  local out = {}
  if not rank or rank <= 0 then return out, "métier non appris" end
  if not D.bySkill[skill] then return out, "aucune recette de ce métier dans la base Forever de l'addon" end
  if not Known(skill) then return out, "ouvre la fenêtre du métier une fois pour savoir ce qui est appris" end
  for _, r in ipairs(D.bySkill[skill]) do
    if r.req <= rank + L.REACH and IsLearned(skill, r) == false then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) if a.req ~= b.req then return a.req < b.req end return tostring(a.name) < tostring(b.name) end)
  return out
end
function L.NextLines(skill)
  if ns.Opt and not ns.Opt("unlearned") then return {} end
  local list, why = L.NextToLearn(skill)
  local lines = {}
  if #list == 0 then
    if why then lines[1] = "|cff999999" .. why .. "|r" end
    return lines
  end
  local rank = S.RankOf(skill)
  local cap = 4
  for i = 1, math.min(cap, #list) do
    local r = list[i]
    local diff = rank >= r.req and Craft.Diff(r, rank) or "locked"
    lines[#lines + 1] = Paint(diff, string.format("%s (rang %d)%s", r.name, r.req, r.learn and (" · " .. r.learn) or ""))
    local comp = {}
    for _, rg in ipairs(r.reagents) do comp[#comp + 1] = rg.count .. " × " .. ItemName(rg.id) .. " : " .. L.ItemOrigin(rg.id) end
    for _, cl in ipairs(comp) do lines[#lines + 1] = "|cffbbbbbb    " .. cl .. "|r" end
  end
  if #list > cap then lines[#lines + 1] = "|cff999999… et " .. (#list - cap) .. " autres|r" end
  return lines
end

-- Infobulle de case de métier (Compact) : section « À apprendre bientôt ».
if ns.Compact and ns.Compact.TooltipModel then
  local baseModel = ns.Compact.TooltipModel
  function ns.Compact.TooltipModel(d)
    local m = baseModel(d)
    if d and d.id and not d.placeholder and (d.kind == "profession" or d.kind == "secondary") and L.DB().bySkill[d.id] then
      local ok, lines = pcall(L.NextLines, d.id)
      if ok and lines and #lines > 0 then
        m.lines[#m.lines + 1] = { " ", 1, 1, 1, false, spacer = true }
        m.lines[#m.lines + 1] = { "À apprendre bientôt", 1, 0.82, 0, false, header = true }
        for _, l in ipairs(lines) do m.lines[#m.lines + 1] = { l, 1, 1, 1, true } end
      end
    end
    return m
  end
end

-- Infobulle d'objet (sacs, butin, liens) : « Utilisé par ».
function L.ItemTooltip(tt)
  if type(tt) ~= "table" or not tt.GetItem then return nil end
  if ns.Opt and not ns.Opt("links") then return nil end   -- 3.3.8 : /drop liens off
  if S.InCombat and S.InCombat() then return nil end
  local ok, _, link = pcall(tt.GetItem, tt)
  local id = ok and S.ItemIDFromLink(link)
  if not id then return nil end
  if tt._osrsLinksFor == id then return nil end
  local lines = L.Lines({ id })
  if #lines == 0 then return 0 end
  tt._osrsLinksFor = id
  pcall(tt.AddLine, tt, "Utilisé par :", 1, 0.82, 0)
  for _, l in ipairs(lines) do pcall(tt.AddLine, tt, l, 1, 1, 1, true) end
  if tt.Show then pcall(tt.Show, tt) end
  return #lines
end
function L.HookItemTooltip()
  if L._hooked then return end
  local tt = _G.GameTooltip
  if type(tt) ~= "table" then return end
  L._hooked = true
  if type(_G.TooltipDataProcessor) == "table" and type(_G.TooltipDataProcessor.AddTooltipPostCall) == "function"
    and _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Item then
    pcall(_G.TooltipDataProcessor.AddTooltipPostCall, _G.Enum.TooltipDataType.Item, function(t) if t == tt then pcall(L.ItemTooltip, t) end end)
    L.ttMode = "TooltipDataProcessor"
  elseif tt.HookScript then
    pcall(tt.HookScript, tt, "OnTooltipSetItem", function(t) pcall(L.ItemTooltip, t) end)
    pcall(tt.HookScript, tt, "OnTooltipCleared", function(t) t._osrsLinksFor = nil end)
    L.ttMode = "OnTooltipSetItem"
  end
end
if ns.On then ns.On("PLAYER_LOGIN", function() L.HookItemTooltip() end) end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local D = L.DB()
  local n = 0 for _, l in pairs(D.bySkill) do n = n + #l end
  return { "— Liens entre métiers (3.3.5) —", "  recettes de la base indexées (Cuisine / Secourisme) : " .. n
    .. " ; autres métiers : seulement les recettes lues en jeu ; fournisseurs : absents de la base (« source inconnue ») ; infobulle d'objet : " .. tostring(L.ttMode or "non accrochée") }
end

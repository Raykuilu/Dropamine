-- Dropamine 2.8.1 : recettes connues, couleur de difficulté, créatures utiles
-- au scanner, recettes réalisables avec le contenu des sacs (tous les métiers de
-- fabrication). Lecture seule des fenêtres de métier ; rien en combat.
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local Craft = {}
ns.Craft = Craft
local S = ns.Scanner

local function N(v) return ns.N(v) end
local function Str(v)
  if v == nil or (ns.IsSecret and ns.IsSecret(v)) then return nil end
  if type(v) ~= "string" or v == "" then return nil end
  return v
end
-- 3.6.0 : sans table temporaire (appelé sur les événements fréquents : survol,
-- barres de nom, cible) et sans troncature aux valeurs nil intermédiaires.
local function Ret(ok, ...) if not ok then return nil end return ... end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  return ns.Unsecret(Ret(pcall(fn, ...)))
end
local function InCombat() return S and S.InCombat and S.InCombat() end

-- Métiers de fabrication (badge, détail, drop « réalisable »). Les métiers de
-- récolte seuls (Dépeçage, Herboristerie, Pêche) n'en ont pas.
Craft.SKILLS = { leatherworking = true, blacksmithing = true, tailoring = true, alchemy = true,
  engineering = true, enchanting = true, mining = true, cooking = true, firstaid = true,
  -- 3.5.12 : sur Forever, les métiers de récolte ont aussi leur fenêtre et des recettes
  skinning = true, herbalism = true, fishing = true }
Craft.VERB = { cooking = "À cuisiner maintenant" }
-- 3.0.1 : plus de texte « ouvre la fenêtre » : sans cache, la ligne est omise.
Craft.ORDER = { optimal = 3, medium = 2, easy = 1, trivial = 0 }
Craft.MAX_LINES = 3
Craft.THROTTLE = 0.5

local function Hex(c) return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
function Craft.Color(diff) return S.DiffColor(diff) end
function Craft.Paint(diff, text) return Hex(Craft.Color(diff)) .. text .. "|r" end
function Craft.Verb(skill) local v = Craft.VERB[skill] return v and Tr[v] or Tr["À fabriquer maintenant"] end

-- Seuils de couleur de la base Forever (Cuisine / Secourisme), par nom de recette.
function Craft.DBColors(skill, name)
  local db = ns.ScannerDB
  if not db or not db.recipes or not name then return nil end
  local code = (skill == "cooking") and "c" or ((skill == "firstaid") and "f" or nil)
  if not code then return nil end
  Craft._colIdx = Craft._colIdx or {}
  local idx = Craft._colIdx[code]
  if not idx then
    idx = {}
    for _, raw in pairs(db.recipes) do
      local p = {}
      for part in string.gmatch(raw, "[^|]+") do p[#p + 1] = part end
      if p[1] == code then
        local col = {}
        for v in string.gmatch(p[3] or "", "[^,]+") do col[#col + 1] = tonumber(v) end
        if p[5] then idx[ns.Fold(p[5])] = col end
        if p[6] then idx[ns.Fold(p[6])] = col end
      end
    end
    Craft._colIdx[code] = idx
  end
  return idx[ns.Fold(name)]
end

-- Couleur actuelle : recalculée d'après les seuils si on les connaît, sinon celle
-- lue dans la fenêtre (rafraîchie à chaque ouverture).
function Craft.Diff(r, rank)
  if r.colors and rank and r.colors[2] then
    local y, g, gr = r.colors[2], r.colors[3], r.colors[4]
    if rank < y then return "optimal" elseif rank < g then return "medium" elseif rank < gr then return "easy" end
    return "trivial"
  end
  return r.diff
end

-- Mémorise les recettes lues (par personnage, SavedVariables).
-- 3.3.5 : FUSION, jamais de remplacement. Une recette apprise ne s'oublie
-- pas ; la fenêtre du métier, elle, peut n'en montrer qu'une partie (champ de
-- recherche, « composants disponibles », sous-classe / emplacement, en-têtes
-- repliés, filtre non détecté…). Remplacer la liste mémorisée par cette vue
-- partielle faisait disparaître puis revenir la pastille « N prêts » selon ce
-- qu'on ouvrait. Désormais : les recettes lues mettent à jour celles déjà
-- connues (couleur, composants, icône), les autres sont GARDÉES ; la liste ne
-- rétrécit jamais. Seule la clé de CE métier est touchée.
function Craft.Merge(prevList, list)
  if type(prevList) ~= "table" or #prevList == 0 then return list, 0 end
  local idx, out = {}, {}
  for _, r in ipairs(prevList) do
    if type(r) == "table" and r.name and not idx[r.name] then
      out[#out + 1] = r
      idx[r.name] = #out
    end
  end
  local added = 0
  for _, r in ipairs(list) do
    local i = r.name and idx[r.name]
    if i then
      local old = out[i]
      if (not r.reagents or #r.reagents == 0) and old.reagents and #old.reagents > 0 then r.reagents = old.reagents end
      r.icon = r.icon or old.icon
      out[i] = r
    elseif r.name then
      out[#out + 1] = r
      idx[r.name] = #out
      added = added + 1
    end
  end
  return out, added
end

-- 3.12.0 : les listes de recettes portent les noms du client qui les a lues ; si la langue du client change,
-- on les oublie (relues à la prochaine ouverture de chaque métier) au lieu de mélanger deux langues
function Craft.CheckLocale()
  local c = ns.CharDB and ns.CharDB()
  if type(c) ~= "table" then return end
  local loc = ns.ClientLocale and ns.ClientLocale() or "enUS"
  if c.recipesLocale == loc then return end
  local stale = c.recipesLocale ~= nil
  if not stale then
    -- sauvegarde d'avant 3.12.0 (langue inconnue) : on compare un nom enregistré au nom donné par le jeu ;
    -- on n'efface que si la langue a vraiment changé (sinon tout le monde perdrait ses listes à la mise à jour)
    for _, rec in pairs(c.recipes or {}) do
      for _, r in ipairs(type(rec) == "table" and rec.list or {}) do
        local rid = N(r.recipeID)
        if rid and rid > 0 and type(_G.GetSpellInfo) == "function" then
          local ok, nm = pcall(_G.GetSpellInfo, rid)
          if ok and type(nm) == "string" and nm ~= "" then stale = (nm ~= r.name) break end
        end
      end
      if stale then break end
    end
  end
  if stale then c.recipes = {} end
  c.recipesLocale = loc
  Craft._ver = (Craft._ver or 0) + 1
end
function Craft.Store(skill, list, source)
  local c = ns.CharDB()
  Craft.CheckLocale()
  c.recipes = c.recipes or {}
  local prev = c.recipes[skill]
  local read = #list
  list = Craft.Merge(prev and prev.list, list)
  Craft.lastStore = { skill = skill, read = read, kept = #list }
  local rank = S.RankOf(skill)
  for _, r in ipairs(list) do
    r.colors = r.colors or Craft.DBColors(skill, r.name)
    -- Recalcul seulement si la couleur lue est cohérente avec les seuils.
    if r.colors and rank and Craft.Diff(r, rank) ~= r.diff then r.colors = nil end
  end
  c.recipes[skill] = { when = (type(time) == "function" and time()) or 0, list = list, source = source, rank = rank, lastRead = read }
  Craft._ver = Craft._ver + 1
  Craft.Update(true)
  return skill, #list
end

-- Enchantement (fenêtre « Craft » sur les clients classiques).
local CRAFT_DIFF = { optimal = "optimal", medium = "medium", easy = "easy", trivial = "trivial" }
function Craft.ReadCraftRange(i0, i1, list)
  list = list or {}
  for i = i0, i1 do
    local name, _, kind, nAvail = Call(_G.GetCraftInfo, i)
    name, kind = Str(name), Str(kind)
    if name and kind and kind ~= "header" then
      local r = { name = name, diff = CRAFT_DIFF[kind] or kind, reagents = {}, avail = N(nAvail), icon = Call(_G.GetCraftIcon, i) }
      for j = 1, (N(Call(_G.GetCraftNumReagents, i)) or 0) do
        local rn, _, cnt = Call(_G.GetCraftReagentInfo, i, j)
        local link = Call(_G.GetCraftReagentItemLink, i, j)
        r.reagents[#r.reagents + 1] = { id = S.ItemIDFromLink(link), name = Str(rn), count = N(cnt) or 1 }
      end
      list[#list + 1] = r
    end
  end
  return list
end
function Craft.CraftIdentity()
  local name = Str(Call(_G.GetCraftDisplaySkillLine)) or Str(Call(_G.GetCraftName))
  local n = N(Call(_G.GetNumCrafts)) or 0
  local id = name and ns.Style and ns.Style.SkillIdForText and ns.Style.SkillIdForText(name) or nil
  local rank = (id and S and S.RankOf and S.RankOf(id)) or 0
  return id, n, rank or 0, name
end
function Craft.ReadCraftWindow()
  if InCombat() then return nil, "combat" end
  local id, n, _, lineName = Craft.CraftIdentity()
  if not n or n <= 0 then return nil, "aucune recette" end
  if not id then return nil, "fenêtre inconnue : " .. tostring(lineName) end
  local list = Craft.ReadCraftRange(1, n, {})
  if #list == 0 then return nil, "aucune recette" end
  return Craft.Store(id, list, "GetCraftInfo")
end

-- Recettes connues ; repli avant la 1re ouverture : recettes de la base (estimation).
function Craft.Known(skill)
  local rec = ns.CharDB().recipes and ns.CharDB().recipes[skill]
  if rec and rec.list then return rec.list, false, rec.source end
  local est = S.DBRecipes and S.DBRecipes(skill)
  if est then return est.list, true, "base Forever (estimation)" end
  return nil
end

local function ItemName(id, fallback)
  if ns.ItemDisplayName then return ns.ItemDisplayName(id, fallback) end
  local it = S and S.StaticItem and S.StaticItem(id)
  if it and (it.fr or it.en) then return ns.GameName(it.en, it.fr) end
  local nm = Str(Call(_G.GetItemInfo, id))
  if nm then return nm end
  if fallback and not (ns.BareItemIdLabel and ns.BareItemIdLabel(fallback)) then return fallback end
  return nil
end
Craft.ItemName = ItemName

-- Recettes connues non grises qui utilisent un objet de cette créature.
Craft._ver = 0
Craft._matchCache = setmetatable({}, { __mode = "k" })
function Craft.Match(c, skill)
  if not c or not c.items then return {}, nil end
  local rank = S.RankOf(skill)
  local per = Craft._matchCache[c]
  local hit = per and per[skill]
  local learnVer = S._learnVer or 0
  if hit and hit.ver == Craft._ver and hit.rank == rank and hit.learn == learnVer then return hit.out, hit.best end
  local out, best = Craft.MatchRaw(c, skill)
  if not per then per = {} Craft._matchCache[c] = per end
  per[skill] = { ver = Craft._ver, rank = rank, learn = learnVer, out = out, best = best }
  return out, best
end

function Craft.MatchRaw(c, skill)
  local list, est = Craft.Known(skill)
  if not list then return {}, nil end
  local rank = S.RankOf(skill)
  local out = {}
  for _, r in ipairs(list) do
    local d = Craft.Diff(r, rank)
    if d and d ~= "trivial" and Craft.ORDER[d] then
      for _, rg in ipairs(r.reagents or {}) do
        if rg.id and c.items[rg.id] then
          out[#out + 1] = { recipe = r, item = rg.id, itemName = ItemName(rg.id, rg.name), diff = d, estimate = est }
          break
        end
      end
    end
  end
  table.sort(out, function(a, b)
    local oa, ob = Craft.ORDER[a.diff], Craft.ORDER[b.diff]
    if oa ~= ob then return oa > ob end
    return tostring(a.recipe.name) < tostring(b.recipe.name)
  end)
  return out, out[1] and out[1].diff or nil
end

-- 3.6.3 : si le nom d'ingrédient n'est pas encore connu, seulement « Recette (+1) ».
function Craft.FormatMatch(m)
  if not m then return "" end
  local rec = tostring(m.recipe and m.recipe.name or "")
  local item = m.itemName
  local text
  if type(item) == "string" and item ~= "" and not (ns.BareItemIdLabel and ns.BareItemIdLabel(item)) then
    text = string.format(Tr["%s : %s (+1)"], item, rec)
  else
    text = string.format(Tr["%s (+1)"], rec)
  end
  return Craft.Paint(m.diff, text)
end

function Craft.MatchLines(creature, matches)
  local lines = {}
  for i = 1, math.min(Craft.MAX_LINES, #(matches or {})) do
    -- 3.3.8 : ni nom de créature (déjà en titre), ni flèche (absente de la police du jeu)
    lines[i] = Craft.FormatMatch(matches[i])
  end
  return lines
end

-- Met à jour un toast encore visible quand le nom d'objet arrive (cache client).
function Craft.BindToastItems(frame, matches)
  if not (frame and matches and ns.WhenItemName) then return end
  local function apply()
    if frame.IsShown and not frame:IsShown() then return end
    local lines = Craft.MatchLines(nil, matches)
    if frame.titleFS and lines[1] and frame.titleFS.SetText then pcall(frame.titleFS.SetText, frame.titleFS, lines[1]) end
    if frame.subFS and frame.subFS.SetText then pcall(frame.subFS.SetText, frame.subFS, lines[2] or "") end
    if frame.hintFS and lines[3] and frame.hintFS.SetText then pcall(frame.hintFS.SetText, frame.hintFS, lines[3]) end
    frame._fullTitle = lines[1] or frame._fullTitle
    frame._fullSub = lines[2] or frame._fullSub
    if ns.ToastFit and ns.ToastFit.FitSoon then pcall(ns.ToastFit.FitSoon, frame) end
  end
  for _, m in ipairs(matches) do
    if m.item and (not m.itemName or m.itemName == "" or (ns.BareItemIdLabel and ns.BareItemIdLabel(m.itemName))) then
      ns.WhenItemName(m.item, function(nm)
        m.itemName = nm
        apply()
      end)
    end
  end
end

local SKILL_FR = { cooking = "Cuisine", firstaid = "Secourisme" }
function Craft.WhyLines(c, skill, creature)
  local out = {}
  local fr = SKILL_FR[skill] and ns.SkillDisplayName(skill) or skill
  local list, est = Craft.Known(skill)
  if not list then
    out[1] = fr .. Tr[" : recettes jamais lues — ouvre la fenêtre "] .. fr .. Tr[" une fois."]
    return out
  end
  if est then out[#out + 1] = fr .. Tr[" : estimation (recettes du maître de la base Forever) — ouvre la fenêtre "] .. fr .. Tr[" pour tes vraies recettes."] end
  local m = Craft.Match(c, skill)
  if #m == 0 then
    local any = false
    local rank = S.RankOf(skill)
    for _, r in ipairs(list) do
      for _, rg in ipairs(r.reagents or {}) do
        if rg.id and c.items[rg.id] then
          any = true
          out[#out + 1] = string.format(Tr["%s : %s pour %s est %s : pas d'icône."], fr, ItemName(rg.id, rg.name) or Tr["composant"], tostring(r.name), Tr[S.DIFF_FR[Craft.Diff(r, rank) or "trivial"] or "?"])
          break
        end
      end
    end
    if not any then out[#out + 1] = fr .. Tr[" : aucune recette connue n'utilise ses objets."] end
    return out
  end
  for _, l in ipairs(Craft.MatchLines(creature, m)) do out[#out + 1] = fr .. Tr[" : "] .. l end
  out[#out + 1] = fr .. Tr[" : couleur de l'icône = "] .. Tr[S.DIFF_FR[m[1].diff]] .. Tr[" (meilleure recette)."]
  return out
end

-- Recettes réalisables avec les sacs -----------------------------------------
function Craft.AvailCount(r)
  if not r then return 0 end
  local n
  for _, rg in ipairs(r.reagents or {}) do
    if not rg.id then n = 0 break end
    local k = math.floor(Craft.ItemCount(rg.id) / math.max(1, rg.count or 1))
    n = (n == nil) and k or math.min(n, k)
  end
  if n == nil and N(r.avail) then n = N(r.avail) end
  return n or 0
end

function Craft.MissingReagents(r)
  local out = {}
  if not r then return out end
  for _, rg in ipairs(r.reagents or {}) do
    local need = math.max(1, rg.count or 1)
    local have = rg.id and Craft.ItemCount(rg.id) or 0
    if have < need then
      out[#out + 1] = { id = rg.id, name = ItemName(rg.id, rg.name), have = have, need = need }
    end
  end
  return out
end

function Craft:FillToastTooltip(tt, data)
  if not tt or not data or not tt.AddLine then return end
  local e = data.entries and data.entries[1]
  local m = data.matches and data.matches[1]
  local r = data.recipe or (e and e.recipe) or (m and m.recipe)
  local skill = data.skill or (e and e.skill)
  local diff = data.diff or (e and e.diff) or (m and m.diff)
  if skill then
    local nm = (ns.SkillDisplayName and ns.SkillDisplayName(skill)) or skill
    pcall(tt.AddLine, tt, string.format(Tr["Métier : %s"], tostring(nm)), 1, 1, 1, true)
  end
  if r and r.req then
    pcall(tt.AddLine, tt, string.format(Tr["Rang requis : %d"], r.req), 1, 1, 1, true)
  end
  if diff then
    local lab = (S and S.DIFF_FR and S.DIFF_FR[diff]) or diff
    lab = Tr[lab] or lab
    local col = Craft.Color and Craft.Color(diff)
    local cr, cg, cb = 1, 1, 1
    if type(col) == "table" then cr, cg, cb = col[1] or 1, col[2] or 1, col[3] or 1 end
    pcall(tt.AddLine, tt, string.format(Tr["Difficulté : %s"], tostring(lab)), cr, cg, cb, true)
  end
  local n = data.n
  if n == nil and e then n = e.n end
  if n == nil and r then n = Craft.AvailCount(r) end
  if n ~= nil then
    pcall(tt.AddLine, tt, string.format(Tr["Réalisable maintenant : %d"], n), 1, 1, 1, true)
  end
  local missing = data.missing
  if missing == nil and r then missing = Craft.MissingReagents(r) end
  if type(missing) == "table" and #missing > 0 then
    pcall(tt.AddLine, tt, Tr["Composants manquants :"], 1, 0.25, 0.25, true)
    for i = 1, #missing do
      local rg = missing[i]
      local nm = rg.name or (ItemName and ItemName(rg.id)) or Tr["composant"]
      pcall(tt.AddLine, tt, string.format("  %s (%d/%d)", tostring(nm), rg.have or 0, rg.need or 1), 1, 0.60, 0.60, true)
    end
  end
end

function Craft.ItemCount(id)
  local v = N(Call(_G.GetItemCount, id))
  if v == nil and type(_G.C_Item) == "table" then v = N(Call(_G.C_Item.GetItemCount, id)) end
  return v or 0
end

function Craft.Compute(skill)
  local rec = ns.CharDB().recipes and ns.CharDB().recipes[skill]
  if not rec or not rec.list then return nil end
  local rank = S.RankOf(skill)
  local st = { list = {}, greys = {}, ready = 0 }
  for _, r in ipairs(rec.list) do
    local n
    for _, rg in ipairs(r.reagents or {}) do
      if not rg.id then n = 0 break end
      local k = math.floor(Craft.ItemCount(rg.id) / math.max(1, rg.count or 1))
      n = (n == nil) and k or math.min(n, k)
    end
    -- 3.5.8 : composants non lus (fenêtre Métiers) : compte donné par le jeu à la lecture
    if n == nil and (not r.reagents or #r.reagents == 0) and N(r.avail) then n = N(r.avail) end
    if n and n > 0 then
      local d = Craft.Diff(r, rank) or "trivial"
      local e = { recipe = r, n = n, diff = d }
      if d == "trivial" or not Craft.ORDER[d] then st.greys[#st.greys + 1] = e
      else st.list[#st.list + 1] = e st.ready = st.ready + n end
    end
  end
  local function cmp(a, b)
    local oa, ob = Craft.ORDER[a.diff] or 0, Craft.ORDER[b.diff] or 0
    if oa ~= ob then return oa > ob end
    return tostring(a.recipe.name) < tostring(b.recipe.name)
  end
  table.sort(st.list, cmp)
  table.sort(st.greys, cmp)
  return st
end

Craft.state = {}
Craft.prev = {}
-- silent : lecture de fenêtre / premier passage → on mémorise sans annoncer.
function Craft.Update(silent)
  if InCombat() then Craft._pending = true return nil end
  if ns.PausedForFlight and ns.PausedForFlight() then silent = true end
  Craft._pending = false
  local gains = {}
  for skill in pairs(Craft.SKILLS) do
    local st = Craft.Compute(skill)
    Craft.state[skill] = st
    if st then
      local prev = Craft.prev[skill]
      local now = {}
      for _, e in ipairs(st.list) do
        local key = tostring(e.recipe.name)
        now[key] = e.n
        if prev and not silent and e.n > (prev[key] or 0) then e.skill = skill gains[#gains + 1] = e end
      end
      Craft.prev[skill] = now
    end
  end
  if #gains > 0 then Craft.Notify(gains) end
  if ns.UI and ns.UI.RefreshCraftBadges then pcall(ns.UI.RefreshCraftBadges, ns.UI) end
  Craft.updates = (Craft.updates or 0) + 1
  return gains
end

-- Titre de toast « recette possible » : le préfixe « N × » seulement si N ≥ 2.
-- Pas de « × » orphelin quand le compte est nil, 0 ou 1.
function Craft.RecipeToastTitle(n, name)
  n = ns.N(n)
  name = tostring(name or "")
  local word = (n and n > 1) and Tr["possibles"] or Tr["possible"]
  local core = name
  if name ~= "" then
    core = name .. " " .. word .. " (+1)"
  else
    core = word .. " (+1)"
  end
  if n and n > 1 then
    return tostring(math.floor(n + 0.5)) .. " × " .. core
  end
  return core
end

function Craft.Notify(gains)
  if not ns.Opt("craftNotify") or not (ns.UI and ns.UI.SpawnDrop) then return nil end
  table.sort(gains, function(a, b)
    local oa, ob = Craft.ORDER[a.diff] or 0, Craft.ORDER[b.diff] or 0
    if oa ~= ob then return oa > ob end
    return tostring(a.recipe.name) < tostring(b.recipe.name)
  end)
  local lines = {}
  for i = 1, math.min(Craft.MAX_LINES, #gains) do
    local e = gains[i]
    lines[i] = Craft.Paint(e.diff, Craft.RecipeToastTitle(e.n, e.recipe and e.recipe.name))
  end
  local g1 = gains[1]
  -- Icône du métier (pas l'icône d'objet de la recette : sac, cuir, composant).
  local opts = {
    kind = "craft", hint = lines[3],
    skillId = g1.skill,
    toastData = {
      kind = "craft", skill = g1.skill, entries = gains,
      recipe = g1.recipe, n = g1.n, diff = g1.diff,
      item = g1.recipe and (g1.recipe.itemID or g1.recipe.item),
    },
  }
  local icon = (ns.UI and ns.UI.ResolveToastIcon and ns.UI.ResolveToastIcon(nil, opts))
    or (ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[g1.skill] and ns.CATALOG_BY_ID[g1.skill].icon)
  local f = ns.UI:SpawnDrop(icon, lines[1], lines[2], nil, nil, nil, opts)
  Craft.lastNotify = lines
  return f
end

-- Mise à jour des sacs : regroupée (une seule par rafale), jamais en combat.
function Craft.OnBags()
  if Craft._timer then return end
  if InCombat() then Craft._pending = true return end
  local run = function() Craft._timer = nil Craft.Update(false) end
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
    Craft._timer = true
    _G.C_Timer.After(Craft.THROTTLE, run)
  else
    run()
  end
end

-- Détail d'une tuile de métier.
function Craft.DetailText(skill)
  if not Craft.SKILLS[skill] then return nil end
  -- 3.10.0 : trajet SkillUp (si installé) : une seule recommandation, la sienne remplace « Prochain +1 »
  local su
  if ns.SkillUp and ns.SkillUp.Lines then local okS, l = pcall(ns.SkillUp.Lines, skill) su = okS and l or nil end
  local function WithSU(text)
    if not su then return text end
    local block = table.concat(su, "\n")
    return text and (text .. "\n" .. block) or block
  end
  local rec = ns.CharDB().recipes and ns.CharDB().recipes[skill]
  if not rec or not rec.list then return WithSU(nil) end
  local st = Craft.state[skill] or (not InCombat() and Craft.Compute(skill)) or nil
  if not st then return WithSU(nil) end
  Craft.state[skill] = st
  local L = {}
  if #st.list == 0 then
    L[1] = Craft.Verb(skill) .. Tr[" : rien qui fasse progresser avec tes sacs."]
    -- 3.9.0 : la recette la plus proche, ce qui manque et où le trouver
    local okN, nb = false, nil
    if not su then okN, nb = pcall(Craft.NextBestLines, skill) end
    if okN and nb then for _, l in ipairs(nb) do L[#L + 1] = l end end
  else
    L[1] = Craft.Verb(skill) .. Tr[" :"]
    for _, e in ipairs(st.list) do L[#L + 1] = Craft.Paint(e.diff, string.format(Tr["%s ×%d (+1)"], tostring(e.recipe.name), e.n)) end
  end
  if #st.greys > 0 then
    L[#L + 1] = Tr["|cff808080Sans gain :|r"]
    for _, e in ipairs(st.greys) do L[#L + 1] = string.format(Tr["|cff808080%s ×%d (sans gain)|r"], tostring(e.recipe.name), e.n) end
  end
  return WithSU(table.concat(L, "\n"))
end

-- 3.9.0 : prochain meilleur +1 quand rien ne fait progresser avec les sacs : la recette connue la plus
-- rentable (chance de point selon sa couleur, divisée par ce qu'il reste à réunir), ses composants
-- manquants et, pour ceux de la base (Cuisine, Secourisme, Dépeçage), les meilleurs monstres de ton niveau.
Craft.POINT_CHANCE = { optimal = 1, medium = 0.75, easy = 0.25 }
function Craft.NextBest(skill)
  local rec = ns.CharDB().recipes and ns.CharDB().recipes[skill]
  if not (rec and rec.list) then return nil end
  local rank = S and S.RankOf and S.RankOf(skill)
  local best, bestScore
  for _, r in ipairs(rec.list) do
    local d = Craft.Diff(r, rank)
    local p = d and Craft.POINT_CHANCE[d]
    if p and type(r.reagents) == "table" and #r.reagents > 0 then
      local known = true
      for _, rg in ipairs(r.reagents) do if not rg.id then known = false break end end
      local miss = known and Craft.MissingReagents(r) or {}
      if known and #miss > 0 then
        local total = 0
        for _, m in ipairs(miss) do total = total + (m.need - m.have) end
        local score = p / (1 + total)
        if not best or score > bestScore then best, bestScore = { recipe = r, diff = d, missing = miss }, score end
      end
    end
  end
  return best
end
-- monstres qui lâchent un objet de la base, triés par chance, près du niveau du joueur
function Craft.SourcesOf(itemID, max)
  local DB = ns.ScannerDB
  if not (DB and DB.drops and DB.npcs and itemID) then return {} end
  if not Craft._byItem then
    local byItem = {}
    for npc, s in pairs(DB.drops) do
      for id, ch in tostring(s):gmatch("(%d+):(%d+)") do
        id = tonumber(id)
        byItem[id] = byItem[id] or {}
        byItem[id][#byItem[id] + 1] = { npc = npc, chance = tonumber(ch) / 10 }
      end
    end
    Craft._byItem = byItem
  end
  local plevel = N(Call(_G.UnitLevel, "player")) or 60
  local out = {}
  for _, e in ipairs(Craft._byItem[itemID] or {}) do
    local row = DB.npcs[e.npc]
    if row then
      local en, fr, lo, hi = tostring(row):match("^([^|]*)|([^|]*)|(%d+)|(%d+)")
      lo, hi = tonumber(lo), tonumber(hi)
      -- à ta portée : pas plus de 3 niveaux au-dessus, pas plus de 12 en dessous (gris, mais ça lâche quand même)
      if lo and hi and hi >= plevel - 12 and lo <= plevel + 3 then
        out[#out + 1] = { name = (ns.GameName and ns.GameName(en, fr)) or en, lo = lo, hi = hi, chance = e.chance }
      end
    end
  end
  table.sort(out, function(a, b) if a.chance ~= b.chance then return a.chance > b.chance end return a.lo > b.lo end)
  for i = #out, (max or 2) + 1, -1 do out[i] = nil end
  return out
end
function Craft.NextBestLines(skill)
  if not ns.Opt("nextBest") then return nil end
  local nb = Craft.NextBest(skill)
  if not nb then return nil end
  local L = { Tr["Prochain +1 : "] .. Craft.Paint(nb.diff, tostring(nb.recipe.name)) }
  local parts = {}
  for _, m in ipairs(nb.missing) do parts[#parts + 1] = string.format("%s ×%d", tostring(m.name), m.need - m.have) end
  L[#L + 1] = Tr["Il manque : "] .. table.concat(parts, ", ")
  for _, m in ipairs(nb.missing) do
    for _, src in ipairs(Craft.SourcesOf(m.id, 2)) do
      L[#L + 1] = string.format(Tr["  %s : %s (niv. %d-%d, %d %%)"], tostring(m.name), src.name, src.lo, src.hi, math.floor(src.chance + 0.5))
    end
  end
  return L
end

function Craft.Ready(skill)
  local st = Craft.state[skill]
  return st and st.ready or 0
end

-- 3.3.5 : recettes NON APPRISES de la base Forever (Cuisine / Secourisme) qui
-- utilisent un objet de cette créature, si elles sont à ta portée (rang requis
-- ≤ ton rang + 25). Couleur = difficulté qu'elles auraient à ton rang (seuils de
-- la base) ; rang requis pas encore atteint : rouge pâle. Recette absente de la
-- base : rien. Il faut avoir lu la fenêtre du métier une fois (sinon on ne
-- sait pas ce qui est appris : rien n'est affiché).
Craft.UNLEARNED_REACH = 25
Craft.UNLEARNED_MAX = 2
local CODE_SKILL = { c = "cooking", f = "firstaid" }
function Craft.DBByReagent()
  if Craft._byReagent then return Craft._byReagent end
  local db = ns.ScannerDB
  local idx = {}
  for _, raw in pairs(db and db.recipes or {}) do
    local p = {}
    for part in string.gmatch(raw, "[^|]+") do p[#p + 1] = part end
    local skill = CODE_SKILL[p[1] or ""]
    if skill then
      local col = {}
      for v in string.gmatch(p[3] or "", "[^,]+") do col[#col + 1] = tonumber(v) end
      local r = { skill = skill, req = tonumber(p[2]), colors = col, en = p[5], fr = p[6], name = ns.GameName(p[5], p[6]), reagents = {} }
      for id, n in string.gmatch(p[4] or "", "(%d+)x(%d+)") do r.reagents[#r.reagents + 1] = { id = tonumber(id), count = tonumber(n) } end
      for _, rg in ipairs(r.reagents) do
        idx[rg.id] = idx[rg.id] or {}
        table.insert(idx[rg.id], r)
      end
    end
  end
  Craft._byReagent = idx
  return idx
end
function Craft.UnlearnedFor(c)
  local out = {}
  if not c or not c.items then return out end
  local idx = Craft.DBByReagent()
  local seen = {}
  for itemID in pairs(c.items) do
    for _, r in ipairs(idx[itemID] or {}) do
      local rec = ns.CharDB().recipes and ns.CharDB().recipes[r.skill]
      local rank = S.RankOf(r.skill)
      if rec and rec.list and rank and rank > 0 and r.req and r.req <= rank + Craft.UNLEARNED_REACH and not seen[r] then
        seen[r] = true
        local known = false
        for _, k in ipairs(rec.list) do
          local f = ns.Fold(k.name or "")
          if f == ns.Fold(r.fr or "") or f == ns.Fold(r.en or "") then known = true break end
        end
        if not known then
          local diff = (rank >= r.req) and Craft.Diff(r, rank) or "locked"
          out[#out + 1] = { recipe = r, item = itemID, diff = diff, rank = rank }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    local oa, ob = Craft.ORDER[a.diff] or -1, Craft.ORDER[b.diff] or -1
    if oa ~= ob then return oa > ob end
    return tostring(a.recipe.name) < tostring(b.recipe.name)
  end)
  return out
end
function Craft.UnlearnedLines(c)
  local lines = {}
  for i, u in ipairs(Craft.UnlearnedFor(c)) do
    if i > Craft.UNLEARNED_MAX then break end
    local txt = string.format(Tr["%s (recette non apprise, rang %d)"], tostring(u.recipe.name), u.recipe.req)
    if u.diff == "locked" then lines[#lines + 1] = "|cffb36060" .. txt .. "|r"
    else
      -- teinte atténuée (≈ 75 %) : ligne secondaire
      local col = Craft.Color(u.diff)
      lines[#lines + 1] = string.format("|cff%02x%02x%02x%s|r", math.floor(col[1] * 191), math.floor(col[2] * 191), math.floor(col[3] * 191), txt)
    end
  end
  return lines
end

-- Infobulle d'unité : jusqu'à 3 lignes « créature → ingrédient → recette (+1) ».
function Craft.UnitTooltip(tt)
  if ns.Tip and ns.Tip.active then return nil end   -- 3.3.8 : infobulle compacte (Tip.lua)
  if InCombat() or (ns.PausedForFlight and ns.PausedForFlight()) or not S.Enabled() or type(tt) ~= "table" then return nil end
  local unit = "mouseover"
  local id = S.UnitNpcID(unit)
  if not id then return nil end
  local _, seen = S.NoteUnit(unit)
  local info = { name = seen and seen.name, family = seen and seen.family, ctype = seen and seen.ctype, alive = not Call(_G.UnitIsDead, unit) }
  local skill, diff, _, matches = S.BestFor(id, info)
  local lines = {}
  if skill and diff ~= "neutral" then lines = Craft.MatchLines(seen and seen.name, matches) end
  -- 3.3.5 : toutes les autres recettes (tous métiers, apprises ou non) qui
  -- utilisent un objet de la créature (butin + dépeçage), plafonnées.
  local c = S.CreatureFor(id, info)
  if ns.Links and c then
    local ex = {}
    for _, m in ipairs(matches or {}) do if m.recipe and m.recipe.name then ex[ns.Fold(m.recipe.name)] = true end end
    local okU, extra = pcall(ns.Links.Lines, ns.Links.CreatureItems(c), { exclude = ex, cap = math.max(2, ns.Links.CAP - #lines) })
    if okU then for _, l in ipairs(extra or {}) do lines[#lines + 1] = l end end
  else
    local okU, extra = pcall(Craft.UnlearnedLines, c)
    if okU then for _, l in ipairs(extra or {}) do lines[#lines + 1] = l end end
  end
  for _, l in ipairs(lines) do pcall(tt.AddLine, tt, l) end
  if #lines > 0 and tt.Show then pcall(tt.Show, tt) end
  return #lines
end

function Craft.HookUnitTooltip()
  if Craft._ttHooked then return end
  local tt = _G.GameTooltip
  if type(tt) ~= "table" then return end
  Craft._ttHooked = true
  if type(_G.TooltipDataProcessor) == "table" and type(_G.TooltipDataProcessor.AddTooltipPostCall) == "function"
    and _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Unit then
    pcall(_G.TooltipDataProcessor.AddTooltipPostCall, _G.Enum.TooltipDataType.Unit, function(t) if t == tt then pcall(Craft.UnitTooltip, t) end end)
    Craft.ttMode = "TooltipDataProcessor"
  elseif tt.HookScript then
    pcall(tt.HookScript, tt, "OnTooltipSetUnit", function(t) pcall(Craft.UnitTooltip, t) end)
    Craft.ttMode = "OnTooltipSetUnit"
  end
end

if ns.On then
  ns.On("PLAYER_LOGIN", function() Craft.CheckLocale() Craft.HookUnitTooltip() Craft.Update(true) end)
  ns.On("BAG_UPDATE_DELAYED", function() Craft.OnBags() end)
  ns.On("PLAYER_REGEN_ENABLED", function() if Craft._pending then Craft.Update(false) end end)
  local function readCraft(ev)
    if ns.ProfJob and ns.ProfJob.Schedule then ns.ProfJob.Schedule(ev or "craft") return end
    if InCombat() then return end
    local ok, id, n = pcall(Craft.ReadCraftWindow)
    if ok and id and S then S.lastRead = tostring(id) .. " : " .. tostring(n) end
  end
  ns.On("CRAFT_SHOW", readCraft)
  ns.On("CRAFT_UPDATE", readCraft)
  ns.On("CHAT_MSG_SKILL", function()
    -- Couleurs recalculées (seuils) puis comptes et barres de nom, hors combat.
    if InCombat() then Craft._pending = true return end
    Craft.Update(true)
    if S.RescanPlates then pcall(S.RescanPlates) end
  end)
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local out = { "— Recettes réalisables (v2.8.1) —" }
  local rec = ns.CharDB().recipes or {}
  for skill in pairs(Craft.SKILLS) do
    local r = rec[skill]
    if r then
      local st = Craft.state[skill]
      out[#out + 1] = string.format("  %s : %d recettes (%s) ; prêtes (progression) %d", skill, #(r.list or {}), tostring(r.source), st and st.ready or 0)
    end
  end
  out[#out + 1] = "  infobulle d'unité : " .. tostring(Craft.ttMode or "non accrochée") .. " ; mises à jour : " .. tostring(Craft.updates or 0)
  return out
end

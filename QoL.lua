-- Dropamine 2.7.0 : qualité de vie.
-- Tout est mesuré ou lu en jeu ; rien n'est inventé. Chaque fonction se coupe
-- dans les options (/drop options) et par commande. Secret-safe, rien en combat
-- qui touche à l'équipement.
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local Q = {}
ns.QoL = Q

local function N(v) return ns.N(v) end
-- 3.6.0 : sans table temporaire (appelé sur les événements fréquents : survol,
-- barres de nom, cible) et sans troncature aux valeurs nil intermédiaires.
local function Ret(ok, ...) if not ok then return nil end return ... end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  return ns.Unsecret(Ret(pcall(fn, ...)))
end
local function Str(v)
  if type(v) ~= "string" or ns.IsSecret(v) then return nil end
  return v
end
local function InCombat()
  return (type(InCombatLockdown) == "function" and Call(InCombatLockdown)) and true or false
end
local function Today()
  local d = Call(date, "%Y-%m-%d")
  return Str(d) or tostring(math.floor(((type(time) == "function" and time()) or 0) / 86400))
end
local function UI() return ns.UI end
local function Drop(icon, title, sub, opts)
  local ui = UI()
  if ui and ui.SpawnDrop then return ui:SpawnDrop(icon, title, sub, nil, nil, nil, opts or { kind = "qol" }) end
end

-- Seuils de jalons personnels (choix d'affichage, pas des données de jeu).
Q.RANK_MILESTONES = { 150, 225, 300 }
Q.TOTAL_MILESTONES = { 500, 1000, 1500, 2000 }
Q.PRE_PALIER_GAP = 5

-- Options (panneau + commandes) ------------------------------------------------
Q.OPTIONS = {
  { section = "Qualité de vie (2.7.0)" },
  { type = "check", key = "eta", label = "Estimation « 125 dans ~40 min » (rythme mesuré)", default = true, cmd = "/drop eta on|off", refresh = true },
  { type = "check", key = "prepalier", label = "Rappel avant le palier (max − 5)", default = true, cmd = "/drop prepalier on|off" },
  { type = "check", key = "historique", label = "Historique 7 jours dans le détail", default = true, cmd = "/drop historique on|off", refresh = true },
  { type = "check", key = "alts", label = "Comparaison des personnages (bandeau)", default = true, cmd = "/drop alts on|off" },
  { type = "check", key = "jalons", label = "Jalons personnels (premier 150, total 1000…)", default = true, cmd = "/drop jalons on|off" },
  { type = "check", key = "peche", label = "Prises de pêche par zone", default = true, cmd = "/drop peche on|off" },
  { type = "check", key = "defense", label = "Rappel discret : Défense contre adversaires gris", default = true, cmd = "/drop defense on|off" },
  { type = "check", key = "recapLogout", label = "Récap de session à la déconnexion (toast + ligne)", default = true, cmd = "/drop recap on|off" },
  { type = "check", key = "courses", label = "Liste de courses de l'objectif (recettes connues)", default = true, cmd = "/drop courses on|off", refresh = true },
  { type = "check", key = "partage", label = "Maj+clic sur une tuile : insérer « Dépeçage 161/225 » dans le chat", default = true, cmd = "/drop partage on|off" },
  { type = "check", key = "maitreArmes", label = "Rappel maître d'armes (arme non apprise)", default = true, cmd = "/drop maitre on|off" },
  { type = "check", key = "armePrincipale", label = "Rappel de l'arme principale", default = true, cmd = "/drop arme on|off" },
}
if ns.Options then
  for _, it in ipairs(Q.OPTIONS) do ns.Options.EXTRA[#ns.Options.EXTRA + 1] = it end
end

local function toggleCmd(key, label)
  return function(rest)
    local v = ns.ParseOnOff(rest, ns.Opt(key))
    if ns.Options then ns.Options.Set(key, v) else ns.SetOpt(key, v) end
    ns.Print(Tr[label] .. (v and Tr[" : activé."] or Tr[" : désactivé."]))
  end
end
ns.SlashExt.eta = toggleCmd("eta", "estimation du temps")
ns.SlashExt.prepalier = toggleCmd("prepalier", "rappel avant palier")
ns.SlashExt.historique = toggleCmd("historique", "historique 7 jours")
ns.SlashExt.alts = toggleCmd("alts", "comparaison des personnages")
ns.SlashExt.jalons = toggleCmd("jalons", "jalons personnels")
ns.SlashExt.defense = toggleCmd("defense", "rappel de Défense")
ns.SlashExt.partage = toggleCmd("partage", "Maj+clic → chat")
ns.SlashExt.maitre = toggleCmd("maitreArmes", "rappel maître d'armes")
ns.SlashExt.peche = toggleCmd("peche", "prises de pêche par zone")
ns.SlashExt["pêche"] = ns.SlashExt.peche

-- Données par personnage -------------------------------------------------------
function Q.C()
  local c = ns.CharDB()
  c.history = c.history or {}        -- [AAAA-MM-JJ] = { total = n, ranks = { [id] = r } }
  c.milestones = c.milestones or {}  -- [clé] = true
  c.prePaliers = c.prePaliers or {}  -- [id] = max déjà signalé
  c.fishing = c.fishing or {}        -- [zone] = { catches = n, items = { [itemID] = n } }
  return c
end
function Q.Global()
  local db = ns.EnsureDB()
  db.weaponMasters = db.weaponMasters or {}  -- [id d'arme] = { npc, zone, when }
  return db
end

-- 1. Instantané : historique, alts, jalons, pré-palier -----------------------
function Q.OnSnapshot(snap)
  if not snap or (snap.liveCount or 0) <= 0 then return end
  local c = Q.C()
  local total = N(snap.total) or 0
  -- historique quotidien (dernier état de la journée)
  local day = Today()
  local ranks = {}
  for _, d in ipairs(snap.tiles or {}) do
    if d.id and N(d.current) and not d.placeholder then ranks[d.id] = N(d.current) end
  end
  -- 3.6.0 : la journée garde ses autres champs (Progress.lua : pts, cat, skills)
  local h = c.history[day]
  if type(h) ~= "table" then h = {} c.history[day] = h end
  h.total, h.ranks = total, ranks
  Q.PruneHistory(c)
  -- alts
  c.lastTotal = total
  c.lastMax = N(snap.totalMax)
  c.lastLevel = N(ns.GetPlayerLevel and ns.GetPlayerLevel())
  local _, cls = Call(UnitClass, "player")
  c.class = Str(cls) or c.class
  c.lastSeenDay = day
  -- jalons et pré-palier
  local first = not c.milestonesSeeded
  for _, d in ipairs(snap.tiles or {}) do
    local cur, cap = N(d.current) or 0, N(d.apiMax) or 0
    if (d.kind == "profession" or d.kind == "secondary") and not d.placeholder then
      for _, m in ipairs(Q.RANK_MILESTONES) do
        local key = "rank" .. m
        if cur >= m and not c.milestones[key] then
          c.milestones[key] = d.id
          if not first and ns.Opt("jalons") then
            Drop(d.icon, Tr["Jalon : premier "] .. m .. " !", (d.name or "") .. " " .. cur, { variant = "gold", kind = "jalon", hint = Tr["Premier métier à "] .. m .. Tr[" sur ce personnage"] })
          end
        end
      end
      if cap > 0 and cur >= cap - Q.PRE_PALIER_GAP and cur < cap and c.prePaliers[d.id] ~= cap then
        c.prePaliers[d.id] = cap
        if not first and ns.Opt("prepalier") then
          Drop(d.icon, Tr["Bientôt le palier : "] .. (d.name or "") .. " " .. cur .. "/" .. cap, Tr["Prévois le passage chez le maître"], { kind = "prepalier", hint = Tr["Encore "] .. (cap - cur) .. Tr[" rang(s)"] })
        end
      end
    end
  end
  for _, m in ipairs(Q.TOTAL_MILESTONES) do
    local key = "total" .. m
    if total >= m and not c.milestones[key] then
      c.milestones[key] = true
      if not first and ns.Opt("jalons") then
        Drop(ns.LEVEL_ICON, Tr["Jalon : niveau total "] .. m .. " !", Tr["Niveau total "] .. total, { variant = "gold", kind = "jalon" })
      end
    end
  end
  c.milestonesSeeded = true
end

Q.HISTORY_DAYS = 35   -- 3.6.0 : 35 jours (fenêtre Progression : 30 jours + marge)
-- Journée d'historique : agrégats seulement (pts, cat, skills, total, ranks, xp).
function Q.SlimHistoryDay(h)
  if type(h) ~= "table" then return h end
  h.events, h.log, h.raw, h.curve, h.hour, h.samples = nil, nil, nil, nil, nil, nil
  return h
end
function Q.PruneHistory(c)
  if type(c) ~= "table" or type(c.history) ~= "table" then return 0 end
  local keys = {}
  for k, h in pairs(c.history) do
    keys[#keys + 1] = k
    Q.SlimHistoryDay(h)
  end
  if #keys <= Q.HISTORY_DAYS then return 0 end
  table.sort(keys)
  local n = 0
  while #keys > Q.HISTORY_DAYS do c.history[table.remove(keys, 1)] = nil n = n + 1 end
  return n
end

-- Série des 7 derniers jours connus (valeur du total ou d'une compétence).
function Q.Series(id)
  local c = Q.C()
  local keys = {}
  for k in pairs(c.history) do keys[#keys + 1] = k end
  table.sort(keys)
  local out = {}
  for i = math.max(1, #keys - 6), #keys do
    local h = c.history[keys[i]]
    local v = id and h.ranks and h.ranks[id] or (not id and h.total) or nil
    if v then out[#out + 1] = { day = keys[i], value = v } end
  end
  return out
end

-- 2. Mini-graphe 7 jours dans le détail --------------------------------------
function Q.UpdateGraph(f, d)
  if not f then return end
  local g = f.osrsGraph
  local id = d and d.id or nil
  local series = (ns.Opt("historique") and Q.Series(id)) or {}
  if #series < 2 then
    if g then g:Hide() end

    return nil
  end
  if not g then
    g = CreateFrame("Frame", nil, f)
    g.bars = {}
    g.label = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    g.label:SetPoint("BOTTOMLEFT", g, "TOPLEFT", 0, 1)
    f.osrsGraph = g
  end
  g:ClearAllPoints()
  -- v2.8.4 : placé sous le contenu par UI:StackDetailFooter (repli : sous le défilement)
  if f.scroll then
    g:SetPoint("TOPLEFT", f.scroll, "BOTTOMLEFT", 6, -16)
    g:SetPoint("TOPRIGHT", f.scroll, "BOTTOMRIGHT", -6, -16)
  else
    g:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 30)
    g:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 30)
  end
  g:SetHeight(24)
  local lo, hi = math.huge, -math.huge
  for _, p in ipairs(series) do lo = math.min(lo, p.value) hi = math.max(hi, p.value) end
  local span = hi - lo
  local w = (f.GetWidth and N(f:GetWidth()) or 200) - 44
  if w < 70 then w = 70 end
  local bw = math.floor(w / 7) - 3
  for i = 1, 7 do
    local b = g.bars[i]
    if not b then
      b = g:CreateTexture(nil, "ARTWORK")
      pcall(b.SetTexture, b, "Interface\\Buttons\\WHITE8X8")
      g.bars[i] = b
    end
    local p = series[i]
    if p then
      local h = (span > 0) and (4 + 20 * (p.value - lo) / span) or 12
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", (i - 1) * (bw + 3), 0)
      b:SetSize(bw, h)
      pcall(b.SetVertexColor, b, 0.25, 0.25, 0.75, 0.9)
      b._value = p.value
      b:Show()
    else
      b:Hide()
    end
  end
  local delta = series[#series].value - series[1].value
  g.label:SetText(#series .. Tr[" derniers jours : "] .. ((delta >= 0) and "+" or "") .. delta)
  g.series = series
  g:Show()
  return series
end

-- 3. Estimation du temps (rythme mesuré dans la session) ----------------------
function Q.ETALine(d)
  if not d or not ns.Opt("eta") then return nil end
  local cur = N(d.current) or 0
  if d.kind == "level" then
    local xp, maxxp = ns.GetPlayerXPSafe and ns.GetPlayerXPSafe()
    xp, maxxp = N(xp), N(maxxp)
    local spu = ns.Rate.SecondsPerUnit("xp")
    if xp and maxxp and spu and maxxp > xp then
      return Tr["Niveau "] .. (cur + 1) .. Tr[" dans "] .. ns.FormatDuration(spu * (maxxp - xp)) .. Tr[" (rythme mesuré)"]
    end
    return nil
  end
  local g = ns.GetGoal(d.id)
  local target = (g and g.rank > cur and g.rank) or N(d.apiMax)
  if not target or target <= cur then return nil end
  local weapon = ns.IsWeaponSkill and ns.IsWeaponSkill(d.id or d.skillID, d.kind, d.skillName or d.name)
  local cap = N(d.apiMax)
  local eta = ns.Rate.ETA("skill:" .. tostring(d.id), cur, target, weapon and cap or nil)
  if not eta then return nil end
  local tag = weapon and Tr[" (~ estimation)"] or Tr[" (rythme mesuré)"]
  return tostring(target) .. Tr[" dans "] .. ns.FormatDuration(eta) .. tag
end

-- 4. Liste de courses de l'objectif (recettes connues, composants en sac) ----
function Q.ShoppingList(d)
  if not d or not ns.Opt("courses") then return nil end
  local g = ns.GetGoal(d.id)
  if not g or g.rank <= (N(d.current) or 0) then return nil end
  local rec = ns.CharDB().recipes and ns.CharDB().recipes[d.id]
  if not rec then return nil end
  local useful = {}
  local order = { optimal = 3, medium = 2, easy = 1 }
  for _, r in ipairs(rec.list or {}) do
    if order[r.diff or ""] then useful[#useful + 1] = r end
  end
  table.sort(useful, function(a, b) return order[a.diff] > order[b.diff] end)
  if #useful == 0 then return { Tr["Courses : aucune recette orange / jaune / verte connue pour l'objectif."] } end
  local lines = { Tr["Courses pour l'objectif "] .. g.rank .. Tr[" (par fabrication) :"] }
  local DFR = ns.Scanner and ns.Scanner.DIFF_FR or {}
  for i = 1, math.min(3, #useful) do
    local r = useful[i]
    local parts = {}
    for _, rg in ipairs(r.reagents or {}) do
      local have = rg.id and N(Call(GetItemCount, rg.id)) or nil
      local nm = (ns.ItemDisplayName and ns.ItemDisplayName(rg.id, rg.name)) or rg.name or (rg.id and Str(Call(GetItemInfo, rg.id))) or Tr["composant"]
      if ns.BareItemIdLabel and ns.BareItemIdLabel(nm) then nm = Tr["composant"] end
      local s = nm .. Tr[" ×"] .. tostring(rg.count or 1)
      if have then s = s .. Tr[" (en sac "] .. have .. ((have < (rg.count or 1)) and Tr[", manque "] .. ((rg.count or 1) - have) or "") .. ")" end
      parts[#parts + 1] = s
    end
    lines[#lines + 1] = "• " .. r.name .. " (" .. Tr[DFR[r.diff] or r.diff] .. ")" .. Tr[" : "] .. table.concat(parts, ", ")
  end
  return lines
end

ns.SlashExt.courses = function(rest)
  local low = (rest or ""):lower()
  if low == "on" or low == "off" then return toggleCmd("courses", Tr["liste de courses"])(low) end
  local c = ns.CharDB()
  local any = false
  local snap = UI() and UI().snapshot or ns.Collect()
  for _, d in ipairs(snap.tiles or {}) do
    local l = (not d.placeholder) and Q.ShoppingList(d) or nil
    if l then any = true for _, x in ipairs(l) do ns.Print(x) end end
  end
  if not any then ns.Print(Tr["courses : fixe un objectif de Cuisine / Secourisme (clic droit) et ouvre le métier une fois pour lire les recettes."]) end
end

-- 5. Pêche : prises par zone --------------------------------------------------
function Q.Zone()
  return Str(Call(GetRealZoneText)) or Str(Call(GetZoneText)) or "?"
end
function Q.OnLootFishing()
  if not ns.Opt("peche") then return nil end
  if type(IsFishingLoot) ~= "function" or not Call(IsFishingLoot) then return nil end
  local zone = Q.Zone()
  local c = Q.C()
  local z = c.fishing[zone] or { catches = 0, items = {} }
  c.fishing[zone] = z
  z.catches = z.catches + 1
  local n = N(Call(GetNumLootItems)) or 0
  for slot = 1, n do
    local link = Str(Call(GetLootSlotLink, slot))
    local id = link and N(link:match("item:(%d+)"))
    if id then z.items[id] = (z.items[id] or 0) + 1 end
  end
  return zone, z.catches
end
function Q.FishingLines()
  if not ns.Opt("peche") then return nil end
  local c = Q.C()
  local zone = Q.Zone()
  local lines = {}
  local here = c.fishing[zone]
  lines[#lines + 1] = Tr["Prises ici ("] .. zone .. ") : " .. (here and here.catches or 0)
  local zs = {}
  for z, v in pairs(c.fishing) do if z ~= zone then zs[#zs + 1] = { z, v.catches } end end
  table.sort(zs, function(a, b) return a[2] > b[2] end)
  for i = 1, math.min(3, #zs) do lines[#lines + 1] = "  " .. zs[i][1] .. Tr[" : "] .. zs[i][2] end
  return lines
end

-- Lignes du panneau de détail --------------------------------------------------
function Q.DetailLines(d)
  local out = {}
  local eta = Q.ETALine(d)
  if eta then out[#out + 1] = eta end
  if d and d.id == "fishing" then
    for _, l in ipairs(Q.FishingLines() or {}) do out[#out + 1] = l end
  end
  for _, l in ipairs(Q.ShoppingList(d) or {}) do out[#out + 1] = l end
  return out
end

-- 6. Info-bulle du bandeau : autres personnages -------------------------------
function Q.AltTooltip(tt)
  if not ns.Opt("alts") or not tt then return 0 end
  local db = ns.EnsureDB()
  local me = ns.CharKey()
  -- 3.8.1 : « Nom- » et « Nom-Royaume » sont le même personnage (cf. AllCharSheets) :
  -- une seule ligne par nom, la fiche la plus récente, et jamais le personnage actuel.
  local function nm(k) return tostring(k):gsub("%-.*$", ""):lower() end
  local function stamp(c) return (type(c.sheet) == "table" and N(c.sheet.updated)) or 0 end
  local mineName, best = nm(me), {}
  for key, c in pairs(db.chars or {}) do
    local n = nm(key)
    if n ~= mineName and N(c.lastTotal) then
      local b = best[n]
      if not b or stamp(c) > stamp(b[2]) or (stamp(c) == stamp(b[2]) and (N(c.lastTotal) or 0) > (N(b[2].lastTotal) or 0)) then
        best[n] = { key, c }
      end
    end
  end
  local rows = {}
  for _, r in pairs(best) do rows[#rows + 1] = r end
  if #rows == 0 then return 0 end
  table.sort(rows, function(a, b) return (a[2].lastTotal or 0) > (b[2].lastTotal or 0) end)
  pcall(tt.AddLine, tt, " ")
  pcall(tt.AddLine, tt, Tr["Autres personnages"], 1, 0.82, 0)
  local mine = N(Q.C().lastTotal) or 0
  for _, r in ipairs(rows) do
    local c = r[2]
    local diff = c.lastTotal - mine
    local right = tostring(c.lastTotal) .. " (" .. ((diff >= 0) and "+" or "") .. diff .. ")"
    local left = r[1]:gsub("%-.*$", "") .. (c.lastLevel and (Tr[" · niv. "] .. c.lastLevel) or "")
    pcall(tt.AddDoubleLine, tt, left, right, 1, 1, 1, 1, 1, 1)
  end
  return #rows
end

-- 7. Récap de session ----------------------------------------------------------
function Q.SessionStart()
  local c = ns.CharDB()
  c.session.startRanks = nil
  c.session.startXP = nil
  c.session.baseline = nil
  Q._sessionXP = 0
end
function Q.EnsureStartRanks(snap)
  local c = ns.CharDB()
  if not snap or (snap.liveCount or 0) <= 0 then return end
  if not c.session.startRanks then
    local r = {}
    for _, d in ipairs(snap.tiles or {}) do if d.id and N(d.current) then r[d.id] = { n = d.name, v = N(d.current) } end end
    c.session.startRanks = r
  end
  local tot = N(snap.total)
  local base = N(c.session.baseline)
  if tot and tot > 0 and (base == nil or base <= 0) then
    c.session.baseline = tot
  end
end
function Q.RecapLine()
  local c = ns.CharDB()
  local snap = UI() and UI().snapshot
  if not snap then local ok, s2 = pcall(ns.Collect) snap = ok and s2 or nil end
  if not snap then return nil end
  local parts = {}
  local gain = ns.SessionGain(snap.total)
  parts[#parts + 1] = Tr["niveau total "] .. ((gain or 0) >= 0 and "+" or "") .. tostring(gain or 0)
  local xp = UI() and UI()._sessionXP or 0
  if xp > 0 then parts[#parts + 1] = "+" .. xp .. Tr[" XP"] end
  local start = c.session.startRanks or {}
  for _, d in ipairs(snap.tiles or {}) do
    local s = start[d.id]
    local cur = N(d.current)
    if s and cur and cur > s.v then parts[#parts + 1] = (d.name or d.id) .. " +" .. (cur - s.v) end
  end
  local started = N(c.session.started)
  local now = (type(time) == "function" and time()) or nil
  local dur = (started and now and now > started) and ns.FormatDuration(now - started) or nil
  return Tr["Session : "] .. table.concat(parts, ", ") .. (dur and (" (" .. dur:gsub("^~", "") .. ")") or "")
end

-- Toast de déconnexion : titre court + une ligne compacte (pas la ligne de chat entière).
function Q.RecapToastTitle(why)
  return Tr["Session"]
end
function Q.RecapShort()
  local c = ns.CharDB()
  local snap = UI() and UI().snapshot
  if not snap then local ok, s2 = pcall(ns.Collect) snap = ok and s2 or nil end
  if not snap then return nil end
  local bits = {}
  local gain = ns.SessionGain(snap.total)
  if gain and gain ~= 0 then
    bits[#bits + 1] = ((gain >= 0) and "+" or "") .. tostring(gain)
  end
  local xp = UI() and UI()._sessionXP or 0
  if xp and xp > 0 then bits[#bits + 1] = "+" .. tostring(xp) .. " XP" end
  local start, n = c.session.startRanks or {}, 0
  for _, d in ipairs(snap.tiles or {}) do
    local s, cur = start[d.id], N(d.current)
    if s and cur and cur > s.v then n = n + 1 end
  end
  if n > 0 then
    bits[#bits + 1] = "+" .. tostring(n) .. " " .. (n > 1 and Tr["compétences"] or Tr["compétence"])
  end
  local started = N(c.session.started)
  local now = (type(time) == "function" and time()) or nil
  local dur = (started and now and now > started) and ns.FormatDuration(now - started) or nil
  if dur then bits[#bits + 1] = dur:gsub("^~", "") end
  if #bits == 0 then return nil end
  return table.concat(bits, " · ")
end
ns.SlashExt.recap = function(rest)
  local low = (rest or ""):lower()
  if low == "on" or low == "off" then return toggleCmd("recapLogout", Tr["récap à la déconnexion"])(low) end
  if ns.ProgressUI and ns.ProgressUI.OpenRecap then
    pcall(ns.ProgressUI.OpenRecap, "current")
    return
  end
  local l = Q.RecapLine()
  ns.Print(l or Tr["récap indisponible (compétences pas encore lues)."])
end

-- 8. Maj+clic : insérer « Dépeçage 161/225 » dans la zone de saisie du chat ---
function Q.ShareText(d)
  if not d then return nil end
  local cur = N(d.current) or 0
  local cap = N(d.apiMax) or 0
  local name = (d.combatTile and d.skillName) or d.name or "?"
  return name .. " " .. cur .. ((cap > 0) and ("/" .. cap) or "")
end
function Q.ShareTile(d)
  local text = Q.ShareText(d)
  if not text then return false end
  local eb = Call(_G.ChatEdit_GetActiveWindow)
  if type(eb) == "table" and eb.Insert then
    pcall(eb.Insert, eb, text)
    return true
  end
  if type(_G.ChatFrame_OpenChat) == "function" then
    pcall(_G.ChatFrame_OpenChat, text)
    return true
  end
  return false
end

-- 9. Maîtres d'armes vus en jeu (fenêtre d'entraîneur) -------------------------
function Q.OnTrainerShow()
  local n = N(Call(GetNumTrainerServices)) or 0
  if n <= 0 then return 0 end
  local npc = Str(Call(UnitName, "npc")) or "?"
  local zone = Q.Zone()
  local found = 0
  for i = 1, n do
    local name, _, category = Call(GetTrainerServiceInfo, i)
    name = Str(name)
    if name and category ~= "header" then
      local e = ns.LookupCatalog and ns.LookupCatalog(name)
      if e and (e.kind == "melee" or e.kind == "ranged") then
        Q.Global().weaponMasters[e.id] = { npc = npc, zone = zone, when = Today() }
        found = found + 1
      end
    end
  end
  return found
end

Q._warnedWeapon = {}
function Q.CheckUnlearnedWeapon()
  if not ns.Opt("maitreArmes") or InCombat() then return nil end
  local info = ns.GetEquippedItemInfo(ns.GetInventorySlot("main"))
  if not info then return nil end
  local id = ns.MapWeaponSubtype(info.subType, N(info.classID), N(info.subclassID))
  if not id then return nil end
  local snap = (ns.SkillRankSnapshotCached and ns.SkillRankSnapshotCached()) or (ns.SkillRankSnapshot and ns.SkillRankSnapshot()) or {}
  local e = ns.CatalogById(id)
  if not e then return nil end
  local live = snap[ns.Fold(e.name)]
  if live and (N(live.rank) or 0) > 0 then return nil end
  local m = Q.Global().weaponMasters[id]
  if not m then return nil end  -- rien de vu en jeu : pas de rappel
  if Q._warnedWeapon[id] then return nil end
  Q._warnedWeapon[id] = true
  Drop(info.texture or e.icon, ns.CatalogDisplayName(e) .. Tr[" : compétence non apprise"], Tr["Maître d'armes vu : "] .. m.npc, { kind = "maitre", hint = m.zone })
  return m
end

-- 10. Arme principale : mémoriser, rappeler, remettre (hors combat) ------------
function Q.MainWeaponHint()
  if not ns.Opt("armePrincipale") then return nil end
  local c = ns.CharDB()
  local mw = c.mainWeapon
  if not mw or not mw.id then return nil end
  local cur = N(Call(GetInventoryItemID, "player", ns.GetInventorySlot("main")))
  if cur == mw.id then return nil end
  return Tr["Arme principale : "] .. tostring(mw.name or mw.id) .. Tr[" — /drop arme pour la remettre (hors combat)"]
end
ns.SlashExt.arme = function(rest)
  local low = (rest or ""):lower()
  local c = ns.CharDB()
  if low == "on" or low == "off" then return toggleCmd("armePrincipale", Tr["rappel de l'arme principale"])(low) end
  if low == "principale" or low == "set" or low == "memoriser" or low == "mémoriser" then
    local info = ns.GetEquippedItemInfo(ns.GetInventorySlot("main"))
    if not info or not N(info.id) then ns.Print(Tr["aucune arme en main."]) return end
    c.mainWeapon = { id = N(info.id), name = Str(info.name) }
    ns.Print(Tr["arme principale mémorisée : "] .. tostring(info.name or info.id) .. ".")
    return
  end
  local mw = c.mainWeapon
  if not mw then ns.Print(Tr["aucune arme principale. Équipe-la puis /drop arme principale."]) return end
  if InCombat() then ns.Print(Tr["en combat : remets "] .. tostring(mw.name or mw.id) .. Tr[" après le combat."]) return end
  local cur = N(Call(GetInventoryItemID, "player", ns.GetInventorySlot("main")))
  if cur == mw.id then ns.Print(tostring(mw.name or mw.id) .. Tr[" est déjà en main."]) return end
  if N(Call(GetItemCount, mw.id)) == 0 then ns.Print(tostring(mw.name or mw.id) .. Tr[" n'est pas dans tes sacs."]) return end
  local ok = pcall(EquipItemByName, mw.id)
  ns.Print(ok and (Tr["arme principale remise : "] .. tostring(mw.name or mw.id) .. ".") or Tr["échange refusé par le jeu."])
end

-- 11. Défense : adversaire gris (une fois par session) -------------------------
function Q.CheckDefenseTarget()
  if not ns.Opt("defense") then Q._defenseTip = nil return nil end
  if not Call(UnitCanAttack, "player", "target") then return nil end
  local lvl = N(Call(UnitLevel, "target"))
  if not lvl or lvl <= 0 then return nil end
  local col = Call(GetQuestDifficultyColor, lvl)
  local trivial = _G.QuestDifficultyColors and _G.QuestDifficultyColors.trivial
  local isGray = type(col) == "table" and trivial and col == trivial
  if not isGray and type(col) == "table" and type(trivial) == "table" then
    isGray = N(col.r) == N(trivial.r) and N(col.g) == N(trivial.g) and N(col.b) == N(trivial.b)
  end
  -- 3.9.0 : niveau de la cible grise retenu aussi pour les cases d'arme (une arme ne monte pas non plus)
  Q._greyTarget = isGray and lvl or nil
  if not isGray then Q._defenseTip = nil return nil end
  local snap = (ns.SkillRankSnapshotCached and ns.SkillRankSnapshotCached()) or (ns.SkillRankSnapshot and ns.SkillRankSnapshot()) or {}
  local def = snap[ns.Fold("Défense")]
  if not def then return nil end
  local cur, maxv = N(def.rank) or 0, N(def.max) or 0
  if maxv <= 0 then maxv = (N(ns.GetPlayerLevel()) or 0) * (ns.WEAPON_RANK_PER_LEVEL or 5) end
  if cur >= maxv then return nil end
  Q._defenseWarned = true
  -- Pas de toast : le rappel reste sur l'infobulle de la case Défense.
  Q._defenseTip = Tr["Défense "] .. cur .. "/" .. maxv .. " — " .. Tr["Adversaire gris (niveau "] .. lvl .. ")"
  return true
end

-- 12. Armes à monter (3.9.0) ----------------------------------------------------
-- Niveau gris (Classic) : en dessous ou égal, un adversaire ne fait monter ni arme ni Défense.
function ns.GreyLevel(p)
  p = N(p) or 1
  if p <= 5 then return 0
  elseif p <= 39 then return p - math.floor(p / 10) - 5
  elseif p <= 59 then return p - math.floor(p / 5) - 1 end
  return p - 9
end
-- plage conseillée : du premier niveau non gris à 2 niveaux au-dessus du joueur
function Q.WeaponLevelRange()
  local p = N(ns.GetPlayerLevel and ns.GetPlayerLevel()) or 1
  return math.max(1, ns.GreyLevel(p) + 1), p + 2
end
local COMBAT = { melee = true, ranged = true, feral = true, defense = true }
function Q.SnapEntry(snap, e)
  local keys = { e.name, ns.CATALOG_EN and ns.CATALOG_EN[e.id] }
  for _, a in ipairs(e.aliases or {}) do keys[#keys + 1] = a end
  for _, k in ipairs(keys) do
    if k then local v = snap[ns.Fold(k)] if v then return v end end
  end
end
-- armes (et Défense) apprises, pas au maximum, de la plus en retard à la moins en retard
function Q.WeaponsToLevel()
  local snap = (ns.SkillRankSnapshotCached and ns.SkillRankSnapshotCached()) or (ns.SkillRankSnapshot and ns.SkillRankSnapshot()) or {}
  local p = N(ns.GetPlayerLevel and ns.GetPlayerLevel()) or 1
  local cap = p * (ns.WEAPON_RANK_PER_LEVEL or 5)
  local out = {}
  for _, e in ipairs(ns.CATALOG or {}) do
    if COMBAT[e.kind] then
      local v = Q.SnapEntry(snap, e)
      local cur = v and N(v.rank) or 0
      if cur > 0 then
        local mx = N(v.max) or 0
        if mx <= 0 then mx = cap end
        if cur < mx then
          out[#out + 1] = { id = e.id, name = (ns.CatalogDisplayName and ns.CatalogDisplayName(e)) or e.name, cur = cur, max = mx, gap = mx - cur }
        end
      end
    end
  end
  table.sort(out, function(a, b) if a.gap ~= b.gap then return a.gap > b.gap end return tostring(a.name) < tostring(b.name) end)
  return out
end
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.armes = function()
  local list = Q.WeaponsToLevel()
  if #list == 0 then ns.Print(Tr["Toutes tes armes et ta Défense sont au maximum."]) return end
  local lo, hi = Q.WeaponLevelRange()
  ns.Print(string.format(Tr["Armes à monter (monstres niv. %d à %d) :"], lo, hi))
  for _, w in ipairs(list) do ns.Print(string.format("  %s %d/%d  (-%d)", tostring(w.name), w.cur, w.max, w.gap)) end
end
ns.SlashExt.weapons = ns.SlashExt.armes
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop armes : armes et Défense à monter, de la plus en retard, et niveaux de monstres conseillés"

-- Événements -------------------------------------------------------------------
if ns.On then
  ns.On("PLAYER_ENTERING_WORLD", function()
    if Q._sessionHandled then return end
    Q._sessionHandled = true
    if ns.sessionFresh then Q.SessionStart() end
  end)
  ns.On("LOOT_OPENED", function() pcall(Q.OnLootFishing) end)
  ns.On("TRAINER_SHOW", function() pcall(Q.OnTrainerShow) end)
  ns.On("PLAYER_EQUIPMENT_CHANGED", function() pcall(Q.CheckUnlearnedWeapon) end)
  ns.On("PLAYER_TARGET_CHANGED", function() if not InCombat() then pcall(Q.CheckDefenseTarget) end end)
  ns.On("PLAYER_REGEN_DISABLED", function() pcall(Q.CheckDefenseTarget) end)

-- 3.9.0 : posé une fois tous les fichiers chargés. QoL.lua passe AVANT Compact.lua dans le .toc :
-- au chargement, ns.Compact n'existait pas et ces lignes n'étaient jamais ajoutées.
local function HookCompactTip()
  if Q._tipHooked or not (ns.Compact and ns.Compact.TooltipModel) then return end
  Q._tipHooked = true
  local baseTip = ns.Compact.TooltipModel
  function ns.Compact.TooltipModel(d)
    local m = baseTip(d)
    local tip = Q._defenseTip
    if tip and m and m.lines and d and (d.kind == "defense" or d.id == "defense") then
      m.lines[#m.lines + 1] = { tip, 0.85, 0.85, 0.85, true }
    end
    -- 3.9.0 : cases d'arme et de Défense pas au maximum : où monter, et cible grise = pas de point
    if m and m.lines and d and COMBAT[d.kind] and ns.Opt("weaponLevels") then
      local cur, mx = N(d.current) or 0, N(d.apiMax) or 0
      if mx <= 0 then mx = (N(ns.GetPlayerLevel and ns.GetPlayerLevel()) or 1) * (ns.WEAPON_RANK_PER_LEVEL or 5) end
      if cur > 0 and cur < mx then
        local lo, hi = Q.WeaponLevelRange()
        m.lines[#m.lines + 1] = { string.format(Tr["Monte sur des monstres niv. %d à %d"], lo, hi), 0.85, 0.85, 0.85, true }
        if Q._greyTarget and d.kind ~= "defense" and ns.Opt("defense") then
          m.lines[#m.lines + 1] = { string.format(Tr["Cible grise (niveau %d) : pas de point"], Q._greyTarget), 1, 0.5, 0.3, true }
        end
      end
    end
    return m
  end
end
HookCompactTip()
ns.On("PLAYER_LOGIN", HookCompactTip)
  -- 3.3.16 : le récap n'est plus écrit à PLAYER_LOGOUT (caché par l'écran de
  -- chargement) mais au DÉBUT du compte à rebours de déconnexion / sortie :
  -- toast visible pendant le décompte + ligne de chat ; annulé par LOGOUT_CANCEL.
  ns.On("PLAYER_CAMPING", function() Q.LogoutRecap(Tr["déconnexion"]) end)
  ns.On("PLAYER_QUITING", function() Q.LogoutRecap(Tr["sortie du jeu"]) end)
  ns.On("LOGOUT_CANCEL", function() Q.CancelLogoutRecap() end)
  if type(hooksecurefunc) == "function" then
    -- crochets POST-appel (sûrs, rien n'est remplacé) : déconnexion instantanée
    -- (auberge) ou client qui n'envoie pas l'événement
    for _, fn in ipairs({ "Logout", "Quit" }) do
      if type(_G[fn]) == "function" then pcall(hooksecurefunc, fn, function() Q.LogoutRecap(fn == "Quit" and Tr["sortie du jeu"] or Tr["déconnexion"]) end) end
    end
  end
end
Q.LOGOUT_SECONDS = 20          -- compte à rebours standard (hors auberge / ville)
Q.recapStats = { shown = 0, cancelled = 0, skipped = 0 }
function Q.LogoutRecap(why)
  if not ns.Opt("recapLogout") then return nil end
  local now = (type(GetTime) == "function" and GetTime()) or 0
  if Q._recapAt and now - Q._recapAt < 3 then
    Q.recapStats.skipped = Q.recapStats.skipped + 1      -- événement + crochet : une seule fois
    return Q._recapToast or nil
  end
  Q._recapAt = now
  local ok, l = pcall(Q.RecapLine)
  if not (ok and l) then return nil end
  ns.Print(l)
  Q.recapStats.shown = Q.recapStats.shown + 1
  Q._recapToast = false
  local U = UI()
  if U and U.SpawnDrop and not InCombat() then
    local title = (Q.RecapToastTitle and Q.RecapToastTitle(why)) or Tr["Session"]
    local body = (Q.RecapShort and Q.RecapShort()) or l:gsub("^" .. (Tr["Session : "]:gsub("%p", "%%%0")), "")
    local icon = "Interface\\AddOns\\Dropamine\\Media\\SkillsTab"
    local okT, t = pcall(U.SpawnDrop, U, icon, title, body, nil, nil, "",
      { hold = Q.LOGOUT_SECONDS, dedupeKey = "osrs-logout-recap", kind = "recap" })
    if okT and t then
      t._fullTitle = Tr["Récap de session — "] .. tostring(why or Tr["déconnexion"])
      t._fullSub = l
      Q._recapToast = t
    end
  end
  return Q._recapToast
end
function Q.CancelLogoutRecap()
  local t = Q._recapToast
  Q._recapAt, Q._recapToast = nil, nil
  if t and t._dismiss then t._dismiss() Q.recapStats.cancelled = Q.recapStats.cancelled + 1 return true end
  return false
end
-- Point de départ des rangs de la session (au premier instantané lisible).
local prevOnSnap = Q.OnSnapshot
Q.OnSnapshot = function(snap)
  Q.EnsureStartRanks(snap)
  return prevOnSnap(snap)
end

ns.HelpExt[#ns.HelpExt + 1] = "/drop recap : résumé de la session (/drop recap on|off : toast + ligne au début du compte à rebours de déconnexion)"
ns.HelpExt[#ns.HelpExt + 1] = "/drop courses : composants des recettes utiles pour tes objectifs"
ns.HelpExt[#ns.HelpExt + 1] = "/drop arme principale : mémoriser l'arme en main · /drop arme : la remettre (hors combat)"
ns.HelpExt[#ns.HelpExt + 1] = "/drop eta|prepalier|historique|alts|jalons|peche|defense|partage|maitre on|off"

ns.DebugExt[#ns.DebugExt + 1] = function()
  local c = Q.C()
  local out = { "— Qualité de vie (v2.7.0) —" }
  local nh, nf = 0, 0
  for _ in pairs(c.history) do nh = nh + 1 end
  for _, z in pairs(c.fishing) do nf = nf + (z.catches or 0) end
  local nm = 0
  for _ in pairs(Q.Global().weaponMasters) do nm = nm + 1 end
  out[#out + 1] = string.format("  historique : %d jour(s) ; prises de pêche : %d ; maîtres d'armes vus : %d", nh, nf, nm)
  out[#out + 1] = "  rythme XP : " .. tostring(ns.Rate.SecondsPerUnit("xp") and "mesuré" or "pas encore") .. " ; arme principale : " .. tostring(c.mainWeapon and (c.mainWeapon.name or c.mainWeapon.id) or "aucune")
  out[#out + 1] = "  API : IsFishingLoot " .. tostring(type(_G.IsFishingLoot) == "function") .. ", GetTrainerServiceInfo " .. tostring(type(_G.GetTrainerServiceInfo) == "function") .. ", GetQuestDifficultyColor " .. tostring(type(_G.GetQuestDifficultyColor) == "function") .. ", ChatEdit_GetActiveWindow " .. tostring(type(_G.ChatEdit_GetActiveWindow) == "function") .. ", EquipItemByName " .. tostring(type(_G.EquipItemByName) == "function")
  return out
end

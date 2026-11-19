-- Dropamine 3.5.0 — petits retours de dopamine.
-- Chaque fonction a sa case. Rien ne tourne au repos : un C_Timer seulement
-- pendant un combo, un OnUpdate seulement pendant la barre du prochain point
-- (retiré hors de ce cas, et en combat). Pas de fichier audio : kits du jeu.
local _, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local D = {}
ns.Dopamine = D
D.WINDOW = 60
D.DAILY_STEP = 5

local function Now()
  return (ns.Now and ns.Now()) or (type(_G.GetTime) == "function" and _G.GetTime()) or 0
end
local function InCombat()
  return ns.InCombat and ns.InCombat() and true or false
end

function D.C()
  local c = ns.CharDB()
  c.dopamine = c.dopamine or {}
  local d = c.dopamine
  d.skins = d.skins or {}
  d.fish = d.fish or {}
  d.records = d.records or {}
  return d
end

-- Réglages. Défaut « on » = ns.Opt (nil). Sons = ns.OptOff (nil = coupé),
-- sauf l'interrupteur maître « Sons » (nil = ouvert, pour ne pas couper un
-- son déjà coché). Les cases existantes (niveau, scanner) gardent leur défaut.
D.OPTIONS = {
  { type = "check", key = "combo", label = "Combo de session", default = true, cmd = "/drop combo on|off",
    help = "x2, x3… quand un point tombe dans les 60 s ; ça retombe ensuite." },
  { type = "check", key = "nextBar", label = "Barre du prochain point", default = true, cmd = "/drop barre on|off",
    help = "Fine barre sous la case en cours, seulement si le rythme est mesuré." },
  { type = "check", key = "collection", label = "Collection", default = true, cmd = "/drop collection on|off",
    help = "Premiers types dépecés et premiers poissons, par personnage." },
  { type = "check", key = "daily", label = "Défi du jour", default = true, cmd = "/drop defi on|off",
    help = "Un objectif au hasard parmi tes compétences, une fois par jour." },
  { type = "check", key = "maxFx", label = "Célébration du maximum", default = true, cmd = "/drop max on|off",
    help = "Grande animation dorée quand un métier ou une arme atteint son max." },
  { type = "check", key = "records", label = "Records personnels", default = true, cmd = "/drop records on|off",
    help = "Plus gros total de session et meilleure heure, avec un toast." },
  { type = "check", key = "sounds", label = "Sons", default = true, cmd = "/drop sons on|off",
    help = "Interrupteur général. Chaque son se règle à part, coupés par défaut." },
  { type = "check", key = "soundSkill", label = "Son à chaque point", default = false, cmd = "/drop son point on|off",
    help = "Petit son du jeu à chaque point de compétence." },
  { type = "check", key = "soundPalier", label = "Son de palier", default = false, cmd = "/drop son palier on|off",
    help = "Autre son du jeu quand tu franchis un palier (75, 150, 225, 300)." },
  { type = "check", key = "soundMax", label = "Son du maximum", default = false, cmd = "/drop son max on|off",
    help = "Son du jeu avec la célébration du maximum." },
  { type = "check", key = "soundDaily", label = "Son du défi", default = false, cmd = "/drop son defi on|off",
    help = "Son du jeu quand le défi du jour est réussi." },
  { type = "check", key = "soundRecord", label = "Son de record", default = false, cmd = "/drop son record on|off",
    help = "Son du jeu avec le toast « Nouveau record ! »." },
}
if ns.Options then
  local H = ns.Options.EXTRA_HOME
  H.combo, H.nextBar = "notif", "display"
  H.collection, H.daily = "prof", "prof"
  H.maxFx, H.records = "notif", "notif"
  H.sounds = "sounds"
  H.soundSkill, H.soundPalier, H.soundMax = "sounds", "sounds", "sounds"
  H.soundDaily, H.soundRecord = "sounds", "sounds"
  for _, it in ipairs(D.OPTIONS) do ns.Options.EXTRA[#ns.Options.EXTRA + 1] = it end
end

local TOGGLE = {
  combo = "combo de session", barre = "barre du prochain point", collection = "collection",
  defi = "défi du jour", max = "célébration du maximum", records = "records personnels", sons = "sons",
}
local TOGGLE_KEY = { combo = "combo", barre = "nextBar", collection = "collection", defi = "daily", max = "maxFx", records = "records", sons = "sounds" }
local SOUND_KEY = { point = "soundSkill", palier = "soundPalier", max = "soundMax", defi = "soundDaily", record = "soundRecord" }

local function toggle(key, label, rest)
  local cur = (key == "sounds" or key == "combo" or key == "nextBar" or key == "collection" or key == "daily" or key == "maxFx" or key == "records") and ns.Opt(key) or ns.OptOff(key)
  if key == "soundSkill" or key == "soundPalier" or key == "soundMax" or key == "soundDaily" or key == "soundRecord" then cur = ns.OptOff(key) end
  local v = ns.ParseOnOff(rest, cur)
  if ns.Options then ns.Options.Set(key, v) else ns.SetOpt(key, v) end
  if ns.Print then ns.Print(Tr[label] .. (v and Tr[" : activé."] or Tr[" : désactivé."])) end
  return v
end
ns.SlashExt = ns.SlashExt or {}
for cmd, label in pairs(TOGGLE) do
  local key = TOGGLE_KEY[cmd]
  ns.SlashExt[cmd] = function(rest) toggle(key, label, rest) end
end
ns.SlashExt.son = function(rest)
  local which, arg = (rest or ""):match("^(%S*)%s*(%S*)")
  which = (which or ""):lower()
  local key = SOUND_KEY[which]
  if not key then
    if ns.Print then ns.Print(Tr["usage : /drop son point|palier|max|defi|record on|off"]) end
    return
  end
  toggle(key, Tr["son ("] .. which .. ")", arg)
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop combo|defi|records|barre|collection|sons on|off · /drop son point|palier|max|defi|record on|off"

-- Kits du jeu seulement (SOUNDKIT si le client l'a, sinon nom classique).
D.KITS = {
  soundSkill = { "IG_QUEST_LOG_OPEN", "QUEST_LOG_OPEN" },
  soundPalier = { "IG_QUEST_LIST_COMPLETE", "ALARM_CLOCK_WARNING_3" },
  soundMax = { "UI_EPICLOOT_TOAST", "RAID_WARNING" },
  soundDaily = { "IG_QUEST_LIST_COMPLETE", "QUEST_COMPLETED" },
  soundRecord = { "UI_LEGENDARY_LOOT_TOAST", "LEVELUP" },
}
D.CLASSIC = {
  soundSkill = "igQuestLogOpen",
  soundPalier = "igQuestListComplete",
  soundMax = "LevelUp",
  soundDaily = "igQuestListComplete",
  soundRecord = "LevelUp",
}
function D.Play(key, force)
  if not force and not ns.SoundOk(key) then return nil end
  if type(_G.PlaySound) ~= "function" then return nil end
  local S = _G.SOUNDKIT
  if type(S) == "table" then
    for _, name in ipairs(D.KITS[key] or {}) do
      local v = S[name]
      if type(v) == "number" then
        if pcall(_G.PlaySound, v, "SFX") or pcall(_G.PlaySound, v) then
          D.lastSound = name
          return name
        end
      end
    end
  end
  local classic = D.CLASSIC[key]
  if classic and pcall(_G.PlaySound, classic) then
    D.lastSound = classic
    return classic
  end
  return nil
end

function D.LiveCombo(now)
  local d = D.C()
  if not d.combo or not d.comboLast then return 0 end
  now = now or Now()
  local idle = now - d.comboLast
  if idle < 0 then idle = 0 end
  local n = d.combo - math.floor(idle / D.WINDOW)
  if n < 0 then n = 0 end
  return n
end
function D.NoteCombo(now)
  if not ns.Opt("combo") then return nil end
  local d = D.C()
  now = now or Now()
  local n = 1
  if d.comboLast and (now - d.comboLast) >= 0 and (now - d.comboLast) <= D.WINDOW then
    n = (d.combo or 1) + 1
  end
  d.combo, d.comboLast = n, now
  if n > (d.bestCombo or 0) then d.bestCombo = n end
  D.ArmDecay()
  D.ShowCombo()
  return n
end
function D.ArmDecay()
  if D._decayArmed then return end
  if D.LiveCombo() < 2 then D.ShowCombo() return end
  D._decayArmed = true
  -- L'échéance est lue sur l'horloge : un rappel trop tôt (tests qui vident
  -- la file sans avancer le temps) ne relance pas une boucle.
  local due = Now() + D.WINDOW
  local function tick()
    D._decayArmed = false
    if Now() + 0.01 < due then return end
    D.ShowCombo()
    if D.LiveCombo() >= 2 then D.ArmDecay() end
  end
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
    _G.C_Timer.After(D.WINDOW, tick)
  end
end
function D.ShowCombo()
  local n = ns.Opt("combo") and D.LiveCombo() or 0
  local parent = ns.Window and ns.Window.frame
  if n < 2 or not parent or type(_G.CreateFrame) ~= "function" then
    if D.badge then D.badge:Hide() end
    return n
  end
  if not D.badge then
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(48, 18)
    f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, 8)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetAllPoints()
    if fs.SetJustifyH then fs:SetJustifyH("RIGHT") end
    f.text = fs
    D.badge = f
  end
  D.badge.text:SetText("x" .. n)
  D.badge:Show()
  return n
end

function D.CrossedPalier(kind, fromR, toR)
  if kind ~= "profession" and kind ~= "secondary" then return nil end
  local steps = ns.PROFESSION_STEPS or { 75, 150, 225, 300 }
  for i = 1, #steps do
    local s = steps[i]
    if fromR < s and toR >= s then return s end
  end
  return nil
end
function D.ReachedMax(kind, fromR, toR, maxv)
  maxv = tonumber(maxv) or 0
  if maxv <= 0 or toR < maxv or fromR >= maxv then return false end
  if kind == "profession" or kind == "secondary" then
    return toR >= (ns.PROF_FINAL_CAP or 300)
  end
  if kind == "melee" or kind == "ranged" or kind == "feral" then return true end
  return false
end

function D.Toast(title, sub, icon, opts)
  local ui = ns.UI
  if not (ui and ui.SpawnDrop) then return nil end
  return ui:SpawnDrop(icon, title, sub, nil, nil, nil, opts or { kind = "dopamine" })
end
function D.Celebrate(info)
  if not ns.Opt("maxFx") then return nil end
  local f = D.Toast((info.name or Tr["Compétence"]) .. Tr[" au maximum !"], tostring(info.to) .. " / " .. tostring(info.max), info.icon,
    { kind = "max", variant = "gold", big = true, skillId = info.id })
  local ui = ns.UI
  if f and ui and ui.AttachFlareFx then pcall(ui.AttachFlareFx, ui, f, true) end
  return f
end

function D.HourKey(now)
  local fn = (type(_G.date) == "function" and _G.date) or (os and os.date)
  if type(fn) == "function" then
    local ok, v = pcall(fn, "%Y-%m-%d-%H", now)
    if ok and type(v) == "string" then return v end
  end
  return tostring(math.floor((now or 0) / 3600))
end
function D.AddPoints(delta, now)
  if not ns.Opt("records") or not delta or delta <= 0 then return nil end
  local r = D.C().records
  now = now or Now()
  r.session = (r.session or 0) + delta
  local hour = D.HourKey(now)
  if r.hourKey ~= hour then r.hourKey, r.hourPts = hour, 0 end
  r.hourPts = (r.hourPts or 0) + delta
  local toast
  -- 3.5.4 : plus d'enchaînement « Nouveau record » à chaque point. Le record
  -- de session ne sonne qu'en franchissant des paliers croissants (25, 50,
  -- 100, 200…) au-delà du meilleur, et jamais sous 25 points (premiers niveaux).
  local MIN = 25
  if r.bestSession == nil then r.bestSession = r.session end
  if r.session > r.bestSession then
    r.bestSession = r.session
    local step = r.recStep or MIN
    if r.session >= MIN and r.session >= step then
      while step <= r.session do step = step * 2 end
      r.recStep = step
      toast = D.Toast(Tr["Nouveau record !"], r.session .. Tr[" points cette session"])
      D.Play("soundRecord")
    end
  end
  -- record horaire : une seule annonce par heure, et seulement au-delà de 25 points
  if r.bestHour == nil then r.bestHour = r.hourPts end
  if r.hourPts > r.bestHour then
    r.bestHour = r.hourPts
    if not toast and r.hourPts >= MIN and r.hourRecKey ~= hour then
      r.hourRecKey = hour
      D.Toast(Tr["Nouveau record !"], r.hourPts .. Tr[" points cette heure"])
      D.Play("soundRecord")
    end
  end
  return r
end

function D.Hash(s)
  local h = 0
  s = tostring(s or "")
  for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 1000003 end
  return h
end
function D.Eligible(list)
  local out = {}
  for _, s in ipairs(list or {}) do
    local cur = tonumber(s.current or s.cur) or 0
    local mx = tonumber(s.max or s.apiMax) or 0
    local kind = s.kind
    if s.id and (s.name or s.skillName) and not s.placeholder and kind ~= "level" and kind ~= "total" and kind ~= "pvp" and kind ~= "stat" then
      if mx <= 0 or cur + D.DAILY_STEP <= mx then
        out[#out + 1] = { id = s.id, name = s.name or s.skillName, current = cur, max = mx }
      end
    end
  end
  return out
end
function D.EnsureDaily(list, day, salt)
  if not ns.Opt("daily") then return nil end
  local d = D.C()
  day = day or (ns.TodayKey and ns.TodayKey()) or "0"
  if d.daily and d.daily.day == day and d.daily.id then return d.daily end
  local pool = D.Eligible(list)
  if #pool == 0 then return nil end
  local pick = pool[(D.Hash(tostring(salt or ns.CharKey and ns.CharKey() or "") .. "|" .. day) % #pool) + 1]
  d.daily = { day = day, id = pick.id, name = pick.name, start = pick.current, goal = pick.current + D.DAILY_STEP, done = false }
  return d.daily
end
function D.DailyLine(id, name, cur)
  if not ns.Opt("daily") then return nil end
  local g = D.C().daily
  if not g then return nil end
  if id ~= g.id and name ~= g.name then return nil end
  local need = (g.goal or 0) - (g.start or 0)
  if g.done then return Tr["Défi du jour réussi : +"] .. need .. Tr[" en "] .. tostring(g.name) end
  local prog = math.max(0, (tonumber(cur) or g.start or 0) - (g.start or 0))
  if prog > need then prog = need end
  return string.format(Tr["Défi du jour : +%d en %s (%d/%d)"], need, tostring(g.name), prog, need)
end
function D.DailyProgress(info)
  local g = D.C().daily
  if not g or g.done or not ns.Opt("daily") then return false end
  if info.id ~= g.id and info.name ~= g.name then return false end
  if (info.to or 0) < (g.goal or 0) then return false end
  g.done = true
  D.Toast(Tr["Défi du jour réussi !"], "+" .. ((g.goal or 0) - (g.start or 0)) .. Tr[" en "] .. tostring(g.name), info.icon,
    { kind = "daily", variant = "gold" })
  D.Play("soundDaily")
  return true
end

function D.DiscoverSkin(ctype)
  if not ns.Opt("collection") then return false end
  if type(ctype) ~= "string" or ctype == "" then return false end
  local d = D.C()
  if d.skins[ctype] then return false end
  d.skins[ctype] = true
  d.skinN = (d.skinN or 0) + 1
  return true
end
function D.DiscoverFish(id, name)
  if not ns.Opt("collection") then return false end
  local key = id and tostring(id) or nil
  if not key or key == "" then key = name end
  if type(key) ~= "string" or key == "" then return false end
  local d = D.C()
  if d.fish[key] then return false end
  d.fish[key] = name or true
  d.fishN = (d.fishN or 0) + 1
  return true
end
function D.DiscoverCount(which)
  local d = D.C()
  if which == "fishing" then return d.fishN or 0 end
  if which == "skinning" then return d.skinN or 0 end
  return (d.skinN or 0) + (d.fishN or 0)
end

function D.BarFraction(now, lastAt, spu)
  now, lastAt, spu = tonumber(now), tonumber(lastAt), tonumber(spu)
  if not spu or spu <= 0 or not lastAt or not now then return nil end
  local f = (now - lastAt) / spu
  if f < 0 then f = 0 end
  if f > 1 then f = 1 end
  return f
end
-- 3.6.0 : la barre ne montre jamais une progression périmée.
--  * (a) chaque nouveau point remet la barre à 0 % TOUT DE SUITE (même si la
--    pompe tournait déjà : avant, elle gardait l'ancien 100 % jusqu'à l'image
--    suivante, et rien si la pompe était arrêtée) ;
--  * (b) en combat : pompe arrêtée ET barre cachée ; à la sortie, soit un point
--    reçu pendant le combat la réarme à 0 %, soit elle reste cachée si le
--    rythme est dépassé (plus de 100 % figé) ;
--  * au-delà de 1,5 × le rythme mesuré sans nouveau point, la barre se cache
--    et la pompe s'arrête (le rythme ne représente plus rien) ;
--  * pompe limitée à ~10 images/s, case mémorisée (plus de parcours de toutes
--    les cases à chaque image).
D.BAR_HZ = 0.1
D.BAR_STALE = 1.5
function D.HideBars(except)
  local tiles = ns.UI and ns.UI.embed and ns.UI.embed.tiles
  if not tiles then return end
  for _, t in ipairs(tiles) do
    if t ~= except and t._nextBar and t._nextBar.Hide then t._nextBar:Hide() end
  end
end
function D.StopBar()
  if D._pump and D._pump.SetScript then pcall(D._pump.SetScript, D._pump, "OnUpdate", nil) end
  D._pumping = false
end
local function TileMatches(t, b)
  local d = t and t.data
  return d and b and (d.id == b.id or d.name == b.name or d.skillName == b.name) and true or false
end
function D.BarTile()
  local b = D.bar
  if not b or not ns.UI or not ns.UI.embed then return nil end
  local c = D._barTile
  if c and TileMatches(c, b) then return c end
  D._barTile = nil
  for _, t in ipairs(ns.UI.embed.tiles or {}) do
    if TileMatches(t, b) then D._barTile = t return t end
  end
  return nil
end
function D.PaintBar(frac)
  local b = D.bar
  if not b or not ns.UI or not ns.UI.embed then return nil end
  local tile = D.BarTile()
  D.HideBars(tile)
  if not tile or type(tile.CreateTexture) ~= "function" and type(_G.CreateFrame) ~= "function" then return nil end
  if not tile._nextBar and type(_G.CreateFrame) == "function" then
    if InCombat() then return nil end   -- aucune création de cadre en combat
    local bar = CreateFrame("StatusBar", nil, tile)
    bar:SetHeight(2)
    bar:SetPoint("TOPLEFT", tile, "BOTTOMLEFT", 2, -1)
    bar:SetPoint("TOPRIGHT", tile, "BOTTOMRIGHT", -2, -1)
    if bar.SetMinMaxValues then bar:SetMinMaxValues(0, 1) end
    local bg = bar.CreateTexture and bar:CreateTexture(nil, "BACKGROUND")
    if bg then
      bg:SetAllPoints()
      if bg.SetColorTexture then bg:SetColorTexture(0, 0, 0, 0.55) end
    end
    if bar.SetStatusBarTexture then pcall(bar.SetStatusBarTexture, bar, "Interface\\TargetingFrame\\UI-StatusBar") end
    if bar.SetStatusBarColor then bar:SetStatusBarColor(0.65, 0.49, 0.27, 1) end
    tile._nextBar = bar
  end
  local bar = tile._nextBar
  if not bar then return nil end
  if bar.SetValue then bar:SetValue(frac or 0) end
  if bar.Show then bar:Show() end
  D.barValue = frac or 0
  return bar
end
-- Une image de la pompe (aussi appelée par les tests).
function D.PumpStep(fr, elapsed)
  if InCombat() or not ns.Opt("nextBar") or not D.bar then
    D.StopBar()
    D.HideBars()
    return false
  end
  D._acc = (D._acc or 0) + (elapsed or D.BAR_HZ)
  if D._acc < D.BAR_HZ then return true end
  D._acc = 0
  local spu = ns.Rate and ns.Rate.SecondsPerUnit and ns.Rate.SecondsPerUnit(D.bar.key)
  if not spu or spu <= 0 then
    D.StopBar()
    D.HideBars()
    return false
  end
  local raw = (Now() - (D.bar.at or 0)) / spu
  if raw > D.BAR_STALE then
    -- rythme dépassé : pas de 100 % figé, la barre attend le prochain point
    D.StopBar()
    D.HideBars()
    D.bar.stale = true
    return false
  end
  local e = ns.UI and ns.UI.embed
  if e and e.IsVisible and not e:IsVisible() then return true end   -- panneau caché : rien à peindre
  D.PaintBar(D.BarFraction(Now(), D.bar.at, spu))
  return true
end
function D.StartBar()
  if D._pumping then return end
  if InCombat() then return end
  if type(_G.CreateFrame) ~= "function" then return end
  if not D._pump then
    local ok, f = pcall(_G.CreateFrame, "Frame")
    if not ok then return end
    D._pump = f
    D._pumpFn = function(fr, el) D.PumpStep(fr, el) end   -- une seule fermeture
  end
  D._pumping = true
  D._acc = D.BAR_HZ   -- première image peinte aussitôt
  D._pump:SetScript("OnUpdate", D._pumpFn)
end
function D.ArmBar(info)
  if not ns.Opt("nextBar") then D.bar = nil D.StopBar() D.HideBars() return nil end
  local key = "skill:" .. tostring(info.id or info.fold or info.name)
  local spu = ns.Rate and ns.Rate.SecondsPerUnit and ns.Rate.SecondsPerUnit(key)
  D.bar = { id = info.id, name = info.name, at = Now(), key = key, spu = spu }
  D._barTile = nil
  if not spu then D.StopBar() D.HideBars() return nil end
  if InCombat() then D.StopBar() D.HideBars() return 0 end
  -- (a) remise à 0 % immédiate, que la pompe tourne déjà ou non
  D.PaintBar(0)
  D.StartBar()
  return D.BarFraction(Now(), D.bar.at, spu)
end
-- (b) sortie de combat : réarmée proprement ou cachée, jamais un 100 % périmé
function D.ResumeBar()
  if not (D.bar and D.bar.spu and ns.Opt("nextBar")) then D.HideBars() return false end
  local spu = ns.Rate and ns.Rate.SecondsPerUnit and ns.Rate.SecondsPerUnit(D.bar.key)
  local raw = spu and spu > 0 and (Now() - (D.bar.at or 0)) / spu or nil
  if not raw or raw >= 1 then
    D.HideBars()
    return false
  end
  D.PaintBar(D.BarFraction(Now(), D.bar.at, spu))
  D.StartBar()
  return true
end

function D.OnRise(info)
  if type(info) ~= "table" then return nil end
  if InCombat() then
    D._queue = D._queue or {}
    D._queue[#D._queue + 1] = info
    return nil
  end
  local fromR, toR = tonumber(info.from) or 0, tonumber(info.to) or 0
  local delta = tonumber(info.delta) or (toR - fromR)
  if delta <= 0 then return nil end
  D.NoteCombo(Now())
  local palier = D.CrossedPalier(info.kind, fromR, toR)
  D.Play("soundSkill")
  if palier then D.Play("soundPalier") end
  if D.ReachedMax(info.kind, fromR, toR, info.max) then
    D.Celebrate(info)
    D.Play("soundMax")
  end
  D.AddPoints(delta, Now())
  D.EnsureDaily(D.SkillList())
  D.DailyProgress(info)
  D.ArmBar(info)
  return true
end
function D.FlushQueue()
  local q = D._queue
  D._queue = nil
  for _, info in ipairs(q or {}) do D.OnRise(info) end
end
function D.SkillList()
  local out = {}
  local snap = ns.UI and ns.UI.snapshot
  for _, t in ipairs((snap and (snap.allTiles or snap.tiles)) or {}) do
    if t.id then out[#out + 1] = t end
  end
  return out
end

local SKIN_SPELLS = { [8613] = true, [8617] = true, [8618] = true, [10768] = true }
local function IsSkinSpell(spellID)
  local id = tonumber(spellID)
  if id and SKIN_SPELLS[id] then return true end
  local A = ns.Activity
  if id and A and A.SPELLS and A.SPELLS.skinning then
    for _, s in ipairs(A.SPELLS.skinning) do if s == id then return true end end
  end
  return false
end
local function Str(v)
  if type(v) ~= "string" or v == "" or (ns.IsSecret and ns.IsSecret(v)) then return nil end
  return v
end

if ns.On then
  ns.On("PLAYER_REGEN_ENABLED", function()
    local before = D.bar
    D.FlushQueue()
    -- un point reçu en combat vient d'être réarmé à 0 % par FlushQueue ;
    -- sinon : reprise seulement si le rythme n'est pas dépassé
    if D.bar == before then D.ResumeBar() end
  end)
  ns.On("PLAYER_REGEN_DISABLED", function() D.StopBar() D.HideBars() end)
  ns.On("PLAYER_ENTERING_WORLD", function(_, isLogin)
    if isLogin == true or ns.sessionFresh then D.C().records.session = 0 D.C().records.recStep = nil end
    D.EnsureDaily(D.SkillList())
  end)
  ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" or not IsSkinSpell(spellID) then return end
    local ctype = Str(type(_G.UnitCreatureType) == "function" and _G.UnitCreatureType("target"))
      or Str(type(_G.UnitCreatureType) == "function" and _G.UnitCreatureType("mouseover"))
    D.DiscoverSkin(ctype)
  end)
  ns.On("LOOT_OPENED", function()
    if type(_G.IsFishingLoot) ~= "function" then return end
    local ok, fish = pcall(_G.IsFishingLoot)
    if not ok or not fish then return end
    local n = 0
    if type(_G.GetNumLootItems) == "function" then
      local okN, v = pcall(_G.GetNumLootItems)
      if okN and tonumber(v) then n = tonumber(v) end
    end
    for slot = 1, n do
      local link = type(_G.GetLootSlotLink) == "function" and _G.GetLootSlotLink(slot) or nil
      local id = type(link) == "string" and link:match("item:(%d+)") or nil
      local name = type(_G.GetLootSlotInfo) == "function" and _G.GetLootSlotInfo(slot) or nil
      D.DiscoverFish(id, type(name) == "string" and name or nil)
    end
  end)
end

if ns.Compact and ns.Compact.TooltipModel then
  local base = ns.Compact.TooltipModel
  function ns.Compact.TooltipModel(d)
    local m = base(d)
    if type(d) ~= "table" or type(m) ~= "table" or type(m.lines) ~= "table" then return m end
    local function add(text)
      if text and text ~= "" then m.lines[#m.lines + 1] = { text, 1, 0.86, 0.46, true } end
    end
    add(D.DailyLine(d.id, d.name or d.skillName, tonumber(d.current)))
    if ns.Opt("collection") and (d.id == "skinning" or d.id == "fishing") then
      add(tostring(D.DiscoverCount(d.id)) .. Tr[" découverts"])
    end
    if ns.Opt("combo") and D.bar and (D.bar.id == d.id or D.bar.name == d.name) then
      local n = D.LiveCombo()
      if n >= 2 then
        local best = D.C().bestCombo
        add(Tr["Combo x"] .. n .. (best and (Tr[" · record x"] .. best) or ""))
      end
    end
    return m
  end
end

if ns.DebugExt then
  ns.DebugExt[#ns.DebugExt + 1] = function()
    local d = D.C()
    local g = d.daily
    return {
      "— Dopamine (3.5.0) —",
      "  combo x" .. tostring(D.LiveCombo()) .. " (record x" .. tostring(d.bestCombo or 0) .. ")",
      "  défi : " .. (g and (tostring(g.name) .. " " .. tostring(g.start) .. "→" .. tostring(g.goal) .. (g.done and " réussi" or "")) or "aucun"),
      "  records : session " .. tostring(d.records.session or 0) .. " (meilleure " .. tostring(d.records.bestSession or 0) .. "), heure " .. tostring(d.records.hourPts or 0),
      "  collection : " .. tostring(d.skinN or 0) .. " types dépecés, " .. tostring(d.fishN or 0) .. " poissons",
    }
  end
end

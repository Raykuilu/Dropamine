-- Dropamine 3.6.0 — moteur de progression (Phase 1 : données et API).
-- La fenêtre « Progression » (Phase 2) se construit directement sur ns.Progress :
-- session en direct (durée, XP/h, niveaux/h, points/h, combo, gains par
-- compétence, courbe échantillonnée), records, historique 30 jours par
-- catégorie, objectif de session, série de jours, récap du lundi, succès,
-- meilleurs coins de récolte par zone, tri intelligent (option), teinte
-- saisonnière (option, Style.lua), texte de partage (/drop share).
-- Comfort : mode calme en instance / en groupe (toasts réduits, sons coupés).
--
-- Règles : presque rien ne tourne au repos (un seul petit cadre caché qui
-- additionne le temps, le vrai travail toutes les 2 min), aucun cadre créé en
-- combat, rien de protégé touché ;
-- en combat on n'enregistre que des nombres (les toasts attendent la fin du
-- combat). Tout est borné : courbe ≤ 90 points, fenêtre horaire glissante,
-- 35 jours d'historique, 40 zones par métier de récolte.
-- Nom réservé : ns.ShowStats (Core.lua) = « caractéristiques dans la grille » ;
-- rien ici ne porte ce nom.
local ADDON, ns = ...
local Tr = ns.L
local P = {}
ns.Progress = P
P.VERSION = 1

P.SAMPLE_SECS = 120        -- échantillon de la courbe toutes les 2 min
P.SAMPLE_MIN_GAP = 30      -- ou à un gain, si le dernier date d'au moins 30 s
P.CURVE_MAX = 90           -- au-delà : un point sur deux est gardé (forme conservée)
P.HOUR = 3600
P.RUN_GAP = 300            -- pause de plus de 5 min : la série de temps actif repart de zéro
P.IDLE_GAP = 600           -- plus de 10 min sans rien : pas compté dans le temps actif
P.MIN_RATE_SECS = 120      -- pas de rythme affiché avant 2 min
P.ZONES_MAX = 40
P.GOAL_DEFAULT, P.GOAL_MIN, P.GOAL_MAX = 20, 1, 500
P.ICON = "Interface\\AddOns\\Dropamine\\Media\\Dropamine-Icon"
P.GATHER = { herbalism = true, mining = true, skinning = true, fishing = true }
P.CRAFT = { alchemy = true, blacksmithing = true, enchanting = true, engineering = true, leatherworking = true,
  tailoring = true, cooking = true, firstaid = true }

local function N(v) return (ns.N and ns.N(v)) or tonumber(v) end
local function Wall() return (type(_G.time) == "function" and _G.time()) or 0 end
local function InCombat() return ns.InCombat and ns.InCombat() or false end
local function Ret(ok, ...) if not ok then return nil end return ... end
local function Call(fn, ...) if type(fn) ~= "function" then return nil end return Ret(pcall(fn, ...)) end
local function Str(v) if type(v) ~= "string" or (ns.IsSecret and ns.IsSecret(v)) or v == "" then return nil end return v end
local function Say(m) if ns.Print then ns.Print(m) end end
local function After(sec, fn)
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then _G.C_Timer.After(sec, fn) return true end
  return false
end

------------------------------------------------------------------------------
-- Dates (calendrier pur Lua : pas de dépendance à time(table) ni à l'heure d'été)
------------------------------------------------------------------------------
local function DaysFromCivil(y, m, d)
  y = (m <= 2) and (y - 1) or y
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = math.floor((153 * mp + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end
local function CivilFromDays(z)
  z = z + 719468
  local era = math.floor(z / 146097)
  local doe = z - era * 146097
  local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local d = doy - math.floor((153 * mp + 2) / 5) + 1
  local m = (mp < 10) and (mp + 3) or (mp - 9)
  if m <= 2 then y = y + 1 end
  return y, m, d
end
function P.ParseDay(key)
  local y, m, d = tostring(key or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not y then return nil end
  return DaysFromCivil(tonumber(y), tonumber(m), tonumber(d))
end
function P.FormatDay(z)
  local y, m, d = CivilFromDays(z)
  return string.format("%04d-%02d-%02d", y, m, d)
end
function P.Today()
  local k = ns.TodayKey and ns.TodayKey() or "?"
  if P.ParseDay(k) then return k end
  return P.FormatDay(math.floor(Wall() / 86400))
end
function P.DayOffset(key, n)
  local z = P.ParseDay(key)
  if not z then return nil end
  return P.FormatDay(z + (n or 0))
end
-- 1 = lundi … 7 = dimanche (1970-01-01 était un jeudi)
function P.Weekday(key)
  local z = P.ParseDay(key or P.Today())
  if not z then return nil end
  return ((z + 3) % 7) + 1
end
function P.WeekStart(key)
  key = key or P.Today()
  local wd = P.Weekday(key)
  if not wd then return nil end
  return P.DayOffset(key, -(wd - 1))
end

------------------------------------------------------------------------------
-- Données (par personnage : DropamineDB.chars[clé].progress)
------------------------------------------------------------------------------
local function NewCats() return { level = 0, combat = 0, prof = 0 } end
function P.C()
  local c = ns.CharDB()
  local p = c.progress
  if type(p) ~= "table" then p = {} c.progress = p end
  p.v = p.v or P.VERSION
  p.records = p.records or {}
  p.streak = p.streak or { n = 0, best = 0 }
  p.ach = p.ach or {}
  p.spots = p.spots or {}
  p.weekly = p.weekly or {}
  p.session = p.session or {}
  c.history = c.history or {}
  return p, c
end
function P.Category(kind)
  if kind == "level" then return "level" end
  if kind == "profession" or kind == "secondary" then return "prof" end
  if kind == "melee" or kind == "ranged" or kind == "feral" or kind == "defense" or kind == "class" then return "combat" end
  return nil
end

-- Session : même borne que « gains de session » (Core : c.session.started,
-- posée à la connexion, pas au /reload).
function P.NewSession(start)
  local cur, mx = nil, nil
  if ns.GetPlayerXPSafe then cur, mx = ns.GetPlayerXPSafe() end
  return { start = start or Wall(), pts = 0, cat = NewCats(), skills = {}, xp = 0, levels = 0,
    combo = 0, bestCombo = 0, curve = {}, hour = {}, active = 0, goalsHit = 0,
    xpPrev = N(cur), xpPrevMax = N(mx), xpPrevLevel = N(ns.GetPlayerLevel and ns.GetPlayerLevel()) }
end
function P.Session()
  local p, c = P.C()
  local s = p.session
  local started = N(c.session and c.session.started)
  if not s.start or (started and s.start ~= started) then
    P.CloseSession(s)
    s = P.NewSession(started)
    p.session = s
  end
  s.cat = s.cat or NewCats()
  s.skills = s.skills or {}
  s.curve = s.curve or {}
  s.hour = s.hour or {}
  return s, p, c
end
-- Temps de jeu suivi : ajouté par tranches (minuterie, déconnexion), jamais deux fois.
function P.AccountTime(now)
  local s, p = P.Session()
  now = now or Wall()
  local last = N(s.tracked) or N(s.start) or now
  local dt = now - last
  if dt > 0 then
    if dt > P.IDLE_GAP then dt = P.IDLE_GAP end
    p.records.playtime = (N(p.records.playtime) or 0) + dt
  end
  s.tracked = now
end
function P.CloseSession(s)
  if type(s) ~= "table" or not s.start then return end
  local p = P.C()
  local last = N(s.lastAct) or N(s.tracked)
  if last and N(s.tracked) and last > s.tracked then
    p.records.playtime = (N(p.records.playtime) or 0) + math.min(P.IDLE_GAP, last - s.tracked)
  end
  p.records.sessions = (N(p.records.sessions) or 0) + 1
end
-- Série de jeu actif : tout signe d'activité (gain, combat, déplacement, incantation, butin) la prolonge ;
-- une pause de plus de RUN_GAP la remet à zéro. Indépendante de la vitesse des gains.
function P.TouchRun(now)
  local s = P.Session()
  now = now or Wall()
  local last = N(s.runLast)
  if not last or now < last or now - last > P.RUN_GAP then s.runStart = now end
  s.runLast = now
  local len = now - (N(s.runStart) or now)
  s.run = len
  local p = P.C()
  if len > (N(p.records.longestRun) or 0) then p.records.longestRun = len end
  if (len >= 1800 and not p.ach.run30) or (len >= 3600 and not p.ach.run60) then P.CheckAchievements("run") end
end
-- Présence (toutes les 10 s) : combat, déplacement ou incantation, et pas en AFK.
function P.Presence()
  local function Plain(v) return not (ns.IsSecret and ns.IsSecret(v)) end
  local function Q(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and Plain(v) then return v end
    return nil
  end
  if Q(_G.UnitIsAFK, "player") then return end
  local busy = Q(_G.UnitAffectingCombat, "player") and true or false
  if not busy then
    local sp = Q(_G.GetUnitSpeed, "player")
    busy = type(sp) == "number" and sp > 0
  end
  if not busy then busy = Q(_G.UnitCastingInfo, "player") ~= nil or Q(_G.UnitChannelInfo, "player") ~= nil end
  if busy then P.TouchRun(Wall()) end
end
local function Activity(s, now)
  local la = N(s.lastAct)
  if la and now > la and now - la <= P.IDLE_GAP then s.active = (N(s.active) or 0) + (now - la) end
  s.lastAct = now
  P.TouchRun(now)
end

------------------------------------------------------------------------------
-- Rythmes, courbe
------------------------------------------------------------------------------
function P.Rates(now)
  local s = P.Session()
  now = now or Wall()
  local elapsed = math.max(0, now - (N(s.start) or now))
  local active = N(s.active) or 0
  -- base de calcul : temps actif dès 5 min mesurées, sinon le temps écoulé
  local base = (active >= 300) and active or elapsed
  local out = { elapsed = elapsed, active = active, base = base, pts = s.pts or 0, xp = s.xp or 0, levels = s.levels or 0 }
  if base >= P.MIN_RATE_SECS then
    local h = base / P.HOUR
    out.xph = (s.xp or 0) / h
    out.pph = (s.pts or 0) / h
    -- lph réel (niveaux gagnés / h) : souvent 0 dans une session ; on le garde à part
    out.levelsPerHour = (s.levels or 0) / h
  end
  local cur, mx
  if ns.GetPlayerXPSafe then cur, mx = ns.GetPlayerXPSafe() end
  cur, mx = N(cur), N(mx)
  out.xpCur, out.xpMax = cur, mx
  -- niv./h comparable : XP/h divisée par le besoin du niveau courant (UnitXPMax)
  if out.xph and mx and mx > 0 then
    out.lph = out.xph / mx
    out.pctLevelPerHour = out.lph * 100
  end
  if out.xph and out.xph > 0 and cur and mx and mx > cur then
    out.etaLevel = (mx - cur) / out.xph * P.HOUR
  end
  return out
end
local function Round(v) v = N(v) if not v then return nil end return math.floor(v + 0.5) end
function P.Sample(now, force)
  local s = P.Session()
  now = now or Wall()
  local last = N(s.lastSample)
  if not force and last and now - last < P.SAMPLE_SECS then return false end
  local r = P.Rates(now)
  local curve = s.curve
  local sc = s.cat or {}
  curve[#curve + 1] = { t = math.max(0, now - (N(s.start) or now)), xph = Round(r.xph) or 0, pph = Round(r.pph) or 0, total = s.pts or 0,
    lv = N(sc.level) or 0, cb = N(sc.combat) or 0, pf = N(sc.prof) or 0, xp = s.xp or 0 }
  s.lastSample = now
  if #curve > P.CURVE_MAX then
    local keep = {}
    for i = 1, #curve do if i % 2 == 1 or i == #curve then keep[#keep + 1] = curve[i] end end
    s.curve = keep
  end
  return true
end
function P.Curve() return P.Session().curve end

------------------------------------------------------------------------------
-- Gains
------------------------------------------------------------------------------
local function HourSum(s, now)
  local list, sum, expired = s.hour, 0, false
  for i = 1, #list do
    local e = list[i]
    if now - (N(e.t) or 0) < P.HOUR then sum = sum + (N(e.n) or 0) else expired = true end
  end
  if expired then   -- nouvelle table seulement s'il y a des entrées à jeter
    local keep, j = {}, 0
    for i = 1, #list do
      local e = list[i]
      if now - (N(e.t) or 0) < P.HOUR then j = j + 1 keep[j] = e end
    end
    s.hour = keep
  end
  return sum
end
function P.HourPoints(now) local s = P.Session() return HourSum(s, now or Wall()) end

-- 3.6.0 phase 2 : abonnés (fenêtre Progression, infobulle) prévenus d'un
-- changement ; ils regroupent eux-mêmes leurs rafraîchissements.
P.listeners = P.listeners or {}
function P.Listen(key, fn) if type(fn) == "function" then P.listeners[key] = fn end end
function P.Notify(why)
  for _, fn in pairs(P.listeners) do pcall(fn, why) end
end
function P.DayEntry(day)
  local _, c = P.C()
  day = day or P.Today()
  local h = c.history[day]
  if type(h) ~= "table" then h = {} c.history[day] = h end
  h.cat = h.cat or NewCats()
  h.skills = h.skills or {}
  h.pts = h.pts or 0
  return h
end

-- Un gain : catégorie (level / combat / prof), clé de compétence, nom, delta.
function P.Gain(cat, key, name, delta, counts, now)
  delta = N(delta)
  if not delta or delta <= 0 then return nil end
  now = now or Wall()
  local s, p = P.Session()
  Activity(s, now)
  -- heure locale du gain (succès Lève-tôt / Noctambule)
  if type(_G.date) == "function" and not (p.records.early and p.records.night) then
    local okD, hr = pcall(function() return _G.date("*t", now).hour end)
    hr = okD and N(hr) or nil
    if hr then
      local newly = false
      if hr < 7 and hr >= 5 and not p.records.early then p.records.early = now newly = true end
      if hr < 5 and not p.records.night then p.records.night = now newly = true end
      if newly then P.CheckAchievements("hour") end
    end
  end
  key = tostring(key or name or "?")
  local sk = s.skills[key]
  if not sk then sk = { name = name, n = 0 } s.skills[key] = sk end
  sk.n, sk.t, sk.name = sk.n + delta, now, name or sk.name
  local day = P.Today()
  local h = P.DayEntry(day)
  h.skills[key] = (N(h.skills[key]) or 0) + delta
  if counts == false or not cat then return s end
  s.pts = (s.pts or 0) + delta
  s.cat[cat] = (N(s.cat[cat]) or 0) + delta
  h.pts = (N(h.pts) or 0) + delta
  h.cat[cat] = (N(h.cat[cat]) or 0) + delta
  -- fenêtre horaire glissante (meilleure heure réelle, pas l'heure d'horloge)
  local hl = s.hour
  hl[#hl + 1] = { t = now, n = delta }
  local hourPts = HourSum(s, now)
  local R = p.records
  if hourPts > (N(R.bestHour) or 0) then R.bestHour, R.bestHourAt = hourPts, now end
  if s.pts > (N(R.bestSession) or 0) then R.bestSession, R.bestSessionAt = s.pts, now end
  if h.pts > (N(R.bestDay) or 0) then R.bestDay, R.bestDayKey = h.pts, day end
  P.TouchStreak(day)
  P.CheckGoal(s)
  local last = N(s.lastSample)
  if not last or now - last >= P.SAMPLE_MIN_GAP then P.Sample(now, true) end
  P.CheckAchievements("gain")
  P.Notify("gain")
  return s
end

-- Appelé par UI:FlushSkillDiff pour chaque compétence qui monte (aussi en combat).
function P.OnRise(info)
  if type(info) ~= "table" then return nil end
  local fromR, toR = N(info.from) or 0, N(info.to) or 0
  local delta = N(info.delta) or (toR - fromR)
  if not delta or delta <= 0 then return nil end
  local key = info.id or info.fold or info.name
  local now = Wall()
  local s = P.Gain(P.Category(info.kind), key, info.name, delta, info.counts ~= false and P.Category(info.kind) ~= nil, now)
  if info.id and P.GATHER[info.id] then P.NoteGather(info.id, delta, now) end
  return s
end
function P.OnLevelUp(newLevel)
  local s = P.Session()
  s.levels = (s.levels or 0) + 1
  return P.Gain("level", "level", Tr["Niveau"], 1, true)
end
-- XP de la session (persistante au /reload ; valeurs secrètes ignorées).
function P.OnXP()
  local s = P.Session()
  local cur, mx
  if ns.GetPlayerXPSafe then cur, mx = ns.GetPlayerXPSafe() end
  cur, mx = N(cur), N(mx)
  if not cur or not mx then return nil end
  local lvl = N(ns.GetPlayerLevel and ns.GetPlayerLevel())
  local prev, pmax, plvl = N(s.xpPrev), N(s.xpPrevMax), N(s.xpPrevLevel)
  s.xpPrev, s.xpPrevMax, s.xpPrevLevel = cur, mx, lvl
  if not prev then return 0 end
  local d = cur - prev
  if d < 0 or (lvl and plvl and lvl > plvl) then
    d = ((pmax or 0) - prev) + cur
  end
  if d <= 0 then return 0 end
  s.xp = (s.xp or 0) + d
  local h = P.DayEntry()
  h.xp = (N(h.xp) or 0) + d
  -- fraction de niveau mesurée (delta / UnitXPMax au moment du gain), comparable entre niveaux
  local frac
  if lvl and plvl and lvl > plvl and pmax and pmax > 0 then
    frac = ((pmax - prev) / pmax) + ((mx and mx > 0) and (cur / mx) or 0)
  elseif mx and mx > 0 then
    frac = d / mx
  end
  if frac and frac > 0 then
    s.xpFrac = (N(s.xpFrac) or 0) + frac
    h.xpFrac = (N(h.xpFrac) or 0) + frac
    if ns.Efficiency and ns.Efficiency.NoteXpFrac then pcall(ns.Efficiency.NoteXpFrac, frac) end
  end
  Activity(s, Wall())
  P.Notify("xp")
  return d
end
-- Combo (Dopamine.lua) : record de session et record absolu.
function P.NoteCombo(n)
  n = N(n)
  if not n then return end
  local s, p = P.Session()
  s.combo = n
  if n > (N(s.bestCombo) or 0) then s.bestCombo = n end
  if n > (N(p.records.longestCombo) or 0) then p.records.longestCombo = n end
  if n >= 10 then P.CheckAchievements("combo") end
end
function P.TopSkills(n)
  local s = P.Session()
  local out = {}
  for key, v in pairs(s.skills) do out[#out + 1] = { key = key, name = v.name or key, n = v.n or 0, t = v.t } end
  table.sort(out, function(a, b) if a.n ~= b.n then return a.n > b.n end return tostring(a.name) < tostring(b.name) end)
  if n and #out > n then for i = #out, n + 1, -1 do out[i] = nil end end
  return out
end

------------------------------------------------------------------------------
-- Objectif de session (réglage du compte : DropamineDB.ui.sessionGoal)
------------------------------------------------------------------------------
function P.GoalTarget()
  local v = N(ns.db and ns.db.ui and ns.db.ui.sessionGoal) or P.GOAL_DEFAULT
  v = math.floor(v + 0.5)
  if v < P.GOAL_MIN then v = P.GOAL_MIN elseif v > P.GOAL_MAX then v = P.GOAL_MAX end
  return v
end
function P.Goal()
  local s = P.Session()
  local target = P.GoalTarget()
  local pts = s.pts or 0
  return { target = target, pts = pts, pct = math.min(1, pts / target), reached = pts >= target, hitAt = s.goalHit }
end
-- Changer l'objectif ne déclenche jamais de toast (pas de rafale en glissant le
-- curseur) : déjà dépassé = marqué atteint en silence.
function P.SetGoal(n)
  n = N(n)
  if not n then return P.GoalTarget() end
  n = math.floor(n + 0.5)
  if n < P.GOAL_MIN then n = P.GOAL_MIN elseif n > P.GOAL_MAX then n = P.GOAL_MAX end
  if ns.SetOpt then ns.SetOpt("sessionGoal", n) else ns.EnsureDB().ui.sessionGoal = n end
  local s = P.Session()
  if (s.pts or 0) >= n then s.goalHit = n end
  return n
end
function P.BumpGoal(delta) return P.SetGoal(P.GoalTarget() + (N(delta) or 0)) end
function P.CheckGoal(s)
  s = s or P.Session()
  local target = P.GoalTarget()
  if (s.pts or 0) < target or s.goalHit == target then return false end
  s.goalHit = target
  s.goalsHit = (s.goalsHit or 0) + 1
  local p = P.C()
  p.records.goalsHit = (N(p.records.goalsHit) or 0) + 1
  if ns.Opt("goalToast") then
    P.Toast(Tr["Objectif de session atteint !"], tostring(s.pts) .. " / " .. tostring(target), { kind = "goal", variant = "gold" }, "prog-goal")
  end
  return true
end

------------------------------------------------------------------------------
-- Série de jours (au moins un point par jour)
------------------------------------------------------------------------------
function P.TouchStreak(day)
  local st = P.C().streak
  day = day or P.Today()
  if st.last == day then return st.n end
  if st.last and P.DayOffset(st.last, 1) == day then st.n = (N(st.n) or 0) + 1 else st.n = 1 end
  st.last = day
  if st.n > (N(st.best) or 0) then st.best = st.n end
  if st.n >= 5 then P.CheckAchievements("streak") end
  return st.n
end
-- Série en cours : vivante si le dernier jour actif est aujourd'hui ou hier.
function P.Streak()
  local st = P.C().streak
  local today = P.Today()
  local alive = st.last == today or (st.last and P.DayOffset(st.last, 1) == today)
  return { n = alive and (N(st.n) or 0) or 0, best = N(st.best) or 0, last = st.last, today = st.last == today }
end
-- Points d'une journée : h.pts (3.6.0) ou écart de total avec la veille.
function P.DayPoints(day)
  local _, c = P.C()
  local h = c.history[day]
  if type(h) ~= "table" then return 0 end
  if N(h.pts) then return N(h.pts) end
  local prev = c.history[P.DayOffset(day, -1) or ""]
  local a, b = N(h.total), prev and N(prev.total)
  if a and b and a > b then return a - b end
  return 0
end
-- Une fois : série reconstruite depuis l'historique existant (rien n'est inventé).
function P.SeedStreak()
  local p = P.C()
  if p.streakSeeded then return false end
  p.streakSeeded = true
  local st = p.streak
  if st.last then return false end
  local today = P.Today()
  local day = (P.DayPoints(today) > 0) and today or P.DayOffset(today, -1)
  local n, last = 0, nil
  for _ = 1, 40 do
    if not day or P.DayPoints(day) <= 0 then break end
    n = n + 1
    last = last or day
    day = P.DayOffset(day, -1)
  end
  if n > 0 then st.n, st.last = n, last if n > (N(st.best) or 0) then st.best = n end end
  return n > 0
end

------------------------------------------------------------------------------
-- Historique 30 jours (catégories, compétences)
------------------------------------------------------------------------------
function P.History(days)
  days = N(days) or 30
  local _, c = P.C()
  local today = P.Today()
  local out = {}
  for i = days - 1, 0, -1 do
    local day = P.DayOffset(today, -i)
    local h = day and c.history[day]
    local cat = type(h) == "table" and h.cat or nil
    out[#out + 1] = { day = day, pts = P.DayPoints(day), total = h and N(h.total) or nil,
      level = cat and N(cat.level) or 0, combat = cat and N(cat.combat) or 0, prof = cat and N(cat.prof) or 0,
      xp = type(h) == "table" and N(h.xp) or 0 }
  end
  return out
end
function P.DayBreakdown(day)
  local _, c = P.C()
  day = day or P.Today()
  local h = c.history[day]
  local out = { day = day, pts = P.DayPoints(day), cat = NewCats(), skills = {} }
  if type(h) ~= "table" then return out end
  for k, v in pairs(h.cat or {}) do out.cat[k] = N(v) or 0 end
  for k, v in pairs(h.skills or {}) do out.skills[#out.skills + 1] = { key = k, n = N(v) or 0 } end
  table.sort(out.skills, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.key < b.key end)
  return out
end

------------------------------------------------------------------------------
-- Récap hebdomadaire (lundi → dimanche)
------------------------------------------------------------------------------
-- offset 0 = semaine en cours, 1 = semaine passée…
function P.WeeklyRecap(offset)
  offset = N(offset) or 1
  local _, c = P.C()
  local monday = P.DayOffset(P.WeekStart(P.Today()), -7 * offset)
  local r = { from = monday, to = P.DayOffset(monday, 6), pts = 0, cat = NewCats(), activeDays = 0, days = {}, skills = {} }
  local sk = {}
  local firstTotal, lastTotal
  for i = 0, 6 do
    local day = P.DayOffset(monday, i)
    local h = c.history[day]
    local pts = P.DayPoints(day)
    r.days[#r.days + 1] = { day = day, pts = pts }
    r.pts = r.pts + pts
    if pts > 0 then r.activeDays = r.activeDays + 1 end
    if not r.best or pts > r.best.pts then r.best = { day = day, pts = pts } end
    if type(h) == "table" then
      for k, v in pairs(h.cat or {}) do r.cat[k] = (r.cat[k] or 0) + (N(v) or 0) end
      for k, v in pairs(h.skills or {}) do sk[k] = (sk[k] or 0) + (N(v) or 0) end
      if N(h.total) then firstTotal = firstTotal or N(h.total) lastTotal = N(h.total) end
    end
  end
  for k, v in pairs(sk) do r.skills[#r.skills + 1] = { key = k, n = v } end
  table.sort(r.skills, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.key < b.key end)
  r.totalFrom, r.totalTo = firstTotal, lastTotal
  if r.best and r.best.pts <= 0 then r.best = nil end
  return r
end
local function SkillLabel(key)
  if key == "level" then return Tr["Niveau"] end
  if ns.SkillDisplayName and ns.CatalogById and ns.CatalogById(key) then return ns.SkillDisplayName(key) end
  return tostring(key)
end
P.SkillLabel = SkillLabel
function P.WeeklyLine(r)
  r = r or P.WeeklyRecap(1)
  local parts = { string.format(Tr["%d points en %d jour(s)"], r.pts, r.activeDays) }
  if r.best then parts[#parts + 1] = Tr["meilleur jour "] .. tostring(r.best.day) .. " (+" .. r.best.pts .. ")" end
  local top = {}
  for i = 1, math.min(3, #r.skills) do top[#top + 1] = SkillLabel(r.skills[i].key) .. " +" .. r.skills[i].n end
  if #top > 0 then parts[#parts + 1] = table.concat(top, ", ") end
  return Tr["Semaine du "] .. tostring(r.from) .. Tr[" : "] .. table.concat(parts, " · ")
end
-- Une seule fois par semaine, le lundi (ou mardi / mercredi si manqué), hors combat.
function P.CheckWeekly(force)
  local p = P.C()
  local today = P.Today()
  local wd = P.Weekday(today)
  local week = P.WeekStart(today)
  if not force then
    if not ns.Opt("weeklyRecap") then return nil end
    if not wd or wd > 3 or p.weekly.shown == week then return nil end
  end
  p.weekly.shown = week
  local r = P.WeeklyRecap(1)
  if r.activeDays <= 0 and not force then return nil end
  local line = P.WeeklyLine(r)
  Say(line)
  P.Toast(Tr["Récap de la semaine"], string.format(Tr["%d points en %d jour(s)"], r.pts, r.activeDays), { kind = "weekly", variant = "gold", hint = r.best and (Tr["meilleur jour "] .. r.best.day) or nil }, "prog-weekly")
  return r
end

------------------------------------------------------------------------------
-- Coins de récolte (Herboristerie, Minage, Dépeçage, Pêche) par zone
------------------------------------------------------------------------------
function P.Zone()
  local z = Str(Call(_G.GetRealZoneText)) or Str(Call(_G.GetZoneText)) or "?"
  local sub = Str(Call(_G.GetSubZoneText))
  return z, sub
end
function P.NoteGather(skill, delta, now)
  local p = P.C()
  now = now or Wall()
  local zone, sub = P.Zone()
  local bySkill = p.spots[skill]
  if not bySkill then bySkill = {} p.spots[skill] = bySkill end
  local z = bySkill[zone]
  if not z then z = { pts = 0, secs = 0, n = 0, subs = {} } bySkill[zone] = z end
  local last = N(z.last)
  if last and now > last and now - last <= P.IDLE_GAP then
    z.secs = (N(z.secs) or 0) + (now - last)
    z.n = (N(z.n) or 0) + delta
    -- 3.13.0 : 10 derniers rythmes (minutes par point) : un coin qui ralentit = nœuds qui verdissent
    z.rec = type(z.rec) == "table" and z.rec or {}
    z.rec[#z.rec + 1] = ((now - last) / delta) / 60
    if #z.rec > 10 then table.remove(z.rec, 1) end
  end
  do   -- 3.13.0 : points de récolte de la session, par zone (onglet Farm, vue Maintenant)
    local s = P.Session()
    if s then s.zoneGather = s.zoneGather or {} s.zoneGather[zone] = (N(s.zoneGather[zone]) or 0) + delta end
  end
  z.pts = (N(z.pts) or 0) + delta
  z.last = now
  if sub and sub ~= zone then
    z.subs[sub] = (N(z.subs[sub]) or 0) + delta
    local cnt, low, lowK = 0, nil, nil
    for k, v in pairs(z.subs) do cnt = cnt + 1 if not low or v < low then low, lowK = v, k end end
    if cnt > 8 and lowK then z.subs[lowK] = nil end
  end
  -- borne : 40 zones par métier (les moins productives partent)
  local cnt, low, lowK = 0, nil, nil
  for k, v in pairs(bySkill) do cnt = cnt + 1 if k ~= zone and (not low or (v.pts or 0) < low) then low, lowK = v.pts or 0, k end end
  if cnt > P.ZONES_MAX and lowK then bySkill[lowK] = nil end
  P.CheckAchievements("spot")
  return z
end
-- Meilleurs coins : sortBy "pts" (défaut) ou "rate" (minutes par point, ≥ 3 mesures).
function P.Spots(skill, limit, sortBy)
  local p = P.C()
  local out = {}
  for zone, z in pairs(p.spots[skill] or {}) do
    local n = N(z.n) or 0
    local avg = (n >= 1 and (N(z.secs) or 0) > 0) and ((z.secs / n) / 60) or nil
    local topSub, topN = nil, 0
    for k, v in pairs(z.subs or {}) do if v > topN then topSub, topN = k, v end end
    -- 3.13.0 : tendance = rythme des 10 derniers points face au rythme habituel du coin
    local recent, trend
    if type(z.rec) == "table" and #z.rec >= 5 then
      local sum = 0 for _, v in ipairs(z.rec) do sum = sum + (N(v) or 0) end
      recent = sum / #z.rec
      if avg and avg > 0 then
        local k = recent / avg
        trend = (k >= 1.3) and "slower" or (k <= 0.77) and "faster" or "steady"
      end
    end
    out[#out + 1] = { zone = zone, pts = N(z.pts) or 0, minutes = (N(z.secs) or 0) / 60, avg = avg, sub = topSub, last = z.last, recent = recent, trend = trend }
  end
  if sortBy == "rate" then
    table.sort(out, function(a, b)
      local ra = (a.avg and a.pts >= 3) and a.avg or math.huge
      local rb = (b.avg and b.pts >= 3) and b.avg or math.huge
      if ra ~= rb then return ra < rb end
      return a.pts > b.pts
    end)
  else
    table.sort(out, function(a, b) if a.pts ~= b.pts then return a.pts > b.pts end return tostring(a.zone) < tostring(b.zone) end)
  end
  if limit and #out > limit then for i = #out, limit + 1, -1 do out[i] = nil end end
  return out
end
function P.SpotZoneCount()
  local zones = {}
  local n = 0
  for _, bySkill in pairs(P.C().spots) do
    for zone in pairs(bySkill) do if not zones[zone] then zones[zone] = true n = n + 1 end end
  end
  return n
end

------------------------------------------------------------------------------
-- Succès Dropamine (par personnage). Les seuils déjà atteints au premier
-- chargement sont enregistrés EN SILENCE ; seuls les nouveaux font un toast.
------------------------------------------------------------------------------
local function RankOf(ctx, id) return ctx.ranks[id] or 0 end
local function CountAtLeast(ctx, set, v)
  local n = 0
  for id in pairs(set) do if RankOf(ctx, id) >= v then n = n + 1 end end
  return n
end
P.ACHIEVEMENTS = {
  { id = "goal1", of = "goalsHit", need = 1, name = "Premier objectif", desc = "Atteindre un objectif de session.", test = function(x) return x.goalsHit >= 1 end },
  { id = "sess25", of = "bestSession", need = 25, name = "Belle séance", desc = "25 points en une session.", test = function(x) return x.bestSession >= 25 end },
  { id = "sess50", of = "bestSession", need = 50, name = "Grosse séance", desc = "50 points en une session.", test = function(x) return x.bestSession >= 50 end },
  { id = "sess100", of = "bestSession", need = 100, name = "Marathon", desc = "100 points en une session.", test = function(x) return x.bestSession >= 100 end },
  { id = "hour10", of = "bestHour", need = 10, name = "Heure dorée", desc = "10 points en une heure.", test = function(x) return x.bestHour >= 10 end },
  { id = "combo10", of = "combo", need = 10, name = "Combo x10", desc = "10 points d'affilée, sans pause d'une minute.", test = function(x) return x.combo >= 10 end },
  { id = "streak5", of = "streak", need = 5, name = "Série de 5 jours", desc = "5 jours de suite avec au moins un point.", test = function(x) return x.streak >= 5 end },
  { id = "streak14", of = "streak", need = 14, name = "Série de 14 jours", desc = "14 jours de suite avec au moins un point.", test = function(x) return x.streak >= 14 end },
  { id = "streak30", of = "streak", need = 30, name = "Série de 30 jours", desc = "30 jours de suite avec au moins un point.", test = function(x) return x.streak >= 30 end },
  { id = "streak60", of = "streak", need = 60, name = "Série de 60 jours", desc = "60 jours de suite avec au moins un point.", test = function(x) return x.streak >= 60 end },
  { id = "active10", of = "active30", need = 10, name = "Habitué", desc = "10 jours actifs sur les 30 derniers.", test = function(x) return x.active30 >= 10 end },
  { id = "active20", of = "active30", need = 20, name = "Assidu", desc = "20 jours actifs sur les 30 derniers.", test = function(x) return x.active30 >= 20 end },
  { id = "total100", of = "total", need = 100, name = "Niveau total 100", desc = "Atteindre 100 au niveau total.", test = function(x) return x.total >= 100 end },
  { id = "total500", of = "total", need = 500, name = "Niveau total 500", desc = "Atteindre 500 au niveau total.", test = function(x) return x.total >= 500 end },
  { id = "total1000", of = "total", need = 1000, name = "Niveau total 1000", desc = "Atteindre 1000 au niveau total.", test = function(x) return x.total >= 1000 end },
  { id = "total1500", of = "total", need = 1500, name = "Niveau total 1500", desc = "Atteindre 1500 au niveau total.", test = function(x) return x.total >= 1500 end },
  { id = "total2000", of = "total", need = 2000, name = "Niveau total 2000", desc = "Atteindre 2000 au niveau total.", test = function(x) return x.total >= 2000 end },
  { id = "total2250", of = "total", need = 2250, name = "Niveau total 2250", desc = "Atteindre 2250 au niveau total.", test = function(x) return x.total >= 2250 end },
  { id = "prof150", of = "prof150", need = 1, name = "Compagnon", desc = "Un métier à 150.", test = function(x) return x.prof150 >= 1 end },
  { id = "prof225", of = "prof225", need = 1, name = "Expert", desc = "Un métier à 225.", test = function(x) return x.prof225 >= 1 end },
  { id = "firstmax", of = "maxProf", need = 1, name = "Maître", desc = "Un métier à 300.", test = function(x) return x.maxProf >= 1 end },
  { id = "gather2", of = "prof150", need = 2, name = "Double métier", desc = "Deux métiers à 150 ou plus.", test = function(x) return x.prof150 >= 2 end },
  { id = "craft2", of = "prof225", need = 2, name = "Double expert", desc = "Deux métiers à 225 ou plus.", test = function(x) return x.prof225 >= 2 end },
  { id = "capped5", of = "capped", need = 5, name = "Cinq au plafond", desc = "5 compétences au maximum.", test = function(x) return x.capped >= 5 end },
  { id = "capped10", of = "capped", need = 10, name = "Dix au plafond", desc = "10 compétences au maximum.", test = function(x) return x.capped >= 10 end },
  { id = "explorer", of = "zones", need = 10, name = "Explorateur", desc = "Des points de récolte ou de pêche dans 10 zones.", test = function(x) return x.zones >= 10 end },
  { id = "explorer25", of = "zones", need = 25, name = "Globe-trotteur", desc = "Des points de récolte ou de pêche dans 25 zones.", test = function(x) return x.zones >= 25 end },
  { id = "run30", of = "run", need = 1800, name = "Demi-heure d'affilée", desc = "30 minutes de jeu actif, sans pause de plus de 5 minutes.", test = function(x) return x.run >= 1800 end },
  { id = "run60", of = "run", need = 3600, name = "Heure d'affilée", desc = "1 heure de jeu actif, sans pause de plus de 5 minutes.", test = function(x) return x.run >= 3600 end },
  { id = "early", of = "early", need = 1, name = "Lève-tôt", desc = "Gagner un point entre 5 h et 7 h du matin.", test = function(x) return x.early end },
  { id = "night", of = "night", need = 1, name = "Noctambule", desc = "Gagner un point entre minuit et 5 h du matin.", test = function(x) return x.night end },
  { id = "fish5", of = "fishZones", need = 5, name = "Pêcheur du monde", desc = "Des points de pêche dans 5 zones.", test = function(x) return x.fishZones >= 5 end },
  { id = "firstfind", of = "huntFound", need = 1, name = "Premier sang", desc = "Trouver un objet recherché dans la Chasse.", test = function(x) return x.huntFound >= 1 end },
  { id = "persist50", of = "huntTries", need = 50, name = "Persévérant", desc = "Trouver un objet recherché après plus de 50 tentatives.", test = function(x) return x.huntTries > 50 end },
  { id = "col10", of = "colPct", need = 10, name = "Collectionneur", desc = "10 % du journal de collection rempli.", test = function(x) return x.colPct >= 10 end },
  { id = "col25", of = "colPct", need = 25, name = "Grand collectionneur", desc = "25 % du journal de collection rempli.", test = function(x) return x.colPct >= 25 end },
  { id = "col50", of = "colPct", need = 50, name = "Collection de rêve", desc = "50 % du journal de collection rempli.", test = function(x) return x.colPct >= 50 end },
  { id = "level60", of = "levelMaxN", need = 1, name = "Niveau maximum", desc = "Atteindre le niveau maximum.", test = function(x) return x.levelMax end },
}
-- Contexte lu une fois par vérification (instantané de la grille, records).
function P.Context()
  local p = P.C()
  local s = P.Session()
  local snap = ns.UI and ns.UI.snapshot
  local ranks = P._ctxRanks
  if type(ranks) == "table" then
    for k in pairs(ranks) do ranks[k] = nil end
  else
    ranks = {}
    P._ctxRanks = ranks
  end
  local maxProf, prof150, prof225 = 0, 0, 0
  local cap = ns.PROF_FINAL_CAP or 300
  for _, d in ipairs((snap and (snap.allTiles or snap.tiles)) or {}) do
    if d.id and not d.placeholder and N(d.current) then
      ranks[d.id] = math.max(ranks[d.id] or 0, N(d.current))
      if (d.kind == "profession" or d.kind == "secondary") and d.id ~= "riding" then
        local cur = N(d.current)
        if cur >= cap then maxProf = maxProf + 1 end
        if cur >= 150 then prof150 = prof150 + 1 end
        if cur >= 225 then prof225 = prof225 + 1 end
      end
    end
  end
  local dr = ns.Dopamine and ns.Dopamine.C and ns.Dopamine.C().records or {}
  local dc = ns.Dopamine and ns.Dopamine.C and ns.Dopamine.C().bestCombo
  local lvl, lcap = N(ns.GetPlayerLevel and ns.GetPlayerLevel()) or 0, N(ns.GetLevelCap and ns.GetLevelCap()) or 60
  local ctx = P._ctxBuf
  if type(ctx) ~= "table" then ctx = {} P._ctxBuf = ctx end
  ctx.snap, ctx.ranks, ctx.maxProf = snap, ranks, maxProf
  ctx.prof150, ctx.prof225 = prof150, prof225
  ctx.total = N(snap and snap.total) or N(ns.CharDB().lastTotal) or 0
  ctx.bestSession = math.max(N(p.records.bestSession) or 0, N(s.pts) or 0, N(dr.bestSession) or 0)
  ctx.bestHour = math.max(N(p.records.bestHour) or 0, N(dr.bestHour) or 0)
  ctx.combo = math.max(N(p.records.longestCombo) or 0, N(dc) or 0)
  ctx.streak = math.max(P.Streak().n, 0)
  ctx.goalsHit = N(p.records.goalsHit) or 0
  ctx.zones = P.SpotZoneCount()
  ctx.early, ctx.night = p.records.early ~= nil, p.records.night ~= nil
  ctx.huntFound, ctx.huntTries = N(p.records.huntFound) or 0, N(p.records.huntTries) or 0
  local fz = 0
  for _ in pairs(p.spots.fishing or {}) do fz = fz + 1 end
  ctx.fishZones = fz
  -- part du journal de collection (calcul mis en cache 60 s : lecture du Journal des donjons)
  local nowC = Wall()
  if not P._colAt or nowC - P._colAt >= 60 then
    P._colAt, P._colPct = nowC, 0
    local H = ns.Hunt
    if H and H.LogTotals then
      local okC, x, y = pcall(H.LogTotals)
      x, y = okC and N(x), okC and N(y)
      if x and y and y > 0 then P._colPct = x / y * 100 end
    end
  end
  ctx.colPct = math.floor((P._colPct or 0) * 10 + 0.5) / 10
  ctx.run = math.max(N(p.records.longestRun) or 0, N(s.run) or 0)
  -- jours actifs sur 30 jours et compétences au plafond (indépendants du rythme)
  local today, act = P.Today(), 0
  for i = 0, 29 do
    local day = P.DayOffset(today, -i)
    if day and P.DayPoints(day) > 0 then act = act + 1 end
  end
  ctx.active30 = act
  local capped = 0
  for _, d in ipairs((snap and (snap.allTiles or snap.tiles)) or {}) do
    if d.inTotal and d.kind ~= "level" and not d.placeholder then
      local cap = N(d.apiMax)
      if cap and cap > 0 and (N(d.current) or 0) >= cap then capped = capped + 1 end
    end
  end
  ctx.capped = capped
  ctx.levelMax = lvl > 0 and lvl >= lcap
  ctx.levelMaxN = nil
  return ctx
end
-- why : « seed » (silencieux), sinon toast pour chaque nouveau succès.
function P.CheckAchievements(why)
  local p = P.C()
  if why ~= "seed" and not p.achSeeded then return {} end
  if P._checking then return {} end
  if why ~= "seed" then
    local now = Wall()
    if P._achAt and now - P._achAt < 1 then return P._achNew or {} end
    P._achAt = now
  end
  P._checking = true
  local ok, ctx = pcall(P.Context)
  local new = {}
  if ok and ctx then
    for _, a in ipairs(P.ACHIEVEMENTS) do
      if not p.ach[a.id] then
        local okT, hit = pcall(a.test, ctx)
        if okT and hit then
          p.ach[a.id] = Wall()
          new[#new + 1] = a
        end
      end
    end
  end
  P._checking = nil
  P._achNew = new
  if why == "seed" then
    p.achSeeded = true
    P.seededSilently = #new
    return new
  end
  if #new > 0 and ns.Opt("achievements") then
    if #new <= 2 then
      for _, a in ipairs(new) do
        P.Toast(Tr["Succès : "] .. Tr[a.name], Tr[a.desc], { kind = "achievement", variant = "gold" }, "prog-ach-" .. a.id, true)
      end
    else
      -- jamais une rafale : un seul toast résume
      P.Toast(string.format(Tr["%d succès débloqués !"], #new), Tr[new[1].name] .. ", " .. Tr[new[2].name] .. "…", { kind = "achievement", variant = "gold" }, "prog-ach-many", true)
    end
  end
  return new
end
-- Feu d'artifice (palier maximum) : gerbes d'étincelles dorées au-dessus du personnage, sans modèle 3D
local SPARK = "Interface\\Cooldown\\star4"
local COLS = { { 1, 0.85, 0.3 }, { 1, 0.6, 0.2 }, { 1, 0.95, 0.7 }, { 0.6, 0.85, 1 } }
function P.Fireworks()
  if not (_G.CreateFrame and _G.UIParent) then return end
  local f = P._fw
  if not f then
    f = CreateFrame("Frame", nil, UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(false)
    f.sparks = {}
    P._fw = f
  end
  f.parts = {}
  local used = 0
  local function Burst(delay, ox, oy, col)
    for i = 1, 16 do
      used = used + 1
      local t = f.sparks[used]
      if not t then t = f:CreateTexture(nil, "OVERLAY") t:SetTexture(SPARK) t:SetBlendMode("ADD") f.sparks[used] = t end
      local a = (i / 16) * math.pi * 2
      local sp = 90 + (i % 3) * 35
      f.parts[#f.parts + 1] = { t = t, d = delay, ox = ox, oy = oy, vx = math.cos(a) * sp, vy = math.sin(a) * sp, c = col }
    end
  end
  Burst(0.0, 0, 140, COLS[1])
  Burst(0.35, -190, 90, COLS[2])
  Burst(0.6, 190, 110, COLS[3])
  Burst(1.0, -80, 190, COLS[4])
  Burst(1.3, 120, 160, COLS[1])
  f.t0 = (GetTime and GetTime()) or 0
  f:Show()
  f:SetScript("OnUpdate", function(self)
    local now = ((GetTime and GetTime()) or 0) - self.t0
    local alive = false
    for _, p in ipairs(self.parts) do
      local tt = now - p.d
      if tt >= 0 and tt < 1.5 then
        alive = true
        local k = tt / 1.5
        p.t:SetVertexColor(p.c[1], p.c[2], p.c[3], 1 - k)
        p.t:SetAlpha(1 - k)
        local sz = 14 * (1 - k * 0.6)
        p.t:SetSize(sz, sz)
        p.t:ClearAllPoints()
        p.t:SetPoint("CENTER", UIParent, "CENTER", p.ox + p.vx * tt, p.oy + p.vy * tt - 120 * tt * tt)
        p.t:Show()
      else
        p.t:Hide()
        if tt < 0 then alive = true end
      end
    end
    if not alive then self:SetScript("OnUpdate", nil) self:Hide() end
  end)
end

function P.DingFx(hit, tmax, force)
  local ui = ns.UI
  if not (ui and ui.SpawnDrop) then return end
  do
    local isMax = (tmax or 0) > 0 and (hit >= tmax)
    local f = ui:SpawnDrop(ns.LEVEL_ICON, Tr["Niveau total "] .. hit .. Tr[" atteint !"],
      isMax and Tr["Maximum atteint !"] or Tr["Palier du total franchi"], nil, nil, nil,
      { kind = "levelup", variant = "gold", big = true })
    if f then
      if ui.AttachFlareFx then pcall(ui.AttachFlareFx, ui, f, true) end
      if ns.SoundOk and ns.SoundOk("levelUpSound") and type(PlaySound) == "function" and ui.LevelUpSoundKit then
        local kit = ui:LevelUpSoundKit()
        if kit then pcall(PlaySound, kit) end
      end
    end
    if ns.Slot and ns.Slot.PlayLevelUp then pcall(ns.Slot.PlayLevelUp) end
    if ui.PulseLevelTile then pcall(ui.PulseLevelTile, ui) end
    if type(DoEmote) == "function" then pcall(DoEmote, "CHEER") end
    if isMax and (force or ns.Opt("fireworks")) then pcall(P.Fireworks) end
  end
end
-- 3.8.1 : « ding » du niveau total : à chaque palier franchi (500, 1000, 1500, 2000, 2250, max),
-- grosse animation de montée de niveau (toast doré, éclat, goutte qui déborde), une seule fois.
function P.TotalDing(prev, cur)
  if not ns.Milestones then return end
  local p = P.C()
  p.dinged = type(p.dinged) == "table" and p.dinged or {}
  local tmax = N(ns.TOTAL_MAX) or 0
  local snap = ns.UI and ns.UI.snapshot
  if snap and N(snap.totalMax) then tmax = N(snap.totalMax) end
  local passed = ns.Milestones(cur, tmax)
  local hit
  for _, m in ipairs(passed) do
    if m > prev and not p.dinged[m] then hit = m end
    if m > prev then p.dinged[m] = true end
  end
  if not hit then return end
  if not ns.Opt("totalDing") then return end
  local ui = ns.UI
  if not (ui and ui.SpawnDrop) then return end
  local function go() P.DingFx(hit, tmax) end
  if InCombat() then
    if ns.AfterCombat then ns.AfterCombat("prog-total-ding", go) end
  else
    go()
  end
end
-- Amorce silencieuse : dès que la grille a été lue une fois (rangs connus).
function P.Seed()
  local p = P.C()
  if p.achSeeded then return false end
  local snap = ns.UI and ns.UI.snapshot
  if not snap or (N(snap.liveCount) or 0) <= 0 then return false end
  P.SeedStreak()
  do
    local p2 = P.C()
    p2.dinged = type(p2.dinged) == "table" and p2.dinged or {}
    local tot = N(snap.total) or 0
    for _, m in ipairs({ 500, 1000, 1500, 2000, 2250 }) do if tot >= m then p2.dinged[m] = true end end
  end
  P.CheckAchievements("seed")
  return true
end
function P.Achievements()
  local p = P.C()
  local okC, ctx = pcall(P.Context)
  if not okC then ctx = nil end
  if ctx then ctx.levelMaxN = ctx.levelMax and 1 or 0 end
  local out = {}
  for _, a in ipairs(P.ACHIEVEMENTS) do
    local cur, target
    if a.of and ctx then cur, target = N(ctx[a.of]) or 0, a.need end
    if a.ofCount and ctx then cur, target = CountAtLeast(ctx, a.ofCount, a.at), 2 end
    if cur and target then cur = math.floor(math.min(cur, target)) end
    out[#out + 1] = { id = a.id, name = Tr[a.name], desc = Tr[a.desc], unlocked = p.ach[a.id] ~= nil, at = p.ach[a.id],
      cur = cur, target = target }
  end
  return out
end

------------------------------------------------------------------------------
-- Toasts (différés après le combat, son de record si permis)
------------------------------------------------------------------------------
function P.Toast(title, sub, opts, key, sound, icon)
  local function go()
    local ui = ns.UI
    if not (ui and ui.SpawnDrop) then return nil end
    opts = opts or { kind = "progress" }
    local f = ui:SpawnDrop(icon or P.ICON, title, sub, nil, nil, nil, opts)
    if sound and ns.Dopamine and ns.Dopamine.Play then ns.Dopamine.Play("soundRecord") end
    return f
  end
  if InCombat() then
    if ns.AfterCombat then ns.AfterCombat(key or ("prog-" .. tostring(title)), go) end
    return nil
  end
  return go()
end

------------------------------------------------------------------------------
-- Mode calme : en instance (donjon / raid) ou en groupe
------------------------------------------------------------------------------
P.QUIET_KEEP = { levelup = true, max = true, achievement = true, goal = true, tier = true, recap = true, weekly = true, daily = true }
P.quietStats = { blocked = 0, changes = 0 }
-- 3.9.0 : une seule liste « Jamais / En donjon ou raid / En groupe ou en instance » (avant : « Jamais » +
-- « Calme auto en donjon » coché par défaut, donc calme en donjon malgré « Jamais »). Reprise, une fois :
-- Jamais + auto coché -> En donjon ou raid ; Jamais + auto décoché -> Jamais ; les autres choix ne bougent pas.
function P.QuietSetting()
  local ui = ns.db and ns.db.ui
  if ui and ui.quietMigrated ~= 1 then
    if ui.quietMode == nil or ui.quietMode == "off" then ui.quietMode = (ui.quietAuto == false) and "off" or "instance" end
    ui.quietMigrated = 1
  end
  local v = ui and ui.quietMode
  if v == "instance" or v == "group" then return v end
  return "off"
end
function P.InInstanceGroup()
  if P._simInstance == "party" or P._simInstance == "raid" then
    return P._simInstance, true
  end
  local inInst, kind = Call(_G.IsInInstance)
  local inst = inInst and (kind == "party" or kind == "raid") and kind or nil
  local grouped = false
  if type(_G.IsInGroup) == "function" then grouped = Call(_G.IsInGroup) and true or false end
  if not grouped then
    for _, fn in ipairs({ "GetNumGroupMembers", "GetNumRaidMembers", "GetNumPartyMembers" }) do
      local n = N(Call(_G[fn]))
      if n and n > 0 then grouped = true break end
    end
  end
  return inst, grouped
end
-- 3.9.0 : champ de bataille ou arène (kind « pvp » / « arena » d'IsInInstance)
function P.InPvp()
  if P._simInstance == "pvp" or P._simInstance == "arena" then return P._simInstance end
  local inInst, kind = Call(_G.IsInInstance)
  return (inInst and (kind == "pvp" or kind == "arena")) and kind or nil
end
-- 3.9.0 : bouton Tester de « Calme auto en champ de bataille » : 15 s simulées (message d'entrée,
-- toasts réduits), puis retour à la normale ; passe outre la case comme les autres tests
function P.SimPvp(seconds)
  local stamp = {}
  P._simPvpStamp, P._simInstance, P._simPvpForce = stamp, "pvp", true
  P.RecomputeQuiet(false)
  local function back()
    if P._simPvpStamp ~= stamp then return end
    P._simInstance, P._simPvpForce, P._simPvpStamp = nil, nil, nil
    P.RecomputeQuiet(false)
  end
  if _G.C_Timer and _G.C_Timer.After then _G.C_Timer.After(seconds or 15, back) end
  return true
end
function P.RecomputeQuiet(silent)
  local mode = P.QuietSetting()
  local inst, grouped = P.InInstanceGroup()
  local on, why = false, nil
  if mode == "instance" and inst then on, why = true, (inst == "raid") and "raid" or "donjon"
  elseif mode == "group" and (inst or grouped) then on, why = true, inst and ((inst == "raid") and "raid" or "donjon") or "groupe"
  end
  -- 3.9.0 : calme auto en champ de bataille / arène (réglage à part, coché par défaut)
  if not on then
    local pvp = P.InPvp()
    if pvp and (P._simPvpForce or not (ns.Opt and ns.Opt("quietAutoPvp") == false)) then on, why = true, (pvp == "arena") and "arène" or "champ de bataille" end
  end
  local was = P._quiet
  P._quiet, P._quietWhy = on, why
  if was ~= nil and was ~= on then
    P.quietStats.changes = P.quietStats.changes + 1
    if not silent then
      if on then Say(Tr["mode calme : actif ("] .. Tr[why] .. Tr[") — toasts réduits, sons coupés selon tes réglages."])
      else Say(Tr["mode calme : terminé, toasts et sons normaux."]) end
    end
  end
  return on, why
end
function P.QuietActive() if P._quiet == nil then P.RecomputeQuiet(true) end return P._quiet and true or false end
function P.AutoQuietOpt()
  return not (ns.Opt and ns.Opt("quietAuto") == false)
end
-- Active le mode calme « instance » à l'entrée en donjon / raid, restaure le
-- réglage précédent à la sortie. Ne combat pas un choix déjà « instance » ou « groupe ».
function P.AutoQuietSync(silent)
  -- 3.7.3 : le calme auto vit en mémoire (RecomputeQuiet) ; on n'écrit plus
  -- jamais quietMode dans les SavedVariables (un /reload ou un crash en donjon
  -- laissait le réglage bloqué sur « instance »).
  P._autoQuietHeld, P._autoQuietPrev = nil, nil
  P.RecomputeQuiet(silent)
end
function P.Quiet() return { active = P.QuietActive(), why = P._quietWhy, mode = P.QuietSetting(), toasts = (ns.db and ns.db.ui and ns.db.ui.quietToasts) or "reduce", sounds = ns.Opt("quietSounds"), blocked = P.quietStats.blocked } end
function P.QuietBlocks(opts)
  if not P.QuietActive() then return false end
  if opts and opts.force then return false end              -- boutons Tester, aperçus
  if ns.UI and ns.UI._inEditMode then return false end
  local m = (ns.db and ns.db.ui and ns.db.ui.quietToasts) or "reduce"
  if m == "keep" then return false end
  if m == "mute" then return true end
  return not P.QUIET_KEEP[opts and opts.kind or ""]
end
local UI = ns.UI
if UI and UI.SpawnDrop then
  local baseSpawn = UI.SpawnDrop
  function UI:SpawnDrop(icon, title, sub, cur, mx, right, opts, ...)
    if P.QuietBlocks(opts) then P.quietStats.blocked = P.quietStats.blocked + 1 return nil end
    return baseSpawn(self, icon, title, sub, cur, mx, right, opts, ...)
  end
end
if ns.SoundOk then
  local baseOk = ns.SoundOk
  function ns.SoundOk(name)
    if P.QuietActive() and ns.Opt("quietSounds") then return false end
    return baseOk(name)
  end
end

------------------------------------------------------------------------------
-- Tri intelligent des cases (option, coupé par défaut) : DANS chaque groupe
-- (même type de case), les compétences actives de la session passent devant ;
-- l'ordre classique des groupes ne change jamais.
------------------------------------------------------------------------------
if ns.SortDisplayTiles then
  local baseSort = ns.SortDisplayTiles
  function ns.SortDisplayTiles(tiles)
    baseSort(tiles)
    if not (ns.OptOff and ns.OptOff("smartSort")) or type(tiles) ~= "table" then return end
    local okS, s = pcall(P.Session)
    if not okS or not s then return end
    local function last(d) local v = d and d.id and s.skills[d.id] return v and N(v.t) or 0 end
    local i = 1
    while i <= #tiles do
      local j = i
      while j + 1 <= #tiles and tiles[j + 1].kind == tiles[i].kind do j = j + 1 end
      if j > i then
        local run = {}
        for k = i, j do run[#run + 1] = { d = tiles[k], o = k, t = last(tiles[k]) } end
        table.sort(run, function(a, b) if a.t ~= b.t then return a.t > b.t end return a.o < b.o end)
        for k = i, j do tiles[k] = run[k - i + 1].d end
      end
      i = j + 1
    end
  end
end

------------------------------------------------------------------------------
-- Partage (UNIQUEMENT sur /drop share ou un clic explicite : jamais automatique)
------------------------------------------------------------------------------
local function Thousands(n)
  n = math.floor((N(n) or 0) + 0.5)
  local s = tostring(math.abs(n))
  local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
  return (n < 0 and "-" or "") .. out
end
P.Thousands = Thousands
local function Dur(sec)
  sec = math.floor(N(sec) or 0)
  local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60)
  if h > 0 then return string.format("%d h %02d", h, m) end
  return string.format(Tr["%d min"], m)
end
P.Dur = Dur
function P.ShareText()
  local s = P.Session()
  local r = P.Rates()
  local snap = ns.UI and ns.UI.snapshot
  local total = N(snap and snap.total) or N(ns.CharDB().lastTotal)
  local parts = {}
  if total then parts[#parts + 1] = Tr["Niveau total "] .. Thousands(total) end
  parts[#parts + 1] = string.format(Tr["session +%d (%s)"], s.pts or 0, Dur(r.elapsed))
  if r.xph and r.xph > 0 then parts[#parts + 1] = Thousands(r.xph) .. Tr[" XP/h"] end
  if r.pph then
    local pph = string.format("%.1f", r.pph)
    if ns.DecimalComma and ns.DecimalComma() then pph = pph:gsub("%.", ",") end
    parts[#parts + 1] = pph .. Tr[" pts/h"]
  end
  local st = P.Streak().n
  if st > 0 then parts[#parts + 1] = string.format(Tr["série %d j"], st) end
  local txt = "[Dropamine] " .. table.concat(parts, " · ")
  -- texte de chat sûr : ni codes couleur, ni liens, ni retour à la ligne
  txt = txt:gsub("|", "/"):gsub("[\r\n]", " ")
  if #txt > 250 then txt = txt:sub(1, 250) end
  return txt
end
P.SHARE_CHANNELS = { say = "SAY", dire = "SAY", party = "PARTY", groupe = "PARTY", guild = "GUILD", guilde = "GUILD",
  raid = "RAID", instance = "INSTANCE_CHAT" }
-- channel nil : le texte est posé dans la zone de saisie (Entrée pour envoyer).
function P.Share(channel)
  local text = P.ShareText()
  local ch = channel and P.SHARE_CHANNELS[tostring(channel):lower()]
  if ch then
    if type(_G.SendChatMessage) ~= "function" then return false, text end
    local ok = pcall(_G.SendChatMessage, text, ch)
    if not ok then Say(Tr["partage refusé par le jeu sur ce canal."]) end
    return ok, text
  end
  local eb = Call(_G.ChatEdit_GetActiveWindow)
  if type(eb) == "table" and eb.Insert then pcall(eb.Insert, eb, text) return true, text end
  if type(_G.ChatFrame_OpenChat) == "function" then pcall(_G.ChatFrame_OpenChat, text) return true, text end
  Say(text)
  return false, text
end

------------------------------------------------------------------------------
-- API complète pour la fenêtre Progression (Phase 2)
------------------------------------------------------------------------------
-- Dernier succès débloqué (fenêtre Progression : bandeau du bas).
function P.LastAchievement()
  local best
  for _, a in ipairs(P.Achievements()) do
    if a.unlocked and (not best or (N(a.at) or 0) > (N(best.at) or 0)) then best = a end
  end
  return best
end
function P.UnlockedCount()
  local n = 0
  for _, a in ipairs(P.Achievements()) do if a.unlocked then n = n + 1 end end
  return n, #P.ACHIEVEMENTS
end
-- Tous les coins (4 métiers de récolte), triés par rythme (min/pt) le plus rapide.
function P.AllSpots(limit)
  local out = {}
  for _, id in ipairs({ "herbalism", "mining", "skinning", "fishing" }) do
    for _, z in ipairs(P.Spots(id)) do z.skill = id out[#out + 1] = z end
  end
  -- 3.13.0 : par points gagnés (le rythme en min/pt dépend trop du rang pour comparer des zones)
  table.sort(out, function(a, b)
    if a.pts ~= b.pts then return a.pts > b.pts end
    return tostring(a.zone) < tostring(b.zone)
  end)
  if limit and #out > limit then for i = #out, limit + 1, -1 do out[i] = nil end end
  return out
end
function P.BestSpot() return P.AllSpots(1)[1] end
-- Points de la session découpés en tranches (graphique « Session »).
function P.SessionBuckets(n)
  n = N(n) or 8
  local s = P.Session()
  local curve = s.curve or {}
  local now = Wall()
  local elapsed = math.max(60, now - (N(s.start) or now))
  local step = elapsed / n
  local out = {}
  for i = 1, n do out[i] = { t0 = (i - 1) * step, t1 = i * step, pts = 0, level = 0, combat = 0, prof = 0, xp = 0 } end
  local pv = { total = 0, lv = 0, cb = 0, pf = 0, xp = 0 }
  local pts = {}
  for _, e in ipairs(curve) do pts[#pts + 1] = e end
  local sc = s.cat or {}
  pts[#pts + 1] = { t = elapsed, total = s.pts or 0, lv = N(sc.level) or 0, cb = N(sc.combat) or 0, pf = N(sc.prof) or 0, xp = s.xp or 0 }
  for _, e in ipairs(pts) do
    local i = math.max(1, math.min(n, math.floor((N(e.t) or 0) / step) + 1))
    local b = out[i]
    local d = function(k, pk) local v = (N(e[k]) or 0) - (N(pv[pk or k]) or 0) return v > 0 and v or 0 end
    b.pts = b.pts + d("total")
    b.level = b.level + d("lv")
    b.combat = b.combat + d("cb")
    b.prof = b.prof + d("pf")
    b.xp = b.xp + d("xp")
    pv = { total = N(e.total) or pv.total, lv = N(e.lv) or pv.lv, cb = N(e.cb) or pv.cb, pf = N(e.pf) or pv.pf, xp = N(e.xp) or pv.xp }
  end
  return out, step
end
function P.Records()
  local p = P.C()
  local R = p.records
  local dr = ns.Dopamine and ns.Dopamine.C and ns.Dopamine.C().records or {}
  return { bestSession = math.max(N(R.bestSession) or 0, N(dr.bestSession) or 0), bestHour = N(R.bestHour) or 0,
    bestDay = N(R.bestDay) or 0, bestDayKey = R.bestDayKey, longestCombo = N(R.longestCombo) or 0, longestRun = N(R.longestRun) or 0,
    playtime = N(R.playtime) or 0, sessions = N(R.sessions) or 0, goalsHit = N(R.goalsHit) or 0,
    bestSessionAt = R.bestSessionAt or dr.bestSessionAt, bestHourAt = R.bestHourAt }
end
function P.GetSession()
  local s = P.Session()
  local D = ns.Dopamine
  return { start = s.start, pts = s.pts or 0, cat = s.cat, xp = s.xp or 0, levels = s.levels or 0,
    combo = (D and D.LiveCombo and D.LiveCombo()) or 0, bestCombo = s.bestCombo or 0,
    hourPts = P.HourPoints(), goalHit = s.goalHit }
end
function P.Snapshot()
  return { session = P.GetSession(), rates = P.Rates(), top = P.TopSkills(8), curve = P.Curve(), records = P.Records(),
    goal = P.Goal(), streak = P.Streak(), history = P.History(30), week = P.WeeklyRecap(0), lastWeek = P.WeeklyRecap(1),
    achievements = P.Achievements(), quiet = P.Quiet(),
    spots = { herbalism = P.Spots("herbalism", 5), mining = P.Spots("mining", 5), skinning = P.Spots("skinning", 5), fishing = P.Spots("fishing", 5) } }
end

------------------------------------------------------------------------------
-- Minuterie (2 min) : courbe + temps de jeu. Une seule chaîne active.
------------------------------------------------------------------------------
-- Un seul cadre caché + compteur (pas de minuterie qui se relance elle-même) :
-- quelques additions par image, le travail réel toutes les 2 min seulement.
function P.Tick()
  pcall(P.AccountTime)
  pcall(P.Sample)
  if ns.CaptureCharSheet then pcall(ns.CaptureCharSheet) end
  P.Notify("tick")
end
function P.TickStep(_, elapsed)
  P._presAcc = (P._presAcc or 0) + (N(elapsed) or 0)
  if P._presAcc >= 10 then P._presAcc = 0 pcall(P.Presence) end
  P._tickAcc = (P._tickAcc or 0) + (N(elapsed) or 0)
  if P._tickAcc < P.SAMPLE_SECS then return end
  P._tickAcc = 0
  P.Tick()
end
function P.StartTicker()
  P._tickAcc = 0
  if P._ticker then return true end
  if type(_G.CreateFrame) ~= "function" then return false end
  local ok, f = pcall(_G.CreateFrame, "Frame")
  if not ok or type(f) ~= "table" or not f.SetScript then return false end
  P._ticker = f
  f:SetScript("OnUpdate", P.TickStep)
  return true
end

------------------------------------------------------------------------------
-- Options (réglages 2.0) et commandes
------------------------------------------------------------------------------
P.OPTIONS = {
  { type = "check", key = "charProfile", label = "Profil d'affichage par personnage", default = false, noReset = true, cmd = "/drop profil perso|compte",
    help = "Ce personnage garde son propre thème, ses colonnes, sa taille, ses opacités et ses positions. Décoché : réglages du compte.",
    get = function() return ns.CharProfileOn and ns.CharProfileOn() or false end,
    set = function(v) if ns.SetCharProfile then ns.SetCharProfile(v and true or false) end end },
  { type = "check", key = "smartSort", label = "Tri intelligent des cases", default = false, cmd = "/drop tri on|off", refresh = true,
    help = "Dans chaque groupe, les compétences qui montent cette session passent devant. Décoché : ordre fixe classique." },
  { type = "radio", key = "quietMode", label = "Mode calme", default = "instance", cmd = "/drop calme off|instance|groupe",
    choices = { { "off", "Jamais" }, { "instance", "En donjon / raid" }, { "group", "En groupe ou en instance" } },
    help = "Réduit les toasts et coupe les sons en instance, ou dès que tu es en groupe. Les boutons Tester passent outre.",
    set = function(v)
      -- un changement manuel en donjon : on arrête de « tenir » le calme auto
      P._autoQuietHeld, P._autoQuietPrev = nil, nil
      ns.SetOpt("quietMode", v) P.RecomputeQuiet()
    end },
  { type = "check", key = "quietAuto", label = "Calme auto en donjon", default = true,
    help = "Active le mode calme « en donjon / raid » à l'entrée, et rétablit ton réglage à la sortie. Ne change pas le défaut du mode calme (jamais).",
    set = function(v) ns.SetOpt("quietAuto", v and true or false) P.AutoQuietSync() end },
  { type = "check", key = "quietAutoPvp", label = "Calme auto en champ de bataille", default = true,
    help = "Active le mode calme en champ de bataille et en arène, et revient à la normale à la sortie.",
    set = function(v) ns.SetOpt("quietAutoPvp", v and true or false) P.AutoQuietSync() end },
  { type = "radio", key = "quietToasts", label = "Toasts en mode calme", default = "reduce", cmd = "/drop calme toasts reduit|aucun|tous",
    choices = { { "reduce", "Seulement l'important" }, { "mute", "Aucun toast" }, { "keep", "Tous les toasts" } },
    help = "Seulement l'important : niveaux, maximums, objectifs, succès, récaps." },
  { type = "check", key = "quietSounds", label = "Couper les sons en mode calme", default = true, cmd = "/drop calme sons on|off",
    help = "Aucun son de Dropamine tant que le mode calme est actif." },
  { type = "check", key = "goalToast", label = "Toast d'objectif atteint", default = true, cmd = "/drop but toast on|off",
    help = "Un seul toast par objectif atteint." },
  { type = "check", key = "achievements", label = "Succès Dropamine", default = true, cmd = "/drop succes on|off",
    help = "Toast doré à chaque succès débloqué ; ceux déjà mérités sont notés sans toast." },
  { type = "check", key = "weeklyRecap", label = "Récap du lundi", default = true, cmd = "/drop semaine on|off",
    help = "Résumé de la semaine passée, une fois, le lundi (au plus tard le mercredi)." },
}
if ns.Options then
  local H = ns.Options.EXTRA_HOME
  H.charProfile, H.smartSort = "display", "display"
  H.quietMode, H.quietAuto, H.quietToasts, H.quietSounds = "notif", "notif", "notif", "sounds"
  H.quietAutoPvp = "notif"
  H.sessionGoal, H.goalToast, H.achievements, H.weeklyRecap = "progress", "progress", "progress", "progress"
  for _, it in ipairs(P.OPTIONS) do ns.Options.EXTRA[#ns.Options.EXTRA + 1] = it end
  ns.Options.ITEMS = ns.Options.All()
end
local function SetKey(key, v)
  if ns.Options and ns.Options.Set then return ns.Options.Set(key, v) end
  return ns.SetOpt(key, v)
end
local function OnOff(word) word = (word or ""):lower() if word == "on" or word == "1" or word == "oui" then return true end if word == "off" or word == "0" or word == "non" then return false end return nil end

ns.SlashExt = ns.SlashExt or {}
ns.HelpExt = ns.HelpExt or {}
function P.SummaryLines()
  local s = P.Session()
  local r = P.Rates()
  local g = P.Goal()
  local st = P.Streak()
  local R = P.Records()
  local L = {}
  L[#L + 1] = string.format(Tr["Session : +%d points en %s (objectif %d/%d)"], s.pts or 0, Dur(r.elapsed), g.pts, g.target)
  local rates = {}
  if r.xph then rates[#rates + 1] = Thousands(r.xph) .. Tr[" XP/h"] end
  if r.pph then rates[#rates + 1] = string.format("%.1f", r.pph) .. Tr[" pts/h"] end
  if r.etaLevel then rates[#rates + 1] = Tr["niveau suivant dans "] .. (ns.FormatDuration and ns.FormatDuration(r.etaLevel) or Dur(r.etaLevel)) end
  if #rates > 0 then L[#L + 1] = "  " .. table.concat(rates, " · ") end
  local top = {}
  for _, t in ipairs(P.TopSkills(4)) do top[#top + 1] = tostring(t.name) .. " +" .. t.n end
  if #top > 0 then L[#L + 1] = "  " .. table.concat(top, ", ") end
  L[#L + 1] = string.format(Tr["  série %d j (record %d) · records : session %d, heure %d, combo x%d"], st.n, st.best, R.bestSession, R.bestHour, R.longestCombo)
  return L
end
ns.SlashExt.progression = function() for _, l in ipairs(P.SummaryLines()) do Say(l) end end
ns.SlashExt.progres = ns.SlashExt.progression
ns.SlashExt["progrès"] = ns.SlashExt.progression
ns.SlashExt.but = function(rest)
  rest = (rest or ""):lower()
  local which, arg = rest:match("^(%S*)%s*(%S*)")
  if which == "toast" then
    local v = OnOff(arg)
    if v == nil then v = not ns.Opt("goalToast") end
    SetKey("goalToast", v)
    Say(Tr["toast d'objectif"] .. (v and Tr[" : activé."] or Tr[" : désactivé."]))
    return
  end
  local sign, num = rest:match("^%s*([%+%-]?)(%d+)")
  if num then
    local n = (sign == "+" and P.BumpGoal(tonumber(num))) or (sign == "-" and P.BumpGoal(-tonumber(num))) or P.SetGoal(tonumber(num))
    if ns.Options and ns.Options.panel and ns.Options.panel:IsShown() and ns.Options.Sync then pcall(ns.Options.Sync) end
    Say(string.format(Tr["objectif de session : %d points."], n))
    return
  end
  local g = P.Goal()
  Say(string.format(Tr["objectif de session : %d/%d (usage : /drop but <n>|+5|+10|+25)"], g.pts, g.target))
end
ns.SlashExt.semaine = function(rest)
  local v = OnOff(rest)
  if v ~= nil then SetKey("weeklyRecap", v) Say(Tr["récap du lundi"] .. (v and Tr[" : activé."] or Tr[" : désactivé."])) return end
  Say(P.WeeklyLine(P.WeeklyRecap(0)))
  Say(P.WeeklyLine(P.WeeklyRecap(1)))
end
ns.SlashExt.succes = function(rest)
  local v = OnOff(rest)
  if v ~= nil then SetKey("achievements", v) Say(Tr["succès Dropamine"] .. (v and Tr[" : activé."] or Tr[" : désactivé."])) return end
  local list, got = P.Achievements(), {}
  for _, a in ipairs(list) do if a.unlocked then got[#got + 1] = a.name end end
  Say(string.format(Tr["succès : %d/%d"], #got, #list) .. ((#got > 0) and (Tr[" : "] .. table.concat(got, ", ")) or ""))
end
ns.SlashExt["succès"] = ns.SlashExt.succes
ns.SlashExt.spots = function(rest)
  local want = (rest or ""):lower()
  local any = false
  for _, id in ipairs({ "herbalism", "mining", "skinning", "fishing" }) do
    if want == "" or want == id or (ns.SkillDisplayName and tostring(ns.SkillDisplayName(id)):lower() == want) then
      local list = P.Spots(id, 3)
      if #list > 0 then
        any = true
        local parts = {}
        for _, z in ipairs(list) do
          parts[#parts + 1] = z.zone .. " +" .. z.pts .. (z.avg and string.format(Tr[" (%.1f min/pt)"], z.avg) or "")
        end
        Say(SkillLabel(id) .. Tr[" : "] .. table.concat(parts, " · "))
      end
    end
  end
  if not any then Say(Tr["coins de récolte : rien encore (herboristerie, minage, dépeçage, pêche)."]) end
end
-- /drop share : on|off = ancien réglage « partage » (Maj+clic) ; sinon le récap.
ns.SlashExt.share = function(rest, msg)
  local low = (rest or ""):lower()
  if low == "on" or low == "off" then
    if ns.SlashExt.partage then return ns.SlashExt.partage(low) end
    return
  end
  local ok, text = P.Share(low ~= "" and low or nil)
  if low ~= "" and not P.SHARE_CHANNELS[low] then Say(Tr["usage : /drop share [say|party|guild|raid]"]) end
  return ok, text
end
ns.SlashExt.calme = function(rest)
  local low = (rest or ""):lower()
  local which, arg = low:match("^(%S*)%s*(%S*)")
  if which == "sons" or which == "sounds" then
    local v = OnOff(arg)
    if v == nil then v = not ns.Opt("quietSounds") end
    SetKey("quietSounds", v)
  elseif which == "toasts" then
    local map = { reduit = "reduce", ["réduit"] = "reduce", reduce = "reduce", aucun = "mute", mute = "mute", none = "mute", tous = "keep", tout = "keep", keep = "keep", all = "keep" }
    if map[arg] then SetKey("quietToasts", map[arg]) end
  elseif which == "off" or which == "0" or which == "non" then SetKey("quietMode", "off")
  elseif which == "on" or which == "instance" or which == "donjon" then SetKey("quietMode", "instance")
  elseif which == "groupe" or which == "group" then SetKey("quietMode", "group") end
  P.RecomputeQuiet(true)
  local q = P.Quiet()
  local names = { off = Tr["jamais"], instance = Tr["en donjon / raid"], group = Tr["en groupe ou en instance"] }
  Say(Tr["mode calme : "] .. (names[q.mode] or q.mode) .. (q.active and (Tr[" — actif ("] .. Tr[q.why or "?"] .. ")") or Tr[" — inactif"]))
end
ns.SlashExt.quiet = ns.SlashExt.calme
ns.SlashExt.profil = function(rest)
  local low = (rest or ""):lower()
  local v
  if low == "perso" or low == "personnage" or low == "char" or low == "on" then v = true
  elseif low == "compte" or low == "account" or low == "off" then v = false end
  if v ~= nil and ns.SetCharProfile then ns.SetCharProfile(v) end
  local on = ns.CharProfileOn and ns.CharProfileOn()
  Say(on and Tr["profil d'affichage : propre à ce personnage."] or Tr["profil d'affichage : réglages du compte."])
end
local function toggle(key, label)
  return function(rest)
    local v = OnOff(rest)
    if v == nil then v = not ns.OptOff(key) end
    SetKey(key, v)
    Say(Tr[label] .. (v and Tr[" : activé."] or Tr[" : désactivé."]))
  end
end
ns.SlashExt.tri = toggle("smartSort", "tri intelligent")
if ns.CMD_ALIAS then ns.CMD_ALIAS.sort = "tri" end
ns.HelpExt[#ns.HelpExt + 1] = "/drop progression : session (XP/h, points/h, objectif, série, records)"
ns.HelpExt[#ns.HelpExt + 1] = "/drop but <n>|+5|+10|+25 : objectif de session · /drop semaine : récap · /drop succes · /drop spots [métier]"
ns.HelpExt[#ns.HelpExt + 1] = "/drop share [say|party|guild|raid] : récap de session dans le chat (sans canal : zone de saisie)"
ns.HelpExt[#ns.HelpExt + 1] = "/drop calme off|instance|groupe · calme toasts reduit|aucun|tous · calme sons on|off · /drop profil perso|compte · /drop tri on|off"

------------------------------------------------------------------------------
-- Événements
------------------------------------------------------------------------------
-- Combo : relevé après Dopamine (même valeur que le badge x2, x3…)
if ns.Dopamine and ns.Dopamine.NoteCombo then
  local D = ns.Dopamine
  local baseNote = D.NoteCombo
  function D.NoteCombo(...)
    local n = baseNote(...)
    if n then pcall(P.NoteCombo, n) end
    return n
  end
end
-- Instantané de la grille : amorce silencieuse, puis succès d'état (total…)
if ns.QoL and ns.QoL.OnSnapshot then
  local Q = ns.QoL
  local baseSnap = Q.OnSnapshot
  Q.OnSnapshot = function(snap, ...)
    local r = baseSnap(snap, ...)
    if snap and (N(snap.liveCount) or 0) > 0 then
      local p = P.C()
      if not p.achSeeded then pcall(P.Seed)
      elseif N(snap.total) ~= P._lastTotal then pcall(P.CheckAchievements, "total") end
      if p.achSeeded and P._lastTotal and (N(snap.total) or 0) > P._lastTotal then pcall(P.TotalDing, P._lastTotal, N(snap.total)) end
      P._lastTotal = N(snap.total)
    end
    return r
  end
end
if ns.OnOptionChanged then
  local baseChanged = ns.OnOptionChanged
  function ns.OnOptionChanged(key, value, ...)
    if key == "quietMode" then pcall(P.RecomputeQuiet) end
    return baseChanged(key, value, ...)
  end
end
if ns.On then
  ns.On("PLAYER_ENTERING_WORLD", function()
    pcall(P.AutoQuietSync, true)

    pcall(P.Session)
    pcall(P.RecomputeQuiet, true)
    if P._entered then return end
    P._entered = true
    if P.QuietActive() then
      local why = P._quietWhy
      After(3, function() Say(Tr["mode calme : actif ("] .. Tr[why or "?"] .. Tr[") — toasts réduits, sons coupés selon tes réglages."]) end)
    end
    pcall(P.SeedStreak)
    P.StartTicker()
    After(12, function()
      if ns.AfterCombat then ns.AfterCombat("prog-weekly-check", function() pcall(P.CheckWeekly) end)
      else pcall(P.CheckWeekly) end
    end)
  end)
  for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "LOOT_OPENED" }) do ns.On(ev, function() pcall(P.TouchRun) end) end
  ns.On("PLAYER_XP_UPDATE", function() pcall(P.OnXP) end)
  ns.On("PLAYER_LEVEL_UP", function(_, lvl) pcall(P.OnLevelUp, lvl) end)
  for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE" }) do
    ns.On(ev, function() pcall(P.AutoQuietSync) pcall(P.RecomputeQuiet) end)
  end
  ns.On("PLAYER_LOGOUT", function()
    pcall(P.AccountTime)
    pcall(P.Sample, nil, true)
    if ns.CaptureCharSheet then pcall(ns.CaptureCharSheet) end
  end)
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local ok, s = pcall(P.Session)
  if not ok then return { "— Progression (3.6.0) — indisponible" } end
  local p = P.C()
  local nAch = 0
  for _ in pairs(p.ach) do nAch = nAch + 1 end
  local q = P.Quiet()
  return { string.format("— Progression (3.6.0) — session +%d (xp %d, %d niv.), courbe %d pts, objectif %d, série %d, succès %d/%d (amorcés en silence : %s), zones de récolte %d ; mode calme %s%s, toasts retenus %d ; profil perso %s",
    s.pts or 0, s.xp or 0, s.levels or 0, #(s.curve or {}), P.GoalTarget(), P.Streak().n, nAch, #P.ACHIEVEMENTS,
    tostring(p.achSeeded and (P.seededSilently or "oui") or "pas encore"), P.SpotZoneCount(),
    q.mode, q.active and (" (actif : " .. tostring(q.why) .. ")") or "", q.blocked, tostring(ns.CharProfileOn and ns.CharProfileOn() or false)) }
end

-- test avant release : /drop ding [palier] rejoue l'animation sans toucher aux paliers mémorisés
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.ding = function(rest)
  local snap = ns.UI and ns.UI.snapshot
  local tmax = (snap and N(snap.totalMax)) or N(ns.TOTAL_MAX) or 2460
  if (rest or ""):lower():find("fx", 1, true) then P.Fireworks() return end
  if (rest or ""):lower():find("max", 1, true) then P.DingFx(tmax, tmax, true) return end
  local n = tonumber((rest or ""):match("%d+")) or 1500
  P.DingFx(n, tmax, true)
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop ding [palier|max|fx] : rejoue l'animation de palier (test)"

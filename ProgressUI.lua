-- Dropamine 3.6.0 — ProgressUI.lua : fenêtre « Progression » (maquette validée
-- preview_3.6_progression.png) et mini-graphe 7 jours de l'infobulle du total.
--
-- Données : ns.Progress (Progress.lua) uniquement ; rien n'est calculé ici
-- qui ne soit déjà mesuré. Dessin : UNIQUEMENT des Frame / Button /
-- ScrollFrame / EditBox, des Texture (couleur pleine WHITE8X8 ou
-- SetColorTexture) et des FontString : aucune API Retail (pas de CreateLine,
-- pas de SetClipsChildren obligatoire), la courbe est faite de micro-colonnes
-- de 2 px — sûr sur tous les clients de WoW Forever.
--
-- Règles :
--  * tout est créé à la PREMIÈRE ouverture, hors combat (en combat, l'ouverture
--    attend la fin du combat) ; ensuite on ne fait que peindre des textures
--    existantes (pools fixes : 30 barres, 110 colonnes de courbe…) ;
--  * rafraîchissement regroupé (0,5 s, 2 s en combat), seulement si la
--    fenêtre est ouverte, seulement l'onglet visible ;
--  * aucun cadre de Blizzard touché : Échap via UISpecialFrames (notre nom
--    de cadre ajouté à la liste), position bornée à l'écran ;
--  * « Partager » n'envoie rien tout seul : le texte est posé dans la zone de
--    saisie du chat, sur clic explicite uniquement.
local _, ns = ...
local Tr = ns.L
local P = ns.Progress
local PU = {}
ns.ProgressUI = PU

PU.NAME = "DropamineProgressFrame"
PU.W, PU.H = 680, 500
PU.PAD = 12
PU.CONTENT_Y = 158
PU.CONTENT_W, PU.CONTENT_H = 656, 318
PU.MEDIA = "Interface\\AddOns\\Dropamine\\Media\\"
PU.LOGO = PU.MEDIA .. "Dropamine-Logo"            -- Media/Dropamine-Logo.tga (128 px, tiré du PNG)
PU.LOGO_FALLBACK = PU.MEDIA .. "Dropamine-Icon"
PU.WHITE = "Interface\\Buttons\\WHITE8X8"
PU.MAX_BARS = 30
PU.CURVE_COLS = 110            -- colonnes de 2 px
PU.REFRESH_WAIT = { idle = 0.5, combat = 2.0 }
PU.TABS = {
  { id = "overview", label = "Vue d'ensemble" },
  { id = "charts", label = "Graphiques" },
  { id = "ach", label = "Succès" },
  { id = "spots", label = "Spots de farm" },
  { id = "weekly", label = "Récap hebdo" },
}
PU.PERIODS = { { id = "session", label = "Session" }, { id = "d7", label = "7 j" }, { id = "d30", label = "30 j" } }
PU.METRICS = { { id = "total", label = "Total" }, { id = "xph", label = "XP/h" }, { id = "cat", label = "Catégories" } }
PU.DAY_SHORT = { "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim" }
PU.stats = { builds = 0, refreshes = 0, deferred = 0, requests = 0, mini = 0, miniHidden = 0, opens = 0, errors = 0 }

local function N(v) return (ns.N and ns.N(v)) or tonumber(v) end
local function Ret(ok, ...) if not ok then return nil end return ... end
local function Call(fn, ...) if type(fn) ~= "function" then return nil end return Ret(pcall(fn, ...)) end
local function InCombat() return ns.InCombat and ns.InCombat() or false end
local function Say(msg) if ns.Print then ns.Print(msg) end end
local function Thousands(n) return (P and P.Thousands and P.Thousands(n)) or tostring(math.floor((N(n) or 0) + 0.5)) end
local function Dur(sec) return (P and P.Dur and P.Dur(sec)) or tostring(sec) end
local function Dec(s) if ns.IsFrench and ns.IsFrench() then return (s:gsub("%.", ",")) end return s end
local function Fmt1(v) return Dec(string.format("%.1f", N(v) or 0)) end
local function Fmt2(v) return Dec(string.format("%.2f", N(v) or 0)) end
local function Short(v)
  v = N(v) or 0
  if v >= 10000 then return Dec(string.format("%.0fk", v / 1000)) end
  if v >= 1000 then return Dec(string.format("%.1fk", v / 1000)) end
  return tostring(math.floor(v + 0.5))
end
PU.Short = Short
local function UIDB()
  local db = ns.EnsureDB and ns.EnsureDB() or ns.db
  if not db then return {} end
  db.ui = db.ui or {}
  local s = db.ui.progressUI
  if type(s) ~= "table" then s = {} db.ui.progressUI = s end
  return s, db.ui
end
local function State()
  local s = UIDB()
  if s.tab ~= "overview" and s.tab ~= "charts" and s.tab ~= "ach" and s.tab ~= "spots" and s.tab ~= "weekly" then s.tab = "overview" end
  if s.period ~= "session" and s.period ~= "d7" and s.period ~= "d30" then s.period = "d7" end
  if s.metric ~= "total" and s.metric ~= "xph" and s.metric ~= "cat" then s.metric = "cat" end
  return s
end
PU.State = State

------------------------------------------------------------------------------
-- Palettes par thème (jetons Style / Theme / ClassicTheme)
------------------------------------------------------------------------------
local BRONZE = (ns.STYLE and ns.STYLE.BORDER) or { 0.65, 0.49, 0.27, 1 }
local SP = ns.Style and ns.Style.PALETTE or {}
local function Col(c, fallback) return (type(c) == "table" and c) or fallback end
PU.THEMES = {
  flare = {
    skin = true, bgAlpha = 0.96,
    card = { 0.153, 0.137, 0.125, 0.92 },                         -- #272320 (Style.PALETTE.sectionBg)
    cardEdge = { BRONZE[1], BRONZE[2], BRONZE[3], 0.55 },
    cardHi = { 0.30, 0.23, 0.12, 0.92 },
    title = Col(SP.titleYellow, { 1, 0.847, 0 }),
    text = Col(SP.bodyText, { 0.875, 0.875, 0.875 }),
    sub = Col(SP.subtitleGrey, { 0.69, 0.65, 0.60 }),
    label = Col(SP.categoryText, { 0.71, 0.61, 0.43 }),
    accent = { BRONZE[1], BRONZE[2], BRONZE[3], 1 },
    accentHi = Col(SP.selectedAccent, { 0.99, 0.82, 0.44 }),
    pillOn = { 0.50, 0.37, 0.18, 1 }, pillOff = { 0.17, 0.15, 0.13, 1 },
    pillEdge = { BRONZE[1], BRONZE[2], BRONZE[3], 0.75 },
    button = { 0.47, 0.33, 0.15, 1 }, buttonEdge = { 0.99, 0.82, 0.44, 0.9 }, buttonText = { 1, 0.92, 0.72 },
    track = { 0, 0, 0, 0.55 }, grid = { 1, 1, 1, 0.07 },
    bar = { 0.80, 0.62, 0.30, 1 }, barHi = { 1, 0.84, 0.40, 1 },
    line1 = { 1, 0.84, 0.35, 1 }, line2 = { 0.80, 0.80, 0.86, 1 }, fill1 = { 0.80, 0.62, 0.30, 0.22 },
    good = { 0.35, 0.95, 0.35 }, bad = { 1, 0.45, 0.40 }, gold = { 1, 0.82, 0 },
    mini = { 0.09, 0.08, 0.07, 0.96 },
  },
  leger = {
    skin = false, bgAlpha = 0.90,
    flat = { 0.05, 0.05, 0.06, 0.90 }, edge = { BRONZE[1], BRONZE[2], BRONZE[3], 0.85 },
    card = { 1, 1, 1, 0.035 }, cardEdge = { 1, 1, 1, 0.08 }, cardHi = { 1, 0.85, 0.45, 0.10 },
    title = { 1, 0.86, 0.30 }, text = { 0.92, 0.92, 0.92 }, sub = { 0.66, 0.66, 0.66 }, label = { 0.85, 0.78, 0.62 },
    accent = { 0.90, 0.80, 0.60, 1 }, accentHi = { 1, 0.90, 0.60 },
    pillOn = { 1, 1, 1, 0.18 }, pillOff = { 1, 1, 1, 0.05 }, pillEdge = { 1, 1, 1, 0.14 },
    button = { 0.55, 0.42, 0.22, 0.85 }, buttonEdge = { 1, 0.9, 0.6, 0.6 }, buttonText = { 1, 0.95, 0.85 },
    track = { 1, 1, 1, 0.08 }, grid = { 1, 1, 1, 0.06 },
    bar = { 0.92, 0.80, 0.55, 1 }, barHi = { 1, 0.92, 0.65, 1 },
    line1 = { 1, 0.88, 0.50, 1 }, line2 = { 0.75, 0.80, 0.90, 1 }, fill1 = { 1, 0.88, 0.50, 0.14 },
    good = { 0.45, 0.95, 0.45 }, bad = { 1, 0.5, 0.45 }, gold = { 1, 0.86, 0.3 },
    mini = { 0.05, 0.05, 0.06, 0.92 },
  },
  classic = {
    skin = true, bgAlpha = 0.94,
    card = { 0.09, 0.09, 0.11, 0.92 }, cardEdge = { 0.55, 0.55, 0.55, 0.9 }, cardHi = { 0.16, 0.20, 0.35, 0.92 },
    title = { 1, 0.82, 0 }, text = { 1, 1, 1 }, sub = { 0.70, 0.70, 0.70 }, label = { 1, 0.82, 0 },
    accent = { 0.25, 0.40, 0.90, 1 }, accentHi = { 0.50, 0.65, 1 },
    pillOn = { 0.20, 0.33, 0.75, 1 }, pillOff = { 0.14, 0.14, 0.16, 1 }, pillEdge = { 0.60, 0.60, 0.60, 0.9 },
    button = { 0.50, 0.08, 0.06, 1 }, buttonEdge = { 0.85, 0.70, 0.30, 1 }, buttonText = { 1, 0.82, 0 },
    track = { 0.10, 0.10, 0.12, 0.85 }, grid = { 1, 1, 1, 0.08 },
    bar = { 0.25, 0.40, 0.90, 1 }, barHi = { 0.45, 0.62, 1, 1 },
    line1 = { 1, 0.82, 0, 1 }, line2 = { 0.60, 0.75, 1, 1 }, fill1 = { 0.25, 0.40, 0.90, 0.22 },
    good = { 0.25, 1, 0.25 }, bad = { 1, 0.35, 0.35 }, gold = { 1, 0.82, 0 },
    mini = { 0.06, 0.06, 0.08, 0.96 },
  },
}
function PU.Mode()
  local Th = ns.Theme
  local m = Th and Th.Mode and Call(Th.Mode) or "flare"
  if not PU.THEMES[m] then m = "flare" end
  return m
end
function PU.Pal() return PU.THEMES[PU.Mode()] end
function PU.SegColors()
  local Wd = ns.Wide
  return (Wd and Wd.SEG_COLORS) or { { 0.616, 0.278, 0.227, 1 }, { 0.329, 0.408, 0.604, 1 }, { 0.310, 0.498, 0.243, 1 } }
end
PU.CAT_INDEX = { level = 1, combat = 2, prof = 3 }

------------------------------------------------------------------------------
-- Primitives
------------------------------------------------------------------------------
local function Paint(t, c, a)
  if not (t and c) then return end
  local alpha = a or c[4] or 1
  local ok = t.SetColorTexture and pcall(t.SetColorTexture, t, c[1], c[2], c[3], alpha)
  if not ok then
    pcall(t.SetTexture, t, PU.WHITE)
    if t.SetVertexColor then pcall(t.SetVertexColor, t, c[1], c[2], c[3], alpha) end
  end
  t._pc = c
end
PU.Paint = Paint
local function Tex(parent, layer, sub)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
  return t
end
local function TextColor(fs, c) if fs and c and fs.SetTextColor then fs:SetTextColor(c[1], c[2], c[3], 1) end end
local function FS(parent, font, role, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  if fs.SetJustifyH then fs:SetJustifyH(justify or "LEFT") end
  if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, false) end
  if role then PU.texts[#PU.texts + 1] = { fs, role } end
  fs._role = role
  return fs
end
local function Edge(owner, layer)
  local e = {}
  for i = 1, 4 do e[i] = owner:CreateTexture(nil, layer or "BORDER") end
  e[1]:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0) e[1]:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 0, 0) e[1]:SetHeight(1)
  e[2]:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 0, 0) e[2]:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, 0) e[2]:SetHeight(1)
  e[3]:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, -1) e[3]:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 0, 1) e[3]:SetWidth(1)
  e[4]:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 0, -1) e[4]:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, 1) e[4]:SetWidth(1)
  return e
end
local function PaintEdge(e, c) if e then for i = 1, 4 do Paint(e[i], c) end end end
local function ShowEdge(e, on) if e then for i = 1, 4 do if on then e[i]:Show() else e[i]:Hide() end end end end
local function Place(o, parent, x, y, w, h)
  o:ClearAllPoints()
  o:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
  if w and h then o:SetSize(w, h) end
end
local function Width(fs, fallback)
  local ok, w = pcall(fs.GetStringWidth, fs)
  w = ok and N(w) or nil
  return (w and w > 0) and w or (fallback or 40)
end
PU.Width = Width

-- Texte le plus long qui tient dans maxW (sans retour à la ligne, sans
-- déborder sur ce qui est à droite : pastilles, bord de carte…).
function PU.SetFittedText(fs, texts, maxW)
  if not fs then return nil end
  if type(texts) == "string" then texts = { texts } end
  maxW = N(maxW) or 0
  local chosen = texts[1] or ""
  if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, false) end
  if fs.SetMaxLines then pcall(fs.SetMaxLines, fs, 1) end
  if maxW > 0 then
    for i = 1, #texts do
      fs:SetText(texts[i] or "")
      if Width(fs, maxW + 1) <= maxW then chosen = texts[i] break end
      chosen = texts[i]
    end
  end
  fs:SetText(chosen or "")
  if maxW > 0 and fs.SetWidth then fs:SetWidth(maxW) end
  return chosen
end

function PU.Card(parent, x, y, w, h, title)
  local c = CreateFrame("Frame", nil, parent)
  Place(c, parent, x, y, w, h)
  c.bg = Tex(c, "BACKGROUND", 1)
  c.bg:SetAllPoints(c)
  c.edge = Edge(c)
  if title then
    c.title = FS(c, "GameFontNormalSmall", "label")
    c.title:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -6)
    c.title:SetText(title)
  end
  c._w, c._h = w, h
  PU.cards[#PU.cards + 1] = c
  return c
end
function PU.PaintCard(c, hi)
  local pal = PU.Pal()
  Paint(c.bg, hi and pal.cardHi or pal.card)
  PaintEdge(c.edge, hi and { pal.accentHi[1], pal.accentHi[2], pal.accentHi[3], 0.8 } or pal.cardEdge)
end

local function TipOn(o, title, line)
  o:SetScript("OnEnter", function(self)
    local tt = _G.GameTooltip
    if not tt then return end
    pcall(tt.SetOwner, tt, self, "ANCHOR_TOP")
    if tt.ClearLines then tt:ClearLines() end
    tt:AddLine(title, 1, 0.82, 0)
    if line then tt:AddLine(line, 1, 1, 1, true) end
    tt:Show()
  end)
  o:SetScript("OnLeave", function(self)
    local tt = _G.GameTooltip
    if tt and tt.Hide then tt:Hide() end
  end)
end
PU.TipOn = TipOn

function PU.Button(parent, w, h, label, kind, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  b.bg = Tex(b, "BACKGROUND", 1)
  b.bg:SetAllPoints(b)
  b.edge = Edge(b)
  b.hl = Tex(b, "HIGHLIGHT")
  b.hl:SetAllPoints(b)
  Paint(b.hl, { 1, 1, 1, 0.10 })
  b.fs = FS(b, (kind == "tab" or kind == "share") and "GameFontNormalSmall" or "GameFontHighlightSmall", nil, "CENTER")
  b.fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.fs:SetText(label or "")
  b.kind = kind or "small"
  if b.RegisterForClicks then pcall(b.RegisterForClicks, b, "LeftButtonUp") end
  b:SetScript("OnClick", function(self, button) if onClick then onClick(self, button) end end)
  PU.buttons[#PU.buttons + 1] = b
  return b
end
function PU.PaintButton(b)
  local pal = PU.Pal()
  local k = b.kind
  if k == "pill" or k == "tab" then
    Paint(b.bg, b.on and pal.pillOn or pal.pillOff)
    PaintEdge(b.edge, b.on and { pal.accentHi[1], pal.accentHi[2], pal.accentHi[3], 0.9 } or pal.pillEdge)
    TextColor(b.fs, b.on and ((k == "tab") and pal.title or { 1, 1, 1 }) or pal.sub)
  elseif k == "share" then
    Paint(b.bg, pal.button)
    PaintEdge(b.edge, pal.buttonEdge)
    TextColor(b.fs, pal.buttonText)
  else
    Paint(b.bg, pal.pillOff)
    PaintEdge(b.edge, pal.pillEdge)
    TextColor(b.fs, pal.text)
  end
end
function PU.SetOn(b, on) b.on = on and true or false PU.PaintButton(b) end

-- Pastilles (choix exclusif), posées de droite à gauche depuis `right`.
function PU.Pills(parent, defs, right, y, get, set)
  local group = { list = {}, get = get }
  local x = right
  for i = #defs, 1, -1 do
    local d = defs[i]
    local b = PU.Button(parent, 20, 14, Tr[d.label], "pill", function() set(d.id) end)
    local w = math.floor(Width(b.fs, 24) + 12 + 0.5)
    b:SetWidth(w)
    x = x - w
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    x = x - 3
    b.id = d.id
    group.list[#group.list + 1] = b
  end
  group.left = x
  PU.pillGroups[#PU.pillGroups + 1] = group
  return group
end
function PU.SyncPills()
  for _, g in ipairs(PU.pillGroups or {}) do
    local cur = g.get()
    for _, b in ipairs(g.list) do PU.SetOn(b, b.id == cur) end
  end
end

-- Barre simple (piste + remplissage)
function PU.NewBar(parent, x, y, w, h)
  local b = { track = Tex(parent, "ARTWORK", 1), fill = Tex(parent, "ARTWORK", 2), w = w, h = h }
  Place(b.track, parent, x, y, w, h)
  b.fill:ClearAllPoints()
  b.fill:SetPoint("TOPLEFT", b.track, "TOPLEFT", 0, 0)
  b.fill:SetSize(1, h)
  return b
end
function PU.SetBar(b, frac, color)
  local pal = PU.Pal()
  frac = math.max(0, math.min(1, N(frac) or 0))
  Paint(b.track, pal.track)
  Paint(b.fill, color or pal.bar)
  local w = math.floor(b.w * frac + 0.5)
  if w < 1 then b.fill:Hide() else b.fill:SetWidth(w) b.fill:Show() end
  b.frac = frac
end

------------------------------------------------------------------------------
-- Aides de données
------------------------------------------------------------------------------
function PU.DayShort(wd) return Tr[PU.DAY_SHORT[wd or 1] or "?"] end
function PU.DayInitial(wd)
  local s = PU.DayShort(wd)
  return s:sub(1, 1)
end
function PU.DayLong(day)
  local wd = P.Weekday(day)
  local d, m = tostring(day or ""):match("^%d%d%d%d%-(%d%d)%-(%d%d)$")
  if d then return PU.DayShort(wd) .. " " .. m .. "/" .. d end
  return tostring(day)
end
function PU.SkillCat(key)
  if key == "level" then return "level" end
  local e = ns.CatalogById and Call(ns.CatalogById, key)
  return e and P.Category(e.kind) or "prof"
end
function PU.SkillName(key, fallback)
  local n = P.SkillLabel and Call(P.SkillLabel, key)
  if n and n ~= tostring(key) then return n end
  return fallback or tostring(key)
end
-- Une entrée de graphique : label, sub (titre d'infobulle), total, level, combat, prof, xp, today, day.
function PU.DayItems(days, skillKey)
  local hist = P.History(days)
  local today = P.Today()
  local _, c = P.C()
  local items = {}
  for i, h in ipairs(hist) do
    local it = { day = h.day, total = h.pts or 0, level = h.level or 0, combat = h.combat or 0, prof = h.prof or 0,
      xp = h.xp or 0, today = (h.day == today) }
    if skillKey then
      local e = c.history[h.day]
      local v = type(e) == "table" and e.skills and N(e.skills[skillKey]) or 0
      it.total, it.level, it.combat, it.prof = v, 0, 0, 0
      it[PU.SkillCat(skillKey)] = v
      it.skill = skillKey
    end
    if days <= 7 then
      it.label = PU.DayShort(P.Weekday(h.day))
    else
      local dd = tonumber(tostring(h.day):sub(9, 10))
      it.label = ((i % 5 == 0) or it.today or i == 1) and tostring(dd or "") or ""
    end
    it.sub = PU.DayLong(h.day)
    items[#items + 1] = it
  end
  return items
end
function PU.SessionItems(n)
  local buckets = P.SessionBuckets(n or 8)
  local items = {}
  for i, b in ipairs(buckets) do
    local m1 = math.floor(b.t1 / 60 + 0.5)
    local m0 = math.floor(b.t0 / 60 + 0.5)
    items[i] = { label = string.format(Tr["%d min"], m1), sub = string.format(Tr["de %d à %d min"], m0, m1),
      total = b.pts, level = b.level, combat = b.combat, prof = b.prof, xp = b.xp, today = (i == #buckets), bucket = i }
  end
  return items
end
function PU.Items(period, skillKey)
  if period == "session" then return PU.SessionItems(8) end
  return PU.DayItems(period == "d30" and 30 or 7, skillKey)
end
-- Échelle « ronde » à 4 graduations.
function PU.NiceScale(v)
  v = N(v) or 0
  if v <= 0 then return 4, 1 end
  local raw = v / 4
  local mag = 10 ^ math.floor(math.log10 and math.log10(raw) or (math.log(raw) / math.log(10)))
  local step
  for _, k in ipairs({ 1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10 }) do
    if k * mag >= raw then step = k * mag break end
  end
  step = step or 10 * mag
  if step < 10 then step = math.max(1, math.ceil(step)) end
  return step * 4, step
end

------------------------------------------------------------------------------
-- Histogramme (barres empilées / total / XP) — pool fixe de barres
------------------------------------------------------------------------------
local function ItemValue(it, metric)
  if not it then return 0 end
  if metric == "xph" then return N(it.xp) or 0 end
  return N(it.total) or 0
end
PU.ItemValue = ItemValue

function PU.BarEnter(b)
  local it = b.item
  local tt = _G.GameTooltip
  if not (it and tt) then return end
  pcall(tt.SetOwner, tt, b, "ANCHOR_TOP")
  if tt.ClearLines then tt:ClearLines() end
  tt:AddLine(it.sub or it.label or "", 1, 0.82, 0)
  local seg = PU.SegColors()
  if it.skill then
    tt:AddDoubleLine(PU.SkillName(it.skill), "+" .. (N(it.total) or 0), 1, 1, 1, 1, 1, 1)
  else
    tt:AddDoubleLine(Tr["Points"], "+" .. (N(it.total) or 0), 1, 1, 1, 1, 1, 1)
    local names = { Tr["Niveau"], Tr["Armes & Déf."], Tr["Métiers"] }
    for i, k in ipairs({ "level", "combat", "prof" }) do
      local v = N(it[k]) or 0
      if v > 0 then tt:AddDoubleLine("  " .. names[i], "+" .. v, seg[i][1], seg[i][2], seg[i][3], 1, 1, 1) end
    end
    if (N(it.xp) or 0) > 0 then tt:AddDoubleLine(Tr["XP"], Thousands(it.xp), 1, 1, 1, 1, 1, 1) end
  end
  if b.chart and b.chart.onSelect then tt:AddLine(Tr["Clic : détail compétence par compétence"], 0.6, 0.6, 0.6) end
  tt:Show()
end
function PU.BarLeave(b)
  local tt = _G.GameTooltip
  if tt and tt.Hide then tt:Hide() end
end
function PU.BarClick(b)
  local c = b.chart
  if c and c.onSelect and b.item then c.onSelect(b.index, b.item) end
end

function PU.NewChart(parent, x, y, w, h, nMax)
  local c = CreateFrame("Frame", nil, parent)
  Place(c, parent, x, y, w, h)
  c.w, c.h = w, h
  c.axisW, c.top, c.bottom = 22, 12, 13
  c.grid, c.ylab = {}, {}
  for i = 1, 4 do
    c.grid[i] = Tex(c, "BACKGROUND", 2)
    c.ylab[i] = FS(c, "GameFontDisableSmall", "sub", "RIGHT")
  end
  c.base = Tex(c, "BACKGROUND", 3)
  c.bars = {}
  for i = 1, (nMax or PU.MAX_BARS) do
    local b = CreateFrame("Button", nil, c)
    b.sel = Tex(b, "BACKGROUND", 1)
    b.sel:SetAllPoints(b)
    b.seg = { Tex(b, "ARTWORK", 1), Tex(b, "ARTWORK", 1), Tex(b, "ARTWORK", 1) }
    b.one = Tex(b, "ARTWORK", 1)
    b.val = FS(c, "GameFontHighlightSmall", nil, "CENTER")
    b.lab = FS(c, "GameFontDisableSmall", nil, "CENTER")
    b.chart, b.index = c, i
    if b.RegisterForClicks then pcall(b.RegisterForClicks, b, "LeftButtonUp") end
    b:SetScript("OnEnter", PU.BarEnter)
    b:SetScript("OnLeave", PU.BarLeave)
    b:SetScript("OnClick", PU.BarClick)
    b:Hide() b.val:Hide() b.lab:Hide()
    c.bars[i] = b
  end
  c.empty = FS(c, "GameFontDisableSmall", "sub", "CENTER")
  c.empty:SetPoint("CENTER", c, "CENTER", 10, 0)
  c.empty:Hide()
  PU.charts[#PU.charts + 1] = c
  return c
end

function PU.RenderChart(c, items, metric, emptyText)
  local pal = PU.Pal()
  local seg = PU.SegColors()
  local n = math.min(#items, #c.bars)
  local plotW = c.w - c.axisW - 4
  local plotH = c.h - c.top - c.bottom
  local vmax = 0
  for i = 1, n do local v = ItemValue(items[i], metric) if v > vmax then vmax = v end end
  local top = PU.NiceScale(vmax)
  for k = 1, 4 do
    local y = c.bottom + math.floor(plotH * k / 4 + 0.5)
    local g = c.grid[k]
    g:ClearAllPoints()
    g:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", c.axisW + 2, y)
    g:SetSize(plotW + 2, 1)
    Paint(g, pal.grid)
    local l = c.ylab[k]
    l:ClearAllPoints()
    l:SetPoint("RIGHT", c, "BOTTOMLEFT", c.axisW - 2, y)
    l:SetText(metric == "xph" and Short(top * k / 4) or tostring(math.floor(top * k / 4 + 0.5)))
    TextColor(l, pal.sub)
  end
  c.base:ClearAllPoints()
  c.base:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", c.axisW + 2, c.bottom)
  c.base:SetSize(plotW + 2, 1)
  Paint(c.base, pal.cardEdge)
  local slot = plotW / math.max(1, n)
  local bw = math.max(3, math.min(26, math.floor(slot * 0.62)))
  local showVals = n <= 14
  for i, b in ipairs(c.bars) do
    local it = (i <= n) and items[i] or nil
    if not it then
      b:Hide() b.val:Hide() b.lab:Hide() b.item = nil
    else
      local x = c.axisW + 4 + (i - 1) * slot + (slot - bw) / 2
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", math.floor(x + 0.5), c.bottom)
      b:SetSize(bw, plotH)
      local v = ItemValue(it, metric)
      local hpx = (top > 0) and math.floor(plotH * v / top + 0.5) or 0
      if v > 0 and hpx < 1 then hpx = 1 end
      if metric == "cat" then
        b.one:Hide()
        local acc = 0
        for k, key in ipairs({ "level", "combat", "prof" }) do
          local t = b.seg[k]
          local hv = (top > 0) and math.floor(plotH * (N(it[key]) or 0) / top + 0.5) or 0
          if (N(it[key]) or 0) > 0 and hv < 1 then hv = 1 end
          t:ClearAllPoints()
          if hv > 0 then
            t:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, acc)
            t:SetSize(bw, hv)
            Paint(t, seg[k])
            t:Show()
            acc = acc + hv
          else t:Hide() end
        end
        hpx = math.max(hpx, acc)
      else
        for k = 1, 3 do b.seg[k]:Hide() end
        local t = b.one
        t:ClearAllPoints()
        if hpx > 0 then
          t:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
          t:SetSize(bw, hpx)
          Paint(t, it.today and pal.barHi or (metric == "xph" and pal.line1 or pal.bar))
          t:Show()
        else t:Hide() end
      end
      if c.selected == i then Paint(b.sel, { 1, 1, 1, 0.07 }) b.sel:Show() else b.sel:Hide() end
      b.val:ClearAllPoints()
      b.val:SetPoint("BOTTOM", b, "BOTTOMLEFT", bw / 2, hpx + 2)
      if v > 0 and (showVals or it.today) then
        b.val:SetText(metric == "xph" and Short(v) or ("+" .. v))
        TextColor(b.val, it.today and pal.title or pal.text)
        b.val:Show()
      else b.val:Hide() end
      b.lab:ClearAllPoints()
      b.lab:SetPoint("TOP", b, "BOTTOMLEFT", bw / 2, -2)
      b.lab:SetText(it.label or "")
      TextColor(b.lab, it.today and pal.title or pal.sub)
      b.lab:Show()
      b.item = it
      b:Show()
    end
  end
  if vmax <= 0 then
    c.empty:SetText(emptyText or Tr["Pas encore de points sur cette période."])
    TextColor(c.empty, pal.sub)
    c.empty:Show()
  else c.empty:Hide() end
  c.items, c.metric, c.vmax, c.top, c.n = items, metric, vmax, top, n
  return c
end

------------------------------------------------------------------------------
-- Courbe de session : micro-colonnes de 2 px (aucune ligne Retail)
------------------------------------------------------------------------------
function PU.NewCurve(parent, x, y, w, h)
  local c = CreateFrame("Frame", nil, parent)
  Place(c, parent, x, y, w, h)
  c.w, c.h = w, h
  c.plotL, c.plotB, c.plotT, c.plotR = 24, 12, 6, 8
  c.plotW = w - c.plotL - c.plotR
  c.plotH = h - c.plotB - c.plotT
  c.cols = math.min(PU.CURVE_COLS, math.floor(c.plotW / 2))
  c.fill, c.l1, c.l2 = {}, {}, {}
  for i = 1, c.cols do
    c.fill[i] = Tex(c, "ARTWORK", 1)
    c.l2[i] = Tex(c, "ARTWORK", 2)
    c.l1[i] = Tex(c, "ARTWORK", 3)
  end
  c.grid, c.ylab, c.xlab = {}, {}, {}
  for i = 1, 2 do c.grid[i] = Tex(c, "BACKGROUND", 2) c.ylab[i] = FS(c, "GameFontDisableSmall", "sub", "RIGHT") end
  for i = 1, 3 do c.xlab[i] = FS(c, "GameFontDisableSmall", "sub", "CENTER") end
  c.base = Tex(c, "BACKGROUND", 3)
  c.peak = Tex(c, "OVERLAY", 4)
  c.peakFS = FS(c, "GameFontHighlightSmall", nil, "CENTER")
  c.endDot = Tex(c, "OVERLAY", 4)
  c.empty = FS(c, "GameFontDisableSmall", "sub", "CENTER")
  c.empty:SetPoint("CENTER", c, "CENTER", 8, 0)
  PU.curves[#PU.curves + 1] = c
  return c
end
local function Interp(pts, key, t)
  local n = #pts
  if n == 0 then return 0 end
  if t <= pts[1].t then return N(pts[1][key]) or 0 end
  for i = 2, n do
    local a, b = pts[i - 1], pts[i]
    if t <= b.t then
      local span = b.t - a.t
      if span <= 0 then return N(b[key]) or 0 end
      local k = (t - a.t) / span
      return (N(a[key]) or 0) + ((N(b[key]) or 0) - (N(a[key]) or 0)) * k
    end
  end
  return N(pts[n][key]) or 0
end
PU.Interp = Interp
-- Points de la courbe : échantillons de la session + le point « maintenant ».
function PU.CurvePoints()
  local pts = {}
  for _, e in ipairs(P.Curve() or {}) do
    pts[#pts + 1] = { t = N(e.t) or 0, a = N(e.xph) or 0, b = N(e.pph) or 0 }
  end
  local r = P.Rates()
  if r and r.elapsed and (#pts == 0 or r.elapsed > pts[#pts].t) then
    pts[#pts + 1] = { t = r.elapsed, a = N(r.xph) or 0, b = N(r.pph) or 0, live = true }
  end
  return pts
end
function PU.RenderCurve(c, pts)
  local pal = PU.Pal()
  local enough = #pts >= 2 and (pts[#pts].t - pts[1].t) > 0
  local amax, bmax, peakI, peakV = 0, 0, nil, 0
  for _, p in ipairs(pts) do
    if p.a > amax then amax = p.a end
    if p.b > bmax then bmax = p.b end
  end
  if not enough or (amax <= 0 and bmax <= 0) then
    for i = 1, c.cols do c.fill[i]:Hide() c.l1[i]:Hide() c.l2[i]:Hide() end
    c.peak:Hide() c.peakFS:Hide() c.endDot:Hide()
    for i = 1, 3 do c.xlab[i]:Hide() end
    for i = 1, 2 do c.ylab[i]:Hide() c.grid[i]:Hide() end
    c.base:Hide()
    c.empty:SetText(Tr["La courbe apparaît après quelques minutes de jeu."])
    TextColor(c.empty, pal.sub)
    c.empty:Show()
    c.mode = "empty"
    return c
  end
  c.empty:Hide()
  -- sans XP (niveau max) : les points/h deviennent la courbe principale
  local mainKey, sideKey = "a", "b"
  if amax <= 0 then mainKey, sideKey = "b", nil end
  local topMain = PU.NiceScale(mainKey == "a" and amax or bmax)
  local topSide = sideKey and PU.NiceScale(bmax) or 1
  local t0, t1 = pts[1].t, pts[#pts].t
  local prev1, prev2
  for i = 1, c.cols do
    local t = t0 + (t1 - t0) * (i - 1) / math.max(1, c.cols - 1)
    local x = c.plotL + (i - 1) * 2
    local v1 = Interp(pts, mainKey, t)
    local y1 = math.floor(c.plotH * v1 / topMain + 0.5)
    if v1 > peakV then peakV, peakI = v1, i end
    local f = c.fill[i]
    f:ClearAllPoints()
    if y1 > 0 then
      f:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", x, c.plotB)
      f:SetSize(2, y1)
      Paint(f, pal.fill1)
      f:Show()
    else f:Hide() end
    local lo, hi = y1, y1
    if prev1 then lo, hi = math.min(prev1, y1), math.max(prev1, y1) end
    local l = c.l1[i]
    l:ClearAllPoints()
    l:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", x, c.plotB + math.max(0, lo - 1))
    l:SetSize(2, math.max(2, hi - lo + 2))
    Paint(l, pal.line1)
    l:Show()
    prev1 = y1
    local l2 = c.l2[i]
    if sideKey then
      local v2 = Interp(pts, sideKey, t)
      local y2 = math.floor(c.plotH * v2 / topSide + 0.5)
      local lo2, hi2 = y2, y2
      if prev2 then lo2, hi2 = math.min(prev2, y2), math.max(prev2, y2) end
      prev2 = y2
      -- trait discontinu (comme la maquette) : 2 colonnes sur 3
      if (i % 3) ~= 0 then
        l2:ClearAllPoints()
        l2:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", x, c.plotB + math.max(0, lo2 - 1))
        l2:SetSize(2, math.max(1, hi2 - lo2 + 1))
        Paint(l2, pal.line2)
        l2:Show()
      else l2:Hide() end
    else l2:Hide() end
  end
  for k = 1, 2 do
    local y = c.plotB + math.floor(c.plotH * k / 2 + 0.5)
    local g = c.grid[k]
    g:ClearAllPoints()
    g:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", c.plotL, y)
    g:SetSize(c.cols * 2, 1)
    Paint(g, pal.grid)
    g:Show()
    local lab = c.ylab[k]
    lab:ClearAllPoints()
    lab:SetPoint("RIGHT", c, "BOTTOMLEFT", c.plotL - 2, y)
    lab:SetText(Short(topMain * k / 2))
    TextColor(lab, pal.sub)
    lab:Show()
  end
  c.base:ClearAllPoints()
  c.base:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", c.plotL, c.plotB)
  c.base:SetSize(c.cols * 2, 1)
  Paint(c.base, pal.cardEdge)
  c.base:Show()
  local mins = { 0, (t1 - t0) / 2, t1 - t0 }
  local anchors = { 0, 0.5, 1 }
  local plotRight = c.plotL + c.cols * 2
  for k = 1, 3 do
    local lab = c.xlab[k]
    lab:ClearAllPoints()
    local x = c.plotL + math.floor((c.cols * 2 - 2) * anchors[k] + 0.5)
    if k == 1 then
      if lab.SetJustifyH then lab:SetJustifyH("LEFT") end
      lab:SetPoint("TOPLEFT", c, "BOTTOMLEFT", c.plotL, c.plotB - 1)
    elseif k == 3 then
      if lab.SetJustifyH then lab:SetJustifyH("RIGHT") end
      lab:SetPoint("TOPRIGHT", c, "BOTTOMLEFT", math.min(c.w - 2, plotRight), c.plotB - 1)
    else
      if lab.SetJustifyH then lab:SetJustifyH("CENTER") end
      lab:SetPoint("TOP", c, "BOTTOMLEFT", x, c.plotB - 1)
    end
    lab:SetText(string.format(Tr["%d min"], math.floor(mins[k] / 60 + 0.5)))
    TextColor(lab, pal.sub)
    lab:Show()
  end
  if peakI then
    local py = math.floor(c.plotH * peakV / topMain + 0.5)
    local px = c.plotL + (peakI - 1) * 2
    c.peak:ClearAllPoints()
    c.peak:SetPoint("CENTER", c, "BOTTOMLEFT", px + 1, c.plotB + py)
    c.peak:SetSize(5, 5)
    Paint(c.peak, pal.title)
    c.peak:Show()
    c.peakFS:ClearAllPoints()
    local lx = math.max(c.plotL + 40, math.min(c.plotL + c.cols * 2 - 40, px))
    c.peakFS:SetPoint("BOTTOM", c, "BOTTOMLEFT", lx, math.min(c.plotB + py + 3, c.h - 11))
    c.peakFS:SetText(Tr["pic "] .. Thousands(peakV) .. (mainKey == "a" and Tr[" XP/h"] or Tr[" pts/h"]))
    TextColor(c.peakFS, pal.text)
    c.peakFS:Show()
  end
  c.endDot:ClearAllPoints()
  c.endDot:SetPoint("CENTER", c, "BOTTOMLEFT", c.plotL + (c.cols - 1) * 2 + 1, c.plotB + (prev1 or 0))
  c.endDot:SetSize(4, 4)
  Paint(c.endDot, pal.title)
  c.endDot:Show()
  c.mode = (mainKey == "a") and "xp" or "pts"
  c.topMain, c.peakV = topMain, peakV
  return c
end

------------------------------------------------------------------------------
-- Construction (une seule fois, hors combat)
------------------------------------------------------------------------------
function PU.SetLogo(t)
  local ok, r = pcall(t.SetTexture, t, PU.LOGO)
  if not ok or r == false then pcall(t.SetTexture, t, PU.LOGO_FALLBACK) t._logo = PU.LOGO_FALLBACK return false end
  t._logo = PU.LOGO
  return true
end

function PU.BuildHeader(f)
  local logo = Tex(f, "ARTWORK", 2)
  Place(logo, f, 14, 12, 30, 30)
  PU.SetLogo(logo)
  f.logo = logo
  f.titleFS = FS(f, "GameFontNormalLarge", "title")
  f.titleFS:SetPoint("TOPLEFT", f, "TOPLEFT", 52, -14)
  f.titleFS:SetText("Dropamine · " .. Tr["Progression"])
  f.subFS = FS(f, "GameFontHighlightSmall", "sub")
  f.subFS:SetPoint("TOPLEFT", f, "TOPLEFT", 52, -33)
  f.close = PU.Button(f, 22, 20, "X", "close", function() PU.Close() end)
  f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -14)
  TipOn(f.close, Tr["Fermer"], Tr["Échap ferme aussi la fenêtre."])
  f.share = PU.Button(f, 88, 20, Tr["Partager"], "share", function() PU.ShareClick() end)
  f.share:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  TipOn(f.share, Tr["Partager"], Tr["Pose le récap de ta session dans la zone de saisie du chat : rien n'est envoyé tant que tu n'appuies pas sur Entrée."])
  f.divider = Tex(f, "ARTWORK", 1)
  f.divider:SetPoint("TOPLEFT", f, "TOPLEFT", PU.PAD, -50)
  f.divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PU.PAD, -50)
  f.divider:SetHeight(1)
end

function PU.BuildBanner(f)
  local b = PU.Card(f, PU.PAD, 56, PU.CONTENT_W, 62)
  f.banner = b
  b.flask = Tex(b, "ARTWORK", 2)
  Place(b.flask, b, 9, 7, 20, 20)
  PU.SetLogo(b.flask)
  b.totalFS = FS(b, "GameFontNormalLarge", "text")
  b.totalFS:SetPoint("TOPLEFT", b, "TOPLEFT", 34, -9)
  b.maxFS = FS(b, "GameFontHighlightSmall", "sub")
  b.maxFS:SetPoint("BOTTOMLEFT", b.totalFS, "BOTTOMRIGHT", 4, 1)
  b.pctFS = FS(b, "GameFontHighlightSmall", "sub", "RIGHT")
  b.pctFS:SetPoint("TOPRIGHT", b, "TOPRIGHT", -10, -12)
  b.barW = PU.CONTENT_W - 20
  b.track = Tex(b, "ARTWORK", 1)
  Place(b.track, b, 10, 31, b.barW, 8)
  b.segs = {}
  for i = 1, 3 do b.segs[i] = Tex(b, "ARTWORK", 2) end
  b.hit = CreateFrame("Frame", nil, b)
  Place(b.hit, b, 10, 28, b.barW, 14)
  if b.hit.EnableMouse then b.hit:EnableMouse(true) end
  b.hit:SetScript("OnEnter", function(self) if ns.Wide and ns.Wide.ShowBarTip then pcall(ns.Wide.ShowBarTip, self, true) end end)
  b.hit:SetScript("OnLeave", function() local tt = _G.GameTooltip if tt and tt.Hide then tt:Hide() end end)
  b.badges = {}
  local x = 10
  for i = 1, 3 do
    local g = CreateFrame("Frame", nil, b)
    g.bg = Tex(g, "BACKGROUND", 1) g.bg:SetAllPoints(g)
    g.edge = Edge(g)
    g.dot = Tex(g, "ARTWORK", 2)
    g.dot:SetPoint("LEFT", g, "LEFT", 5, 0)
    g.dot:SetSize(7, 7)
    g.fs = FS(g, "GameFontHighlightSmall", "text")
    g.fs:SetPoint("LEFT", g.dot, "RIGHT", 4, 0)
    Place(g, b, x, 44, 90, 14)
    x = x + 96
    b.badges[i] = g
  end
end

function PU.BuildTabs(f)
  f.tabs = {}
  local x = PU.PAD
  for _, t in ipairs(PU.TABS) do
    local id = t.id
    local btn = PU.Button(f, 60, 22, Tr[t.label], "tab", function() PU.SetTab(id) end)
    btn.id = id
    local w = math.floor(Width(btn.fs, 60) + 22 + 0.5)
    if id == "ach" then w = w + 30 end   -- place pour « (N/18) »
    btn:SetWidth(w)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", f, "TOPLEFT", x, -126)
    x = x + w + 6
    f.tabs[#f.tabs + 1] = btn
  end
end

local function Page(f, id)
  local p = CreateFrame("Frame", nil, f)
  Place(p, f, PU.PAD, PU.CONTENT_Y, PU.CONTENT_W, PU.CONTENT_H)
  p.id = id
  p:Hide()
  f.pages[id] = p
  return p
end

-- Onglet 1 : Vue d'ensemble -------------------------------------------------
function PU.BuildOverview(f)
  local p = Page(f, "overview")
  local kw = math.floor((PU.CONTENT_W - 24) / 4)
  p.kpi = {}
  local titles = { Tr["Rythme XP"], Tr["Rythme points"], Tr["Série & records"], Tr["Objectif session"] }
  for i = 1, 4 do
    local c = PU.Card(p, (i - 1) * (kw + 8), 0, kw, 58, titles[i])
    c.value = FS(c, "GameFontNormalLarge", "text")
    c.value:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -19)
    c.sub = FS(c, "GameFontHighlightSmall", "sub")
    c.sub:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -40)
    if c.sub.SetWidth then c.sub:SetWidth(kw - 16) end
    p.kpi[i] = c
  end
  -- objectif : barre + [+5] [+10] [Éditer] + saisie
  local g = p.kpi[4]
  g.sub:Hide()
  g.bar = PU.NewBar(g, 8, 37, kw - 16, 4)
  g.plus5 = PU.Button(g, 26, 13, "+5", "small", function() PU.BumpGoal(5) end)
  g.plus5:SetPoint("TOPLEFT", g, "TOPLEFT", 8, -43)
  g.plus10 = PU.Button(g, 30, 13, "+10", "small", function() PU.BumpGoal(10) end)
  g.plus10:SetPoint("LEFT", g.plus5, "RIGHT", 4, 0)
  g.edit = PU.Button(g, 44, 13, Tr["Éditer"], "small", function() PU.EditGoal() end)
  g.edit:SetPoint("LEFT", g.plus10, "RIGHT", 4, 0)
  TipOn(g.edit, Tr["Objectif session"], Tr["Saisis un nombre de points puis Entrée (Échap : annuler)."])
  local eb = CreateFrame("EditBox", nil, g)
  eb:SetSize(54, 18)
  eb:SetPoint("TOPLEFT", g, "TOPLEFT", 6, -17)
  if eb.SetAutoFocus then pcall(eb.SetAutoFocus, eb, false) end
  if eb.SetNumeric then pcall(eb.SetNumeric, eb, true) end
  if eb.SetMaxLetters then pcall(eb.SetMaxLetters, eb, 3) end
  if eb.SetFontObject then pcall(eb.SetFontObject, eb, _G.GameFontHighlight or "GameFontHighlight") end
  if eb.SetJustifyH then pcall(eb.SetJustifyH, eb, "CENTER") end
  eb.bg = Tex(eb, "BACKGROUND", 1) eb.bg:SetAllPoints(eb)
  eb.edge = Edge(eb)
  eb:SetScript("OnEnterPressed", function(self) PU.ApplyGoalEdit(self:GetText()) end)
  eb:SetScript("OnEscapePressed", function() PU.CancelGoalEdit() end)
  eb:SetScript("OnEditFocusLost", function() PU.CancelGoalEdit() end)
  eb:Hide()
  g.input = eb
  -- graphiques
  local gw, cw = 386, PU.CONTENT_W - 386 - 8
  local left = PU.Card(p, 0, 66, gw, 186, "")
  left.title:SetFontObject(_G.GameFontNormalSmall or "GameFontNormalSmall")
  p.left = left
  left.metric = PU.Pills(left, PU.METRICS, gw - 8, 6, function() return State().metric end, function(id) PU.SetMetric(id) end)
  left.period = PU.Pills(left, PU.PERIODS, left.metric.left - 6, 6, function() return State().period end, function(id) PU.SetPeriod(id) end)
  left.chart = PU.NewChart(left, 6, 24, gw - 12, 158, PU.MAX_BARS)
  local right = PU.Card(p, gw + 8, 66, cw, 186, Tr["Courbe de session (XP/h & pts/h)"])
  p.right = right
  right.k1 = Tex(right, "ARTWORK", 2) Place(right.k1, right, 10, 23, 10, 2)
  right.k1FS = FS(right, "GameFontDisableSmall", "sub") right.k1FS:SetPoint("LEFT", right.k1, "RIGHT", 3, 0) right.k1FS:SetText(Tr["XP/h"])
  right.k2 = Tex(right, "ARTWORK", 2) Place(right.k2, right, 60, 23, 10, 2)
  right.k2FS = FS(right, "GameFontDisableSmall", "sub") right.k2FS:SetPoint("LEFT", right.k2, "RIGHT", 3, 0) right.k2FS:SetText(Tr["pts/h"])
  right.curve = PU.NewCurve(right, 4, 28, cw - 8, 88)
  right.topTitle = FS(right, "GameFontNormalSmall", "label")
  right.topTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -124)
  right.topTitle:SetText(Tr["Top de la session"])
  right.top = {}
  for i = 1, 4 do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local e = {}
    e.dot = Tex(right, "ARTWORK", 2)
    Place(e.dot, right, 10 + col * math.floor((cw - 16) / 2), 142 + row * 18, 7, 7)
    e.fs = FS(right, "GameFontHighlightSmall", "text")
    e.fs:SetPoint("LEFT", e.dot, "RIGHT", 5, 0)
    e.n = FS(right, "GameFontNormalSmall", "title")
    e.n:SetPoint("LEFT", e.fs, "RIGHT", 4, 0)
    right.top[i] = e
  end
  right.topEmpty = FS(right, "GameFontDisableSmall", "sub")
  right.topEmpty:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -142)
  -- bandeau du bas
  local bw = math.floor((PU.CONTENT_W - 8) / 2)
  p.bottom = {}
  for i = 1, 2 do
    local c = PU.Card(p, (i - 1) * (bw + 8), 260, bw, 56)
    c.icon = Tex(c, "ARTWORK", 2)
    Place(c.icon, c, 10, 14, 28, 28)
    c.head = FS(c, "GameFontNormal", "title")
    c.head:SetPoint("TOPLEFT", c, "TOPLEFT", 46, -12)
    if c.head.SetWidth then c.head:SetWidth(bw - 54) end
    c.line = FS(c, "GameFontHighlightSmall", "text")
    c.line:SetPoint("TOPLEFT", c, "TOPLEFT", 46, -31)
    if c.line.SetWidth then c.line:SetWidth(bw - 54) end
    p.bottom[i] = c
  end
  PU.SetLogo(p.bottom[1].icon)
  pcall(p.bottom[2].icon.SetTexture, p.bottom[2].icon, "Interface\\Icons\\INV_Misc_Map_01")
  if p.bottom[2].icon.SetTexCoord then p.bottom[2].icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
end

-- Onglet 2 : Graphiques ------------------------------------------------------
function PU.BuildCharts(f)
  local p = Page(f, "charts")
  local c = PU.Card(p, 0, 0, PU.CONTENT_W, 214, "")
  p.card = c
  c.metric = PU.Pills(c, PU.METRICS, PU.CONTENT_W - 8, 6, function() return State().metric end, function(id) PU.SetMetric(id) end)
  c.period = PU.Pills(c, PU.PERIODS, c.metric.left - 6, 6, function() return State().period end, function(id) PU.SetPeriod(id) end)
  c.chart = PU.NewChart(c, 6, 24, PU.CONTENT_W - 12, 186, PU.MAX_BARS)
  c.chart.onSelect = function(i, it) PU.SelectBar(i, it) end
  local d = PU.Card(p, 0, 222, PU.CONTENT_W, 96, "")
  p.detail = d
  d.clear = PU.Button(d, 80, 14, Tr["Tout afficher"], "pill", function() PU.SetSkillFilter(nil) end)
  d.clear:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -5)
  d.rows = {}
  local cw = math.floor((PU.CONTENT_W - 24) / 2)
  for i = 1, 8 do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local r = CreateFrame("Button", nil, d)
    Place(r, d, 8 + col * (cw + 8), 24 + row * 17, cw, 16)
    r.hl = Tex(r, "HIGHLIGHT") r.hl:SetAllPoints(r) Paint(r.hl, { 1, 1, 1, 0.08 })
    r.sel = Tex(r, "BACKGROUND", 1) r.sel:SetAllPoints(r)
    r.dot = Tex(r, "ARTWORK", 2) r.dot:SetPoint("LEFT", r, "LEFT", 4, 0) r.dot:SetSize(7, 7)
    r.fs = FS(r, "GameFontHighlightSmall", "text") r.fs:SetPoint("LEFT", r.dot, "RIGHT", 5, 0)
    r.n = FS(r, "GameFontNormalSmall", "title", "RIGHT") r.n:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    if r.RegisterForClicks then pcall(r.RegisterForClicks, r, "LeftButtonUp") end
    r:SetScript("OnClick", function(self) if self.key then PU.SetSkillFilter(self.key) end end)
    r:Hide()
    d.rows[i] = r
  end
  d.empty = FS(d, "GameFontDisableSmall", "sub")
  d.empty:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -28)
end

-- Onglet 3 : Succès (liste défilante, 2 colonnes) ----------------------------
function PU.BuildAch(f)
  local p = Page(f, "ach")
  local sf = CreateFrame("ScrollFrame", nil, p)
  Place(sf, p, 0, 0, PU.CONTENT_W - 10, PU.CONTENT_H)
  if sf.SetClipsChildren then pcall(sf.SetClipsChildren, sf, true) end
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(PU.CONTENT_W - 10, 10)
  if sf.SetScrollChild then sf:SetScrollChild(child) end
  if sf.EnableMouseWheel then sf:EnableMouseWheel(true) end
  sf:SetScript("OnMouseWheel", function(_, delta) PU.ScrollAch(-(N(delta) or 0) * 40) end)
  p.scroll, p.child = sf, child
  p.thumbTrack = Tex(p, "ARTWORK", 1)
  Place(p.thumbTrack, p, PU.CONTENT_W - 5, 0, 3, PU.CONTENT_H)
  p.thumb = Tex(p, "ARTWORK", 2)
  p.cards = {}
  local n = (P and P.ACHIEVEMENTS and #P.ACHIEVEMENTS) or 18
  local cw = math.floor((PU.CONTENT_W - 10 - 8) / 2)
  for i = 1, n do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local c = PU.Card(child, col * (cw + 8), row * 58, cw, 52)
    c.icon = Tex(c, "ARTWORK", 2)
    Place(c.icon, c, 9, 10, 32, 32)
    PU.SetLogo(c.icon)
    c.name = FS(c, "GameFontNormal", nil)
    c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 48, -8)
    c.desc = FS(c, "GameFontHighlightSmall", nil)
    c.desc:SetPoint("TOPLEFT", c, "TOPLEFT", 48, -25)
    if c.desc.SetWidth then c.desc:SetWidth(cw - 56) end
    c.when = FS(c, "GameFontDisableSmall", nil, "RIGHT")
    c.when:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -9)
    c.bar = PU.NewBar(c, 48, 41, cw - 110, 4)
    c.prog = FS(c, "GameFontDisableSmall", nil, "RIGHT")
    c.prog:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -37)
    p.cards[i] = c
  end
  p.rows = math.ceil(n / 2)
  p.childH = p.rows * 58
  child:SetHeight(p.childH)
  p.scrollY = 0
end

-- Onglet 4 : Spots de farm ---------------------------------------------------
PU.SPOT_ROWS = 12
PU.SPOT_COLS = { 10, 290, 430, 530 }
function PU.BuildSpots(f)
  local p = Page(f, "spots")
  local c = PU.Card(p, 0, 0, PU.CONTENT_W, PU.CONTENT_H)
  p.card = c
  local heads = { Tr["Zone"], Tr["Métier"], Tr["Points"], Tr["Rythme (min/pt)"] }
  c.heads = {}
  for i, h in ipairs(heads) do
    local fs = FS(c, "GameFontNormalSmall", "label", (i >= 3) and "RIGHT" or "LEFT")
    if i >= 3 then fs:SetPoint("TOPRIGHT", c, "TOPLEFT", PU.SPOT_COLS[i] + 80, -10)
    else fs:SetPoint("TOPLEFT", c, "TOPLEFT", PU.SPOT_COLS[i], -10) end
    fs:SetText(h)
    c.heads[i] = fs
  end
  c.line = Tex(c, "ARTWORK", 1)
  Place(c.line, c, 8, 26, PU.CONTENT_W - 16, 1)
  c.rows = {}
  for i = 1, PU.SPOT_ROWS do
    local y = 30 + (i - 1) * 21
    local r = { bg = Tex(c, "BACKGROUND", 2) }
    Place(r.bg, c, 6, y, PU.CONTENT_W - 12, 20)
    r.zone = FS(c, "GameFontHighlightSmall", "text") r.zone:SetPoint("TOPLEFT", c, "TOPLEFT", PU.SPOT_COLS[1], -(y + 4))
    if r.zone.SetWidth then r.zone:SetWidth(270) end
    r.skill = FS(c, "GameFontHighlightSmall", "text") r.skill:SetPoint("TOPLEFT", c, "TOPLEFT", PU.SPOT_COLS[2], -(y + 4))
    r.pts = FS(c, "GameFontNormalSmall", "title", "RIGHT") r.pts:SetPoint("TOPRIGHT", c, "TOPLEFT", PU.SPOT_COLS[3] + 80, -(y + 4))
    r.rate = FS(c, "GameFontHighlightSmall", "text", "RIGHT") r.rate:SetPoint("TOPRIGHT", c, "TOPLEFT", PU.SPOT_COLS[4] + 80, -(y + 4))
    c.rows[i] = r
  end
  c.empty = FS(c, "GameFontHighlight", "sub", "CENTER")
  c.empty:SetPoint("CENTER", c, "CENTER", 0, 10)
  if c.empty.SetWidth then c.empty:SetWidth(PU.CONTENT_W - 80) end
  if c.empty.SetWordWrap then pcall(c.empty.SetWordWrap, c.empty, true) end
  c.note = FS(c, "GameFontDisableSmall", "sub")
  c.note:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 10, 8)
end

-- Onglet 5 : Récap hebdo -----------------------------------------------------
function PU.BuildWeekly(f)
  local p = Page(f, "weekly")
  local lw = 320
  local rw = PU.CONTENT_W - lw - 8
  local L = PU.Card(p, 0, 0, lw, PU.CONTENT_H, Tr["Cette semaine (lun. – dim.)"])
  p.L = L
  L.big = FS(L, "GameFontNormalHuge", "title")
  L.big:SetPoint("TOPLEFT", L, "TOPLEFT", 10, -24)
  L.lines = {}
  for i = 1, 5 do
    local fs = FS(L, "GameFontHighlightSmall", "text")
    fs:SetPoint("TOPLEFT", L, "TOPLEFT", 10, -(60 + (i - 1) * 18))
    if fs.SetWidth then fs:SetWidth(lw - 20) end
    L.lines[i] = fs
  end
  L.splitTitle = FS(L, "GameFontNormalSmall", "label")
  L.splitTitle:SetPoint("TOPLEFT", L, "TOPLEFT", 10, -158)
  L.splitTitle:SetText(Tr["Répartition"])
  L.splitW = lw - 20
  L.track = Tex(L, "ARTWORK", 1)
  Place(L.track, L, 10, 176, L.splitW, 8)
  L.segs = { Tex(L, "ARTWORK", 2), Tex(L, "ARTWORK", 2), Tex(L, "ARTWORK", 2) }
  L.legend = {}
  for i = 1, 3 do
    local e = { dot = Tex(L, "ARTWORK", 2) }
    Place(e.dot, L, 12, 194 + (i - 1) * 18, 7, 7)
    e.fs = FS(L, "GameFontHighlightSmall", "text")
    e.fs:SetPoint("LEFT", e.dot, "RIGHT", 5, 0)
    L.legend[i] = e
  end
  local R = PU.Card(p, lw + 8, 0, rw, PU.CONTENT_H, Tr["Jour par jour"])
  p.R = R
  R.chart = PU.NewChart(R, 4, 22, rw - 8, 150, 7)
  R.topTitle = FS(R, "GameFontNormalSmall", "label")
  R.topTitle:SetPoint("TOPLEFT", R, "TOPLEFT", 8, -184)
  R.topTitle:SetText(Tr["Top de la semaine"])
  R.top = {}
  for i = 1, 5 do
    local e = { dot = Tex(R, "ARTWORK", 2) }
    Place(e.dot, R, 10, 204 + (i - 1) * 18, 7, 7)
    e.fs = FS(R, "GameFontHighlightSmall", "text")
    e.fs:SetPoint("LEFT", e.dot, "RIGHT", 5, 0)
    e.n = FS(R, "GameFontNormalSmall", "title", "RIGHT")
    e.n:SetPoint("TOPRIGHT", R, "TOPLEFT", rw - 10, -(201 + (i - 1) * 18))
    R.top[i] = e
  end
  R.topEmpty = FS(R, "GameFontDisableSmall", "sub")
  R.topEmpty:SetPoint("TOPLEFT", R, "TOPLEFT", 10, -204)
end

function PU.Build()
  if PU.frame then return PU.frame end
  if InCombat() then return nil end
  if type(_G.CreateFrame) ~= "function" then return nil end
  PU.cards, PU.buttons, PU.texts, PU.pillGroups, PU.charts, PU.curves = {}, {}, {}, {}, {}, {}
  local f = CreateFrame("Frame", PU.NAME, _G.UIParent)
  f:SetSize(PU.W, PU.H)
  f:SetFrameStrata("HIGH")
  if f.SetToplevel then pcall(f.SetToplevel, f, true) end
  if f.SetMovable then f:SetMovable(true) end
  f:EnableMouse(true)
  if f.SetClampedToScreen then f:SetClampedToScreen(true) end
  if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
  f:SetScript("OnDragStart", function(self) pcall(self.StartMoving, self) self._moving = true end)
  f:SetScript("OnDragStop", function(self) pcall(self.StopMovingOrSizing, self) self._moving = nil PU.SavePos() end)
  f:Hide()
  f.flat = Tex(f, "BACKGROUND", -7)
  f.flat:SetAllPoints(f)
  f.edge = Edge(f, "BORDER")
  local Sk = ns.Skin
  if Sk and Sk.Host and Sk.enabled ~= false then
    local ok, h = pcall(Sk.Host, f)
    if ok and h then f.skin = h end
  end
  f.pages = {}
  PU.frame = f
  PU.BuildHeader(f)
  PU.BuildBanner(f)
  PU.BuildTabs(f)
  PU.BuildOverview(f)
  PU.BuildCharts(f)
  PU.BuildAch(f)
  PU.BuildSpots(f)
  PU.BuildWeekly(f)
  f.foot = FS(f, "GameFontDisableSmall", "sub", "CENTER")
  f.foot:SetPoint("BOTTOM", f, "BOTTOM", 0, 9)
  f.foot:SetText(Tr["Clic gauche sur la fiole ou /drop progression · Échap pour fermer"])
  f:SetScript("OnShow", function() PU.OnShow() end)
  f:SetScript("OnHide", function() PU.OnHide() end)
  -- Échap : NOTRE cadre ajouté à la liste (aucun cadre de Blizzard modifié)
  local sf = _G.UISpecialFrames
  if type(sf) == "table" then
    local found = false
    for _, n in ipairs(sf) do if n == PU.NAME then found = true end end
    if not found then table.insert(sf, PU.NAME) end
  end
  PU.ApplyTheme()
  PU.stats.builds = PU.stats.builds + 1
  return f
end

------------------------------------------------------------------------------
-- Thème
------------------------------------------------------------------------------
function PU.ApplyTheme()
  local f = PU.frame
  if not f then return nil end
  local mode = PU.Mode()
  local pal = PU.Pal()
  local Sk = ns.Skin
  if pal.skin and f.skin and Sk then
    pcall(f.skin.SetBackdrop, f.skin, Sk.Backdrop())
    pcall(Sk.Paint, f.skin, pal.bgAlpha)
    f.skin:Show()
    if f.skin.SetAlpha then f.skin:SetAlpha(1) end
    f.flat:Hide()
    ShowEdge(f.edge, false)
  else
    if f.skin then f.skin:Hide() end
    Paint(f.flat, pal.flat or { 0.06, 0.05, 0.05, 0.94 })
    f.flat:Show()
    PaintEdge(f.edge, pal.edge or pal.cardEdge)
    ShowEdge(f.edge, true)
  end
  Paint(f.divider, { pal.accent[1], pal.accent[2], pal.accent[3], 0.45 })
  for _, c in ipairs(PU.cards) do PU.PaintCard(c, c._hi) end
  for _, b in ipairs(PU.buttons) do PU.PaintButton(b) end
  for _, e in ipairs(PU.texts) do
    local c = pal[e[2]]
    if c then TextColor(e[1], c) end
  end
  local eb = f.pages.overview and f.pages.overview.kpi[4].input
  if eb then Paint(eb.bg, pal.track) PaintEdge(eb.edge, pal.accentHi) end
  local ach = f.pages.ach
  if ach then Paint(ach.thumbTrack, pal.track) Paint(ach.thumb, pal.accent) end
  local ov = f.pages.overview
  if ov then Paint(ov.right.k1, pal.line1) Paint(ov.right.k2, pal.line2) end
  local sp = f.pages.spots
  if sp then Paint(sp.card.line, pal.cardEdge) end
  for _, g in ipairs(f.banner.badges) do Paint(g.bg, pal.pillOff) PaintEdge(g.edge, pal.pillEdge) end
  PU.SyncPills()
  f._theme = mode
  PU.themeApplied = mode
  if PU.mini then PU.PaintMini() end
  if f:IsShown() then PU.Refresh() end
  return mode
end

------------------------------------------------------------------------------
-- Rafraîchissement
------------------------------------------------------------------------------
local function Snap() return ns.UI and ns.UI.snapshot end
function PU.Segments()
  local snap = Snap()
  if snap and snap.segments then return snap.segments end
  return (ns.ComputeTotalSegments and Call(ns.ComputeTotalSegments, snap and snap.tiles)) or {}
end
function PU.RefreshHeader()
  local f = PU.frame
  local name = Call(_G.UnitName, "player") or "?"
  local cls = Call(_G.UnitClass, "player") or ""
  local lvl = N(ns.GetPlayerLevel and Call(ns.GetPlayerLevel)) or N(Call(_G.UnitLevel, "player")) or 0
  f.subFS:SetText(string.format(Tr["%s · %s niv. %d"], tostring(name), tostring(cls), lvl))
  local snap = Snap()
  local cur = snap and (N(snap.total) or N(snap.ficTotal)) or N(ns.CharDB and ns.CharDB().lastTotal) or 0
  local mx = snap and (N(snap.totalMax) or N(snap.ficMax)) or N(ns.TOTAL_MAX) or 2460
  local b = f.banner
  b.totalFS:SetText(tostring(cur))
  b.maxFS:SetText("/ " .. tostring(mx))
  b.pctFS:SetText((mx > 0) and (string.format("%d %%", math.floor(cur / mx * 100 + 0.5))) or "")
  local pal = PU.Pal()
  Paint(b.track, pal.track)
  local segs = PU.Segments()
  local widths
  local Wd = ns.Wide
  if Wd and Wd.SegmentWidths then widths = Wd.SegmentWidths(segs, b.barW, cur, mx) end
  widths = widths or { 0, 0, 0 }
  local colors = PU.SegColors()
  local x = 10
  for i = 1, 3 do
    local t, w = b.segs[i], widths[i] or 0
    t:ClearAllPoints()
    if w > 0 then
      t:SetPoint("TOPLEFT", b, "TOPLEFT", x, -31)
      t:SetSize(w, 8)
      Paint(t, colors[i])
      t:Show()
      x = x + w
    else t:Hide() end
  end
  b.widths = widths
  local labels = { Tr["Niv."], Tr["Armes & Déf."], Tr["Métiers"] }
  local bx = 10
  for i = 1, 3 do
    local g = b.badges[i]
    local v = segs[i] and (N(segs[i].cur) or 0) or 0
    if i == 1 and v <= 0 then v = N(ns.GetPlayerLevel and Call(ns.GetPlayerLevel)) or 0 end
    g.fs:SetText(labels[i] .. " " .. tostring(v))
    Paint(g.dot, colors[i])
    local w = math.floor(Width(g.fs, 50) + 22 + 0.5)
    g:SetWidth(w)
    Place(g, b, bx, 44)
    g:SetSize(w, 14)
    bx = bx + w + 6
  end
  -- onglets : compteur de succès
  local got, all = P.UnlockedCount()
  for _, t in ipairs(f.tabs) do
    if t.id == "ach" then t.fs:SetText(Tr["Succès"] .. " (" .. got .. "/" .. all .. ")") end
    PU.SetOn(t, t.id == State().tab)
  end
end

function PU.RefreshOverview(p)
  local pal = PU.Pal()
  local r = P.Rates()
  local s = P.Session()
  local k = p.kpi
  -- 1. Rythme XP
  if r.xph and r.xph > 0 then
    k[1].value:SetText(Thousands(r.xph) .. Tr[" XP/h"])
    local lvl = N(ns.GetPlayerLevel and Call(ns.GetPlayerLevel)) or 0
    local parts = { Fmt2(r.lph or (r.xph and 0) or 0) .. Tr[" niv./h"] }
    if r.etaLevel then parts[#parts + 1] = string.format(Tr["niv. %d ≈ %s"], lvl + 1, Dur(r.etaLevel)) end
    k[1].sub:SetText(table.concat(parts, " · "))
  else
    k[1].value:SetText("—")
    k[1].sub:SetText((r.base or 0) < (P.MIN_RATE_SECS or 120) and Tr["mesure en cours…"] or Tr["pas d'XP cette session"])
  end
  -- 2. Rythme points
  k[2].value:SetText(r.pph and ("+" .. Fmt1(r.pph) .. Tr[" pts/h"]) or "—")
  k[2].sub:SetText(string.format(Tr["Session : +%d pts en %s"], s.pts or 0, Dur(r.elapsed)))
  -- 3. Série & records
  local st = P.Streak()
  local R = P.Records()
  k[3].value:SetText(string.format(st.n == 1 and Tr["%d jour d'affilée"] or Tr["%d jours d'affilée"], st.n))
  PU.SetFittedText(k[3].sub, {
    string.format(Tr["Max session +%d · Max heure +%d"], R.bestSession, R.bestHour),
    string.format(Tr["Sess. +%d · Heure +%d"], R.bestSession, R.bestHour),
  }, (k[3]._w or 0) - 16)
  -- 4. Objectif
  local g = P.Goal()
  k[4].value:SetText(string.format(Tr["+%d / +%d pts"], g.pts, g.target))
  TextColor(k[4].value, g.reached and pal.good or pal.text)
  PU.SetBar(k[4].bar, g.pct, g.reached and pal.barHi or pal.bar)
  -- histogramme
  local stt = State()
  local items = PU.Items(stt.period)
  local titleMax = ((p.left.period and p.left.period.left) or 80) - 12
  PU.SetFittedText(p.left.title, ({
    session = { Tr["Progression de la session"], Tr["Session"] },
    d7 = { Tr["Progression sur 7 jours"], Tr["7 jours"] },
    d30 = { Tr["Progression sur 30 jours"], Tr["30 jours"] },
  })[stt.period] or { "" }, titleMax)
  PU.RenderChart(p.left.chart, items, stt.metric, (stt.metric == "xph") and Tr["Pas encore d'XP mesurée sur cette période."] or nil)
  -- courbe
  PU.RenderCurve(p.right.curve, PU.CurvePoints())
  local top = P.TopSkills(4)
  local seg = PU.SegColors()
  for i, e in ipairs(p.right.top) do
    local t = top[i]
    if t then
      e.fs:SetText(PU.SkillName(t.key, t.name))
      e.n:SetText("+" .. t.n)
      Paint(e.dot, seg[PU.CAT_INDEX[PU.SkillCat(t.key)] or 3])
      e.dot:Show() e.fs:Show() e.n:Show()
    else e.dot:Hide() e.fs:Hide() e.n:Hide() end
  end
  if #top == 0 then p.right.topEmpty:SetText(Tr["Aucun point cette session pour l'instant."]) p.right.topEmpty:Show() else p.right.topEmpty:Hide() end
  -- bas : dernier succès, meilleur spot
  local got, all = P.UnlockedCount()
  local last = P.LastAchievement()
  local b1, b2 = p.bottom[1], p.bottom[2]
  if last then
    b1.head:SetText(Tr["Dernier succès"] .. " · " .. last.name)
    b1.line:SetText(last.desc .. " · " .. string.format(Tr["%d / %d débloqués"], got, all))
    if b1.icon.SetDesaturated then pcall(b1.icon.SetDesaturated, b1.icon, false) end
  else
    b1.head:SetText(Tr["Dernier succès"])
    b1.line:SetText(Tr["Aucun succès pour l'instant : le premier arrive vite !"] .. " · " .. string.format(Tr["%d / %d débloqués"], got, all))
    if b1.icon.SetDesaturated then pcall(b1.icon.SetDesaturated, b1.icon, true) end
  end
  local spot = P.BestSpot()
  if spot then
    b2.head:SetText(Tr["Meilleur spot actuel"] .. " · " .. spot.zone .. " (" .. PU.SkillName(spot.skill) .. ")")
    local parts = {}
    if spot.avg then parts[#parts + 1] = "≈ " .. Fmt1(spot.avg) .. Tr[" min/rang"] end
    parts[#parts + 1] = string.format(Tr["+%d pts mesurés"], spot.pts)
    b2.line:SetText(table.concat(parts, " · "))
  else
    b2.head:SetText(Tr["Meilleur spot actuel"])
    b2.line:SetText(Tr["Aucun coin de récolte mesuré pour l'instant."])
  end
end

function PU.RefreshCharts(p)
  local stt = State()
  local c = p.card
  local skill = stt.period ~= "session" and PU.skillFilter or nil
  local items = PU.Items(stt.period, skill)
  local metric = skill and "total" or stt.metric
  local titles = { session = Tr["Progression de la session"], d7 = Tr["Progression sur 7 jours"], d30 = Tr["Progression sur 30 jours"] }
  if skill then c.title:SetText(string.format(Tr["%s — points par jour"], PU.SkillName(skill)))
  else c.title:SetText(titles[stt.period] or "") end
  if not c.chart.selected or c.chart.selected > #items then c.chart.selected = #items end
  PU.RenderChart(c.chart, items, metric)
  -- détail : compétence par compétence
  local d = p.detail
  local pal = PU.Pal()
  local sel = items[c.chart.selected]
  local list = {}
  if stt.period == "session" then
    for _, t in ipairs(P.TopSkills(8)) do list[#list + 1] = { key = t.key, n = t.n, name = t.name } end
    d.title:SetText(Tr["Détail de la session"])
  else
    local day = sel and sel.day or P.Today()
    for _, e in ipairs(P.DayBreakdown(day).skills) do list[#list + 1] = { key = e.key, n = e.n } end
    d.title:SetText(Tr["Détail : "] .. PU.DayLong(day))
  end
  local seg = PU.SegColors()
  for i, r in ipairs(d.rows) do
    local e = list[i]
    if e and (N(e.n) or 0) > 0 then
      r.key = e.key
      r.fs:SetText(PU.SkillName(e.key, e.name))
      r.n:SetText("+" .. e.n)
      Paint(r.dot, seg[PU.CAT_INDEX[PU.SkillCat(e.key)] or 3])
      if PU.skillFilter == e.key then Paint(r.sel, pal.cardHi) r.sel:Show() else r.sel:Hide() end
      r:Show()
    else r.key = nil r:Hide() end
  end
  if #list == 0 then d.empty:SetText(Tr["Rien à détailler : aucun point ce jour-là."]) d.empty:Show() else d.empty:Hide() end
  if PU.skillFilter then d.clear:Show() else d.clear:Hide() end
end

function PU.FormatWhen(at)
  at = N(at)
  if not at then return "" end
  local fn = (type(_G.date) == "function" and _G.date) or (type(os) == "table" and os.date) or nil
  local v = fn and Call(fn, "%d/%m/%Y", at)
  return v and (Tr["le "] .. v) or ""
end
function PU.RefreshAch(p)
  local pal = PU.Pal()
  local list = P.Achievements()
  for i, c in ipairs(p.cards) do
    local a = list[i]
    if a then
      c._hi = a.unlocked
      PU.PaintCard(c, a.unlocked)
      c.name:SetText(a.name)
      c.desc:SetText(a.desc)
      TextColor(c.name, a.unlocked and pal.title or pal.sub)
      TextColor(c.desc, a.unlocked and pal.text or pal.sub)
      if c.icon.SetDesaturated then pcall(c.icon.SetDesaturated, c.icon, not a.unlocked) end
      c.icon:SetAlpha(a.unlocked and 1 or 0.35)
      if a.unlocked then
        c.when:SetText(PU.FormatWhen(a.at))
        TextColor(c.when, pal.gold)
        c.when:Show()
        c.bar.track:Hide() c.bar.fill:Hide() c.prog:Hide()
      else
        c.when:Hide()
        local cur, target = N(a.cur) or 0, N(a.target)
        if target and target > 0 then
          PU.SetBar(c.bar, cur / target, pal.accent)
          c.bar.track:Show()
          c.prog:SetText(cur .. " / " .. target)
          TextColor(c.prog, pal.sub)
          c.prog:Show()
        else c.bar.track:Hide() c.bar.fill:Hide() c.prog:Hide() end
      end
      c:Show()
    else c:Hide() end
  end
  PU.ScrollAch(0)
end
function PU.ScrollAch(delta)
  local p = PU.frame and PU.frame.pages.ach
  if not p then return 0 end
  local maxY = math.max(0, p.childH - PU.CONTENT_H)
  p.scrollY = math.max(0, math.min(maxY, (p.scrollY or 0) + (N(delta) or 0)))
  if p.scroll.SetVerticalScroll then pcall(p.scroll.SetVerticalScroll, p.scroll, p.scrollY) end
  local th = math.max(20, math.floor(PU.CONTENT_H * PU.CONTENT_H / math.max(PU.CONTENT_H, p.childH)))
  local ty = (maxY > 0) and math.floor((PU.CONTENT_H - th) * p.scrollY / maxY) or 0
  Place(p.thumb, p, PU.CONTENT_W - 5, ty, 3, th)
  if maxY > 0 then p.thumb:Show() p.thumbTrack:Show() else p.thumb:Hide() p.thumbTrack:Hide() end
  return p.scrollY
end

function PU.RefreshSpots(p)
  local c = p.card
  local pal = PU.Pal()
  local list = P.AllSpots()
  for i, r in ipairs(c.rows) do
    local z = list[i]
    if z then
      r.zone:SetText(z.zone .. ((z.sub and z.sub ~= z.zone) and (" · " .. z.sub) or ""))
      r.skill:SetText(PU.SkillName(z.skill))
      r.pts:SetText("+" .. z.pts)
      r.rate:SetText(z.avg and (Fmt1(z.avg)) or "—")
      Paint(r.bg, (i % 2 == 1) and { 1, 1, 1, 0.035 } or { 0, 0, 0, 0 })
      if i == 1 and z.avg then Paint(r.bg, pal.cardHi) end
      r.bg:Show() r.zone:Show() r.skill:Show() r.pts:Show() r.rate:Show()
    else
      r.bg:Hide() r.zone:Hide() r.skill:Hide() r.pts:Hide() r.rate:Hide()
    end
  end
  for _, h in ipairs(c.heads) do if #list > 0 then h:Show() else h:Hide() end end
  if #list == 0 then
    c.empty:SetText(Tr["Aucun gain de récolte enregistré pour l'instant.\nHerboristerie, Minage, Dépeçage et Pêche sont mesurés par zone dès le premier point."])
    c.empty:Show()
    c.line:Hide()
  else c.empty:Hide() c.line:Show() end
  local more = #list - #c.rows
  c.note:SetText(Tr["Trié du rythme le plus rapide au plus lent (au moins 3 points mesurés)."] .. ((more > 0) and (" " .. string.format(Tr["+%d autres zones."], more)) or ""))
  c.count = #list
end

function PU.RefreshWeekly(p)
  local pal = PU.Pal()
  local cur, prev = P.WeeklyRecap(0), P.WeeklyRecap(1)
  local L, R = p.L, p.R
  L.big:SetText("+" .. cur.pts .. Tr[" pts"])
  local diff = cur.pts - prev.pts
  local pct = (prev.pts > 0) and math.floor(diff / prev.pts * 100 + 0.5) or nil
  local cmp = string.format(Tr["vs semaine dernière : %s%d"], diff >= 0 and "+" or "", diff) .. (pct and string.format(" (%s%d %%)", pct >= 0 and "+" or "", pct) or "")
  L.lines[1]:SetText(cmp)
  TextColor(L.lines[1], diff >= 0 and pal.good or pal.bad)
  L.lines[2]:SetText(string.format(Tr["Semaine dernière : +%d pts en %d jour(s)"], prev.pts, prev.activeDays))
  L.lines[3]:SetText(string.format(Tr["%d jour(s) actif(s) sur 7"], cur.activeDays))
  L.lines[4]:SetText(cur.best and string.format(Tr["Meilleur jour : %s +%d"], PU.DayLong(cur.best.day), cur.best.pts) or Tr["Meilleur jour : —"])
  local st = P.Streak()
  L.lines[5]:SetText(string.format(Tr["Série : %d j (record %d)"], st.n, st.best))
  local seg = PU.SegColors()
  local tot = (cur.cat.level or 0) + (cur.cat.combat or 0) + (cur.cat.prof or 0)
  Paint(L.track, pal.track)
  local x = 10
  local names = { Tr["Niveau"], Tr["Armes & Déf."], Tr["Métiers"] }
  for i, key in ipairs({ "level", "combat", "prof" }) do
    local v = N(cur.cat[key]) or 0
    local w = (tot > 0) and math.floor(L.splitW * v / tot + 0.5) or 0
    if i == 3 and tot > 0 then w = math.max(0, L.splitW - (x - 10)) end
    if v <= 0 then w = 0 end
    local t = L.segs[i]
    t:ClearAllPoints()
    if w > 0 then
      t:SetPoint("TOPLEFT", L, "TOPLEFT", x, -176)
      t:SetSize(w, 8)
      Paint(t, seg[i])
      t:Show()
      x = x + w
    else t:Hide() end
    local e = L.legend[i]
    Paint(e.dot, seg[i])
    e.fs:SetText(string.format("%s : +%d", names[i], v) .. ((tot > 0) and string.format(" (%d %%)", math.floor(v / tot * 100 + 0.5)) or ""))
  end
  -- jour par jour (lun. → dim. de la semaine en cours)
  local items = {}
  local today = P.Today()
  for i, d in ipairs(cur.days) do
    local _, c = P.C()
    local h = c.history[d.day]
    local cat = type(h) == "table" and h.cat or {}
    items[i] = { day = d.day, label = PU.DayShort(i), sub = PU.DayLong(d.day), total = d.pts,
      level = N(cat.level) or 0, combat = N(cat.combat) or 0, prof = N(cat.prof) or 0, xp = type(h) == "table" and N(h.xp) or 0,
      today = d.day == today }
  end
  PU.RenderChart(R.chart, items, "cat")
  for i, e in ipairs(R.top) do
    local t = cur.skills[i]
    if t then
      e.fs:SetText(PU.SkillName(t.key))
      e.n:SetText("+" .. t.n)
      Paint(e.dot, seg[PU.CAT_INDEX[PU.SkillCat(t.key)] or 3])
      e.dot:Show() e.fs:Show() e.n:Show()
    else e.dot:Hide() e.fs:Hide() e.n:Hide() end
  end
  if #cur.skills == 0 then R.topEmpty:SetText(Tr["Rien encore cette semaine."]) R.topEmpty:Show() else R.topEmpty:Hide() end
end

PU.REFRESHERS = { overview = "RefreshOverview", charts = "RefreshCharts", ach = "RefreshAch", spots = "RefreshSpots", weekly = "RefreshWeekly" }
function PU.Refresh()
  local f = PU.frame
  if not (f and f:IsShown()) then return false end
  PU.stats.refreshes = PU.stats.refreshes + 1
  local ok, err = pcall(PU.RefreshHeader)
  if not ok then PU.lastError = err PU.stats.errors = PU.stats.errors + 1 end
  local tab = State().tab
  for id, page in pairs(f.pages) do if id == tab then page:Show() else page:Hide() end end
  local fn = PU[PU.REFRESHERS[tab]]
  if fn then
    local ok2, err2 = pcall(fn, f.pages[tab])
    if not ok2 then PU.lastError = err2 PU.stats.errors = PU.stats.errors + 1 end
  end
  PU.SyncPills()
  return true
end
-- Regroupé : un seul rafraîchissement par fenêtre de 0,5 s (2 s en combat).
function PU.RequestRefresh()
  if not PU.IsShown() then return false end
  PU.stats.requests = PU.stats.requests + 1
  if PU._pending then return false end
  PU._pending = true
  local wait = InCombat() and PU.REFRESH_WAIT.combat or PU.REFRESH_WAIT.idle
  local function go() PU._pending = nil PU.Refresh() end
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then _G.C_Timer.After(wait, go) else go() end
  return true
end

------------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------------
function PU.SetTab(id, quiet)
  local s = State()
  if not PU.REFRESHERS[id] then return s.tab end
  s.tab = id
  if not quiet then PU.Refresh() end
  return id
end
function PU.SetPeriod(id) State().period = id if PU.frame and PU.frame.pages.charts then PU.frame.pages.charts.card.chart.selected = nil end PU.Refresh() return id end
function PU.SetMetric(id) State().metric = id PU.Refresh() return id end
function PU.SelectBar(i, it)
  local c = PU.frame.pages.charts.card.chart
  c.selected = i
  PU.Refresh()
  return it
end
function PU.SetSkillFilter(key)
  if key and PU.skillFilter == key then key = nil end
  PU.skillFilter = key
  if key and State().period == "session" then State().period = "d7" end
  PU.Refresh()
  return key
end
function PU.BumpGoal(d)
  local n = P.BumpGoal(d)
  PU.SyncOptions()
  PU.Refresh()
  return n
end
function PU.EditGoal()
  local g = PU.frame and PU.frame.pages.overview.kpi[4]
  if not g then return end
  local eb = g.input
  eb:SetText(tostring(P.GoalTarget()))
  g.value:Hide()
  eb:Show()
  if eb.SetFocus then pcall(eb.SetFocus, eb) end
  if eb.HighlightText then pcall(eb.HighlightText, eb) end
  PU.editing = true
end
function PU.ApplyGoalEdit(text)
  local n = N(text)
  local g = PU.frame and PU.frame.pages.overview.kpi[4]
  if n and n > 0 then P.SetGoal(n) PU.SyncOptions() end
  PU.editing = nil
  if g then
    if g.input.ClearFocus then pcall(g.input.ClearFocus, g.input) end
    g.input:Hide() g.value:Show()
  end
  PU.Refresh()
  return P.GoalTarget()
end
function PU.CancelGoalEdit()
  if not PU.editing then return end
  PU.editing = nil
  local g = PU.frame and PU.frame.pages.overview.kpi[4]
  if g then g.input:Hide() g.value:Show() end
end
function PU.SyncOptions()
  local O = ns.Options
  if O and O.panel and O.panel.IsShown and O.panel:IsShown() and O.Sync then pcall(O.Sync) end
end
-- « Partager » : texte posé dans la zone de saisie (jamais envoyé seul).
function PU.ShareClick()
  PU.shares = (PU.shares or 0) + 1
  return P.Share(nil)
end

------------------------------------------------------------------------------
-- Ouverture / fermeture / position
------------------------------------------------------------------------------
function PU.IsShown() return (PU.frame and PU.frame:IsShown()) and true or false end
function PU.SavePos()
  local f = PU.frame
  if not f then return end
  local ok, point, _, rel, x, y = pcall(f.GetPoint, f, 1)
  if not ok or not point then return end
  local _, ui = UIDB()
  ui.progressPos = { point = point, relativePoint = rel or point, x = N(x) or 0, y = N(y) or 0 }
end
function PU.Place()
  local f = PU.frame
  local _, ui = UIDB()
  local p = ui.progressPos
  local SO = ns.SafeOpen
  f:ClearAllPoints()
  if type(p) == "table" and N(p.x) and N(p.y) and not (SO and SO.SavedPosOk and not SO.SavedPosOk(f, p)) then
    if pcall(f.SetPoint, f, p.point or "CENTER", _G.UIParent, p.relativePoint or p.point or "CENTER", p.x, p.y) then
      PU.posSource = "saved"
      return "saved"
    end
    f:ClearAllPoints()
  end
  if type(p) == "table" then ui.progressPos = nil end
  f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 40)
  PU.posSource = "center"
  return "center"
end
function PU.Open(tab)
  if not PU.frame then
    if InCombat() then
      -- jamais de cadre créé en combat : ouverture à la fin du combat
      PU.stats.deferred = PU.stats.deferred + 1
      PU.pendingOpen = tab or true
      if ns.AfterCombat then ns.AfterCombat("progressui-open", function() local t = PU.pendingOpen PU.pendingOpen = nil PU.Open(t ~= true and t or nil) end) end
      Say(Tr["fenêtre Progression : elle s'ouvrira à la fin du combat."])
      return false
    end
    if not PU.Build() then return false end
  end
  if tab then PU.SetTab(tab, true) end
  if not PU.frame:IsShown() then PU.Place() end
  PU.stats.opens = PU.stats.opens + 1
  PU.frame:Show()
  PU.Refresh()
  return true
end
function PU.Close()
  if PU.frame and PU.frame:IsShown() then PU.frame:Hide() end
  return false
end
function PU.Toggle(tab)
  if PU.IsShown() and (not tab or tab == State().tab) then return PU.Close() end
  return PU.Open(tab)
end
function PU.OnShow()
  PU.HideMini()
  PU.Refresh()
end
function PU.OnHide()
  PU.CancelGoalEdit()
  PU._pending = nil
  if PU.frame and PU.frame._moving then pcall(PU.frame.StopMovingOrSizing, PU.frame) PU.frame._moving = nil PU.SavePos() end
end

-- Clic sur la fiole / la barre du total / le bandeau (View, Wide, UI) :
-- renvoie true si le clic a ouvert ou fermé la fenêtre.
function PU.OnTotalClick(src, button)
  if button == "RightButton" then return false end
  if src and src._thDragged then src._thDragged = nil return false end   -- c'était un glisser
  PU.Toggle()
  return true
end

------------------------------------------------------------------------------
-- Mini-graphe 7 jours accroché à l'infobulle du total
------------------------------------------------------------------------------
PU.MINI_H = 64
function PU.BuildMini()
  if PU.mini then return PU.mini end
  if InCombat() or type(_G.CreateFrame) ~= "function" then return nil end
  local m = CreateFrame("Frame", nil, _G.UIParent)
  m:SetFrameStrata("TOOLTIP")
  m:SetSize(180, PU.MINI_H)
  if m.EnableMouse then m:EnableMouse(false) end
  m.bg = m:CreateTexture(nil, "BACKGROUND", nil, 1)
  m.bg:SetAllPoints(m)
  m.edge = Edge(m)
  m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  m.title:SetPoint("TOPLEFT", m, "TOPLEFT", 8, -6)
  m.sum = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  m.sum:SetPoint("TOPRIGHT", m, "TOPRIGHT", -8, -6)
  m.bars, m.vals, m.days = {}, {}, {}
  for i = 1, 7 do
    m.bars[i] = m:CreateTexture(nil, "ARTWORK", nil, 2)
    m.vals[i] = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    m.days[i] = m:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  end
  m.base = m:CreateTexture(nil, "ARTWORK", nil, 1)
  m:Hide()
  m:SetScript("OnUpdate", PU.MiniWatch)
  PU.mini = m
  PU.PaintMini()
  return m
end
function PU.PaintMini()
  local m = PU.mini
  if not m then return end
  local pal = PU.Pal()
  Paint(m.bg, pal.mini)
  PaintEdge(m.edge, pal.skin and pal.cardEdge or (pal.edge or pal.cardEdge))
  TextColor(m.title, pal.title)
  TextColor(m.sum, pal.text)
end
-- garde-fou : l'infobulle a disparu ou changé de propriétaire → on se cache
function PU.MiniWatch(m, elapsed)
  m._acc = (m._acc or 0) + (N(elapsed) or 0)
  if m._acc < 0.1 then return end
  m._acc = 0
  local tt = _G.GameTooltip
  local gone = not (tt and tt.IsShown and tt:IsShown())
  if not gone and tt.GetOwner and m.owner then
    local ok, o = pcall(tt.GetOwner, tt)
    if ok and o ~= m.owner then gone = true end
  end
  if gone then PU.HideMini() end
end
function PU.ShowMini(tt, owner)
  tt = tt or _G.GameTooltip
  if type(tt) ~= "table" or not P then return nil end
  local m = PU.mini or PU.BuildMini()
  if not m then return nil end
  local pal = PU.Pal()
  local items = PU.DayItems(7)
  local w = math.max(180, math.floor(N(tt.GetWidth and tt:GetWidth()) or 180))
  m:SetWidth(w)
  local vmax, sum = 0, 0
  for _, it in ipairs(items) do
    if it.total > vmax then vmax = it.total end
    sum = sum + it.total
  end
  m.title:SetText(Tr["7 derniers jours"])
  m.sum:SetText("+" .. sum .. Tr[" pts"])
  local plotH, bottom = 20, 13
  local slot = (w - 16) / 7
  local bw = math.max(4, math.min(14, math.floor(slot * 0.55)))
  m.base:ClearAllPoints()
  m.base:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", 8, bottom)
  m.base:SetSize(w - 16, 1)
  Paint(m.base, pal.cardEdge)
  for i = 1, 7 do
    local it = items[i]
    local x = 8 + (i - 1) * slot + (slot - bw) / 2
    local h = (vmax > 0) and math.floor(plotH * it.total / vmax + 0.5) or 0
    if it.total > 0 and h < 2 then h = 2 end
    local t = m.bars[i]
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", math.floor(x + 0.5), bottom + 1)
    t:SetSize(bw, math.max(1, h))
    Paint(t, it.today and pal.barHi or pal.bar, (h > 0) and 1 or 0.25)
    t:Show()
    local v = m.vals[i]
    v:ClearAllPoints()
    v:SetPoint("BOTTOM", t, "TOP", 0, 1)
    v:SetText(it.total > 0 and tostring(it.total) or "")
    TextColor(v, it.today and pal.title or pal.text)
    local d = m.days[i]
    d:ClearAllPoints()
    d:SetPoint("TOP", t, "BOTTOM", 0, -2)
    d:SetText(PU.DayInitial(P.Weekday(it.day)))
    TextColor(d, it.today and pal.title or pal.sub)
  end
  m:ClearAllPoints()
  local bottomY = N(tt.GetBottom and Call(tt.GetBottom, tt))
  if bottomY and bottomY < PU.MINI_H + 8 then
    m:SetPoint("BOTTOMLEFT", tt, "TOPLEFT", 0, 1)
    m.side = "above"
  else
    m:SetPoint("TOPLEFT", tt, "BOTTOMLEFT", 0, -1)
    m.side = "below"
  end
  m.owner = owner
  m.items, m.sumPts = items, sum
  PU.PaintMini()
  m._acc = 0
  m:Show()
  PU.stats.mini = PU.stats.mini + 1
  return m
end
function PU.HideMini()
  local m = PU.mini
  if m and m:IsShown() then
    m:Hide()
    PU.stats.miniHidden = PU.stats.miniHidden + 1
  end
  if m then m.owner = nil end
end

------------------------------------------------------------------------------
-- Branchements : données, thème, réglages, commandes
------------------------------------------------------------------------------
if P and P.Listen then P.Listen("progressui", function() PU.RequestRefresh() end) end
do
  local Th = ns.Theme
  if Th then
    local prev = Th.OnModeChanged
    function Th.OnModeChanged(m, ...)
      if prev then pcall(prev, m, ...) end
      -- Th.Set a déjà enregistré le mode et ClassicTheme a échangé ses textures
      if PU.frame then pcall(PU.ApplyTheme) end
      if PU.mini then pcall(PU.PaintMini) end
    end
  end
end
-- Réglages 2.0 : bouton « Ouvrir la fenêtre » sur l'en-tête de la section Progression
do
  local O = ns.Options
  if O and O.Build then
    local baseBuild = O.Build
    function O.Build(...)
      local r = { baseBuild(...) }
      pcall(PU.AddOptionsButton)
      return unpack(r)
    end
  end
end
function PU.AddOptionsButton()
  local O = ns.Options
  local rst = O and O.sectionResets and O.sectionResets.progress
  if not rst then return nil end
  if PU.optButton and PU.optButton._rst == rst then return PU.optButton end
  local parent = rst.GetParent and rst:GetParent() or O.content
  local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
  if not ok or not b then ok, b = pcall(CreateFrame, "Button", nil, parent) end
  if not ok or not b then return nil end
  b._rst = rst
  b:SetSize(150, 20)
  b:SetPoint("RIGHT", rst, "LEFT", -6, 0)
  if b.SetText then b:SetText(Tr["Ouvrir la fenêtre"]) end
  b:SetScript("OnClick", function() PU.Open() end)
  TipOn(b, Tr["Progression"], Tr["Ouvre la fenêtre Progression (aussi : clic gauche sur la fiole, /drop progression)."])
  PU.optButton = b
  return b
end

ns.SlashExt = ns.SlashExt or {}
do
  local printSummary = ns.SlashExt.progression
  PU.PrintSummary = printSummary
  local TAB = { vue = "overview", overview = "overview", graphiques = "charts", graphes = "charts", charts = "charts", graphs = "charts",
    succes = "ach", ["succès"] = "ach", achievements = "ach", spots = "spots", farm = "spots",
    semaine = "weekly", hebdo = "weekly", week = "weekly", weekly = "weekly" }
  local function cmd(rest)
    local low = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if low == "texte" or low == "text" or low == "chat" then
      if printSummary then return printSummary(rest) end
      return
    end
    if TAB[low] then return PU.Open(TAB[low]) end
    return PU.Toggle()
  end
  ns.SlashExt.progression = cmd
  ns.SlashExt.progres = cmd
  ns.SlashExt["progrès"] = cmd
end
ns.HelpExt = ns.HelpExt or {}
for i, l in ipairs(ns.HelpExt) do
  if l == "/drop progression : session (XP/h, points/h, objectif, série, records)" then
    ns.HelpExt[i] = "/drop progression : fenêtre Progression (onglets : vue, graphiques, succes, spots, semaine ; « texte » : résumé dans le chat)"
  end
end

if ns.On then
  ns.On("PLAYER_LOGIN", function() pcall(PU.BuildMini) end)
  ns.On("PLAYER_REGEN_ENABLED", function() if PU.IsShown() then PU.RequestRefresh() end end)
end
ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  return { string.format("fenêtre Progression (3.6.0) : %s, thème %s, onglet %s ; %d ouvertures, %d rafraîchissements, %d reportées (combat), mini-graphe %d ; erreur : %s",
    PU.frame and (PU.IsShown() and "ouverte" or "fermée") or "pas encore créée", tostring(PU.themeApplied or PU.Mode()), tostring(State().tab),
    PU.stats.opens, PU.stats.refreshes, PU.stats.deferred, PU.stats.mini, tostring(PU.lastError or "aucune")) }
end

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
PU.W, PU.H = 680, 524      -- 3.13.0 : +24 px pour la rangée des vues sous les onglets
PU.PAD = 12
PU.CONTENT_Y = 182
PU.VIEWS_Y = 153          -- 3.13.0 : en-tête de page sous les onglets : titre et description à gauche, vues à droite
PU.CONTENT_W, PU.CONTENT_H = 656, 318
PU.MEDIA = "Interface\\AddOns\\Dropamine\\Media\\"
PU.LOGO = PU.MEDIA .. "Dropamine-Logo-64"            -- Media/Dropamine-Logo.tga (128 px, tiré du PNG)
PU.LOGO_FALLBACK = PU.MEDIA .. "Dropamine-Icon"
PU.WHITE = "Interface\\Buttons\\WHITE8X8"
PU.MAX_BARS = 30
PU.CURVE_COLS = 110            -- colonnes de 2 px
PU.REFRESH_WAIT = { idle = 0.5, combat = 2.0 }
-- 3.13.0 : 6 onglets rangés par usage ; Aperçu (Aujourd'hui · Graphiques · Semaine) et Collection (Carnet · Chasse)
-- ont leurs vues en pastilles, comme Farm (Spots · Efficacité)
PU.TABS = {
  { id = "overview", label = "Aperçu", pages = { "overview", "charts", "weekly" }, desc = "ta progression d'un coup d'œil" },
  { id = "skills", label = "Compétences", pages = { "skills" }, desc = "chaque compétence, jour après jour" },
  { id = "farm", label = "Farm", pages = { "now", "spots", "efficiency" }, desc = "où et comment tu montes le plus vite" },
  { id = "collection", label = "Collection", pages = { "collection", "hunt" }, desc = "ton carnet et les objets que tu chasses" },
  { id = "ach", label = "Succès", pages = { "ach" }, desc = "tes succès Dropamine" },
  { id = "chars", label = "Personnages", pages = { "chars" }, desc = "tous les personnages du compte" },
}
function PU.Endgame() return ns.Hunt and ns.Hunt.Endgame and ns.Hunt.Endgame() or false end
function PU.GroupOf(pageId)
  for _, t in ipairs(PU.TABS) do
    for _, pg in ipairs(t.pages) do if pg == pageId then return t.id end end
  end
  return pageId
end
function PU.GroupDefault(gid)
  local ui = PU.State and PU.State() or nil
  if gid == "overview" then return (ui and ui.overSub) or "overview" end
  if gid == "charts" then return (ui and ui.chartsSub) or "charts" end
  if gid == "farm" then return (ui and ui.farmSub) or "now" end
  if gid == "collection" then
    local sub = (ui and ui.collSub) or "collection"
    if sub == "hunt" and ns.Hunt and ns.Hunt.On and not ns.Hunt.On() then sub = "collection" end
    return sub
  end
  return gid
end
PU.CHAR_MAX = 16
PU.CHAR_COLS = {
  { id = "name",     label = "Personnage",  w = 112 },
  { id = "level",    label = "Niveau",      w = 50 },
  { id = "xp",       label = "XP",          w = 88 },
  { id = "gold",     label = "Or",          w = 78 },
  { id = "profs",    label = "Métiers",     w = 128 },
  { id = "weapons",  label = "Armes",       w = 110 },
  { id = "playtime", label = "Temps de jeu", w = 82 },
}
PU.PERIODS = { { id = "session", label = "Session" }, { id = "d7", label = "7 j" }, { id = "d30", label = "30 j" } }

PU.EFF_PERIODS = { { id = "session", label = "Session" }, { id = "d7", label = "7 j" }, { id = "d30", label = "30 j" } }

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
local function Dec(s) if ns.DecimalComma and ns.DecimalComma() then return (s:gsub("%.", ",")) end return s end
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
  if s.tab ~= "overview" and s.tab ~= "charts" and s.tab ~= "ach" and s.tab ~= "spots" and s.tab ~= "weekly" and s.tab ~= "efficiency" and s.tab ~= "chars"
    and s.tab ~= "hunt" and s.tab ~= "collection" and s.tab ~= "skills" and s.tab ~= "now" then s.tab = "overview" end   -- 3.13.0 : + Compétences
  if s.tab == "hunt" and ns.Hunt and ns.Hunt.On and not ns.Hunt.On() then s.tab = "overview" end
  if s.chartsSub ~= "weekly" then s.chartsSub = "charts" end
  if s.farmSub ~= "efficiency" and s.farmSub ~= "spots" then s.farmSub = "now" end
  if s.effPeriod ~= "session" and s.effPeriod ~= "d7" and s.effPeriod ~= "d30" then s.effPeriod = "session" end
  if s.period ~= "session" and s.period ~= "d7" and s.period ~= "d30" then s.period = "d7" end
  if s.metric ~= "total" and s.metric ~= "xph" and s.metric ~= "cat" then s.metric = "cat" end
  return s
end
PU.State = State

function PU.SetEffPeriod(id)
  local s = State()
  if id ~= "session" and id ~= "d7" and id ~= "d30" then return s.effPeriod end
  s.effPeriod = id
  PU.Refresh()
  return id
end

function PU.AtMaxLevel()
  local E = ns.Efficiency
  if E and E.AtMaxLevel then return E.AtMaxLevel() end
  local lvl = N(ns.GetPlayerLevel and Call(ns.GetPlayerLevel)) or N(Call(_G.UnitLevel, "player")) or 0
  local mx = N(ns.MAX_PLAYER_LEVEL) or N(_G.MAX_PLAYER_LEVEL) or 60
  return lvl > 0 and mx > 0 and lvl >= mx
end

function PU.ScanTruncateTips(root)
  if not root then return end
  local function walk(fr)
    if not fr then return end
    if type(fr.GetRegions) == "function" then
      local ok, regs = pcall(function() return { fr:GetRegions() } end)
      if ok and type(regs) == "table" then
        for i = 1, #regs do
          local r = regs[i]
          if r and r.GetObjectType then
            local ok2, typ = pcall(r.GetObjectType, r)
            if ok2 and typ == "FontString" and r.GetText then
              local txt = r._fullText or Call(r.GetText, r) or ""
              PU.BindTruncateTip(r, txt, r._tipExtra, N(r.GetWidth and r:GetWidth()) or 0)
            end
          end
        end
      end
    end
    if type(fr.GetChildren) == "function" then
      local ok, ch = pcall(function() return { fr:GetChildren() } end)
      if ok and type(ch) == "table" then
        for i = 1, #ch do walk(ch[i]) end
      end
    end
  end
  walk(root)
end



------------------------------------------------------------------------------
-- Palettes par thème (jetons Style / Theme / ClassicTheme)
------------------------------------------------------------------------------
local BRONZE = (ns.STYLE and ns.STYLE.BORDER) or { 0.65, 0.49, 0.27, 1 }
local SP = ns.Style and ns.Style.PALETTE or {}
local function Col(c, fallback) return (type(c) == "table" and c) or fallback end
PU.THEMES = {
  -- 3.13.0 : thème Dropamine = la charte du site (dropamine.app) : fond brun très sombre, filets fins,
  -- titres or, pastilles détourées (l'active pleine, or, texte sombre), liseré tricolore sous l'en-tête
  flare = {
    skin = false, bgAlpha = 0.97, site = true,
    flat = { 0.067, 0.051, 0.035, 0.97 }, edge = { 0.541, 0.416, 0.227, 1 },
    card = { 0.098, 0.075, 0.051, 0.96 }, cardEdge = { 0.18, 0.141, 0.094, 1 }, cardHi = { 0.16, 0.12, 0.07, 0.96 },
    title = { 0.91, 0.784, 0.541 }, text = { 0.937, 0.886, 0.776 }, sub = { 0.659, 0.58, 0.435 }, label = { 0.769, 0.604, 0.361 },
    accent = { 0.769, 0.604, 0.361, 1 }, accentHi = { 0.91, 0.784, 0.541 },
    pillOn = { 0.91, 0.784, 0.541, 1 }, pillOff = { 0.098, 0.075, 0.051, 0 }, pillEdge = { 0.235, 0.184, 0.118, 1 }, pillOnText = { 0.1, 0.07, 0.04 },
    button = { 0.098, 0.075, 0.051, 0 }, buttonEdge = { 0.235, 0.184, 0.118, 1 }, buttonText = { 0.91, 0.784, 0.541 },
    track = { 0.043, 0.031, 0.024, 1 }, grid = { 0.91, 0.784, 0.541, 0.06 },
    bar = { 0.769, 0.604, 0.361, 1 }, barHi = { 0.91, 0.784, 0.541, 1 },
    line1 = { 0.91, 0.784, 0.541, 1 }, line2 = { 0.612, 0.714, 0.878, 1 }, fill1 = { 0.91, 0.784, 0.541, 0.16 },
    good = { 0.549, 0.769, 0.447 }, bad = { 0.851, 0.541, 0.451 }, gold = { 0.91, 0.784, 0.541 },
    mini = { 0.067, 0.051, 0.035, 0.96 },
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
-- 3.13.0 : cadre « jeu » = tout aux couleurs et éléments du jeu (encadrés d'options, boutons rouges et or,
-- onglets, barres de compétence). Seules les couleurs Niveau / Armes / Métiers restent celles de Dropamine.
PU.THEMES.native = {
  skin = false, bgAlpha = 1,
  card = { 0, 0, 0, 0.4 }, cardEdge = { BRONZE[1], BRONZE[2], BRONZE[3], 1 }, cardHi = { 0.20, 0.16, 0.02, 0.45 },
  title = { 1, 0.82, 0 }, text = { 1, 1, 1 }, sub = { 0.72, 0.72, 0.72 }, label = { 1, 0.82, 0 },
  accent = { 1, 0.82, 0, 1 }, accentHi = { 1, 0.9, 0.45 },
  pillOn = { 0.3, 0.25, 0.05, 1 }, pillOff = { 0.1, 0.1, 0.1, 1 }, pillEdge = { 0.55, 0.55, 0.55, 1 },
  button = { 0.5, 0.08, 0.06, 1 }, buttonEdge = { 0.85, 0.7, 0.3, 1 }, buttonText = { 1, 0.82, 0 },
  track = { 0, 0, 0, 0.6 }, grid = { 1, 1, 1, 0.08 },
  bar = { 0.95, 0.72, 0.15, 1 }, barHi = { 1, 0.86, 0.35, 1 },
  line1 = { 1, 0.82, 0, 1 }, line2 = { 0.6, 0.75, 1, 1 }, fill1 = { 1, 0.82, 0, 0.2 },
  good = { 0.25, 1, 0.25 }, bad = { 1, 0.35, 0.35 }, gold = { 1, 0.82, 0 },
  mini = { 0, 0, 0, 0.85 },
}
function PU.Mode()
  local Th = ns.Theme
  local m = Th and Th.Mode and Call(Th.Mode) or "flare"
  if not PU.THEMES[m] then m = "flare" end
  return m
end
function PU.Pal() return PU.native and PU.THEMES.native or PU.THEMES[PU.Mode()] end
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
  PU.BindTruncateTip(fs, texts[1] or chosen, nil, maxW)
  return chosen
end

------------------------------------------------------------------------------
-- Infobulle si le texte est tronqué (GetStringWidth / IsTruncated)
------------------------------------------------------------------------------
function PU.IsTruncated(fs, visW)
  if not fs then return false end
  if type(fs.IsTruncated) == "function" then
    local ok, v = pcall(fs.IsTruncated, fs)
    if ok and v == true then return true end
  end
  local sw = Width(fs, 0)
  visW = N(visW) or (fs.GetWidth and N(fs:GetWidth())) or 0
  return visW > 0 and sw > visW + 0.5
end

function PU.EnsureTipHit(fs)
  if not fs then return nil end
  if fs._tipHit then return fs._tipHit end
  local parent = (fs.GetParent and fs:GetParent()) or fs.parent
  if not parent or type(CreateFrame) ~= "function" then return nil end
  local hit = CreateFrame("Frame", nil, parent)
  if not hit then return nil end
  if hit.EnableMouse then pcall(hit.EnableMouse, hit, false) end
  if hit.SetAllPoints then pcall(hit.SetAllPoints, hit, fs) end
  if hit.SetFrameLevel and parent.GetFrameLevel then
    pcall(hit.SetFrameLevel, hit, (N(parent:GetFrameLevel()) or 1) + 6)
  end
  hit:SetScript("OnEnter", function(self)
    if not self._active then return end
    local tt = _G.GameTooltip
    if not tt then return end
    pcall(tt.SetOwner, tt, self, "ANCHOR_TOP")
    if tt.ClearLines then tt:ClearLines() end
    if self._full and tt.AddLine then tt:AddLine(self._full, 1, 0.82, 0, true) end
    if type(self._extra) == "table" then
      for i = 1, #self._extra do
        if self._extra[i] and tt.AddLine then tt:AddLine(self._extra[i], 1, 1, 1, true) end
      end
    elseif type(self._extra) == "string" and self._extra ~= "" and tt.AddLine then
      tt:AddLine(self._extra, 1, 1, 1, true)
    end
    if tt.Show then tt:Show() end
  end)
  hit:SetScript("OnLeave", function()
    local tt = _G.GameTooltip
    if tt and tt.Hide then tt:Hide() end
  end)
  fs._tipHit = hit
  return hit
end

function PU.BindTruncateTip(fs, fullText, extra, visW)
  if not fs then return end
  local trunc = PU.IsTruncated(fs, visW)
  local hit = PU.EnsureTipHit(fs)
  if not hit then return end
  hit._full = fullText
  hit._extra = extra
  local vis = not fs.IsShown or fs:IsShown()   -- 3.13.0 : un texte caché ne garde pas sa bulle
  hit._active = vis and trunc and type(fullText) == "string" and fullText ~= ""
  if hit.EnableMouse then pcall(hit.EnableMouse, hit, hit._active and true or false) end
  if hit.SetAllPoints then pcall(hit.SetAllPoints, hit, fs) end
end

function PU.BindTip(fs, fullText, extra, visW)
  if not fs then return end
  local trunc = PU.IsTruncated(fs, visW)
  local hasExtra = (type(extra) == "table" and #extra > 0) or (type(extra) == "string" and extra ~= "")
  local hit = PU.EnsureTipHit(fs)
  if not hit then return end
  hit._full = fullText
  hit._extra = extra
  local vis = not fs.IsShown or fs:IsShown()
  hit._active = vis and (trunc or hasExtra) and type(fullText) == "string" and fullText ~= ""
  if hit.EnableMouse then pcall(hit.EnableMouse, hit, hit._active and true or false) end
  if hit.SetAllPoints then pcall(hit.SetAllPoints, hit, fs) end
end

local function FmtWhen(ts, dayKey)
  if type(dayKey) == "string" and dayKey ~= "" then return dayKey end
  ts = N(ts)
  if ts and ts > 0 and type(_G.date) == "function" then
    local ok, s = pcall(_G.date, "%d/%m/%Y", ts)
    if ok and type(s) == "string" then return s end
  end
  return nil
end
PU.FmtWhen = FmtWhen


local CARD_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } }
function PU.Card(parent, x, y, w, h, title)
  local okC, c = pcall(CreateFrame, "Frame", nil, parent, PU.native and "BackdropTemplate" or nil)
  if not (okC and c) then c = CreateFrame("Frame", nil, parent) end
  if PU.native and c.SetBackdrop and pcall(c.SetBackdrop, c, CARD_BACKDROP) then c._bd = true end
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
  if c._bd then
    c.bg:Hide() ShowEdge(c.edge, false)
    local bg, e = c._solid and { 0.07, 0.065, 0.055, 0.97 } or pal.card, hi and { 1, 0.82, 0, 1 } or pal.cardEdge
    if c.SetBackdropColor then pcall(c.SetBackdropColor, c, bg[1], bg[2], bg[3], bg[4]) end
    if c.SetBackdropBorderColor then pcall(c.SetBackdropBorderColor, c, e[1], e[2], e[3], e[4] or 1) end
    return
  end
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

local function NativeButton(parent, w, h, label, kind, onClick)
  local isTab = kind == "tab"
  local name = isTab and ("DropamineProgressTab" .. (#PU.buttons + 1)) or nil
  local ok, b = pcall(CreateFrame, "Button", name, parent, isTab and "TabButtonTemplate" or "UIPanelButtonTemplate")
  if not (ok and b) and isTab then ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate") isTab = false end
  if not (ok and b) then return nil end
  b:SetSize(w, math.max(h, kind == "pill" and 18 or 22))
  b:SetText(label or "")
  if kind == "pill" or kind == "small" then
    if b.SetNormalFontObject then pcall(b.SetNormalFontObject, b, "GameFontHighlightSmall") end
    if b.SetHighlightFontObject then pcall(b.SetHighlightFontObject, b, "GameFontHighlightSmall") end
  end
  b.fs = (b.GetFontString and b:GetFontString()) or b.Text
  b.kind, b.native, b.isTab = kind or "small", true, isTab
  -- textures de l'ancien habillage, gardées cachées (le reste du code peut encore les peindre)
  b.bg = b:CreateTexture(nil, "BACKGROUND") b.bg:Hide()
  b.edge = Edge(b) ShowEdge(b.edge, false)
  b.hl = b.bg
  if isTab then b:SetScript("OnShow", nil) end   -- pas de redimensionnement auto : la rangée d'onglets décide
  if b.RegisterForClicks then pcall(b.RegisterForClicks, b, "LeftButtonUp") end
  b:SetScript("OnClick", function(self, button) if onClick then onClick(self, button) end end)
  PU.buttons[#PU.buttons + 1] = b
  return b
end
function PU.Button(parent, w, h, label, kind, onClick)
  if PU.native and kind ~= "close" and kind ~= "row" then   -- 3.13.0 : une ligne de liste reste une ligne (pas un bouton rouge)
    local nb = NativeButton(parent, w, h, label, kind, onClick)
    if nb then return nb end
  end
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
  if b.native then
    if b.isTab then
      local f = b.on and _G.PanelTemplates_SelectTab or _G.PanelTemplates_DeselectTab
      if f then pcall(f, b) end
    elseif k == "pill" or k == "tab" then
      if b.on then pcall(b.LockHighlight, b) else pcall(b.UnlockHighlight, b) end
      if b.fs and b.fs.SetTextColor then if b.on then b.fs:SetTextColor(1, 1, 1) else b.fs:SetTextColor(1, 0.82, 0) end end
    end
    return
  end
  if k == "pill" or k == "tab" then
    Paint(b.bg, b.on and pal.pillOn or pal.pillOff)
    PaintEdge(b.edge, b.on and { pal.accentHi[1], pal.accentHi[2], pal.accentHi[3], 0.9 } or pal.pillEdge)
    TextColor(b.fs, b.on and (pal.pillOnText or ((k == "tab") and pal.title or { 1, 1, 1 })) or pal.sub)
  elseif k == "row" then   -- 3.13.0 : ligne de liste cliquable : fond discret, filet bronze léger
    Paint(b.bg, { 0, 0, 0, 0.25 })
    PaintEdge(b.edge, { BRONZE[1], BRONZE[2], BRONZE[3], 0.35 })
    TextColor(b.fs, pal.text)
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
-- pastilles posées de gauche à droite depuis x (PU.Pills les pose de droite à gauche)
function PU.LeftAlign(parent, grp, x, y)
  for i = #grp.list, 1, -1 do
    local b = grp.list[i]
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    x = x + ((b.GetWidth and b:GetWidth()) or 60) + 4
  end
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
    local dayEff = c.history[h.day]
    local xpFrac = (type(dayEff) == "table" and (N(dayEff.xpFrac) or (dayEff.eff and N(dayEff.eff.xpFrac)))) or N(h.xpFrac) or 0
    local it = { day = h.day, total = h.pts or 0, level = h.level or 0, combat = h.combat or 0, prof = h.prof or 0,
      xp = h.xp or 0, xpFrac = xpFrac, today = (h.day == today) }
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
  if metric == "xph" then
    -- uniquement la fraction de niveau mesurée (xpFrac) ; on n'invente pas un % à partir de l'XP brute
    return N(it.xpFrac) or 0
  end
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
    local names = { Tr["Niveau"], Tr["Armes et Défense"], Tr["Métiers"] }
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
  -- 3.6.2 : marge haute = c.padTop (c.top servait AUSSI à mémoriser le haut de
  -- l'échelle : dès le 2e rendu, la hauteur du tracé devenait négative et les
  -- graduations 25/50/75/100 partaient sous la fenêtre)
  c.axisW, c.padTop, c.bottom = 22, 12, 13
  if c.SetClipsChildren then pcall(c.SetClipsChildren, c, true) end
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
  if c.empty.SetWidth then c.empty:SetWidth(math.max(40, w - c.axisW - 12)) end
  if c.empty.SetWordWrap then pcall(c.empty.SetWordWrap, c.empty, true) end
  if c.empty.SetMaxLines then pcall(c.empty.SetMaxLines, c.empty, 2) end
  c.empty:Hide()
  PU.charts[#PU.charts + 1] = c
  return c
end

function PU.RenderChart(c, items, metric, emptyText)
  local pal = PU.Pal()
  local seg = PU.SegColors()
  local n = math.min(#items, #c.bars)
  local plotW = c.w - c.axisW - 4
  local plotH = math.max(0, c.h - c.padTop - c.bottom)
  local vmax = 0
  for i = 1, n do local v = ItemValue(items[i], metric) if v > vmax then vmax = v end end
  local top = PU.NiceScale(vmax)
  for k = 1, 4 do
    local y = c.bottom + math.floor(plotH * k / 4 + 0.5)
    if plotH <= 0 or y > c.h then c.grid[k]:Hide() c.ylab[k]:Hide() else
    c.grid[k]:Show() c.ylab[k]:Show()
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
  c.items, c.metric, c.vmax, c.scaleTop, c.n = items, metric, vmax, top, n
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
  c.empty:SetPoint("CENTER", c, "CENTER", 0, 0)
  -- 3.6.2 : « La courbe apparaît… » débordait à droite : largeur bornée, sur 2 lignes
  if c.empty.SetWidth then c.empty:SetWidth(math.max(40, w - 16)) end
  if c.empty.SetWordWrap then pcall(c.empty.SetWordWrap, c.empty, true) end
  if c.empty.SetMaxLines then pcall(c.empty.SetMaxLines, c.empty, 2) end
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
  local maxed = PU.AtMaxLevel and PU.AtMaxLevel()
  for _, e in ipairs(P.Curve() or {}) do
    pts[#pts + 1] = { t = N(e.t) or 0, a = (not maxed and N(e.xph) or 0) or 0, b = N(e.pph) or 0 }
  end
  local r = P.Rates()
  if r and r.elapsed and (#pts == 0 or r.elapsed > pts[#pts].t) then
    pts[#pts + 1] = { t = r.elapsed, a = (not maxed and N(r.xph) or 0) or 0, b = N(r.pph) or 0, live = true }
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
  Place(logo, f, 12, 7, 42, 42)
  PU.SetLogo(logo)
  f.logo = logo
  f.titleFS = FS(f, "GameFontNormalLarge", "title")
  f.titleFS:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -14)
  f.titleFS:SetText("Dropamine · " .. Tr["Progression"])
  f.subFS = FS(f, "GameFontHighlightSmall", "sub")
  f.subFS:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -33)
  f.close = PU.Button(f, 22, 20, "X", "close", function() PU.Close() end)
  f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -14)
  TipOn(f.close, Tr["Fermer"], Tr["Échap ferme aussi la fenêtre."])
  f.share = PU.Button(f, 88, 20, Tr["Partager"], "share", function() PU.ShareClick() end)
  f.share:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  f.recap = PU.Button(f, 96, 20, Tr["Récap session"], "share", function() PU.OpenRecap("current") end)
  f.recap:SetPoint("RIGHT", f.share, "LEFT", -6, 0)
  f.about = PU.Button(f, 22, 20, "?", "share", function() if ns.Setup and ns.Setup.OpenAbout then ns.Setup.OpenAbout() end end)
  f.about:SetPoint("RIGHT", f.recap, "LEFT", -6, 0)
  TipOn(f.about, Tr["À propos"], Tr["Version, liens et signalement de bug."])
  f.app = PU.Button(f, 112, 20, "Dropamine.app", "share", function() local HS = ns.Hiscores if HS and HS.OpenApp then HS.OpenApp() end end)
  f.app:SetPoint("RIGHT", f.about, "LEFT", -6, 0)
  -- 3.14.0 : sac de couchage (bonus d'XP de groupe) : bouton montré seulement à qui possède le sac (PU.RefreshHeader)
  f.bag = PU.Button(f, 44, 20, Tr["Sac"], "share", function() local SB = ns.SleepBag if SB and SB.Give then SB.Give() end end)
  f.bag:SetPoint("RIGHT", f.app, "LEFT", -6, 0)
  f.bag:Hide()
  TipOn(f.bag, Tr["Sac de couchage"], Tr["Macro du sac sur ton curseur : un clic le pose à tes pieds, l'annonce en /dire et invite pendant 5 minutes qui te chuchote « inv »."])
  TipOn(f.app, "Dropamine.app", Tr["Envoyer ta ligne au site, recevoir ta chasse et tes sorties."])
  TipOn(f.recap, Tr["Récap session"], Tr["Durée, temps actif, progression normalisée, paliers, recettes, morts, butin perdu, meilleur spot, succès, valeur marchand et comparaisons."])
  TipOn(f.share, Tr["Partager"], Tr["Pose le récap de ta session dans la zone de saisie du chat : rien n'est envoyé tant que tu n'appuies pas sur Entrée."])
  f.divider = Tex(f, "ARTWORK", 1)
  f.divider:SetPoint("TOPLEFT", f, "TOPLEFT", PU.PAD, -50)
  f.divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PU.PAD, -50)
  f.divider:SetHeight(1)
  -- 3.13.0 : thème Dropamine : liseré tricolore (niveau, armes, métiers) à la place du filet, comme sur le site
  f.tri = {}
  for i = 1, 3 do
    local t = Tex(f, "ARTWORK", 2)
    t:SetHeight(2)
    f.tri[i] = t
  end
  local third = math.floor(PU.CONTENT_W / 3)
  f.tri[1]:SetPoint("TOPLEFT", f, "TOPLEFT", PU.PAD, -50) f.tri[1]:SetWidth(third)
  f.tri[2]:SetPoint("TOPLEFT", f.tri[1], "TOPRIGHT", 0, 0) f.tri[2]:SetWidth(third)
  f.tri[3]:SetPoint("TOPLEFT", f.tri[2], "TOPRIGHT", 0, 0) f.tri[3]:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PU.PAD, -50)
end

function PU.BuildBanner(f)
  local b = PU.Card(f, PU.PAD, 56, PU.CONTENT_W, 62)
  f.banner = b
  b.totalFS = FS(b, "GameFontNormalLarge", "text")
  b.totalFS:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -9)
  b.maxFS = FS(b, "GameFontHighlightSmall", "sub")
  b.maxFS:SetPoint("BOTTOMLEFT", b.totalFS, "BOTTOMRIGHT", 4, 1)
  b.pctFS = FS(b, "GameFontHighlightSmall", "sub", "RIGHT")
  b.pctFS:SetPoint("TOPRIGHT", b, "TOPRIGHT", -10, -12)
  b.barW = PU.CONTENT_W - 20
  b.track = Tex(b, "ARTWORK", 1)
  Place(b.track, b, 10, 31, b.barW, 8)
  b.segs = {}
  for i = 1, 3 do b.segs[i] = Tex(b, "ARTWORK", 2) end
  -- cadre jeu : la jauge du panneau de compétences (piste Dropamine-Bar, filet bronze Dropamine-Thin, reflet 1 px)
  if PU.native then
    local MEDIA = "Interface\\AddOns\\Dropamine\\Media\\"
    b.gauge = true
    pcall(b.track.SetTexture, b.track, MEDIA .. "Dropamine-Bar")
    if b.track.SetVertexColor then pcall(b.track.SetVertexColor, b.track, 0.15, 0.15, 0.15, 0.9) end
    b.sheen = Tex(b, "ARTWORK", 3)
    Paint(b.sheen, { 1, 0.95, 0.85, 0.28 })
    b.sheen:Hide()
    local okE, e = pcall(CreateFrame, "Frame", nil, b, "BackdropTemplate")
    if okE and e and e.SetBackdrop and pcall(e.SetBackdrop, e, { edgeFile = MEDIA .. "Dropamine-Thin", edgeSize = 8 }) then
      e:SetPoint("TOPLEFT", b.track, "TOPLEFT", -3, 3)
      e:SetPoint("BOTTOMRIGHT", b.track, "BOTTOMRIGHT", 3, -3)
      if e.SetBackdropBorderColor then pcall(e.SetBackdropBorderColor, e, BRONZE[1], BRONZE[2], BRONZE[3], 1) end
      if e.EnableMouse then e:EnableMouse(false) end
      b.gaugeEdge = e
    end
  end
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
  for _, t in ipairs(PU.TABS) do
    local id = t.id
    local btn = PU.Button(f, 60, 22, Tr[t.label], "tab", function() PU.SetTab(PU.GroupDefault(id)) end)
    btn.id = id
    btn.endgame = t.endgame
    local w = math.floor(Width(btn.fs, 60) + 22 + 0.5)
    if id == "ach" then   -- 3.13.0 : largeur mesurée avec le compteur (« Succès (88/88) »), plus une marge fixe
      btn.fs:SetText(Tr[t.label] .. " (88/88)")
      w = math.floor(Width(btn.fs, 90) + 22 + 0.5)
      btn.fs:SetText(Tr[t.label])
    end
    btn._w0 = w
    f.tabs[#f.tabs + 1] = btn
  end
  PU.LayoutTabs(f)
end
-- 3.8.1 : Chasse et Collection sont des fonctions à part entière : leurs onglets sont visibles à tout niveau.
function PU.LayoutTabs(f)
  f = f or PU.frame
  if not (f and f.tabs) then return end
  local eg = PU.Endgame()
  local huntOn = not (ns.Hunt and ns.Hunt.On) or ns.Hunt.On()
  local vis, used = {}, 0
  for _, btn in ipairs(f.tabs) do
    if btn.id == "hunt" and not huntOn then btn:Hide()   -- 3.11.1 : chasse coupée
    else vis[#vis + 1] = btn used = used + btn._w0 + 6 end
  end
  used = used - 6
  local scale = (used > PU.CONTENT_W) and (PU.CONTENT_W / used) or 1
  local x = PU.PAD
  for _, btn in ipairs(vis) do
    local w = (scale < 1) and math.max(44, math.floor(btn._w0 * scale + 0.5)) or btn._w0
    btn:SetWidth(w)
    if btn.isTab and _G.PanelTemplates_TabResize then pcall(_G.PanelTemplates_TabResize, btn, 0, w) end   -- onglet du jeu : ses 3 morceaux suivent la largeur
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", f, "TOPLEFT", x, -126)
    btn:Show()
    x = x + w + ((scale < 1) and 4 or 6)
  end
  f._tabsEndgame, f._tabsHunt = eg, huntOn
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
  local titles = { Tr["Rythme XP"], Tr["Points de la session"], Tr["Série & records"], Tr["Objectif session"] }
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
  local left = PU.Card(p, 0, 66, gw, 186, Tr["Aujourd'hui"])
  left.title:SetFontObject(_G.GameFontNormalSmall or "GameFontNormalSmall")
  p.left = left
  -- 3.8.1 : « Aujourd'hui » (le graphique détaillé est dans l'onglet Graphiques)
  left.hero = FS(left, "GameFontNormalLarge", "text")
  left.hero:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -20)
  left.heroSub = FS(left, "GameFontHighlightSmall", "sub")
  left.heroSub:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -42)
  left.cats = {}
  for i = 1, 3 do
    local y = 62 + (i - 1) * 16
    local e = {}
    e.dot = Tex(left, "ARTWORK", 2)
    Place(e.dot, left, 10, y + 3, 7, 7)
    e.fs = FS(left, "GameFontHighlightSmall", "text")
    e.fs:SetPoint("LEFT", e.dot, "RIGHT", 5, 0)
    e.v = FS(left, "GameFontNormalSmall", "title")
    e.v:SetPoint("TOPRIGHT", left, "TOPRIGHT", -8, -y)
    if e.v.SetJustifyH then e.v:SetJustifyH("RIGHT") end
    e.bar = PU.NewBar(left, 130, y + 4, gw - 130 - 56, 4)
    left.cats[i] = e
  end
  left.week = {}
  local colW = math.floor((gw - 20) / 7)
  for i = 1, 7 do
    local e = {}
    e.bar = Tex(left, "ARTWORK", 2)
    e.lab = FS(left, "GameFontDisableSmall", "sub")
    e.lab:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 10 + (i - 1) * colW + math.floor(colW / 2) - 8, 6)
    e.val = FS(left, "GameFontNormalSmall", "title")
    e.col = 10 + (i - 1) * colW + math.floor((colW - 26) / 2)
    left.week[i] = e
  end
  local right = PU.Card(p, gw + 8, 66, cw, 186, Tr["Courbe de session (XP/h & pts/h)"])
  p.right = right
  right.k1 = Tex(right, "ARTWORK", 2) Place(right.k1, right, 10, 23, 10, 2)
  right.k1FS = FS(right, "GameFontDisableSmall", "sub") right.k1FS:SetPoint("LEFT", right.k1, "RIGHT", 3, 0) right.k1FS:SetText(Tr["XP/h"])
  right.k2 = Tex(right, "ARTWORK", 2) Place(right.k2, right, 60, 23, 10, 2)
  right.k2FS = FS(right, "GameFontDisableSmall", "sub") right.k2FS:SetPoint("LEFT", right.k2, "RIGHT", 3, 0) right.k2FS:SetText(Tr["pts/h"])
  -- Option B : prochain palier + où il reste des points (affichage seul)
  right.k1:Hide() right.k1FS:Hide() right.k2:Hide() right.k2FS:Hide()
  right.hero = FS(right, "GameFontNormalLarge", "text")
  right.hero:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -20)
  right.heroSub = FS(right, "GameFontHighlightSmall", "sub")
  right.heroSub:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -60)
  right.heroBar = PU.NewBar(right, 8, 44, cw - 16, 8)
  right.srcTitle = FS(right, "GameFontNormalSmall", "label")
  right.srcTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -80)
  right.srcTitle:SetText(Tr["Où il reste des points"])
  right.src = {}
  for i = 1, 3 do
    local y = 96 + (i - 1) * 29
    local e = {}
    e.dot = Tex(right, "ARTWORK", 2)
    Place(e.dot, right, 10, y + 3, 7, 7)
    e.fs = FS(right, "GameFontHighlightSmall", "text")
    e.fs:SetPoint("LEFT", e.dot, "RIGHT", 5, 0)
    e.n = FS(right, "GameFontNormalSmall", "title")
    e.n:SetPoint("TOPRIGHT", right, "TOPRIGHT", -8, -y)
    e.bar = PU.NewBar(right, 10, y + 14, cw - 20, 4)
    right.src[i] = e
  end
  -- bandeau du bas
  local bw = math.floor((PU.CONTENT_W - 8) / 2)
  p.bottom = {}
  for i = 1, 2 do
    local c = PU.Card(p, (i - 1) * (bw + 8), 260, bw, 56)
    c.icon = Tex(c, "ARTWORK", 2)
    Place(c.icon, c, 10, 14, 28, 28)
    c.head = FS(c, PU.native and "GameFontNormalSmall" or "GameFontNormal", PU.native and "label" or "title")
    c.head:SetPoint("TOPLEFT", c, "TOPLEFT", 46, -12)
    if c.head.SetWidth then c.head:SetWidth(bw - 54) end
    c.line = FS(c, "GameFontHighlightSmall", "text")
    c.line:SetPoint("TOPLEFT", c, "TOPLEFT", 46, -31)
    if c.line.SetWidth then c.line:SetWidth(bw - 54) end
    p.bottom[i] = c
  end
  -- 3.8.1 : les deux cartes du bas ouvrent leur onglet (Succès / Spots de farm)
  for i, tab in ipairs({ "ach", "spots" }) do
    local c = p.bottom[i]
    if c.EnableMouse then c:EnableMouse(true) end
    c:SetScript("OnMouseUp", function() if PU.SetTab then PU.SetTab(tab) end end)
  end
  PU.SetLogo(p.bottom[1].icon)
  local farm = ns.FARM_ICON or (PU.MEDIA .. "Farm-Spots-Icon")
  pcall(p.bottom[2].icon.SetTexture, p.bottom[2].icon, farm)
  if p.bottom[2].icon.SetTexCoord then p.bottom[2].icon:SetTexCoord(0, 1, 0, 1) end
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
  if sf.EnableMouse then sf:EnableMouse(true) end   -- 3.13.0 : glisser dans la liste ne déplace plus la fenêtre
  p.scroll, p.child = sf, child
  -- 3.13.0 : barre qu'on peut saisir (comme celle de la Collection) ; le glisser suit le curseur jusqu'au relâchement
  local grab = CreateFrame("Button", nil, p)
  Place(grab, p, PU.CONTENT_W - 9, 0, 12, PU.CONTENT_H)
  if grab.EnableMouseWheel then grab:EnableMouseWheel(true) end
  grab:SetScript("OnMouseWheel", function(_, delta) PU.ScrollAch(-(N(delta) or 0) * 40) end)
  local function DragTo(self)
    local maxY = math.max(0, (p.childH or 0) - PU.CONTENT_H)
    if maxY <= 0 then return end
    local _, cy = _G.GetCursorPosition()
    local scale = (self.GetEffectiveScale and self:GetEffectiveScale()) or 1
    local top = (self.GetTop and self:GetTop()) or 0
    local frac = math.max(0, math.min(1, (top - cy / scale) / PU.CONTENT_H))
    PU.ScrollAch(frac * maxY - (p.scrollY or 0))
  end
  local function DragUpdate(self)
    local down = _G.IsMouseButtonDown
    if type(down) == "function" and not down("LeftButton") then self:SetScript("OnUpdate", nil) return end
    DragTo(self)
  end
  grab:SetScript("OnMouseDown", function(self) DragTo(self) self:SetScript("OnUpdate", DragUpdate) end)
  grab:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
  p.grab = grab
  p.thumbTrack = Tex(p, "ARTWORK", 1)
  Place(p.thumbTrack, p, PU.CONTENT_W - 7, 0, 6, PU.CONTENT_H)
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
PU.SPOT_ROWS = 8
PU.SPOT_TOP = 96            -- 3.13.0 : bandeau des meilleures zones au-dessus du tableau
PU.SPOT_COLS = { 10, 290, 430, 530 }
function PU.BuildSpots(f)
  local p = Page(f, "spots")
  -- 3.13.0 : une carte par métier de récolte : meilleure zone en points/h, tendance, meilleure zone en or/h
  p.best = {}
  local bw = math.floor((PU.CONTENT_W - 3 * 8) / 4)
  for i = 1, 4 do
    local b = PU.Card(p, (i - 1) * (bw + 8), 0, bw, PU.SPOT_TOP - 8, "")
    b.skill = FS(b, "GameFontNormalSmall", "label") b.skill:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -7) b.skill:SetWidth(bw - 16)
    b.zone = FS(b, "GameFontHighlight", "text") b.zone:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -22) b.zone:SetWidth(bw - 16)
    b.rate = FS(b, "GameFontHighlightSmall", "text") b.rate:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -40) b.rate:SetWidth(bw - 16)
    b.gold = FS(b, "GameFontHighlightSmall", "sub") b.gold:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -56) b.gold:SetWidth(bw - 16)
    b.gold2 = FS(b, "GameFontDisableSmall", "sub") b.gold2:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -69) b.gold2:SetWidth(bw - 16)
    p.best[i] = b
  end
  local c = PU.Card(p, 0, PU.SPOT_TOP, PU.CONTENT_W, PU.CONTENT_H - PU.SPOT_TOP)
  p.card = c
  local heads = { Tr["Zone"], Tr["Métier"], Tr["Points"], Tr["Temps"] }
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
  c.empty:SetPoint("CENTER", c, "CENTER", 0, 6)
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

function PU.BuildEfficiency(f)
  local p = Page(f, "efficiency")
  p.period = PU.Pills(p, PU.EFF_PERIODS, PU.CONTENT_W, 2, function() return State().effPeriod or "session" end, function(id) PU.SetEffPeriod(id) end)

  local score = PU.Card(p, 0, 28, PU.CONTENT_W, 80, Tr["Temps actif"])
  p.score = score
  score.value = FS(score, "GameFontNormalHuge", "title")
  score.value:SetPoint("TOPLEFT", score, "TOPLEFT", 12, -18)
  score.sub = FS(score, "GameFontHighlightSmall", "sub")
  score.sub:SetPoint("LEFT", score.value, "RIGHT", 10, 0)
  if score.sub.SetWidth then score.sub:SetWidth(PU.CONTENT_W - 160) end
  if score.sub.SetHeight then score.sub:SetHeight(14) end
  if score.value.SetHeight then score.value:SetHeight(28) end
  score.track = Tex(score, "ARTWORK", 1)
  Place(score.track, score, 12, 50, PU.CONTENT_W - 24, 8)
  score.seg = { Tex(score, "ARTWORK", 2), Tex(score, "ARTWORK", 2), Tex(score, "ARTWORK", 2) }
  score.split = FS(score, "GameFontHighlightSmall", "text")
  score.split:SetPoint("TOPLEFT", score, "TOPLEFT", 12, -62)
  if score.split.SetWidth then score.split:SetWidth(PU.CONTENT_W - 24) end
  if score.split.SetHeight then score.split:SetHeight(14) end

  local gw = math.floor((PU.CONTENT_W - 16) / 3)
  p.stat = {}
  local stitles = { Tr["Morts"], Tr["Butin perdu"], Tr["Pêche"] }
  for i = 1, 3 do
    local c = PU.Card(p, (i - 1) * (gw + 8), 116, gw, 50, stitles[i])
    c.value = FS(c, "GameFontNormalLarge", "text")
    c.value:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -18)
    c.sub = FS(c, "GameFontHighlightSmall", "sub")
    c.sub:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -36)
    if c.sub.SetWidth then c.sub:SetWidth(gw - 16) end
    if c.value.SetHeight then c.value:SetHeight(16) end
    if c.sub.SetHeight then c.sub:SetHeight(12) end
    p.stat[i] = c
  end

  local profit = PU.Card(p, 0, 174, PU.CONTENT_W, 110, Tr["Rentabilité"])
  p.profit = profit
  profit.net = FS(profit, "GameFontNormal", "text")
  profit.net:SetPoint("TOPLEFT", profit, "TOPLEFT", 10, -18)
  if profit.net.SetWidth then profit.net:SetWidth(PU.CONTENT_W - 20) end
  if profit.net.SetHeight then profit.net:SetHeight(14) end
  profit.rows = {}
  for i = 1, 3 do
    local fs = FS(profit, "GameFontHighlightSmall", "text")
    fs:SetPoint("TOPLEFT", profit, "TOPLEFT", 10, -(36 + (i - 1) * 16))
    if fs.SetWidth then fs:SetWidth(PU.CONTENT_W - 20) end
    if fs.SetHeight then fs:SetHeight(14) end
    profit.rows[i] = fs
  end
  profit.empty = FS(profit, "GameFontDisableSmall", "sub")
  profit.empty:SetPoint("TOPLEFT", profit, "TOPLEFT", 10, -40)
  if profit.empty.SetWidth then profit.empty:SetWidth(PU.CONTENT_W - 20) end
  if profit.empty.SetHeight then profit.empty:SetHeight(28) end

  p.flags = FS(p, "GameFontHighlightSmall", "text")
  p.flags:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -286)
  if p.flags.SetWidth then p.flags:SetWidth(PU.CONTENT_W - 8) end
  if p.flags.SetHeight then p.flags:SetHeight(12) end
  p.tip = FS(p, "GameFontDisableSmall", "sub")
  p.tip:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -300)
  if p.tip.SetWidth then p.tip:SetWidth(PU.CONTENT_W - 8) end
  if p.tip.SetHeight then p.tip:SetHeight(14) end
  return p
end



function PU.OpenRecap(which)
  local s = State()
  s.recapOpen = true
  s.recapId = which or "current"
  if not PU.frame then PU.Build() end
  PU.Open()
  PU.Refresh()
  return true
end

function PU.CloseRecap()
  local s = State()
  s.recapOpen = false
  s.recapId = nil
  PU.Refresh()
end

function PU.BuildRecap(f)
  local p = Page(f, "recap")
  p.back = PU.Button(p, 70, 20, Tr["Retour"], "small", function() PU.CloseRecap() end)
  p.back:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  p.title = FS(p, "GameFontNormalLarge", "title")
  p.title:SetPoint("LEFT", p.back, "RIGHT", 8, 0)
  p.title:SetText(Tr["Récap session"])
  if p.title.SetHeight then p.title:SetHeight(18) end
  p.test = PU.Button(p, 88, 20, Tr["Test"], "small", function() PU.OpenRecap("demo") end)
  p.test:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
  TipOn(p.test, Tr["Récap session"], Tr["Charge un récap de démonstration (données d'exemple, signalées comme telles)."])

  local hw = 200
  local hist = PU.Card(p, 0, 26, hw, 254, Tr["Historique"])
  p.histCard = hist
  p.hist = {}
  for i = 1, 10 do
    local btn = PU.Button(hist, hw - 12, 20, "", "row", function()
      local it = p.hist[i] and p.hist[i]._item
      if it then
        State().recapId = it.id
        PU.Refresh()
      end
    end)
    btn:SetPoint("TOPLEFT", hist, "TOPLEFT", 6, -(20 + (i - 1) * 22))
    p.hist[i] = btn
  end
  p.histMore = FS(hist, "GameFontDisableSmall", "sub")
  p.histMore:SetPoint("BOTTOMLEFT", hist, "BOTTOMLEFT", 8, 6)
  if p.histMore.SetWidth then p.histMore:SetWidth(hw - 16) end
  if p.histMore.SetHeight then p.histMore:SetHeight(12) end

  local dw = PU.CONTENT_W - hw - 8
  local det = PU.Card(p, hw + 8, 26, dw, 254, "")
  p.det = det
  p.head = FS(det, "GameFontNormal", "title")
  p.head:SetPoint("TOPLEFT", det, "TOPLEFT", 10, -8)
  if p.head.SetWidth then p.head:SetWidth(dw - 20) end
  if p.head.SetHeight then p.head:SetHeight(16) end
  p.lines = {}
  for i = 1, 14 do
    local fs = FS(det, "GameFontHighlightSmall", "text")
    fs:SetPoint("TOPLEFT", det, "TOPLEFT", 10, -(26 + (i - 1) * 14))
    if fs.SetWidth then fs:SetWidth(dw - 20) end
    if fs.SetHeight then fs:SetHeight(13) end
    p.lines[i] = fs
  end

  -- tableau de comparaison (dans la fiche de détail) : une ligne par mesure, une colonne par période
  p.tbl = { head = {}, rows = {} }
  local LW, CW = 100, 82
  local function Cell(col, y)
    local fs = FS(det, "GameFontHighlightSmall", "text")
    local x = (col == 0) and 10 or (10 + LW + (col - 1) * CW)
    fs:SetPoint("TOPLEFT", det, "TOPLEFT", x, -y)
    fs:SetWidth(col == 0 and LW or CW - 6)
    fs:SetHeight(13)
    if fs.SetJustifyH then fs:SetJustifyH(col == 0 and "LEFT" or "RIGHT") end
    return fs
  end
  for col = 0, 4 do p.tbl.head[col] = Cell(col, 162) end
  for r = 1, 4 do
    p.tbl.rows[r] = {}
    for col = 0, 4 do p.tbl.rows[r][col] = Cell(col, 162 + 14 + (r - 1) * 15) end
  end
  p.tip = FS(p, "GameFontDisableSmall", "sub")
  p.tip:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -286)
  if p.tip.SetWidth then p.tip:SetWidth(PU.CONTENT_W - 8) end
  if p.tip.SetHeight then p.tip:SetHeight(16) end
  return p
end

local function CmpBit(label, pack, fmt)
  if not pack or pack.mine == nil then return nil end
  local bits = { label .. " " .. fmt(pack.mine) }
  if pack.prev then bits[#bits + 1] = Tr["préc."] .. " " .. fmt(pack.prev) end
  if pack.d7 then bits[#bits + 1] = Tr["moy. 7 j"] .. " " .. fmt(pack.d7) end
  if pack.d30 then bits[#bits + 1] = Tr["moy. 30 j"] .. " " .. fmt(pack.d30) end
  return table.concat(bits, " · ")
end

function PU.RefreshRecap(p)
  if not p then return end
  local E = ns.Efficiency
  if not E then return end
  if p.test then
    if ns.DEV_TEST then p.test:Show() else p.test:Hide() end
  end
  local which = State().recapId or "current"
  local snap
  if which == "demo" and E.DemoRecap then
    snap = E.DemoRecap()
  elseif which == "current" or not which then
    snap = E.CaptureRecap and E.CaptureRecap() or nil
  else
    local hist = E.HistoryList and E.HistoryList() or { sessions = {}, weeks = {} }
    for _, s in ipairs(hist.sessions) do
      if s.id == which or tostring(s.start) == tostring(which) then snap = s break end
    end
    if not snap then
      for _, w in ipairs(hist.weeks) do
        if (w.week or w.id) == which then snap = w break end
      end
    end
  end
  if not snap then snap = E.CaptureRecap and E.CaptureRecap() or {} end

  local hist = E.HistoryList and E.HistoryList() or { sessions = {}, weeks = {} }
  local rows = {}
  rows[#rows + 1] = { id = "current", label = Tr["Session en cours"] }
  if which == "demo" or (snap and snap.demo) then
    rows[#rows + 1] = { id = "demo", label = Tr["Démonstration"] }
  end
  for i, s in ipairs(hist.sessions) do
    local when = PU.FormatWhen and PU.FormatWhen(s.start) or tostring(s.start or "")
    local dur = (P.Dur and P.Dur(s.duration)) or Dur(s.duration or 0)
    rows[#rows + 1] = { id = tostring(s.start), label = (when ~= "" and when or Tr["Session"]) .. " · " .. dur, snap = s }
  end
  for _, w in ipairs(hist.weeks) do
    rows[#rows + 1] = { id = w.week, label = Tr["Semaine"] .. " " .. tostring(w.week or "") .. " (" .. tostring(w.n or "?") .. ")", snap = w }
  end
  for i = 1, #p.hist do
    local btn = p.hist[i]
    local it = rows[i]
    if it then
      btn._item = it
      if btn.fs and btn.fs.SetText then btn.fs:SetText(it.label)
      elseif btn.SetText then btn:SetText(it.label) end
      btn:Show()
    else
      btn._item = nil
      btn:Hide()
    end
  end
  if #rows > #p.hist then
    p.histMore:SetText(string.format(Tr["+%d plus anciennes"], #rows - #p.hist))
    p.histMore:Show()
  else
    p.histMore:SetText("")
    p.histMore:Hide()
  end

  local money = E.FormatMoney
  local function pct(v) return string.format("%d %%", math.floor((N(v) or 0) * 100 + 0.5)) end
  local function rate(v, suf) return Fmt1(v) .. (suf or "") end
  local when = (snap.weekly and (Tr["Semaine"] .. " " .. tostring(snap.week or "")))
    or ((PU.FormatWhen and PU.FormatWhen(snap.start)) or "")
  local dur = Dur(snap.duration or snap.total or 0)
  p.head:SetText((snap.demo and (Tr["Démonstration"] .. " · ") or "") .. (when ~= "" and when .. " · " or "") .. dur)

  local lines = {}
  local function add(s) if s and s ~= "" then lines[#lines + 1] = s end end
  if snap.score then add(Tr["Temps actif"] .. " : " .. pct(snap.score)) end
  if not snap.maxLevel and N(snap.pctLevelPerHour) then
    add(Tr["Progression"] .. " : " .. Fmt2(snap.pctLevelPerHour) .. Tr[" % niv./h"] .. (N(snap.xpFrac) and (" · " .. Fmt2((snap.xpFrac or 0) * 100) .. " %") or ""))
  elseif snap.maxLevel then
    add(Tr["Les rythmes d'XP sont masqués au niveau maximum."])
  end
  if N(snap.skillUps) and snap.skillUps > 0 then
    local names = {}
    for i, sk in ipairs(snap.skills or {}) do
      if i <= 4 then names[#names + 1] = (sk.name or sk.id) .. " +" .. tostring(sk.n) end
    end
    add(Tr["Paliers"] .. " : " .. tostring(snap.skillUps) .. (snap.skillUpsPerHour and (" · " .. Fmt1(snap.skillUpsPerHour) .. Tr[" pal./h"]) or "") .. ((#names > 0) and (" · " .. table.concat(names, ", ")) or ""))
  end
  if snap.recipes and #snap.recipes > 0 then
    local rn = {}
    for i, r in ipairs(snap.recipes) do if i <= 3 then rn[#rn + 1] = r.name or "?" end end
    add(Tr["Recettes apprises"] .. " : " .. table.concat(rn, ", "))
  end
  local deaths = snap.deaths or {}
  if N(deaths.n) or N(deaths.secs) then
    add(Tr["Morts"] .. " : " .. tostring(N(deaths.n) or 0) .. ((N(deaths.secs) and deaths.secs > 0) and (" · " .. Tr["dont "] .. Dur(deaths.secs)) or ""))
  end
  if N(snap.bagMiss) and snap.bagMiss > 0 then
    add(Tr["Butin perdu"] .. " : " .. tostring(snap.bagMiss))
  end
  local pr = snap.profit or {}
  if pr.bestMix and pr.bestMix.zone then add(Tr["Meilleur spot mixte"] .. " : " .. pr.bestMix.zone)
  elseif pr.bestProg and pr.bestProg.zone then add(Tr["Meilleur spot progression"] .. " : " .. pr.bestProg.zone) end
  if snap.achievements and #snap.achievements > 0 then
    local an = {}
    for i, a in ipairs(snap.achievements) do if i <= 3 then an[#an + 1] = a.name or "?" end end
    add(Tr["Succès"] .. " : " .. table.concat(an, ", "))
  end
  if snap.lootValue ~= nil and money then
    local parts = { Tr["Valeur marchand"] .. " : " .. money(snap.lootValue, false) }
    if N(snap.lootCoin) then parts[#parts + 1] = Tr["pièces"] .. " " .. money(snap.lootCoin, false) end
    if N(snap.lootVendor) then parts[#parts + 1] = Tr["objets"] .. " " .. money(snap.lootVendor, false) end
    if snap.goldPerHour then parts[#parts + 1] = money(snap.goldPerHour, false) .. Tr[" /h"] end
    add(table.concat(parts, " · "))
  end
  for i = 1, #p.lines do
    if lines[i] then p.lines[i]:SetText(lines[i]) p.lines[i]:Show()
      p.lines[i]._fullText = lines[i]
    else p.lines[i]:SetText("") p.lines[i]:Hide() end
  end
  if p.lines[1] then
    local tipGold = E.VendorTip and E.VendorTip() or ""
    p.lines[1]._tipExtra = { tipGold }
  end

  local cmp = E.CompareRecap and E.CompareRecap(snap) or {}
  local pal = PU.Pal()
  local heads = { [0] = Tr["Comparaison"], Tr["Cette session"], Tr["Précédente"], Tr["Moy. 7 j"], Tr["Moy. 30 j"] }
  for col = 0, 4 do
    local fs = p.tbl.head[col]
    fs:SetText(heads[col]) TextColor(fs, pal.sub or pal.text)
  end
  local specs = {
    { Tr["Temps actif"], cmp.score, pct },
    { Tr["Niveau / h"], cmp.pctLevelPerHour, function(v) return Fmt2(v) .. " %" end },
    { Tr["Paliers / h"], cmp.skillUpsPerHour, function(v) return Fmt1(v) end },
    { Tr["Valeur / h"], cmp.goldPerHour, function(v) return money and money(v, false) or tostring(v) end },
  }
  for r, sp in ipairs(specs) do
    local row, pack, fmt = p.tbl.rows[r], sp[2], sp[3]
    row[0]:SetText(sp[1]) TextColor(row[0], pal.title or pal.text)
    local vals = { pack and pack.mine, pack and pack.prev, pack and pack.d7, pack and pack.d30 }
    for col = 1, 4 do
      local v = vals[col]
      row[col]:SetText(v ~= nil and fmt(v) or "—")
      TextColor(row[col], pal.text)
    end
    -- cette session : dorée, verte au-dessus de ta moyenne 30 j, rouge en dessous (seulement si la moyenne existe)
    local mine, avg = pack and pack.mine, pack and pack.d30
    local c = pal.gold or pal.title or pal.text
    if mine ~= nil and avg and avg > 0 then c = (mine >= avg) and pal.good or pal.bad end
    TextColor(row[1], c)
  end
  p.tbl.tip = Tr["Comparaisons normalisées uniquement (part active, % de niveau / h, paliers / h, valeur marchand / h). Jamais les points / h ni l'XP brute."]

  local tipText = (snap.tip and snap.tip ~= "") and snap.tip or p.tbl.tip
  p.tip:SetText(tipText or "")
  p.tip._fullText = tipText or ""
end

function PU.ListJoin(items, n)
  if type(items) ~= "table" or #items == 0 then return "—" end
  n = n or 3
  local parts = {}
  for i = 1, math.min(n, #items) do
    local it = items[i]
    if type(it) == "table" then
      local name = (ns.LocSkillName and ns.LocSkillName(it.name, it.id)) or it.name or "?"
      local rk = tonumber(it.rank)
      parts[#parts + 1] = rk and (name .. " " .. tostring(rk)) or name
    else
      parts[#parts + 1] = tostring(it)
    end
  end
  if #items > n then parts[#parts + 1] = "…" end
  return table.concat(parts, ", ")
end

function PU.CharGrid(w)
  w = w or PU.CONTENT_W
  local inner = math.max(160, (w or 656) - 16)
  local cols = (inner >= 420) and 2 or 1
  local gap = 8
  local cw = math.floor((inner - (cols - 1) * gap) / cols)
  local ch = 136
  return cols, cw, ch, gap, inner
end

function PU.SetClipped(fs, text, width)
  if not fs then return end
  text = tostring(text or "")
  fs._fullText = text
  if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, false) end
  if width and fs.SetWidth then pcall(fs.SetWidth, fs, width) end
  fs:SetText(text)
  if not (width and width > 8 and fs.GetStringWidth) then return text end
  local ok, sw = pcall(fs.GetStringWidth, fs)
  if not (ok and sw and sw > width) then return text end
  local lo, hi, best = 1, #text, "…"
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    local cand = string.sub(text, 1, mid) .. "…"
    fs:SetText(cand)
    ok, sw = pcall(fs.GetStringWidth, fs)
    if ok and sw and sw <= width then best = cand lo = mid + 1 else hi = mid - 1 end
  end
  fs:SetText(best)
  return best
end

function PU.CharTip(s)
  s = s or {}
  local money = ns.Efficiency and ns.Efficiency.FormatMoney
  local gold = (money and money(s.gold or 0, false)) or tostring(s.gold or 0)
  local xp
  if (N(s.xpMax) or 0) > 0 then
    xp = tostring(s.xp or 0) .. " / " .. tostring(s.xpMax)
  else
    xp = (s.xp and s.xp > 0) and tostring(s.xp) or "—"
  end
  local lines = {}
  local cls = ns.LocClassName and ns.LocClassName(s.class, s.classFile) or s.class
  lines[#lines + 1] = (cls and (cls .. " · ") or "") .. Tr["Niveau "] .. tostring(s.level or 0)
  lines[#lines + 1] = "XP : " .. xp
  lines[#lines + 1] = Tr["Or"] .. " : " .. gold
  lines[#lines + 1] = Tr["Métiers"] .. " : " .. PU.ListJoin(s.professions, 12)
  local arms = PU.ListJoin(s.weapons, 12)
  if s.defense and (s.defense.name or s.defense.rank) then
    local d = s.defense
    local dtxt = ((d.name and ns.LocSkillName and ns.LocSkillName(d.name, d.id)) or d.name or Tr["Défense"]) .. " " .. tostring(d.rank or 0)
    arms = (arms ~= "—" and (arms .. ", " .. dtxt)) or dtxt
  end
  lines[#lines + 1] = Tr["Armes"] .. " : " .. arms
  lines[#lines + 1] = Tr["Temps de jeu"] .. " : " .. Dur(s.playtime or 0)
  return table.concat(lines, "\n")
end

function PU.SelectChar(key)
  PU.charSel = key
end

function PU.BuildChars(f)
  local p = Page(f, "chars")
  local card = PU.Card(p, 0, 0, PU.CONTENT_W, PU.CONTENT_H, Tr["Personnages"])
  p.card = card
  -- Sous-titre SOUS le titre de carte (plus de chevauchement).
  card.hint = FS(card, "GameFontHighlightSmall", "sub")
  card.hint:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -22)
  if card.hint.SetWidth then card.hint:SetWidth(PU.CONTENT_W - 20) end
  if card.title and card.title.SetWidth then card.title:SetWidth(PU.CONTENT_W - 20) end
  local headerH = 40
  local sf = CreateFrame("ScrollFrame", nil, card)
  Place(sf, card, 8, headerH, PU.CONTENT_W - 16, PU.CONTENT_H - headerH - 8)
  if sf.SetClipsChildren then pcall(sf.SetClipsChildren, sf, true) end
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(PU.CONTENT_W - 16, 10)
  if sf.SetScrollChild then sf:SetScrollChild(child) end
  if sf.EnableMouseWheel then sf:EnableMouseWheel(true) end
  if sf.EnableMouse then sf:EnableMouse(true) end   -- 3.13.0 : glisser dans la liste ne déplace plus la fenêtre
  sf:SetScript("OnMouseWheel", function(_, delta)
    local cur = (sf.GetVerticalScroll and sf:GetVerticalScroll()) or 0
    local maxs = (sf.GetVerticalScrollRange and sf:GetVerticalScrollRange()) or 0
    local nxt = math.max(0, math.min(maxs, cur - (N(delta) or 0) * 40))
    if sf.SetVerticalScroll then sf:SetVerticalScroll(nxt) end
  end)
  p.scroll, p.child = sf, child
  p.cards = {}
  local cols, cw, ch, gap = PU.CharGrid(PU.CONTENT_W)
  for i = 1, PU.CHAR_MAX do
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    local c = PU.Card(child, col * (cw + gap), row * (ch + gap), cw, ch, "")
    c.name = c.title or FS(c, "GameFontNormalSmall", "label")
    if c.name.ClearAllPoints then c.name:ClearAllPoints() end
    c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -6)
    -- 3.8.1 : portrait (icône de classe) + total, puis barres Niveau / Métiers / Armes
    c.icon = Tex(c, "ARTWORK", 2)
    Place(c.icon, c, 8, 8, 32, 32)
    c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 46, -8)
    c.sub = FS(c, "GameFontHighlightSmall", "sub")
    c.sub:SetPoint("TOPLEFT", c, "TOPLEFT", 46, -23)
    c.gold = FS(c, "GameFontHighlightSmall", "text")
    c.gold:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -8)
    if c.gold.SetJustifyH then c.gold:SetJustifyH("RIGHT") end
    c.tot = FS(c, "GameFontNormalSmall", "title")
    c.tot:SetPoint("TOPLEFT", c, "TOPLEFT", 46, -36)
    c.rows = {}
    for r = 1, 5 do
      local y = 54 + (r - 1) * 15
      local e = {}
      e.fs = FS(c, "GameFontHighlightSmall", "text")
      e.fs:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -y)
      e.v = FS(c, "GameFontNormalSmall", "title")
      e.v:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -y)
      if e.v.SetJustifyH then e.v:SetJustifyH("RIGHT") end
      e.bar = PU.NewBar(c, 104, y + 4, cw - 104 - 46, 4)
      c.rows[r] = e
    end
    if c.EnableMouse then c:EnableMouse(true) end
    c:SetScript("OnMouseUp", function(self)
      if self._key and PU.SelectChar then PU.SelectChar(self._key) end
    end)
    c:SetScript("OnEnter", function(self)
      local tt = _G.GameTooltip
      if not (tt and self._tipTitle) then return end
      if tt.SetOwner then pcall(tt.SetOwner, tt, self, "ANCHOR_RIGHT") end
      if tt.ClearLines then pcall(tt.ClearLines, tt) end
      if tt.AddLine then
        tt:AddLine(self._tipTitle, 1, 0.82, 0)
        for line in string.gmatch((self._tipBody or "") .. "\n", "(.-)\n") do
          if line ~= "" then tt:AddLine(line, 1, 1, 1, true) end
        end
      end
      if tt.Show then tt:Show() end
    end)
    c:SetScript("OnLeave", function()
      local tt = _G.GameTooltip
      if tt and tt.Hide then tt:Hide() end
    end)
    c:Hide()
    p.cards[i] = c
  end
  p.more = FS(card, "GameFontDisableSmall", "sub")
  p.more:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 6)
  return p
end

function PU.RefreshChars(p)
  p = p or (PU.frame and PU.frame.pages.chars)
  if not p then return end
  if ns.CaptureCharSheet then pcall(ns.CaptureCharSheet) end
  local rows = ns.AllCharSheets and ns.AllCharSheets() or {}
  -- 3.8.1 : du niveau le plus haut au plus bas (puis nom, pour un ordre stable)
  table.sort(rows, function(a, b)
    local la, lb = N(a.level) or 0, N(b.level) or 0
    if la ~= lb then return la > lb end
    return tostring(a.name or a.key or ""):lower() < tostring(b.name or b.key or ""):lower()
  end)
  local n = #rows
  if p.card and p.card.hint then
    p.card.hint:SetText(string.format(Tr["%d personnage(s) sur ce compte."], n))
  end
  local me = ns.CharKey and ns.CharKey()
  local sel = PU.charSel or me
  local money = ns.Efficiency and ns.Efficiency.FormatMoney
  local cols, cw, ch, gap, inner = PU.CharGrid(PU.CONTENT_W)
  local textW = math.max(40, cw - 16)
  local shown = 0
  for i = 1, PU.CHAR_MAX do
    local c, s = p.cards[i], rows[i]
    if not c then break end
    if not s then
      c:Hide()
      c._key, c._sheet = nil, nil
    else
      shown = shown + 1
      local col, row = (shown - 1) % cols, math.floor((shown - 1) / cols)
      Place(c, p.child, col * (cw + gap), row * (ch + gap), cw, ch)
      local gold = (money and money(s.gold or 0, false)) or tostring(s.gold or 0)
      local cls = ns.LocClassName and ns.LocClassName(s.class, s.classFile) or s.class
      local sub = ((cls and (cls .. " · ")) or "") .. Tr["Niveau "] .. tostring(s.level or 0)
      if s.realm and s.realm ~= "" then sub = sub .. " · " .. s.realm end
      local who = s.name or s.key or "?"
      PU.SetClipped(c.name, who, math.floor(textW * 0.5))
      PU.SetClipped(c.sub, sub, textW - 30)
      PU.SetClipped(c.gold, gold, math.floor(textW * 0.45))
      -- couleur et icône de classe (affichage seul)
      local cf = s.classFile or (ns.ClassCode and ns.ClassCode(s.class))
      if not cf and s.class then  -- anciennes fiches : retrouver le code depuis le nom localisé
        for _, tbl in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE, _G.LOCALIZED_CLASS_NAMES_FEMALE }) do
          if type(tbl) == "table" and not cf then
            for code, nm in pairs(tbl) do if nm == s.class then cf = code break end end
          end
        end
      end
      local cc = _G.RAID_CLASS_COLORS and cf and _G.RAID_CLASS_COLORS[cf]
      if c.name.SetTextColor then
        if cc then c.name:SetTextColor(cc.r, cc.g, cc.b) else TextColor(c.name, PU.Pal().title) end
      end
      local tc = _G.CLASS_ICON_TCOORDS and cf and _G.CLASS_ICON_TCOORDS[cf]
      if tc and c.icon.SetTexture then
        c.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        c.icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        c.icon:SetVertexColor(1, 1, 1, 1)
        c.icon:Show()
      else
        c.icon:Hide()
      end
      local rec = ns.db and ns.db.chars and ns.db.chars[s.key]
      local tot = rec and N(rec.lastTotal)
      local line = tot and (tostring(tot) .. " / " .. tostring(ns.TOTAL_MAX or 2460) .. " · ") or ""
      PU.SetClipped(c.tot, line .. Dur(s.playtime or 0), textW - 30)
      -- barres : Niveau (rouge), 2 meilleurs métiers (vert), 2 meilleures armes / défense (bleu)
      local seg = PU.SegColors()
      local function top(list, extra)
        local out = {}
        for _, it in ipairs(list or {}) do if type(it) == "table" and (N(it.rank) or 0) > 0 then out[#out + 1] = it end end
        if extra and (N(extra.rank) or 0) > 0 then out[#out + 1] = extra end
        table.sort(out, function(x, y) return (N(x.rank) or 0) > (N(y.rank) or 0) end)
        return out
      end
      local cap = (ns.GetLevelCap and ns.GetLevelCap()) or 60
      local items = { { name = Tr["Niveau"], v = N(s.level) or 0, mx = cap, col = seg[1] } }
      for i, it in ipairs(top(s.professions)) do
        if i > 2 then break end
        items[#items + 1] = { name = ns.LocSkillName and ns.LocSkillName(it.name, it.id) or it.name, v = it.rank, mx = (N(it.max) or 0) > 0 and it.max or 300, col = seg[3] }
      end
      for i, it in ipairs(top(s.weapons, s.defense)) do
        if i > 2 then break end
        items[#items + 1] = { name = (it.name and ns.LocSkillName and ns.LocSkillName(it.name, it.id)) or it.name or Tr["Défense"], v = it.rank, mx = (N(it.max) or 0) > 0 and it.max or math.max(it.rank, 1), col = seg[2] }
      end
      for r, e in ipairs(c.rows) do
        local it = items[r]
        if it then
          PU.SetClipped(e.fs, it.name, 94)
          e.v:SetText(tostring(it.v))
          PU.SetBar(e.bar, it.v / math.max(1, it.mx), it.col)
          e.fs:Show() e.v:Show() e.bar.track:Show()
        else
          e.fs:Hide() e.v:Hide() e.bar.track:Hide() e.bar.fill:Hide()
        end
      end
      c._key, c._sheet = s.key, s
      c._tipTitle, c._tipBody = who, PU.CharTip(s)
      local mine = me and s.key == me
      local selected = sel and s.key == sel
      if PU.PaintCard then PU.PaintCard(c, mine or selected) end
      c:Show()
    end
  end
  local rowsN = math.max(1, math.ceil(shown / cols))
  if p.child and p.child.SetHeight then
    p.child:SetHeight(math.max(10, rowsN * (ch + gap) - gap))
  end
  if p.more then
    if n > PU.CHAR_MAX then
      p.more:SetText(string.format(Tr["… et %d de plus"], n - PU.CHAR_MAX))
      p.more:Show()
    else
      p.more:SetText("")
      p.more:Hide()
    end
  end
end

-- Onglet Chasse (endgame) : équipement à chasser (clic sur une case = choisir l'objet) ----------
local HX = 160                                   -- début du volet de droite
local HW = PU.CONTENT_W - HX - 10
function PU.BuildHunt(f)
  local p = Page(f, "hunt")
  local c = PU.Card(p, 0, 0, PU.CONTENT_W, PU.CONTENT_H, Tr["Chasse"])
  p.card = c
  c.ui = { search = "", mine = true, offset = 0, tile = nil }
  -- grille d'équipement : 3 colonnes de 6 cases
  c.tiles = {}
  for i, t in ipairs((ns.Hunt and ns.Hunt.TILES) or {}) do
    local col, row = math.floor((i - 1) / 6), (i - 1) % 6
    local b = CreateFrame("Button", nil, c)
    b:SetSize(40, 40)
    b:SetPoint("TOPLEFT", c, "TOPLEFT", 10 + col * 46, -(26 + row * 44))
    b.bg = Tex(b, "BACKGROUND", 1) b.bg:SetAllPoints(b)
    b.icon = Tex(b, "ARTWORK", 2)
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.edge = Edge(b)
    b.lab = FS(b, "GameFontDisableSmall", "sub")
    b.lab:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.lab:SetText(ns.Hunt.TileLabel(t))
    b.ok = FS(b, "GameFontNormalSmall", "title")
    b.ok:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.tile = t
    if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    b:SetScript("OnClick", function(self, btn) PU.HuntTileClick(self.tile[1], btn) end)
    b:SetScript("OnEnter", function(self)
      local tt = _G.GameTooltip
      if not tt then return end
      if tt.SetOwner then pcall(tt.SetOwner, tt, self, "ANCHOR_RIGHT") end
      local it = self.item
      if it then
        tt:AddLine(tostring(it.name), 1, 0.82, 0)
        if it.boss then tt:AddLine(tostring(it.boss) .. " · " .. tostring(it.dungeon or ""), 1, 1, 1) end
        tt:AddLine(PU.Tries(it.attempts, it.drops), 0.8, 0.8, 0.8)
        tt:AddLine(Tr["Clic droit : retirer"], 0.6, 0.6, 0.6)
      else
        tt:AddLine(ns.Hunt.TileLabel(self.tile), 1, 0.82, 0)
        tt:AddLine(Tr["Clic : choisir l'objet à chasser"], 1, 1, 1)
      end
      tt:Show()
    end)
    b:SetScript("OnLeave", function() if _G.GameTooltip then _G.GameTooltip:Hide() end end)
    c.tiles[i] = b
  end
  do   -- 3.13.0 : tous les libellés à la même taille, celle qui fait tenir le plus long (« Distance ») dans sa case
    local k = 1
    for _, b in ipairs(c.tiles) do
      local w = b.lab and b.lab.GetStringWidth and N(b.lab:GetStringWidth()) or 0
      if w > 36 then k = math.min(k, 36 / w) end
    end
    if k < 1 then
      for _, b in ipairs(c.tiles) do
        if b.lab and b.lab.GetFont and b.lab.SetFont then
          local file, size, flags = b.lab:GetFont()
          if file and size then pcall(b.lab.SetFont, b.lab, file, math.max(7, math.floor(size * k)), flags) end
        end
      end
    end
  end
  -- volet de droite : liste suivie
  c.hint = FS(c, "GameFontHighlightSmall", "sub")
  c.hint:SetPoint("TOPLEFT", c, "TOPLEFT", HX, -24)
  c.hint:SetWidth(HW)
  c.rows = {}
  for i = 1, 7 do
    local y = 44 + (i - 1) * 30
    local e = {}
    e.name = FS(c, "GameFontNormal", "title")
    e.name:SetPoint("TOPLEFT", c, "TOPLEFT", HX, -y)
    e.name:SetWidth(math.floor(HW * 0.5))
    if e.name.SetJustifyH then e.name:SetJustifyH("LEFT") end
    e.info = FS(c, "GameFontHighlightSmall", "text")
    e.info:SetPoint("TOPRIGHT", c, "TOPRIGHT", -32, -y)
    if e.info.SetJustifyH then e.info:SetJustifyH("RIGHT") end
    e.del = PU.Button(c, 18, 14, "x", "small", function()
      if e.idx and ns.Hunt and PU.ConfirmArm("row:" .. tostring(e.idx)) then ns.Hunt.Remove(e.idx) end
      PU.Refresh()
    end)
    e.del:ClearAllPoints()
    e.del:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -(y + 1))
    e.bar = PU.NewBar(c, HX, y + 17, HW - 22, 4)
    c.rows[i] = e
  end
  c.empty = FS(c, "GameFontDisableSmall", "sub")
  c.empty:SetPoint("TOPLEFT", c, "TOPLEFT", HX, -50)
  c.empty:SetWidth(HW)
  if c.empty.SetWordWrap then pcall(c.empty.SetWordWrap, c.empty, true) end
  -- volet de droite : choix de l'objet pour une case (recherche + armure)
  c.pickTitle = FS(c, "GameFontNormal", "title")
  c.pickTitle:SetPoint("TOPLEFT", c, "TOPLEFT", HX, -24)
  c.search = CreateFrame("EditBox", nil, c)
  c.search:SetSize(170, 18)
  c.search:SetPoint("TOPLEFT", c, "TOPLEFT", HX + 150, -22)
  if c.search.SetAutoFocus then pcall(c.search.SetAutoFocus, c.search, false) end
  if c.search.SetMaxLetters then pcall(c.search.SetMaxLetters, c.search, 40) end
  if c.search.SetFontObject then pcall(c.search.SetFontObject, c.search, _G.GameFontHighlightSmall or "GameFontHighlightSmall") end
  if c.search.SetTextInsets then pcall(c.search.SetTextInsets, c.search, 5, 5, 0, 0) end
  c.search.bg = Tex(c.search, "BACKGROUND", 1) c.search.bg:SetAllPoints(c.search)
  c.search.edge = Edge(c.search)
  c.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  c.search:SetScript("OnTextChanged", function(self)
    c.ui.search = self:GetText() or "" c.ui.coff = 0
    if c:IsShown() then PU.RefreshHunt() end
  end)
  c.mineBtn = PU.Button(c, 90, 16, "", "small", function() c.ui.mine = not c.ui.mine PU.RefreshHunt() end)
  c.mineBtn:ClearAllPoints()
  c.mineBtn:SetPoint("TOPLEFT", c, "TOPLEFT", HX + 326, -22)
  c.backBtn = PU.Button(c, 60, 16, Tr["Retour"], "small", function() c.ui.tile = nil PU.RefreshHunt() end)
  c.backBtn:ClearAllPoints()
  c.backBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -22)
  c.cands = {}
  for i = 1, 7 do
    local y = 46 + (i - 1) * 27
    local b = PU.Button(c, HW, 23, "", "row", function(self) PU.HuntPick(i) end)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", c, "TOPLEFT", HX, -y)
    b.fs:ClearAllPoints()
    b.fs:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.fs:SetWidth(HW - 16)
    if b.fs.SetJustifyH then b.fs:SetJustifyH("LEFT") end
    c.cands[i] = b
  end
  -- saisie manuelle (lien, ID ou nom) : toujours disponible, même sans Dungeon Journal
  local yb = PU.CONTENT_H - 30
  local function MakeBox(x, w, maxl)
    local eb = CreateFrame("EditBox", nil, c)
    eb:SetSize(w, 20)
    eb:SetPoint("TOPLEFT", c, "TOPLEFT", x, -yb)
    if eb.SetAutoFocus then pcall(eb.SetAutoFocus, eb, false) end
    if eb.SetMaxLetters then pcall(eb.SetMaxLetters, eb, maxl) end
    if eb.SetFontObject then pcall(eb.SetFontObject, eb, _G.GameFontHighlightSmall or "GameFontHighlightSmall") end
    if eb.SetTextInsets then pcall(eb.SetTextInsets, eb, 5, 5, 0, 0) end
    eb.bg = Tex(eb, "BACKGROUND", 1) eb.bg:SetAllPoints(eb)
    eb.edge = Edge(eb)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
  end
  -- 3.12.1 : une seule case : on tape, les résultats s'affichent à droite, un clic ajoute (case rangée toute seule) ;
  -- Entrée : le premier résultat, ou le lien / numéro collé. Plus de champ « % » (taux lu dans le Journal) ni de bouton Ajouter.
  c.link = MakeBox(HX, HW - 124, 200)   -- 3.13.0 : s'arrête avant « Importer… » (bouton plus large dans le cadre jeu)
  c.linkHint = FS(c.link, "GameFontDisableSmall", "sub")
  c.linkHint:SetPoint("LEFT", c.link, "LEFT", 6, 0)
  c.linkHint:SetPoint("RIGHT", c.link, "RIGHT", -6, 0)   -- 3.13.0 : le texte d'aide reste dans la case
  c.linkHint:SetText(Tr["Rechercher un objet, ou Maj+clic sur un objet (sacs, chat, butin, autres addons)"])
  local function hintShown()
    local empty = (c.link:GetText() or "") == ""
    local focus = c.link.HasFocus and c.link:HasFocus()
    if empty and not focus then c.linkHint:Show() else c.linkHint:Hide() end
  end
  c.link:SetScript("OnEditFocusGained", hintShown)
  c.link:SetScript("OnEditFocusLost", hintShown)
  function PU.HuntResult(it, why)
    if it and why ~= "dup" then
      c.link:SetText("") c.ui.q = "" c.ui.coff = 0
      if c.link.ClearFocus then c.link:ClearFocus() end
      c.msg:SetText(Tr["Suivi : "] .. tostring(it.name or it.id))
    elseif why == "dup" then c.msg:SetText(Tr["Déjà suivi."])
    elseif why == "full" then c.msg:SetText(Tr["Liste pleine (20 objets maximum)."])
    elseif why == "none" then c.msg:SetText(Tr["Aucun butin récent : ouvre un butin d'abord."])
    else c.msg:SetText(Tr["Objet non reconnu : Maj+clic sur un objet, ou tape son nom."]) end
    hintShown()
    PU.Refresh()
  end
  local function doAdd()
    local H = ns.Hunt
    if not H then return end
    local txt = c.link:GetText() or ""
    if txt == "" then return end
    -- code copié sur dropamine.app (« Copier pour le jeu », avec ou sans /drop) : toute la liste d'un coup
    if txt:find("DROP%-CH1:") then
      local added, dup, full = H.ImportCode(txt)
      if added == nil then c.msg:SetText(Tr["Code non reconnu : copie-le à nouveau sur dropamine.app."])
      else
        c.link:SetText("") c.ui.q = "" if c.link.ClearFocus then c.link:ClearFocus() end
        c.msg:SetText(string.format(Tr["dropamine.app : %d ajoutés, %d déjà suivis."], added, dup or 0) .. (full and (" " .. Tr["Liste pleine (20 objets maximum)."]) or ""))
      end
      hintShown() PU.Refresh() return
    end
    -- lien, numéro d'objet : tel quel ; sinon le premier résultat de la recherche, sinon le nom tapé
    local first = (not txt:find("|H", 1, true) and not txt:match("^%s*%d+%s*$")) and c.candList and c.candList[1]
    PU.HuntResult(H.Add(first and first.id or txt))
  end
  c.link:SetScript("OnEnterPressed", doAdd)
  c.link:SetScript("OnTextChanged", function(self)
    c.ui.q = self:GetText() or "" c.ui.coff = 0
    if c.ui.q:find("DROP%-CH1:") or c.ui.q:find("|H", 1, true) then c.ui.q = "" end
    hintShown()
    if c:IsShown() then PU.RefreshHunt() end
  end)
  -- « Importer… » : le dernier butin et les favoris du Journal, rangés dans un petit menu
  c.importBtn = PU.Button(c, 112, 18, Tr["Importer…"], "small", function()
    c.ui.importOpen = not c.ui.importOpen
    if c.ui.importOpen then c.lastBtn:Show() c.favBtn:Show() c.siteBtn:Show() else c.lastBtn:Hide() c.favBtn:Hide() c.siteBtn:Hide() end
  end)
  c.importBtn:ClearAllPoints() c.importBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -(yb + 1))
  c.lastBtn = PU.Button(c, 120, 18, Tr["Dernier butin"], "small", function()
    c.ui.importOpen = false c.lastBtn:Hide() c.favBtn:Hide() c.siteBtn:Hide()
    PU.HuntResult(ns.Hunt.AddLast())
  end)
  c.favBtn = PU.Button(c, 120, 18, Tr["Favoris du Journal"], "small", function()
    c.ui.importOpen = false c.lastBtn:Hide() c.favBtn:Hide() c.siteBtn:Hide()
    local H = ns.Hunt
    local a, d, full = H.ImportFavourites()
    if not H.HasSource() then c.msg:SetText(Tr["Installe l'addon Dungeon Journal pour voir les objets de donjon. Les statistiques restent disponibles."])
    elseif a + d == 0 then c.msg:SetText(Tr["Aucun favori dans le Journal des donjons (clic droit sur un objet > Ajouter aux favoris)."])
    else c.msg:SetText(string.format(Tr["Favoris du Journal : %d ajoutés, %d déjà suivis."], a, d) .. (full and (" " .. Tr["Liste pleine (20 objets maximum)."]) or "")) end
    PU.Refresh()
  end)
  c.siteBtn = PU.Button(c, 120, 18, Tr["Depuis dropamine.app"], "small", function()
    c.ui.importOpen = false c.lastBtn:Hide() c.favBtn:Hide() c.siteBtn:Hide()
    local HS = ns.Hiscores
    if HS and HS.OpenApp then HS.OpenApp(true) return end   -- 3.13.0 : un seul endroit pour recevoir du site
    c.link:SetText("") if c.link.SetFocus then c.link:SetFocus() end
    c.msg:SetText(Tr["Colle le code copié sur dropamine.app (Ctrl+V), puis Entrée."])
  end)
  c.favBtn:ClearAllPoints() c.favBtn:SetPoint("BOTTOMRIGHT", c.importBtn, "TOPRIGHT", 0, 2)
  c.lastBtn:ClearAllPoints() c.lastBtn:SetPoint("BOTTOMRIGHT", c.favBtn, "TOPRIGHT", 0, 2)
  c.siteBtn:ClearAllPoints() c.siteBtn:SetPoint("BOTTOMRIGHT", c.lastBtn, "TOPRIGHT", 0, 2)
  c.favBtn:Hide() c.lastBtn:Hide() c.siteBtn:Hide()
  for _, b in ipairs({ c.favBtn, c.lastBtn, c.siteBtn }) do if b.SetFrameLevel and c.GetFrameLevel then pcall(b.SetFrameLevel, b, c:GetFrameLevel() + 20) end end
  c.msg = FS(c, "GameFontDisableSmall", "sub")
  c.msg:SetPoint("TOPLEFT", c, "TOPLEFT", HX, -(yb - 15))
  c.msg:SetWidth(HW)
  c:EnableMouseWheel(true)
  c:SetScript("OnMouseWheel", function(_, delta)
    if c.ui.tile or #(c.ui.q or "") >= 2 then
      c.ui.coff = math.max(0, math.min(math.max(0, (c.candTotal or 0) - 7), (c.ui.coff or 0) - (N(delta) or 0)))
      PU.RefreshHunt() return
    end
    local n = #((ns.Hunt and ns.Hunt.List()) or {})
    c.ui.offset = math.max(0, math.min(math.max(0, n - 7), c.ui.offset - (N(delta) or 0)))
    if not c.ui.tile then PU.RefreshHunt() end
  end)
  -- Maj+clic sur un objet : dans la case du bas si elle a le curseur ; sinon, onglet Chasse ouvert et pas de saisie
  -- dans le chat : l'objet est ajouté directement. 3.12.2 : deux chemins écoutés (ChatEdit_InsertLink, et
  -- HandleModifiedItemClick que les clients récents utilisent pour les sacs et l'équipement), un seul ajout par clic.
  if type(_G.hooksecurefunc) == "function" and not PU._huntHook then
    PU._huntHook = true
    local lastLink, lastAt = nil, 0
    local function onLink(text)
      if type(text) ~= "string" or not text:find("|Hitem:", 1, true) then return end
      local pg = PU.frame and PU.frame.pages and PU.frame.pages.hunt
      local card = pg and pg.card
      local eb = card and card.link
      if not eb then return end
      local now = (type(_G.GetTime) == "function" and _G.GetTime()) or 0
      if text == lastLink and now - lastAt < 0.3 then return end   -- même clic vu par les deux chemins
      lastLink, lastAt = text, now
      local fp = PU.frame and PU.frame.pages and PU.frame.pages.now
      local fR = fp and fp.R
      if fR and fR.gbox then
        if fR.gbox.HasFocus and fR.gbox:HasFocus() then fR.gbox:Insert(text) return end
        local chat = type(_G.ChatEdit_GetActiveWindow) == "function" and _G.ChatEdit_GetActiveWindow()
        if fR.IsVisible and fR:IsVisible() and not chat then PU.FarmAddFromText(text, N(fR.gqty and fR.gqty:GetText()) or 20) return end
      end
      if eb.HasFocus and eb:HasFocus() then eb:Insert(text) return end
      local shown = card.IsVisible and card:IsVisible()
      local chatOpen = type(_G.ChatEdit_GetActiveWindow) == "function" and _G.ChatEdit_GetActiveWindow()
      if shown and not chatOpen and PU.HuntResult and ns.Hunt then PU.HuntResult(ns.Hunt.Add(text)) end
    end
    if type(_G.ChatEdit_InsertLink) == "function" then pcall(_G.hooksecurefunc, "ChatEdit_InsertLink", onLink) end
    if type(_G.HandleModifiedItemClick) == "function" then
      pcall(_G.hooksecurefunc, "HandleModifiedItemClick", function(link)
        local shift = type(_G.IsShiftKeyDown) == "function" and _G.IsShiftKeyDown()
        if shift then onLink(link) end
      end)
    end
    local CFU = rawget(_G, "ChatFrameUtil")
    if type(CFU) == "table" and type(CFU.InsertLink) == "function" then pcall(_G.hooksecurefunc, CFU, "InsertLink", onLink) end
  end
  return p
end

-- Retrait en deux temps : un premier clic arme, un second dans les 4 s confirme.
local armed = {}
function PU.ConfirmArm(key)
  local now = (_G.GetTime and _G.GetTime()) or 0
  if armed[key] and now - armed[key] <= 4 then armed[key] = nil return true end
  armed[key] = now
  if _G.C_Timer and _G.C_Timer.After then _G.C_Timer.After(4.1, function() if armed[key] == now then armed[key] = nil PU.Refresh() end end) end
  return false
end
function PU.IsArmed(key) return armed[key] ~= nil end
function PU.HuntTileClick(tileId, btn)
  local pg = PU.frame and PU.frame.pages.hunt
  local c = pg and pg.card
  if not (c and ns.Hunt) then return end
  if btn == "RightButton" then
    for _, it in ipairs(ns.Hunt.List()) do
      if it.tile == tileId then
        if PU.ConfirmArm("tile:" .. tostring(it.i)) then ns.Hunt.Remove(it.i)
        else c.msg:SetText(string.format(Tr["Clic droit à nouveau pour retirer : %s"], tostring(it.name))) return end
      end
    end
    c.ui.tile = nil
  else
    c.ui.tile = tileId
    c.ui.search = "" c.ui.coff = 0
    c.search:SetText("")
  end
  PU.Refresh()
end
function PU.HuntPick(i)
  local pg = PU.frame and PU.frame.pages.hunt
  local c = pg and pg.card
  local e = c and c.candList and c.candList[i]
  if not (e and ns.Hunt) then return end
  if c.ui.tile then
    ns.Hunt.Add(e.id, nil, { tile = c.ui.tile })
    c.ui.tile = nil
    PU.Refresh()
  else
    PU.HuntResult(ns.Hunt.Add(e.id))   -- recherche du bas : la case se range toute seule
  end
end

function PU.RefreshHunt(p)
  p = p or (PU.frame and PU.frame.pages.hunt)
  if not p then return end
  local c, pal, H = p.card, PU.Pal(), ns.Hunt
  if not H then return end
  for _, eb in ipairs({ c.link, c.search }) do
    if eb and eb.bg then Paint(eb.bg, pal.track) PaintEdge(eb.edge, PU.native and { BRONZE[1], BRONZE[2], BRONZE[3], 0.9 } or pal.accentHi) end
  end
  local list = H.List()
  local byTile = H.ByTile()
  local seg = PU.SegColors()
  -- grille d'équipement
  for _, b in ipairs(c.tiles) do
    local it = byTile[b.tile[1]]
    b.item = it
    Paint(b.bg, pal.track)
    local sel = (c.ui.tile == b.tile[1])
    PaintEdge(b.edge, sel and pal.accentHi or ((it and it.drops > 0) and pal.good or pal.buttonEdge))
    if it then
      b.icon:SetTexture(H.Icon(it.id)) b.icon:Show() b.lab:Hide()
      b.ok:SetText(it.drops > 0 and "✓" or "") TextColor(b.ok, pal.good)
    else
      b.icon:Hide() b.lab:Show() b.ok:SetText("")
    end
  end
  c.msg:SetText((c.msg:GetText() or "") ~= "" and c.msg:GetText() or Tr["Tape le nom d'un objet ici, ou clique une case de l'équipement."])
  -- 3.12.1 : choix d'un objet : la case cliquée (son emplacement) ou la recherche du bas (tous emplacements) ;
  -- toute la liste, qui défile à la molette (avant : 7 résultats et « précise la recherche »)
  local q = c.ui.q or ""
  if c.ui.tile or #q >= 2 then
    local tile
    for _, t in ipairs(H.TILES) do if t[1] == c.ui.tile then tile = t end end
    c.hint:Hide() c.empty:Hide()
    for _, e in ipairs(c.rows) do e.name:Hide() e.info:Hide() e.del:Hide() e.bar.track:Hide() e.bar.fill:Hide() end
    if tile then
      c.pickTitle:SetText(Tr["Choisir : "] .. H.TileLabel(tile))
      c.pickTitle:Show() c.search:Show() c.mineBtn:Show() c.backBtn:Show()
      c.mineBtn.fs:SetText(c.ui.mine and Tr["Armure : classe"] or Tr["Armure : toutes"])
    else
      c.pickTitle:SetText(Tr["Résultats : "] .. q)
      c.pickTitle:Show() c.search:Hide() c.mineBtn:Hide() c.backBtn:Hide()
    end
    if not H.HasSource() then
      c.candList = {}
      c.empty:SetText(tile and Tr["Pour choisir dans une liste, installe l'addon Dungeon Journal. Sinon, tape un nom ou colle un lien ci-dessous."]
        or Tr["Sans l'addon Dungeon Journal : Entrée ajoute l'objet par son nom, ou Maj+clic sur un objet."])
      c.empty:Show()
      for _, b in ipairs(c.cands) do b:Hide() end
      return
    end
    local all, total = H.Candidates(tile and tile[3], tile and c.ui.search or q, tile and c.ui.mine or false)
    total = total or #all
    c.candTotal = total
    local off = math.max(0, math.min(c.ui.coff or 0, math.max(0, total - #c.cands)))
    c.ui.coff = off
    local res = {}
    for i = 1, #c.cands do res[i] = all[off + i] end
    c.candList = res
    for i, b in ipairs(c.cands) do
      local e = res[i]
      if e then
        local s1 = e.src[1]
        b.fs:SetText(string.format("%s  —  %s · %s%s", H.DisplayName(e.id, e.name), tostring(H.LocBoss(s1.boss)), tostring(H.LocDungeon(s1.dungeon)),
          #e.src > 1 and (" +" .. (#e.src - 1)) or ""))
        b:Show()
      else
        b:Hide()
      end
    end
    if total == 0 then
      c.empty:SetText(tile and Tr["Aucun objet trouvé. Essaie « Armure : toutes » ou une autre recherche."]
        or Tr["Aucun objet de donjon trouvé : Entrée ajoute l'objet par son nom."])
      c.empty:Show()
    else
      c.empty:Hide()
      if total > #c.cands then c.msg:SetText(string.format(Tr["%d–%d sur %d · molette pour défiler"], off + 1, math.min(total, off + #c.cands), total)) end
    end
    return
  end
  -- liste suivie
  c.pickTitle:Hide() c.search:Hide() c.mineBtn:Hide() c.backBtn:Hide()
  for _, b in ipairs(c.cands) do b:Hide() end
  c.hint:Show()
  c.hint:SetText(H.HasSource() and Tr["Clique une case de l'équipement pour choisir l'objet à chasser."]
    or Tr["Ajoute des objets par nom ou lien (installe Dungeon Journal pour les choisir par emplacement)."])
  c.empty:SetText(#list == 0 and Tr["Aucun objet suivi pour l'instant."] or "")
  c.empty:Show()
  for i, e in ipairs(c.rows) do
    local it = list[i + c.ui.offset]
    e.idx = it and it.i or nil
    if it then
      local ch = H.Chance({ rate = it.rate, attempts = it.attempts })
      local info = PU.Tries(it.attempts, it.drops)
      if it.boss then info = tostring(H.LocBoss(it.boss)) .. " · " .. info end
      if ch then info = info .. string.format(" · " .. Tr["chance %d %%"], math.floor(ch * 100 + 0.5)) end
      PU.SetClipped(e.info, info, math.floor(HW * 0.5))
      -- 3.12.1 : le donjon à côté du nom, en gris, dans la place vraiment libre à gauche du texte de droite ;
      -- en manque de place : l'aile seule (« Cathédrale » pour « Monastère Écarlate : Cathédrale »), sinon rien
      local base = it.i .. ". " .. tostring(it.name)
      local room = HW
      if e.info.GetStringWidth then
        local okW, iw = pcall(e.info.GetStringWidth, e.info)
        if okW and type(iw) == "number" then room = HW - iw - 24 end
      end
      local dun = (it.dungeon and it.dungeon ~= "") and tostring(it.dungeon) or nil
      local function fits(txt)
        e.name:SetText(txt)
        if not e.name.GetStringWidth then return true end
        local ok, sw = pcall(e.name.GetStringWidth, e.name)
        return not (ok and sw and sw > room)
      end
      local short = dun and (dun:match(":%s*(.+)$") or dun:match(" – (.+)$") or dun:match(" %- (.+)$"))
      if not (dun and fits(base .. "  |cff8a8a8a" .. dun .. "|r"))
        and not (short and short ~= dun and fits(base .. "  |cff8a8a8a" .. short .. "|r")) then
        e.name:SetText(base)
      end
      PU.SetBar(e.bar, ch or (it.drops > 0 and 1 or 0), it.drops > 0 and pal.good or pal.bar)
      e.name:Show() e.info:Show() e.del:Show() e.bar.track:Show()
      if e.del.fs then e.del.fs:SetText(PU.IsArmed("row:" .. tostring(e.idx)) and "?" or "x") end
    else
      e.name:Hide() e.info:Hide() e.bar.track:Hide() e.bar.fill:Hide() e.del:Hide()
    end
  end
end

-- Onglet Collection (endgame) : un vrai log. Liste à sous-titres à gauche, objets à droite -------
local LOG_LROWS, LOG_RLINES, LOG_PERROW = 13, 8, 14
-- 3.10.0 : couleur de survol unique de la collection (voile doré léger, ne cache jamais le texte)
PU.HOVER = { 1, 0.85, 0.45, 0.10 }
-- 3.10.0 : barre de défilement du volet de droite : visible seulement si la liste dépasse
function PU.SetRScroll(c, total)
  local tr = c and c.rtrack
  if not tr then return end
  total = tonumber(total) or 0
  tr.total = total
  if total <= LOG_RLINES then tr:Hide() return end
  local pal = PU.Pal()
  Paint(tr.bg, pal.line1 or pal.grid or { 1, 1, 1, 0.06 })
  Paint(tr.thumb, pal.bar or pal.title or { 0.9, 0.75, 0.3, 0.9 })
  local th = math.max(14, tr.h * LOG_RLINES / total)
  local frac = (c.ui.rOff or 0) / math.max(1, total - LOG_RLINES)
  tr.thumb:ClearAllPoints()
  tr.thumb:SetSize(6, th)
  tr.thumb:SetPoint("TOP", tr, "TOP", 0, -math.floor(frac * (tr.h - th) + 0.5))
  tr:Show()
end
-- rang actuel d'une case métier (snapshot du panneau)
function PU.SkillRank(id)
  local snap = ns.UI and ns.UI.snapshot
  for _, t in ipairs((snap and (snap.allTiles or snap.tiles)) or {}) do
    if t.id == id then return tonumber(t.current) or 0 end
  end
  return 0
end
function PU.BuildCollection(f)
  local p = Page(f, "collection")
  local c = PU.Card(p, 0, 0, PU.CONTENT_W, PU.CONTENT_H, "")
  p.card = c
  c.ui = { sel = nil, lOff = 0, rOff = 0 }
  c.title:SetText("")
  c.lhead = FS(c, "GameFontNormalSmall", "label")
  c.lhead:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -8)
  c.lhead:SetText(Tr["Collection"])
  -- 3.9.0 : tri des donjons (par niveau, ou les plus avancés d'abord) ; gardé d'une session à l'autre
  c.sortBtn = PU.Button(c, 70, 16, "", "small", function()
    local ui = ns.db and ns.db.ui
    -- 3.10.0 : « x and nil or y » donnait toujours y : le tri restait bloqué sur %
    if ui then if ui.logSort == "pct" then ui.logSort = nil else ui.logSort = "pct" end end
    PU.RefreshCollection()
  end)
  c.sortBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 120, -5)
  -- 3.9.0 : partage de la page affichée dans le chat (texte inséré, tu valides avec Entrée)
  c.shareBtn = PU.Button(c, 70, 16, Tr["Partager"], "small", function() PU.ShareCollection() end)
  -- séparateur vertical
  c.sep = Tex(c, "ARTWORK", 1)
  Place(c.sep, c, 196, 6, 1, PU.CONTENT_H - 12)
  -- liste de gauche (sous-titres + entrées)
  c.lrows = {}
  for i = 1, LOG_LROWS do
    local b = CreateFrame("Button", nil, c)
    b:SetSize(184, 19)
    b:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -(24 + (i - 1) * 21))
    b.bg = Tex(b, "BACKGROUND", 1) b.bg:SetAllPoints(b)
    -- 3.10.0 : survol commun à toute la collection (gauche, en-têtes, recettes)
    b.hov = Tex(b, "BACKGROUND", 2) b.hov:SetAllPoints(b) Paint(b.hov, PU.HOVER) b.hov:Hide()
    b.fs = FS(b, "GameFontHighlightSmall", "text")
    b.fs:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.fs:SetWidth(132)
    if b.fs.SetJustifyH then b.fs:SetJustifyH("LEFT") end
    b:SetScript("OnEnter", function(self)
      if self.entry or self.head then self.hov:Show() end
      local tt = _G.GameTooltip
      local nm = self.entry and self.entry.label
      if tt and nm and tt.SetOwner then pcall(tt.SetOwner, tt, self, "ANCHOR_RIGHT") tt:AddLine(nm, 1, 1, 1) tt:Show() end
    end)
    b:SetScript("OnLeave", function(self) self.hov:Hide() if _G.GameTooltip then _G.GameTooltip:Hide() end end)
    b.val = FS(b, "GameFontNormalSmall", "title")
    b.val:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.bar = PU.NewBar(b, 6, 17, 172, 2)   -- 3.9.0 : progression du donjon, sous le nom
    b:SetScript("OnClick", function(self)
      if self.entry then c.ui.sel = self.entry.key c.ui.rOff = 0 PU.RefreshCollection()
      elseif self.head then
        -- ouvrir / fermer une catégorie (réglage du compte, gardé d'une session à l'autre)
        local ui = ns.db and ns.db.ui
        if ui then
          ui.logFold = type(ui.logFold) == "table" and ui.logFold or {}
          ui.logFold[self.head] = (not ui.logFold[self.head]) or nil
        end
        PU.RefreshCollection()
      end
    end)
    c.lrows[i] = b
  end
  -- volet de droite
  local RX, RW = 206, PU.CONTENT_W - 206 - 10
  c.rtitle = FS(c, "GameFontNormalLarge", "title")
  c.rtitle:SetPoint("TOPLEFT", c, "TOPLEFT", RX, -8)
  c.rtitle:SetWidth(RW - 120)
  if c.rtitle.SetJustifyH then c.rtitle:SetJustifyH("LEFT") end
  c.rcount = FS(c, "GameFontNormal", "text")
  c.rcount:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -10)
  c.shareBtn:SetPoint("RIGHT", c.rcount, "LEFT", -8, 0)
  if c.rcount.SetJustifyH then c.rcount:SetJustifyH("RIGHT") end
  c.rbar = PU.NewBar(c, RX, 32, RW, 5)
  c.rlines = {}
  for i = 1, LOG_RLINES do
    local y = 44 + (i - 1) * 33
    local ln = {}
    ln.fs = FS(c, "GameFontNormalSmall", "label")
    ln.fs:SetPoint("TOPLEFT", c, "TOPLEFT", RX, -(y + 8))
    ln.fs:SetWidth(RW - 60)
    if ln.fs.SetJustifyH then ln.fs:SetJustifyH("LEFT") end
    ln.val = FS(c, "GameFontNormalSmall", "title")
    ln.val:SetPoint("TOPRIGHT", c, "TOPRIGHT", -16, -(y + 8))
    if ln.val.SetJustifyH then ln.val:SetJustifyH("RIGHT") end
    ln.icons = {}
    for k = 1, LOG_PERROW do
      local b = CreateFrame("Button", nil, c)
      b:SetSize(28, 28)
      b:SetPoint("TOPLEFT", c, "TOPLEFT", RX + (k - 1) * 31, -(y + 2))
      b.icon = Tex(b, "ARTWORK", 2)
      b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
      b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
      b.edge = Edge(b)
      b:SetScript("OnEnter", function(self)
        local tt = _G.GameTooltip
        if not (tt and self.id) then return end
        if tt.SetOwner then pcall(tt.SetOwner, tt, self, "ANCHOR_RIGHT") end
        local ok = tt.SetHyperlink and pcall(tt.SetHyperlink, tt, "item:" .. tostring(self.id))
        if not ok then tt:AddLine(tostring(self.nm or self.id), 1, 1, 1) end
        tt:AddLine(self.got and Tr["Obtenu"] or Tr["Pas encore obtenu"], self.got and 0.4 or 0.7, self.got and 1 or 0.7, self.got and 0.4 or 0.7)
        tt:AddLine(self.got and Tr["Clic droit : retirer du log"] or Tr["Clic droit : marquer obtenu"], 0.6, 0.6, 0.6)
        tt:Show()
      end)
      -- 3.11.1 : clic droit = corriger le log à la main (obtenu / pas obtenu)
      if b.RegisterForClicks then pcall(b.RegisterForClicks, b, "RightButtonUp") end
      b:SetScript("OnClick", function(self, btn)
        local Hn = ns.Hunt
        if btn ~= "RightButton" or not self.id or not (Hn and Hn.SetOwned) then return end
        if Hn.SetOwned(self.id, not self.got) then
          if _G.GameTooltip then _G.GameTooltip:Hide() end
          PU.RefreshCollection()
        end
      end)
      b:SetScript("OnLeave", function() if _G.GameTooltip then _G.GameTooltip:Hide() end end)
      ln.icons[k] = b
    end
    -- 3.10.0 : zone cliquable des en-têtes de tranche (recettes), cachée sinon
    local hit = CreateFrame("Button", nil, c)
    -- 3.10.0 : la bande de survol va jusqu'à la barre de défilement
    hit:SetHeight(22)
    hit:SetPoint("TOPLEFT", c, "TOPLEFT", RX - 4, -(y + 3))
    hit:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    hit.hl = Tex(hit, "BACKGROUND", 1) hit.hl:SetAllPoints(hit) Paint(hit.hl, PU.HOVER) hit.hl:Hide()
    hit:SetScript("OnEnter", function(self)
      self.hl:Show()
      -- ligne de recette : nom complet (peut être coupé) et source
      if self.tipTitle then
        local tt = _G.GameTooltip
        if tt and tt.SetOwner then
          pcall(tt.SetOwner, tt, self, "ANCHOR_RIGHT")
          tt:AddLine(self.tipTitle, 1, 1, 1)
          if self.tipText and self.tipText ~= "" then tt:AddLine(self.tipText, 0.85, 0.85, 0.85, true) end
          tt:Show()
        end
      end
    end)
    hit:SetScript("OnLeave", function(self) self.hl:Hide() if _G.GameTooltip then _G.GameTooltip:Hide() end end)
    hit:SetScript("OnClick", function(self)
      local ui = ns.db and ns.db.ui
      if not (ui and self.skill and self.head) then return end
      ui.recipeFold = type(ui.recipeFold) == "table" and ui.recipeFold or {}
      ui.recipeFold[self.skill] = type(ui.recipeFold[self.skill]) == "table" and ui.recipeFold[self.skill] or {}
      ui.recipeFold[self.skill][self.head] = not self.open
      PU.RefreshCollection()
    end)
    hit:Hide()
    ln.hit = hit
    c.rlines[i] = ln
  end
  -- 3.10.0 : barre de défilement fine du volet de droite (molette ou clic-glisser)
  local trackH = LOG_RLINES * 33 - 6
  c.rtrack = CreateFrame("Button", nil, c)
  c.rtrack:SetSize(6, trackH)
  c.rtrack:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2, -44)
  c.rtrack.bg = Tex(c.rtrack, "BACKGROUND", 1) c.rtrack.bg:SetAllPoints(c.rtrack)
  c.rtrack.thumb = Tex(c.rtrack, "ARTWORK", 2)
  c.rtrack.h = trackH
  local function DragTo(self)
    local total = self.total or 0
    if total <= LOG_RLINES then return end
    local _, cy = _G.GetCursorPosition()
    local scale = (self.GetEffectiveScale and self:GetEffectiveScale()) or 1
    local top = (self.GetTop and self:GetTop()) or 0
    local frac = math.max(0, math.min(1, (top - cy / scale) / self.h))
    local off = math.floor(frac * (total - LOG_RLINES) + 0.5)
    if off ~= c.ui.rOff then c.ui.rOff = off PU.RefreshCollection() end
  end
  -- 3.10.0 : le glisser s'arrête dès que le bouton est relâché, même hors de la barre
  local function DragUpdate(self)
    local down = _G.IsMouseButtonDown
    if type(down) == "function" and not down("LeftButton") then self:SetScript("OnUpdate", nil) return end
    DragTo(self)
  end
  c.rtrack:SetScript("OnMouseDown", function(self) DragTo(self) self:SetScript("OnUpdate", DragUpdate) end)
  c.rtrack:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
  c.rtrack:Hide()
  c.rfoot = FS(c, "GameFontDisableSmall", "sub")
  c.rfoot:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", RX, 8)
  c.rfoot:SetWidth(RW)
  if c.rfoot.SetJustifyH then c.rfoot:SetJustifyH("LEFT") end
  c.rstat = FS(c, "GameFontHighlightSmall", "sub")
  c.rstat:SetPoint("TOPLEFT", c, "TOPLEFT", RX, -50)
  c.rstat:SetWidth(RW)
  c.rempty = FS(c, "GameFontDisableSmall", "sub")
  c.rempty:SetPoint("TOPLEFT", c, "TOPLEFT", RX, -50)
  c.rempty:SetWidth(RW)
  if c.rempty.SetWordWrap then pcall(c.rempty.SetWordWrap, c.rempty, true) end
  -- page d'accueil : vue d'ensemble (chiffres clés, progression par catégorie, presque terminés)
  c.hkpi = FS(c, "GameFontHighlightSmall", "sub")
  c.hkpi:SetPoint("TOPLEFT", c, "TOPLEFT", RX, -48)
  c.hkpi:SetWidth(RW)
  if c.hkpi.SetJustifyH then c.hkpi:SetJustifyH("LEFT") end
  c.hlab1 = FS(c, "GameFontNormalSmall", "label")
  c.hlab1:SetPoint("TOPLEFT", c, "TOPLEFT", RX, -72)
  c.hlab1:SetText(Tr["Progression par catégorie · clic pour ouvrir"])
  c.hlab2 = FS(c, "GameFontNormalSmall", "label")
  c.hlab2:SetPoint("TOPLEFT", c, "TOPLEFT", RX, -222)
  c.hlab2:SetText(Tr["Les plus avancés"])
  local function HomeRow(y)
    local b = CreateFrame("Button", nil, c)
    b:SetSize(RW, 20)
    b:SetPoint("TOPLEFT", c, "TOPLEFT", RX, -y)
    b.fs = FS(b, "GameFontHighlightSmall", "text")
    b.fs:SetPoint("LEFT", b, "LEFT", 4, 0)
    b.fs:SetWidth(170)
    if b.fs.SetJustifyH then b.fs:SetJustifyH("LEFT") end
    b.bar = PU.NewBar(b, 180, 7, RW - 180 - 84, 6)
    b.val = FS(b, "GameFontNormalSmall", "title")
    b.val:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    if b.val.SetJustifyH then b.val:SetJustifyH("RIGHT") end
    b.hl = Tex(b, "BACKGROUND", 1) b.hl:SetAllPoints(b)
    b:SetScript("OnEnter", function(self) local pal = PU.Pal() Paint(self.hl, pal.cardHi or { 1, 1, 1, 0.07 }) end)
    b:SetScript("OnLeave", function(self) Paint(self.hl, { 0, 0, 0, 0 }) end)
    b:SetScript("OnClick", function(self)
      if not self.target then return end
      local ui = ns.db and ns.db.ui
      if ui and type(ui.logFold) == "table" and self.targetHead then ui.logFold[self.targetHead] = nil end
      c.ui.sel = self.target c.ui.rOff = 0 PU.RefreshCollection()
    end)
    return b
  end
  c.hcat, c.halm = {}, {}
  for i = 1, 6 do c.hcat[i] = HomeRow(88 + (i - 1) * 22) end
  for i = 1, 3 do c.halm[i] = HomeRow(238 + (i - 1) * 22) end
  c:EnableMouseWheel(true)
  c:SetScript("OnMouseWheel", function(self, delta)
    local x = (_G.GetCursorPosition and select(1, _G.GetCursorPosition())) or 0
    local scale = (self.GetEffectiveScale and self:GetEffectiveScale()) or 1
    local left = (self.GetLeft and self:GetLeft()) or 0
    local inLeft = (x / scale - left) < 196
    if inLeft then c.ui.lOff = math.max(0, c.ui.lOff - (N(delta) or 0)) else c.ui.rOff = math.max(0, c.ui.rOff - (N(delta) or 0)) end
    PU.RefreshCollection()
  end)
  return p
end

-- 3.9.0 : « [Dropamine] Collection Log · Shadowfang Keep 12/39 (31 %) » inséré dans le chat
function PU.CollectionShareText(e)
  if not (e and e.y and e.y > 0) then return nil end
  local pct = math.floor(math.min(1, e.x / e.y) * 100 + 0.5)
  return string.format(Tr["[Dropamine] Collection Log · %s %d/%s%d (%d %%)"], tostring(e.label), e.x, e.approx and "≈" or "", e.y, pct)
end
function PU.ShareCollection()
  local p = PU.frame and PU.frame.pages and PU.frame.pages.collection
  local e = p and p.card and p.card.ui and p.card.ui.cur
  local text = PU.CollectionShareText(e)
  if not text then return false end
  local eb = type(_G.ChatEdit_GetActiveWindow) == "function" and _G.ChatEdit_GetActiveWindow()
  if type(eb) == "table" and eb.Insert then pcall(eb.Insert, eb, text) return true end
  if type(_G.ChatFrame_OpenChat) == "function" then pcall(_G.ChatFrame_OpenChat, text) return true end
  return false
end

-- Accueil du collection log : total, chiffres clés, une barre par catégorie, donjons presque terminés.
function PU.RefreshCollectionHome(c, secs, pal, H)
  local tx, ty, kills, full, nd = 0, 0, 0, 0, 0
  local almost = {}
  local cats = {}
  for _, sec in ipairs(secs) do
    local sx, sy, first = 0, 0, nil
    for _, e in ipairs(sec.entries) do
      if not e.stat then
        sx, sy = sx + e.x, sy + e.y
        first = first or e.key
        nd = nd + 1
        if e.y > 0 and e.x >= e.y then full = full + 1
        elseif e.x > 0 then e.head = sec.header almost[#almost + 1] = e end
        for _, b in ipairs(e.bosses or {}) do kills = kills + (b.kills or 0) end
      end
    end
    tx, ty = tx + sx, ty + sy
    if first and sy > 0 then cats[#cats + 1] = { label = sec.header, x = sx, y = sy, key = first, head = sec.header } end
  end
  c.rtitle:SetText(Tr["Vue d'ensemble"])
  local frac = ty > 0 and (tx / ty) or 0
  c.rcount:SetText(ty > 0 and string.format("%d / %d · %d %%", tx, ty, math.floor(frac * 100 + 0.5)) or "")
  PU.SetBar(c.rbar, frac, pal.bar)
  if ty == 0 then
    c.rempty:SetText(H.HasSource() and Tr["Rien à afficher pour l'instant."] or Tr["Installe l'addon Dungeon Journal pour voir les objets de donjon. Les statistiques restent disponibles."])
    c.rempty:Show()
    return
  end
  c.hkpi:SetText(string.format(Tr["Donjons complets : %d / %d"], full, nd) .. "   ·   " .. (kills > 0 and (string.format(Tr["Boss tués ≈ %d"], kills) .. "   ·   ") or "") .. string.format(Tr["Objets : %d / %d"], tx, ty))
  c.hkpi:Show() c.hlab1:Show()
  for i, b in ipairs(c.hcat) do
    local ct = cats[i]
    if ct then
      local f = ct.x / ct.y
      PU.SetClipped(b.fs, ct.label, 168)
      TextColor(b.fs, pal.text)
      PU.SetBar(b.bar, f, f >= 1 and pal.good or pal.bar)
      b.val:SetText(string.format("%d %%", math.floor(f * 100 + 0.5)))
      TextColor(b.val, f >= 1 and pal.good or pal.title or pal.text)
      b.target, b.targetHead = ct.key, ct.head
      Paint(b.hl, { 0, 0, 0, 0 })
      b:Show()
    end
  end
  table.sort(almost, function(a, b)
    local ra, rb = a.y - a.x, b.y - b.x
    if ra ~= rb then return ra < rb end
    return a.label < b.label
  end)
  if #almost > 0 then
    c.hlab2:Show()
    for i, b in ipairs(c.halm) do
      local e = almost[i]
      if e then
        PU.SetClipped(b.fs, e.label, 168)
        TextColor(b.fs, pal.text)
        PU.SetBar(b.bar, e.x / e.y, pal.bar)
        b.val:SetText(string.format(Tr["reste %d"], e.y - e.x))
        TextColor(b.val, pal.title or pal.text)
        b.target, b.targetHead = e.key, e.head
        Paint(b.hl, { 0, 0, 0, 0 })
        b:Show()
      end
    end
  end
end

function PU.RefreshCollection(p)
  p = p or (PU.frame and PU.frame.pages.collection)
  if not p then return end
  local c, pal, H = p.card, PU.Pal(), ns.Hunt
  if not H then return end
  pcall(H.ScanOwned)
  Paint(c.sep, pal.line1 or pal.grid)
  local secs = H.LogSections()
  if c.sortBtn then
    local pct = ns.db and ns.db.ui and ns.db.ui.logSort == "pct"
    c.sortBtn.fs:SetText(pct and Tr["Tri : %"] or Tr["Tri : niveau"])
    PU.PaintButton(c.sortBtn)
  end
  c.ui.curSecs = secs
  -- liste aplatie : sous-titres + entrées
  local flat, byKey = {}, {}
  flat[1] = { entry = { key = "home", label = Tr["Accueil"], home = true, x = 0, y = 0 } }
  byKey.home = flat[1].entry
  local fold = (ns.db and ns.db.ui and type(ns.db.ui.logFold) == "table") and ns.db.ui.logFold or {}
  for _, sec in ipairs(secs) do
    local sx, sy, anyDj = 0, 0, false
    for _, e in ipairs(sec.entries) do if not e.stat then sx, sy, anyDj = sx + e.x, sy + e.y, true end end
    local folded = fold[sec.header] and true or false
    flat[#flat + 1] = { head = sec.header, folded = folded, tally = (anyDj and sy > 0) and (sx .. "/" .. sy) or "" }
    for _, e in ipairs(sec.entries) do
      byKey[e.key] = e
      if not folded then flat[#flat + 1] = { entry = e } end
    end
  end
  if not (c.ui.sel and byKey[c.ui.sel]) then c.ui.sel = "home" end
  c.ui.lOff = math.min(c.ui.lOff, math.max(0, #flat - LOG_LROWS))
  for i, b in ipairs(c.lrows) do
    local it = flat[i + c.ui.lOff]
    if not it then b:Hide() else
      b:Show()
      b.entry, b.head = it.entry, it.head
      if b.bar then b.bar.track:Hide() b.bar.fill:Hide() end
      if it.head then
        b.fs:SetWidth(118)
        PU.SetClipped(b.fs, (it.folded and "+ " or "- ") .. it.head, 116)
        TextColor(b.fs, pal.title or pal.text)
        b.val:SetText(it.tally or "") TextColor(b.val, pal.text)
        Paint(b.bg, { 0, 0, 0, 0 })
      else
        local e = it.entry
        b.fs:SetWidth(132)
        PU.SetClipped(b.fs, e.label, 130)
        local done = e.y and e.y > 0 and e.x >= e.y
        b.val:SetText(e.home and "" or ((e.y and e.y > 0) and (e.x .. "/" .. (e.approx and "≈" or "") .. e.y) or tostring(e.x)))
        TextColor(b.fs, pal.text)
        TextColor(b.val, done and pal.good or pal.title or pal.text)
        Paint(b.bg, (e.key == c.ui.sel) and (pal.pillOn or pal.accent) or { 0, 0, 0, 0 })
        if b.bar and not e.home and e.y and e.y > 0 then
          PU.SetBar(b.bar, e.x / e.y, done and pal.good or nil)
          b.bar.track:Show()
        end
      end
    end
  end
  local e = c.ui.sel and byKey[c.ui.sel]
  for _, ln in ipairs(c.rlines) do
    ln.fs:Hide() ln.val:Hide()
    for _, b in ipairs(ln.icons) do b:Hide() end
    if ln.hit then ln.hit:Hide() end
  end
  c.rstat:Hide() c.rempty:Hide() c.rfoot:Hide()
  PU.SetRScroll(c, 0)
  c.hkpi:Hide() c.hlab1:Hide() c.hlab2:Hide()
  for _, b in ipairs(c.hcat) do b:Hide() end
  for _, b in ipairs(c.halm) do b:Hide() end
  c.ui.cur = e
  if c.shareBtn then
    if e and not e.home and e.y and e.y > 0 then c.shareBtn:Show() PU.PaintButton(c.shareBtn) else c.shareBtn:Hide() end
  end
  if e and e.home then PU.RefreshCollectionHome(c, secs, pal, H) return end
  if not e then
    c.rtitle:SetText(Tr["Collection"]) c.rcount:SetText("") PU.SetBar(c.rbar, 0)
    c.rempty:SetText(H.HasSource() and Tr["Rien à afficher pour l'instant."] or Tr["Installe l'addon Dungeon Journal pour voir les objets de donjon. Les statistiques restent disponibles."])
    c.rempty:Show()
    return
  end
  c.rtitle:SetText(e.label)
  local frac = (e.y and e.y > 0) and math.min(1, e.x / e.y) or 0
  c.rcount:SetText((e.y and e.y > 0) and string.format(e.approx and "%d / ≈%d · %d %%" or "%d / %d · %d %%", e.x, e.y, math.floor(frac * 100 + 0.5)) or tostring(e.x))
  local seg = PU.SegColors()
  PU.SetBar(c.rbar, frac, e.stat and (seg[e.cat or 3] or seg[3]) or pal.bar)
  if e.stat then
    -- listes détaillées : recettes manquantes (Cuisine, Secourisme) et créatures par tranche de niveau
    local slines, note
    -- 3.10.0 : SkillUp Forever (facultatif) : toutes les recettes manquantes, source et autres personnages
    local full, fullWhy
    if e.skill and e.full and H.MissingRecipesFull then full, fullWhy = H.MissingRecipesFull(e.skill) end
    if full then
      slines = {}
      local SU = ns.SkillUp
      -- tranches de rang (Apprenti 1-75…), repliables ; par défaut seule la tranche du rang actuel est ouverte
      local byT = {}
      for _, m in ipairs(full) do
        local t = SU.TrancheOf(m.lvl)
        byT[t] = byT[t] or {}
        byT[t][#byT[t] + 1] = m
      end
      local cur = PU.SkillRank and PU.SkillRank(e.skill) or 0
      local curT = SU.TrancheOf(math.max(1, cur + 1))
      local ui = ns.db and ns.db.ui
      local folds = ui and type(ui.recipeFold) == "table" and ui.recipeFold[e.skill] or nil
      for t, tr in ipairs(SU.TRANCHES) do
        local list = byT[t]
        if list and #list > 0 then
          local open
          if folds and folds[t] ~= nil then open = folds[t] else open = (t == curT) end
          slines[#slines + 1] = { head = t, skill = e.skill, open = open, hi = (t == curT),
            text = (open and "– " or "+ ") .. string.format("%s (%d-%d)", Tr[tr[3]], tr[1], tr[2]),
            val = string.format(Tr["%d manquantes"], #list) }
          if open then
            for _, m in ipairs(list) do
              slines[#slines + 1] = { text = "   " .. m.name, rid = m.rid, lvl = m.lvl,
                lazy = function()
                  local src = (SU and SU.SourceText and SU.SourceText(m.rid)) or Tr["chargement…"]
                  local alt = SU and SU.KnownByAlt and SU.KnownByAlt(m.rid)
                  return string.format(Tr["niv. %d"], m.lvl) .. " · " .. src .. (alt and (" · " .. Tr["connue de "] .. alt) or "")
                end }
            end
          end
        end
      end
      if #slines == 0 then note = Tr["Toutes les recettes du métier sont apprises."] end
    elseif fullWhy == "noread" then
      note = Tr["Ouvre la fenêtre du métier une fois pour que Dropamine lise tes recettes."]
    elseif e.code then
      local miss, why = H.MissingRecipes(e.skill, e.code)
      if miss then
        slines = {}
        local SRC = { t = Tr["Entraîneur"], b = Tr["Appris de base"] }
        for _, m in ipairs(miss) do
          slines[#slines + 1] = { text = m.name, val = string.format(Tr["niv. %d"], m.lvl) .. " · " .. (SRC[m.src] or Tr["Butin, quête ou vendeur"]) }
        end
        if #slines == 0 then note = Tr["Toutes les recettes de la base sont apprises."] end
      elseif why == "noread" then
        note = Tr["Ouvre la fenêtre du métier une fois pour que Dropamine lise tes recettes."]
      end
    elseif e.kind then
      local sm = H.LevelSummary(e.kind)
      if sm then
        slines = {}
        local lvl = N(ns.GetPlayerLevel and ns.GetPlayerLevel()) or 0
        for _, b in ipairs(sm) do
          if b.y > 0 then slines[#slines + 1] = { text = string.format(Tr["Niveaux %d-%d"], b.lo, b.hi), val = string.format("%d / %d", b.x, b.y), hi = (lvl >= b.lo and lvl <= b.hi) } end
        end
      end
    end
    if not note and not slines and e.skill and not e.code then
      note = Tr["Recettes connues de ton personnage, lues dans la fenêtre du métier (ouvre-la pour les mettre à jour)."]
        .. "\n\n" .. Tr["Facultatif : installe SkillUp Forever pour la liste complète du métier et où trouver chaque recette."]
    end
    if slines and #slines > 0 then
      if e.kind then c.rfoot:SetText(Tr["Créatures rencontrées par tous tes personnages, sur le total connu de la base."]) c.rfoot:Show() end
      if full then
        local foot = Tr["Liste complète grâce à SkillUp Forever."]
        if ns.SkillUp.RichSources and not ns.SkillUp.RichSources() then foot = foot .. " " .. Tr["Sources plus précises avec Questie ou AtlasLoot."] end
        c.rfoot:SetText(foot) c.rfoot:Show()
      end
      c.ui.rOff = math.min(c.ui.rOff, math.max(0, #slines - LOG_RLINES))
      for i, ln in ipairs(c.rlines) do
        local l = slines[i + c.ui.rOff]
        if l then
          -- les sources ne sont lues que pour les lignes affichées
          local val = l.val
          if not val and l.lazy then local okL, v = pcall(l.lazy) val = okL and v or "" end
          ln.val:SetText(val) ln.fs:Show() ln.val:Show()
          -- 3.10.0 : le nom s'arrête avant la colonne de droite (« … », nom complet au survol)
          local vw = (ln.val.GetStringWidth and ln.val:GetStringWidth()) or 0
          local room = math.max(60, (PU.CONTENT_W - 206 - 10) - 16 - vw - 14)
          PU.SetClipped(ln.fs, l.text, room)
          local col = (l.hi or l.head) and (pal.title or pal.text) or pal.text
          TextColor(ln.fs, col)
          TextColor(ln.val, col)
          -- 3.10.0 : en-têtes de tranche cliquables (+ / –), survol et infobulle sur les lignes de recettes
          if ln.hit and (l.head or l.rid) then
            ln.hit.head, ln.hit.skill, ln.hit.open = l.head, l.skill, l.open
            ln.hit.tipTitle = l.rid and (tostring(l.text):gsub("^%s+", "")) or nil
            ln.hit.tipText = l.rid and val or nil
            ln.hit:Show()
          end
        end
      end
      PU.SetRScroll(c, #slines)
      return
    end
    c.rstat:SetText(note or Tr["Ce compteur se remplit en jouant : le scanner apprend les créatures, nœuds et recettes que tu rencontres."])
    c.rstat:Show()
    return
  end
  -- lignes de droite : un titre de boss, puis ses objets (14 par ligne)
  local lines = {}
  for _, b in ipairs(e.bosses) do
    local got = 0
    for _, it in ipairs(b.items) do if it.got then got = got + 1 end end
    lines[#lines + 1] = { boss = b.name, text = string.format("%d / %d", got, #b.items) .. ((b.kills or 0) > 0 and ("  ·  ≈" .. b.kills .. " " .. Tr["kills"]) or "") }
    for i = 1, #b.items, LOG_PERROW do
      local chunk = {}
      for k = i, math.min(i + LOG_PERROW - 1, #b.items) do chunk[#chunk + 1] = b.items[k] end
      lines[#lines + 1] = { items = chunk }
    end
  end
  c.ui.rOff = math.min(c.ui.rOff, math.max(0, #lines - LOG_RLINES))
  PU.SetRScroll(c, #lines)
  for i, ln in ipairs(c.rlines) do
    local l = lines[i + c.ui.rOff]
    if l and l.boss then
      ln.fs:SetText(l.boss) ln.val:SetText(l.text) ln.fs:Show() ln.val:Show()
      TextColor(ln.fs, pal.title or pal.text)
    elseif l and l.items then
      for k, b in ipairs(ln.icons) do
        local it = l.items[k]
        if it then
          b.id, b.nm, b.got = it.id, it.name, it.got
          b.icon:SetTexture(H.Icon(it.id))
          if b.icon.SetDesaturated then b.icon:SetDesaturated(not it.got) end
          b.icon:SetAlpha(it.got and 1 or 0.4)
          PaintEdge(b.edge, it.got and pal.good or pal.line1 or pal.grid)
          b:Show()
        end
      end
    end
  end
end

-- Changement de mode (route / endgame) : onglets recalculés, page valide.
function PU.OnModeChanged()
  local f = PU.frame
  if f then PU.LayoutTabs(f) end
  State()
  PU.Refresh()
end

-- 3.13.0 : habillage de la fenêtre. « jeu » = cadre à portrait du jeu (comme /drop hiscores) ;
-- « dropamine » = notre cadre d'avant, gardé intact (/drop progression cadre dropamine).
-- 3.13.0 : la fenêtre Progression (et les fenêtres de la visite / À propos) prend toujours le cadre du jeu ;
-- le thème (jeu / dropamine / léger) ne concerne que le panneau des cases et les toasts
function PU.FrameStyle() return "jeu" end
PU.native = true
local function NativeShell()
  local ok, f = pcall(CreateFrame, "Frame", PU.NAME, _G.UIParent, "PortraitFrameTemplate")
  if not (ok and f) then return nil end
  if type(f.SetTitle) == "function" then pcall(f.SetTitle, f, "Dropamine · " .. Tr["Progression"]) end
  local DW = ns.DebugWindow
  if DW and DW.DecoratePortrait then local okP, ic = pcall(DW.DecoratePortrait, f) if okP then f.portraitIcon = ic end end
  f.native = true
  return f
end
-- Après les en-têtes : le cadre du jeu a déjà titre, portrait et ✕ ; on range les nôtres
function PU.FitNative(f)
  if not f.native then return end
  if f.logo then f.logo:Hide() end
  if f.titleFS then f.titleFS:Hide() end
  if f.divider then f.divider:Hide() end   -- le filet doré passait sous les boutons descendus d'une ligne ; la carte du total sépare déjà
  if f.subFS then
    f.subFS:ClearAllPoints() f.subFS:SetPoint("LEFT", f, "TOPLEFT", 64, -40)
    local font = _G.GameFontHighlightLarge or _G.GameFontNormalLarge
    if font and f.subFS.SetFontObject then pcall(f.subFS.SetFontObject, f.subFS, font) end
    f.subFS._role = nil   -- couleur fixe (blanc), la classe est colorée dans le texte
    for i = #PU.texts, 1, -1 do if PU.texts[i][1] == f.subFS then table.remove(PU.texts, i) end end
  end
  local close = rawget(f, "CloseButton")
  if type(close) == "table" then
    if f.close then f.close:Hide() end
    if close.SetScript then close:SetScript("OnClick", function() PU.Close() end) end
    if f.share then f.share:ClearAllPoints() f.share:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -29) end
  elseif f.close then
    f.close:ClearAllPoints() f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -29)
  end
end

function PU.Build()
  if PU.frame then return PU.frame end
  if InCombat() then return nil end
  if type(_G.CreateFrame) ~= "function" then return nil end
  PU.cards, PU.buttons, PU.texts, PU.pillGroups, PU.charts, PU.curves = {}, {}, {}, {}, {}, {}
  local f = (PU.FrameStyle() == "jeu") and NativeShell() or CreateFrame("Frame", PU.NAME, _G.UIParent)
  PU.native = f.native == true
  f:SetSize(PU.W, PU.H)
  f:SetFrameStrata("DIALOG")   -- 3.13.0 : même étage que le Dungeon Journal (HIGH restait toujours dessous)
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
  if not f.native and Sk and Sk.Host and Sk.enabled ~= false then
    local ok, h = pcall(Sk.Host, f, true)
    if ok and h then f.skin = h end
  end
  f.pages = {}
  PU.frame = f
  PU.BuildHeader(f)
  PU.FitNative(f)
  PU.BuildBanner(f)
  PU.BuildTabs(f)
  PU.BuildOverview(f)
  PU.BuildCharts(f)
  PU.BuildAch(f)
  PU.BuildSpots(f)
  PU.BuildWeekly(f)
  PU.BuildEfficiency(f)
  PU.BuildChars(f)
  PU.BuildSkills(f)
  PU.BuildFarmNow(f)
  PU.BuildHunt(f)
  PU.BuildCollection(f)
  PU.BuildRecap(f)
  f.foot = FS(f, "GameFontDisableSmall", "sub", "CENTER")
  f.foot:SetPoint("BOTTOM", f, "BOTTOM", 0, 9)
  f.foot:SetText(Tr["Clic gauche sur la goutte ou /drop progression · Échap pour fermer"])
  f.subs = {
    overview = PU.Pills(f, { { id = "overview", label = "Aujourd'hui" }, { id = "charts", label = "Graphiques" }, { id = "weekly", label = "Semaine" } }, PU.W - PU.PAD, PU.VIEWS_Y,
      function() return State().tab end, function(id) PU.SetTab(id) end),
    collection = PU.Pills(f, { { id = "collection", label = "Carnet" }, { id = "hunt", label = "Chasse" } }, PU.W - PU.PAD, PU.VIEWS_Y,
      function() return State().tab end, function(id) PU.SetTab(id) end),
    farm = PU.Pills(f, { { id = "now", label = "Maintenant" }, { id = "spots", label = "Spots" }, { id = "efficiency", label = "Efficacité" } }, PU.W - PU.PAD, PU.VIEWS_Y,
      function() return State().tab end, function(id) PU.SetTab(id) end),
  }
  f.pageTitle = FS(f, "GameFontNormal", "title")
  f.pageTitle:SetPoint("TOPLEFT", f, "TOPLEFT", PU.PAD + 2, -(PU.VIEWS_Y + 3))
  f.pageDesc = FS(f, "GameFontHighlightSmall", "sub")
  f.pageDesc:SetPoint("LEFT", f.pageTitle, "RIGHT", 8, 0)
  f.pageLine = Tex(f, "ARTWORK", 1)
  f.pageLine:SetPoint("TOPLEFT", f, "TOPLEFT", PU.PAD, -(PU.VIEWS_Y + 23))
  f.pageLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PU.PAD, -(PU.VIEWS_Y + 23))
  f.pageLine:SetHeight(1)
  Paint(f.pageLine, { BRONZE[1], BRONZE[2], BRONZE[3], 0.6 })
  f:SetScript("OnShow", function(self) if self.Raise then self:Raise() end PU.OnShow() end)   -- 3.13.0 : rouverte = devant
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
  if f.native then
    -- cadre du jeu : son fond et sa bordure, rien de peint par-dessus
    if f.skin then f.skin:Hide() end
    f.flat:Hide()
    ShowEdge(f.edge, false)
  elseif pal.skin and f.skin and Sk then
    pcall(f.skin.SetBackdrop, f.skin, Sk.Backdrop(f.skin))
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
  local tri = pal.site and not f.native
  local seg = PU.SegColors()
  for i, t in ipairs(f.tri or {}) do
    if tri then Paint(t, seg[i]) t:Show() else t:Hide() end
  end
  if f.divider and not f.native then if tri then f.divider:Hide() else f.divider:Show() end end
  for _, c in ipairs(PU.cards) do PU.PaintCard(c, c._hi) end
  for _, b in ipairs(PU.buttons) do PU.PaintButton(b) end
  for _, e in ipairs(PU.texts) do
    local c = pal[e[2]]
    if c then TextColor(e[1], c) end
  end
  local eb = f.pages.overview and f.pages.overview.kpi[4].input
  if eb then Paint(eb.bg, pal.track) PaintEdge(eb.edge, PU.native and { BRONZE[1], BRONZE[2], BRONZE[3], 0.9 } or pal.accentHi) end
  local ach = f.pages.ach
  if ach then Paint(ach.thumbTrack, pal.track) Paint(ach.thumb, pal.accent) end
  local ov = f.pages.overview
  if ov then Paint(ov.right.k1, pal.line1) Paint(ov.right.k2, pal.line2) end
  local sp = f.pages.spots
  if sp then Paint(sp.card.line, pal.cardEdge) end
  for _, g in ipairs(f.banner.badges) do
    if PU.native then g.bg:Hide() ShowEdge(g.edge, false) else Paint(g.bg, pal.pillOff) PaintEdge(g.edge, pal.pillEdge) end
  end
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
  if f.bag then local SB = ns.SleepBag f.bag:SetShown(SB and SB.Has and SB.Has() or false) end
  local name = Call(_G.UnitName, "player") or "?"
  local cls = Call(_G.UnitClass, "player") or ""
  local lvl = N(ns.GetPlayerLevel and Call(ns.GetPlayerLevel)) or N(Call(_G.UnitLevel, "player")) or 0
  if f.native then
    -- cadre jeu : la classe dans sa couleur (comme la fiche du personnage)
    local _, file = Call(_G.UnitClass, "player")
    local cc = file and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[file]
    if cc then cls = string.format("|cff%02x%02x%02x%s|r", math.floor(cc.r * 255), math.floor(cc.g * 255), math.floor(cc.b * 255), tostring(cls)) end
  end
  f.subFS:SetText(string.format(Tr["%s · %s niv. %d"], tostring(name), tostring(cls), lvl))
  local snap = Snap()
  local cur = snap and (N(snap.total) or N(snap.ficTotal)) or N(ns.CharDB and ns.CharDB().lastTotal) or 0
  local mx = snap and (N(snap.totalMax) or N(snap.ficMax)) or N(ns.TOTAL_MAX) or 2460
  local b = f.banner
  b.totalFS:SetText(tostring(cur))
  b.maxFS:SetText("/ " .. tostring(mx))
  b.pctFS:SetText((mx > 0) and (string.format("%d %%", math.floor(cur / mx * 100 + 0.5))) or "")
  local pal = PU.Pal()
  if not b.gauge then Paint(b.track, pal.track) end
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
  if b.sheen then
    if x > 10 then b.sheen:ClearAllPoints() b.sheen:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -31) b.sheen:SetSize(x - 10, 1) b.sheen:Show() else b.sheen:Hide() end
  end
  local labels = { Tr["Niv."], Tr["Armes et Défense"], Tr["Métiers"] }
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
  if f._tabsEndgame ~= PU.Endgame() or f._tabsHunt ~= (not (ns.Hunt and ns.Hunt.On) or ns.Hunt.On()) then PU.LayoutTabs(f) end
  -- récap de session ouvert : aucun onglet n'est « actif » (le récap n'est pas un onglet) et les sélecteurs du bas se masquent
  local curGroup = nil
  if not State().recapOpen then curGroup = PU.GroupOf(State().tab) end
  for _, t in ipairs(f.tabs) do
    if t.id == "ach" then t.fs:SetText(Tr["Succès"] .. " (" .. got .. "/" .. all .. ")") end
    PU.SetOn(t, t.id == curGroup)
  end
  if f.pageTitle then
    local def
    for _, t in ipairs(PU.TABS) do if t.id == curGroup then def = t end end
    f.pageTitle:SetText(def and Tr[def.label] or "")
    f.pageDesc:SetText(def and def.desc and Tr[def.desc] or "")
    if def then f.pageLine:Show() else f.pageLine:Hide() end
  end
  -- sélecteurs de sous-page (bas à droite) : Graphiques/Hebdo et Spots/Efficacité
  if f.subs then
    -- Efficacité n'apparaît que lorsqu'il existe des mesures (30 jours) : sinon il ne reste que « Spots »
    local effOk = PU._effOk
    local nowT = (_G.GetTime and _G.GetTime()) or 0
    if effOk == nil or nowT - (PU._effAt or 0) > 5 then
      local E = ns.Efficiency
      local okR, rep = pcall(function() return E and E.Report and E.Report("d30") end)
      effOk = okR and type(rep) == "table" and (N(rep.total) or 0) >= ((E and E.MIN_SECS) or 60)
      PU._effOk, PU._effAt = effOk, nowT
    end
    if not effOk and State().farmSub == "efficiency" and State().tab == "efficiency" then PU.SetTab("now", true) end
    for gid, grp in pairs(f.subs) do
      for _, b in ipairs(grp.list) do
        local huntOff = ns.Hunt and ns.Hunt.On and not ns.Hunt.On()
        local hide = (gid ~= curGroup) or (gid == "farm" and b.id == "efficiency" and not effOk) or (gid == "collection" and b.id == "hunt" and huntOff)
        if hide then b:Hide() else b:Show() end
      end
      local x = PU.W - PU.PAD
      for _, b in ipairs(grp.list) do
        if b:IsShown() then
          x = x - ((b.GetWidth and b:GetWidth()) or 60)
          b:ClearAllPoints() b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -PU.VIEWS_Y)
          x = x - 4
        end
      end
    end
  end
end

function PU.RefreshOverview(p)
  local pal = PU.Pal()
  local r = P.Rates()
  local s = P.Session()
  local k = p.kpi
  -- 1. Rythme XP (masqué au niveau max ; lph = XP/h / UnitXPMax)
  local maxed = PU.AtMaxLevel and PU.AtMaxLevel()
  local huntOn = not (ns.Hunt and ns.Hunt.On) or ns.Hunt.On()
  local egAll = PU.Endgame() and ns.Hunt and ns.Hunt.List
  local eg = egAll and huntOn
  local hl = (eg and ns.Hunt.List()) or {}
  -- cartes cliquables en endgame : Chasse et Collection
  for i, tab in ipairs({ "hunt", "collection" }) do
    local kc = k[i]
    if not kc._link then
      kc._link = true
      kc:EnableMouse(true)
      kc:SetScript("OnMouseUp", function(self) if self._go then PU.SetTab(self._go) end end)
    end
    kc._go = egAll and (tab == "collection" or huntOn) and tab or nil
  end
  if eg and #hl == 0 then
    k[1].title:SetText(Tr["Chasse"])
    k[1].value:SetText(Tr["Choisir un objet"])
    k[1].sub:SetText(Tr["Clic : ouvrir la liste de chasse"])
    k[1].value._tipExtra, k[1].sub._tipExtra = nil, nil
  elseif #hl > 0 then
    -- endgame : la carte des rythmes d'XP devient « Chasse » (premier objet suivi)
    local it = hl[1]
    local ch = ns.Hunt.Chance({ rate = it.rate, attempts = it.attempts })
    k[1].title:SetText(Tr["Chasse"])
    PU.SetFittedText(k[1].value, { tostring(it.name) }, (k[1]._w or 150) - 16)
    k[1].sub:SetText(PU.Tries(it.attempts, it.drops) .. (ch and string.format(" · %d %%", math.floor(ch * 100 + 0.5)) or ""))
    k[1].value._tipExtra, k[1].sub._tipExtra = nil, nil
  elseif maxed then
    k[1].title:SetText(Tr["Niveau max"])
    k[1].value:SetText("—")
    k[1].sub:SetText(Tr["Les rythmes d'XP sont masqués au niveau maximum."])
    k[1].value._tipExtra, k[1].sub._tipExtra = nil, nil
  elseif r.xph and r.xph > 0 then
    k[1].title:SetText(Tr["Rythme XP"])
    k[1].value:SetText(Thousands(r.xph) .. Tr[" XP/h"])
    local lvl = N(ns.GetPlayerLevel and Call(ns.GetPlayerLevel)) or 0
    local parts = { Fmt2(r.pctLevelPerHour or ((r.lph or 0) * 100) or 0) .. Tr[" % niv./h"] }
    if r.etaLevel then parts[#parts + 1] = string.format(Tr["niv. %d ≈ %s"], lvl + 1, Dur(r.etaLevel)) end
    k[1].sub:SetText(table.concat(parts, " · "))
    local extra = {}
    if r.etaLevel then
      extra[#extra + 1] = string.format(Tr["Temps estimé pour le niveau %d : %s"], lvl + 1, Dur(r.etaLevel))
    end
    extra[#extra + 1] = Tr["Le rythme en % de niveau / h rend les sessions comparables d'un niveau à l'autre."]
    k[1].sub._fullText = table.concat(parts, " · ")
    k[1].sub._tipExtra = extra
    k[1].value._tipExtra = extra
  else
    k[1].title:SetText(Tr["Rythme XP"])
    k[1].value:SetText("—")
    k[1].sub:SetText((r.base or 0) < (P.MIN_RATE_SECS or 120) and Tr["mesure en cours…"] or Tr["pas d'XP cette session"])
  end
  -- 2. Rythme points
  if eg then
    local cx, cy = 0, 0
    if ns.Hunt.LogTotals then cx, cy = ns.Hunt.LogTotals() end
    k[2].title:SetText(Tr["Collection"])
    k[2].value:SetText(cy > 0 and string.format("%d / %d", cx, cy) or "—")
    k[2].sub:SetText(cy > 0 and string.format(Tr["%d %% des objets de donjon · clic : ouvrir"], math.floor(cx / cy * 100 + 0.5)) or Tr["Clic : ouvrir le collection log"])
  else
    k[2].title:SetText(Tr["Points de la session"])
  end
  if not eg then
    -- 3.13.0 : plus de points/heure (un métier monte bien plus vite au rang 50 qu'au rang 250) : le total, et la durée
    k[2].value:SetText(string.format(Tr["+%d pts"], s.pts or 0))
    k[2].sub:SetText(string.format(Tr["en %s · aujourd'hui +%d"], Dur(r.elapsed), N(P.DayPoints and P.DayPoints(P.Today())) or 0))
  end
  -- 3. Série & records
  local st = P.Streak()
  local R = P.Records()
  k[3].value:SetText(string.format(st.n == 1 and Tr["%d jour d'affilée"] or Tr["%d jours d'affilée"], st.n))
  local recLong = string.format(Tr["Max session +%d · Max heure +%d"], R.bestSession, R.bestHour)
  PU.SetFittedText(k[3].sub, {
    recLong,
    string.format(Tr["Sess. +%d · Heure +%d"], R.bestSession, R.bestHour),
  }, (k[3]._w or 0) - 16)
  local recTip = { recLong }
  if R.bestSessionAt then recTip[#recTip + 1] = Tr["Meilleure session"] .. " " .. (PU.FormatWhen(R.bestSessionAt) or "") end
  if R.bestHourAt then recTip[#recTip + 1] = Tr["Meilleure heure"] .. " " .. (PU.FormatWhen(R.bestHourAt) or "") end
  if (R.bestDay or 0) > 0 then recTip[#recTip + 1] = string.format(Tr["Meilleur jour : +%d"], R.bestDay) end
  if (R.longestCombo or 0) > 0 then recTip[#recTip + 1] = string.format(Tr["Plus long combo : %d"], R.longestCombo) end
  if (R.longestRun or 0) >= 60 then recTip[#recTip + 1] = string.format(Tr["Plus longue série active : %d min"], math.floor(R.longestRun / 60)) end
  if (R.bestHour or 0) > 0 then
    local hp = N(P.HourPoints and P.HourPoints()) or 0
    recTip[#recTip + 1] = string.format(Tr["Heure en cours : +%d (%d %% du record)"], hp, math.floor(hp / R.bestHour * 100 + 0.5))
  end
  k[3].sub._fullText = recLong
  k[3].sub._tipExtra = recTip
  k[3].value._tipExtra = recTip
  -- 4. Objectif
  local g = P.Goal()
  k[4].value:SetText(string.format(Tr["+%d / +%d pts"], g.pts, g.target))
  TextColor(k[4].value, g.reached and pal.good or pal.text)
  PU.SetBar(k[4].bar, g.pct, g.reached and pal.barHi or pal.bar)
  -- Aujourd'hui : total du jour, par catégorie, 7 derniers jours
  local items = PU.DayItems(7)
  local today = items[#items] or {}
  local yest = items[#items - 1]
  local L = p.left
  local tp = N(today.total) or 0
  L.hero:SetText("+" .. tp .. " " .. Tr["pts"])
  local week = 0
  for _, it in ipairs(items) do week = week + (N(it.total) or 0) end
  local sub = string.format(Tr["7 jours : +%d"], week)
  if yest then sub = string.format(Tr["hier +%d"], N(yest.total) or 0) .. " · " .. sub end
  L.heroSub:SetText(sub)
  local segc = PU.SegColors()
  local sg0 = (Snap() or {}).segments or {}
  local cats = {
    { (sg0[1] and sg0[1].label) or Tr["Niveau"], N(today.level) or 0, segc[1] },
    { (sg0[2] and sg0[2].label) or Tr["Armes et Défense"], N(today.combat) or 0, segc[2] },
    { (sg0[3] and sg0[3].label) or Tr["Métiers"], N(today.prof) or 0, segc[3] },
  }
  local cmax = 1
  for _, c3 in ipairs(cats) do cmax = math.max(cmax, c3[2]) end
  for i, e in ipairs(L.cats) do
    local c3 = cats[i]
    e.fs:SetText(c3[1]) e.v:SetText("+" .. c3[2])
    Paint(e.dot, c3[3])
    PU.SetBar(e.bar, c3[2] / cmax, c3[3])
  end
  local wmax = 1
  for _, it in ipairs(items) do wmax = math.max(wmax, N(it.total) or 0) end
  local plotH = 40
  for i, e in ipairs(L.week) do
    local it = items[i]
    if it then
      local v = N(it.total) or 0
      local h = (v > 0) and math.max(2, math.floor(plotH * v / wmax + 0.5)) or 1
      e.bar:ClearAllPoints()
      e.bar:SetPoint("BOTTOMLEFT", L, "BOTTOMLEFT", e.col, 20)
      e.bar:SetSize(26, h)
      Paint(e.bar, it.today and pal.barHi or pal.bar)
      e.bar:Show()
      e.lab:SetText(it.label or "")
      e.lab:Show()
      e.val:ClearAllPoints()
      e.val:SetPoint("BOTTOM", e.bar, "TOP", 0, 1)
      e.val:SetText(v > 0 and tostring(v) or "")
      e.val:Show()
    else
      e.bar:Hide() e.lab:Hide() e.val:Hide()
    end
  end
  -- palier + sources
  local R2, sn = p.right, Snap()
  local total = N(sn and (sn.total or sn.ficTotal)) or 0
  local tmax = N(sn and (sn.totalMax or sn.ficMax)) or ns.TOTAL_MAX or 0
  local passed, nextM, prevM = {}, nil, 0
  if ns.Milestones then passed, nextM = ns.Milestones(total, tmax) end
  prevM = passed[#passed] or 0
  R2.title:SetText(Tr["Prochain palier"])
  if nextM then
    R2.hero:SetText(string.format(Tr["%d  ·  encore %d pts"], nextM, nextM - total))
    PU.SetBar(R2.heroBar, (total - prevM) / math.max(1, nextM - prevM), pal.bar)
    local sub = string.format(Tr["Niveau total %d / %d"], total, tmax)
    if r.pph and r.pph > 0.5 then
      sub = sub .. " · " .. string.format(Tr["≈ %s à ce rythme"], Dur(((nextM - total) / r.pph) * 3600))
    end
    R2.heroSub:SetText(sub)
  else
    R2.hero:SetText(Tr["Tous les paliers atteints"])
    PU.SetBar(R2.heroBar, 1, pal.barHi)
    R2.heroSub:SetText(string.format(Tr["Niveau total %d / %d"], total, tmax))
  end
  local segs = (sn and sn.segments) or {}
  local seg = PU.SegColors()
  for i, e in ipairs(R2.src) do
    local sg = segs[i]
    if sg and N(sg.max) and N(sg.max) > 0 then
      local cur, mx = N(sg.cur) or 0, N(sg.max)
      e.fs:SetText(tostring(sg.label or "?"))
      e.n:SetText(string.format(Tr["%d / %d · reste %d"], cur, mx, math.max(0, mx - cur)))
      Paint(e.dot, seg[i] or seg[3])
      PU.SetBar(e.bar, cur / mx, seg[i] or seg[3])
      e.dot:Show() e.fs:Show() e.n:Show() e.bar.track:Show()
    else
      e.dot:Hide() e.fs:Hide() e.n:Hide() e.bar.track:Hide() e.bar.fill:Hide()
    end
  end
  -- bas : dernier succès, rentabilité / meilleur spot
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
  local E = ns.Efficiency
  local profit = E and E.Report and E.Report("session")
  profit = profit and profit.profit or nil
  local mix = profit and profit.bestMix
  local money = E and E.FormatMoney
  if mix then
    b2.head:SetText(Tr["Meilleur spot mixte"] .. " · " .. (mix.zone or "?"))
    local parts = {}
    if money and N(mix.goldPerHour) then parts[#parts + 1] = money(mix.goldPerHour, false) .. Tr[" /h"] end
    if N(mix.pctLevelPerHour) then parts[#parts + 1] = Fmt2(mix.pctLevelPerHour) .. Tr[" % niv./h"]
    elseif N(mix.gathersPerHour) then parts[#parts + 1] = Fmt1(mix.gathersPerHour) .. Tr[" pal./h"] end
    if money and profit.moneyNet ~= nil then parts[#parts + 1] = Tr["session"] .. " " .. money(profit.moneyNet, true) end
    b2.line:SetText(table.concat(parts, " · "))
    local tip = { E.ScoringTip and E.ScoringTip() or "", E.VendorTip and E.VendorTip() or "" }
    if profit.bestProg and profit.bestProg.zone then
      tip[#tip + 1] = Tr["Meilleur spot progression"] .. " : " .. profit.bestProg.zone
    end
    if profit.bestGold and profit.bestGold.zone then
      tip[#tip + 1] = Tr["Meilleur spot or"] .. " : " .. profit.bestGold.zone
    end
    b2.head._fullText = b2.head:GetText()
    b2.line._fullText = b2.line:GetText()
    b2.head._tipExtra, b2.line._tipExtra = tip, tip
    PU.BindTip(b2.head, b2.head._fullText, tip, (b2._w or 0) - 54)
    PU.BindTip(b2.line, b2.line._fullText, tip, (b2._w or 0) - 54)
  else
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
    b2.head._fullText = b2.head:GetText()
    b2.line._fullText = b2.line:GetText()
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
  Place(p.thumb, p, PU.CONTENT_W - 7, ty, 6, th)
  if maxY > 0 then p.thumb:Show() p.thumbTrack:Show() else p.thumb:Hide() p.thumbTrack:Hide() end
  if p.grab then if maxY > 0 then p.grab:Show() else p.grab:Hide() end end
  return p.scrollY
end

function PU.RefreshSpots(p)
  local c = p.card
  local pal = PU.Pal()
  local best = PU.BestSpots()
  for i, b in ipairs(p.best or {}) do
    local x = best[i]
    if x then
      b.skill:SetText(PU.SkillName(x.skill))
      b.zone:SetText(tostring(x.zone))
      b.rate:SetText(string.format(Tr["+%d pts · %s"], x.pts, (N(x.minutes) or 0) >= 1 and Dur(math.floor(x.minutes * 60)) or "—"))
      TextColor(b.rate, pal.text)
      if x.gold then b.gold:SetText(string.format(Tr["Or : %s /h"], PU.GoldStr(x.gold.gph))) b.gold2:SetText(tostring(x.gold.zone))
      else b.gold:SetText(Tr["Or : pas encore mesuré"]) b.gold2:SetText("") end
      b:Show()
    else b:Hide() end
  end
  local list = P.AllSpots()
  for i, r in ipairs(c.rows) do
    local z = list[i]
    if z then
      r.zone:SetText(z.zone .. ((z.sub and z.sub ~= z.zone) and (" · " .. z.sub) or ""))
      r.skill:SetText(PU.SkillName(z.skill))
      r.pts:SetText("+" .. z.pts)
      r.rate:SetText((N(z.minutes) or 0) >= 1 and Dur(math.floor(z.minutes * 60)) or "—")
      Paint(r.bg, (i % 2 == 1) and { 1, 1, 1, 0.035 } or { 0, 0, 0, 0 })
      if i == 1 then Paint(r.bg, pal.cardHi) end
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
  c.note:SetText(Tr["Trié par points gagnés dans la zone."] .. ((more > 0) and (" " .. string.format(Tr["+%d autres zones."], more)) or ""))
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
  local names = { Tr["Niveau"], Tr["Armes et Défense"], Tr["Métiers"] }
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

local function RateLine(s)
  local bits = {}
  if N(s.pctLevelPerHour) then
    bits[#bits + 1] = Fmt2(s.pctLevelPerHour) .. Tr[" % niv./h"]
  elseif N(s.gathersPerHour) then
    bits[#bits + 1] = Fmt1(s.gathersPerHour) .. Tr[" pal./h"]
  end
  if N(s.goldPerHour) then
    local E = ns.Efficiency
    local g = E and E.FormatMoney and E.FormatMoney(s.goldPerHour, false)
    if g then bits[#bits + 1] = g .. Tr[" /h"] end
  end
  return table.concat(bits, " · ")
end

function PU.RefreshEfficiency(p)
  local E = ns.Efficiency
  if not E then return end
  local period = State().effPeriod or "session"
  E.Pulse("ui")
  local rep = E.Report(period)
  if not rep then return end
  local pal = PU.Pal()
  local score = rep.score
  local pct = (type(score) == "number") and math.floor(score * 100 + 0.5) or nil
  local c = p.score
  if pct and (N(rep.total) or 0) >= (E.MIN_SECS or 60) then
    c.value:SetText(tostring(pct) .. " %")
    c.sub:SetText(Tr["Part du temps de session passée à progresser (combat, récolte, artisanat)."])
  else
    c.value:SetText("—")
    c.sub:SetText(Tr["mesure en cours…"] or "…")
  end
  local total = N(rep.total) or 0
  local function share(v)
    if total <= 0 then return 0 end
    return (N(v) or 0) / total
  end
  local a, d, o = share(rep.active), share(rep.dead), share(rep.other)
  local barW = PU.CONTENT_W - 24
  local x = 12
  local cols = { pal.good or { 0.45, 0.7, 0.35, 1 }, pal.bad or { 0.7, 0.28, 0.22, 1 }, pal.track or { 0.3, 0.3, 0.3, 1 } }
  local shares = { a, d, o }
  Paint(c.track, pal.track)
  for i = 1, 3 do
    local w = math.floor(barW * shares[i] + 0.5)
    if shares[i] > 0 and w < 1 then w = 1 end
    if i == 3 then w = math.max(0, 12 + barW - x) end
    if w > 0 then
      Place(c.seg[i], c, x, 50, w, 8)
      Paint(c.seg[i], cols[i])
      c.seg[i]:Show()
      x = x + w
    else
      c.seg[i]:Hide()
    end
  end
  c.split:SetText(string.format(Tr["actif %d %% · temps mort %d %% · autre %d %%"],
    math.floor(a * 100 + 0.5), math.floor(d * 100 + 0.5), math.floor(o * 100 + 0.5)))
  c.split._tipExtra = {
    Tr["Le score d'efficacité est uniquement la part de temps actif. Il ne dépend ni des points / h ni de l'XP / h."],
  }

  local deaths = rep.deaths or {}
  p.stat[1].value:SetText(tostring(N(deaths.n) or 0))
  p.stat[1].sub:SetText((N(deaths.secs) and deaths.secs > 0) and (Tr["dont "] .. (Dur(deaths.secs) or "")) or Tr["aucune cette période"])

  p.stat[2].value:SetText(tostring(N(rep.bagMiss) or 0))
  p.stat[2].sub:SetText(Tr["tentatives à sacs pleins"])

  local fish = rep.fish or {}
  if N(fish.n) and fish.n > 0 then
    p.stat[3].value:SetText(tostring(fish.n))
    local sub = {}
    if fish.perHour then sub[#sub + 1] = Fmt1(fish.perHour) .. Tr[" /h"] end
    p.stat[3].sub:SetText(table.concat(sub, " · "))
  else
    local weps = rep.weapons or {}
    if #weps > 0 then
      local w = weps[1]
      p.stat[3].title:SetText(Tr["Armes"])
      local frac = N(w.frac)
      p.stat[3].value:SetText(frac and (string.format("%d %%", math.floor(frac * 100 + 0.5))) or "—")
      p.stat[3].sub:SetText((w.name or "") .. (w.current and w.cap and string.format(" %d / %d", w.current, w.cap) or ""))
    else
      p.stat[3].title:SetText(Tr["Pêche"])
      p.stat[3].value:SetText("—")
      p.stat[3].sub:SetText(Tr["pas de mesure"])
    end
  end

  -- informatif : % niveau / h (jamais le score ; masqué au niveau max)
  if (not rep.maxLevel) and N(rep.pctLevelPerHour) then
    c.sub:SetText(string.format(Tr["Part du temps actif. À titre informatif : %s %% niv./h."], Fmt2(rep.pctLevelPerHour)))
  elseif rep.maxLevel then
    c.sub:SetText(Tr["Part du temps de session passée à progresser (combat, récolte, artisanat). Les rythmes d'XP sont masqués au niveau maximum."])
  end

  local pr = rep.profit or (E.Profitability and E.Profitability(rep)) or {}
  local money = E.FormatMoney
  local netTxt = money and pr.moneyNet ~= nil and money(pr.moneyNet, true) or nil
  local gph = (pr.goldPerHour ~= nil and money) and (money(pr.goldPerHour, true) .. Tr[" /h"]) or nil
  local netLine
  if netTxt then
    netLine = Tr["Valeur marchand"] .. " : " .. netTxt
    if gph then netLine = netLine .. " · " .. gph end
    if pr.prev and pr.prev.moneyNet ~= nil and money then
      netLine = netLine .. " · " .. Tr["session préc."] .. " " .. money(pr.prev.moneyNet, true)
    end
    p.profit.net:SetText(netLine)
    local tips = { E.ScoringTip and E.ScoringTip() or "", E.VendorTip and E.VendorTip() or "" }
    p.profit.net._tipExtra = tips
  else
    p.profit.net:SetText(Tr["Valeur marchand : pas encore mesurée sur cette période."])
  end

  local function fill(fs, label, spot)
    if not (fs and spot) then return false end
    local zone = spot.zone or spot.name or "?"
    local line = label .. " : " .. zone
    local extra = RateLine(spot)
    if extra ~= "" then line = line .. " · " .. extra end
    fs:SetText(line)
    fs:Show()
    local tip = { E.ScoringTip and E.ScoringTip() or "" }
    if N(spot._pPct) then tip[#tip + 1] = string.format(Tr["Centile progression : %s"], Fmt1(spot._pPct)) end
    if N(spot._gPct) then tip[#tip + 1] = string.format(Tr["Centile or / h : %s"], Fmt1(spot._gPct)) end
    if N(spot.mixScore) then tip[#tip + 1] = string.format(Tr["Score mixte : %s"], Fmt1(spot.mixScore)) end
    fs._fullText = line
    fs._tipExtra = tip
    PU.BindTip(fs, line, tip, PU.CONTENT_W - 20)
    return true
  end
  local n = 0
  if fill(p.profit.rows[1], Tr["Meilleur spot mixte"], pr.bestMix) then n = n + 1 end
  if fill(p.profit.rows[2], Tr["Meilleur spot progression"], pr.bestProg) then n = n + 1 end
  if fill(p.profit.rows[3], Tr["Meilleur spot or"], pr.bestGold) then n = n + 1 end
  if n == 0 then
    for i = 1, 3 do p.profit.rows[i]:SetText("") p.profit.rows[i]:Hide() end
    p.profit.empty:SetText(Tr["Pas encore assez de temps mesuré sur un spot (minimum 1 min) pour classer la rentabilité."])
    p.profit.empty:Show()
  else
    p.profit.empty:Hide()
    for i = n + 1, 3 do p.profit.rows[i]:SetText("") p.profit.rows[i]:Hide() end
  end

  local flags = {}
  local FLAG_TXT = {
    trainer = "palier à apprendre chez le maître",
    green = "beaucoup de recettes vertes ou grises (peu de paliers mesurés)",
  }
  for i, f in ipairs(rep.professions or {}) do
    if f.flag then
      local label = f.name or f.skill or "?"
      local msg = FLAG_TXT[f.flag] or f.flag
      flags[#flags + 1] = label .. " : " .. (Tr[msg] or msg)
    end
  end
  p.flags:SetText(table.concat(flags, " · "))
  p.flags._fullText = table.concat(flags, " · ")

  p.tip:SetText(rep.tip or "")
  p.tip._fullText = rep.tip or ""
end

------------------------------------------------------------------------------
-- 3.13.0 : Farm · vue « Maintenant » — ta session dans la zone où tu es (temps, points/h, or/h, sacs, ce que tu
-- ramasses), ce qu'il manque pour le prochain +1 de chaque métier, et tes objectifs de farm.
------------------------------------------------------------------------------
local function GoldStr(copper)
  local E = ns.Efficiency
  return (E and E.FormatMoney and E.FormatMoney(copper, false)) or tostring(math.floor((N(copper) or 0) / 10000)) .. "g"
end
PU.GoldStr = GoldStr
local function ItemInfo(id)
  local gi = _G.GetItemInfo or (type(_G.C_Item) == "table" and _G.C_Item.GetItemInfo)
  local name, _, _, _, _, _, _, _, _, icon = Call(gi, id)
  if not icon and type(_G.GetItemIcon) == "function" then icon = Call(_G.GetItemIcon, id) end
  return name, icon
end
-- l'or par heure de chaque zone (30 jours), seulement au-delà de 10 minutes mesurées
function PU.ZoneGold()
  local E = ns.Efficiency
  local okR, rep = pcall(function() return E and E.Report and E.Report("d30") end)
  local out = {}
  if not (okR and type(rep) == "table") then return out end
  for z, v in pairs(rep.moneyByZone or {}) do
    local secs = N((rep.zoneSecs or {})[z]) or 0
    local val = type(v) == "table" and (N(v.net) or N(v.value) or 0) or (N(v) or 0)
    if secs >= 600 and val > 0 then out[z] = { value = val, secs = secs, gph = val / (secs / 3600) } end
  end
  return out
end

function PU.BuildFarmNow(f)
  local p = Page(f, "now")
  local LW = 318
  local L = PU.Card(p, 0, 0, LW, PU.CONTENT_H, "")
  local R = PU.Card(p, LW + 8, 0, PU.CONTENT_W - LW - 8, PU.CONTENT_H, "")
  p.L, p.R = L, R
  L.head = FS(L, "GameFontNormalSmall", "label") L.head:SetPoint("TOPLEFT", L, "TOPLEFT", 10, -8) L.head:SetWidth(LW - 20)
  L.kv = {}
  for i = 1, 4 do
    local y = 26 + (i - 1) * 30
    local k = FS(L, "GameFontHighlightSmall", "sub") k:SetPoint("TOPLEFT", L, "TOPLEFT", 10, -y)
    local v = FS(L, "GameFontHighlight", "text") v:SetPoint("TOPLEFT", L, "TOPLEFT", 10, -(y + 11)) v:SetWidth(LW - 20)
    L.kv[i] = { k = k, v = v }
  end
  L.items = FS(L, "GameFontNormalSmall", "label") L.items:SetPoint("TOPLEFT", L, "TOPLEFT", 10, -150)
  L.rows = {}
  for i = 1, 6 do
    local y = 168 + (i - 1) * 22
    local ic = Tex(L, "ARTWORK", 1) Place(ic, L, 10, y, 18, 18)
    local nm = FS(L, "GameFontHighlightSmall", "text") nm:SetPoint("TOPLEFT", L, "TOPLEFT", 34, -(y + 3)) nm:SetWidth(LW - 90)
    local n = FS(L, "GameFontNormalSmall", "title", "RIGHT") n:SetPoint("TOPRIGHT", L, "TOPLEFT", LW - 10, -(y + 3))
    L.rows[i] = { ic = ic, nm = nm, n = n }
  end
  L.empty = FS(L, "GameFontDisableSmall", "sub") L.empty:SetPoint("TOPLEFT", L, "TOPLEFT", 10, -170) L.empty:SetWidth(LW - 20)
  if L.empty.SetWordWrap then pcall(L.empty.SetWordWrap, L.empty, true) end
  -- à droite : ce qu'il manque, puis les objectifs
  local RW = PU.CONTENT_W - LW - 8
  R.head = FS(R, "GameFontNormalSmall", "label") R.head:SetPoint("TOPLEFT", R, "TOPLEFT", 10, -8)
  R.need = {}
  for i = 1, 3 do
    local y = 26 + (i - 1) * 40
    local a = FS(R, "GameFontHighlightSmall", "text") a:SetPoint("TOPLEFT", R, "TOPLEFT", 10, -y) a:SetWidth(RW - 20)
    local b = FS(R, "GameFontHighlightSmall", "sub") b:SetPoint("TOPLEFT", R, "TOPLEFT", 10, -(y + 13)) b:SetWidth(RW - 20)
    local c = FS(R, "GameFontDisableSmall", "sub") c:SetPoint("TOPLEFT", R, "TOPLEFT", 10, -(y + 25)) c:SetWidth(RW - 20)
    -- « + » : le réactif qui manque devient un objectif (quantité manquante)
    local add = PU.Button(R, 18, 16, "+", "small", function(self) if self.goal then PU.FarmAdd(self.goal.id, self.goal.qty) end end)
    add:ClearAllPoints() add:SetPoint("TOPRIGHT", R, "TOPRIGHT", -8, -(y + 11))
    b:SetWidth(RW - 46)
    PU.TipOn(add, Tr["Objectif de farm"], Tr["Ajoute ce qui manque à tes objectifs de farm."])
    R.need[i] = { a = a, b = b, c = c, add = add }
  end
  R.needEmpty = FS(R, "GameFontDisableSmall", "sub") R.needEmpty:SetPoint("TOPLEFT", R, "TOPLEFT", 10, -28) R.needEmpty:SetWidth(RW - 20)
  if R.needEmpty.SetWordWrap then pcall(R.needEmpty.SetWordWrap, R.needEmpty, true) end
  R.goalHead = FS(R, "GameFontNormalSmall", "label") R.goalHead:SetPoint("TOPLEFT", R, "TOPLEFT", 10, -150)
  -- saisie : Maj+clic sur un objet (sacs, chat, butin) ou son numéro, quantité, Ajouter
  local function Box(x, w, maxl, numeric)
    local okB, eb = pcall(CreateFrame, "EditBox", nil, R)
    if not (okB and eb) then return nil end
    eb:SetSize(w, 18) eb:SetPoint("TOPLEFT", R, "TOPLEFT", x, -166)
    if eb.SetAutoFocus then pcall(eb.SetAutoFocus, eb, false) end
    if eb.SetMaxLetters then pcall(eb.SetMaxLetters, eb, maxl) end
    if numeric and eb.SetNumeric then pcall(eb.SetNumeric, eb, true) end
    if eb.SetFontObject then pcall(eb.SetFontObject, eb, _G.GameFontHighlightSmall or "GameFontHighlightSmall") end
    if eb.SetTextInsets then pcall(eb.SetTextInsets, eb, 5, 5, 0, 0) end
    eb.bg = Tex(eb, "BACKGROUND", 1) eb.bg:SetAllPoints(eb) Paint(eb.bg, { 0, 0, 0, 0.5 })
    eb.edge = Edge(eb) PaintEdge(eb.edge, { BRONZE[1], BRONZE[2], BRONZE[3], 0.8 })
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
  end
  R.gbox = Box(10, RW - 128, 300, false)
  R.gqty = Box(RW - 112, 36, 4, true)
  if R.gqty then R.gqty:SetText("20") end
  R.gadd = PU.Button(R, 58, 18, Tr["Ajouter"], "small", function() PU.FarmAddFromBox() end)
  R.gadd:ClearAllPoints() R.gadd:SetPoint("TOPRIGHT", R, "TOPRIGHT", -8, -166)
  if R.gbox then
    R.ghint = FS(R.gbox, "GameFontDisableSmall", "sub")
    R.ghint:SetPoint("LEFT", R.gbox, "LEFT", 6, 0) R.ghint:SetPoint("RIGHT", R.gbox, "RIGHT", -6, 0)
    R.ghint:SetText(Tr["Maj+clic sur un objet, ou son numéro"])
    local function hint() local e = (R.gbox:GetText() or "") == "" local f = R.gbox.HasFocus and R.gbox:HasFocus() if e and not f then R.ghint:Show() else R.ghint:Hide() end end
    R.gbox:SetScript("OnEditFocusGained", hint) R.gbox:SetScript("OnEditFocusLost", hint) R.gbox:HookScript("OnTextChanged", hint)
    R.gbox:SetScript("OnEnterPressed", function() PU.FarmAddFromBox() end)
  end
  if R.gqty then R.gqty:SetScript("OnEnterPressed", function() PU.FarmAddFromBox() end) end
  R.goals = {}
  for i = 1, 4 do
    local y = 192 + (i - 1) * 28
    local ic = Tex(R, "ARTWORK", 1) Place(ic, R, 10, y, 16, 16)
    local nm = FS(R, "GameFontHighlightSmall", "text") nm:SetPoint("TOPLEFT", R, "TOPLEFT", 32, -(y + 1)) nm:SetWidth(RW - 110)
    local n = FS(R, "GameFontHighlightSmall", "text", "RIGHT") n:SetPoint("TOPRIGHT", R, "TOPLEFT", RW - 34, -(y + 1))
    local bar = PU.NewBar(R, 32, y + 15, RW - 66, 3)
    -- « x » : retrait en deux clics (le premier arme « ? », le second dans les 4 s retire), comme la Chasse
    local del = PU.Button(R, 18, 16, "x", "small", function(self)
      if not self.idx then return end
      if PU.ConfirmArm("goal:" .. self.idx) then local E = ns.Efficiency if E and E.GoalRemove then E.GoalRemove(self.idx) end end
      PU.Refresh()
    end)
    del:ClearAllPoints() del:SetPoint("TOPRIGHT", R, "TOPRIGHT", -8, -y)
    PU.TipOn(del, Tr["Retirer"], Tr["Clique deux fois pour retirer cet objectif."])
    R.goals[i] = { ic = ic, nm = nm, n = n, bar = bar, del = del }
  end
  R.goalEmpty = FS(R, "GameFontDisableSmall", "sub") R.goalEmpty:SetPoint("TOPLEFT", R, "TOPLEFT", 10, -194) R.goalEmpty:SetWidth(RW - 20)
  if R.goalEmpty.SetWordWrap then pcall(R.goalEmpty.SetWordWrap, R.goalEmpty, true) end
  return p
end

function PU.FarmAdd(id, qty)
  local E = ns.Efficiency
  if not (E and E.GoalAdd) then return end
  local x, err = E.GoalAdd(id, qty)
  if x and err ~= "same" and ns.Print then ns.Print(string.format(Tr["Objectif de farm : %s × %d"], (select(1, ItemInfo(x.id))) or ("#" .. x.id), x.qty))
  elseif err == "full" and ns.Print then ns.Print(string.format(Tr["%d objectifs au plus."], E.GOALS_MAX)) end
  PU.Refresh()
  return x
end
function PU.FarmAddFromText(text, qty)
  text = tostring(text or "")
  local id = N(text:match("item:(%d+)")) or N(text:match("^%s*(%d+)%s*$"))
  if not id then if ns.Print then ns.Print(Tr["Maj+clic sur un objet, ou son numéro"]) end return nil end
  return PU.FarmAdd(id, qty)
end
function PU.FarmAddFromBox()
  local R = PU.frame and PU.frame.pages.now and PU.frame.pages.now.R
  if not (R and R.gbox) then return end
  local qty = N(R.gqty and R.gqty:GetText()) or 20
  if PU.FarmAddFromText(R.gbox:GetText(), qty) then R.gbox:SetText("") R.gbox:ClearFocus() end
end
function PU.RefreshFarmNow(p)
  if not p then return end
  local L, R = p.L, p.R
  local pal = PU.Pal()
  local E = ns.Efficiency
  local zone = (P.Zone and Call(P.Zone)) or "?"
  local e = E and E.Sess and E.Sess() or {}
  local s = P.Session and P.Session() or {}
  local secs = N((e.zoneSecs or {})[zone]) or 0
  local hours = secs / 3600
  L.head:SetText(string.format(Tr["Ta session ici · %s"], tostring(zone)))
  -- 1) temps et points de récolte (face à ton rythme habituel dans la zone)
  local pts = N((s.zoneGather or {})[zone]) or 0
  local lines = {}
  lines[1] = { Tr["Temps dans la zone"], secs >= 60 and Dur(secs) or Tr["vient d'arriver"] }
  lines[2] = { Tr["Points de récolte"], string.format("+%d", pts) }
  local lz = (e.lootByZone or {})[zone]
  local val = type(lz) == "table" and (N(lz.value) or 0) or 0
  local goldTxt = GoldStr(val)
  if val > 0 and hours >= 0.05 then goldTxt = goldTxt .. " · " .. GoldStr(val / hours) .. Tr[" /h"] end
  local zg = PU.ZoneGold()[zone]
  lines[3] = { Tr["Butin (valeur marchand)"] .. (zg and string.format(Tr[" (d'habitude %s)"], GoldStr(zg.gph) .. Tr[" /h"]) or ""), goldTxt }
  local S = ns.Slot
  local free = S and S.FreeBagSlots and Call(S.FreeBagSlots)
  local bag = free and string.format(Tr["%d places libres"], free) or "—"
  local miss = N(e.bagMiss) or 0
  if miss > 0 then bag = bag .. string.format(Tr[" · sacs pleins %d fois"], miss) end
  lines[4] = { Tr["Sacs"], bag }
  for i, kv in ipairs(L.kv) do
    kv.k:SetText(lines[i][1]) kv.v:SetText(lines[i][2])
    if i == 4 then TextColor(kv.v, (free and free <= 2) and pal.bad or pal.text) end
  end
  -- 2) ce que tu ramasses ici
  L.items:SetText(Tr["Ramassé ici"])
  local items = E and E.SessionItems and E.SessionItems(zone, #L.rows) or {}
  for i, r in ipairs(L.rows) do
    local it = items[i]
    if it then
      local name, icon = ItemInfo(it.id)
      pcall(r.ic.SetTexture, r.ic, icon or ns.FALLBACK_ICON)
      r.nm:SetText(name or ("#" .. it.id)) r.n:SetText("×" .. it.n)
      r.ic:Show() r.nm:Show() r.n:Show()
    else r.ic:Hide() r.nm:Hide() r.n:Hide() end
  end
  if #items == 0 then L.empty:SetText(Tr["Rien ramassé dans cette zone pour l'instant cette session."]) L.empty:Show() else L.empty:Hide() end
  -- 3) ce qu'il te manque pour le prochain +1 (métiers dont l'addon connaît les recettes)
  R.head:SetText(Tr["Ce qu'il te manque"])
  local C = ns.Craft
  local recs = (ns.CharDB and ns.CharDB().recipes) or {}
  local needs = {}
  for skill in pairs(recs) do
    local okB, nb = pcall(function() return C and C.NextBest and C.NextBest(skill) end)
    if okB and nb and nb.recipe then needs[#needs + 1] = { skill = skill, nb = nb } end
  end
  table.sort(needs, function(a, b) return tostring(a.skill) < tostring(b.skill) end)
  for i, r in ipairs(R.need) do
    local x = needs[i]
    if x then
      local parts = {}
      for _, m in ipairs(x.nb.missing or {}) do parts[#parts + 1] = string.format("%s ×%d", tostring(m.name), (N(m.need) or 0) - (N(m.have) or 0)) end
      local rec = C.Paint and C.Paint(x.nb.diff, tostring(x.nb.recipe.name)) or tostring(x.nb.recipe.name)
      r.a:SetText(PU.SkillName(x.skill) .. " · " .. rec)
      r.b:SetText(Tr["Il manque : "] .. table.concat(parts, ", "))
      local m1 = (x.nb.missing or {})[1]
      local src = m1 and C.SourcesOf and C.SourcesOf(m1.id, 1)[1]
      r.c:SetText(src and string.format(Tr["%s : %s (niv. %d-%d, %d %%)"], tostring(m1.name), src.name, src.lo, src.hi, math.floor(src.chance + 0.5)) or "")
      r.add.goal = m1 and m1.id and { id = m1.id, qty = math.max(1, (N(m1.need) or 0) - (N(m1.have) or 0)) } or nil
      r.a:Show() r.b:Show() r.c:Show() if r.add.goal then r.add:Show() else r.add:Hide() end
    else r.a:Hide() r.b:Hide() r.c:Hide() r.add:Hide() end
  end
  if #needs == 0 then
    R.needEmpty:SetText(next(recs) and Tr["Rien ne manque : tu as de quoi faire ton prochain +1 dans chaque métier."]
      or Tr["Ouvre la fenêtre d'un métier une fois : l'addon lira tes recettes et te dira quoi farmer."])
    R.needEmpty:Show()
  else R.needEmpty:Hide() end
  -- 4) objectifs de farm (avancement lu dans les sacs)
  R.goalHead:SetText(Tr["Objectifs de farm"])
  local goals = E and E.GoalList and E.GoalList() or {}
  for i, g in ipairs(R.goals) do
    local x = goals[i]
    if x then
      pcall(g.ic.SetTexture, g.ic, x.icon or ns.FALLBACK_ICON)
      g.nm:SetText(x.name or ("#" .. x.id))
      g.n:SetText(string.format("%d / %d", math.min(x.have, x.qty), x.qty))
      TextColor(g.n, x.done and pal.good or pal.text)
      PU.SetBar(g.bar, x.frac, x.done and pal.good or pal.bar)
      g.del.idx = x.i
      if g.del.fs then g.del.fs:SetText(PU.IsArmed("goal:" .. x.i) and "?" or "x") end
      g.ic:Show() g.nm:Show() g.n:Show() g.bar.track:Show() g.del:Show() if x.frac > 0 then g.bar.fill:Show() end
    else g.ic:Hide() g.nm:Hide() g.n:Hide() g.bar.track:Hide() g.bar.fill:Hide() g.del:Hide() g.del.idx = nil end
  end
  if #goals == 0 then R.goalEmpty:SetText(Tr["Aucun objectif : Maj+clic sur un objet, ou « + » à côté de ce qui te manque."]) R.goalEmpty:Show() else R.goalEmpty:Hide() end
end

-- Spots en classement : pour chaque métier de récolte, la meilleure zone en points/h et en or/h, et la tendance
PU.TREND = { slower = { "ralentit ↓", "bad" }, faster = { "accélère ↑", "good" }, steady = { "stable", "sub" } }
function PU.BestSpots()
  local gold = PU.ZoneGold()
  local out = {}
  for _, id in ipairs({ "herbalism", "mining", "skinning", "fishing" }) do
    local list = P.Spots and P.Spots(id) or {}
    local best = list[1]
    if best and best.pts > 0 then
      local bg
      for _, z in ipairs(list) do local g = gold[z.zone] if g and (not bg or g.gph > bg.gph) then bg = { zone = z.zone, gph = g.gph } end end
      out[#out + 1] = { skill = id, zone = best.zone, pts = best.pts, minutes = best.minutes, gold = bg }
    end
  end
  return out
end

------------------------------------------------------------------------------
-- 3.13.0 : onglet Compétences — toutes tes compétences (rang, gain du jour, 7 jours) et le détail de
-- la compétence choisie : courbe 30 jours, rythme, prochain rang de métier et où l'apprendre, prochaine recette.
-- Données : historique quotidien de Progress (gains par compétence, 30 jours) et cases du panneau.
------------------------------------------------------------------------------
PU.SK_ROWS = 12
PU.SK_SORTS = { { id = "gain", label = "Plus progressé" }, { id = "gap", label = "Plus loin du max" }, { id = "panel", label = "Ordre du panneau" } }
local SK_KINDS = { level = true, profession = true, secondary = true, melee = true, ranged = true, feral = true, defense = true }
-- gains d'une compétence sur les « n » derniers jours (aujourd'hui compris) et par jour (du plus ancien au plus récent)
-- 3.13.0 : « 1 tentative » au singulier
function PU.Tries(n, d)
  return string.format(Tr[(N(n) or 0) == 1 and "%d tentative · %d trouvé(s)" or "%d tentatives · %d trouvé(s)"], n, d)
end
function PU.SkillGains(key, n)
  local P = ns.Progress
  if not (P and P.C and P.Today and P.DayOffset) then return 0, {} end
  local _, c = P.C()
  local hist = c and c.history or {}
  local today, sum, days = P.Today(), 0, {}
  for i = (n or 30) - 1, 0, -1 do
    local day = P.DayOffset(today, -i)
    local h = day and hist[day]
    local v = type(h) == "table" and type(h.skills) == "table" and N(h.skills[key]) or 0
    days[#days + 1] = v
    sum = sum + v
  end
  return sum, days
end
-- les compétences du panneau (apprises, hors caractéristiques et monte)
function PU.SkillList()
  local snap = Snap()
  local tiles = snap and (snap.allTiles or snap.tiles) or {}
  local out, seen = {}, {}
  for i, d in ipairs(tiles) do
    local cur = N(d.current) or 0
    if d and not d.placeholder and SK_KINDS[d.kind] and cur > 0 and not d.excludedMonte and d.id ~= "riding" and not seen[d.id or d.name] then
      seen[d.id or d.name] = true
      local key = d.id or d.name
      local max = N(d.apiMax) or N(d.max) or 0
      if d.kind == "level" then max = N(ns.GetLevelCap and Call(ns.GetLevelCap)) or 60 end
      local g7, days = PU.SkillGains(key, 30)
      local w7 = 0 for j = #days - 6, #days do w7 = w7 + (days[j] or 0) end
      out[#out + 1] = { d = d, key = key, name = d.skillName or d.catName or d.name or key, cur = cur, max = max,
        today = days[#days] or 0, w7 = w7, g30 = g7, days = days, ord = i, icon = d.icon,
        cat = (d.kind == "level") and 1 or (d.kind == "profession" or d.kind == "secondary") and 3 or 2 }
    end
  end
  return out
end
function PU.SortSkills(list, how)
  table.sort(list, function(a, b)
    if how == "gap" then local ga, gb = math.max(0, a.max - a.cur), math.max(0, b.max - b.cur) if ga ~= gb then return ga > gb end
    elseif how == "gain" then if a.w7 ~= b.w7 then return a.w7 > b.w7 end if a.today ~= b.today then return a.today > b.today end end
    return a.ord < b.ord
  end)
  return list
end
-- détail : lignes « libellé · valeur »
function PU.SkillDetail(e)
  local L = {}
  local rate = e.w7 / 7
  L[#L + 1] = { Tr["Gagné"], string.format(Tr["aujourd'hui +%d · 7 j +%d · 30 j +%d"], e.today, e.w7, e.g30) }
  L[#L + 1] = { Tr["Rythme récent"], rate > 0 and string.format(Tr["+%s / jour"], (rate >= 10 or rate == math.floor(rate)) and tostring(math.floor(rate + 0.5)) or string.format("%.1f", rate)) or "—" }
  local d, kind = e.d, e.d.kind
  if kind == "melee" or kind == "ranged" or kind == "feral" or kind == "defense" then
    local lvl = N(ns.GetPlayerLevel and Call(ns.GetPlayerLevel)) or N(Call(_G.UnitLevel, "player")) or 0
    L[#L + 1] = { Tr["Maximum à ton niveau"], string.format("5 × %d = %d", lvl, 5 * lvl) }
  end
  if kind == "profession" or kind == "secondary" then
    local tiers = ns.PROF_TIERS and ns.PROF_TIERS[d.id]
    local final = N(ns.PROF_FINAL_CAP) or 300
    local nx = tiers and tiers[e.max]
    if e.max >= final then L[#L + 1] = { Tr["Prochain rang"], Tr["rang maximum atteint"] }
    elseif nx and nx.rank then
      local how = nx.src == "livre" and Tr[" (livre)"] or nx.src == "quête" and Tr[" (quête)"] or ""
      L[#L + 1] = { Tr["Prochain rang"], string.format(Tr["%s dès %d%s"], Tr[nx.rank], N(nx.skill) or e.max, how) }
      local fac = Call(_G.UnitFactionGroup, "player")
      local where = type(nx.where) == "table" and (nx.where[fac] or nx.where.Alliance) or nx.where
      if type(where) == "string" and where ~= "" then L[#L + 1] = { Tr["Où l'apprendre"], Tr[where] } end
    end
    local C = ns.Craft
    if C and C.NextBest then
      local okB, nb = pcall(C.NextBest, d.id)
      if okB and nb and nb.recipe and nb.recipe.name then
        local txt = C.Paint and C.Paint(nb.diff, tostring(nb.recipe.name)) or tostring(nb.recipe.name)
        L[#L + 1] = { Tr["Prochaine recette utile"], txt }
      end
    end
  end
  if e.max > 0 then
    if e.cur >= e.max then L[#L + 1] = { Tr["Maximum"], Tr["atteint"] }
    elseif rate > 0 then
      local days = math.ceil((e.max - e.cur) / rate)
      L[#L + 1] = { Tr["Maximum estimé"], days <= 1 and Tr["≈ 1 jour"] or string.format(Tr["≈ %d jours"], days) }
    end
  end
  return L
end

function PU.BuildSkills(f)
  local p = Page(f, "skills")
  local LW = 372
  local left = PU.Card(p, 0, 0, LW, PU.CONTENT_H, "")
  local right = PU.Card(p, LW + 8, 0, PU.CONTENT_W - LW - 8, PU.CONTENT_H, "")
  p.left, p.right = left, right
  left.sort = PU.Pills(left, PU.SK_SORTS, LW - 8, 4, function() return State().skSort or "gain" end,
    function(id) State().skSort = id State().skOff = 0 PU.Refresh() end)
  left.rows = {}
  for i = 1, PU.SK_ROWS do
    local r = CreateFrame("Button", nil, left)
    Place(r, left, 6, 24 + (i - 1) * 22, LW - 12, 21)
    r.hl = Tex(r, "BACKGROUND", 2) r.hl:SetAllPoints(r)
    r.ic = Tex(r, "ARTWORK", 1) Place(r.ic, r, 2, 2, 17, 17)
    r.name = FS(r, "GameFontHighlightSmall", "text") r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 24, -2) r.name:SetWidth(150)
    r.bar = PU.NewBar(r, 24, 15, 150, 3)
    r.rank = FS(r, "GameFontHighlightSmall", "text", "RIGHT") r.rank:SetPoint("RIGHT", r, "LEFT", 248, 0)
    r.day = FS(r, "GameFontHighlightSmall", "good", "RIGHT") r.day:SetPoint("RIGHT", r, "LEFT", 298, 0)
    r.week = FS(r, "GameFontHighlightSmall", "good", "RIGHT") r.week:SetPoint("RIGHT", r, "LEFT", LW - 18, 0)
    r:SetScript("OnClick", function(self) if self.key then State().skSel = self.key PU.Refresh() end end)
    left.rows[i] = r
  end
  left.more = FS(left, "GameFontDisableSmall", "sub") left.more:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 10, 6)
  if left.EnableMouseWheel then left:EnableMouseWheel(true) end
  left:SetScript("OnMouseWheel", function(_, delta)
    local s = State()
    s.skOff = math.max(0, math.min(math.max(0, (p.n or 0) - PU.SK_ROWS), (s.skOff or 0) - (N(delta) or 0)))
    PU.Refresh()
  end)
  -- détail
  local RW = PU.CONTENT_W - LW - 8
  right.head = FS(right, "GameFontNormalSmall", "label") right.head:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -8) right.head:SetWidth(RW - 20)
  right.big = FS(right, "GameFontNormalLarge", "text") right.big:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -24)
  right.sub = FS(right, "GameFontHighlightSmall", "sub") right.sub:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -48)
  right.sub:SetText(Tr["30 derniers jours"])
  right.cols = {}
  local cw = math.floor((RW - 20) / 30)
  for i = 1, 30 do
    local t = Tex(right, "ARTWORK", 2)
    t:SetPoint("BOTTOMLEFT", right, "TOPLEFT", 10 + (i - 1) * cw, -128)
    t:SetSize(math.max(2, cw - 2), 2)
    right.cols[i] = t
  end
  right.kv = {}
  for i = 1, 7 do
    local y = 136 + (i - 1) * 25
    local k = FS(right, "GameFontHighlightSmall", "sub") k:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -y)
    local v = FS(right, "GameFontHighlightSmall", "text", "LEFT") v:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -(y + 11)) v:SetWidth(RW - 20)
    if v.SetWordWrap then pcall(v.SetWordWrap, v, true) end
    right.kv[i] = { k = k, v = v }
  end
  right.empty = FS(right, "GameFontDisableSmall", "sub", "CENTER") right.empty:SetPoint("CENTER", right, "CENTER", 0, 0)
  return p
end

function PU.RefreshSkills(p)
  if not p then return end
  local s = State()
  local list = PU.SortSkills(PU.SkillList(), s.skSort or "gain")
  p.n = #list
  local left, right = p.left, p.right
  local pal = PU.Pal()
  local colors = PU.SegColors()
  local off = math.max(0, math.min(math.max(0, #list - PU.SK_ROWS), s.skOff or 0))
  local sel
  for _, e in ipairs(list) do if e.key == s.skSel then sel = e end end
  sel = sel or list[1]
  for i, r in ipairs(left.rows) do
    local e = list[off + i]
    if e then
      r.key = e.key
      pcall(r.ic.SetTexture, r.ic, e.icon or ns.FALLBACK_ICON)
      r.name:SetText(tostring(e.name))
      PU.SetBar(r.bar, e.max > 0 and e.cur / e.max or 0, colors[e.cat])
      r.rank:SetText(e.max > 0 and (e.cur .. " / " .. e.max) or tostring(e.cur))
      r.day:SetText("+" .. e.today) r.week:SetText("+" .. e.w7)
      TextColor(r.day, e.today > 0 and pal.good or pal.sub) TextColor(r.week, e.w7 > 0 and pal.good or pal.sub)
      Paint(r.hl, (e == sel) and { 1, 0.82, 0, 0.12 } or { 0, 0, 0, 0 })
      r:Show()
    else r.key = nil r:Hide() end
  end
  local rest = #list - off - PU.SK_ROWS
  left.more:SetText(rest > 0 and string.format(Tr["+ %d autres · molette pour défiler"], rest) or (#list > 0 and Tr["clic sur une compétence pour le détail"] or ""))
  if not sel then
    right.head:SetText("") right.big:SetText("") right.sub:Hide()
    for _, t in ipairs(right.cols) do t:Hide() end
    for _, kv in ipairs(right.kv) do kv.k:SetText("") kv.v:SetText("") end
    right.empty:SetText(Tr["Ouvre le panneau (/drop) pour lire tes compétences."]) right.empty:Show()
    return
  end
  right.empty:Hide() right.sub:Show()
  right.head:SetText(tostring(sel.name))
  right.big:SetText(sel.max > 0 and (sel.cur .. "  / " .. sel.max) or tostring(sel.cur))
  -- courbe : rang reconstitué jour par jour (rang actuel moins les gains des jours suivants)
  local ranks, after = {}, 0
  for i = #sel.days, 1, -1 do ranks[i] = sel.cur - after after = after + (sel.days[i] or 0) end
  local lo, hi = math.huge, 0
  for _, v in ipairs(ranks) do lo = math.min(lo, v) hi = math.max(hi, v) end
  if lo == hi then lo = math.max(0, hi - 10) end
  for i, t in ipairs(right.cols) do
    local v = ranks[i] or sel.cur
    t:SetHeight(math.max(2, math.floor(4 + 56 * (v - lo) / math.max(1, hi - lo) + 0.5)))
    Paint(t, (sel.days[i] or 0) > 0 and colors[sel.cat] or { colors[sel.cat][1], colors[sel.cat][2], colors[sel.cat][3], 0.45 })
    t:Show()
  end
  local L = PU.SkillDetail(sel)
  -- lignes empilées : une adresse de maître sur deux lignes pousse la suite, rien ne déborde du cadre
  local y = 136
  for i, kv in ipairs(right.kv) do
    local line = L[i]
    kv.k:SetText(line and line[1] or "") kv.v:SetText(line and line[2] or "")
    kv.k:ClearAllPoints() kv.k:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -y)
    kv.v:ClearAllPoints() kv.v:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -(y + 11))
    local vh = (line and kv.v.GetStringHeight and N(kv.v:GetStringHeight())) or 10
    y = y + 11 + math.max(10, vh) + 5
    local fits = line and y <= PU.CONTENT_H - 4
    if fits then kv.k:Show() kv.v:Show() else kv.k:Hide() kv.v:Hide() end
  end
end

PU.REFRESHERS = { now = "RefreshFarmNow", skills = "RefreshSkills", overview = "RefreshOverview", charts = "RefreshCharts", ach = "RefreshAch", spots = "RefreshSpots", weekly = "RefreshWeekly", efficiency = "RefreshEfficiency", chars = "RefreshChars", hunt = "RefreshHunt", collection = "RefreshCollection" }
function PU.Refresh()
  local f = PU.frame
  if not (f and f:IsShown()) then return false end
  PU.stats.refreshes = PU.stats.refreshes + 1
  local ok, err = pcall(PU.RefreshHeader)
  if not ok then PU.lastError = err PU.stats.errors = PU.stats.errors + 1 end
  local st = State()
  if st.recapOpen and f.pages.recap then
    for id, page in pairs(f.pages) do
      if id == "recap" then page:Show() else page:Hide() end
    end
    local ok2, err2 = pcall(PU.RefreshRecap, f.pages.recap)
    if not ok2 then PU.lastError = err2 PU.stats.errors = PU.stats.errors + 1 end
  else
    if f.pages.recap then f.pages.recap:Hide() end
    local tab = st.tab
    for id, page in pairs(f.pages) do if id == tab then page:Show() else page:Hide() end end
    local fn = PU[PU.REFRESHERS[tab]]
    if fn then
      local ok2, err2 = pcall(fn, f.pages[tab])
      if not ok2 then PU.lastError = err2 PU.stats.errors = PU.stats.errors + 1 end
    end
  end
  PU.SyncPills()
  if PU.ScanTruncateTips then pcall(PU.ScanTruncateTips, f) end
  if ns.StepGC then pcall(ns.StepGC, 400) end
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
  s.recapOpen = nil   -- 3.8.1 : un clic sur un onglet ferme le récap de session
  if id == "weekly" or id == "charts" then s.chartsSub = id end
  if id == "overview" or id == "weekly" or id == "charts" then s.overSub = id end
  if id == "now" or id == "spots" or id == "efficiency" then s.farmSub = id end
  if id == "collection" or id == "hunt" then s.collSub = id end
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

-- Clic sur la goutte / la barre du total / le bandeau (View, Wide, UI) :
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
  -- 3.8.1 : même habillage que l'infobulle au-dessus (bord arrondi), pas un cadre carré
  local okT, m = pcall(CreateFrame, "Frame", nil, _G.UIParent, "BackdropTemplate")
  if not okT or not m then m = CreateFrame("Frame", nil, _G.UIParent) end
  m:SetFrameStrata("TOOLTIP")
  m:SetSize(180, PU.MINI_H)
  if m.SetBackdrop then
    pcall(m.SetBackdrop, m, { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    m._round = true
  end
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
  if m._round and m.SetBackdropColor then
    -- couleurs reprises de l'infobulle du jeu (ou de l'addon qui l'habille), sinon palette Dropamine
    local tt, br, bg, bb, ba, er, eg, eb, ea = _G.GameTooltip
    local ns9 = tt and tt.NineSlice
    if ns9 and ns9.GetCenterColor then local ok, r, g, b, a = pcall(ns9.GetCenterColor, ns9) if ok and r then br, bg, bb, ba = r, g, b, a end end
    if ns9 and ns9.GetBorderColor then local ok, r, g, b, a = pcall(ns9.GetBorderColor, ns9) if ok and r then er, eg, eb, ea = r, g, b, a end end
    if tt and not br and tt.GetBackdropColor then local ok, r, g, b, a = pcall(tt.GetBackdropColor, tt) if ok and r then br, bg, bb, ba = r, g, b, a end end
    if tt and not er and tt.GetBackdropBorderColor then local ok, r, g, b, a = pcall(tt.GetBackdropBorderColor, tt) if ok and r then er, eg, eb, ea = r, g, b, a end end
    m:SetBackdropColor(br or 0.06, bg or 0.06, bb or 0.06, ba or 0.92)
    m:SetBackdropBorderColor(er or 0.55, eg or 0.5, eb or 0.4, ea or 1)
    if m.bg then m.bg:Hide() end
    ShowEdge(m.edge, false)
  else
    Paint(m.bg, pal.mini)
    PaintEdge(m.edge, pal.skin and pal.cardEdge or (pal.edge or pal.cardEdge))
  end
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
  TipOn(b, Tr["Progression"], Tr["Ouvre la fenêtre Progression (aussi : clic gauche sur la goutte, /drop progression)."])
  PU.optButton = b
  return b
end

ns.SlashExt = ns.SlashExt or {}
do
  local printSummary = ns.SlashExt.progression
  PU.PrintSummary = printSummary
  local TAB = { vue = "overview", overview = "overview", graphiques = "charts", graphes = "charts", charts = "charts", graphs = "charts",
    succes = "ach", ["succès"] = "ach", achievements = "ach", spots = "spots", farm = "spots",
    maintenant = "now", now = "now", competences = "skills", ["compétences"] = "skills", skills = "skills", apercu = "overview", ["aperçu"] = "overview",
    collection = "collection", carnet = "collection", chasse = "hunt", hunt = "hunt",
    semaine = "weekly", hebdo = "weekly", week = "weekly", weekly = "weekly" }
  local function cmd(rest)
    local low = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if low == "texte" or low == "text" or low == "chat" then
      if printSummary then return printSummary(rest) end
      return
    end
    if TAB[low] then return PU.Open(TAB[low]) end
    -- 3.13.0 : /drop progression cadre jeu|dropamine (habillage ; pris en compte au /reload)
    -- 3.13.0 : un seul cadre (celui du jeu) : l'ancienne commande /drop progression cadre … ouvre simplement la fenêtre
    if low:match("^cadre") or low:match("^frame") then return PU.Open() end
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

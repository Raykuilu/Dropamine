-- Dropamine : style « Métiers » (fenêtre des métiers de Forever).
-- Sonde à l'exécution les barres de rang colorées et les encadrés (fond dégradé
-- brun clair + filet doré) de la fenêtre Métiers, puis les réutilise pour les
-- barres des tuiles, du détail et des drops, et pour la grille / le détail / le
-- bandeau. Rien n'est inventé : sans fenêtre trouvée, on garde le style actuel.
local ADDON, ns = ...
local Style = {}
ns.Style = Style

-- Modules Blizzard qui portent la fenêtre des métiers (chargés hors combat, pcall).
Style.ADDONS = { "Blizzard_ProfessionsBook", "Blizzard_TradeSkillUI", "Blizzard_Professions" }
-- Racines candidates (noms connus des clients ; la sonde scanne leurs enfants).
Style.ROOTS = {
  "ProfessionsBookFrame", "SpellBookProfessionFrame", "ProfessionsFrame", "TradeSkillFrame",
  "ProfessionFrame", "SpellBookFrame", "PlayerSpellsFrame",
}
-- Repli coloré (couleurs relevées sur la capture Métiers fournie, pas des données de jeu).
Style.FALLBACK_COLORS = {
  leatherworking = { 0.55, 0.36, 0.18 },
  skinning = { 0.47, 0.55, 0.42 },
  cooking = { 0.62, 0.74, 0.90 },
  fishing = { 0.62, 0.74, 0.90 },
  firstaid = { 0.20, 0.66, 0.22 },
}
-- Encadré Métiers reproduit : couleurs relevées au pixel sur la capture de la
-- fenêtre Métiers de Forever (v270_vs_metiers.png, sections « Travail du cuir »,
-- « Dépeçage »). Dégradé vertical sombre en haut → plus clair en bas.
-- v2.8.0 : PALETTE = source unique des couleurs (voir STYLEGUIDE.md), relevée au
-- pixel sur la capture FlareUI pleine résolution (bf7d98bd….png, 2885×1404) :
-- fenêtre d'options FlareUI « Sacs et butin ». Coordonnées des relevés dans
-- STYLEGUIDE.md. Les textures Media/Skin/*.tga sont redessinées avec ces valeurs.
local function C(r, g, b, a) return { r / 255, g / 255, b / 255, a or 1 } end
local function H(hex, a)
  hex = hex:gsub("#", "")
  return C(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), a)
end
Style.HEX = H
Style.PALETTE = {
  -- Bord or des encadrés (4 px, de l'extérieur vers l'intérieur, coins biseautés)
  borderOuter = H("#181513"),   -- trait sombre extérieur (encadré « Fenêtre des sacs »)
  borderGold = H("#624F32"),    -- filet or
  borderInner = H("#463824"),   -- filet bronze
  borderDark = H("#161412"),    -- trait sombre intérieur
  divider = H("#796345"),       -- filet 1 px sous l'en-tête de section
  -- Fonds
  windowBg = H("#443F38"),      -- fond de fenêtre (gouttière entre les panneaux)
  panelBg = H("#302C29"),       -- panneau de contenu
  sidebarBg = H("#2C2924"),     -- barre latérale / encadré d'info
  sectionBg = H("#272320"),     -- intérieur d'un encadré
  inputBg = H("#26231F"),       -- champ « Rechercher… »
  -- Textes
  titleYellow = H("#FFD800"),   -- titre, en-têtes, « Réinitialiser », « Par défaut », « Astuce »
  labelWhite = H("#FFFFFF"),    -- libellés d'options
  bodyText = H("#DFDFDF"),      -- texte de l'encadré d'info
  sidebarText = H("#DFD4BE"),   -- libellés de la barre latérale
  subtitleGrey = H("#B0A699"),  -- sous-titre « Vos sacs et ce que vous ramassez. », version
  categoryText = H("#B49B6D"),  -- catégories de la barre latérale (« Combat », « Interface »)
  helpGrey = H("#B0A699"),      -- aide courte (même gris que le sous-titre)
  -- Contrôles
  checkEdge = H("#685948"),     -- bord de case
  checkBox = H("#190E00"),      -- intérieur de case (haut)
  checkGold = H("#FDED23"),     -- coche
  sliderEdge = H("#504131"),    -- filets de la piste
  sliderTrack = H("#1A1815"),   -- intérieur de la piste
  thumb = H("#A97B59"),         -- losange cuivre
  tabEdge = H("#927450"),       -- liseré or des onglets / boutons
  buttonTop = H("#5F5F5F"),     -- dégradé gris des boutons (haut)
  buttonBottom = H("#282727"),  -- (bas)
  selectedRow = H("#A97B3D"),   -- ligne sélectionnée, à gauche (dégradé vers #43321D)
  selectedRowEnd = H("#43321D"),
  selectedAccent = H("#FDD271"),-- accent or 2 px à gauche de la ligne sélectionnée
  iconRing = H("#756451"),      -- anneau or des icônes rondes
  scrollThumb = H("#603F21"),   -- ascenseur
  -- Repères conservés (drops : le vrai bord du chat reste prioritaire)
  chatGold = H("#896D43"),
  chatBronze = H("#624F32"),
}
-- Textures redessinées (Media/Skin), tailles en puissances de 2.
local FLARE = "Interface\\AddOns\\Dropamine\\Media\\Skin\\"
Style.FLARE = {
  border = FLARE .. "Border",          -- 32×32, 9 tranches (coins 8 px), centre transparent
  button = FLARE .. "Button",          -- 64×32, 3 tranches (bords 6 px)
  dropdown = FLARE .. "Dropdown",      -- 64×32
  check = FLARE .. "CheckBox",         -- 32×32
  mark = FLARE .. "CheckMark",         -- 32×32
  track = FLARE .. "SliderTrack",      -- 64×16
  thumb = FLARE .. "SliderThumb",      -- 32×32
  row = FLARE .. "RowSelected",        -- 128×32
  ring = FLARE .. "IconRing",          -- 64×64, anneau rond (avec masque rond)
  mask = FLARE .. "IconMask",          -- 64×64, disque blanc (masque)
  frame = FLARE .. "IconFrame",        -- 64×64, cadre biseauté (repli sans masque)
  scroll = FLARE .. "ScrollThumb",     -- 16×64
  arrow = FLARE .. "Arrow",            -- 32×32
  divider = FLARE .. "Divider",        -- 64×4
  burst = FLARE .. "LightBurst",       -- 128×128, éclat doré (montée de niveau)
  glow = FLARE .. "Glow",              -- 64×64, lueur de bord (9 tranches, 12 px)
}

Style.SECTION = {
  top = { 33 / 255, 28 / 255, 24 / 255, 1 },      -- #211C18
  bottom = { 58 / 255, 44 / 255, 36 / 255, 1 },   -- #3A2C24
  bronze = { 99 / 255, 77 / 255, 54 / 255, 1 },   -- #634D36 (filet clair)
  outer = { 50 / 255, 31 / 255, 17 / 255, 1 },    -- #321F11 (trait sombre extérieur)
  -- v2.7.2 : les encadrés prennent le bord or commun (Style.PALETTE).
}
Style.FALLBACK_SECTION = {
  top = Style.SECTION.top, bottom = Style.SECTION.bottom,
  edge = "Interface\\Tooltips\\UI-Tooltip-Border", gold = Style.SECTION.bronze,
}

local function N(v) return ns.N and ns.N(v) or tonumber(v) end
local function Fold(s) return ns.Fold and ns.Fold(s or "") or string.lower(s or "") end

local function TexInfo(obj)
  if type(obj) ~= "table" then return nil end
  local path, atlas
  if obj.GetAtlas then
    local ok, a = pcall(obj.GetAtlas, obj)
    if ok and type(a) == "string" and a ~= "" then path, atlas = a, true end
  end
  if not path and obj.GetTexture then
    local ok, p = pcall(obj.GetTexture, obj)
    if ok and ((type(p) == "string" and p ~= "") or type(p) == "number") then path = p end
  end
  if not path then return nil end
  local info = { tex = path, atlas = atlas and true or false }
  if obj.GetVertexColor then
    local ok, r, g, b, a = pcall(obj.GetVertexColor, obj)
    if ok and N(r) then info.color = { N(r), N(g) or 1, N(b) or 1, N(a) or 1 } end
  end
  if obj.GetTexCoord then
    local ok, a1, a2, a3, a4, a5, a6, a7, a8 = pcall(obj.GetTexCoord, obj)
    if ok and N(a1) then info.coords = { a1, a2, a3, a4, a5, a6, a7, a8 } end
  end
  return info
end
Style.TexInfo = TexInfo

local function Children(f)
  local out = {}
  if type(f) ~= "table" or not f.GetChildren then return out end
  local ok, r = pcall(function() return { f:GetChildren() } end)
  if ok and r then out = r end
  return out
end
local function Regions(f)
  local out = {}
  if type(f) ~= "table" or not f.GetRegions then return out end
  local ok, r = pcall(function() return { f:GetRegions() } end)
  if ok and r then out = r end
  return out
end
local function ObjType(f)
  if type(f) ~= "table" or not f.GetObjectType then return nil end
  local ok, t = pcall(f.GetObjectType, f)
  return ok and t or nil
end
local function TextOf(fs)
  if type(fs) ~= "table" or not fs.GetText then return nil end
  local ok, t = pcall(fs.GetText, fs)
  if ok and type(t) == "string" and t ~= "" then return t end
  return nil
end

-- Associe un texte (« Cuisine 78/150 », « Travail du cuir ») à un id du catalogue.
-- 3.6.0 : teinte saisonnière discrète (option « seasonal », coupée par défaut).
-- Neutre côté faction : hiver givré, printemps vert tendre, été or pâle,
-- automne ambre. Rien n'est peint ici : la Phase 2 (fenêtre Progression) et
-- les toasts dorés lisent Style.SeasonalTint() ; nil = pas de teinte.
Style.SEASONS = {
  winter = { 0.70, 0.84, 1.00, 0.18 },
  spring = { 0.62, 0.90, 0.58, 0.16 },
  summer = { 1.00, 0.88, 0.52, 0.16 },
  autumn = { 0.95, 0.62, 0.30, 0.18 },
}
function Style.SeasonFor(month)
  month = tonumber(month)
  if not month then
    local fn = (type(_G.date) == "function" and _G.date) or (type(os) == "table" and os.date) or nil
    local ok, t = false, nil
    if fn then ok, t = pcall(fn, "*t") end
    month = ok and type(t) == "table" and tonumber(t.month) or 1
  end
  if month == 12 or month <= 2 then return "winter" end
  if month <= 5 then return "spring" end
  if month <= 8 then return "summer" end
  return "autumn"
end
function Style.SeasonalTint(month)
  if not (ns.OptOff and ns.OptOff("seasonal")) then return nil end
  local key = Style.SeasonFor(month)
  return Style.SEASONS[key], key
end

-- 3.7.1 : résultat mémorisé par texte (catalogue statique) ; l'ancien calcul
-- créait une table par entrée du catalogue à chaque barre de nom / infobulle.
local skillTextCache, skillTextN, NOHIT = {}, 0, {}
function Style.SkillIdForText(text)
  if type(text) ~= "string" then return nil end
  local hit = skillTextCache[text]
  if hit ~= nil then if hit == NOHIT then return nil end return hit end
  local r = Style.SkillIdForTextRaw(text)
  if skillTextN >= 2000 then skillTextCache, skillTextN = {}, 0 end
  skillTextCache[text] = (r == nil) and NOHIT or r
  skillTextN = skillTextN + 1
  return r
end
function Style.SkillIdForTextRaw(text)
  local f = Fold(text)
  local best, bestLen
  for _, e in ipairs(ns.CATALOG or {}) do
    local names = { e.name }
    for _, a in ipairs(e.aliases or {}) do
      -- 3.5.18 : noms d'armes courts (« arc », « masse »…) en correspondance exacte seulement
      if not (ns.EXACT_ONLY and ns.EXACT_ONLY[Fold(a)]) then names[#names + 1] = a end
    end
    for _, nm in ipairs(names) do
      local fn = Fold(nm)
      if fn ~= "" and f:find(fn, 1, true) and (not bestLen or #fn > bestLen) then best, bestLen = e.id, #fn end
    end
  end
  return best
end

-- Cherche un libellé de compétence autour d'une barre (elle-même, parent, grand-parent).
local function SkillNear(bar)
  local f = bar
  for _ = 1, 3 do
    if type(f) ~= "table" then break end
    for _, r in ipairs(Regions(f)) do
      if ObjType(r) == "FontString" then
        local id = Style.SkillIdForText(TextOf(r))
        if id then return id, TextOf(r) end
      end
    end
    for _, c in ipairs(Children(f)) do
      for _, r in ipairs(Regions(c)) do
        if ObjType(r) == "FontString" then
          local id = Style.SkillIdForText(TextOf(r))
          if id then return id, TextOf(r) end
        end
      end
    end
    f = f.GetParent and f:GetParent() or nil
  end
  return nil
end

local function BarStyle(bar, name)
  local okT, tex = pcall(bar.GetStatusBarTexture, bar)
  local info = TexInfo(okT and tex or nil)
  if not info then return nil end
  local st = { tex = info.tex, atlas = info.atlas, source = name }
  if bar.GetStatusBarColor then
    local ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
    if ok and N(r) then st.color = { N(r), N(g) or 1, N(b) or 1, N(a) or 1 } end
  end
  local okW, w = pcall(bar.GetWidth, bar)
  local okH, h = pcall(bar.GetHeight, bar)
  st.w, st.h = okW and N(w) or nil, okH and N(h) or nil
  -- Fond / cadre : textures de la barre ou de son parent (hors remplissage).
  for _, r in ipairs(Regions(bar)) do
    if ObjType(r) == "Texture" and r ~= tex then
      local okL, layer = pcall(r.GetDrawLayer, r)
      local ti = TexInfo(r)
      if ti then
        if okL and layer == "BACKGROUND" and not st.bg then st.bg = ti
        elseif not st.border then st.border = ti end
      end
    end
  end
  if type(bar.Border) == "table" and not st.border then st.border = TexInfo(bar.Border) end
  return st
end

-- Encadré : fond (texture BACKGROUND la plus grande) + pièces NineSlice / bords.
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }
local function SectionStyle(frame, name)
  if type(frame) ~= "table" then return nil end
  local st = { source = name, pieces = {} }
  local bestA = 0
  for _, r in ipairs(Regions(frame)) do
    if ObjType(r) == "Texture" then
      local okL, layer = pcall(r.GetDrawLayer, r)
      if okL and (layer == "BACKGROUND" or layer == "BORDER") then
        local okW, w = pcall(r.GetWidth, r)
        local okH, h = pcall(r.GetHeight, r)
        local a = (okW and N(w) or 0) * (okH and N(h) or 0)
        local ti = TexInfo(r)
        if ti and a > bestA then bestA, st.bg = a, ti end
      end
    end
  end
  local ns9 = frame.NineSlice or frame.BackgroundNineSlice or frame.Border
  if type(ns9) == "table" then
    for _, k in ipairs(PIECES) do
      local ti = TexInfo(ns9[k])
      if ti then st.pieces[k] = ti end
    end
  end
  if st.bg or next(st.pieces) then return st end
  return nil
end

function Style.LoadProfessionAddons()
  if Style._loaded then return end
  if type(InCombatLockdown) == "function" and InCombatLockdown() then return end
  Style._loaded = true
  Style.loadReport = {}
  local loader = (type(_G.C_AddOns) == "table" and _G.C_AddOns.LoadAddOn) or _G.LoadAddOn
  if type(loader) ~= "function" then
    Style.loadReport[#Style.loadReport + 1] = "LoadAddOn indisponible"
    return
  end
  for _, a in ipairs(Style.ADDONS) do
    local ok, r = pcall(loader, a)
    Style.loadReport[#Style.loadReport + 1] = a .. " : " .. ((ok and r) and "chargé" or "absent")
  end
end

-- Sonde complète. Résultat mémorisé dans les SV (réutilisé sans rouvrir la fenêtre).
function Style.Probe(force)
  if Style.probed and not force then return Style.data end
  Style.LoadProfessionAddons()
  local data = { bars = {}, sections = {}, roots = {}, generic = nil }
  local seen = {}
  local function scan(f, path, depth)
    if type(f) ~= "table" or seen[f] or depth > 7 then return end
    seen[f] = true
    local t = ObjType(f)
    if t == "StatusBar" then
      local id, label = SkillNear(f)
      local st = BarStyle(f, path)
      if st then
        st.label = label
        if id and not data.bars[id] then data.bars[id] = st end
        data.generic = data.generic or st
        local p = f.GetParent and f:GetParent()
        if id and p then
          local sec = SectionStyle(p, path .. ".parent") or SectionStyle(p.GetParent and p:GetParent(), path .. ".parent.parent")
          if sec then data.sections[#data.sections + 1] = sec end
        end
      end
    end
    for i, c in ipairs(Children(f)) do
      local cn = (c.GetName and c:GetName()) or (path .. "[" .. i .. "]")
      scan(c, cn, depth + 1)
    end
  end
  for _, n in ipairs(Style.ROOTS) do
    local root = _G[n]
    if type(root) == "table" then
      data.roots[#data.roots + 1] = n
      pcall(scan, root, n, 0)
      local inset = root.Inset or _G[n .. "Inset"] or (root.CraftingPage and root.CraftingPage.RecipeList)
      local sec = SectionStyle(inset, n .. ".Inset")
      if sec then table.insert(data.sections, 1, sec) end
    end
  end
  data.section = data.sections[1]
  -- Barres colorées par métier ? (au moins deux couleurs différentes relevées)
  local colors = {}
  for _, st in pairs(data.bars) do
    if st.color then colors[string.format("%.2f,%.2f,%.2f", st.color[1], st.color[2], st.color[3])] = true end
  end
  local nc = 0
  for _ in pairs(colors) do nc = nc + 1 end
  local texs = {}
  for _, st in pairs(data.bars) do texs[tostring(st.tex)] = true end
  local nt = 0
  for _ in pairs(texs) do nt = nt + 1 end
  data.perSkill = (nc > 1 or nt > 1)
  data.found = next(data.bars) ~= nil or data.section ~= nil
  Style.data = data
  Style.probed = true
  local db = ns.db
  if db and data.found then
    db.style = { bars = data.bars, section = data.section, perSkill = data.perSkill, when = (type(time) == "function" and time()) or 0 }
  end
  if not data.found and db and type(db.style) == "table" then
    -- Pas de fenêtre chargée cette fois : on reprend la dernière capture.
    data.bars = db.style.bars or {}
    data.section = db.style.section
    data.perSkill = db.style.perSkill
    data.fromSV = true
    data.found = next(data.bars) ~= nil or data.section ~= nil
  end
  return data
end

-- Style de barre pour une tuile (id du catalogue). nil = garder la barre bleue native.
function Style.BarFor(skillId)
  if not skillId then return nil end
  local d = Style.data or Style.Probe()
  local st = d and d.bars and d.bars[skillId]
  if st then return st end
  local fc = Style.FALLBACK_COLORS[skillId]
  if fc then return { color = { fc[1], fc[2], fc[3], 1 }, fallback = true, source = "repli coloré" } end
  return nil
end

local function SetTex(t, info)
  if not t or not info then return false end
  if info.atlas and t.SetAtlas then
    local ok = pcall(t.SetAtlas, t, info.tex)
    if ok then return true end
  end
  if t.SetTexture then
    local ok = pcall(t.SetTexture, t, info.tex)
    return ok
  end
  return false
end

local function Gradient(t, top, bottom)
  if not t then return end
  pcall(t.SetTexture, t, "Interface\\Buttons\\WHITE8X8")
  local done = false
  if t.SetGradient and type(_G.CreateColor) == "function" then
    done = pcall(t.SetGradient, t, "VERTICAL", _G.CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]), _G.CreateColor(top[1], top[2], top[3], top[4]))
  end
  if not done and t.SetGradientAlpha then
    done = pcall(t.SetGradientAlpha, t, "VERTICAL", bottom[1], bottom[2], bottom[3], bottom[4], top[1], top[2], top[3], top[4])
  end
  if not done and t.SetVertexColor then
    pcall(t.SetVertexColor, t, (top[1] + bottom[1]) / 2, (top[2] + bottom[2]) / 2, (top[3] + bottom[3]) / 2, top[4])
  end
end

-- Habille un cadre comme un encadré de la fenêtre Métiers : dégradé + filet
-- bronze de 1 px (trait sombre à l'extérieur). Idempotent : rien n'est refait
-- si le cadre est déjà habillé (aucun coût au survol ni au rafraîchissement).
local function Pix(frame, layer, sub)
  local t = frame:CreateTexture(nil, layer, nil, sub)
  pcall(t.SetTexture, t, "Interface\\Buttons\\WHITE8X8")
  return t
end
local function Edge(frame, list, inset, col, layer)
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = list[side] or Pix(frame, layer or "BORDER")
    list[side] = t
    t:ClearAllPoints()
    if side == "TOP" or side == "BOTTOM" then
      local y = (side == "TOP") and -inset or inset
      t:SetPoint(side .. "LEFT", frame, side .. "LEFT", inset, y)
      t:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", -inset, y)
      t:SetHeight(1)
    else
      local x = (side == "LEFT") and inset or -inset
      t:SetPoint("TOP" .. side, frame, "TOP" .. side, x, -inset)
      t:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, x, inset)
      t:SetWidth(1)
    end
    pcall(t.SetVertexColor, t, col[1], col[2], col[3], col[4] or 1)
    t:Show()
  end
end

-- Texture en 9 tranches avec SetTexCoord (API 16001, aucun NineSlice requis).
-- tex : chemin ; tw, th : taille de la texture ; c : taille des coins (px texture) ;
-- size : taille affichée des coins ; out : débord hors du cadre (lueur).
Style.NINE_ORDER = { "TL", "TR", "BL", "BR", "T", "B", "L", "R" }
function Style.Nine(frame, key, tex, tw, th, c, size, layer, sub, out)
  if type(frame) ~= "table" or not frame.CreateTexture then return nil end
  frame._flare = frame._flare or {}
  local set = frame._flare[key]
  if not set then set = {} frame._flare[key] = set end
  size, out = size or c, out or 0
  local u, v = c / tw, c / th
  local parts = {
    TL = { 0, u, 0, v }, T = { u, 1 - u, 0, v }, TR = { 1 - u, 1, 0, v },
    L = { 0, u, v, 1 - v }, M = nil, R = { 1 - u, 1, v, 1 - v },
    BL = { 0, u, 1 - v, 1 }, B = { u, 1 - u, 1 - v, 1 }, BR = { 1 - u, 1, 1 - v, 1 },
  }
  -- 3.5.3 : coins d'abord, puis bords (les bords s'ancrent aux coins ; avec
  -- pairs(), un bord créé avant son coin s'ancrait au parent → lueur partielle)
  for _, name in ipairs(Style.NINE_ORDER) do
    local tc = parts[name]
    local t = set[name]
    if not t then t = frame:CreateTexture(nil, layer or "BORDER") set[name] = t end
    if t.SetDrawLayer then pcall(t.SetDrawLayer, t, layer or "BORDER", sub or 0) end
    pcall(t.SetTexture, t, tex)
    t.texPath = tex
    if t.SetTexCoord then pcall(t.SetTexCoord, t, tc[1], tc[2], tc[3], tc[4]) end
    t:ClearAllPoints()
    local o = out
    if name == "TL" then t:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, o) t:SetSize(size, size)
    elseif name == "TR" then t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", o, o) t:SetSize(size, size)
    elseif name == "BL" then t:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -o, -o) t:SetSize(size, size)
    elseif name == "BR" then t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -o) t:SetSize(size, size)
    elseif name == "T" then t:SetPoint("TOPLEFT", set.TL, "TOPRIGHT") t:SetPoint("BOTTOMRIGHT", set.TR, "BOTTOMLEFT")
    elseif name == "B" then t:SetPoint("TOPLEFT", set.BL, "TOPRIGHT") t:SetPoint("BOTTOMRIGHT", set.BR, "BOTTOMLEFT")
    elseif name == "L" then t:SetPoint("TOPLEFT", set.TL, "BOTTOMLEFT") t:SetPoint("BOTTOMRIGHT", set.BL, "TOPRIGHT")
    elseif name == "R" then t:SetPoint("TOPLEFT", set.TR, "BOTTOMLEFT") t:SetPoint("BOTTOMRIGHT", set.BR, "TOPRIGHT") end
    t:Show()
  end
  set.tex = tex
  return set
end

-- Bord or FlareUI (Border.tga, 4 px biseautés) ; tint : couleur de variante (drops).
function Style.FlareBorder(frame, layer, sub, tint)
  local set = Style.Nine(frame, "border", Style.FLARE.border, 32, 32, 8, 8, layer or "BORDER", sub or 2)
  if set then
    for k, t in pairs(set) do
      if type(t) == "table" and t.SetVertexColor then
        if tint then pcall(t.SetVertexColor, t, math.min(1, tint[1] * 1.5), math.min(1, tint[2] * 1.5), math.min(1, tint[3] * 1.5), 1)
        else pcall(t.SetVertexColor, t, 1, 1, 1, 1) end
      end
    end
    set.tint = tint
  end
  return set
end

local function Solid(frame, key, layer, sub, col, inset)
  frame[key] = frame[key] or Pix(frame, layer, sub)
  local t = frame[key]
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
  t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
  if t.SetColorTexture then pcall(t.SetColorTexture, t, col[1], col[2], col[3], col[4] or 1) end
  pcall(t.SetVertexColor, t, col[1], col[2], col[3], col[4] or 1)
  t._color = col
  t:Show()
  return t
end
Style.Solid = Solid

-- v2.8.1 : chargement vérifié des textures Media/Skin. SetTexture renvoie
-- false (ou GetTexture nil) quand le fichier est introuvable — p. ex. fichiers
-- ajoutés pendant que le jeu tournait (un /reload ne suffit pas : relancer le jeu).
Style.flareLoaded = {}
function Style.TexLoaded(path)
  if type(path) ~= "string" then return false end
  local c = Style.flareLoaded[path]
  if c ~= nil then return c end
  local okF, f = pcall(CreateFrame, "Frame")
  if not okF or type(f) ~= "table" or not f.CreateTexture then return false end
  local t = f:CreateTexture(nil, "BACKGROUND")
  local ok, res = pcall(t.SetTexture, t, path)
  local loaded = ok and res ~= false
  if loaded and res == nil and t.GetTexture then
    local okG, g = pcall(t.GetTexture, t)
    if okG and (g == nil or g == false) then loaded = false end
  end
  if f.Hide then pcall(f.Hide, f) end
  Style.flareLoaded[path] = loaded and true or false
  return Style.flareLoaded[path]
end

-- Encadré : TOUJOURS le dégradé brun clair façon Métiers (#211C18 → #3A2C24,
-- WHITE8X8 + SetGradient, garanti) + filet bronze 1 px (trait sombre dehors) ;
-- le bord or FlareUI (Border.tga) se pose par-dessus seulement s'il est chargé.
function Style.ApplySection(frame, bgKey)
  if type(frame) ~= "table" or not frame.CreateTexture then return nil end
  if frame._osrsSection then return frame._osrsSection end
  if frame.SetBackdrop then pcall(frame.SetBackdrop, frame, nil) end
  local S = Style.SECTION
  frame._osrsSecBg = frame._osrsSecBg or Pix(frame, "BACKGROUND", -8)
  local bg = frame._osrsSecBg
  bg:ClearAllPoints()
  bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
  Gradient(bg, S.top, S.bottom)
  bg._gradient = { S.top, S.bottom }
  bg:Show()
  frame._osrsSecOuter = frame._osrsSecOuter or {}
  frame._osrsSecEdge = frame._osrsSecEdge or {}
  Edge(frame, frame._osrsSecOuter, 0, S.outer, "BORDER")
  Edge(frame, frame._osrsSecEdge, 1, S.bronze, "BORDER")
  local flare = Style.TexLoaded(Style.FLARE.border)
  -- Bord du drop (composant de référence) si l'UI le fournit, sinon FlareUI.
  local hook = Style.SectionBorderHook
  local hooked = hook and select(2, pcall(hook, frame)) or nil
  if hooked then flare = false
  elseif flare then Style.FlareBorder(frame, "BORDER", 2) end
  frame._osrsSecDropBorder = hooked
  frame._osrsSecFlare = flare
  frame._osrsSection = "encadré : dégradé #211C18 → #3A2C24 + filet bronze #634D36" .. (hooked and (" + bord du drop (" .. tostring(hooked) .. ")") or (flare and " + bord or FlareUI (Border.tga)" or " (Border.tga non chargée : filet seul)"))
  Style.applyCount = (Style.applyCount or 0) + 1
  return frame._osrsSection
end

-- Filet 1 px #796345 (sous un en-tête).
function Style.Divider(parent, key)
  parent[key or "_flareDivider"] = parent[key or "_flareDivider"] or Pix(parent, "ARTWORK", 1)
  local t = parent[key or "_flareDivider"]
  local c = Style.PALETTE.divider
  if t.SetColorTexture then pcall(t.SetColorTexture, t, c[1], c[2], c[3], 1) end
  pcall(t.SetVertexColor, t, c[1], c[2], c[3], 1)
  t:SetHeight(1)
  t._color = c
  return t
end

-- Case à cocher FlareUI (CheckBox.tga + CheckMark.tga), API CheckButton standard.
function Style.SkinCheck(cb)
  if type(cb) ~= "table" then return nil end
  local F = Style.FLARE
  if cb.SetNormalTexture then pcall(cb.SetNormalTexture, cb, F.check) end
  if cb.SetPushedTexture then pcall(cb.SetPushedTexture, cb, F.check) end
  if cb.SetCheckedTexture then pcall(cb.SetCheckedTexture, cb, F.mark) end
  if cb.SetDisabledCheckedTexture then pcall(cb.SetDisabledCheckedTexture, cb, F.mark) end
  if cb.SetHighlightTexture then pcall(cb.SetHighlightTexture, cb, F.glow, "ADD") end
  cb._flare = cb._flare or {}
  cb._flare.check = F.check
  return true
end

-- Choix de radio en onglet FlareUI : bouton gris liseré or ; choisi = texte blanc.
function Style.SkinTab(btn, fs)
  if type(btn) ~= "table" then return nil end
  local set = Style.Nine(btn, "tab", Style.FLARE.button, 64, 32, 6, 6, "BACKGROUND", 1)
  if btn.SetNormalTexture then pcall(btn.SetNormalTexture, btn, "") end
  if btn.SetCheckedTexture then pcall(btn.SetCheckedTexture, btn, "") end
  if btn.SetHighlightTexture then pcall(btn.SetHighlightTexture, btn, Style.FLARE.glow, "ADD") end
  btn._flareTab = set
  btn._flareFS = fs
  return set
end
function Style.TabState(btn, checked)
  local fs = btn and btn._flareFS
  local P = Style.PALETTE
  if fs and fs.SetTextColor then
    local c = checked and P.labelWhite or P.titleYellow
    fs:SetTextColor(c[1], c[2], c[3])
  end
  local set = btn and btn._flareTab
  if set then
    local v = checked and 1 or 0.78
    for _, t in pairs(set) do if type(t) == "table" and t.SetVertexColor then pcall(t.SetVertexColor, t, v, v, v, 1) end end
  end
end

-- Curseur FlareUI : piste SliderTrack.tga + losange SliderThumb.tga.
function Style.SkinSlider(sl)
  if type(sl) ~= "table" then return nil end
  local F = Style.FLARE
  if sl.SetBackdrop then pcall(sl.SetBackdrop, sl, nil) end
  sl._flareTrack = sl._flareTrack or (sl.CreateTexture and sl:CreateTexture(nil, "BACKGROUND"))
  local t = sl._flareTrack
  if t then
    pcall(t.SetTexture, t, F.track)
    t.texPath = F.track
    t:ClearAllPoints()
    t:SetPoint("LEFT", sl, "LEFT", 0, 0)
    t:SetPoint("RIGHT", sl, "RIGHT", 0, 0)
    t:SetHeight(16)
    t:Show()
  end
  if sl.SetThumbTexture then pcall(sl.SetThumbTexture, sl, F.thumb) end
  local th = sl.GetThumbTexture and sl:GetThumbTexture()
  if th and th.SetSize then pcall(th.SetSize, th, 24, 24) end
  sl._flareThumb = F.thumb
  return true
end

-- Ascenseur FlareUI (ScrollThumb.tga) sur un UIPanelScrollFrameTemplate à nous.
function Style.SkinScrollBar(scroll)
  local bar = scroll and (scroll.ScrollBar or (scroll.GetName and scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"]))
  if type(bar) ~= "table" then return nil end
  if bar.SetThumbTexture then pcall(bar.SetThumbTexture, bar, Style.FLARE.scroll) end
  local th = bar.GetThumbTexture and bar:GetThumbTexture()
  if th and th.SetSize then pcall(th.SetSize, th, 12, 40) end
  bar._flareThumb = Style.FLARE.scroll
  return true
end

-- Masque rond : seulement si le client le propose (CreateMaskTexture vérifié).
function Style.MaskSupported(frame)
  return type(frame) == "table" and type(frame.CreateMaskTexture) == "function"
end

-- Icône FlareUI : ronde + anneau or (masque disponible) ; sinon cadre biseauté
-- (IconFrame.tga) par-dessus une icône carrée rognée. Rien d'autre dessous.
function Style.IconRing(slot, icon)
  if type(slot) ~= "table" or not slot.CreateTexture then return nil end
  local F = Style.FLARE
  slot._flareRing = slot._flareRing or slot:CreateTexture(nil, "OVERLAY")
  local r = slot._flareRing
  if r.SetDrawLayer then pcall(r.SetDrawLayer, r, "OVERLAY", 6) end
  r:ClearAllPoints()
  r:SetAllPoints(slot)
  local mode
  if icon and Style.MaskSupported(slot) and icon.AddMaskTexture then
    slot._flareMask = slot._flareMask or slot:CreateMaskTexture()
    local m = slot._flareMask
    local ok = pcall(m.SetTexture, m, F.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if ok then
      m:ClearAllPoints()
      m:SetAllPoints(icon)
      if not slot._flareMasked then pcall(icon.AddMaskTexture, icon, m) slot._flareMasked = true end
      mode = "ronde"
    end
  end
  local size = (slot.GetWidth and slot:GetWidth()) or slot._slotSize or 32
  size = tonumber(size) or 32
  local inset = math.max(2, math.floor(size * 3 / 32 + 0.5))
  slot._ringInset = inset
  if mode == "ronde" then
    pcall(r.SetTexture, r, F.ring) r.texPath = F.ring
    if icon then
      icon:ClearAllPoints()
      icon:SetPoint("TOPLEFT", slot, "TOPLEFT", inset, -inset)
      icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -inset, inset)
    end
  else
    mode = "biseautée"
    pcall(r.SetTexture, r, F.frame) r.texPath = F.frame
    if icon then
      icon:ClearAllPoints()
      icon:SetPoint("TOPLEFT", slot, "TOPLEFT", inset, -inset)
      icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -inset, inset)
      if icon.SetTexCoord then pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92) end
    end
  end
  r:Show()
  slot._flareIcon = mode
  return mode
end

-- v2.8.2 : emplacement d'objet NATIF carré (comme les emplacements du
-- personnage) : fond d'emplacement vide, icône carrée rognée, cadre carré or /
-- bronze par-dessus. Relevé en lecture seule sur CharacterHeadSlot (texture
-- NormalTexture + rapport de taille), mémorisé ; repli : textures natives connues.
Style.SLOT_FALLBACK = {
  border = "Interface\\Buttons\\UI-Quickslot2", ratio = 64 / 37,
  empty = "Interface\\Paperdoll\\UI-Backpack-EmptySlot",
}
local function texPath(t)
  if type(t) ~= "table" or not t.GetTexture then return nil end
  local ok, p = pcall(t.GetTexture, t)
  if ok and p ~= nil and not (ns.IsSecret and ns.IsSecret(p)) then return p end
end
function Style.DiscoverItemSlot()
  if Style._slotAsset then return Style._slotAsset end
  local found
  if not (ns.InCombat and ns.InCombat()) then
    for _, n in ipairs({ "CharacterHeadSlot", "CharacterChestSlot", "CharacterHandsSlot" }) do
      local b = _G[n]
      if type(b) == "table" and b.GetNormalTexture then
        local ok, nt = pcall(b.GetNormalTexture, b)
        local p = ok and texPath(nt)
        if p then
          local okW, w = pcall(nt.GetWidth, nt)
          local okB, bw = pcall(b.GetWidth, b)
          w, bw = okW and ns.N(w), okB and ns.N(bw)
          found = { border = p, ratio = (w and bw and bw > 0 and w / bw >= 1 and w / bw <= 2.2) and (w / bw) or Style.SLOT_FALLBACK.ratio, from = n }
          break
        end
      end
    end
  end
  local db = ns.db
  if found then
    if db then db.nativeAssets = db.nativeAssets or {} db.nativeAssets.slot = found end
  elseif db and db.nativeAssets and db.nativeAssets.slot then
    found = db.nativeAssets.slot
  end
  if found then Style._slotAsset = found end
  return found or Style.SLOT_FALLBACK
end
function Style.IconSlot(slot, icon)
  if type(slot) ~= "table" or not slot.CreateTexture then return nil end
  local a = Style.DiscoverItemSlot()
  local size = slot._slotSize or 36
  slot._slotBg = slot._slotBg or slot:CreateTexture(nil, "BACKGROUND")
  local bg = slot._slotBg
  bg:ClearAllPoints()
  bg:SetAllPoints(slot)
  pcall(bg.SetTexture, bg, a.empty or Style.SLOT_FALLBACK.empty)
  bg.texPath = a.empty or Style.SLOT_FALLBACK.empty
  bg:Show()
  slot._slotBorder = slot._slotBorder or slot:CreateTexture(nil, "OVERLAY")
  local b = slot._slotBorder
  if b.SetDrawLayer then pcall(b.SetDrawLayer, b, "OVERLAY", 6) end
  b:ClearAllPoints()
  local bs = math.floor(size * (a.ratio or Style.SLOT_FALLBACK.ratio) + 0.5)
  b:SetSize(bs, bs)
  b:SetPoint("CENTER", slot, "CENTER", 0, 0)
  pcall(b.SetTexture, b, a.border)
  b.texPath = a.border
  b:Show()
  if slot._flareRing then slot._flareRing:Hide() end
  if icon then
    icon:ClearAllPoints()
    icon:SetAllPoints(slot)
    if icon.SetTexCoord then pcall(icon.SetTexCoord, icon, 0.07, 0.93, 0.07, 0.93) end
  end
  slot._flareIcon = "carrée"
  slot._slotAssetFrom = a.from or "repli"
  return "carrée"
end

function Style.DebugLines()
  local d = Style.Probe()
  local out = { "— Style métiers —" }
  local okM, mf = pcall(CreateFrame, "Frame")
  local mask = okM and type(mf) == "table" and type(mf.CreateMaskTexture) == "function"
  out[#out + 1] = "  FlareUI : palette Style.PALETTE (capture bf7d98bd…), textures Media/Skin ; masque rond : " .. (mask and "oui (icônes rondes)" or "non (cadre biseauté)")
  out[#out + 1] = "  rangs de métier (Forever) : 50 / 125 / 200 au maître ; Cuisine, Secourisme : Expert = livre (125), Artisan = quête niv. 35 (points non documentés : jamais vert) ; Pêche : Expert = livre (125, niv. 20), Artisan = quête niv. 35"
  local okT, bad = 0, {}
  local keys = {}
  for k in pairs(Style.FLARE) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    if Style.TexLoaded(Style.FLARE[k]) then okT = okT + 1 else bad[#bad + 1] = k end
  end
  out[#out + 1] = string.format("  textures Flare chargées : %d/%d%s", okT, #keys, (#bad > 0) and (" ; manquantes : " .. table.concat(bad, ", ") .. " (relance complète du jeu si ajoutées en jeu)") or "")
  for _, k in ipairs(keys) do out[#out + 1] = "    " .. k .. " : " .. (Style.TexLoaded(Style.FLARE[k]) and "chargée" or "NON chargée") .. " (" .. Style.FLARE[k] .. ")" end
  out[#out + 1] = "  modules : " .. table.concat(Style.loadReport or { "non chargés (combat ?)" }, ", ")
  out[#out + 1] = "  racines trouvées : " .. ((#(d.roots or {}) > 0) and table.concat(d.roots, ", ") or "aucune")
  out[#out + 1] = "  source : " .. (d.fromSV and "dernière capture (SV)" or (d.found and "fenêtre Métiers" or "aucune (repli)"))
  local any = false
  for id, st in pairs(d.bars or {}) do
    any = true
    local c = st.color and string.format("%.2f/%.2f/%.2f", st.color[1], st.color[2], st.color[3]) or "-"
    out[#out + 1] = string.format("  barre %s : %s%s couleur %s (%s)", id, tostring(st.tex), st.atlas and " [atlas]" or "", c, tostring(st.source))
  end
  if not any then out[#out + 1] = "  barres : aucune trouvée → barres natives colorées (repli)" end
  out[#out + 1] = "  colorées par métier : " .. (d.perSkill and "oui" or "non")
  local s = d.section
  if s then
    local pk = {}
    for k, v in pairs(s.pieces or {}) do pk[#pk + 1] = k .. "=" .. tostring(v.tex) end
    out[#out + 1] = "  encadré : " .. tostring(s.source) .. " fond " .. tostring(s.bg and s.bg.tex) .. " ; pièces " .. ((#pk > 0) and table.concat(pk, ", ") or "aucune")
  else
    out[#out + 1] = "  encadré : aucun trouvé → dégradé brun clair + filet doré (repli)"
  end
  return out
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = Style.DebugLines

-- Nouvelle capture quand la fenêtre Métiers s'ouvre (barres remplies à ce moment).
function Style.HookRoots()
  for _, n in ipairs(Style.ROOTS) do
    local root = _G[n]
    -- v2.7.2 : racine absente (fenêtre Métiers pas encore chargée) → on passe.
    local flags = (type(root) == "table" and ns.NF) and ns.NF(root) or {}
    if type(root) == "table" and root.HookScript and not flags.StyleHooked then
      flags.StyleHooked = true
      pcall(root.HookScript, root, "OnShow", function()
        if ns.ProfJob and ns.ProfJob.Schedule then ns.ProfJob.Schedule("style")
        else Style.Probe(false) end
      end)
    end
  end
end

if ns.On then
  ns.On("ADDON_LOADED", function(_, name)
    for _, a in ipairs(Style.ADDONS) do
      if name == a then Style.HookRoots() end
    end
  end)
  ns.On("PLAYER_LOGIN", function() pcall(Style.HookRoots) end)
  ns.On("TRADE_SKILL_SHOW", function()
    Style.HookRoots()
    if ns.ProfJob and ns.ProfJob.Schedule then ns.ProfJob.Schedule("style")
    else Style.Probe(false) end
  end)
end

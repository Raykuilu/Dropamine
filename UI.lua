-- Dropamine 2.5.0 — vue OSRS dans l'onglet Comp. natif, fenêtre de secours /drop
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
if type(ns) ~= "table" then ns = _G.Dropamine or {} end
local UI = {}
ns.UI = UI

local COLS = 3
local TILE_W, TILE_H, GAP = 118, 54, 4
local TILE_HGAP, TILE_VGAP = 8, 6   -- v2.7.2 : un peu plus d'air entre les tuiles
local HEADER_H = 20
-- Couleurs calquées sur la fiche Comp. native (titres or, valeurs vertes, fond brun).
local GOLD = { 1, 0.82, 0 }
local GOLD_BORDER = { 0.78, 0.62, 0.18, 1 }
local GOLD_BORDER_HOVER = { 1.0, 0.86, 0.28, 1 }
local GOLD_BORDER_SELECTED = { 1.0, 0.94, 0.45, 1 }
local GREEN = { 0.15, 0.95, 0.30 }
local GREY = { 0.55, 0.50, 0.42 }
local BROWN_BG = { 0.10, 0.07, 0.04, 0.96 }
local TILE_BG = { 0.12, 0.08, 0.05, 0.98 }
local TILE_BG_HOVER = { 0.22, 0.15, 0.07, 1 }
local TILE_BG_SELECTED = { 0.20, 0.13, 0.06, 1 }
local TILE_BG_DIM = { 0.10, 0.08, 0.06, 0.85 }
local BAR_BLUE = { 0.20, 0.48, 0.90, 1 }
local BANNER_BG = { 0.22, 0.14, 0.05, 0.97 }
local TOOLTIP_BD = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
-- Filets dorés natifs à essayer (pcall) avant un repli 1 px.
local EDGE_FILES = {
  "Interface\\Tooltips\\UI-Tooltip-Border",
  "Interface\\DialogFrame\\UI-DialogBox-Border",
  "Interface\\CastingBar\\UI-CastingBar-Border",
}
local BAR_FILL_FILES = {
  "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
  "Interface\\TargetingFrame\\UI-StatusBar",
  "Interface\\Buttons\\WHITE8X8",
}
local BAR_BORDER_FILES = {
  "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder",
  "Interface\\CastingBar\\UI-CastingBar-Border",
}
local CHECKBOX_TEX_FILES = {
  "Interface\\Buttons\\UI-CheckBox-Up",
}
local BAR_H = 18
-- v2.5.0 : disposition interne UNIQUE des tuiles (identique quel que soit
-- l'état du panneau droit) : icône 38 px centrée à gauche, puis chiffre,
-- nom et barre empilés serrés sur la hauteur de l'icône.
local TILE_SLOT = 38
local TILE_FIXED_H = 42
local TILE_TEXT_GAP = 6
local TILE_NAME_H, TILE_RANK_H = 12, 10   -- v2.7.2 : hauteurs de ligne (GameFontNormal / HighlightSmall)
local TILE_BAR_H = 15  -- v2.8.3 : hauteur de la barre native (relevée sur la liste native quand possible)
UI.TILE_TOP_PAD = 3     -- v2.8.3 : texte calé en haut de la tuile
local TILE_LEVEL_FONT = "GameFontHighlight"
local GRID_COLS = 2
local GRID_PAD, FOOT_H = 8, 26
-- v2.8.3 : marge gauche/droite de la liste native (relevée), bornée.
function UI:SetGridPad(p)
  p = ns.N(p)
  if p and p >= 2 and p <= 20 then GRID_PAD = math.floor(p + 0.5) end
  UI.gridPad = GRID_PAD
end
local CUSTOM_TAB_TEX = "Interface\\AddOns\\Dropamine\\Media\\SkillsTab"

-- Chromes d'emplacements Forever (sacs / barres de sorts), sondés au pcall.
local SLOT_NORMAL = "Interface\\Buttons\\UI-Quickslot2"
local SLOT_PUSHED = "Interface\\Buttons\\UI-Quickslot-Depress"
local SLOT_HILITE = "Interface\\Buttons\\ButtonHilight-Square"
local SLOT_CHECKED = "Interface\\Buttons\\CheckButtonHilight"
local SLOT_ACTION_BORDER = "Interface\\Buttons\\UI-ActionButton-Border"
local BAR_EDGE_DARK = { 0.12, 0.09, 0.06, 1 }
local BRONZE = { 0.48, 0.36, 0.16, 1 }
local SLOT_TEMPLATES = { "ItemButtonTemplate", "ActionButtonTemplate" }

local function TryCreate(kind, name, parent, template)
  if template then
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f, true end
  end
  return CreateFrame(kind, name, parent), false
end

local TrySetTex, initDBSafe -- déclarés tôt, définis plus bas

-- v2.4.4 : chaque étape d'intégration est isolée. Une erreur cosmétique
-- (filet, icône d'onglet, détail) ne doit plus empêcher la grille de
-- s'accrocher à l'onglet Comp. L'erreur est gardée pour /drop debug et
-- écrite une seule fois dans le chat.
UI.errors = {}
local function SafeStep(label, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    UI.errors[label] = tostring(err)
    UI._errPrinted = UI._errPrinted or {}
    if not UI._errPrinted[label] and ns.Print then
      UI._errPrinted[label] = true
      ns.Print(Tr["|cffff4040erreur|r "] .. tostring(label) .. " : " .. tostring(err))
    end
  end
  return ok, err
end
UI.SafeStep = SafeStep

-- Nos propres cadres ne doivent jamais être pris pour la liste / le détail natifs.
local function IsOwnFrame(f)
  if type(f) ~= "table" then return false end
  if f == UI.embed or f == UI.viewToggle or f == UI.ownDetail or f == UI.frame then return true end
  if rawget(f, "_osrsOwn") then return true end
  local n = f.GetName and f:GetName()
  return type(n) == "string" and string.find(n, "Dropamine", 1, true) == 1
end
local function SetBackdropSafe(f, bd, r, g, b, a, br, bg, bb, ba)
  if not f or not f.SetBackdrop then return false end
  local ok = pcall(f.SetBackdrop, f, bd)
  if not ok then return false end
  if r then pcall(f.SetBackdropColor, f, r, g, b, a) end
  if br then pcall(f.SetBackdropBorderColor, f, br, bg, bb, ba) end
  return true
end

local function FillTexture(tex, r, g, b, a)
  if not tex then return false end
  if tex.SetColorTexture then
    local ok = pcall(tex.SetColorTexture, tex, r, g, b, a)
    if ok then return true end
  end
  if tex.SetTexture then
    local ok = pcall(tex.SetTexture, tex, "Interface\\Buttons\\WHITE8X8")
    if ok then
      if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, r, g, b, a or 1) end
      return true
    end
  end
  return false
end

local function Text(parent, font, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  fs:SetJustifyH(justify or "LEFT")
  return fs
end

-- v2.7.1 (souillure) : aucun champ écrit sur les cadres / tables natifs.
-- Nos drapeaux vivent dans une table à clés faibles.
local NATIVE_FLAGS = setmetatable({}, { __mode = "k" })
local function NF(o)
  -- v2.7.2 : NF(nil) levait « table index is nil » (ADDON_LOADED, UI.lua:143)
  -- quand un cadre natif n'existait pas encore. Table jetable, jamais d'erreur.
  if o == nil then return {} end
  local t = NATIVE_FLAGS[o]
  if not t then t = {} NATIVE_FLAGS[o] = t end
  return t
end
ns.NF = NF

-- Masquer un widget natif SANS Hide/Show (qui exécuterait ses scripts OnShow /
-- OnHide — ScrollBox, fournisseur de données — dans notre contexte souillé) :
-- seulement l'opacité. Notre grille, au-dessus, capte la souris.
local VEIL = setmetatable({}, { __mode = "k" })
-- 3.0.0 : plus AUCUNE astuce d'opacité. Un objet natif à écarter est CACHÉ
-- (Hide) et réaffiché (Show) seulement s'il était visible avant nous. En
-- combat, rien n'est touché : la dernière demande est appliquée à la fin du
-- combat. Jamais sur nos propres cadres.
local VEIL_PENDING = {}
local function NativeVeil(obj, hide)
  if type(obj) ~= "table" or not obj.Hide or not obj.Show then return end
  if IsOwnFrame(obj) or obj._osrsOwn then return end
  if ns.InCombat and ns.InCombat() then
    VEIL_PENDING[obj] = hide and true or false
    if ns.AfterCombat then
      ns.AfterCombat("natif-masque", function()
        local p = VEIL_PENDING
        VEIL_PENDING = {}
        for o, h in pairs(p) do NativeVeil(o, h) end
      end)
    end
    return
  end
  VEIL_PENDING[obj] = nil
  if hide then
    -- état voulu par le natif : s'il a réaffiché l'objet depuis, on le note
    local ok, sh = pcall(obj.IsShown, obj)
    if ok and sh then VEIL[obj] = true
    elseif VEIL[obj] == nil then VEIL[obj] = false end
    if ok and sh then pcall(obj.Hide, obj) end
  else
    local was = VEIL[obj]
    if was ~= nil then
      VEIL[obj] = nil
      if was then pcall(obj.Show, obj) end
    end
  end
end
UI._VEIL = VEIL
ns.NativeVeil = NativeVeil

-- 3.0.1 : contenu du DÉTAIL natif écarté par OPACITÉ (pas Hide) : le natif
-- réaffiche ses propres textes (Show) à chaque mise à jour, ce qui faisait
-- revenir son panneau SOUS le nôtre (double panneau). L'opacité 0 tient.
-- Réservé au détail (aucun clic dans cette zone) ; la liste reste en Hide.
local DVEIL = setmetatable({}, { __mode = "k" })
local function DetailVeil(obj, hide)
  if type(obj) ~= "table" or not obj.SetAlpha then return end
  if IsOwnFrame(obj) or obj._osrsOwn then return end
  if obj.IsProtected then
    local okP, prot = pcall(obj.IsProtected, obj)
    if okP and prot and ns.InCombat and ns.InCombat() then return end
  end
  if hide then
    if DVEIL[obj] == nil then
      local ok, a = pcall(obj.GetAlpha, obj)
      DVEIL[obj] = (ok and type(a) == "number" and a > 0) and a or 1
    end
    pcall(obj.SetAlpha, obj, 0)
  else
    local a = DVEIL[obj]
    if a ~= nil then
      DVEIL[obj] = nil
      pcall(obj.SetAlpha, obj, a)
    end
  end
end
UI._DVEIL = DVEIL
ns.DetailVeil = DetailVeil

local function SetShownSafe(frame, show)
  if not frame then return end
  if frame.SetShown then
    pcall(frame.SetShown, frame, show and true or false)
  elseif show then
    if frame.Show then pcall(frame.Show, frame) end
  else
    if frame.Hide then pcall(frame.Hide, frame) end
  end
end

-- Réutilise un cadre nommé déjà créé (évite les doublons si Init est rappelé).
local function ReuseOrCreate(kind, name, parent, template)
  if type(name) == "string" and type(_G[name]) == "table" and _G[name].SetPoint then
    local f = _G[name]
    if parent and f.SetParent then pcall(f.SetParent, f, parent) end
    return f, true
  end
  return TryCreate(kind, name, parent, template)
end


local function SetTileIcon(tex, path)
  if not tex then return end
  local icon = path or ns.FALLBACK_ICON
  local ok = tex.SetTexture and pcall(tex.SetTexture, tex, icon)
  if not ok and icon ~= ns.FALLBACK_ICON then
    pcall(tex.SetTexture, tex, ns.FALLBACK_ICON)
  end
  -- 3.5.20 : la fiole a son propre alpha — ne pas recadrer (ça coupait la pointe).
  local fold = type(icon) == "string" and string.lower(icon):gsub("/", "\\") or ""
  local logo = string.find(fold, "skillstab", 1, true) or string.find(fold, "dropamine-icon", 1, true)
  if tex.SetTexCoord then
    if logo then pcall(tex.SetTexCoord, tex, 0, 1, 0, 1)
    else pcall(tex.SetTexCoord, tex, 0.07, 0.93, 0.07, 0.93) end
  end
end

local function DisplayNumber(d)
  if d.kind == "stat" then
    return tostring(d.current or 0)
  end
  if d.kind == "level" then
    if d.apiMax and d.apiMax > 0 then
      return tostring(d.current or 0) .. "/" .. tostring(d.apiMax)
    end
    return tostring(d.current or 0)
  end
  if d.apiMax and d.apiMax > 0 then
    return tostring(d.current or 0) .. "/" .. tostring(d.apiMax)
  end
  return tostring(d.current or 0)
end

local function ContributionLine(d)
  if not d then return "" end
  if d.kind == "stat" then
    return Tr["Non inclus dans le total (caractéristique)."]
  end
  if d.excludedMonte then
    return Tr["Affichée mais non incluse : aucun plafond de Monte n'est documenté."]
  end
  if d.combatTile and d.skillName and d.skillName ~= d.name then
    return Tr["Compte dans le total : +"] .. tostring(d.current or 0) .. "  (" .. d.skillName .. ")"
  end
  if d.inTotal then
    return Tr["Compte dans le total : +"] .. tostring(d.current or 0)
  end
  return ""
end

-- Construction d'une tuile compacte (icône + valeur réelle) -----------------
-- Chrome doré natif (filet type barre Comp. / tooltip, repli 1 px) ------------
local function Colorize(tex, r, g, b, a)
  if not tex then return end
  if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, r, g, b, a or 1)
  else FillTexture(tex, r, g, b, a or 1) end
end

local function EnsurePixelBorder(frame, layer)
  if frame._osrsPix then return frame._osrsPix end
  local t = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local tex = frame:CreateTexture(nil, layer or "OVERLAY")
    FillTexture(tex, GOLD_BORDER[1], GOLD_BORDER[2], GOLD_BORDER[3], 1)
    t[side] = tex
  end
  t.TOP:SetHeight(1)
  t.TOP:SetPoint("TOPLEFT", 0, 0)
  t.TOP:SetPoint("TOPRIGHT", 0, 0)
  t.BOTTOM:SetHeight(1)
  t.BOTTOM:SetPoint("BOTTOMLEFT", 0, 0)
  t.BOTTOM:SetPoint("BOTTOMRIGHT", 0, 0)
  t.LEFT:SetWidth(1)
  t.LEFT:SetPoint("TOPLEFT", 0, 0)
  t.LEFT:SetPoint("BOTTOMLEFT", 0, 0)
  t.RIGHT:SetWidth(1)
  t.RIGHT:SetPoint("TOPRIGHT", 0, 0)
  t.RIGHT:SetPoint("BOTTOMRIGHT", 0, 0)
  frame._osrsPix = t
  return t
end

local function ColorPixelBorder(frame, r, g, b, a)
  local t = frame._osrsPix
  if not t then return end
  Colorize(t.TOP, r, g, b, a)
  Colorize(t.BOTTOM, r, g, b, a)
  Colorize(t.LEFT, r, g, b, a)
  Colorize(t.RIGHT, r, g, b, a)
end

local function ShowPixelBorder(frame, show)
  local t = frame._osrsPix
  if not t then return end
  for _, tex in pairs(t) do
    if show then tex:Show() else tex:Hide() end
  end
end

-- Essaie un backdrop avec filet doré du client ; sinon filet 1 px.
local function ApplyGoldEdge(frame, edgeSize)
  if not frame then return false end
  if frame._osrsEdgeApplied then return frame._osrsEdgeOk and true or false end
  frame._osrsEdgeApplied = true
  -- Reprendre le filet d'une barre native si on l'a déjà observé.
  local files = {}
  if UI.nativeEdgeFile then files[#files + 1] = UI.nativeEdgeFile end
  for i = 1, #EDGE_FILES do files[#files + 1] = EDGE_FILES[i] end
  if frame.SetBackdrop then
    for i = 1, #files do
      local bd = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = files[i],
        tile = true,
        tileSize = 8,
        edgeSize = edgeSize or UI.nativeEdgeSize or 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
      }
      if pcall(frame.SetBackdrop, frame, bd) then
        frame._osrsEdgeOk = true
        frame._osrsEdgeFile = files[i]
        return true
      end
    end
  end
  frame._osrsEdgeOk = false
  EnsurePixelBorder(frame, "OVERLAY")
  return false
end

local function SetGoldEdgeColor(frame, r, g, b, a)
  if frame and frame._osrsEdgeOk and frame.SetBackdropBorderColor then
    pcall(frame.SetBackdropBorderColor, frame, r, g, b, a or 1)
  end
  ColorPixelBorder(frame, r, g, b, a)
end

local function SetGoldFill(frame, r, g, b, a)
  if frame and frame.SetBackdropColor then
    pcall(frame.SetBackdropColor, frame, r, g, b, a)
  end
  if frame and frame.bg then
    FillTexture(frame.bg, r, g, b, a)
  end
end

local function RegionTexPath(obj)
  if not obj then return nil, false end
  if obj.GetTexture then
    local ok, path = pcall(obj.GetTexture, obj)
    if ok and type(path) == "string" and path ~= "" then return path, false end
  end
  if obj.GetAtlas then
    local ok, atlas = pcall(obj.GetAtlas, obj)
    if ok and type(atlas) == "string" and atlas ~= "" then return atlas, true end
  end
  return nil, false
end

function UI:LearnNativeBarChrome()
  if self.nativeBarTex and self.nativeBarBorder then return end
  local candidates = {
    _G.SkillDetailStatusBar, _G.SkillRankFrame, _G.SkillRankFrame1,
    _G.ReputationBar1, _G.ReputationWatchBar,
  }
  -- SkillRankFrame1..20
  for i = 1, 20 do
    candidates[#candidates + 1] = _G["SkillRankFrame" .. i]
    candidates[#candidates + 1] = _G["SkillRankFrame" .. i .. "StatusBar"]
  end
  -- Probe ReputationBarTemplate by creating a hidden throwaway if needed later.
  for ci = 1, #candidates do
    local bar = candidates[ci]
    if type(bar) == "table" then
      if not self.nativeBarTex and bar.GetStatusBarTexture then
        local ok, tex = pcall(bar.GetStatusBarTexture, bar)
        if ok then
          local path, isAtlas = RegionTexPath(tex)
          if path then self.nativeBarTex, self.nativeBarTexAtlas = path, isAtlas end
        end
      end
      if not self.nativeBarColor and bar.GetStatusBarColor then
        local ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
        -- Ne retenir que le bleu des barres Comp. (pas le vert/jaune de réputation).
        if ok and r and (b or 0) > (r or 0) and (b or 0) > (g or 0) then
          self.nativeBarColor = { r, g, b, a or 1 }
        end
      end
      if not self.nativeBarBorder then
        local names = { "Border", "barBorder", "BarBorder" }
        for ni = 1, #names do
          local bd = bar[names[ni]]
          local path, isAtlas = RegionTexPath(bd)
          if path then self.nativeBarBorder, self.nativeBarBorderAtlas = path, isAtlas break end
        end
        if not self.nativeBarBorder and bar.GetName then
          local n = bar:GetName()
          if n then
            local path, isAtlas = RegionTexPath(_G[n .. "Border"] or _G[n .. "BarBorder"])
            if path then self.nativeBarBorder, self.nativeBarBorderAtlas = path, isAtlas end
          end
        end
      end
      if not self.nativeEdgeFile and bar.GetBackdrop then
        local ok, bd = pcall(bar.GetBackdrop, bar)
        if ok and type(bd) == "table" and bd.edgeFile then
          self.nativeEdgeFile, self.nativeEdgeSize = bd.edgeFile, bd.edgeSize
        end
      end
    end
  end
end

function UI:LearnNativeCheckboxChrome()
  if self.nativeCheckTex then return end
  local names = {
    "ReputationDetailAtWarCheckBox", "ReputationDetailInactiveCheckBox",
    "ReputationDetailMainScreenCheckBox", "ReputationDetailCheckBox",
  }
  for i = 1, #names do
    local cb = _G[names[i]]
    if type(cb) == "table" and cb.GetNormalTexture then
      local ok, nt = pcall(cb.GetNormalTexture, cb)
      if ok then
        local path, isAtlas = RegionTexPath(nt)
        if path then
          self.nativeCheckTex, self.nativeCheckAtlas = path, isAtlas
          return
        end
      end
    end
  end
  -- Repli : instancier un UICheckButtonTemplate caché pour lire sa texture.
  if not self.nativeCheckTex and type(CreateFrame) == "function" then
    local ok, tmp = pcall(CreateFrame, "CheckButton", "DropamineCheckProbe", UIParent, "UICheckButtonTemplate")
    if ok and tmp then
      if tmp.Hide then pcall(tmp.Hide, tmp) end
      if tmp.GetNormalTexture then
        local ok2, nt = pcall(tmp.GetNormalTexture, tmp)
        if ok2 then
          local path, isAtlas = RegionTexPath(nt)
          if path then self.nativeCheckTex, self.nativeCheckAtlas = path, isAtlas end
        end
      end
    end
  end
end

function UI:LearnNativeChrome()
  self:LearnNativeBarChrome()
  self:LearnNativeCheckboxChrome()
  -- On n'empêche plus les essais suivants : les cadres peuvent apparaître plus tard.
end

-- Couleur du filet intérieur Forever, relevée sur le séparateur de la fiche (repli).
local NATIVE_INSET_COLOR = { 0.53, 0.41, 0.26, 1 }
local INSET_EDGE_FALLBACKS = {
  "Interface\\FrameGeneral\\UI-Frame",
  "Interface\\FrameGeneral\\UIFrameBorder",
  "Interface\\Common\\ThinGoldEdge",
  "Interface\\DialogFrame\\UI-DialogBox-Border",
}

local INSET_NAME_HINTS = { "inset", "nineslice", "separator", "divider", "border", "edge", "bordered" }

local function LabelLooksInset(label)
  if type(label) ~= "string" then return false end
  local l = string.lower(label)
  if string.find(l, "osrs", 1, true) then return false end
  for i = 1, #INSET_NAME_HINTS do
    if string.find(l, INSET_NAME_HINTS[i], 1, true) then return true end
  end
  return false
end

function UI:HarvestFrameBorders(root, out, prefix, depth, learn)
  out = out or {}
  if not root or (depth or 0) > 5 or #out > 80 then return out end
  local fname = (root.GetName and root:GetName()) or (prefix ~= "" and prefix) or "(sans nom)"
  local function consider(tex, label)
    if type(tex) ~= "table" then return end
    local path, isAtlas = RegionTexPath(tex)
    if not path then return end
    local rec = { path = path, atlas = isAtlas and true or false, label = label }
    if tex.GetVertexColor then
      local ok, r, g, b, a = pcall(tex.GetVertexColor, tex)
      if ok and r then rec.color = { r, g, b, a or 1 } end
    end
    out[#out + 1] = rec
    if learn and (not self.nativeInsetEdge) and LabelLooksInset(label) then
      self.nativeInsetEdge = path
      self.nativeInsetAtlas = isAtlas and true or false
      self.nativeInsetSource = label
      if rec.color then self.nativeInsetColor = rec.color end
    end
  end
  -- NineSlice (fiches Mainline / Forever)
  if type(root.NineSlice) == "table" then
    local keys = {
      "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
      "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    }
    for i = 1, #keys do
      consider(root.NineSlice[keys[i]], tostring(fname) .. ".NineSlice." .. keys[i])
    end
  end
  if root.GetRegions then
    local regs = { pcall(root.GetRegions, root) }
    if regs[1] then
      for i = 2, #regs do
        local r = regs[i]
        local rn = (r and r.GetName and r:GetName()) or ("region" .. (i - 1))
        consider(r, tostring(fname) .. "." .. tostring(rn))
      end
    end
  end
  if type(root.Inset) == "table" then
    self:HarvestFrameBorders(root.Inset, out, tostring(fname) .. ".Inset", (depth or 0) + 1, learn)
  end
  if root.GetChildren then
    local kids = { pcall(root.GetChildren, root) }
    if kids[1] then
      for i = 2, #kids do
        local c = kids[i]
        local cn = (c and c.GetName and c:GetName()) or ""
        if LabelLooksInset(cn) or (depth or 0) < 2 then
          self:HarvestFrameBorders(c, out, (cn ~= "" and cn) or (tostring(fname) .. ".child"), (depth or 0) + 1, learn)
        end
      end
    end
  end
  return out
end

function UI:LearnNativeInsetBorder()
  if self.nativeInsetEdge then return end
  local roots = {
    _G.SkillFrame, _G.SkillDetailFrame, _G.CharacterFrame,
    _G.CharacterFrameInset, _G.CharacterFrameInsetFrame,
    self.skillFrame, self.nativeDetail,
  }
  if _G.CharacterFrame and type(_G.CharacterFrame.Inset) == "table" then
    roots[#roots + 1] = _G.CharacterFrame.Inset
  end
  self._insetHarvest = self._insetHarvest or {}
  for i = 1, #roots do
    if type(roots[i]) == "table" then
      self:HarvestFrameBorders(roots[i], self._insetHarvest, "", 0, true)
    end
  end
end

function UI:ApplyNativeInsetBorder(frame)
  if not frame then return "none" end
  self:LearnNativeChrome()
  self:LearnNativeInsetBorder()
  -- Pas de fond : uniquement le filet (le pied doit laisser voir le bois natif).
  local edges = {}
  if self.nativeInsetEdge and not self.nativeInsetAtlas then
    edges[#edges + 1] = self.nativeInsetEdge
  end
  for i = 1, #INSET_EDGE_FALLBACKS do edges[#edges + 1] = INSET_EDGE_FALLBACKS[i] end
  for i = 1, #edges do
    local bd = {
      bgFile = nil,
      edgeFile = edges[i],
      edgeSize = self.nativeInsetEdgeSize or 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    }
    if SetBackdropSafe(frame, bd, 0, 0, 0, 0, 1, 1, 1, 1) then
      if frame._osrsPix then ShowPixelBorder(frame, false) end
      frame._osrsNativeBorder = edges[i]
      return "backdrop:" .. edges[i]
    end
    -- Certains clients exigent un bgFile : fond 100 % transparent.
    bd.bgFile = "Interface\\Buttons\\WHITE8X8"
    if SetBackdropSafe(frame, bd, 0, 0, 0, 0, 1, 1, 1, 1) then
      if frame._osrsPix then ShowPixelBorder(frame, false) end
      frame._osrsNativeBorder = edges[i]
      return "backdrop-bg:" .. edges[i]
    end
  end
  -- Atlas NineSlice : on habille les 4 côtés avec la même pièce.
  local t = EnsurePixelBorder(frame, "OVERLAY")
  local col = self.nativeInsetColor or NATIVE_INSET_COLOR
  local usedAtlas = false
  if self.nativeInsetEdge and self.nativeInsetAtlas then
    usedAtlas = TrySetTex(t.TOP, self.nativeInsetEdge, nil, true)
      and TrySetTex(t.BOTTOM, self.nativeInsetEdge, nil, true)
      and TrySetTex(t.LEFT, self.nativeInsetEdge, nil, true)
      and TrySetTex(t.RIGHT, self.nativeInsetEdge, nil, true)
  end
  t.TOP:SetHeight(2)
  t.BOTTOM:SetHeight(2)
  t.LEFT:SetWidth(2)
  t.RIGHT:SetWidth(2)
  ColorPixelBorder(frame, col[1], col[2], col[3], col[4] or 1)
  ShowPixelBorder(frame, true)
  frame._osrsNativeBorder = usedAtlas and ("atlas:" .. self.nativeInsetEdge) or "fallback-color"
  return frame._osrsNativeBorder
end

function UI:DebugInsetLines()
  self:LearnNativeInsetBorder()
  local lines = {}
  local function add(s) lines[#lines + 1] = s end
  add("  filet retenu : " .. tostring(self.nativeInsetEdge or "aucun (repli couleur séparateur)"))
  add("  atlas : " .. (self.nativeInsetAtlas and "oui" or "non"))
  add("  source : " .. tostring(self.nativeInsetSource or "—"))
  local harvest = {}
  local roots = { _G.SkillFrame, _G.SkillDetailFrame, _G.CharacterFrame, _G.CharacterFrameInset, self.skillFrame }
  for i = 1, #roots do
    if type(roots[i]) == "table" then
      self:HarvestFrameBorders(roots[i], harvest, "", 0, false)
    end
  end
  if #harvest == 0 then
    add("  (aucune région Inset/Border/NineSlice trouvée ; ouvre la fiche puis /drop debug)")
  else
    local n = math.min(#harvest, 40)
    add("  régions sondées (" .. tostring(#harvest) .. ", max " .. tostring(n) .. ") :")
    for i = 1, n do
      local rec = harvest[i]
      add("    " .. tostring(rec.label) .. " = " .. (rec.atlas and "atlas:" or "") .. tostring(rec.path))
    end
  end
  return lines
end

function UI:LearnNativeChrome()
  self:LearnNativeBarChrome()
  self:LearnNativeCheckboxChrome()
  self:LearnNativeInsetBorder()
end


local function ApplyBarFill(bar)
  local files = {}
  if UI.nativeBarTex then files[#files + 1] = UI.nativeBarTex end
  for i = 1, #BAR_FILL_FILES do files[#files + 1] = BAR_FILL_FILES[i] end
  local applied = false
  if bar.SetStatusBarTexture then
    for i = 1, #files do
      if pcall(bar.SetStatusBarTexture, bar, files[i]) then
        applied = true
        break
      end
    end
  end
  local col = (UI.BarBlueColor and UI:BarBlueColor()) or BAR_BLUE
  if bar.SetStatusBarColor then
    pcall(bar.SetStatusBarColor, bar, col[1], col[2], col[3], col[4] or 1)
  end
  return applied
end

function UI:BarBlueColor()
  local col = self.nativeBarColor
  if col and (col[3] or 0) > (col[1] or 0) and (col[3] or 0) > (col[2] or 0) then
    return col
  end
  local nb = self.nativeSkillBar
  if nb and nb.color then return nb.color end
  return BAR_BLUE
end

local function ApplyNumberColor(fs, cur, cap, d)
  if not fs or not fs.SetTextColor then return end
  local col = GREEN
  -- v2.8.0 : niveau (XP du niveau), métiers (rang suivant), armes / défense.
  local st = d and ns.RankStatus and ns.RankStatus(d, cur, cap)
  if st and st.col then
    fs:SetTextColor(st.col[1], st.col[2], st.col[3])
    fs._rankState = st.state
    return st
  end
  fs._rankState = nil
  if ns.NumberColorForProgress then
    local c = ns.NumberColorForProgress(cur, cap)
    if type(c) == "table" then col = c end
  end
  fs:SetTextColor(col[1], col[2], col[3])
end

TrySetTex = function(tex, path, blend, asAtlas)
  if not tex or not path then return false end
  if asAtlas and tex.SetAtlas then
    if pcall(tex.SetAtlas, tex, path) then
      if blend and tex.SetBlendMode then pcall(tex.SetBlendMode, tex, blend) end
      return true
    end
  end
  if tex.SetTexture and pcall(tex.SetTexture, tex, path) then
    if blend and tex.SetBlendMode then pcall(tex.SetBlendMode, tex, blend) end
    return true
  end
  return false
end

-- Le filet et l'icône partagent le même centre et la même taille.
-- On n'utilise plus UI-Quickslot2 à 64/36 : en jeu le filet dépassait
-- l'icône et se décalait à gauche (ancres du template + overlay trop grand).
local function SizeSlotOverlay(tex, slot)
  if not tex or not slot then return end
  if tex.ClearAllPoints then tex:ClearAllPoints() end
  tex:SetAllPoints(slot)
end

local function ThinDarkBorder(frame)
  -- Filet sombre type barre de cadre d'unité, PAS le filet jaune plat des tooltips.
  EnsurePixelBorder(frame, "OVERLAY")
  ColorPixelBorder(frame, BAR_EDGE_DARK[1], BAR_EDGE_DARK[2], BAR_EDGE_DARK[3], BAR_EDGE_DARK[4])
end

local function ThinBronzeBorder(frame)
  -- Filet unique : le cadre intérieur / séparateur Forever, pas notre or maison.
  if UI.ApplyNativeInsetBorder then
    -- Jamais bloquant : un filet raté ne doit pas empêcher la grille.
    local ok = SafeStep("filet natif", UI.ApplyNativeInsetBorder, UI, frame)
    if not ok then
      EnsurePixelBorder(frame, "OVERLAY")
      ColorPixelBorder(frame, NATIVE_INSET_COLOR[1], NATIVE_INSET_COLOR[2], NATIVE_INSET_COLOR[3], 1)
    end
  else
    EnsurePixelBorder(frame, "OVERLAY")
    ColorPixelBorder(frame, (NATIVE_INSET_COLOR or GOLD_BORDER)[1], (NATIVE_INSET_COLOR or GOLD_BORDER)[2], (NATIVE_INSET_COLOR or GOLD_BORDER)[3], 1)
  end
end

-- Barre type Comp. / réputation Forever : ~18 px, fond sombre, filet bronze, remplissage BLEU, texte au centre.
local function SkinBarHolder(hold, height)
  if not hold then return end
  hold:SetHeight(height or BAR_H)
  if not hold.bg then
    hold.bg = hold:CreateTexture(nil, "BACKGROUND")
    hold.bg:SetAllPoints()
  end
  FillTexture(hold.bg, 0.05, 0.04, 0.03, 0.95)
  if hold.borderTex then hold.borderTex:Hide() end
  -- Un seul filet partout (barre, pied, drops) : le cadre intérieur Forever.
  ThinBronzeBorder(hold)
end

local function EnsureBarText(hold)
  if hold.barText then return hold.barText end
  local fs = Text(hold, "GameFontHighlightSmall", "CENTER")
  fs:SetPoint("CENTER", 0, 0)
  fs:SetTextColor(1, 1, 1)
  if fs.SetDrawLayer then pcall(fs.SetDrawLayer, fs, "OVERLAY", 7) end
  hold.barText = fs
  return fs
end

local function SetBlueBarProgress(hold, bar, cur, cap, widthHint)
  if not hold then return end
  cur, cap = ns.N(cur) or 0, ns.N(cap) or 0
  SkinBarHolder(hold, BAR_H)
  local barW = widthHint
  if (not barW or barW < 8) and hold.GetWidth then
    local ok, v = pcall(hold.GetWidth, hold)
    if ok then barW = ns.N(v) end
  end
  if not barW or barW < 8 then barW = 80 end
  if widthHint and widthHint >= 8 and hold.SetWidth then hold:SetWidth(widthHint) end
  hold:Show()
  local col = (UI.BarBlueColor and UI:BarBlueColor()) or BAR_BLUE
  if bar then
    if bar.SetMinMaxValues and cap > 0 then pcall(bar.SetMinMaxValues, bar, 0, cap) end
    if bar.SetValue then pcall(bar.SetValue, bar, cur) end
    ApplyBarFill(bar)
    if bar.SetStatusBarColor then pcall(bar.SetStatusBarColor, bar, col[1], col[2], col[3], col[4] or 1) end
    if bar.Show then bar:Show() end
  end
  if not hold.fill then
    hold.fill = hold:CreateTexture(nil, "ARTWORK")
    hold.fill:SetPoint("TOPLEFT", 1, -1)
    hold.fill:SetPoint("BOTTOMLEFT", 1, 1)
  end
  FillTexture(hold.fill, col[1], col[2], col[3], col[4] or 1)
  local inner = math.max(0, barW - 2)
  local pct = (cap > 0) and (cur / cap) or 0
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  local fw = inner * pct
  if fw < 0.5 and cur > 0 and cap > 0 then fw = 0.5 end
  hold.fill:SetWidth((fw > 0) and fw or 0.01)
  if fw > 0 then hold.fill:Show() else hold.fill:Hide() end
  local fs = EnsureBarText(hold)
  fs:SetText((cap > 0) and (tostring(cur) .. " / " .. tostring(cap)) or tostring(cur))
  -- Le chiffre de palier (tuile) est coloré ailleurs ; le texte SUR la barre reste blanc (lisible sur le bleu).
  fs:SetTextColor(1, 1, 1)
  if fs.Show then fs:Show() end
end

-- v2.4.4 : barres copiées sur les barres de rang natives de l'onglet Comp.
-- (SkillRankFrameN / SkillDetailStatusBar) : même texture de remplissage,
-- même fond, même cadre (UI-Character-Skills-BarBorder) et même géométrie,
-- relevés en jeu ; valeurs du template natif en repli.
local NATIVE_SKILLBAR_FILE = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
local NATIVE_SKILLBAR_BORDER = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"
local NATIVE_SKILLBAR_COLOR = { 0.0, 0.40, 1.0, 1 }   -- v2.8.4 : repli bleu natif (plus le violet)
local NATIVE_SKILLBAR_BG = { 0, 0, 0, 0.75 }         -- v2.8.4 : repli fond quasi noir (plus le gris)
local NATIVE_SKILLBAR_H = 15
UI.THIN_NATIVE_EDGE = { 0.42, 0.40, 0.36, 0.9 }   -- gris-acier du cadre natif SkillRankFrame, en 1 px
-- SkillStatusBarTemplate : barre 271×15, cadre 281×32 ancré LEFT -5.
local NATIVE_BORDER_GEOM = { dw = 10, x = -5, y = 0, hRatio = 32 / 15 }

local function TexOrFileID(obj)
  if type(obj) ~= "table" then return nil, false end
  if obj.GetAtlas then
    local ok, a = pcall(obj.GetAtlas, obj)
    if ok and type(a) == "string" and a ~= "" then return a, true end
  end
  if obj.GetTexture then
    local ok, p = pcall(obj.GetTexture, obj)
    if ok and ((type(p) == "string" and p ~= "") or type(p) == "number") then return p, false end
  end
  return nil, false
end

local function SizeOf(f)
  local w, h
  if f and f.GetWidth then local ok, v = pcall(f.GetWidth, f) if ok then w = ns.N(v) end end
  if f and f.GetHeight then local ok, v = pcall(f.GetHeight, f) if ok then h = ns.N(v) end end
  return w, h
end

function UI:LearnNativeSkillBar()
  if self.nativeSkillBar and self.nativeSkillBar.fromList then return self.nativeSkillBar end
  -- v2.8.3 : barre lue sur une vraie ligne de la liste native (ScrollBox) :
  -- texture/atlas de remplissage, couleur, hauteur, fond + cadre clonés.
  local L = ns.NativeLook and ns.NativeLook.ProbeList and ns.NativeLook.ProbeList()
  if L and L.bar and (L.bar.tex or L.bar.atlas) then
    local b = L.bar
    self.nativeSkillBar = {
      tex = b.atlas or b.tex, texAtlas = b.atlas and true or false,
      color = b.color or NATIVE_SKILLBAR_COLOR, bg = NATIVE_SKILLBAR_BG,
      h = (b.h and b.h >= 6 and b.h <= 30) and b.h or NATIVE_SKILLBAR_H,
      border = { tex = NATIVE_SKILLBAR_BORDER, atlas = false, dw = NATIVE_BORDER_GEOM.dw,
                 x = NATIVE_BORDER_GEOM.x, y = NATIVE_BORDER_GEOM.y, hRatio = NATIVE_BORDER_GEOM.hRatio },
      look = b.look, textFont = b.textFont,
      learned = true, fromList = true, source = "liste native" .. (L.cached and " (mémorisée)" or ""),
    }
    return self.nativeSkillBar
  end
  if self.nativeSkillBar and self.nativeSkillBar.learned then return self.nativeSkillBar end
  local info = {
    tex = NATIVE_SKILLBAR_FILE, texAtlas = false, color = NATIVE_SKILLBAR_COLOR,
    bg = NATIVE_SKILLBAR_BG, h = NATIVE_SKILLBAR_H,
    border = { tex = NATIVE_SKILLBAR_BORDER, atlas = false, dw = NATIVE_BORDER_GEOM.dw,
               x = NATIVE_BORDER_GEOM.x, y = NATIVE_BORDER_GEOM.y, hRatio = NATIVE_BORDER_GEOM.hRatio },
    learned = false, source = "template natif (repli)",
  }
  local names = {}
  for i = 1, 30 do names[#names + 1] = "SkillRankFrame" .. i end
  names[#names + 1] = "SkillDetailStatusBar"
  if UI._noNativeScan then names = {} end   -- 3.2.0 : on ne lit plus rien du natif
  for i = 1, #names do
    local n = names[i]
    local bar = _G[n]
    if type(bar) == "table" and bar.GetStatusBarTexture then
      local okT, tex = pcall(bar.GetStatusBarTexture, bar)
      local path, isAtlas = TexOrFileID(okT and tex or nil)
      if path then
        info.tex, info.texAtlas = path, isAtlas
        if bar.GetStatusBarColor then
          local ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
          if ok and r and (b or 0) >= (r or 0) and (b or 0) >= (g or 0) then info.color = { r, g, b, a or 1 } end
        end
        local bw, bh = SizeOf(bar)
        if bh and bh >= 8 and bh <= 30 then info.h = bh end
        local bgTex = _G[n .. "Background"]
        if type(bgTex) == "table" and bgTex.GetVertexColor then
          local ok, r, g, b, a = pcall(bgTex.GetVertexColor, bgTex)
          if ok and r then info.bg = { r, g, b, a or NATIVE_SKILLBAR_BG[4] } end
          local bgPath = TexOrFileID(bgTex)
          if bgPath then info.bgTex = bgPath end
        end
        local border = _G[n .. "Border"] or bar.Border
        if type(border) == "table" then
          local btex = border
          if border.GetNormalTexture then
            local ok, nt = pcall(border.GetNormalTexture, border)
            if ok and nt then btex = nt end
          end
          local bpath, batlas = TexOrFileID(btex)
          if bpath then
            local ow, oh = SizeOf(border)
            local pt, _, _, x, y
            if border.GetPoint then
              local okp
              okp, pt, _, _, x, y = pcall(border.GetPoint, border, 1)
              if not okp then pt, x, y = nil, nil, nil end
            end
            info.border.tex, info.border.atlas = bpath, batlas
            if bw and ow and ow > bw then info.border.dw = ow - bw end
            if bh and oh and bh > 0 and oh > 0 then info.border.hRatio = oh / bh end
            if pt == "LEFT" and ns.N(x) then info.border.x, info.border.y = ns.N(x), ns.N(y) or 0 end
          end
        end
        info.learned = true
        info.source = n
        break
      end
    end
  end
  self.nativeSkillBar = info
  return info
end

-- Habille un porte-barre comme une barre de rang native.
local function SkinNativeSkillBar(hold, bar, width, heightOverride)
  if not hold then return end
  local nb = UI:LearnNativeSkillBar()
  local h = heightOverride or nb.h or NATIVE_SKILLBAR_H
  hold:SetHeight(h)
  if width and width >= 8 and hold.SetWidth then hold:SetWidth(width) end
  -- Plus de filet maison ni de backdrop : seul le cadre natif.
  if hold._osrsPix then ShowPixelBorder(hold, false) end
  if hold.SetBackdrop then pcall(hold.SetBackdrop, hold, nil) end
  if hold.borderTex then hold.borderTex:Hide() end
  if hold.fill then hold.fill:Hide() end
  if not hold.bg then
    hold.bg = hold:CreateTexture(nil, "BACKGROUND")
  end
  hold.bg:ClearAllPoints()
  hold.bg:SetAllPoints(hold)
  local bgc = nb.bg or NATIVE_SKILLBAR_BG
  if nb.bgTex then
    TrySetTex(hold.bg, nb.bgTex)
    if hold.bg.SetVertexColor then pcall(hold.bg.SetVertexColor, hold.bg, bgc[1], bgc[2], bgc[3], bgc[4] or 0.2) end
  else
    FillTexture(hold.bg, bgc[1], bgc[2], bgc[3], bgc[4] or 0.2)
  end
  -- Style « Métiers » : barre colorée / texturée par compétence si relevée.
  local ps = hold._styleSkill and ns.Style and ns.Style.BarFor(hold._styleSkill) or nil
  hold._styleUsed = ps and (ps.fallback and "repli coloré" or ("métiers:" .. tostring(ps.source))) or nil
  if ps and ps.bg and not ps.fallback then
    TrySetTex(hold.bg, ps.bg.tex, nil, ps.bg.atlas and ps.bg.tex or nil)
    if ps.bg.color and hold.bg.SetVertexColor then pcall(hold.bg.SetVertexColor, hold.bg, unpack(ps.bg.color)) end
  end
  if bar then
    bar:ClearAllPoints()
    bar:SetAllPoints(hold)
    if bar.SetStatusBarTexture then
      local texPath, texAtlas = nb.tex, nb.texAtlas
      if ps and ps.tex then texPath, texAtlas = ps.tex, ps.atlas end
      local okT = false
      if texAtlas and bar.GetStatusBarTexture then
        local ok, t = pcall(bar.GetStatusBarTexture, bar)
        if ok and t and t.SetAtlas then okT = pcall(t.SetAtlas, t, texPath) end
      end
      if not okT then okT = pcall(bar.SetStatusBarTexture, bar, texPath) end
      if not okT then pcall(bar.SetStatusBarTexture, bar, NATIVE_SKILLBAR_FILE) end
      bar._styleTex = texPath
    end
    local col = (ps and ps.color) or nb.color or NATIVE_SKILLBAR_COLOR
    if bar.SetStatusBarColor then pcall(bar.SetStatusBarColor, bar, col[1], col[2], col[3], col[4] or 1) end
  end
  -- Cadre au-dessus de la barre (comme le bouton $parentBorder natif).
  if not hold.nbOverlay then
    hold.nbOverlay = CreateFrame("Frame", nil, hold)
    if hold.nbOverlay.EnableMouse then hold.nbOverlay:EnableMouse(false) end
    hold.nbOverlay:SetAllPoints(hold)
    hold.nbBorder = hold.nbOverlay:CreateTexture(nil, "ARTWORK")
    hold.nbText = hold.nbOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  end
  if hold.nbOverlay.SetFrameLevel and hold.GetFrameLevel then
    local base = hold:GetFrameLevel() or 1
    if bar and bar.GetFrameLevel then base = math.max(base, bar:GetFrameLevel() or base) end
    pcall(hold.nbOverlay.SetFrameLevel, hold.nbOverlay, base + 2)
  end
  local bd = nb.border
  local w = width
  if not w or w < 8 then w = select(1, SizeOf(hold)) or 80 end
  local btex = hold.nbBorder
  btex:ClearAllPoints()
  btex:SetPoint("LEFT", hold, "LEFT", bd.x or -5, bd.y or 0)
  btex:SetSize(w + (bd.dw or 10), math.floor(h * (bd.hRatio or (32 / 15)) + 0.5))
  if not TrySetTex(btex, bd.tex, nil, bd.atlas) then TrySetTex(btex, NATIVE_SKILLBAR_BORDER) end
  btex:Show()
  hold._osrsNativeBorder = "skillbar:" .. tostring(bd.tex)
  -- v2.8.3 : fond + cadre clonés de la barre native (fond sous le remplissage,
  -- cadre au-dessus), couleurs relevées telles quelles.
  local NLk = ns.NativeLook
  local usedClone = false
  if nb.look and nb.look.parts and #nb.look.parts > 0 and NLk and NLk.ApplyClone and not hold._thinNative and not hold._metiers then
    local under, over = { w = nb.look.w, h = nb.look.h, parts = {}, from = "fond barre native" }, { w = nb.look.w, h = nb.look.h, parts = {}, from = "cadre barre native" }
    for _, part in ipairs(nb.look.parts) do
      if part.layer == "BACKGROUND" then under.parts[#under.parts + 1] = part else over.parts[#over.parts + 1] = part end
    end
    if #under.parts > 0 then NLk.ApplyClone(hold, under) hold.bg:Hide() else hold.bg:Show() end
    if #over.parts > 0 then NLk.ApplyClone(hold.nbOverlay, over) btex:Hide() end
    usedClone = true
    hold._osrsNativeBorder = "clone barre native (" .. #nb.look.parts .. " pièces)"
  else
    if hold._nlParts then for _, x in ipairs(hold._nlParts) do x:Hide() end end
    if hold.nbOverlay._nlParts then for _, x in ipairs(hold.nbOverlay._nlParts) do x:Hide() end end
    hold.bg:Show()
  end
  hold._nativeClone = usedClone
  -- v2.8.2 : barre fine des tuiles — remplissage/couleur bleus natifs (nb.tex /
  -- nb.color relevés sur SkillRankFrame), fond sombre et filet 1 px façon natif.
  if hold._thinNative then
    btex:Hide()
    local c = UI.THIN_NATIVE_EDGE
    FillTexture(hold.bg, 0, 0, 0, 0.55)
    if not hold.mEdge then
      hold.mEdge = {}
      for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = hold.nbOverlay:CreateTexture(nil, "BORDER")
        if side == "TOP" or side == "BOTTOM" then
          t:SetPoint(side .. "LEFT", hold, side .. "LEFT", -1, (side == "TOP") and 1 or -1)
          t:SetPoint(side .. "RIGHT", hold, side .. "RIGHT", 1, (side == "TOP") and 1 or -1)
          t:SetHeight(1)
        else
          t:SetPoint("TOP" .. side, hold, "TOP" .. side, (side == "LEFT") and -1 or 1, 1)
          t:SetPoint("BOTTOM" .. side, hold, "BOTTOM" .. side, (side == "LEFT") and -1 or 1, -1)
          t:SetWidth(1)
        end
        hold.mEdge[side] = t
      end
    end
    for _, t in pairs(hold.mEdge) do FillTexture(t, c[1], c[2], c[3], c[4]) t:Show() end
    hold._osrsNativeBorder = "fine native : bleu " .. tostring(nb.tex) .. " + filet 1 px"
  elseif hold._metiers then
    btex:Hide()
    FillTexture(hold.bg, 0, 0, 0, 0.9)
    if not hold.mEdge then
      hold.mEdge = {}
      for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = hold.nbOverlay:CreateTexture(nil, "BORDER")
        FillTexture(t, 99 / 255, 77 / 255, 54 / 255, 1)
        if side == "TOP" or side == "BOTTOM" then
          t:SetPoint(side .. "LEFT", hold, side .. "LEFT", -1, (side == "TOP") and 1 or -1)
          t:SetPoint(side .. "RIGHT", hold, side .. "RIGHT", 1, (side == "TOP") and 1 or -1)
          t:SetHeight(1)
        else
          t:SetPoint("TOP" .. side, hold, "TOP" .. side, (side == "LEFT") and -1 or 1, 1)
          t:SetPoint("BOTTOM" .. side, hold, "BOTTOM" .. side, (side == "LEFT") and -1 or 1, -1)
          t:SetWidth(1)
        end
        hold.mEdge[side] = t
      end
    end
    hold._osrsNativeBorder = "métiers:filet bronze 1 px"
  end
  -- Texte « rang / max » centré DANS la barre, jamais hors cadre.
  local fs = hold.nbText
  fs:ClearAllPoints()
  fs:SetPoint("LEFT", hold, "LEFT", 2, 1)
  fs:SetPoint("RIGHT", hold, "RIGHT", -2, 1)
  fs:SetJustifyH("CENTER")
  if fs.SetJustifyV then fs:SetJustifyV("MIDDLE") end
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  if fs.SetNonSpaceWrap then pcall(fs.SetNonSpaceWrap, fs, false) end
  if hold.barText and hold.barText ~= fs and hold.barText.Hide then hold.barText:Hide() end
  hold.barText = fs
  if nb.textFont and ns.NativeLook then ns.NativeLook.ApplyFont(fs, nb.textFont, true) end
  return w
end

local function FitBarText(fs, cur, cap, width, label)
  local avail = (width or 80) - 4
  -- Style Métiers : « Cuisine 78/150 » centré dans la barre quand ça tient.
  if label and label ~= "" and cap > 0 then
    fs:SetText(label .. Tr[" : "] .. tostring(cur) .. "/" .. tostring(cap))
    local okL, lw = pcall(fs.GetStringWidth, fs)
    lw = okL and ns.N(lw) or nil
    if lw and lw <= avail then return fs:GetText(), true end
  end
  local full = (cap > 0) and (tostring(cur) .. " / " .. tostring(cap)) or tostring(cur)
  fs:SetText(full)
  local okW, sw = false, nil
  if fs.GetStringWidth then okW, sw = pcall(fs.GetStringWidth, fs) end
  sw = okW and ns.N(sw) or nil
  if sw and sw > avail and cap > 0 then
    fs:SetText(tostring(cur) .. "/" .. tostring(cap))
    okW, sw = pcall(fs.GetStringWidth, fs)
    sw = okW and ns.N(sw) or nil
    if sw and sw > avail then fs:SetText(tostring(cur)) end
  end
  return fs:GetText()
end

local function SetSkillBarProgress(hold, bar, cur, cap, widthHint, heightOverride)
  if not hold then return end
  cur, cap = ns.N(cur) or 0, ns.N(cap) or 0
  local barW = widthHint
  if not barW or barW < 8 then barW = select(1, SizeOf(hold)) end
  if not barW or barW < 8 then barW = 80 end
  SkinNativeSkillBar(hold, bar, barW, heightOverride)
  hold:Show()
  if bar then
    if bar.SetMinMaxValues then pcall(bar.SetMinMaxValues, bar, 0, (cap > 0) and cap or 1) end
    if bar.SetValue then pcall(bar.SetValue, bar, math.min(cur, (cap > 0) and cap or cur)) end
    if bar.Show then bar:Show() end
    if bar._manualFill and bar.fill then
      local pct = (cap > 0) and math.max(0, math.min(1, cur / cap)) or 0
      bar.fill:SetHeight(hold:GetHeight() or NATIVE_SKILLBAR_H)
      bar.fill:SetWidth(math.max(0.01, barW * pct))
    end
  end
  local fs = hold.barText
  if hold._noText then
    fs:SetText("")
    if fs.Hide then fs:Hide() end
    hold._labelInBar = false
    return
  end
  local _, withLabel = FitBarText(fs, cur, cap, barW, hold._barLabel)
  hold._labelInBar = withLabel and true or false
  fs:SetTextColor(1, 1, 1)
  if fs.Show then fs:Show() end
end

-- v2.7.2 : bord or commun à tout l'addon (3 px biseauté, Style.PALETTE) :
-- trait sombre #433010, reflet or #A68863, bronze #685335, relevés sur le bord
-- de la fenêtre Options native de Forever. Coins « arrondis » : le filet sombre s'arrête
-- 1 px avant chaque coin. Dessiné PAR-DESSUS (OVERLAY) : il encadre l'icône.
local GOLD_EDGE = {
  -- Couleurs tirées de Style.PALETTE (source unique, voir STYLEGUIDE.md).
  dark = ns.Style.PALETTE.borderOuter,   -- #433010
  hi = ns.Style.PALETTE.borderGold,      -- #A68863
  bronze = ns.Style.PALETTE.borderInner, -- #685335
}
UI.GOLD_EDGE = GOLD_EDGE
local function DrawGoldBorder(frame, layer, sub, tint)
  if not frame or not frame.CreateTexture then return nil end
  frame._goldEdge = frame._goldEdge or {}
  local E = frame._goldEdge
  local rings = {
    { inset = 0, col = GOLD_EDGE.dark, round = 1 },
    { inset = 1, col = tint or GOLD_EDGE.hi, round = 0 },
    { inset = 2, col = tint and { tint[1] * 0.72, tint[2] * 0.72, tint[3] * 0.72, 1 } or GOLD_EDGE.bronze, round = 0 },
  }
  for ri, rg in ipairs(rings) do
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
      local k = side .. ri
      local t = E[k]
      if not t then
        t = frame:CreateTexture(nil, layer or "OVERLAY")
        E[k] = t
      end
      if t.SetDrawLayer then pcall(t.SetDrawLayer, t, layer or "OVERLAY", sub or 6) end
      FillTexture(t, rg.col[1], rg.col[2], rg.col[3], rg.col[4] or 1)
      t._goldColor = rg.col
      t:ClearAllPoints()
      local i, r = rg.inset, rg.round
      if side == "TOP" or side == "BOTTOM" then
        local y = (side == "TOP") and -i or i
        t:SetPoint(side .. "LEFT", frame, side .. "LEFT", i + r, y)
        t:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", -i - r, y)
        t:SetHeight(1)
      else
        local x = (side == "LEFT") and i or -i
        t:SetPoint("TOP" .. side, frame, "TOP" .. side, x, -i - r)
        t:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, x, i + r)
        t:SetWidth(1)
      end
      t:Show()
    end
  end
  frame._goldBorder = true
  return E
end
UI.DrawGoldBorder = DrawGoldBorder

local function ApplyCheckboxFrame(slot, size)
  if not slot then return end
  size = size or slot._slotSize or 36
  -- Plus de case à cocher grise : icône en retrait de 3 px, bord or par-dessus.
  if slot.recess then slot.recess:Hide() end
  if slot.boxTex and slot.boxTex.Hide then slot.boxTex:Hide() end
  for _, e in pairs(slot.boxEdges or {}) do e:Hide() end
  if slot._osrsPix then ShowPixelBorder(slot, false) end
  -- v2.8.0 : icône FlareUI (ronde + anneau or si le masque existe, sinon cadre
  -- biseauté IconFrame.tga), Media/Skin, par-dessus l'icône.
  slot._slotSize = size
  if slot._ringLook then
    -- Drops (aspect figé) : anneau FlareUI inchangé.
    local mode = ns.Style.IconRing(slot, slot.iconTex)
    slot._osrsNativeBorder = "FlareUI : icône " .. tostring(mode)
    return
  end
  -- v2.8.2 : tuiles = emplacement d'objet natif carré (plus d'anneau ni de masque).
  local mode = ns.Style.IconSlot(slot, slot.iconTex)
  slot._osrsNativeBorder = "emplacement natif : icône " .. tostring(mode)
end

local function CreateSlotButton(parent, size, ringLook)
  size = size or 36
  -- Pas de ItemButtonTemplate / ActionButtonTemplate : leur NormalTexture
  -- 64x64 n'était pas recentrée, d'où un cadre vide à gauche de l'icône.
  local slot = CreateFrame("Button", nil, parent)
  slot:SetSize(size, size)
  if slot.EnableMouse then slot:EnableMouse(false) end
  local icon = slot:CreateTexture(nil, "ARTWORK")
  slot.icon, slot.iconTex = icon, icon
  slot._ringLook = ringLook and true or nil
  ApplyCheckboxFrame(slot, size)
  slot.normalTex = nil

  local hi = slot:CreateTexture(nil, "OVERLAY")
  if not TrySetTex(hi, SLOT_HILITE, "ADD") then
    FillTexture(hi, 1, 1, 1, 0.18)
  end
  hi:SetAllPoints(slot)
  hi:Hide()
  slot.hoverTex = hi

  local ch = slot:CreateTexture(nil, "OVERLAY")
  if not TrySetTex(ch, SLOT_CHECKED, "ADD") then
    TrySetTex(ch, SLOT_ACTION_BORDER, "ADD")
  end
  ch:SetAllPoints(slot)
  ch:Hide()
  slot.checkedTex = ch
  slot._slotSize = size
  slot._tmpl = nil
  return slot
end

local function ResizeSlotButton(slot, size)
  if not slot then return end
  slot:SetSize(size, size)
  slot._slotSize = size
  ApplyCheckboxFrame(slot, size)
  if slot.hoverTex then
    slot.hoverTex:ClearAllPoints()
    slot.hoverTex:SetAllPoints(slot)
  end
  if slot.checkedTex then
    slot.checkedTex:ClearAllPoints()
    slot.checkedTex:SetAllPoints(slot)
  end
end

-- (3.0.0 : code de tuile déplacé dans View.lua)
function UI:PaintHover(t)
  self:PaintTileBg(t)
end

-- Détail au survol : rien n'est recalculé si la même tuile est déjà affichée
-- pour le même instantané ; sinon on remplit depuis les données en cache.
function UI:ShowDetailCached(d)
  if not d then return end
  self.perf = self.perf or {}
  local key = self:SelectionKey(d) .. "#" .. tostring(self._snapVersion or 0) .. "#" .. tostring(ns.Craft and ns.Craft._ver or 0)
  if self._detailShownKey == key and self.ownDetail and self.ownDetail:IsShown() then
    self.perf.detailSkip = (self.perf.detailSkip or 0) + 1
    return
  end
  self.perf.detailFill = (self.perf.detailFill or 0) + 1
  self._detailShownKey = key
  if not self:IsOsrsView() then return end
  self._cachedDetailFill = true
  if d.kind == "total" then self:ShowDetailBreakdown(self.snapshot)
  else self:FillOwnDetail(d, nil) end
  self._cachedDetailFill = false
end

-- Lien avec la sélection native (liste / vue classique) : différé et une
-- seule fois par tuile différente, jamais à chaque image.
function UI:ScheduleNativeSync(d)
  if not d then return end
  local key = self:SelectionKey(d)
  if key == self._nativeSyncedKey then return end
  self._nativeSyncPending = d
  local tf = self:TimerFrame("nativesync")
  if not tf then return end
  tf._acc = 0
  tf:SetScript("OnUpdate", function(f, elapsed)
    f._acc = (f._acc or 0) + (elapsed or 0.05)
    if f._acc < 0.15 then return end
    f:SetScript("OnUpdate", nil)
    local pd = UI._nativeSyncPending
    UI._nativeSyncPending = nil
    if not pd then return end
    local k = UI:SelectionKey(pd)
    if k == UI._nativeSyncedKey then return end
    UI._nativeSyncedKey = k
    UI.perf = UI.perf or {}
    UI.perf.nativeSync = (UI.perf.nativeSync or 0) + 1
    SafeStep("lien natif", UI.WriteNativeDetail, UI, pd)
  end)
end

-- (3.0.0 : code de tuile déplacé dans View.lua)
local TILE_FONT_STEPS = {
  { font = "GameFontHighlightLarge", h = 16 },
  { font = "GameFontHighlight", h = 13 },
}
local NAME_FONT_H = 10

local function SetFontSafe(fs, fontName)
  if not fs or not fontName then return end
  local obj = _G[fontName]
  if obj and fs.SetFontObject then pcall(fs.SetFontObject, fs, obj) end
  fs.font = fontName
end

local function TextFits(fs, avail)
  if not fs.GetStringWidth then return true end
  local ok, w = pcall(fs.GetStringWidth, fs)
  w = ok and ns.N(w) or nil
  return not w or w <= avail
end

-- (3.0.0 : code de tuile déplacé dans View.lua)
-- v2.5.0 : objectifs, paliers, rappel d'arme --------------------------------
local GOAL_SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local CAP_ICON = "Interface\\GossipFrame\\TrainerGossipIcon"
local WARN_ICON = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"
local WARN_ICON_FALLBACK = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertOther"

function UI:GoalKey(d)
  return d and (d.key or d.id or d.name)
end

function UI:GoalLabel(d)
  if not d then return "" end
  if d.combatTile and d.skillName then return d.skillName end
  return d.name or ""
end

-- (3.0.0 : code de tuile déplacé dans View.lua)
function UI:IsCapped(d, cur, cap)
  if not d or (d.kind ~= "profession" and d.kind ~= "secondary") or d.excludedMonte then return false end
  return cap and cap > 0 and cur and cur >= cap
end

function UI:WeaponLagInfo(d)
  if not d or d.kind ~= "melee" or not d.combatTile then return nil end
  local cur = ns.N(d.current) or 0
  local maxv = ns.N(d.apiMax) or 0
  if maxv <= 0 then maxv = (ns.GetPlayerLevel() or 1) * (ns.WEAPON_RANK_PER_LEVEL or 5) end
  if maxv <= 0 or cur >= maxv * 0.5 then return nil end
  return { name = d.skillName or d.name, cur = cur, max = maxv }
end

function UI:InDruidForm()
  local okC, _, class = pcall(UnitClass, "player")
  if not okC or class ~= "DRUID" then return false end
  local okF, form = pcall(GetShapeshiftForm)
  form = okF and ns.N(form) or 0
  return (form or 0) > 0
end

-- v2.8.1 : pastille FlareUI « N prêts » (recettes qui font progresser,
-- réalisables avec les sacs) ; cachée à 0 et pour les métiers de récolte.
function UI:UpdateCraftBadge(t, d)
  local C = ns.Craft
  local n = (C and d and d.id and C.SKILLS[d.id]) and C.Ready(d.id) or 0
  if n <= 0 then
    if t.craftBadge then t.craftBadge:Hide() end
    return 0
  end
  local b = t.craftBadge
  if not b then
    b = CreateFrame("Frame", nil, t)
    if b.EnableMouse then b:EnableMouse(false) end
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    pcall(bg.SetTexture, bg, "Interface\\Buttons\\WHITE8X8")
    local P = ns.Style and ns.Style.PALETTE or {}
    local c = P.sectionBg or { 0.15, 0.14, 0.13 }
    pcall(bg.SetVertexColor, bg, c[1], c[2], c[3], 0.92)
    b.bg = bg
    -- 3.3.9 : filet bronze de 1 px (plus de bord FlareUI de 4 px qui faisait un halo sombre)
    do
      local e = b:CreateTexture(nil, "BACKGROUND", nil, -1)   -- sous le fond : seul le liseré de 1 px dépasse
      e:SetPoint("TOPLEFT", -1, 1) e:SetPoint("BOTTOMRIGHT", 1, -1)
      pcall(e.SetTexture, e, "Interface\\Buttons\\WHITE8X8")
      local B = ns.STYLE and ns.STYLE.BORDER or { 0.65, 0.49, 0.27 }
      pcall(e.SetVertexColor, e, B[1], B[2], B[3], 1)   -- 3.3.14 : jeton de bord
      b.edge = e
    end
    b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    if ns.Icons and ns.Icons.CleanText then ns.Icons.CleanText(b.fs) end
    b.fs:SetTextColor(1.00, 0.85, 0.00)
    t.craftBadge = b
  end
  local txt = tostring(n) .. ((n > 1) and Tr[" prêts"] or Tr[" prêt"])
  b.fs:SetText(txt)
  local w = 6 * #txt
  if b.fs.GetStringWidth then local ok, v = pcall(b.fs.GetStringWidth, b.fs) if ok and ns.N(v) and v > 0 then w = v end end
  -- 3.3.10 : petite pastille AU-DESSUS du bord haut de la case (elle ne mord
  -- que sur le haut de l'icône) : les chiffres, en bas, ne sont jamais couverts.
  -- L'écart vertical de la grille (Icons.VGAP) lui laisse la place.
  local Th = ns.Theme
  local bh, over = (Th and Th.BADGE_H) or 11, (Th and Th.BADGE_OVERLAP) or 4
  b:SetSize(math.ceil(w) + 6, bh)
  b:ClearAllPoints()
  b:SetPoint("BOTTOM", t, "TOP", 0, -over)
  if b.SetFrameLevel and t.GetFrameLevel then pcall(b.SetFrameLevel, b, (t:GetFrameLevel() or 1) + 6) end
  b._text = txt
  b:Show()
  return n
end

function UI:RefreshCraftBadges()
  local embed = self.embed
  if not embed or not embed.tiles then return end
  for i = 1, #embed.tiles do
    local t = embed.tiles[i]
    if t and t.data and t:IsShown() then pcall(self.UpdateCraftBadge, self, t, t.data) end
  end
  local d = self.selected
  if d and ns.Craft and ns.Craft.SKILLS[d.id or ""] and self.ownDetail and self.ownDetail:IsShown() then
    self._detailShownKey = nil
    self._snapVersion = (self._snapVersion or 0) + 1
    pcall(self.ShowDetailCached, self, d)
  end
end

-- (3.0.0 : code de tuile déplacé dans View.lua)
function UI:DetailExtraLines(d)
  if not d then return "" end
  local lines = {}
  local cur = ns.N(d.current) or 0
  local cap = ns.N(d.apiMax) or 0
  local g = ns.GetGoal(self:GoalKey(d))
  if g then
    local left = g.rank - cur
    lines[#lines + 1] = Tr["Objectif : "] .. tostring(g.rank) .. ((left > 0) and (Tr[" (encore "] .. tostring(left) .. ")") or "")
  end
  if ns.Opt("paliers") and self:IsCapped(d, cur, cap) then
    lines[#lines + 1] = Tr["Palier atteint ("] .. tostring(cap) .. Tr[") : va voir ton maître pour le suivant."]
  end
  local lag = ns.Opt("rappel") and self:WeaponLagInfo(d) or nil
  if lag then
    lines[#lines + 1] = Tr["Compétence d'arme sous-montée : "] .. tostring(lag.name) .. " " .. tostring(lag.cur) .. "/" .. tostring(lag.max)
  end
  if ns.QoL and ns.QoL.DetailLines then
    local okQ, extra = pcall(ns.QoL.DetailLines, d)
    if okQ and type(extra) == "table" then for i = 1, #extra do lines[#lines + 1] = extra[i] end end
  end
  return table.concat(lines, "\n")
end

-- Popup natif (StaticPopup) ; repli : palier suivant.
function UI:EnsureGoalPopup()
  if type(_G.StaticPopupDialogs) ~= "table" or type(_G.StaticPopup_Show) ~= "function" then return false end
  if _G.StaticPopupDialogs.OSRS_TOTALLEVEL_GOAL then return true end
  local function editOf(p) return p and (p.editBox or p.EditBox or (p.GetName and _G[(p:GetName() or "") .. "EditBox"])) end
  local function accept(p, data)
    local eb = editOf(p)
    local v = eb and eb.GetText and ns.N(eb:GetText())
    if data and v then UI:ApplyGoal(data, v) end
  end
  _G.StaticPopupDialogs.OSRS_TOTALLEVEL_GOAL = {
    text = Tr["Objectif pour %s (actuel %s) :"],
    button1 = Tr["Valider"], button2 = Tr["Annuler"], button3 = Tr["Effacer"],
    hasEditBox = 1, maxLetters = 4, timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    OnShow = function(p, data)
      local eb = editOf(p)
      if eb and eb.SetText and data then
        local g = ns.GetGoal(UI:GoalKey(data))
        local nxt = (g and g.rank) or ns.NextGoalStep(data) or ""
        eb:SetText(tostring(nxt))
        if eb.HighlightText then pcall(eb.HighlightText, eb) end
      end
    end,
    OnAccept = accept,
    OnAlt = function(_, data) if data then ns.ClearGoal(UI:GoalKey(data)) UI:Refresh(true) end end,
    EditBoxOnEnterPressed = function(eb)
      local p = eb.GetParent and eb:GetParent()
      accept(p, p and p.data)
      if p and p.Hide then p:Hide() end
    end,
    EditBoxOnEscapePressed = function(eb) local p = eb:GetParent() if p and p.Hide then p:Hide() end end,
  }
  return true
end

function UI:PromptGoal(d)
  if self:EnsureGoalPopup() then
    local ok, popup = pcall(_G.StaticPopup_Show, "OSRS_TOTALLEVEL_GOAL", self:GoalLabel(d), tostring(ns.N(d.current) or 0), d)
    if ok and popup then
      if type(popup) == "table" then popup.data = d end
      return true
    end
  end
  self:CycleGoal(d)
  return false
end

function UI:ApplyGoal(d, rank)
  rank = ns.N(rank)
  local cur = ns.N(d and d.current) or 0
  if not d or not rank or rank <= cur then return false end
  -- 3.3.10 : l'objectif est enregistré AVANT le rafraîchissement ; une erreur
  -- de dessin ne le perd pas et ne bloque pas la fenêtre (rapportée au client).
  ns.SetGoal(self:GoalKey(d), self:GoalLabel(d), rank)
  local ok, err = pcall(self.Refresh, self, true)
  if not ok then
    UI.lastGoalError = err
    local h = type(_G.geterrorhandler) == "function" and _G.geterrorhandler()
    if h then pcall(h, err) end
  end
  return true
end

function UI:CycleGoal(d)
  if not d then return nil end
  local key = self:GoalKey(d)
  local g = ns.GetGoal(key)
  local nxt = ns.NextGoalStep(d, g and g.rank or nil)
  if nxt and nxt > (ns.N(d.current) or 0) then
    ns.SetGoal(key, self:GoalLabel(d), nxt)
  else
    ns.ClearGoal(key)
    nxt = nil
  end
  self:Refresh(true)
  return nxt
end

function UI:FindTileByName(name)
  local snap = self.snapshot or ns.Collect()
  self.snapshot = snap
  local want = ns.Fold(name or "")
  if want == "" then return nil end
  local ce = ns.LookupCatalog and ns.LookupCatalog(name)   -- 3.5.19 : nom FR ou EN
  for _, list in ipairs({ snap.tiles or {}, snap.allTiles or {} }) do
    for i = 1, #list do
      local d = list[i]
      if ns.Fold(d.name or "") == want or ns.Fold(d.skillName or "") == want then return d end
      if ce and ce.id and d.id == ce.id then return d end
      if (want == "niveau" or want == "level") and d.kind == "level" then return d end
    end
  end
  return nil
end

function UI:SlashGoal(rest)
  rest = rest or ""
  local onoff = rest:lower()
  if onoff == "on" or onoff == "off" then
    ns.SetOpt("objectifs", onoff == "on")
    ns.Print(Tr["drops d'objectif "] .. ((onoff == "on") and Tr["activés."] or Tr["désactivés."]))
    return
  end
  local low = string.lower(rest)
  if rest == "" then
    local c = ns.CharDB()
    local any = false
    for k, g in pairs(c.goals) do any = true ns.Print(Tr["objectif : "] .. tostring(g.name or k) .. " → " .. tostring(g.rank)) end
    if not any then ns.Print(Tr["aucun objectif. Usage : /drop objectif <compétence> <rang> | /drop objectif clear"]) end
    return
  end
  local clearWhat = low:match("^clear%s*(.*)$") or low:match("^effacer%s*(.*)$")
  if clearWhat then
    if clearWhat == "" then
      ns.ClearGoal(nil)
      ns.Print(Tr["objectifs effacés."])
    else
      local d = self:FindTileByName(rest:match("^%S+%s+(.+)$"))
      if d and ns.ClearGoal(self:GoalKey(d)) then ns.Print(Tr["objectif effacé : "] .. self:GoalLabel(d))
      else ns.Print(Tr["aucun objectif pour « "] .. tostring(clearWhat) .. Tr[" »."]) end
    end
    self:Refresh(true)
    return
  end
  local name, num = rest:match("^(.-)%s+(%d+)%s*$")
  local d = name and self:FindTileByName(name)
  if not d then
    ns.Print(Tr["compétence introuvable : « "] .. tostring(name or rest) .. Tr[" ». Usage : /drop objectif <compétence> <rang>"])
    return
  end
  if self:ApplyGoal(d, num) then
    ns.Print(Tr["objectif : "] .. self:GoalLabel(d) .. " → " .. tostring(num))
  else
    ns.Print(Tr["objectif refusé : il doit dépasser le rang actuel ("] .. tostring(d.current) .. ").")
  end
end

-- Objectifs atteints + paliers : drops dédiés, une seule fois.
function UI:CheckMilestones(snap)
  snap = snap or self.snapshot
  if not snap then
    local ok, s2 = pcall(ns.Collect)
    if not ok then return end
    snap = s2
  end
  local c = ns.CharDB()
  local list = {}
  for _, d0 in ipairs(snap.tiles or {}) do if not d0.placeholder then list[#list + 1] = d0 end end
  -- Premier passage pour ce personnage : on mémorise les plafonds actuels
  -- sans annoncer (pas de rafale de drops à l'installation).
  local seeding = not c.capsSeeded and (snap.liveCount or 0) > 0
  for i = 1, #list do
    local d = list[i]
    local key = self:GoalKey(d)
    local cur = ns.N(d.current) or 0
    local cap = ns.N(d.apiMax) or 0
    local g = ns.GetGoal(key)
    if g and cur >= g.rank then
      ns.ClearGoal(key)
      c.goalsDone[key] = g.rank
      if ns.Opt("objectifs") then self:SpawnDrop(d.icon, Tr["Objectif atteint : "] .. self:GoalLabel(d) .. " " .. tostring(g.rank),
        Tr["Clic droit sur la tuile pour le suivant"], cur, (cap > 0) and cap or nil, nil, { variant = "gold", skillId = d.id, kind = "goal" }) end
    end
    if self:IsCapped(d, cur, cap) and c.caps[key] ~= cap then
      c.caps[key] = cap
      if not seeding and ns.Opt("paliers") then
        self:SpawnDrop(d.icon, Tr["Palier atteint — va voir ton maître"],
          self:GoalLabel(d) .. " " .. tostring(cur) .. " / " .. tostring(cap), cur, cap, nil, { variant = "palier", skillId = d.id, kind = "palier" })
      end
    end
  end
  -- v2.8.0 : rang de métier apprenable / rang obtenu → variante légère.
  c.rankStates = c.rankStates or {}
  c.profCaps = c.profCaps or {}
  for i = 1, #list do
    local d = list[i]
    if ns.PROF_TIERS and ns.PROF_TIERS[d.id] and (d.kind == "profession" or d.kind == "secondary") then
      local key = self:GoalKey(d)
      local cur, cap = ns.N(d.current) or 0, ns.N(d.apiMax) or 0
      local st = ns.RankStatus and ns.RankStatus(d, cur, cap)
      local state = st and st.state
      local prevCap = c.profCaps[key]
      if not seeding and prevCap and cap > prevCap then
        self:PlayRankMilestone(d, Tr["Nouveau rang : "] .. tostring(d.name), Tr["maximum "] .. tostring(cap))
      elseif not seeding and state == "available" and c.rankStates[key] and c.rankStates[key] ~= "available" then
        self:PlayRankMilestone(d, tostring(d.name), st.note)
      end
      if cap > 0 then c.profCaps[key] = cap end
      if state then c.rankStates[key] = state end
    end
  end
  if (snap.liveCount or 0) > 0 then
    c.capsSeeded = true
    if ns.Opt("session") then ns.SessionGain(snap.total) ns.DailyGains(snap) end
    if ns.QoL and ns.QoL.OnSnapshot then
      local okQ, errQ = pcall(ns.QoL.OnSnapshot, snap)
      if not okQ then SafeStep("qualité de vie", error, errQ) end
    end
  end
end

function UI:DebugDropLines()
  local cc = self:LearnChatChrome()
  local lines = {}
  local pieces = {}
  for k, v in pairs(cc.pieces or {}) do pieces[#pieces + 1] = k .. "=" .. tostring(v.tex) end
  lines[#lines + 1] = "  chrome : " .. tostring(cc.source) .. " ; fond alpha " .. tostring(cc.bgColor and cc.bgColor[4])
  lines[#lines + 1] = "  pièces : " .. ((#pieces > 0) and table.concat(pieces, ", ") or "aucune (repli bord d'info-bulle doré)")
  local nb = self:LearnNativeSkillBar()
  lines[#lines + 1] = "  barre : " .. tostring(nb.source) .. " (" .. tostring(nb.tex) .. ")"
  local gl = _G.GroupLootFrame1
  lines[#lines + 1] = "  GroupLootFrame1 : " .. ((type(gl) == "table") and "présent" or "absent")
  return lines
end

-- Encadrés façon fenêtre Métiers : grille, détail, bandeau.
function UI:ApplyProfessionStyle()
  -- v2.8.2 : style NATIF. Aucun fond, dégradé, bord ou ombre à nous sur la
  -- grille, les tuiles, le bandeau du total ni le panneau de droite : seul le
  -- fond de la fenêtre native est visible. (Les drops gardent leur finition.)
  local out = {}
  for _, fr in ipairs({ self.embed, self.embed and self.embed.foot, self.ownDetail }) do
    if type(fr) == "table" then
      if fr.SetBackdrop then pcall(fr.SetBackdrop, fr, nil) end
      if fr._osrsSecBg then fr._osrsSecBg:Hide() end
      for _, list in ipairs({ fr._osrsSecOuter, fr._osrsSecEdge, fr._flare and fr._flare.border }) do
        if type(list) == "table" then
          for _, t in pairs(list) do if type(t) == "table" and t.Hide then t:Hide() end end
        end
      end
      if fr._osrsPix then ShowPixelBorder(fr, false) end
      fr._osrsSection, fr._dropFinish = nil, nil
    end
  end
  out.grid, out.foot, out.detail = "natif (aucun fond)", "natif (aucun fond)", "natif (fond du panneau natif)"
  self.styleApplied = out
  return out
end

-- Bandeau : « Niveau total : X / Y (+N aujourd'hui) », une seule ligne.
function UI:FooterText(snap)
  local total = snap.total or snap.ficTotal or 0
  local tmax = snap.totalMax or snap.ficMax or ns.TOTAL_MAX or 2460
  local base = Tr["Niveau total : "] .. tostring(total) .. " / " .. tostring(tmax)
  if not ns.Opt("session") or (snap.liveCount or 0) <= 0 then return base, base end
  local gain = ns.DailyGains(snap)
  if not gain or gain == 0 then return base, base end
  local sign = (gain >= 0) and "+" or ""
  return base .. " (" .. sign .. tostring(gain) .. Tr[" aujourd'hui)"], base .. " (" .. sign .. tostring(gain) .. ")"
end

-- Grille compacte : emplacements sur le fond du panneau, sans cadre extérieur.
function UI:BuildGrid(parent, namePrefix)
  local wrap = CreateFrame("Frame", namePrefix and (namePrefix .. "Wrap") or nil, parent)
  local child = CreateFrame("Frame", namePrefix and (namePrefix .. "Child") or nil, wrap)
  child:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, -2)
  child:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", 0, 26)
  -- Bandeau bronze sobre, façon barre d'argent des sacs (pas un rectangle jaune).
  local foot = CreateFrame("Button", namePrefix and (namePrefix .. "Banner") or nil, wrap)
  foot:SetPoint("BOTTOMLEFT", wrap, "BOTTOMLEFT", 0, 0)
  foot:SetHeight(22)
  foot:EnableMouse(true)
  -- Pas de fond séparé : on laisse transparaître le panneau natif (même texture).
  -- Un FillTexture débordait à droite sous le séparateur et ne matchait pas le bois.
  if foot.SetBackdrop then pcall(foot.SetBackdrop, foot, nil) end
  foot.bg = nil   -- v2.8.2 : pas de fond ni de filet (style natif)
  wrap.totalFS = Text(foot, "GameFontNormal", "CENTER")
  wrap.totalFS:SetPoint("LEFT", 8, 0)
  wrap.totalFS:SetPoint("RIGHT", -8, 0)
  if wrap.totalFS.SetJustifyH then wrap.totalFS:SetJustifyH("CENTER") end
  wrap.totalFS:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  wrap.realFS = Text(foot, "GameFontHighlightSmall", "RIGHT")
  wrap.realFS:SetPoint("RIGHT", -8, 0)
  wrap.realFS:Hide()
  foot:SetScript("OnEnter", function(self)
    if UI.snapshot then UI:ShowDetailBreakdown(UI.snapshot) end
    UI:ShowRulesTooltip(self)
  end)
  foot:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
    local d = UI.selected
    if d then UI:ShowDetailCached(d) end
  end)
  -- v2.7.2 : tout le bandeau est cliquable (sélectionne « Niveau total »).
  if foot.RegisterForClicks then pcall(foot.RegisterForClicks, foot, "LeftButtonUp") end
  foot:SetScript("OnClick", function() UI:SelectTile(UI.TOTAL_DATA) end)
  wrap:SetScript("OnSizeChanged", function(fr)
    if wrap._snap and UI:SizeChangedFor(fr, "grid") then UI:LayoutGrid(wrap, wrap._snap) end
  end)
  wrap.child, wrap.foot = child, foot
  wrap.tiles = {}
  return wrap
end

function UI:GetGridInnerWidth(wrap)
  -- Grille de la vue Comp. : largeur du volet gauche natif, figée.
  if wrap and wrap == self.embed then
    local w = self:GetLeftPaneSize()
    return math.max(80, w - 2 * GRID_PAD)
  end
  local function tryWidth(f)
    if not f or not f.GetWidth then return nil end
    local ok, v = pcall(f.GetWidth, f)
    if ok then
      v = ns.N(v)
      if v and v >= 80 then return v end
    end
    return nil
  end
  local w = tryWidth(wrap and wrap.child) or tryWidth(wrap) or 300
  return math.max(80, w - 12)
end

-- Taille du volet gauche natif (la liste), relevée une fois puis figée.
function UI:GetLeftPaneSize()
  if self.leftPaneW and self.leftPaneH then return self.leftPaneW, self.leftPaneH end
  local left = self.nativeLeft
  if not left and self.skillFrame then
    local okL, l = pcall(self.LocateNativePanes, self, self.skillFrame)
    if okL then left = l end
  end
  local w, h
  if left then w, h = SizeOf(left) end
  if w and h and w >= 150 and h >= 120 then
    self.leftPaneW, self.leftPaneH, self.leftPaneSource = w, h, (left.GetName and left:GetName()) or "liste native"
    return w, h
  end
  -- Repli (pas de liste mesurable) : ne pas mémoriser, on réessaiera.
  return 300, 340
end

function UI:GridAreaHeight(wrap)
  local h
  if wrap == self.embed then
    local _, ph = self:GetLeftPaneSize()
    h = ph
  elseif wrap and wrap.GetHeight then
    local ok, v = pcall(wrap.GetHeight, wrap)
    h = ok and ns.N(v) or nil
  end
  if not h or h < 120 then h = 340 end
  return h - GRID_PAD * 2 - FOOT_H - 4
end

-- v2.8.2 : groupes à en-tête natif, comme la liste classique.
UI.GROUP_TITLES = { "Combat", "Métiers", "Métiers secondaires" }
local GROUP_OF = { level = 1, stat = 1, melee = 1, ranged = 1, feral = 1, defense = 1, profession = 2, secondary = 3 }
UI.HEADER_H, UI.HEADER_GAP = 18, 2
function UI:GroupTiles(tiles)
  local groups = { {}, {}, {} }
  for i = 1, #(tiles or {}) do
    local g = GROUP_OF[tiles[i].kind] or 3
    local list = groups[g]
    list[#list + 1] = tiles[i]
  end
  local out = {}
  for g = 1, 3 do
    if #groups[g] > 0 then out[#out + 1] = { title = Tr[UI.GROUP_TITLES[g]], tiles = groups[g] } end
  end
  return out
end

-- En-tête de section : barre native relevée sur une ligne d'en-tête de la liste
-- Comp. (lecture seule : GetTexture/GetAtlas/GetTexCoord), mémorisée dans les
-- SavedVariables ; repli : bandeau or translucide dégradé.
local function ObjType(o)
  if type(o) ~= "table" or not o.GetObjectType then return nil end
  local ok, t = pcall(o.GetObjectType, o)
  return ok and t or nil
end
function UI:DiscoverNativeHeader()
  if self._hdrProbed and not self._nativeRescan then return self.nativeHeader end
  self._hdrProbed = true
  local names = {}
  for k in pairs(ns.openHeaders or {}) do names[k] = true end
  for _, k in ipairs(ns.collapsedHeaders or {}) do names[k] = true end
  local f = self.skillFrame
  local found
  local function textOf(fs)
    if not fs.GetText then return nil end
    local ok, t = pcall(fs.GetText, fs)
    if ok and type(t) == "string" and not ns.IsSecret(t) then return t end
  end
  local function widest(frame)
    local best, bw
    local regs = { pcall(frame.GetRegions, frame) }
    for i = 2, #regs do
      local r = regs[i]
      if type(r) == "table" and ObjType(r) == "Texture" then
        local w = select(1, SizeOf(r)) or 0
        if w > (bw or 0) then best, bw = r, w end
      end
    end
    return best
  end
  local function visit(o, depth)
    if found or type(o) ~= "table" or depth > 6 or IsOwnFrame(o) then return end
    if o.GetRegions then
      local regs = { pcall(o.GetRegions, o) }
      for i = 2, #regs do
        local r = regs[i]
        if type(r) == "table" and ObjType(r) == "FontString" then
          local t = textOf(r)
          if t and names[t] then
            local bar = widest(o)
            if bar then
              local d = { from = t }
              local okA, atlas = pcall(function() return bar.GetAtlas and bar:GetAtlas() end)
              if okA and type(atlas) == "string" and atlas ~= "" and not ns.IsSecret(atlas) then d.atlas = atlas end
              local path = TexOrFileID(bar)
              if path ~= nil and not ns.IsSecret(path) then d.tex = path end
              if bar.GetTexCoord then
                local tc = { pcall(bar.GetTexCoord, bar) }
                if tc[1] and #tc >= 9 then d.coords = { tc[2], tc[3], tc[4], tc[5], tc[6], tc[7], tc[8], tc[9] } end
              end
              if bar.GetVertexColor then
                local vc = { pcall(bar.GetVertexColor, bar) }
                if vc[1] then d.color = { ns.N(vc[2]) or 1, ns.N(vc[3]) or 1, ns.N(vc[4]) or 1, ns.N(vc[5]) or 1 } end
              end
              if d.atlas or d.tex then found = d return end
            end
          end
        end
      end
    end
    if o.GetChildren then
      local kids = { pcall(o.GetChildren, o) }
      if kids[1] then for i = 2, #kids do visit(kids[i], depth + 1) end end
    end
  end
  if f and not ns.InCombat() then
    visit(f.ScrollBox, 0)
    if not found then visit(self.nativeLeft, 0) end
    if not found then for _, r in ipairs(self:NativeListRows()) do visit(r, 0) if found then break end end end
  end
  local db = ns.db
  if found then
    if db then db.nativeAssets = db.nativeAssets or {} db.nativeAssets.header = found end
  elseif db and db.nativeAssets and db.nativeAssets.header then
    found = db.nativeAssets.header
    found.cached = true
  end
  self.nativeHeader = found
  return found
end

-- (3.0.0 : déplacé dans View.lua)
function UI:FitGrid(wrap, n)
  -- Toujours 2 colonnes, largeur fixe (volet gauche natif). Les rangées se
  -- répartissent sur toute la hauteur disponible : pas de vide en bas.
  local w = self:GetGridInnerWidth(wrap)
  local cols = GRID_COLS
  local tw = math.floor((w - (cols - 1) * TILE_HGAP) / cols)
  if tw < 60 then tw = 60 end
  local rows = math.max(1, math.ceil((n or 1) / cols))
  local areaH = self:GridAreaHeight(wrap)
  -- v2.8.2 : en-têtes de groupe (Combat / Métiers / Métiers secondaires).
  local groups = wrap and wrap._snap and self:GroupTiles(wrap._snap.tiles) or nil
  if groups and #groups > 0 then
    rows = 0
    for gi = 1, #groups do
      if not self:IsGroupCollapsed(groups[gi].title) then rows = rows + math.ceil(#groups[gi].tiles / cols) end
    end
    rows = math.max(1, rows)
    areaH = areaH - #groups * (UI.HEADER_H + UI.HEADER_GAP)
  end
  -- v2.8.1 : tuiles tassées en haut (jamais étirées en grands vides).
  local step = math.min(areaH / rows, 56 + TILE_VGAP)
  local th = math.floor(math.min(step - TILE_VGAP, 56))
  if th < 30 then th = 30 end
  return cols, tw, th, step, rows
end

-- v2.8.4 : origine et largeur de la liste native : les en-têtes natifs
-- commencent à L.header (gauche/haut) et s'arrêtent avant la barre de
-- défilement. Repli : marge native + place de la barre de défilement visible.
function UI:ListInsets()
  local L = ns.NativeLook and ns.NativeLook.ProbeList and ns.NativeLook.ProbeList()
  local f, embed = self.skillFrame, self.embed
  local el, er, et = UI.RectOf(embed)
  local ins = { left = GRID_PAD, right = GRID_PAD, top = GRID_PAD, source = "repli" }
  if L and L.headerInset then
    local ew = select(1, SizeOf(embed)) or 0
    ins.left, ins.top = L.headerInset.left, L.headerInset.top
    ins.right = ew - L.headerInset.left - (L.headerInset.width or 0)
    ins.source = "en-tête natif"
  elseif f and f.ScrollBar and el then
    local sl = UI.RectOf(f.ScrollBar)
    local okV, vis = pcall(function() return f.ScrollBar:IsShown() end)
    if sl and okV and vis and sl > el and sl < er then ins.right = math.max(GRID_PAD, er - sl + 2) ins.source = "barre de défilement" end
  end
  for _, k in ipairs({ "left", "right", "top" }) do
    local v = ns.N(ins[k]) or GRID_PAD
    if v < 0 or v > 60 then v = GRID_PAD end
    ins[k] = math.floor(v + 0.5)
  end
  self.listInsets = ins
  return ins
end

-- (3.0.0 : déplacé dans View.lua)
function UI:FillBreakdownTooltip(tt, snap)
  if not tt then return end
  tt:AddLine(Tr["Niveau total"], GOLD[1], GOLD[2], GOLD[3])
  if not snap then return end
  local total = snap.total or snap.ficTotal or 0
  local tmax = snap.totalMax or snap.ficMax or ns.TOTAL_MAX
  tt:AddLine(Tr["Total : "] .. tostring(total) .. " / " .. tostring(tmax), 1, 1, 1)
  if snap.breakdown then
    tt:AddLine(Tr["Détail"], GOLD[1], GOLD[2], GOLD[3])
    for i = 1, #snap.breakdown do
      local b = snap.breakdown[i]
      tt:AddLine(b.name .. Tr[" : +"] .. tostring(b.value), 0.85, 0.85, 0.85)
    end
  end
  local gain, list = ns.DailyGains(snap)
  if gain and gain > 0 then
    tt:AddLine(Tr["Aujourd'hui : +"] .. tostring(gain), GOLD[1], GOLD[2], GOLD[3])
    for _, e in ipairs(list) do tt:AddLine(e.name .. " +" .. tostring(e.gain), 0.25, 1, 0.25) end
  end
  tt:AddLine(" ", 1, 1, 1)
  if ns.TOTAL_FORMULA_FR then tt:AddLine(Tr[ns.TOTAL_FORMULA_FR], 0.7, 0.7, 0.7, true) end
  if ns.MONTE_NOTE_FR then tt:AddLine(Tr[ns.MONTE_NOTE_FR], 0.7, 0.65, 0.4, true) end
end

-- Panneau de droite : on ne pose PLUS de texte par-dessus la barre native.
-- 1) SetSelectedSkill(index résolu au clic, après ExpandSkillHeader) + fonctions d'update sondées.
-- 2) Si le panneau natif ne suit pas (titre bloqué sur « Dépeçage »), on le cache
--    et on dessine le nôtre : titre, barre, description, contribution — tout à l'intérieur.
local NATIVE_UPDATE_CANDIDATES = {
  "SkillFrame_Update", "SkillFrame_UpdateSkills", "SkillFrame_UpdateSkillLine",
  "SkillDetailFrame_Update", "SkillDetailFrame_OnShow", "SkillFrame_OnEvent",
  "SkillFrame_OnShow", "SkillFrameUpdate", "SkillFrameUpdateSkills",
  "UpdateSkillFrame", "UpdateSkillDetailFrame", "CharacterFrame_Update",
  "CharacterFrame_UpdateSkills",
}

local NATIVE_DETAIL_WIDGETS = {
  -- SkillDetailFrame volontairement absent : on ne cache jamais le conteneur.
  "SkillDetailName", "SkillDetailNameText",
  "SkillDetailStatusBar", "SkillDetailDescriptionText", "SkillDetailCost",
  "SkillDetailUnlearnButton",
}

-- Lignes de la liste native (SkillRankFrameN / SkillTypeLabelN, bouton « Tout ») :
-- ce sont des enfants directs du SkillFrame, pas du ScrollFrame. Les cacher
-- seulement avec la liste laissait la liste visible derrière la grille.
local NATIVE_ROW_PATTERNS = { "SkillRankFrame%d", "SkillTypeLabel%d" }
local NATIVE_ROW_SINGLES = { "SkillFrameExpandButtonFrame", "SkillFrameCollapseAllButton", "SkillListScrollFrameScrollBar" }
function UI:NativeListRows()
  local out, sf = {}, self.skillFrame
  for pi = 1, #NATIVE_ROW_PATTERNS do
    for i = 1, 40 do
      local r = _G[string.format(NATIVE_ROW_PATTERNS[pi], i)]
      if type(r) == "table" and r.Hide and not IsOwnFrame(r) then out[#out + 1] = r end
    end
  end
  for i = 1, #NATIVE_ROW_SINGLES do
    local r = _G[NATIVE_ROW_SINGLES[i]]
    if type(r) == "table" and r.Hide and not IsOwnFrame(r) then out[#out + 1] = r end
  end
  return out
end

-- (3.0.0 : déplacé dans View.lua)
function UI:ProbeNativeUpdateFunctions()
  if self._updateProbed then return self.nativeUpdateNames end
  self._updateProbed = true
  local found = {}
  local function add(name, fn)
    if type(fn) == "function" then
      found[#found + 1] = name
    end
  end
  for i = 1, #NATIVE_UPDATE_CANDIDATES do
    local name = NATIVE_UPDATE_CANDIDATES[i]
    add(name, _G[name])
  end
  -- Méthodes d'objets
  local frames = { _G.SkillFrame, _G.SkillDetailFrame, _G.CharacterFrame, self.skillFrame, self.nativeDetail }
  local methods = { "Update", "UpdateSkills", "UpdateSkillLine", "Refresh", "UpdateDetail" }
  for fi = 1, #frames do
    local f = frames[fi]
    if type(f) == "table" then
      local fname = (f.GetName and f:GetName()) or ("frame" .. fi)
      for mi = 1, #methods do
        local m = f[methods[mi]]
        if type(m) == "function" then
          add(fname .. ":" .. methods[mi], m)
        end
      end
    end
  end
  self.nativeUpdateNames = found
  ns.lastNativeUpdateNames = found
  return found
end

function UI:CallNativeSkillUpdates()
  -- v2.7.1 : plus JAMAIS d'appel aux fonctions natives (SkillFrame_Update…) :
  -- elles s'exécutaient souillées par l'addon et la ScrollBox échouait en combat
  -- sur les valeurs secrètes (SkillsFrame.lua:442). Conservé en no-op.
  if true then return end
  local names = self:ProbeNativeUpdateFunctions() or {}
  for i = 1, #names do
    local name = names[i]
    local fn
    local colon = string.find(name, ":", 1, true)
    if colon then
      local fname, meth = string.sub(name, 1, colon - 1), string.sub(name, colon + 1)
      local f = _G[fname]
      if type(f) == "table" then fn = f[meth] if fn then pcall(fn, f) end end
    else
      fn = _G[name]
      if type(fn) == "function" then pcall(fn) end
    end
  end
end

local function HideLegacyDetailExtras(detail)
  if not detail then return end
  for _, key in ipairs({ "osrsFic", "osrsPct", "osrsFormula" }) do
    local fs = detail[key]
    if type(fs) == "table" then
      if fs.SetText then pcall(fs.SetText, fs, "") end
      if fs.Hide then pcall(fs.Hide, fs) end
      if fs.ClearAllPoints then pcall(fs.ClearAllPoints, fs) end
      if fs.SetPoint and UIParent then pcall(fs.SetPoint, fs, "TOPLEFT", UIParent, "TOPLEFT", -8000, 0) end
    end
    detail[key] = nil
  end
  -- L'ancien bandeau bas (v2.2) débordait sur la barre native : on le cache.
  if detail._osrsBottom then
    if detail._osrsBottom.Hide then detail._osrsBottom:Hide() end
    if detail._osrsBottom.SetText then end
    if detail._osrsBottom.line1 then detail._osrsBottom.line1:SetText("") end
    if detail._osrsBottom.line2 then detail._osrsBottom.line2:SetText("") end
    if detail._osrsBottom.line3 then detail._osrsBottom.line3:SetText("") end
  end
end

local function IsDescendantOf(obj, ancestor)
  if not obj or not ancestor then return false end
  local cur, guard = obj, 0
  while cur and guard < 12 do
    guard = guard + 1
    if cur == ancestor then return true end
    if cur.GetParent then
      local ok, par = pcall(cur.GetParent, cur)
      if ok then cur = par else break end
    else
      break
    end
  end
  return false
end

function UI:HideLegacyOverlays(root)
  HideLegacyDetailExtras(root)
  HideLegacyDetailExtras(self.skillFrame)
  HideLegacyDetailExtras(self.nativeDetail)
  if self.detailBottom then
    self.detailBottom:Hide()
    if self.detailBottom.line1 then self.detailBottom.line1:SetText("") end
    if self.detailBottom.line2 then self.detailBottom.line2:SetText("") end
    if self.detailBottom.line3 then self.detailBottom.line3:SetText("") end
  end
  for _, name in ipairs({ "DropamineDetailBottom", "DropamineDetailBottom2" }) do
    local f = _G[name]
    if type(f) == "table" and f ~= self.ownDetail then
      if f.Hide then pcall(f.Hide, f) end
      if f.SetAlpha then pcall(f.SetAlpha, f, 0) end
    end
  end
end

-- Le parent du panneau de détail : UNIQUEMENT la colonne / le cadre natif de droite,
-- jamais le SkillFrame entier (sinon le détail reste dessiné une fois la colonne repliée).
function UI:GetDetailParent()
  local function usable(f)
    return type(f) == "table" and f.SetPoint and f ~= self.skillFrame and not IsOwnFrame(f)
  end
  if usable(_G.SkillDetailFrame) then return _G.SkillDetailFrame end
  if usable(self.nativeDetail) then return self.nativeDetail end
  if self.skillFrame and self.skillFrame.GetChildren then
    local kids = { pcall(self.skillFrame.GetChildren, self.skillFrame) }
    if kids[1] then
      for i = 2, #kids do
        local c = kids[i]
        local n = (c.GetName and c:GetName()) or ""
        if usable(c) and type(n) == "string" and string.find(string.lower(n), "detail", 1, true) then
          return c
        end
      end
    end
  end
  return nil
end

function UI:IsRightPaneVisible()
  local d = self:GetDetailParent()
  if not d then return false end
  if d.IsShown then
    local ok, shown = pcall(d.IsShown, d)
    if not ok or not shown then return false end
  end
  local w = 0
  if d.GetWidth then
    local ok, v = pcall(d.GetWidth, d)
    if ok then w = ns.N(v) or 0 end
  end
  return w >= 80
end

function UI:HookCollapseArrow(root)
  if not root then return end
  local function hookBtn(b)
    if type(b) ~= "table" or NF(b).ArrowHooked or b == self.viewToggle then return end
    NF(b).ArrowHooked = true
    if b.HookScript then
      pcall(b.HookScript, b, "OnClick", function()
        if UI.SyncCollapsedState then UI:SyncCollapsedState() end
      end)
    end
  end
  local names = {
    "SkillFrameCollapseButton", "SkillFrameExpandButton", "SkillDetailCollapseButton",
    "SkillDetailFrameCollapseButton", "SkillFrameToggleButton", "CharacterFrameCollapseButton",
  }
  for i = 1, #names do hookBtn(_G[names[i]]) end
  if root.GetChildren then
    local kids = { pcall(root.GetChildren, root) }
    if kids[1] then
      for i = 2, #kids do
        local c = kids[i]
        local n = (c.GetName and c:GetName()) or ""
        n = string.lower(tostring(n))
        local typ = (c.GetObjectType and c:GetObjectType()) or ""
        if typ == "Button" and (string.find(n, "collapse", 1, true) or string.find(n, "expand", 1, true)
            or string.find(n, "toggle", 1, true) or string.find(n, "arrow", 1, true)) then
          hookBtn(c)
        end
      end
    end
  end
end

-- v2.8.4 : un OnSizeChanged n'agit que si la taille a VRAIMENT changé
-- (au pixel) : une mise en page qui redéclenche l'événement ne boucle plus.
function UI:SizeChangedFor(frame, key)
  if type(frame) ~= "table" then return true end
  local w, h = SizeOf(frame)
  local sig = tostring(math.floor((w or 0) + 0.5)) .. "x" .. tostring(math.floor((h or 0) + 0.5))
  local g = NF(frame)
  if g["sz_" .. key] == sig then
    self.sizeEventsSkipped = (self.sizeEventsSkipped or 0) + 1
    return false
  end
  g["sz_" .. key] = sig
  return true
end

function UI:HookDetailVisibility(detail)
  local function sync()
    if UI.SyncCollapsedState then UI:SyncCollapsedState() end
  end
  local function syncSize(fr)
    if UI:SizeChangedFor(fr, "sync") then sync() end
  end
  if detail and not NF(detail).VisHooked then
    NF(detail).VisHooked = true
    if detail.HookScript then
      pcall(detail.HookScript, detail, "OnHide", sync)
      pcall(detail.HookScript, detail, "OnShow", sync)
    end
  end
  local sf = self.skillFrame
  if sf and not NF(sf).SizeHooked then
    NF(sf).SizeHooked = true
    if sf.HookScript then pcall(sf.HookScript, sf, "OnSizeChanged", syncSize) end
  end
  self:HookCollapseArrow(sf)
  self:HookCollapseArrow(detail)
end

-- v2.5.0 : la flèche native qui replie / déplie le panneau de droite.
local ARROW_NAMES = {
  "SkillFrameCollapseButton", "SkillFrameExpandButton", "SkillDetailCollapseButton",
  "SkillDetailFrameCollapseButton", "SkillFrameToggleButton", "SkillFrameDetailToggleButton",
  "SkillFrameDetailCollapseButton", "SkillFrameArrowButton", "CharacterFrameCollapseButton",
}
local function NameHintsArrow(n)
  n = string.lower(n or "")
  if n == "" then return false end
  if string.find(n, "collapseall", 1, true) or string.find(n, "cancel", 1, true) or string.find(n, "close", 1, true) then return false end
  return string.find(n, "collapse", 1, true) or string.find(n, "expand", 1, true)
    or string.find(n, "arrow", 1, true) or string.find(n, "toggle", 1, true)
end
local function TextureHintsArrow(b)
  local regs = {}
  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
    if b[getter] then
      local ok, t = pcall(b[getter], b)
      if ok and t then regs[#regs + 1] = t end
    end
  end
  for i = 1, #regs do
    local t = regs[i]
    for _, g in ipairs({ "GetAtlas", "GetTexture" }) do
      if t[g] then
        local ok, v = pcall(t[g], t)
        if ok and type(v) == "string" then
          local l = string.lower(v)
          if string.find(l, "arrow", 1, true) or string.find(l, "collapse", 1, true) or string.find(l, "expand", 1, true)
            or string.find(l, "minus", 1, true) or string.find(l, "plus", 1, true) then
            return true
          end
        end
      end
    end
  end
  return false
end

function UI:FindCollapseArrow()
  local function okBtn(b)
    if type(b) ~= "table" or IsOwnFrame(b) or b == self.viewToggle or not b.GetObjectType then return false end
    local okT, typ = pcall(b.GetObjectType, b)
    return okT and (typ == "Button" or typ == "CheckButton")
  end
  for i = 1, #ARROW_NAMES do
    local b = _G[ARROW_NAMES[i]]
    if okBtn(b) then return b, ARROW_NAMES[i] end
  end
  local roots = { self.skillFrame, self:GetDetailParent() }
  -- 1. nom évocateur ; 2. petit bouton avec texture de flèche.
  for pass = 1, 2 do
    for ri = 1, #roots do
      local root = roots[ri]
      if root and root.GetChildren then
        local kids = { pcall(root.GetChildren, root) }
        if kids[1] then
          for i = 2, #kids do
            local c = kids[i]
            if okBtn(c) then
              local n = (c.GetName and c:GetName()) or ""
              if pass == 1 and NameHintsArrow(n) then return c, n end
              if pass == 2 then
                local w, h = SizeOf(c)
                if w and h and w <= 40 and h <= 40 and TextureHintsArrow(c) then return c, (n ~= "" and n) or "(flèche sans nom)" end
              end
            end
          end
        end
      end
    end
  end
  return nil
end

-- Habillage du bouton : style natif à filet doré (jamais le bouton rouge).
-- 3.0.1 : bouton carré nu ; son habillage est copié de la flèche native (View.lua).
local TOGGLE_TEMPLATES = {}
function UI:SkinViewToggle(btn)
  if not btn or btn._osrsSkinned then return end
  btn._osrsSkinned = true
  -- Fond sombre + filet intérieur natif doré, texte or GameFontNormalSmall.
  if not btn._osrsTemplate then
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
      if btn[getter] then
        local ok, t = pcall(btn[getter], btn)
        if ok and t and t.SetAlpha then pcall(t.SetAlpha, t, 0) end
      end
    end
    for _, k in ipairs({ "Left", "Middle", "Right" }) do
      if type(btn[k]) == "table" and btn[k].Hide then pcall(btn[k].Hide, btn[k]) end
    end
    if not btn.osrsBg then
      btn.osrsBg = btn:CreateTexture(nil, "BACKGROUND")
      btn.osrsBg:SetPoint("TOPLEFT", 1, -1)
      btn.osrsBg:SetPoint("BOTTOMRIGHT", -1, 1)
      FillTexture(btn.osrsBg, 0.08, 0.06, 0.04, 0.92)
    end
    ThinBronzeBorder(btn)
  end
  local fs = (btn.GetFontString and btn:GetFontString()) or btn.fs
  if fs and fs.SetTextColor then fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
  if fs and btn.SetFontString == nil and fs.SetFontObject and _G.GameFontNormalSmall then pcall(fs.SetFontObject, fs, _G.GameFontNormalSmall) end
end

-- Petits boutons natifs visibles du SkillFrame (flèche, +/-, etc.).
function UI:NativeSmallButtons()
  local out, f = {}, self.skillFrame
  local function visit(o, depth)
    if type(o) ~= "table" or depth > 4 or IsOwnFrame(o) or o == self.embed or o == self.ownDetail then return end
    local kids = o.GetChildren and { pcall(o.GetChildren, o) } or {}
    for i = 2, #kids do
      local c = kids[i]
      if type(c) == "table" and c ~= self.viewToggle and not IsOwnFrame(c) then
        local okT, typ = pcall(c.GetObjectType, c)
        if okT and (typ == "Button" or typ == "CheckButton") then
          local okS, sh = pcall(c.IsVisible or c.IsShown, c)
          local w, h = SizeOf(c)
          if okS and sh and w and h and w <= 60 and h <= 40 then out[#out + 1] = c end
        end
        visit(c, depth + 1)
      end
    end
  end
  visit(f, 0)
  -- v2.8.3 : la flèche peut appartenir au cadre du personnage (pas au
  -- SkillFrame) : on parcourt aussi l'ancêtre de premier niveau.
  local top = f
  for _ = 1, 6 do
    local okP, p = pcall(function() return top and top.GetParent and top:GetParent() end)
    if not okP or not p or p == _G.UIParent then break end
    top = p
  end
  if top and top ~= f then
    local seenSet = {}
    for _, b in ipairs(out) do seenSet[b] = true end
    local before = #out
    visit(top, 0)
    local uniq = {}
    for i, b in ipairs(out) do if i <= before or not seenSet[b] then uniq[#uniq + 1] = b seenSet[b] = true end end
    out = uniq
  end
  if self.collapseArrow then
    local seen = false
    for _, b in ipairs(out) do if b == self.collapseArrow then seen = true end end
    if not seen then out[#out + 1] = self.collapseArrow end
  end
  return out
end
local function Overlap(a, b, gap)
  local al, ar, at, ab = UI.RectOf(a)
  local bl, br, bt, bb = UI.RectOf(b)
  if not (al and bl) then return false end
  gap = gap or 0
  return al < br + gap and ar + gap > bl and ab < bt and at > bb
end
UI.RectsOverlap = Overlap
function UI:ResolveToggleOverlap()
  local btn = self.viewToggle
  if not btn or not UI.RectOf then return end
  for _ = 1, 4 do
    local hit
    for _, b in ipairs(self:NativeSmallButtons()) do
      if Overlap(btn, b, 1) then hit = b break end
    end
    if not hit then return true end
    btn:ClearAllPoints()
    btn:SetPoint("RIGHT", hit, "LEFT", -UI.TOGGLE_GAP, 0)
    local n = hit.GetName and hit:GetName()
    local hw, hh = SizeOf(hit)
    self.toggleHitInfo = string.format("%s (%sx%s)", tostring(n or "sans nom"), tostring(hw), tostring(hh))
    self.toggleAnchor = "à gauche de " .. tostring(n or "bouton natif sans nom") .. " (chevauchement évité)"
    self.toggleMoved = (self.toggleMoved or 0) + 1
  end
  return false
end

function UI:PlaceViewToggle()
  local btn, embed, f = self.viewToggle, self.embed, self.skillFrame
  if not btn then return end
  -- Parenté au SkillFrame (jamais à la grille, cachée en vue classique).
  if f and btn.SetParent and not (btn.GetParent and btn:GetParent() == f) then pcall(btn.SetParent, btn, f) end
  local arrow, arrowName = self:FindCollapseArrow()
  self.collapseArrow, self.collapseArrowName = arrow, arrowName
  self:SizeViewToggle()
  local strata = (arrow and arrow.GetFrameStrata and arrow:GetFrameStrata())
    or (f and f.GetFrameStrata and f:GetFrameStrata()) or "MEDIUM"
  if btn.SetFrameStrata then pcall(btn.SetFrameStrata, btn, strata) end
  -- Au-dessus de la liste, du défilement, du détail et de la flèche.
  local lvl = (f and f.GetFrameLevel and f:GetFrameLevel()) or 1
  for _, o in ipairs({ arrow, self.nativeLeft, self.nativeDetail, self:GetDetailParent(), embed, self.ownDetail }) do
    if type(o) == "table" and o.GetFrameLevel then
      local okL, l = pcall(o.GetFrameLevel, o)
      if okL and ns.N(l) and l > lvl then lvl = l end
    end
  end
  if btn.SetFrameLevel then pcall(btn.SetFrameLevel, btn, lvl + 10) end
  if btn.SetToplevel then pcall(btn.SetToplevel, btn, true) end
  if btn.EnableMouse then btn:EnableMouse(true) end
  if btn.RegisterForClicks then pcall(btn.RegisterForClicks, btn, "LeftButtonUp") end
  btn:ClearAllPoints()
  if arrow then
    -- Bord droit du bouton = bord gauche de la flèche − 4 px, même centre vertical.
    btn:SetPoint("RIGHT", arrow, "LEFT", -UI.TOGGLE_GAP, 0)
    self.toggleAnchor = "flèche " .. tostring(arrowName)
  else
    -- Pas de flèche trouvée : à gauche du panneau droit, en haut ; sinon en haut de la colonne gauche.
    local detail = self:GetDetailParent()
    if detail and self:IsRightPaneVisible() then
      btn:SetPoint("TOPRIGHT", detail, "TOPLEFT", -4, -2)
      self.toggleAnchor = "panneau droit (pas de flèche trouvée)"
    elseif f then
      btn:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -52)
      self.toggleAnchor = "SkillFrame TOPLEFT (pas de flèche trouvée)"
    end
  end
  self:SkinViewToggle(btn)
  self:SizeViewToggle()
  -- v2.8.2 : aucun bouton natif ne doit chevaucher le nôtre (la flèche jaune
  -- trouvée n'était pas toujours celle qui est affichée) : on vérifie les
  -- rectangles réels, maintenant et une image plus tard.
  self:ResolveToggleOverlap()
  if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
    C_Timer.After(0.05, function() if UI.viewToggle then SafeStep("chevauchement du bouton", UI.ResolveToggleOverlap, UI) end end)
  end
  if f and f.HookScript and not NF(f).ToggleSizeHooked then
    NF(f).ToggleSizeHooked = true
    pcall(f.HookScript, f, "OnSizeChanged", function(fr) if not ns.InCombat() and UI:SizeChangedFor(fr, "toggle") then SafeStep("chevauchement du bouton", UI.ResolveToggleOverlap, UI) end end)
  end
  -- Panneau replié / déplié : la flèche bouge → on se recale après son clic.
  if arrow and arrow.HookScript and not self._arrowHooked then
    self._arrowHooked = arrow
    pcall(arrow.HookScript, arrow, "OnClick", function()
      if ns.InCombat and ns.InCombat() then return end
      if UI.PlaceViewToggle then pcall(UI.PlaceViewToggle, UI) end
    end)
  end
  btn:Show()
end

function UI:LayoutFooter(wrap)
  local foot = wrap and wrap.foot
  if not foot then return end
  if foot.bg and foot.bg.Hide then foot.bg:Hide() end
  -- Bandeau = petit encadré Métiers en bas du volet, texte centré.
  foot:ClearAllPoints()
  foot:SetPoint("BOTTOMLEFT", wrap, "BOTTOMLEFT", GRID_PAD, GRID_PAD)
  foot:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", -GRID_PAD, GRID_PAD)
  foot:SetHeight(FOOT_H)
  -- v2.8.2 : bandeau du total = même barre d'en-tête native que les groupes.
  if not foot.bar and foot.CreateTexture then
    foot.bar = foot:CreateTexture(nil, "BACKGROUND")
    foot.bar:SetAllPoints(foot)
  end
  if foot.bar and wrap.totalFS then
    foot.text = wrap.totalFS
    -- Bouton d'en-tête natif (« Récompenses au rang 1 » / « Adversaire de niveau
    -- égal ») relevé en lecture seule ; repli : barre de groupe native.
    local used = ns.NativeLook and ns.NativeLook.ApplyHeaderButton(foot)
    if used then foot.bar:Hide() else SafeStep("bandeau natif", self.SkinGroupHeader, self, foot) foot.bar:Show() end
    foot._nativeLook = used or self.headerAsset
    wrap.totalFS:SetTextColor(1, 1, 1)
  end
  if wrap.totalFS then
    wrap.totalFS:ClearAllPoints()
    wrap.totalFS:SetPoint("LEFT", foot, "LEFT", 6, 0)
    wrap.totalFS:SetPoint("RIGHT", foot, "RIGHT", -6, 0)
    if wrap.totalFS.SetJustifyH then wrap.totalFS:SetJustifyH("CENTER") end
  end
end

function UI:LayoutForPane()
  local f, embed = self.skillFrame, self.embed
  if not f or not embed or not self:IsOsrsView() then return end
  -- Même ancre TOPLEFT et même taille que la liste native, dans les deux états
  -- du panneau droit : déplier ne fait que révéler le détail à côté.
  local w, h = self:GetLeftPaneSize()
  local left = self.nativeLeft
  embed:ClearAllPoints()
  if left and not IsOwnFrame(left) then
    embed:SetPoint("TOPLEFT", left, "TOPLEFT", 0, 0)
  else
    embed:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -56)
  end
  embed:SetSize(w, h)
  if embed._snap then self:LayoutGrid(embed, embed._snap) end
  self:LayoutFooter(embed)
  self:PlaceViewToggle()
end

function UI:SyncCollapsedState()
  local visible = self:IsRightPaneVisible()
  if self.ownDetail then
    if visible and self:IsOsrsView() then
      -- Re-remplir si on a une sélection ; sinon rester prêt.
      if self._detailData then
        self:FillOwnDetail(self._detailData, self._detailLive)
      else
        self.ownDetail:Show()
      end
    else
      self.ownDetail:Hide()
    end
  end
  if self:IsOsrsView() then
    self:LayoutForPane()
  end
end

function UI:WalkNativeDetailRegions(root, fn, depth)
  if not root or not fn or (depth or 0) > 8 then return end
  if root == self.ownDetail or IsDescendantOf(root, self.ownDetail) then return end
  if root == self.embed or IsDescendantOf(root, self.embed) then return end
  if root == self.viewToggle then return end
  fn(root)
  if root.GetRegions then
    local regs = { pcall(root.GetRegions, root) }
    if regs[1] then
      for i = 2, #regs do
        self:WalkNativeDetailRegions(regs[i], fn, (depth or 0) + 1)
      end
    end
  end
  if root.GetChildren then
    local kids = { pcall(root.GetChildren, root) }
    if kids[1] then
      for i = 2, #kids do
        self:WalkNativeDetailRegions(kids[i], fn, (depth or 0) + 1)
      end
    end
  end
end

local function NativeWidgetType(obj)
  if not obj or not obj.GetObjectType then return "" end
  local ok, typ = pcall(obj.GetObjectType, obj)
  return (ok and typ) or ""
end

local function IsCollapseWidget(obj)
  local n = (obj.GetName and obj:GetName()) or ""
  n = string.lower(tostring(n))
  return string.find(n, "collapse", 1, true) or string.find(n, "expand", 1, true) or string.find(n, "arrow", 1, true)
end

-- v2.7.1 : le balayage complet (dont pairs(_G)) ne tourne qu'une fois, ou
-- quand la fiche se rouvre ; ensuite on ne recache que la liste mémorisée.
-- v2.8.2 : cause des « crochets » : les barres d'en-tête natives (cadres sans
-- nom contenant « Adversaire de niveau égal »…) de la compétence précédente
-- restaient visibles derrière notre panneau. On voile (opacité 0 seulement)
-- TOUT cadre natif de contenu du panneau droit — un cadre dont le sous-arbre
-- contient du texte ou une barre — et ses textes ; les cadres faits seulement
-- de textures (fond / bordure du panneau natif) restent visibles.
local function HasContent(o, depth)
  if type(o) ~= "table" or depth > 5 then return false end
  if o.GetRegions then
    local regs = { pcall(o.GetRegions, o) }
    for i = 2, #regs do
      local r = regs[i]
      if type(r) == "table" and r.GetObjectType then
        local ok, t = pcall(r.GetObjectType, r)
        if ok and t == "FontString" then return true end
      end
    end
  end
  if o.GetObjectType then
    local ok, t = pcall(o.GetObjectType, o)
    if ok and t == "StatusBar" then return true end
  end
  if o.GetChildren then
    local kids = { pcall(o.GetChildren, o) }
    for i = 2, #kids do if HasContent(kids[i], depth + 1) then return true end end
  end
  return false
end
function UI:NativeDetailContent()
  local root = self:GetDetailParent()
  local out = {}
  if not root then return out end
  local function skip(o)
    if IsOwnFrame(o) or o == self.ownDetail or o == self.embed or o == self.viewToggle then return true end
    if IsDescendantOf(o, self.ownDetail) then return true end
    if IsCollapseWidget(o) or o == self.collapseArrow then return true end
    return false
  end
  local function visit(o, depth)
    if depth > 4 or type(o) ~= "table" then return end
    local kids = o.GetChildren and { pcall(o.GetChildren, o) } or {}
    for i = 2, #kids do
      local c = kids[i]
      if type(c) == "table" and not skip(c) then
        if HasContent(c, 0) then
          -- conteneur pur (sans texte direct) : descendre pour garder ses fonds
          local direct = false
          if c.GetRegions then
            local regs = { pcall(c.GetRegions, c) }
            for k = 2, #regs do
              local r = regs[k]
              local ok, t = pcall(r.GetObjectType, r)
              if ok and t == "FontString" then direct = true break end
            end
          end
          local okT, typ = pcall(c.GetObjectType, c)
          if direct or (okT and (typ == "Button" or typ == "StatusBar")) or depth >= 3 then
            out[#out + 1] = c
          else
            visit(c, depth + 1)
          end
        end
      end
    end
    if o.GetRegions then
      local regs = { pcall(o.GetRegions, o) }
      for i = 2, #regs do
        local r = regs[i]
        local ok, t = pcall(r.GetObjectType, r)
        if ok and t == "FontString" then out[#out + 1] = r end
      end
    end
  end
  visit(root, 0)
  return out
end
function UI:VeilNativeDetailContent(hide)
  if hide then
    if ns.InCombat() then
      ns.AfterCombat("veil-detail", function() if UI:IsOsrsView() then UI:VeilNativeDetailContent(true) end end)
      return
    end
    local list = self:NativeDetailContent()
    self._veiledContent = self._veiledContent or {}
    for i = 1, #list do
      DetailVeil(list[i], true)
      self._veiledContent[list[i]] = true
    end
    self.perf = self.perf or {}
    self.perf.contentVeil = (self.perf.contentVeil or 0) + 1
  else
    for o in pairs(self._veiledContent or {}) do DetailVeil(o, false) end
    self._veiledContent = {}
  end
end

function UI:SetNativeDetailShown(show)
  -- v2.8.2 : le contenu natif suit toujours (voilé sous notre panneau, rendu
  -- tel quel pour une arme / Défense que le natif affiche déjà).
  SafeStep("contenu du détail natif", self.VeilNativeDetailContent, self, not show)
  if not show and self._nativeHideList and not self._nativeRescan then
    for i = 1, #self._nativeHideList do
      local obj = self._nativeHideList[i]
      DetailVeil(obj, true)
    end
    self.perf = self.perf or {}
    self.perf.nativeQuickHide = (self.perf.nativeQuickHide or 0) + 1
    return
  end
  self.perf = self.perf or {}
  self.perf.nativeFullScan = (self.perf.nativeFullScan or 0) + 1
  self._nativeRescan = false
  self._nativeHideList = {}
  for _, rec in pairs(self._nativeHidden or {}) do rec.listed = nil end
  self:SetNativeDetailShownFull(show)
  if show then self._nativeHideList = nil end
end

function UI:SetNativeDetailShownFull(show)
  -- Jamais cacher le cadre-conteneur SkillDetailFrame (colonne / flèche).
  -- En vue OSRS : masquer récursivement tout FontString / StatusBar natif
  -- (et les widgets SkillDetail*), puis SetAlpha(0). Restaurer en vue classique.
  self._nativeHidden = self._nativeHidden or {}
  local function consider(obj)
    if not obj or obj == self.ownDetail or IsDescendantOf(obj, self.ownDetail) then return end
    if obj == self.embed or IsDescendantOf(obj, self.embed) or obj == self.viewToggle then return end
    local typ = NativeWidgetType(obj)
    local n = (obj.GetName and obj:GetName()) or ""
    local isContainer = (n == "SkillDetailFrame") or (obj == self:GetDetailParent())
    if isContainer then return end
    if IsCollapseWidget(obj) then return end
    local hideable = (typ == "FontString" or typ == "StatusBar" or typ == "Slider")
    if typ == "Button" and string.find(n, "SkillDetail", 1, true) then hideable = true end
    -- v2.5.0 : restes natifs (cadres de barre vides, flèches de défilement).
    local ln = string.lower(n)
    if (typ == "Button" or typ == "Frame") and (string.find(ln, "scrollbar", 1, true)
        or string.find(ln, "scrollup", 1, true) or string.find(ln, "scrolldown", 1, true)) then
      hideable = true
    end
    if typ == "Texture" then
      if string.find(n, "SkillDetail", 1, true) then hideable = true end
      local path = TexOrFileID(obj)
      if type(path) == "string" then
        local lp = string.lower(path)
        if string.find(lp, "skills-bar", 1, true) or string.find(lp, "barborder", 1, true)
            or string.find(lp, "scrollbar", 1, true) then
          hideable = true
        end
      end
    end
    if typ == "Frame" and n ~= "" and string.find(n, "SkillDetail", 1, true)
        and not string.find(n, "SkillDetailFrame", 1, true) then
      hideable = true
    end
    if not hideable then return end
    local rec = self._nativeHidden[obj]
    if not rec then
      rec = { shown = true, alpha = 1 }
      if obj.IsShown then
        local ok, sh = pcall(obj.IsShown, obj)
        if ok then rec.shown = sh and true or false end
      end
      if obj.GetAlpha then
        local ok, a = pcall(obj.GetAlpha, obj)
        if ok and type(a) == "number" then rec.alpha = a end
      end
      self._nativeHidden[obj] = rec
    end
    if show then
      DetailVeil(obj, false)
    else
      DetailVeil(obj, true)
      if self._nativeHideList and not rec.listed then
        rec.listed = true
        self._nativeHideList[#self._nativeHideList + 1] = obj
      end
    end
  end

  for i = 1, #NATIVE_DETAIL_WIDGETS do
    local w = _G[NATIVE_DETAIL_WIDGETS[i]]
    if w then consider(w) end
  end
  -- Tout SkillDetail* global sauf le conteneur.
  if type(_G) == "table" then
    for k, v in pairs(_G) do
      if type(k) == "string" and string.find(k, "SkillDetail", 1, true) and k ~= "SkillDetailFrame" then
        if type(v) == "table" then consider(v) end
      end
    end
  end
  local parent = self:GetDetailParent()
  if parent then self:WalkNativeDetailRegions(parent, consider, 0) end
  self:HookNativeUpdatesForHide()
end

function UI:HookNativeUpdatesForHide()
  self._osrsHookedUpdateNames = self._osrsHookedUpdateNames or {}
  if type(hooksecurefunc) ~= "function" then return end
  local function after()
    if UI:IsOsrsView() and not UI._inRowRestore then
      if UI._nativeAsIsKey then
        -- natif tel quel : on relit seulement (le natif a pu changer de compétence)
        UI:RecheckNativeAsIs()
      else
        UI:SetNativeDetailShown(false)
      end
      UI:SetNativeListRowsShown(false)
      UI:RequestOrnamentCover("mise à jour native")
    end
  end
  local names = self:ProbeNativeUpdateFunctions() or {}
  for i = 1, #names do
    local name = names[i]
    if not self._osrsHookedUpdateNames[name] and not string.find(name, ":", 1, true) then
      if type(_G[name]) == "function" then
        if pcall(hooksecurefunc, name, after) then
          self._osrsHookedUpdateNames[name] = true
        end
      end
    end
  end
  -- Hook OnShow du détail : un refresh natif le réaffiche souvent.
  local d = self:GetDetailParent()
  if d and not NF(d).NativeHideOnShow then
    NF(d).NativeHideOnShow = true
    if d.HookScript then
      pcall(d.HookScript, d, "OnShow", function()
        if UI:IsOsrsView() then
          if UI._nativeAsIsKey then UI:RecheckNativeAsIs() else UI:SetNativeDetailShown(false) end
          UI:RequestOrnamentCover("détail affiché")
        end
      end)
    end
  end
end

function UI:EnsureOwnDetail(detail)
  self:HideLegacyOverlays(detail)
  local parent = self:GetDetailParent()
  if not parent then
    -- Pas encore de colonne droite : ne rien accrocher au SkillFrame.
    return self.ownDetail
  end
  if not self.ownDetail and type(_G.DropamineDetail) == "table" and _G.DropamineDetail.title then
    self.ownDetail = _G.DropamineDetail
  end
  if self.ownDetail then
    local cur
    if self.ownDetail.GetParent then
      local ok, p = pcall(self.ownDetail.GetParent, self.ownDetail)
      if ok then cur = p end
    end
    if cur ~= parent then
      if self.ownDetail.SetParent then pcall(self.ownDetail.SetParent, self.ownDetail, parent) end
    end
    self.ownDetail:ClearAllPoints()
    self.ownDetail:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -8)
    self.ownDetail:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 10)
    self:HookDetailVisibility(parent)
    return self.ownDetail
  end
  local f = ReuseOrCreate("Frame", "DropamineDetail", parent)
  if f.SetFrameLevel and parent.GetFrameLevel then
    pcall(f.SetFrameLevel, f, (parent:GetFrameLevel() or 1) + 6)
  end
  -- Uniquement à l'intérieur de la colonne droite, sans offset sur SkillFrame.
  f:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -8)
  f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 10)

  local title = Text(f, "GameFontNormal", "CENTER")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
  title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
  title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

  -- v2.8.4 : ligne de valeur sous le titre (« Niveau 4 »), comme le natif.
  local sub = Text(f, "GameFontHighlight", "CENTER")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  sub:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -4)
  sub:SetTextColor(1, 1, 1)
  sub:Hide()
  f.sub = sub
  -- Barre ancrée au panneau (pas à la largeur du titre, qui ne s'étirait pas).
  local barHold = CreateFrame("Frame", nil, f)
  barHold:SetPoint("TOP", title, "BOTTOM", 0, -10)
  barHold:SetPoint("LEFT", f, "LEFT", 16, 0)
  barHold:SetPoint("RIGHT", f, "RIGHT", -16, 0)
  barHold:SetHeight(BAR_H)
  barHold.bg = barHold:CreateTexture(nil, "BACKGROUND")
  barHold.bg:SetAllPoints()
  FillTexture(barHold.bg, 0.05, 0.04, 0.03, 0.95)
  ThinBronzeBorder(barHold)
  local okB, bar = pcall(CreateFrame, "StatusBar", nil, barHold)
  if not (okB and bar) then bar = CreateFrame("Frame", nil, barHold) end
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("BOTTOMRIGHT", -1, 1)
  ApplyBarFill(bar)
  if bar.SetStatusBarColor then
    local col = UI.nativeBarColor or BAR_BLUE
    pcall(bar.SetStatusBarColor, bar, col[1], col[2], col[3], col[4] or 1)
  end
  -- Remplissage manuel : sur Forever le StatusBar restait vide sans texture valide.
  barHold.fill = barHold:CreateTexture(nil, "ARTWORK")
  barHold.fill:SetPoint("TOPLEFT", 1, -1)
  barHold.fill:SetPoint("BOTTOMLEFT", 1, 1)
  do
    local col = UI.nativeBarColor or BAR_BLUE
    FillTexture(barHold.fill, col[1], col[2], col[3], col[4] or 1)
  end
  barHold.fill:Hide()
  local barText = Text(barHold, "GameFontHighlightSmall", "CENTER")
  barText:SetPoint("CENTER", 0, 0)
  barText:SetTextColor(1, 1, 1)
  if barText.SetDrawLayer then pcall(barText.SetDrawLayer, barText, "OVERLAY", 7) end

  -- Contribution : une seule ligne, centrée, jamais dans le pied.
  local contrib = Text(f, "GameFontNormal", "CENTER")
  contrib:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
  contrib:SetPoint("LEFT", f, "LEFT", 10, 0)
  contrib:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  contrib:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
  if contrib.SetJustifyH then contrib:SetJustifyH("CENTER") end
  if contrib.SetWordWrap then contrib:SetWordWrap(false) end
  if contrib.SetNonSpaceWrap then pcall(contrib.SetNonSpaceWrap, contrib, false) end

  -- Description dans un ScrollFrame (molette) pour la lire sans perdre la sélection.
  local scroll = CreateFrame("ScrollFrame", "DropamineDetailScroll", f)
  scroll:SetPoint("TOPLEFT", barHold, "BOTTOMLEFT", 0, -12)
  scroll:SetPoint("TOPRIGHT", barHold, "BOTTOMRIGHT", 0, -12)
  scroll:SetPoint("BOTTOMLEFT", contrib, "TOPLEFT", 0, 10)
  scroll:SetPoint("BOTTOMRIGHT", contrib, "TOPRIGHT", 0, 10)
  if scroll.EnableMouse then pcall(scroll.EnableMouse, scroll, true) end
  if scroll.EnableMouseWheel then pcall(scroll.EnableMouseWheel, scroll, true) end
  local scrollChild = CreateFrame("Frame", nil, scroll)
  if scroll.SetScrollChild then pcall(scroll.SetScrollChild, scroll, scrollChild) end
  scrollChild:SetPoint("TOPLEFT", 0, 0)
  scrollChild:SetWidth(200)
  scrollChild:SetHeight(80)
  local desc = Text(scrollChild, "GameFontHighlightSmall", "LEFT")
  desc:SetPoint("TOPLEFT", 0, 0)
  desc:SetPoint("TOPRIGHT", 0, 0)
  if desc.SetJustifyV then desc:SetJustifyV("TOP") end
  if desc.SetWordWrap then desc:SetWordWrap(true) end
  if desc.SetNonSpaceWrap then pcall(desc.SetNonSpaceWrap, desc, true) end
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = 0
    if self.GetVerticalScroll then
      local ok, v = pcall(self.GetVerticalScroll, self)
      if ok then cur = ns.N(v) or 0 end
    end
    local maxs = 0
    if self.GetVerticalScrollRange then
      local ok, v = pcall(self.GetVerticalScrollRange, self)
      if ok then maxs = ns.N(v) or 0 end
    end
    local nxt = cur - (ns.N(delta) or 0) * 22
    if nxt < 0 then nxt = 0 end
    if nxt > maxs then nxt = maxs end
    if self.SetVerticalScroll then pcall(self.SetVerticalScroll, self, nxt) end
  end)

  -- Liste « compétence ........ +rang » pour le Niveau total.
  f.rows = {}
  f.rowNote = Text(scrollChild, "GameFontHighlightSmall", "LEFT")
  if f.rowNote.SetWordWrap then f.rowNote:SetWordWrap(true) end
  f.rowNote:Hide()
  -- Survol du titre : règles détaillées dans l'info-bulle (pas dans le panneau).
  local titleHit = CreateFrame("Frame", nil, f)
  titleHit:SetPoint("TOPLEFT", title, "TOPLEFT", 0, 0)
  titleHit:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 0, 0)
  if titleHit.EnableMouse then titleHit:EnableMouse(true) end
  titleHit:SetScript("OnEnter", function(self) UI:ShowRulesTooltip(self) end)
  titleHit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f.titleHit = titleHit
  f.title, f.barHold, f.bar, f.barText, f.desc, f.contrib = title, barHold, bar, barText, desc, contrib
  f.scroll, f.scrollChild = scroll, scrollChild
  f:Hide()
  self.ownDetail = f
  self:HookDetailVisibility(parent)
  return f
end

function UI:DetailLabelFor(d)
  if not d then return "" end
  if d.combatTile and d.skillName then return d.skillName end
  return d.name or ""
end

function UI:DetailDescriptionFor(d, liveInfo)
  if liveInfo and type(liveInfo.description) == "string" and liveInfo.description ~= "" then
    return liveInfo.description
  end
  if d and type(d.description) == "string" and d.description ~= "" then
    return d.description
  end
  if not d then return "" end
  if d.kind == "level" then
    return Tr["Niveau du personnage, sur "] .. tostring(ns.GetLevelCap and ns.GetLevelCap() or 60)
      .. Tr[". Il compte dans le total (règles détaillées : survol du titre ou du bandeau)."]
  end
  if d.kind == "stat" then
    return Tr["Caractéristique déjà visible sur la fiche de personnage. Elle est affichée ici uniquement sur demande (/drop stats) et n'entre pas dans le total : aucun plafond n'est documenté pour Forever."]
  end
  if d.excludedMonte then
    return Tr["Compétence de Monte. Elle est affichée si elle est apprise, mais elle n'entre pas dans le total : aucun plafond n'est documenté pour Forever."]
  end
  return ""
end

function UI:WriteNativeDetail(d)
  -- Résoudre l'index AU MOMENT du clic / survol (après ExpandSkillHeader),
  -- pas seulement celui mémorisé à la collecte — d'où le titre bloqué sur Dépeçage.
  if not d then return nil end
  local lookup = d.skillName or d.name
  local index, info
  if ns.ResolveSkillIndexByName and lookup and d.kind ~= "level" and d.kind ~= "stat" then
    index, info = ns.ResolveSkillIndexByName(lookup)
  end
  if not index then index = d.skillIndex end
  -- v2.7.1 : lecture seule. Plus de C_SkillInfo.SetSelectedSkill ni de mise à
  -- jour native depuis l'addon (source de souillure de la ScrollBox).
  if index then d.skillIndex = index end
  -- La mise à jour native réaffiche ses lignes : la grille garde la place.
  if self:IsOsrsView() and self.embed and self.embed:IsShown() then
    SafeStep("lignes natives", self.SetNativeListRowsShown, self, false)
  end
  return info
end

function UI:DetailBarWidth(f)
  local w = 0
  if f and f.GetWidth then
    local ok, v = pcall(f.GetWidth, f)
    if ok then w = ns.N(v) or 0 end
  end
  if (not w or w < 40) and f and f.GetParent then
    local okp, par = pcall(f.GetParent, f)
    if okp and par and par.GetWidth then
      local ok, v = pcall(par.GetWidth, par)
      if ok then w = (ns.N(v) or 0) - 24 end
    end
  end
  if not w or w < 40 then w = 200 end
  return math.max(80, w - 32)
end

-- v2.8.0 : barre du Niveau = XP du niveau en cours (+ XP reposée), sauf au maximum.
function UI:LevelBarXP(level, cap)
  local lcap = ns.GetLevelCap and ns.GetLevelCap() or 60
  if (ns.N(level) or 0) >= lcap then return nil end
  return ns.LevelXPInfo and ns.LevelXPInfo() or nil
end

-- Calque XP reposée bleu clair, comme la barre d'XP native, borné au bout de la barre.
UI.RESTED_COLOR = { 0.45, 0.62, 1.0, 0.55 }
function UI:ApplyRestedOverlay(hold, barW, xp)
  if not hold then return end
  local ov = hold._restedTex
  if not xp or not xp.rested or xp.rested <= 0 or not xp.max or xp.max <= 0 then
    if ov then ov:Hide() end
    hold._restedW = nil
    return
  end
  if not ov and hold.CreateTexture then
    ov = hold:CreateTexture(nil, "ARTWORK")
    hold._restedTex = ov
  end
  if not ov then return end
  barW = barW or select(1, SizeOf(hold)) or 80
  local x0 = barW * math.min(1, xp.cur / xp.max)
  local x1 = barW * math.min(1, (xp.cur + xp.rested) / xp.max)
  local w = x1 - x0
  if w < 1 then ov:Hide() hold._restedW = 0 return end
  local c = UI.RESTED_COLOR
  if ov.SetColorTexture then pcall(ov.SetColorTexture, ov, c[1], c[2], c[3], c[4]) end
  pcall(ov.SetVertexColor, ov, c[1], c[2], c[3], c[4])
  ov:ClearAllPoints()
  ov:SetPoint("TOPLEFT", hold, "TOPLEFT", x0, 0)
  ov:SetPoint("BOTTOMLEFT", hold, "BOTTOMLEFT", x0, 0)
  ov:SetWidth(w)
  ov:Show()
  hold._restedW = w
end

function UI:SetDetailBar(f, cur, cap)
  if not f or not f.barHold then return end
  cur, cap = ns.N(cur) or 0, ns.N(cap) or 0
  local barW = self:DetailBarWidth(f)
  f.barHold._styleSkill = f._styleSkill
  local d = self._detailData
  local xp = d and d.kind == "level" and self:LevelBarXP(cur, cap) or nil
  if xp then SetSkillBarProgress(f.barHold, f.bar, xp.cur, xp.max, barW)
  else SetSkillBarProgress(f.barHold, f.bar, cur, cap, barW) end
  self:ApplyRestedOverlay(f.barHold, barW, xp)
  -- v2.8.4 : texte de la barre du panneau droit en BLANC, comme le natif.
  local fs = f.barHold.barText or f.barText
  if fs then fs:SetTextColor(1, 1, 1) end
end

-- v2.8.3 : mise en page du détail natif — titre centré, barre centrée,
-- description et lignes ALIGNÉES À GAUCHE sur la marge native, pleine largeur ;
-- polices = objets de police relevés sur le détail natif (titre, description,
-- en-têtes, lignes).
UI.DETAIL_TEXT_LEFT = 18   -- repli : marge gauche du texte natif dans le volet droit
UI.DETAIL_OWN_INSET = 12   -- notre cadre est posé à 12 px du bord du volet
-- v2.8.4 : titre toujours visible (police native relevée si valide, sinon
-- GameFontNormal or natif), jamais transparent.
function UI:EnsureDetailTitle(f)
  local t = f and f.title
  if not t then return end
  local NLk = ns.NativeLook
  local fonts = NLk and NLk.DetailFonts and NLk.DetailFonts() or {}
  local ok = fonts.title and NLk.ApplyFont(t, fonts.title, false)
  if not ok then SetFontSafe(t, "GameFontNormal") end
  local c = fonts.title and fonts.title.color
  if c and (c[4] or 1) >= 0.5 and (c[1] + c[2] + c[3]) > 0.6 then t:SetTextColor(c[1], c[2], c[3]) else t:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
  if t.SetAlpha then t:SetAlpha(1) end
  t:Show()
end
function UI:AnchorDetailBar(f)
  if not f or not f.barHold then return end
  local above = (f.sub and f.sub:IsShown()) and f.sub or f.title
  f.barHold:ClearAllPoints()
  f.barHold:SetPoint("TOP", above, "BOTTOM", 0, (above == f.sub) and -8 or -10)
  f.barHold:SetPoint("LEFT", f, "LEFT", 16, 0)
  f.barHold:SetPoint("RIGHT", f, "RIGHT", -16, 0)
end
-- v2.8.4 : contenu empilé depuis le haut ; le graphe puis « Compte dans le
-- total » viennent JUSTE SOUS le contenu (plus collés au bas du volet).
UI.DETAIL_TOP_AREA = 76
function UI:StackDetailFooter(f)
  if not f or not f.scroll then return end
  local contentH = select(2, SizeOf(f.scrollChild)) or 40
  local fh = select(2, SizeOf(f)) or 300
  local g = f.osrsGraph
  local gShown = g and g.IsShown and g:IsShown()
  local footH = 14 + 10 + (gShown and 40 or 0)
  local maxH = math.max(40, fh - UI.DETAIL_TOP_AREA - footH)
  local h = math.max(20, math.min(contentH, maxH))
  f.scroll:SetHeight(h)
  f._scrollH = h
  local below = f.scroll
  if gShown then
    g:ClearAllPoints()
    g:SetPoint("TOPLEFT", f.scroll, "BOTTOMLEFT", 6, -16)
    g:SetPoint("TOPRIGHT", f.scroll, "BOTTOMRIGHT", -6, -16)
    g:SetHeight(24)
    below = g
  end
  f.contrib:ClearAllPoints()
  f.contrib:SetPoint("TOP", below, "BOTTOM", 0, -8)
  f.contrib:SetPoint("LEFT", f, "LEFT", 10, 0)
  f.contrib:SetPoint("RIGHT", f, "RIGHT", -10, 0)
end

function UI:ApplyNativeDetailLayout(f)
  if not f or not f.scroll then return end
  local NLk = ns.NativeLook
  local fonts = NLk and NLk.DetailFonts and NLk.DetailFonts() or {}
  if fonts.title and f.title then
    if NLk.ApplyFont(f.title, fonts.title, true) then f._titleFont = fonts.title.obj or fonts.title.font end
  end
  if fonts.desc and f.desc then NLk.ApplyFont(f.desc, fonts.desc, true) end
  if f.desc and f.desc.SetJustifyH then f.desc:SetJustifyH("LEFT") end
  local left = ns.N(fonts.descLeft)
  if not left or left < 2 or left > 40 then left = UI.DETAIL_TEXT_LEFT end
  local x = left - UI.DETAIL_OWN_INSET
  f._textLeft = left
  f.scroll:ClearAllPoints()
  f.scroll:SetPoint("TOP", f.barHold, "BOTTOM", 0, -12)
  f.scroll:SetPoint("LEFT", f, "LEFT", x, 0)
  f.scroll:SetPoint("RIGHT", f, "RIGHT", -x, 0)
  -- v2.8.4 : plus d'ancre au bas du volet ; hauteur = contenu (StackDetailFooter)
  if f.contrib and f.contrib.SetJustifyH then f.contrib:SetJustifyH("CENTER") end
end

function UI:LayoutDetailDesc(f)
  if not f or not f.desc then return end
  SafeStep("détail (mise en page native)", self.ApplyNativeDetailLayout, self, f)
  local sw = 200
  if f.scroll and f.scroll.GetWidth then
    local ok, v = pcall(f.scroll.GetWidth, f.scroll)
    if ok and ns.N(v) and ns.N(v) > 40 then sw = ns.N(v) end
  end
  if (not sw or sw < 40) and f.GetWidth then
    local ok, v = pcall(f.GetWidth, f)
    if ok and ns.N(v) then sw = math.max(40, ns.N(v) - 8) end
  end
  if f.desc.SetWidth then f.desc:SetWidth(sw) end
  if f.scrollChild then
    f.scrollChild:SetWidth(sw)
    local dh = 40
    if f.desc.GetStringHeight then
      local ok, h = pcall(f.desc.GetStringHeight, f.desc)
      if ok and ns.N(h) then dh = ns.N(h) end
    elseif f.desc.GetHeight then
      local ok, h = pcall(f.desc.GetHeight, f.desc)
      if ok and ns.N(h) then dh = ns.N(h) end
    end
    f.scrollChild:SetHeight(math.max(dh + 4, 20))
  end
  if f.scroll and f.scroll.SetVerticalScroll then pcall(f.scroll.SetVerticalScroll, f.scroll, 0) end
end

function UI:FillOwnDetail(d, liveInfo)
  self._detailData, self._detailLive = d, liveInfo
  local f = self:EnsureOwnDetail(self.nativeDetail)
  if not f then return end
  if not d or not self:IsRightPaneVisible() or not self:IsOsrsView() then
    f:Hide()
    return
  end
  if ns.QoL and ns.QoL.UpdateGraph then SafeStep("historique", ns.QoL.UpdateGraph, f, d) end
  local title = self:DetailLabelFor(d)
  f.title:SetText(title or "")
  self:EnsureDetailTitle(f)
  if f.sub then
    if d.kind == "level" then
      f.sub:SetText(Tr["Niveau "] .. tostring(ns.N(d.current) or 0))
      f.sub:Show()
    else
      f.sub:SetText("")
      f.sub:Hide()
    end
  end
  self:AnchorDetailBar(f)
  local cap = ns.N(d.apiMax) or 0
  local cur = ns.N(d.current) or 0
  if liveInfo and ns.N(liveInfo.rank) then cur = ns.N(liveInfo.rank) or cur end
  if liveInfo and ns.N(liveInfo.max) and ns.N(liveInfo.max) > 0 then cap = ns.N(liveInfo.max) end
  if (cap and cap > 0) or d.kind == "level" then
    if d.kind == "level" and (not cap or cap <= 0) then cap = ns.GetLevelCap and ns.GetLevelCap() or 60 end
    f._styleSkill = d.id
    f.barHold._barLabel = (d.kind == "profession" or d.kind == "secondary") and (d.name) or nil
    self:SetDetailBar(f, cur, cap)
  else
    f.barHold:Hide()
    if d.kind == "stat" then
      f.title:SetText((d.name or "") .. "  " .. tostring(cur))
    end
  end
  self:HideDetailRows(f)
  -- v2.8.2 : contenu en sections de style natif (en-tête natif + lignes or/blanc).
  local NL = ns.NativeLook
  local desc = self:DetailDescriptionFor(d, liveInfo) or ""
  local sections = {}
  local function add(title, lines)
    local keep = {}
    for _, l in ipairs(lines or {}) do if l and l ~= "" then keep[#keep + 1] = l end end
    if #keep > 0 then sections[#sections + 1] = { title = title, lines = keep } end
  end
  local function split(txt)
    local out = {}
    for l in string.gmatch((txt or "") .. "\n", "(.-)\n") do if l ~= "" then out[#out + 1] = l end end
    return out
  end
  local isCombat = (d.kind == "melee" or d.kind == "ranged" or d.kind == "feral" or d.kind == "defense")
  if d.placeholder then
    desc = "|cff808080" .. tostring(d.placeholderNote or Tr["Emplacement libre."]) .. "|r"
  else
    local prog = {}
    local st = ns.RankStatus and ns.RankStatus(d, cur, cap)
    if st and st.note and d.kind == "level" then
      -- v2.8.4 : lignes du Niveau en deux tons natifs (or / blanc), pas en rouge.
      for _, l in ipairs(split(st.note)) do prog[#prog + 1] = NL and NL.TwoTone(l) or l end
    elseif st and st.note then
      local c = st.col or { 1, 1, 1 }
      prog[#prog + 1] = string.format("|cff%02x%02x%02x%s|r", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), st.note)
    end
    self._detailStatus = st
    local extra = self.DetailExtraLines and self:DetailExtraLines(d) or ""
    for _, l in ipairs(split(extra)) do prog[#prog + 1] = NL and NL.TwoTone(l) or l end
    if isCombat then
      -- Lignes du détail natif, LUES (jamais calculées) quand le natif a affiché
      -- cette compétence ; sinon masquées, avec une indication grise.
      local cached = NL and NL.Cached(d.skillName or d.name)
      if cached then
        if cached.desc and #cached.desc > 0 then desc = table.concat(cached.desc, "\n") end
        for _, sec in ipairs(cached.sections or {}) do
          local ls = {}
          for _, l in ipairs(sec.lines or {}) do ls[#ls + 1] = NL.TwoTone(l) end
          add(sec.title, ls)
        end
      end
      if ns.CombatStatsText then
        local okS, stx = pcall(ns.CombatStatsText, d.kind)
        if okS and stx and stx ~= "" then
          local ls = split(stx)
          table.remove(ls, 1)   -- l'en-tête devient une barre de section
          for i = 1, #ls do ls[i] = NL and NL.TwoTone(ls[i]) or ls[i] end
          add(Tr["Statistiques"], ls)
        end
      end
    end
    local pr = { title = Tr["Progression"], lines = prog }
    if #prog > 0 then table.insert(sections, 1, pr) end
    if ns.Craft and ns.Craft.DetailText and d.id then
      local okC, ct = pcall(ns.Craft.DetailText, d.id)
      if okC and ct and ct ~= "" then add(Tr["Recettes"], split(ct)) end
    end
  end
  f.desc:SetText(desc)
  self:LayoutDetailDesc(f)
  self:RenderDetailSections(f, sections)
  self._detailSections = sections
  local line = ContributionLine(d) or ""
  if f.contrib.SetWordWrap then f.contrib:SetWordWrap(false) end
  self:FitContribLine(f, line)
  SafeStep("pied du détail", self.StackDetailFooter, self, f)
  f:Show()
  if not self._cachedDetailFill then
    self:SetNativeDetailShown(false)
    self:RequestOrnamentCover("sélection")
  end
  -- Arme / Défense : si le panneau natif affiche DÉJÀ cette compétence, on le
  -- laisse tel quel (notre panneau se retire). Jamais de SetSelectedSkill.
  if isCombat and not d.placeholder then self:TryNativeAsIs(d, f) else self._nativeAsIsKey = nil end
end

-- Le natif a changé de compétence pendant le mode « tel quel » : notre panneau revient.
function UI:RecheckNativeAsIs()
  local d = self.selected
  if not d or ns.InCombat() then return end
  local NL = ns.NativeLook
  if NL and NL.NativeShows(d.skillName or d.name) then return end
  self._nativeAsIsKey = nil
  self._detailShownKey = nil
  self:FillOwnDetail(d, nil)
end

-- Natif tel quel pour une tuile d'arme / Défense (lecture seule ; hors combat).
function UI:TryNativeAsIs(d, f)
  local NL = ns.NativeLook
  if not NL or ns.InCombat() then return false end
  local key = self:SelectionKey(d)
  local shows
  if self._cachedDetailFill then
    shows = (self._nativeAsIsKey == key)
  else
    shows = NL.NativeShows(d.skillName or d.name)
  end
  if shows then
    self._nativeAsIsKey = key
    self:SetNativeDetailShown(true)
    if f then f:Hide() end
    self.detailMode = "natif tel quel"
    return true
  end
  self._nativeAsIsKey = nil
  self.detailMode = "notre panneau (style natif)"
  return false
end

-- Sections : barre d'en-tête native (relevée) + lignes en deux tons.
UI.SECTION_HDR_H, UI.SECTION_GAP = 20, 6
function UI:RenderDetailSections(f, sections)
  local child = f and f.scrollChild
  if not child then return end
  f.secPool = f.secPool or {}
  -- v2.8.3 : chaque élément est ANCRÉ sous le précédent (en-tête sous le texte
  -- d'au-dessus, texte sous son en-tête) : jamais de chevauchement, même si une
  -- hauteur mesurée est fausse. Les hauteurs ne servent qu'à la zone défilante.
  local w = select(1, SizeOf(child)) or 200
  if w < 80 then w = 200 end
  local fonts = ns.NativeLook and ns.NativeLook.DetailFonts and ns.NativeLook.DetailFonts() or {}
  local prev, y = nil, 0
  local hasDesc = f.desc and f.desc.GetText and (f.desc:GetText() or "") ~= "" and (not f.desc.IsShown or f.desc:IsShown())
  if hasDesc then
    prev = f.desc
    y = self:FSHeight(f.desc, 14) + UI.SECTION_GAP
  end
  for i, sec in ipairs(sections or {}) do
    local e = f.secPool[i]
    if not e then
      e = {}
      e.hdr = CreateFrame("Frame", nil, child)
      if e.hdr.EnableMouse then e.hdr:EnableMouse(false) end
      e.hdrBar = e.hdr:CreateTexture(nil, "BACKGROUND")
      e.hdrBar:SetAllPoints(e.hdr)
      e.hdrText = Text(e.hdr, "GameFontHighlight", "CENTER")
      e.hdrText:SetPoint("LEFT", e.hdr, "LEFT", 8, 0)
      e.hdrText:SetPoint("RIGHT", e.hdr, "RIGHT", -8, 0)
      e.body = Text(child, "GameFontHighlightSmall", "LEFT")
      if e.body.SetWordWrap then e.body:SetWordWrap(true) end
      if e.body.SetJustifyV then e.body:SetJustifyV("TOP") end
      f.secPool[i] = e
    end
    local hh = (fonts.headerH and fonts.headerH > 0) and fonts.headerH or UI.SECTION_HDR_H
    -- largeur du bouton d'en-tête natif (relevée), centré comme le natif
    local hw = (fonts.headerW and fonts.headerW >= 60 and fonts.headerW <= w) and fonts.headerW or w
    local hx = math.floor((w - hw) / 2)
    e.hdr:ClearAllPoints()
    if prev then
      -- 3.3.1 : sous le texte précédent, mais aligné sur la zone (le texte a
      -- sa propre marge intérieure ; le bandeau, non)
      e.hdr:SetPoint("TOP", prev, "BOTTOM", 0, -UI.SECTION_GAP)
      e.hdr:SetPoint("LEFT", child, "LEFT", hx, 0)
    else
      e.hdr:SetPoint("TOPLEFT", child, "TOPLEFT", hx, 0)
    end
    e.hdr:SetSize(hw, hh)
    e._hx = hx
    if fonts.header then ns.NativeLook.ApplyFont(e.hdrText, fonts.header) end
    e.hdrText:SetText(sec.title or "")
    local used = ns.NativeLook and ns.NativeLook.ApplyHeaderButton(e.hdr)
    if used then e.hdrBar:Hide()
    else
      e.bar, e.text = e.hdrBar, e.hdrText
      self:SkinGroupHeader(e)
      e.hdrBar:Show()
    end
    local hc = fonts.header and fonts.header.color
    if hc then e.hdrText:SetTextColor(hc[1], hc[2], hc[3]) else e.hdrText:SetTextColor(1, 1, 1) end
    e.hdr:Show()
    if fonts.line then ns.NativeLook.ApplyFont(e.body, fonts.line) end
    if e.body.SetJustifyH then e.body:SetJustifyH("LEFT") end
    e.body:ClearAllPoints()
    -- lignes : retour à la marge gauche native, pleine largeur
    local bin = UI.DETAIL_BODY_INSET or 0   -- 3.3.1 : marge intérieure du texte
    e.body:SetPoint("TOPLEFT", e.hdr, "BOTTOMLEFT", -hx + bin, -4)
    e.body:SetWidth(math.max(40, w - 2 * bin))
    e.body:SetText(table.concat(sec.lines or {}, "\n"))
    e.body:Show()
    prev = e.body
    y = y + hh + 4 + self:FSHeight(e.body, 14 * #(sec.lines or {})) + UI.SECTION_GAP
  end
  for i = #(sections or {}) + 1, #f.secPool do f.secPool[i].hdr:Hide() f.secPool[i].body:Hide() end
  child:SetHeight(math.max(y + 8, 20))
  f._sectionsHeight = y
end

function UI:FSHeight(fs, default)
  if fs and fs.GetStringHeight then
    local ok, h = pcall(fs.GetStringHeight, fs)
    if ok and ns.N(h) and ns.N(h) > 0 then return ns.N(h) end
  end
  if fs and fs.GetHeight then
    local ok, h = pcall(fs.GetHeight, fs)
    if ok and ns.N(h) and ns.N(h) > 0 then return ns.N(h) end
  end
  return default or 14
end

function UI:ShowDetail(d, reason)
  self._detailShownKey = d and (self:SelectionKey(d) .. "#" .. tostring(self._snapVersion or 0)) or nil
  if self.nativeDetail then HideLegacyDetailExtras(self.nativeDetail) end
  -- Cacher l'ancien bandeau bas s'il existe encore sur le SkillFrame.
  if self.detailBottom then
    self.detailBottom:Hide()
    if self.detailBottom.line1 then self.detailBottom.line1:SetText("") end
    if self.detailBottom.line2 then self.detailBottom.line2:SetText("") end
    if self.detailBottom.line3 then self.detailBottom.line3:SetText("") end
  end
  if not d then
    if self.ownDetail then self.ownDetail:Hide() end
    return
  end
  local liveInfo = self:WriteNativeDetail(d)
  -- On affiche toujours NOTRE panneau dans la colonne de droite (contenu ancré,
  -- rien ne déborde sur la barre native) et on cache les widgets de détail natifs
  -- qui restaient bloqués sur « Dépeçage ».
  if self:IsOsrsView() then
    self:SetNativeDetailShown(false)
    self:FillOwnDetail(d, liveInfo)
  end
end

ns.TOTAL_SHORT_FR = "Niveau + Mêlée, 2e tuile de combat (selon la classe), Défense + 2 métiers + Cuisine, Pêche, Secourisme."

function UI:ShowRulesTooltip(owner)
  if not GameTooltip or not owner then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  self:FillBreakdownTooltip(GameTooltip, self.snapshot)
  if ns.QoL and ns.QoL.AltTooltip and owner == (self.embed and self.embed.foot) then pcall(ns.QoL.AltTooltip, GameTooltip) end
  GameTooltip:Show()
end

-- « Compte dans le total : +82 » ne doit jamais être tronqué.
function UI:FitContribLine(f, line)
  local fs = f and f.contrib
  if not fs then return end
  local avail = select(1, SizeOf(f)) or 200
  avail = avail - 24
  SetFontSafe(fs, "GameFontNormal")
  fs:SetText(line or "")
  local function fits()
    if not fs.GetStringWidth then return true end
    local ok, w = pcall(fs.GetStringWidth, fs)
    w = ok and ns.N(w) or nil
    return not w or w <= avail
  end
  if fits() then return end
  local short = (line or ""):gsub("%s*%b()%s*$", "")
  fs:SetText(short)
  if fits() then return end
  SetFontSafe(fs, "GameFontNormalSmall")
  if fits() then return end
  fs:SetText((short:gsub(Tr["Compte dans le total"], Tr["Total"])))
end

function UI:HideDetailRows(f)
  if not f or not f.rows then return end
  for i = 1, #f.rows do f.rows[i].label:Hide() f.rows[i].value:Hide() end
  if f.rowNote then f.rowNote:Hide() end
  if f.desc then f.desc:Show() end
end

function UI:ShowDetailRows(f, items, note)
  local child = f.scrollChild
  if not child then return end
  local w = 200
  if f.scroll then w = select(1, SizeOf(f.scroll)) or w end
  if w < 80 then w = 200 end
  child:SetWidth(w)
  f.desc:SetText("")
  f.desc:Hide()
  local y = 0
  for i = 1, #items do
    local r = f.rows[i]
    if not r then
      r = { label = Text(child, "GameFontNormalSmall", "LEFT"), value = Text(child, "GameFontHighlightSmall", "RIGHT") }
      if r.label.SetWordWrap then r.label:SetWordWrap(false) end
      f.rows[i] = r
    end
    r.label:ClearAllPoints()
    r.label:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -y)
    r.label:SetPoint("RIGHT", child, "RIGHT", -44, 0)
    r.value:ClearAllPoints()
    r.value:SetPoint("TOPRIGHT", child, "TOPRIGHT", -2, -y)
    r.value:SetWidth(40)
    r.label:SetText(items[i].label)
    r.value:SetText(items[i].value)
    r.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    r.value:SetTextColor(1, 1, 1)
    if items[i].header then y = y + 6 r.label:ClearAllPoints() r.label:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -y)
      r.label:SetPoint("RIGHT", child, "RIGHT", -44, 0) r.value:ClearAllPoints() r.value:SetPoint("TOPRIGHT", child, "TOPRIGHT", -2, -y) end
    if items[i].today then r.label:SetTextColor(0.85, 0.85, 0.85) r.value:SetTextColor(0.25, 1, 0.25) end
    r.label:Show() r.value:Show()
    y = y + 14
  end
  for i = #items + 1, #f.rows do f.rows[i].label:Hide() f.rows[i].value:Hide() end
  local nh = 0
  if note and note ~= "" then
    f.rowNote:ClearAllPoints()
    f.rowNote:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -(y + 6))
    f.rowNote:SetPoint("RIGHT", child, "RIGHT", -2, 0)
    f.rowNote:SetText(note)
    f.rowNote:SetTextColor(0.80, 0.80, 0.80)
    f.rowNote:Show()
    nh = 30
  else
    f.rowNote:Hide()
  end
  child:SetHeight(y + 6 + nh)
  if f.scroll and f.scroll.SetVerticalScroll then pcall(f.scroll.SetVerticalScroll, f.scroll, 0) end
end

function UI:ShowDetailBreakdown(snap)
  if not snap then return end
  if not self:IsRightPaneVisible() or not self:IsOsrsView() then
    if self.ownDetail then self.ownDetail:Hide() end
    return
  end
  local f = self:EnsureOwnDetail(self.nativeDetail)
  if not f then return end
  if self.detailBottom then self.detailBottom:Hide() end
  self:SetNativeDetailShown(false)
  local total = snap.total or 0
  local tmax = snap.totalMax or ns.TOTAL_MAX
  f.title:SetText(Tr["Niveau total"])
  self:EnsureDetailTitle(f)
  if f.sub then f.sub:SetText("") f.sub:Hide() end
  self:AnchorDetailBar(f)
  f._styleSkill = nil
  if f.barHold then f.barHold._barLabel = nil end
  self:SetDetailBar(f, total, tmax or 2460)
  -- Texte de la barre du total : blanc (pas de couleur de palier).
  local bfs = f.barHold and f.barHold.barText
  if bfs then bfs:SetTextColor(1, 1, 1) end
  -- v2.8.3 : détail du total en sections natives (plus de liste posée sous les
  -- sections de la tuile précédente).
  self:HideDetailRows(f)
  local NL = ns.NativeLook
  local lines = {}
  for i = 1, #(snap.breakdown or {}) do
    local b = snap.breakdown[i]
    lines[#lines + 1] = NL and NL.TwoTone(b.name .. Tr[" : +"] .. tostring(b.value)) or (b.name .. Tr[" : +"] .. tostring(b.value))
  end
  local sections = { { title = Tr["Détail"], lines = lines } }
  local gain, glist = ns.DailyGains(snap)
  if gain and gain > 0 then
    local tl = { NL and NL.TwoTone(Tr["Total : +"] .. tostring(gain)) or (Tr["Total : +"] .. tostring(gain)) }
    for _, e in ipairs(glist) do tl[#tl + 1] = "|cff40ff40" .. e.name .. " +" .. tostring(e.gain) .. "|r" end
    sections[#sections + 1] = { title = Tr["Aujourd'hui"], lines = tl }
  end
  self._todayItems = gain and gain > 0 and #glist or 0
  f.desc:SetText(Tr[ns.TOTAL_SHORT_FR or ""])
  f.desc:Show()
  self:LayoutDetailDesc(f)
  self:RenderDetailSections(f, sections)
  self._detailSections = sections
  f.contrib:SetText("")
  if ns.QoL and ns.QoL.UpdateGraph then SafeStep("historique", ns.QoL.UpdateGraph, f, nil) end
  SafeStep("pied du détail", self.StackDetailFooter, self, f)
  f:Show()
end

function UI:SelectionKey(d)
  if not d then return nil end
  return table.concat({ tostring(d.kind or ""), tostring(d.id or ""), tostring(d.name or ""), tostring(d.skillName or "") }, "|")
end

function UI:IsSelectedData(d)
  if not d or (not self.selected and not self.selectedKey) then return false end
  if self.selected == d then return true end
  local key = self.selectedKey or self:SelectionKey(self.selected)
  return key and self:SelectionKey(d) == key
end

function UI:RememberSelection(d)
  self.selected = d
  self.selectedKey = self:SelectionKey(d)
end

function UI:ResolveSelected()
  if not self.selected and not self.selectedKey then return nil end
  local key = self.selectedKey or self:SelectionKey(self.selected)
  local tiles = self.snapshot and self.snapshot.tiles
  if key and tiles then
    for i = 1, #tiles do
      if self:SelectionKey(tiles[i]) == key then
        self.selected = tiles[i]
        self.selectedKey = key
        return self.selected
      end
    end
    local name = self.selected and (self.selected.skillName or self.selected.name)
    if name then
      for i = 1, #tiles do
        local t = tiles[i]
        if t.name == name or t.skillName == name then
          self.selected = t
          self.selectedKey = self:SelectionKey(t)
          return self.selected
        end
      end
    end
  end
  return self.selected
end

function UI:ReapplySelection()
  local d = self:ResolveSelected()
  if not d or not self:IsOsrsView() then return d end
  if d.kind == "total" then self._detailShownKey = nil self:ShowDetailCached(d) return d end
  self:ShowDetail(d, "reapply")
  if self.embed then
    for i = 1, #(self.embed.tiles or {}) do self:PaintTileBg(self.embed.tiles[i]) end
  end
  if self.soloGrid then
    for i = 1, #(self.soloGrid.tiles or {}) do self:PaintTileBg(self.soloGrid.tiles[i]) end
  end
  return d
end

-- 3.5.19 : nom lu à l'affichage (langue choisie après le chargement)
UI.TOTAL_DATA = setmetatable({ kind = "total", id = "total" }, { __index = function(_, k) if k == "name" then return Tr["Niveau total"] end end })
function UI:SelectTile(d)
  if not d then return end
  if d.kind == "total" then
    self:RememberSelection(d)
    self._nativeSyncedKey = self:SelectionKey(d)
    self._detailShownKey = nil
    self:ShowDetailCached(d)
    if self.embed then for i = 1, #(self.embed.tiles or {}) do self:PaintTileBg(self.embed.tiles[i]) end end
    return
  end
  self:RememberSelection(d)
  local key = self:SelectionKey(d)
  if self._nativeSyncedKey ~= key then
    self._nativeSyncedKey = key
    self:ShowDetail(d, "select")
  else
    self:ShowDetailCached(d)
  end
  if self.embed then
    for i = 1, #(self.embed.tiles or {}) do self:PaintTileBg(self.embed.tiles[i]) end
  end
  if self.soloGrid then
    for i = 1, #(self.soloGrid.tiles or {}) do self:PaintTileBg(self.soloGrid.tiles[i]) end
  end
end

-- Hook de l'onglet Comp. (SkillFrame) ---------------------------------------
local SKILL_FRAME_NAMES = {
  "SkillFrame", "SkillsFrame", "CharacterSkillFrame", "CharacterSkillsFrame", "SkillListFrame",
}

function UI:FindSkillFrame()
  for i = 1, #SKILL_FRAME_NAMES do
    local f = _G[SKILL_FRAME_NAMES[i]]
    if type(f) == "table" and f.SetScript then return f, SKILL_FRAME_NAMES[i] end
  end
  if type(CharacterFrame) == "table" and CharacterFrame.GetChildren then
    local kids = { pcall(CharacterFrame.GetChildren, CharacterFrame) }
    if kids[1] then
      for i = 2, #kids do
        local n = kids[i].GetName and kids[i]:GetName()
        if type(n) == "string" and string.find(string.lower(n), "skill", 1, true) then
          return kids[i], n
        end
      end
    end
  end
  return nil
end

local function LooksLikeScroll(f)
  if not f or not f.GetObjectType then return false end
  local typ = f:GetObjectType()
  local n = (f.GetName and f:GetName()) or ""
  n = string.lower(n)
  if typ == "ScrollFrame" then return true end
  if string.find(n, "scroll", 1, true) or string.find(n, "list", 1, true) then return true end
  return false
end

local function LooksLikeDetail(f)
  if not f or not f.GetName then return false end
  local n = string.lower(f:GetName() or "")
  return string.find(n, "detail", 1, true) and true or false
end

function UI:LocateNativePanes(skillFrame)
  -- Noms classiques, puis heuristique.
  local left = _G.SkillListScrollFrame
  local detail = _G.SkillDetailFrame
  if IsOwnFrame(left) then left = nil end
  if IsOwnFrame(detail) then detail = nil end
  if left and left.GetParent and left:GetParent() ~= skillFrame then left = nil end
  if detail and detail.GetParent and detail:GetParent() ~= skillFrame then detail = nil end
  if not left or not detail then
    local kids = { pcall(skillFrame.GetChildren, skillFrame) }
    if kids[1] then
      for i = 2, #kids do
        local c = kids[i]
        if IsOwnFrame(c) then
          -- ignoré
        elseif LooksLikeDetail(c) then detail = detail or c
        elseif LooksLikeScroll(c) then left = left or c end
      end
      -- Si rien n'est nommé, on prend les deux plus grands cadres enfants, gauche / droite.
      if not left or not detail then
        local frames = {}
        for i = 2, #kids do
          local c = kids[i]
          if not IsOwnFrame(c) and c.GetWidth and c:GetWidth() and c:GetWidth() > 80 then
            frames[#frames + 1] = c
          end
        end
        table.sort(frames, function(a, b)
          local ax = (a.GetLeft and a:GetLeft()) or 0
          local bx = (b.GetLeft and b:GetLeft()) or 0
          return ax < bx
        end)
        if #frames >= 2 then
          left = left or frames[1]
          detail = detail or frames[#frames]
        elseif #frames == 1 then
          left = left or frames[1]
        end
      end
    end
  end
  return left, detail
end

function UI:AnchorEmbedDefault(embed, f)
  -- Ancres par défaut dès la création : un cadre sans ancre a un rectangle
  -- invalide, et le bouton ancré dessus n'était pas dessiné (v2.4.3).
  if not embed or not f then return end
  local okN, n = pcall(embed.GetNumPoints, embed)
  if okN and (n or 0) > 0 then return end
  embed:ClearAllPoints()
  embed:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -56)
  local w, h = self:GetLeftPaneSize()
  embed:SetSize(w, h)
end

function UI:EnsureViewToggle(f)
  if self.viewToggle then return self.viewToggle end
  local btn, used
  if type(_G.DropamineViewToggle) == "table" then
    btn, used = ReuseOrCreate("Button", "DropamineViewToggle", f)
  else
    for i = 1, #TOGGLE_TEMPLATES do
      local ok, cand = pcall(CreateFrame, "Button", "DropamineViewToggle", f, TOGGLE_TEMPLATES[i])
      if ok and cand then btn, used = cand, true cand._osrsTemplate = TOGGLE_TEMPLATES[i] break end
    end
    if not btn then btn, used = CreateFrame("Button", "DropamineViewToggle", f), false end
  end
  btn:SetSize(110, 20)
  if btn.SetText then pcall(btn.SetText, btn, Tr["Vue classique"]) end
  btn:SetScript("OnClick", function() UI:ToggleView() end)
  self.viewToggle = btn
  if not (btn.GetFontString and btn:GetFontString()) and btn.CreateFontString then
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints()
    fs:SetText(Tr["Vue classique"])
    btn.fs = fs
  end
  return btn
end

function UI:EnsureEmbed(f)
  if self.embed then
    self:AnchorEmbedDefault(self.embed, f)
    return self.embed
  end
  local embed = self:BuildGrid(f, "DropamineEmbed")
  self.embed = embed
  self:AnchorEmbedDefault(embed, f)
  if not self:IsOsrsView() then embed:Hide() end
  return embed
end

function UI:HookSkillFrame()
  local f, fname = self:FindSkillFrame()
  if not f then return false end
  self.skillFrame, self.skillFrameName = f, fname or self.skillFrameName

  -- 1. Bouton et grille : indispensables, chacun isolé.
  SafeStep("bouton Vue classique", self.EnsureViewToggle, self, f)
  if not self.embed then SafeStep("grille Comp.", self.EnsureEmbed, self, f) end
  SafeStep("placement du bouton", self.PlaceViewToggle, self)

  -- 2. Hooks d'ouverture : posés une seule fois, indépendamment du reste.
  if not NF(f).ShowHooked then
    local function onShow()
      SafeStep("ouverture Comp.", function()
        UI:HookSkillFrame()
        UI:ApplyView()
      end)
    end
    local okH = f.HookScript and pcall(f.HookScript, f, "OnShow", onShow)
    if not okH then pcall(f.SetScript, f, "OnShow", onShow) end
    NF(f).ShowHooked = true
  end
  if not UI._toggleCharHooked and type(hooksecurefunc) == "function" and type(_G.ToggleCharacter) == "function" then
    local okT = pcall(hooksecurefunc, "ToggleCharacter", function(name)
      if name == "SkillFrame" then
        SafeStep("ToggleCharacter", function()
          UI:HookSkillFrame()
          if UI.skillFrame then UI:ApplyView() end
        end)
      end
    end)
    UI._toggleCharHooked = okT and true or false
  end

  -- 3. Cosmétique : jamais bloquant.
  SafeStep("hooks collapse", self.HookDetailVisibility, self, self:GetDetailParent())
  SafeStep("onglet (hook)", self.HookCharacterFrameForTab, self)
  SafeStep("chrome natif", self.LearnNativeChrome, self)
  SafeStep("icône d'onglet", self.ApplyTabIcon, self)
  if self.HookEditMode then SafeStep("mode édition", self.HookEditMode, self) end
  local firstHook = not NF(f).Hooked
  NF(f).Hooked = (self.embed ~= nil)

  -- /reload avec l'onglet déjà ouvert : appliquer tout de suite.
  if firstHook and NF(f).Hooked and not self._inApplyView and f.IsShown then
    local okS, shown = pcall(f.IsShown, f)
    if okS and shown then SafeStep("vue", self.ApplyView, self) end
  end
  return self.embed ~= nil
end

function UI:IsOsrsView()
  return not (ns.db and ns.db.ui and ns.db.ui.osrsView == false)
end

function UI:SetViewToggleText()
  local b = self.viewToggle
  if not b then return end
  local label = self:IsOsrsView() and Tr["Vue classique"] or Tr["Vue OSRS"]
  if b.SetText then pcall(b.SetText, b, label) end
  if b.fs then b.fs:SetText(label) end
  self:SizeViewToggle()
end

-- v2.7.1 : bouton à la taille de son texte (+ marge), même hauteur que la flèche.
UI.TOGGLE_PAD, UI.TOGGLE_GAP = 8, 4
function UI:SizeViewToggle()
  local b = self.viewToggle
  if not b then return end
  local fs = (b.GetFontString and b:GetFontString()) or b.fs
  -- v2.8.1 : police posée AVANT la mesure, largeur libérée (pas de troncature
  -- « Vue classiqu »), mesure non bornée si l'API existe.
  if fs and fs.SetFontObject and _G.GameFontNormalSmall then pcall(fs.SetFontObject, fs, _G.GameFontNormalSmall) end
  if fs and fs.SetWidth then pcall(fs.SetWidth, fs, 0) end
  if fs and fs.SetWordWrap then pcall(fs.SetWordWrap, fs, false) end
  local tw
  if fs and fs.GetUnboundedStringWidth then local okU, v = pcall(fs.GetUnboundedStringWidth, fs) tw = okU and ns.N(v) or nil end
  if (not tw or tw <= 0) and fs and fs.GetStringWidth then local okW, v = pcall(fs.GetStringWidth, fs) tw = okW and ns.N(v) or nil end
  local txt = fs and fs.GetText and fs:GetText() or ""
  local est = #(tostring(txt or "")) * 6
  if not tw or tw < est * 0.75 then tw = math.max(tw or 0, est, 78) end
  tw = tw + 4
  local h = 20
  local arrow = self.collapseArrow
  if arrow and arrow.GetHeight then
    local okH, ah = pcall(arrow.GetHeight, arrow)
    ah = okH and ns.N(ah) or nil
    if ah and ah >= 12 and ah <= 40 then h = ah end
  end
  local w = math.ceil(tw + 2 * UI.TOGGLE_PAD)
  b:SetSize(w, h)
  if fs and fs.ClearAllPoints and b.fs == fs then
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  end
  self.toggleSize = { w = w, h = h, text = tw }
end

function UI:ApplyView()
  if self._inApplyView then return end
  self._inApplyView = true
  local ok, err = pcall(self.ApplyViewInner, self)
  self._inApplyView = false
  if not ok then SafeStep("vue", error, err) end
end

-- (3.0.0 : supprimé — vue réécrite dans View.lua)
local RAISE_DEPTH = 6   -- v2.8.1 : lignes de ScrollBox (ScrollBox > cible > ligne > enfants)
local function MaxLevel(root, depth, best)
  if type(root) ~= "table" or not root.GetFrameLevel or depth > RAISE_DEPTH then return best end
  local ok, l = pcall(root.GetFrameLevel, root)
  l = ok and ns.N(l) or nil
  if l and l > best then best = l end
  if root.GetChildren and depth < RAISE_DEPTH then
    local kids = { pcall(root.GetChildren, root) }
    if kids[1] then
      for i = 2, #kids do
        if not IsOwnFrame(kids[i]) then best = MaxLevel(kids[i], depth + 1, best) end
      end
    end
  end
  return best
end

-- (3.0.0 : supprimé — vue réécrite dans View.lua)
UI.ORNAMENT_BAND = 24   -- distance max (px) entre le centre de l'ornement et notre bord gauche
UI.ORNAMENT_MAXW = 40   -- un ornement est étroit (pas un panneau)
UI.ORNAMENT_MAXH = 60   -- et court (les bords du cadre natif sont longs)
local function RectOf(o)
  if not o or not o.GetLeft then return nil end
  local ok1, l = pcall(o.GetLeft, o)
  local ok2, r = pcall(o.GetRight, o)
  local ok3, t = pcall(o.GetTop, o)
  local ok4, b = pcall(o.GetBottom, o)
  l, r, t, b = ok1 and ns.N(l), ok2 and ns.N(r), ok3 and ns.N(t), ok4 and ns.N(b)
  if not (l and r and t and b) then return nil end
  return l, r, t, b
end
UI.RectOf = RectOf
local function OrnamentLabel(o)
  local n = o.GetName and o:GetName()
  if type(n) == "string" and n ~= "" then return n end
  local p = TexOrFileID(o)
  if p ~= nil then return "texture " .. tostring(p) end
  return tostring(o.GetObjectType and o:GetObjectType() or "région")
end
function UI:IsDetailOrnament(o, edge, top, bottom)
  if not o or IsOwnFrame(o) then return false end
  if o == self.viewToggle then return false end
  if self.embed and (o == self.embed or IsDescendantOf(o, self.embed)) then return false end
  if self.ownDetail and (o == self.ownDetail or IsDescendantOf(o, self.ownDetail)) then return false end
  local n = (o.GetName and o:GetName()) or ""
  if n == "SkillDetailFrame" or o == self:GetDetailParent() or o == self.skillFrame then return false end
  if IsCollapseWidget(o) or NameHintsArrow(n) then return false end
  local l, r, t, b = RectOf(o)
  if not l then return false end
  local w = r - l
  if w <= 0 or w > UI.ORNAMENT_MAXW then return false end
  -- jamais les longs bords du cadre natif (fond / bordure du panneau restent visibles)
  if (t - b) > UI.ORNAMENT_MAXH then return false end
  local cx = (l + r) / 2
  if math.abs(cx - edge) > UI.ORNAMENT_BAND then return false end
  if b >= top or t <= bottom then return false end   -- hors de la hauteur du panneau
  return true
end
function UI:CoverDetailEdge(reason)
  if not self:IsOsrsView() then return end
  local od = self.ownDetail
  if not od or not od.IsShown or not od:IsShown() then return end
  -- Notre détail au-dessus de tout le sous-arbre natif du panneau (écriture sur NOTRE cadre).
  local parent = self:GetDetailParent()
  if parent and od.SetFrameLevel then
    local okP, pl = pcall(parent.GetFrameLevel, parent)
    local lvl = math.max((okP and ns.N(pl) or 1) + 6, MaxLevel(parent, 0, 0) + 2)
    pcall(od.SetFrameLevel, od, lvl)
  end
  if ns.InCombat() then
    ns.AfterCombat("ornements", function() if UI:IsOsrsView() then UI:CoverDetailEdge("après combat") end end)
    return
  end
  local l, _, t, b = RectOf(od)
  if not l then return end
  self._ornaments = self._ornaments or {}
  local seen = {}
  local found = 0
  local function visit(o, depth)
    if type(o) ~= "table" or depth > 6 or seen[o] then return end
    seen[o] = true
    if IsOwnFrame(o) or o == self.embed or o == self.ownDetail then return end
    if self:IsDetailOrnament(o, l, t, b) then
      DetailVeil(o, true)
      if not self._ornaments[o] then self._ornaments[o] = OrnamentLabel(o) end
      found = found + 1
    end
    if o.GetRegions then
      local regs = { pcall(o.GetRegions, o) }
      if regs[1] then
        for i = 2, #regs do
          local rg = regs[i]
          if type(rg) == "table" and not seen[rg] then
            seen[rg] = true
            if self:IsDetailOrnament(rg, l, t, b) then
              DetailVeil(rg, true)
              if not self._ornaments[rg] then self._ornaments[rg] = OrnamentLabel(rg) end
              found = found + 1
            end
          end
        end
      end
    end
    if o.GetChildren then
      local kids = { pcall(o.GetChildren, o) }
      if kids[1] then for i = 2, #kids do visit(kids[i], depth + 1) end end
    end
  end
  visit(self.skillFrame, 0)
  if parent and parent ~= self.skillFrame then visit(parent, 0) end
  self.perf = self.perf or {}
  self.perf.ornamentPass = (self.perf.ornamentPass or 0) + 1
  -- Lecture des lignes du détail natif (pour les tuiles d'arme / Défense).
  if ns.NativeLook then pcall(ns.NativeLook.CaptureNativeDetail) end
  self._ornamentReason = reason
  self:HookOrnamentSources()
  return found
end
function UI:RestoreDetailEdge()
  for o in pairs(self._ornaments or {}) do DetailVeil(o, false) end
  self._ornaments = {}
end
function UI:OrnamentNames()
  local out = {}
  for _, lbl in pairs(self._ornaments or {}) do out[#out + 1] = lbl end
  table.sort(out)
  return out
end
-- Re-voile à chaque réaffichage natif : HookScript seulement (jamais de script remplacé).
function UI:HookOrnamentSources()
  local f = self.skillFrame
  local list = { f, self:GetDetailParent(), f and f.ScrollBar, f and f.ScrollBox, self.nativeDetail }
  for i = 1, #list do
    local o = list[i]
    if type(o) == "table" and o.HookScript and not NF(o).OrnHooked then
      NF(o).OrnHooked = true
      pcall(o.HookScript, o, "OnShow", function() UI:RequestOrnamentCover("OnShow") end)
      pcall(o.HookScript, o, "OnSizeChanged", function(fr) if UI:SizeChangedFor(fr, "orn") then UI:RequestOrnamentCover("taille") end end)
    end
  end
end
-- Regroupé (0,05 s) : une rafale de mises à jour natives = un seul passage.
function UI:RequestOrnamentCover(reason)
  if not self:IsOsrsView() then return end
  local tf = self:TimerFrame("ornaments")
  if not tf then return self:CoverDetailEdge(reason) end
  tf._acc, tf._why = 0, reason
  tf:SetScript("OnUpdate", function(fr, el)
    fr._acc = (fr._acc or 0) + (el or 0.05)
    if fr._acc < 0.05 then return end
    fr:SetScript("OnUpdate", nil)
    SafeStep("ornements du détail", UI.CoverDetailEdge, UI, fr._why)
  end)
end

-- (3.0.0 : supprimé — vue réécrite dans View.lua)
function UI:RefreshNativeProbe()
  if ns.InCombat and ns.InCombat() then return end
  local NLk = ns.NativeLook
  if not (NLk and NLk.ProbeList) then return end
  local L = NLk.ProbeList(true)
  if not L or L.cached then return end
  if not (self.nativeSkillBar and self.nativeSkillBar.fromList) then self.nativeSkillBar = nil end
  -- surbrillances déjà créées sans la texture native : reconstruites
  for _, t in ipairs(self.embed and self.embed.tiles or {}) do
    if not t._hlNative and L.highlight and ns.View then ns.View.PaintTile(t) end
  end
  if L.pad and self.SetGridPad then self:SetGridPad(L.pad) end
  -- hauteur d'en-tête et écart en-tête → première ligne = natifs
  if L.header and L.header.h and L.header.h >= 12 and L.header.h <= 40 then UI.HEADER_H = math.floor(L.header.h + 0.5) end
  if L.headerGap and L.headerGap >= 0 and L.headerGap <= 12 then UI.HEADER_GAP = math.floor(L.headerGap + 0.5) end
end

-- (3.0.0 : supprimé — vue réécrite dans View.lua)

function UI:ToggleView()
  if not ns.db then initDBSafe() end
  if not ns.db.ui then ns.db.ui = {} end
  ns.db.ui.osrsView = not self:IsOsrsView()
  self:ApplyView()
  -- Pas de Print ici : le bouton de l'onglet spamait le chat à chaque clic.
  -- Seule la commande /drop vue affiche un message (voir le slash handler).
end

initDBSafe = function()
  DropamineDB = DropamineDB or {}
  DropamineDB.ui = DropamineDB.ui or {}
  if DropamineDB.ui.osrsView == nil then DropamineDB.ui.osrsView = true end
  if DropamineDB.ui.customTabIcon == nil then DropamineDB.ui.customTabIcon = true end
  if DropamineDB.ui.dropsEnabled == nil then DropamineDB.ui.dropsEnabled = true end
  if DropamineDB.ui.showStats == nil then DropamineDB.ui.showStats = false end
  if DropamineDB.ui.paliers == nil then DropamineDB.ui.paliers = true end
  if DropamineDB.ui.session == nil then DropamineDB.ui.session = true end
  if DropamineDB.ui.rappel == nil then DropamineDB.ui.rappel = true end
  DropamineDB.chars = DropamineDB.chars or {}
  if DropamineDB.ui.colorMode ~= "vert" and DropamineDB.ui.colorMode ~= "jaune" and DropamineDB.ui.colorMode ~= "palier" then
    DropamineDB.ui.colorMode = "palier"
  end
  ns.db = DropamineDB
end

-- Fenêtre de secours /drop ----------------------------------------------------
local function SaveFramePos(frame, key)
  if not (ns.db and ns.db.ui and frame and frame.GetLeft) then return end
  local l, b = frame:GetLeft(), frame:GetBottom()
  if l and b then
    ns.db.ui[key] = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = l, y = b }
    return
  end
  local ok, point, _, rel, x, y = pcall(frame.GetPoint, frame, 1)
  if ok and point then
    ns.db.ui[key] = { point = point, relativePoint = rel or "CENTER", x = x or 0, y = y or 0 }
  end
end

local function RestoreFramePos(frame, key, defaultPoint)
  frame:ClearAllPoints()
  local p = ns.db and ns.db.ui and ns.db.ui[key]
  if p and p.x and p.y then
    local ok = pcall(frame.SetPoint, frame, p.point or "BOTTOMLEFT", UIParent, p.relativePoint or "BOTTOMLEFT", p.x, p.y)
    if ok then return end
    frame:ClearAllPoints()
  end
  local dp = defaultPoint or { "CENTER", 0, 0 }
  frame:SetPoint(dp[1], UIParent, dp[1], dp[2] or 0, dp[3] or 0)
end

function UI:BuildStandalone()
  if self.frame then return end
  local f, used
  for _, tmpl in ipairs({ "PortraitFrameTemplate", "ButtonFrameTemplate", "BasicFrameTemplateWithInset", "BackdropTemplate" }) do
    local ok, cand = pcall(CreateFrame, "Frame", "DropamineFrame", UIParent, tmpl)
    if ok and cand then f, used = cand, tmpl break end
  end
  if not f then
    f = TryCreate("Frame", "DropamineFrame", UIParent, "BackdropTemplate")
    used = "custom"
  end
  f:SetSize(420, 560)
  f:SetFrameStrata("HIGH")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(frame)
    frame:StopMovingOrSizing()
    SaveFramePos(frame, "pos")
  end)
  if f.SetClampedToScreen then f:SetClampedToScreen(true) end
  f:Hide()
  if type(UISpecialFrames) == "table" then
    UISpecialFrames[#UISpecialFrames + 1] = "DropamineFrame"
  end
  if used == "custom" or used == "BackdropTemplate" then
    if not SetBackdropSafe(f, {
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 },
    }, BROWN_BG[1], BROWN_BG[2], BROWN_BG[3], BROWN_BG[4], 0.55, 0.40, 0.18, 1) then
      local bg = f:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      FillTexture(bg, BROWN_BG[1], BROWN_BG[2], BROWN_BG[3], BROWN_BG[4])
    end
    local close = TryCreate("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)
  end
  local tt = f.TitleText
  if type(tt) == "table" and tt.SetText then
    self.title = tt
  else
    self.title = Text(f, "GameFontNormal", "CENTER")
    self.title:SetPoint("TOP", 0, -8)
  end
  self.title:SetText(Tr["Niveau total"])
  local portrait = (type(f.portrait) == "table" and f.portrait) or (f.PortraitContainer and f.PortraitContainer.portrait)
  if portrait and SetPortraitTexture then pcall(SetPortraitTexture, portrait, "player") end
  self.subtitle = Text(f, "GameFontHighlightSmall", "LEFT")
  self.subtitle:SetPoint("TOPLEFT", 70, -32)
  self.subtitle:SetTextColor(0.85, 0.80, 0.65)

  local grid = self:BuildGrid(f, "DropamineSolo")
  grid:SetPoint("TOPLEFT", 12, -56)
  grid:SetPoint("BOTTOMRIGHT", -8, 8)
  self.soloGrid = grid
  self.frame = f
  RestoreFramePos(f, "pos", { "CENTER", 0, 40 })
  f:SetScript("OnShow", function()
    if SetPortraitTexture and portrait then pcall(SetPortraitTexture, portrait, "player") end
    UI:Refresh(true)
  end)
end

-- 3.5.21 : en combat, mise à jour des textes et du remplissage des cases
-- déjà posées, sans SetPoint / Show / Hide / SetFrameLevel (le wrap peut
-- être enfant de SkillFrame, cadre protégé). La mise en page complète
-- attend PLAYER_REGEN_ENABLED (self.dirty).
function UI:RefreshVisibleTiles(wrap, snap)
  if not (wrap and snap and wrap.tiles) then return end
  wrap._snap = snap
  local function match(t)
    local d0 = t and t.data
    if not d0 then return nil end
    if d0.kind == "total" then
      d0.current = snap.total or snap.ficTotal or d0.current
      d0.apiMax = snap.totalMax or snap.ficMax or d0.apiMax
      return d0
    end
    for _, d in ipairs(snap.tiles or {}) do
      if d and ((d0.key and d.key == d0.key) or (d0.kind and d.kind == d0.kind and d0.name and d.name == d0.name)) then
        return d
      end
    end
    return nil
  end
  for i = 1, #wrap.tiles do
    local t = wrap.tiles[i]
    local d = match(t)
    if d then
      pcall(self.UpdateTile, self, t, d)
      if t._wideOn and ns.Wide and ns.Wide.Paint then pcall(ns.Wide.Paint, t) end
    end
  end
  if wrap.totalFS and wrap.totalFS.SetText then
    local full, short = self:FooterText(snap)
    wrap.totalFS:SetText(full)
    local okW, sw = pcall(wrap.totalFS.GetStringWidth, wrap.totalFS)
    sw = okW and ns.N(sw) or nil
    if sw and sw > self:GetGridInnerWidth(wrap) - 12 then wrap.totalFS:SetText(short) end
  end
end

function UI:Refresh(force)
  local need = force or (self.frame and self.frame:IsShown()) or (self.embed and self.embed:IsShown()) or (self.skillFrame and self.skillFrame:IsShown() and self:IsOsrsView())
  if not need and not force then
    self.dirty = true
    return
  end
  local combat = type(InCombatLockdown) == "function" and InCombatLockdown()
  -- 3.5.21 : en combat on met à jour les valeurs (textes, jauges) ; seules
  -- les opérations sur cadres protégés (SetPoint / Show / Hide / SetFrameLevel)
  -- sont reportées à PLAYER_REGEN_ENABLED.
  local okC, snap = pcall(ns.Collect)
  if not okC then SafeStep("collecte", error, snap) return end
  self.snapshot = snap
  self._snapVersion = (self._snapVersion or 0) + 1
  SafeStep("objectifs / paliers", self.CheckMilestones, self, snap)
  if not combat then
    SafeStep("style métiers", self.ApplyProfessionStyle, self)
  end
  if self.title then
    self.title:SetText(Tr["Niveau total"])
  end
  if self.subtitle then
    local name = snap.playerName or ""
    if name ~= "" then
      self.subtitle:SetText(name .. Tr["  ·  niveau "] .. tostring(snap.level or 0))
    else
      self.subtitle:SetText("")
    end
  end
  if combat then
    if self.soloGrid and self.frame and self.frame:IsShown() then
      self:RefreshVisibleTiles(self.soloGrid, snap)
    end
    if self.embed and self.embed:IsShown() then
      self:RefreshVisibleTiles(self.embed, snap)
    end
    self.dirty = true
    return
  end
  self.dirty = false
  if self.soloGrid and self.frame and self.frame:IsShown() then
    self:LayoutGrid(self.soloGrid, snap)
  end
  if self.embed and self.embed:IsShown() then
    self:LayoutGrid(self.embed, snap)
  end
  self:ReapplySelection()
end

-- Cadres de minuterie dédiés : chacun s'arrête après un passage (aucun
-- OnUpdate permanent, plus de minuterie qui en écrase une autre).
function UI:TimerFrame(name)
  self.timers = self.timers or {}
  local f = self.timers[name]
  if not f then
    local ok, fr = pcall(CreateFrame, "Frame")
    if not ok then return nil end
    f = fr
    self.timers[name] = f
  end
  return f
end

function UI:RequestRefresh()
  self.dirty = true
  local visible = (self.frame and self.frame:IsShown()) or (self.embed and self.embed:IsShown()) or (self.skillFrame and self.skillFrame:IsShown())
  if not visible then return end
  if self.pending then return end
  self.pending = true
  local holder = self:TimerFrame("refresh")
  if not holder or not holder.SetScript then
    self.pending = false
    self:Refresh()
    return
  end
  holder:SetScript("OnUpdate", function(f, elapsed)
    f._osrsAcc = (f._osrsAcc or 0) + (elapsed or 0.05)
    if f._osrsAcc < 0.10 then return end
    f._osrsAcc = 0
    f:SetScript("OnUpdate", nil)
    UI.pending = false
    UI:Refresh()
  end)
end

-- v2.4.4 : si l'onglet Comp. existe, on l'ouvre en vue OSRS ; la fenêtre
-- de secours n'apparaît QUE si le client n'a pas de SkillFrame.
-- v2.8.4 : si l'onglet Comp. n'existe pas encore (créé à la 1re ouverture de
-- la fiche), on ouvre la fiche puis on attend le cadre au plus ~1 s ; la
-- minuterie s'arrête dans tous les cas (aucun OnUpdate qui reste actif).
UI.OPEN_WAIT_MAX = 1.0
function UI:OpenSkillTab(after)
  local f = self:FindSkillFrame()
  if not f and not (ns.InCombat and ns.InCombat()) and type(_G.ToggleCharacter) == "function" then
    pcall(_G.ToggleCharacter, "SkillFrame")
    f = self:FindSkillFrame()
    if not f then
      local tf = self:TimerFrame("openwait")
      if not tf then return false end
      tf._acc = 0
      tf:SetScript("OnUpdate", function(fr, el)
        fr._acc = (fr._acc or 0) + (el or 0.05)
        local sf = UI:FindSkillFrame()
        if sf or fr._acc >= UI.OPEN_WAIT_MAX then
          fr:SetScript("OnUpdate", nil)
          if sf then
            SafeStep("ouverture Comp.", function() UI:HookSkillFrame() UI:ApplyView() end)
            if after then SafeStep("après ouverture", after) end
          else
            ns.Print(Tr["onglet Comp. introuvable : ouvrez la fiche du personnage (C) puis l'onglet Comp."])
          end
        end
      end)
      return "waiting"
    end
  end
  if not f then return false end
  if ns.InCombat and ns.InCombat() then
    ns.AfterCombat("openskilltab", function() UI:OpenSkillTab() end)
    ns.Print(Tr["en combat : la fenêtre s'ouvrira à la fin du combat."])
    return true
  end
  if self.frame and self.frame.Hide then self.frame:Hide() end
  if not ns.db then initDBSafe() end
  ns.db.ui = ns.db.ui or {}
  local okS, shown = pcall(f.IsShown, f)
  local cf = _G.CharacterFrame
  local cfShown = cf and cf.IsShown and select(2, pcall(cf.IsShown, cf))
  if not (okS and shown and cfShown) and type(_G.ToggleCharacter) == "function" then
    pcall(_G.ToggleCharacter, "SkillFrame")
  end
  SafeStep("ouverture Comp.", function()
    UI:HookSkillFrame()
    UI:ApplyView()
  end)
  if after then SafeStep("après ouverture", after) end
  return true
end

function UI:Show()
  if self:OpenSkillTab() then return end
  if not self.frame then self:BuildStandalone() end
  if self.frame then self.frame:Show() end
end
function UI:Hide()
  if self.frame then self.frame:Hide() end
end
function UI:Toggle()
  if self:FindSkillFrame() then
    local f = self.skillFrame or self:FindSkillFrame()
    local cf = _G.CharacterFrame
    local okS, shown = pcall(f.IsShown, f)
    local cfShown = cf and cf.IsShown and select(2, pcall(cf.IsShown, cf))
    if okS and shown and cfShown and type(_G.ToggleCharacter) == "function" then
      if ns.InCombat and ns.InCombat() then
        ns.AfterCombat("closeskilltab", function() pcall(_G.ToggleCharacter, "SkillFrame") end)
        return
      end
      pcall(_G.ToggleCharacter, "SkillFrame")
      return
    end
    self:OpenSkillTab()
    return
  end
  if not self.frame then self:BuildStandalone() end
  if not self.frame then return end
  if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

-- Minimap -------------------------------------------------------------------
local DEFAULT_ANGLE = 45
local function MinimapAnglePoint(angle)
  local radius = 80
  if Minimap and Minimap.GetWidth then radius = (Minimap:GetWidth() / 2) + 10 end
  local rad = math.rad(angle or DEFAULT_ANGLE)
  return math.cos(rad) * radius, math.sin(rad) * radius
end

function UI:PlaceMinimapButton()
  local b = self.minimap
  if not b then return end
  if not Minimap then
    RestoreFramePos(b, "minimapPos", { "CENTER", 0, 0 })
    return
  end
  local angle = (ns.db and ns.db.ui and ns.db.ui.minimapAngle) or DEFAULT_ANGLE
  local x, y = MinimapAnglePoint(angle)
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function UI:BuildMinimap()
  if self.minimap then return end
  local parent = Minimap or UIParent
  local b = TryCreate("Button", "DropamineMinimapButton", parent, "BackdropTemplate")
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  if b.SetFrameLevel and parent.GetFrameLevel then
    pcall(b.SetFrameLevel, b, (parent:GetFrameLevel() or 0) + 8)
  end
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  -- 3.5.20 : icône « La Fiole » (master simplifié 32 px) ; ToggleIcon la reprend ensuite.
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  pcall(icon.SetTexture, icon, "Interface\\AddOns\\Dropamine\\Media\\Dropamine-Icon-32")
  b.icon = icon
  local overlay = b:CreateTexture(nil, "OVERLAY")
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetSize(54, 54)
  overlay:SetPoint("TOPLEFT")
  b.overlay = overlay
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnClick", function(self)
    -- 3.5.5 : seul le clic qui TERMINE un glisser est ignoré (avant, un glisser
    -- relâché hors du bouton avalait le clic suivant : bouton « sans effet »)
    local moved = self.moved
    self.moved = false
    if moved and type(GetTime) == "function" and (GetTime() - (self._dragStop or 0)) < 0.3 then return end
    -- Clic : ouvrir / fermer le panneau (chemin protégé, voir SafeOpen.lua)
    UI:Toggle()
  end)
  local function minimapDragUpdate(self)
    if not self.dragging then self:SetScript("OnUpdate", nil) return end
    if Minimap and Minimap.GetCenter and GetCursorPosition then
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = (Minimap.GetEffectiveScale and Minimap:GetEffectiveScale()) or 1
      if scale == 0 then scale = 1 end
      cx, cy = cx / scale, cy / scale
      local angle = math.deg(math.atan2(cy - my, cx - mx))
      if ns.db and ns.db.ui then ns.db.ui.minimapAngle = angle end
      UI:PlaceMinimapButton()
    elseif self.StartMoving and not self._freeMoving then
      self._freeMoving = true
      self:SetMovable(true)
      self:StartMoving()
    end
  end
  b:SetScript("OnDragStart", function(self)
    self.dragging = true self.moved = true
    self:SetScript("OnUpdate", minimapDragUpdate)
  end)
  b:SetScript("OnDragStop", function(self)
    self.dragging = false
    self._dragStop = type(GetTime) == "function" and GetTime() or 0
    if self._freeMoving and self.StopMovingOrSizing then
      self:StopMovingOrSizing()
      self._freeMoving = false
    end
    if not Minimap then SaveFramePos(self, "minimapPos") end
  end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local snap = UI.snapshot or (ns.Collect and ns.Collect())
    GameTooltip:AddLine(Tr["Niveau total"], GOLD[1], GOLD[2], GOLD[3])
    if snap then
      GameTooltip:AddLine(Tr["Total : "] .. tostring(snap.total or snap.ficTotal or 0) .. " / " .. tostring(snap.totalMax or snap.ficMax or 0), 1, 1, 1)
    end
    GameTooltip:AddLine(Tr["Clic : ouvrir / fermer"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  if b.SetMovable then b:SetMovable(true) end
  if b.SetClampedToScreen then b:SetClampedToScreen(true) end
  self.minimap = b
  self:PlaceMinimapButton()
  if ns.db and ns.db.ui and ns.db.ui.minimapHidden then b:Hide() else b:Show() end
end

function UI:ToggleMinimap()
  if not self.minimap then self:BuildMinimap() end
  if not self.minimap then return false end
  local hide = self.minimap:IsShown()
  SetShownSafe(self.minimap, not hide)
  if ns.db and ns.db.ui then ns.db.ui.minimapHidden = hide and true or false end
  return not hide
end

function UI:ResetPositions()
  if ns.db and ns.db.ui then
    ns.db.ui.pos = nil
    ns.db.ui.minimapAngle = DEFAULT_ANGLE
    ns.db.ui.minimapPos = nil
    ns.db.ui.dropsPos = nil
  end
  if self.frame then RestoreFramePos(self.frame, "pos", { "CENTER", 0, 40 }) end
  if self.dropsFrame then RestoreFramePos(self.dropsFrame, "dropsPos", { "TOPRIGHT", -40, -80 }) end
  self:PlaceMinimapButton()
end

-- Drops d'XP / compétences, style notifications Forever au repos -------------
-- Au repos : fond noir translucide (~0.6) comme le chat, filet sombre mince,
-- titre or, sous-titre jaune, barre kaki, icône dans un anneau d'or.
-- Le voile bleu-gris n'apparaît QUE dans le mode édition (grille Forever).
-- Jamais le portrait : XP = icône livre du Niveau, compétences = leur icône.
-- v2.7.1 : 56 = hauteur d'un drop complet type (titre 12 + ligne 14 + marges 12
-- + astuce 11 + barre 7) ; c'est aussi la taille du support en mode édition.
local TOAST_W, TOAST_H = 260, 56
local TOAST_GAP = 4
local TOAST_FADEIN, TOAST_HOLD, TOAST_FADEOUT = 0.15, 2.6, 0.70
local TOAST_BG_A = 0.35   -- v2.7.1 : un peu plus translucide, comme le chat
local TOAST_LIGHT_H = 26

-- Durée d'affichage (options) et opacité du fond, bornées.
function UI:DropHold()
  local v = ns.db and ns.db.ui and ns.N(ns.db.ui.dropDuration)
  if not v then return TOAST_HOLD end
  return math.max(1, math.min(10, v))
end
function UI:DropBgAlpha()
  local v = ns.db and ns.db.ui and ns.N(ns.db.ui.dropBgAlpha)
  if not v then return nil end
  return math.max(0, math.min(1, v))
end
local TOAST_BORDER = { 0.12, 0.10, 0.08, 0.95 }
local TOAST_YELLOW = { 1.00, 0.82, 0.20 }
local TOAST_KHAKI = { 0.76, 0.64, 0.30, 1 }
local EDIT_BG = { 0.45, 0.62, 0.78, 0.32 }
local EDIT_BORDER = { 0.55, 0.82, 0.95, 0.95 }
local RING_TEX = {
  "Interface\\Minimap\\MiniMap-TrackingBorder",
  "Interface\\Common\\WhiteIconFrame",
  "Interface\\Buttons\\UI-ActionButton-Border",
  "Interface\\ContainerFrame\\UI-Icon-QuestBorder",
}
-- v2.4.1 : les templates d'alerte natifs (AlertFrameTemplate...) déclarent un
-- OnClick réservé aux Button : sur un Frame ils lèvent un avertissement LUA
-- (non intercepté par pcall). On ne garde que BackdropTemplate.
local TOAST_TEMPLATES = { "BackdropTemplate" }
local LOOT_BAR_TEX = {
  "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
  "Interface\\TargetingFrame\\UI-StatusBar",
  "Interface\\Buttons\\WHITE8X8",
}
local CHAT_BG_FILES = {
  "Interface\\ChatFrame\\ChatFrameBackground",
  "Interface\\Tooltips\\UI-Tooltip-Background",
  "Interface\\Buttons\\WHITE8X8",
}
local CHAT_EDGE_FILES = {
  "Interface\\Tooltips\\UI-Tooltip-Border",
  "Interface\\ChatFrame\\ChatFrameBorder",
  "Interface\\DialogFrame\\UI-DialogBox-Border",
}

-- v2.5.0 : chrome des drops = cadre du chat Forever (fond noir translucide,
-- filet doré fin aux coins arrondis). Pièces relevées en jeu sur ChatFrame1
-- (NineSlice ou textures $parentTopLeftTexture…), recopiées telles quelles ;
-- repli : bord arrondi des info-bulles teinté or + fond du chat.
local CHAT_PIECES = {
  { key = "TopLeftCorner", suffix = "TopLeftTexture", corner = "TOPLEFT" },
  { key = "TopRightCorner", suffix = "TopRightTexture", corner = "TOPRIGHT" },
  { key = "BottomLeftCorner", suffix = "BottomLeftTexture", corner = "BOTTOMLEFT" },
  { key = "BottomRightCorner", suffix = "BottomRightTexture", corner = "BOTTOMRIGHT" },
  { key = "TopEdge", suffix = "TopTexture", edge = "TOP" },
  { key = "BottomEdge", suffix = "BottomTexture", edge = "BOTTOM" },
  { key = "LeftEdge", suffix = "LeftTexture", edge = "LEFT" },
  { key = "RightEdge", suffix = "RightTexture", edge = "RIGHT" },
}
local CHAT_FALLBACK_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local CHAT_FALLBACK_BG = "Interface\\ChatFrame\\ChatFrameBackground"
-- v2.7.1 : bronze du bord du chat, relevé au pixel sur la capture des drops
-- (055c59bc….png) : #655131 (101, 81, 49).
local CHAT_GOLD = { 101 / 255, 81 / 255, 49 / 255, 1 }

local function PieceInfo(tex)
  if type(tex) ~= "table" then return nil end
  local path, atlas = TexOrFileID(tex)
  if not path then return nil end
  local info = { tex = path, atlas = atlas }
  if tex.GetTexCoord then
    local ok, a, b, c, d, e, f2, g, h = pcall(tex.GetTexCoord, tex)
    if ok and a then info.coords = { a, b, c, d, e, f2, g, h } end
  end
  local w, h2 = SizeOf(tex)
  info.w, info.h = w, h2
  if tex.GetVertexColor then
    local ok, r, g2, b2, a2 = pcall(tex.GetVertexColor, tex)
    if ok and r then info.color = { r, g2, b2, a2 or 1 } end
  end
  return info
end

-- v2.7.2 : le vrai bord du chat est copié à l'exécution. Ordre :
--   1. NineSlice / Border du ChatFrame1 (pièces + couleurs d'origine) ;
--   2. backdrop du ChatFrame1 (GetBackdrop : edgeFile, edgeSize, insets, couleur) ;
--   3. enfants du ChatFrame1 portant un NineSlice ou un backdrop à bord ;
--   sinon repli dessiné : 3 px (filet sombre + or + bronze relevés au pixel).
-- Les textures ChatFrame1TopLeftTexture… ne sont PLUS utilisées : c'est le
-- fond gris qui apparaît au survol du chat, d'où le bord gris/blanc en 2.7.1.
local function BackdropInfo(fr)
  if type(fr) ~= "table" or type(fr.GetBackdrop) ~= "function" then return nil end
  local ok, bd = pcall(fr.GetBackdrop, fr)
  if not ok or type(bd) ~= "table" or not bd.edgeFile then return nil end
  local info = { edgeFile = bd.edgeFile, edgeSize = ns.N(bd.edgeSize) or 12, tile = bd.tile, tileEdge = bd.tileEdge,
    insets = type(bd.insets) == "table" and { left = ns.N(bd.insets.left) or 0, right = ns.N(bd.insets.right) or 0,
      top = ns.N(bd.insets.top) or 0, bottom = ns.N(bd.insets.bottom) or 0 } or nil }
  if fr.GetBackdropBorderColor then
    local okc, r, g, b, a = pcall(fr.GetBackdropBorderColor, fr)
    if okc and ns.N(r) then info.color = { r, g, b, a or 1 } end
  end
  return info
end

local function NinePieces(ns9)
  if type(ns9) ~= "table" then return nil end
  local pieces = {}
  for i = 1, #CHAT_PIECES do
    local pc = CHAT_PIECES[i]
    local info = PieceInfo(ns9[pc.key])
    if info then pieces[pc.key] = info end
  end
  return next(pieces) and pieces or nil
end

function UI:LearnChatChrome()
  if self.chatChrome and self.chatChrome.learned then return self.chatChrome end
  local cc = { learned = false, pieces = {}, source = "repli FlareUI (Border.tga : #181513 / #624F32 / #463824 / #161412)" }
  local cf = _G.ChatFrame1
  if type(cf) == "table" then
    -- 1. NineSlice / Border
    for _, k in ipairs({ "NineSlice", "Border" }) do
      local p9 = not next(cc.pieces) and NinePieces(cf[k])
      if p9 then cc.pieces, cc.source = p9, "ChatFrame1." .. k end
    end
    -- 2. backdrop du chat
    if not next(cc.pieces) then
      local bdi = BackdropInfo(cf) or BackdropInfo(cf.Border)
      if bdi then cc.backdrop, cc.source = bdi, "ChatFrame1:GetBackdrop() " .. tostring(bdi.edgeFile) .. " (" .. tostring(bdi.edgeSize) .. " px)" end
    end
    -- 3. enfants du chat
    if not next(cc.pieces) and not cc.backdrop and cf.GetChildren then
      local kids = { pcall(cf.GetChildren, cf) }
      if kids[1] then
        for i = 2, #kids do
          local c = kids[i]
          local nm = (c and c.GetName and c:GetName()) or "(enfant)"
          local p9 = NinePieces(c and c.NineSlice)
          if p9 then cc.pieces, cc.source = p9, tostring(nm) .. ".NineSlice" break end
          local bdi = BackdropInfo(c)
          if bdi then cc.backdrop, cc.source = bdi, tostring(nm) .. ":GetBackdrop() " .. tostring(bdi.edgeFile) break end
        end
      end
    end
    local bg = _G.ChatFrame1Background or (type(cf.Background) == "table" and cf.Background)
    local bgi = PieceInfo(bg)
    if bgi then cc.bg = bgi end
    -- Couleur du fond : alpha relevée, jamais plus opaque que 0,5 au repos.
    if bgi and bgi.color then
      local a = bgi.color[4] or TOAST_BG_A
      if a > 0.5 or a < 0.2 then a = TOAST_BG_A end
      cc.bgColor = { 0, 0, 0, a }
    end
    cc.learned = next(cc.pieces) ~= nil or cc.backdrop ~= nil
  end
  cc.bgColor = cc.bgColor or { 0, 0, 0, TOAST_BG_A }
  self.chatChrome = cc
  return cc
end

local ApplyRestToastChromeRaw
-- 3.3.9 : bord des toasts = bord de l'infobulle native (Chrome.lua), coins lisses.
local function ApplyRestToastChrome(frame, tint, noBg)
  local r = ApplyRestToastChromeRaw(frame, tint, noBg)
  if frame and not noBg and ns.Chrome and ns.Chrome.Toast then
    local ok, c = pcall(ns.Chrome.Toast, frame, tint)
    if ok and c then return frame._osrsNativeBorder end
  end
  return r
end
ApplyRestToastChromeRaw = function(frame, tint, noBg)
  if not frame then return "none" end
  local cc = UI:LearnChatChrome()
  local bgc = cc.bgColor
  local ua = UI:DropBgAlpha()
  if ua then bgc = { bgc[1], bgc[2], bgc[3], ua } end
  if not noBg then
  frame._bgAlpha = bgc[4]
  if not frame._toastBg then
    frame._toastBg = frame:CreateTexture(nil, "BACKGROUND")
  end
  frame._toastBg:ClearAllPoints()
  frame._toastBg:SetPoint("TOPLEFT", 3, -3)
  frame._toastBg:SetPoint("BOTTOMRIGHT", -3, 3)
  FillTexture(frame._toastBg, bgc[1], bgc[2], bgc[3], bgc[4])
  if frame._toastBg.SetAlpha then pcall(frame._toastBg.SetAlpha, frame._toastBg, 1) end
  end
  if next(cc.pieces) then
    frame._chatPieces = frame._chatPieces or {}
    local cw, chh = 16, 16
    local tl = cc.pieces.TopLeftCorner
    if tl and tl.w and tl.w > 0 and tl.w <= 64 then cw = tl.w end
    if tl and tl.h and tl.h > 0 and tl.h <= 64 then chh = tl.h end
    for i = 1, #CHAT_PIECES do
      local pc = CHAT_PIECES[i]
      local info = cc.pieces[pc.key]
      if info then
        local t = frame._chatPieces[pc.key] or frame:CreateTexture(nil, "BORDER")
        frame._chatPieces[pc.key] = t
        t:ClearAllPoints()
        TrySetTex(t, info.tex, nil, info.atlas)
        if info.coords and t.SetTexCoord then pcall(t.SetTexCoord, t, unpack(info.coords)) end
        if pc.corner then
          t:SetSize(cw, chh)
          t:SetPoint(pc.corner, frame, pc.corner, 0, 0)
        elseif pc.edge == "TOP" or pc.edge == "BOTTOM" then
          t:SetHeight(chh)
          t:SetPoint(pc.edge .. "LEFT", frame, pc.edge .. "LEFT", cw, 0)
          t:SetPoint(pc.edge .. "RIGHT", frame, pc.edge .. "RIGHT", -cw, 0)
        else
          t:SetWidth(cw)
          t:SetPoint("TOP" .. pc.edge, frame, "TOP" .. pc.edge, 0, -chh)
          t:SetPoint("BOTTOM" .. pc.edge, frame, "BOTTOM" .. pc.edge, 0, chh)
        end
        -- Couleur d'origine du chat ; seule une variante (or / palier) teinte.
        local col = tint or info.color or { 1, 1, 1, 1 }
        if t.SetVertexColor then pcall(t.SetVertexColor, t, col[1], col[2], col[3], col[4] or 1) end
        t:Show()
      end
    end
    frame._osrsNativeBorder = "chat:" .. tostring(cc.source)
    return frame._osrsNativeBorder
  end
  if cc.backdrop then
    local b = cc.backdrop
    local bd = { edgeFile = b.edgeFile, edgeSize = b.edgeSize, tile = b.tile, tileEdge = b.tileEdge, insets = b.insets }
    local col = tint or b.color or { 1, 1, 1, 1 }
    if SetBackdropSafe(frame, bd, nil, nil, nil, nil, col[1], col[2], col[3], col[4] or 1) then
      frame._osrsNativeBorder = "chat:" .. tostring(cc.source)
      return frame._osrsNativeBorder
    end
  end
  ns.Style.FlareBorder(frame, "BORDER", 2, tint)
  frame._osrsNativeBorder = "repli FlareUI (Border.tga, or 4 px)"
  return frame._osrsNativeBorder
end

local function ApplyKhakiBar(bar)
  if not bar then return end
  if bar.SetStatusBarTexture then
    local ok = false
    for i = 1, #LOOT_BAR_TEX do
      if pcall(bar.SetStatusBarTexture, bar, LOOT_BAR_TEX[i]) then ok = true break end
    end
    if not ok then ApplyBarFill(bar) end
  else
    ApplyBarFill(bar)
  end
  if bar.SetStatusBarColor then
    pcall(bar.SetStatusBarColor, bar, TOAST_KHAKI[1], TOAST_KHAKI[2], TOAST_KHAKI[3], TOAST_KHAKI[4] or 1)
  end
end

local function PlaceGoldRing(iconHold, icon)
  local ring = iconHold:CreateTexture(nil, "OVERLAY")
  ring:SetPoint("CENTER", icon, "CENTER", 0, 0)
  local used
  for i = 1, #RING_TEX do
    ring:SetSize(46, 46)
    if TrySetTex(ring, RING_TEX[i], "BLEND") then
      if ring.SetVertexColor then pcall(ring.SetVertexColor, ring, GOLD[1], GOLD[2], GOLD[3], 1) end
      used = RING_TEX[i]
      break
    end
  end
  if not used then
    ring:Hide()
    ThinBronzeBorder(iconHold)
  end
  if icon.SetMask then
    pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask")
  end
  return used
end

function UI:DropsEnabled()
  return not (ns.db and ns.db.ui and ns.db.ui.dropsEnabled == false)
end

function UI:BuildDrops()
  if self.dropsFrame then
    self:HookEditMode()
    return self.dropsFrame
  end
  local existing = _G.DropamineDrops
  if type(existing) == "table" and existing.SetPoint then
    self.dropsFrame = existing
    self.dropsStack = existing.stack or existing
    self.dropsActive = self.dropsActive or {}
    self:HookEditMode()
    return existing
  end
  local parent = UIParent
  if not parent then return nil end
  local f, usedTmpl
  for i = 1, #TOAST_TEMPLATES do
    local ok, cand = pcall(CreateFrame, "Frame", "DropamineDrops", parent, TOAST_TEMPLATES[i])
    if ok and cand then f, usedTmpl = cand, TOAST_TEMPLATES[i] break end
  end
  if not f then f = CreateFrame("Frame", "DropamineDrops", parent) end
  -- v2.7.1 : le support a exactement la taille du premier drop (aucune marge),
  -- pour pouvoir le poser pile sur le cadre de chat.
  local firstH = self:DropFirstHeight()
  f:SetSize(TOAST_W, firstH)
  if f.SetFrameStrata then pcall(f.SetFrameStrata, f, "HIGH") end
  if f.SetMovable then pcall(f.SetMovable, f, true) end
  if f.EnableMouse then pcall(f.EnableMouse, f, false) end
  if f.RegisterForDrag then pcall(f.RegisterForDrag, f, "LeftButton") end
  f:SetScript("OnDragStart", function(self)
    if (self._osrsMoving or self._osrsEditMoving) and self.StartMoving then
      pcall(self.StartMoving, self)
    end
  end)
  f:SetScript("OnDragStop", function(self)
    if self.StopMovingOrSizing then pcall(self.StopMovingOrSizing, self) end
    SaveFramePos(self, "dropsPos")
    UI:SnapDropsToChat()
  end)
  if f.SetClampedToScreen then pcall(f.SetClampedToScreen, f, true) end
  -- Migration : avant 2.7.1 le support faisait 200 px de haut, ancré par le
  -- bas ; on garde son bord haut à la même place (empilement vers le bas).
  if ns.db and ns.db.ui and ns.db.ui.dropsPos and not ns.db.ui.dropsPosV271 then
    local p = ns.db.ui.dropsPos
    if (p.point or "BOTTOMLEFT") == "BOTTOMLEFT" and type(p.y) == "number" then p.y = p.y + (200 - firstH) end
  end
  if ns.db and ns.db.ui then ns.db.ui.dropsPosV271 = true end
  f._osrsHeight = firstH
  RestoreFramePos(f, "dropsPos", { "TOPRIGHT", -40, -80 })
  if ns.db and ns.db.ui and ns.db.ui.dropsSnapChat then
    local _, _, cw = self:ChatRect()
    if cw then f._snapW = math.floor(cw + 0.5) f:SetSize(f._snapW, firstH) end
  end

  -- Poignée /drop drops move : style chat (fond noir), PAS le voile bleu d'édition.
  local handle = CreateFrame("Frame", nil, f)
  handle:SetHeight(18)
  ApplyRestToastChrome(handle)
  local hfs = Text(handle, "GameFontNormalSmall", "CENTER")
  hfs:SetPoint("CENTER", 0, 0)
  hfs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  hfs:SetText(Tr["Drops  ·  glisser pour déplacer"])
  handle:Hide()
  f.handle = handle

  -- Voile bleu-gris du mode édition uniquement.
  local ov = CreateFrame("Frame", nil, f)
  ov:SetAllPoints(f)   -- v2.7.1 : voile = taille exacte du premier drop
  if ov.SetFrameLevel and f.GetFrameLevel then
    pcall(ov.SetFrameLevel, ov, (f:GetFrameLevel() or 1) + 1)
  end
  if ov.EnableMouse then pcall(ov.EnableMouse, ov, false) end
  local glow = ov:CreateTexture(nil, "BACKGROUND")
  glow:SetAllPoints(ov)
  FillTexture(glow, EDIT_BORDER[1], EDIT_BORDER[2], EDIT_BORDER[3], 0.18)
  local ovbg = ov:CreateTexture(nil, "ARTWORK")
  ovbg:SetAllPoints()
  FillTexture(ovbg, EDIT_BG[1], EDIT_BG[2], EDIT_BG[3], EDIT_BG[4])
  EnsurePixelBorder(ov, "OVERLAY")
  ColorPixelBorder(ov, EDIT_BORDER[1], EDIT_BORDER[2], EDIT_BORDER[3], EDIT_BORDER[4])
  local ovfs = Text(ov, "GameFontNormal", "CENTER")
  ovfs:SetPoint("CENTER", 0, 0)
  ovfs:SetTextColor(0.85, 0.95, 1)
  ovfs:SetText(Tr["Drops  ·  glisser pour déplacer"])
  ov:Hide()
  f.editOverlay, f.editLabel = ov, ovfs

  local stack = CreateFrame("Frame", nil, f)
  stack:SetPoint("TOPLEFT", 0, 0)
  stack:SetPoint("BOTTOMRIGHT", 0, 0)
  f.stack = stack

  self.dropsFrame, self.dropsStack = f, stack
  self.dropsActive = {}
  self._dropsTemplate = usedTmpl
  self:PlaceDropsHandle()
  if f.Show then pcall(f.Show, f) end
  self:HookEditMode()
  return f
end

function UI:ApplyDropsEnabled()
  self:BuildDrops()
  if not self.dropsFrame then return end
  if self:DropsEnabled() or self._inEditMode or (self.dropsFrame and self.dropsFrame._osrsMoving) then
    if self.dropsFrame.Show then pcall(self.dropsFrame.Show, self.dropsFrame) end
  else
    if self.dropsFrame.Hide then pcall(self.dropsFrame.Hide, self.dropsFrame) end
  end
end

function UI:ToggleDropsMove()
  self:BuildDrops()
  self:ApplyDropsEnabled()
  local f = self.dropsFrame
  if not f then return end
  if not self:DropsEnabled() then
    if ns.db and ns.db.ui then ns.db.ui.dropsEnabled = true end
    self:ApplyDropsEnabled()
  end
  f._osrsMoving = not f._osrsMoving
  if f.EnableMouse then pcall(f.EnableMouse, f, (f._osrsMoving or self._inEditMode) and true or false) end
  if f.handle and not self._inEditMode then
    if f._osrsMoving then f.handle:Show() else f.handle:Hide() end
  end
  if f._osrsMoving then
    ns.Print(Tr["déplace le cadre des drops, puis /drop drops move pour figer."])
  else
    SaveFramePos(f, "dropsPos")
    ns.Print(Tr["position des drops enregistrée."])
  end
end

-- 3.5.1 : sens d'empilement en position libre (« Vers le haut » par défaut,
-- « Vers le bas », « Sur place »). En position accrochée, Notif.lua force
-- haut / bas selon dessus / dessous.
UI.PILE_OFF, UI.PILE_MAX = 4, 3
UI.PILE_FADE = { 1, 0.80, 0.60 }
function UI:DropDir()
  local d = ns.db and ns.db.ui and ns.db.ui.dropDir
  if d == "haut" or d == "bas" or d == "place" then return d end
  return "haut"
end

local function ToastAlpha(frame, a)
  if not frame or not frame.SetAlpha then return end
  local fade = frame._pileHidden and 0 or (frame._pileFade or 1)
  pcall(frame.SetAlpha, frame, (a or 1) * fade)
end

local function EnsurePileShade(t)
  if t._shade then return t._shade end
  if not t.CreateTexture then return nil end
  local sh = t:CreateTexture(nil, "OVERLAY")
  sh:SetAllPoints(t)
  pcall(sh.SetTexture, sh, "Interface\\Buttons\\WHITE8X8")
  if sh.SetDrawLayer then pcall(sh.SetDrawLayer, sh, "OVERLAY", 7) end
  t._shade = sh
  return sh
end

-- v2.7.2 : support posé sur le chat → même largeur que le chat, collé à son
-- bord haut et aligné à gauche (aimant de 16 px). Sinon 260 px.
UI.SNAP_PX = 16
function UI:ChatRect()
  local cf = _G.ChatFrame1
  if type(cf) ~= "table" or not cf.GetLeft then return nil end
  local l, t, w = cf:GetLeft(), cf.GetTop and cf:GetTop(), cf.GetWidth and cf:GetWidth()
  l, t, w = ns.N(l), ns.N(t), ns.N(w)
  if not (l and t and w and w > 50) then return nil end
  return l, t, w
end

function UI:DropSnappedToChat()
  local f = self.dropsFrame
  if not f or not f.GetLeft or not f.GetBottom then return false end
  local cl, ct = self:ChatRect()
  if not cl then return false end
  local l, b = ns.N(f:GetLeft()), ns.N(f:GetBottom())
  if not (l and b) then return false end
  return math.abs(l - cl) <= UI.SNAP_PX and b >= ct - UI.SNAP_PX and b <= ct + UI.SNAP_PX * 3
end

function UI:DropWidth()
  if self.dropsFrame and self.dropsFrame._snapW then return self.dropsFrame._snapW end
  return TOAST_W
end

-- Après un déplacement : aimante le support au chat (même largeur, sans décalage).
function UI:SnapDropsToChat()
  local f = self.dropsFrame
  if not f then return false end
  if self:DropSnappedToChat() then
    local cl, ct, cw = self:ChatRect()
    f._snapW = math.floor(cw + 0.5)
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cl, ct)
    if ns.db and ns.db.ui then
      ns.db.ui.dropsPos = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = cl, y = ct }
      ns.db.ui.dropsSnapChat = true
    end
  else
    f._snapW = nil
    if ns.db and ns.db.ui then ns.db.ui.dropsSnapChat = false end
  end
  self:ApplyDropsLayout()
  return f._snapW ~= nil
end

-- Option « Coller au chat » : pose le support au ras du bord haut du chat.
function UI:SetDropsSnapChat(on)
  self:BuildDrops()
  local f = self.dropsFrame
  if not f then return false end
  if on then
    local cl, ct, cw = self:ChatRect()
    if not cl then
      if ns.db and ns.db.ui then ns.db.ui.dropsSnapChat = false end
      ns.Print(Tr["cadre de chat introuvable : impossible d'y coller les drops."])
      return false
    end
    f._snapW = math.floor(cw + 0.5)
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cl, ct)
    if ns.db and ns.db.ui then
      ns.db.ui.dropsPos = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = cl, y = ct }
      ns.db.ui.dropsSnapChat = true
    end
  else
    f._snapW = nil
    if ns.db and ns.db.ui then ns.db.ui.dropsSnapChat = false end
  end
  self:ApplyDropsLayout()
  return f._snapW ~= nil
end

function UI:DropFirstHeight()
  local light = ns.db and ns.db.ui and ns.db.ui.dropStyle == "leger"
  return light and TOAST_LIGHT_H or TOAST_H
end

function UI:PlaceDropsHandle()
  local f = self.dropsFrame
  local h = f and f.handle
  if not h then return end
  h:ClearAllPoints()
  local dir = self:DropDir()
  if dir == "haut" or dir == "place" then
    -- Les drops montent ou s'empilent sur place : la poignée passe sous le support.
    h:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
    h:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, 0)
  else
    h:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 0)
    h:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 0)
  end
end

-- Recalcule la taille du support (= premier drop, + décalage pile en « sur place »)
-- en gardant fixe le bord d'ancrage (haut en « vers le bas », bas autrement).
function UI:ApplyDropsLayout()
  local f = self.dropsFrame
  if not f then return end
  local newH = self:DropFirstHeight()
  local dir = self:DropDir()
  local extra = (dir == "place") and ((self.PILE_MAX or 3) - 1) * (self.PILE_OFF or 4) or 0
  local oldH = f._osrsHeight or newH
  local oldExtra = f._osrsPile or 0
  if (newH + extra) ~= (oldH + oldExtra) and f.GetLeft and f.GetBottom then
    local l, b = f:GetLeft(), f:GetBottom()
    if type(l) == "number" and type(b) == "number" then
      if dir == "bas" then b = b + (oldH + oldExtra) - (newH + extra) end
      f:ClearAllPoints()
      f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
      if ns.db and ns.db.ui then ns.db.ui.dropsPos = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = l, y = b } end
    end
  end
  f:SetSize(self:DropWidth() + extra, newH + extra)
  f._osrsHeight, f._osrsPile = newH, extra
  self:PlaceDropsHandle()
  self:PackDrops()
end

function UI:PackDrops()
  local parent = self.dropsStack or self.dropsFrame
  if not parent or not self.dropsActive then return end
  local dir = self:DropDir()
  local n = #self.dropsActive
  local pile = dir == "place"
  local off, maxv = self.PILE_OFF or 4, self.PILE_MAX or 3
  local fades = self.PILE_FADE or { 1, 0.80, 0.60 }
  local baseLvl = (parent.GetFrameLevel and parent:GetFrameLevel()) or 1
  if pile then
    for i = 1, n do
      local t = self.dropsActive[i]
      if t and t.ClearAllPoints then
        t:ClearAllPoints()
        local depth = n - i
        if depth >= maxv then
          t._pileHidden, t._pileFade = true, 0
          if t._shade then t._shade:Hide() end
          if t.Hide then pcall(t.Hide, t) end
          ToastAlpha(t, 0)
          if t.EnableMouse then pcall(t.EnableMouse, t, false) end
        else
          t._pileHidden, t._pileFade = nil, fades[depth + 1] or 0.5
          if t.Show then pcall(t.Show, t) end
          t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", depth * off, depth * off)
          if t.SetFrameLevel then pcall(t.SetFrameLevel, t, baseLvl + (maxv - depth) + 1) end
          if depth > 0 then
            local sh = EnsurePileShade(t)
            if sh then
              sh:SetVertexColor(0, 0, 0, 0.18 * depth)
              sh:Show()
            end
            if t.EnableMouse then pcall(t.EnableMouse, t, false) end
          else
            if t._shade then t._shade:Hide() end
            if t.EnableMouse and not self._inEditMode then pcall(t.EnableMouse, t, true) end
          end
          ToastAlpha(t, 1)
        end
      end
    end
    return
  end
  local y = 0
  if dir == "haut" then
    -- Le plus récent reste à l'ancre (bas du support), les plus anciens montent.
    for i = n, 1, -1 do
      local t = self.dropsActive[i]
      if t and t.ClearAllPoints then
        t._pileHidden, t._pileFade = nil, 1
        if t._shade then t._shade:Hide() end
        t:ClearAllPoints()
        if t.Show then pcall(t.Show, t) end
        t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, y)
        y = y + (t._h or TOAST_H) + TOAST_GAP
        ToastAlpha(t, 1)
      end
    end
  else
    -- Vers le bas : comportement historique (le plus ancien en haut, les suivants en dessous).
    for i = 1, n do
      local t = self.dropsActive[i]
      if t and t.ClearAllPoints then
        t._pileHidden, t._pileFade = nil, 1
        if t._shade then t._shade:Hide() end
        t:ClearAllPoints()
        if t.Show then pcall(t.Show, t) end
        t:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
        y = y + (t._h or TOAST_H) + TOAST_GAP
        ToastAlpha(t, 1)
      end
    end
  end
end

local DROP_VARIANTS = {
  gold = { border = { 1.00, 0.82, 0.10, 1 }, title = { 1.00, 0.86, 0.20 } },
  palier = { border = { 1.00, 0.55, 0.15, 1 }, title = { 1.00, 0.62, 0.20 } },
}

-- v2.8.1 : finition du drop = composant de référence (STYLEGUIDE.md). Bord
-- seul (noBg) pour les encadrés qui gardent le dégradé brun clair Métiers.
function UI:ApplyDropFinish(frame, noBg)
  if type(frame) ~= "table" or not frame.CreateTexture then return nil end
  local ok, r = pcall(ApplyRestToastChrome, frame, nil, noBg)
  frame._dropFinish = ok and (noBg and "bord" or "fond+bord") or nil
  return ok and r or nil
end

function UI:WireDropMouse(f)
  if not f or not f.SetScript then return end
  if f.EnableMouse then pcall(f.EnableMouse, f, not self._inEditMode) end
  f:SetScript("OnEnter", function(self) self._hover = true ToastAlpha(self, 1) end)
  f:SetScript("OnLeave", function(self) self._hover = false if self._restart then self._restart() end end)
  f:SetScript("OnMouseUp", function(self, button)
    -- mode édition / déplacement : jamais d'ouverture (le clic sert au glisser)
    if self._dragged then self._dragged = nil return end
    if UI._inEditMode or self._editPreview then return end
    local df = UI.dropsFrame
    if df and (df._osrsMoving or df._osrsEditMoving) then return end
    if button == "RightButton" then UI:DismissDrop(self)
    else UI:OpenFromDrop(self._target, self) end
  end)
  -- 3.0.0 : le glisser sur un drop déplace le SUPPORT (mode édition ou
  -- /drop drops move) — le drop ne vole plus le glisser au support.
  if f.RegisterForDrag then pcall(f.RegisterForDrag, f, "LeftButton") end
  f:SetScript("OnDragStart", function(self)
    local df = UI.dropsFrame
    if df and (df._osrsMoving or df._osrsEditMoving or UI._inEditMode) and df.StartMoving then
      self._dragged = true
      pcall(df.StartMoving, df)
      df._osrsDragging = true
    end
  end)
  f:SetScript("OnDragStop", function(self)
    local df = UI.dropsFrame
    if df and df._osrsDragging then
      df._osrsDragging = nil
      local h = df.GetScript and df:GetScript("OnDragStop")
      if h then h(df) end
    end
  end)
  -- état final de la souris posé APRÈS les SetScript
  if f.EnableMouse then pcall(f.EnableMouse, f, (not self._inEditMode) or f._editPreview or false) end
end

function UI:DismissDrop(f)
  if not f then return end
  if f.SetScript then pcall(f.SetScript, f, "OnUpdate", nil) end
  f._hover = false
  if f.Hide then pcall(f.Hide, f) end
  for i = #(self.dropsActive or {}), 1, -1 do
    if self.dropsActive[i] == f then table.remove(self.dropsActive, i) end
  end
  self:PackDrops()
  self.dismissed = (self.dismissed or 0) + 1
end

-- Tuile visée par un drop : XP / niveau → Niveau ; montée de niveau → Niveau
-- total ; arme → tuile de combat ; métier → sa tuile.
function UI:DropTargetData(target)
  target = target or {}
  if target.kind == "levelup" then return UI.TOTAL_DATA end
  local snap = self.snapshot
  if not snap then local ok, s2 = pcall(ns.Collect) snap = ok and s2 or nil self.snapshot = snap end
  local tiles = snap and snap.tiles or {}
  if target.kind == "xp" then
    for _, d in ipairs(tiles) do if d.kind == "level" then return d end end
  end
  local id = target.skillId
  if id then
    for _, d in ipairs(tiles) do if d.id == id and not d.placeholder then return d end end
    local e = ns.CatalogById and ns.CatalogById(id)
    local nm = e and e.name
    for _, d in ipairs(tiles) do if d.combatTile and nm and (d.catName == nm or d.skillName == ns.CatalogDisplayName(e)) then return d end end
    for _, d in ipairs(tiles) do if d.id == id then return d end end
  end
  return nil
end

function UI:OpenFromDrop(target, drop)
  if ns.InCombat and ns.InCombat() then
    ns.AfterCombat("openfromdrop", function() UI:OpenFromDrop(target) end)
    ns.Print(Tr["en combat : la fenêtre s'ouvrira à la fin du combat."])
    return "queued"
  end
  if self._openingFromDrop then return "busy" end
  self._openingFromDrop = true
  -- v2.8.4 : la vue OSRS est forcée, le drop cliqué se ferme (son OnUpdate
  -- de fondu s'arrête) et la tuile est choisie APRÈS l'ouverture.
  if not ns.db then initDBSafe() end
  ns.db.ui = ns.db.ui or {}
  ns.db.ui.osrsView = true
  if drop then SafeStep("fermer le drop", self.DismissDrop, self, drop) end
  local d
  local function selectIt()
    d = UI:DropTargetData(target)
    if d and UI.embed and UI.embed:IsShown() then SafeStep("sélection depuis un drop", UI.SelectTile, UI, d) end
    UI.lastDropOpen = d and (d.name or d.id) or "?"
  end
  local ok, opened = pcall(self.OpenSkillTab, self, selectIt)
  self._openingFromDrop = nil
  if not ok then SafeStep("ouverture depuis un drop", error, opened) return "error" end
  if opened == "waiting" then return "waiting" end
  return opened and "opened" or "none", d
end

-- Cadres de l'addon dont un OnUpdate tourne encore (doit être vide au repos).
function UI:ActiveOnUpdates()
  local out = {}
  local function chk(f, label)
    if type(f) == "table" and f.GetScript then
      local ok, s = pcall(f.GetScript, f, "OnUpdate")
      if ok and s then out[#out + 1] = label end
    end
  end
  for name, f in pairs(self.timers or {}) do chk(f, "minuterie " .. name) end
  for i, f in ipairs(self.dropsActive or {}) do if f:IsShown() then chk(f, "drop " .. i) end end
  chk(self._hitTicker, "hitdebug")
  return out
end

function UI:SetDropsMouse(on)
  for _, f in ipairs(self.dropsActive or {}) do
    if not f._editPreview and f.EnableMouse then pcall(f.EnableMouse, f, on and true or false) end
  end
end

-- Petite impulsion d'échelle sur le titre quand un drop cumule (AnimationGroup,
-- seulement pendant l'animation ; repli silencieux si l'API manque).
function UI:BumpDropTitle(f)
  local fs = f and f.titleFS
  if not fs or not fs.CreateAnimationGroup then f._bumps = (f._bumps or 0) + 1 return end
  if not f._bumpAG then
    local okA, ag = pcall(fs.CreateAnimationGroup, fs)
    if okA and ag then
      local okS, sc = pcall(ag.CreateAnimation, ag, "Scale")
      if okS and sc then
        if sc.SetScale then pcall(sc.SetScale, sc, 1.12, 1.12) end
        if sc.SetScaleFrom then pcall(sc.SetScaleFrom, sc, 1, 1) pcall(sc.SetScaleTo, sc, 1.12, 1.12) end
        if sc.SetDuration then pcall(sc.SetDuration, sc, 0.12) end
        if sc.SetOrigin then pcall(sc.SetOrigin, sc, "LEFT", 0, 0) end
      end
      if ag.SetLooping then pcall(ag.SetLooping, ag, "BOUNCE") end
      f._bumpAG = ag
    end
  end
  local ag = f._bumpAG
  if ag then
    pcall(ag.Stop, ag)
    if ag.SetLooping then pcall(ag.SetLooping, ag, "NONE") end
    pcall(ag.Play, ag)
  end
  f._bumps = (f._bumps or 0) + 1
end

function UI:SpawnDrop(iconPath, title, subtitle, barCur, barMax, rightValue, opts)
  opts = opts or {}
  if not self:DropsEnabled() and not self._inEditMode and not (opts and opts.force) then return end
  self:BuildDrops()
  local parent = self.dropsStack or self.dropsFrame or UIParent
  if not parent then return end
  self.dropsActive = self.dropsActive or {}
  -- v2.8.1 : même compétence déjà affichée → on met ce drop à jour (pas d'empilement).
  if opts.dedupeKey then
    for i = 1, #self.dropsActive do
      local o = self.dropsActive[i]
      if o and o._dedupeKey == opts.dedupeKey and o._restart then
        -- v2.8.1 : drop cumulatif tant qu'il est visible (« Dagues +1 » → « +2 »).
        local acc = opts.accumulate
        if acc and type(acc.fmt) == "function" and ns.N(acc.delta) then
          o._acc = (o._acc or 0) + acc.delta
          o._kills = (o._kills or 0) + (acc.kills or 0)
          o._quest = o._quest or acc.quest
          title = acc.fmt(o._acc, o)
          if o._light and subtitle and subtitle ~= "" then title = title .. "  |cffffffff" .. subtitle .. "|r" end
        end
        if o.titleFS and title then o.titleFS:SetText(title) end
        self:BumpDropTitle(o)
        if o.subFS and subtitle then o.subFS:SetText(subtitle) end
        if o.hintFS and opts.hint then o.hintFS:SetText(opts.hint) end
        if o.barHold and o.bar and ns.N(barMax) and ns.N(barMax) > 0 then
          pcall(SetSkillBarProgress, o.barHold, o.bar, barCur, ns.N(barMax), o._bw, 4)
        end
        o._restart()
        o._updates = (o._updates or 0) + 1
        return o
      end
    end
    -- Limite 1 / 2 s : si le drop a déjà disparu (plafond), on en recrée un seul.
  end
  -- Plafond : 5 drops visibles, le plus ancien part.
  local live = 0
  for i = 1, #self.dropsActive do if not self.dropsActive[i]._editPreview then live = live + 1 end end
  while live >= (UI.DROP_MAX or 5) do
    local idx
    for i = 1, #self.dropsActive do if not self.dropsActive[i]._editPreview then idx = i break end end
    if not idx then break end
    local o = table.remove(self.dropsActive, idx)
    if o.SetScript then pcall(o.SetScript, o, "OnUpdate", nil) end
    if o.Hide then pcall(o.Hide, o) end
    live = live - 1
  end
  local variant = opts.variant and DROP_VARIANTS[opts.variant] or nil
  local maxv = ns.N(barMax)
  local hint = opts.hint

  -- Style « Léger » : une ligne compacte icône + texte, sans barre.
  local light = opts.light or (ns.db and ns.db.ui and ns.db.ui.dropStyle == "leger")
  -- Complet : boîte compacte façon toast — icône 32 px à gauche, 3 lignes
  -- (titre or, ligne blanche, astuce verte) et fine barre en bas.
  local fh
  if light then fh = TOAST_LIGHT_H
  else
    fh = 12 + 14 + 12 + ((hint and hint ~= "") and 11 or 0) + ((maxv and maxv > 0) and 7 or 0)
    if fh < 46 then fh = 46 end
    if opts.big then fh = math.max(fh, UI.LEVELUP_H) end
  end
  local iconSize = light and 20 or (opts.big and 40 or 32)
  local f = TryCreate("Frame", nil, parent, "BackdropTemplate")
  local dw = self:DropWidth()
  f:SetSize(dw, fh)
  f._h = fh
  f._light = light and true or false
  f._variant = opts.variant
  f._kind = opts.kind
  if f.SetFrameStrata then pcall(f.SetFrameStrata, f, "HIGH") end
  ApplyRestToastChrome(f, variant and variant.border or nil)

  -- Icône nette dans un cadre fin carré.
  local slot = CreateSlotButton(f, iconSize, true)
  if light then slot:SetPoint("LEFT", f, "LEFT", 4, 0)
  else slot:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -7) end
  SetTileIcon(slot.iconTex, iconPath or ns.LEVEL_ICON or ns.FALLBACK_ICON)
  f.iconSlot, f.icon = slot, slot.iconTex

  local titleFS = Text(f, "GameFontNormal", "LEFT")
  titleFS:SetPoint("TOPLEFT", slot, "TOPRIGHT", 7, 1)
  titleFS:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  if titleFS.SetWordWrap then titleFS:SetWordWrap(false) end
  titleFS:SetText(title or "")
  local tc = (variant and variant.title) or GOLD
  titleFS:SetTextColor(tc[1], tc[2], tc[3])
  if opts.big and not light then
    if titleFS.SetFontObject and _G.GameFontNormalLarge then pcall(titleFS.SetFontObject, titleFS, _G.GameFontNormalLarge) end
    titleFS.font = "GameFontNormalLarge"
  end

  local subFS = Text(f, "GameFontHighlightSmall", "LEFT")
  subFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -2)
  subFS:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  if subFS.SetWordWrap then subFS:SetWordWrap(false) end
  subFS:SetText(subtitle or "")
  subFS:SetTextColor(1, 1, 1)

  local hintFS = Text(f, "GameFontHighlightSmall", "LEFT")
  hintFS:SetPoint("TOPLEFT", subFS, "BOTTOMLEFT", 0, -1)
  hintFS:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  if hintFS.SetWordWrap then hintFS:SetWordWrap(false) end
  hintFS:SetText(hint or "")
  hintFS:SetTextColor(0.25, 1.00, 0.25)
  if not hint or hint == "" then hintFS:Hide() end
  f.hintFS = hintFS

  if light then
    titleFS:ClearAllPoints()
    titleFS:SetPoint("LEFT", slot, "RIGHT", 6, 0)
    titleFS:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    if titleFS.SetFontObject then pcall(titleFS.SetFontObject, titleFS, "GameFontNormalSmall") end
    titleFS.font = "GameFontNormalSmall"
    if subtitle and subtitle ~= "" then titleFS:SetText((title or "") .. "  |cffffffff" .. subtitle .. "|r") end
    subFS:SetText("")
    subFS:Hide()
    hintFS:Hide()
  end

  -- Fine barre en bas, alignée sur le texte : elle commence au bord gauche
  -- du titre (jamais sous l'icône ronde) et finit au même retrait droit.
  if maxv and maxv > 0 and not light then
    local hold = CreateFrame("Frame", nil, f)
    hold:SetPoint("LEFT", titleFS, "LEFT", 0, 0)
    hold:SetPoint("RIGHT", titleFS, "RIGHT", 0, 0)
    hold:SetPoint("BOTTOM", f, "BOTTOM", 0, 6)
    local textRight = 8
    local bw = math.max(8, dw - (7 + iconSize + 7) - textRight)
    local okB, sbar = pcall(CreateFrame, "StatusBar", nil, hold)
    if not (okB and sbar) then sbar = CreateFrame("Frame", nil, hold) end
    hold._styleSkill = opts.skillId
    SetSkillBarProgress(hold, sbar, barCur, maxv, bw, 4)
    f._bw = bw
    if hold.nbBorder then hold.nbBorder:Hide() end
    if hold.barText then hold.barText:SetText("") hold.barText:Hide() end
    f.barHold, f.bar = hold, sbar
  end
  f.titleFS, f.subFS = titleFS, subFS
  self.dropsActive[#self.dropsActive + 1] = f
  self:PackDrops()
  ToastAlpha(f, 0)
  if f.Show then pcall(f.Show, f) end

  -- Aperçu d'édition : pas de fondu, on le garde visible.
  if f._editPreview then return f end

  local t = 0
  f._dedupeKey = opts.dedupeKey
  f._acc = opts.accumulate and ns.N(opts.accumulate.delta) or nil
  f._kills = opts.accumulate and opts.accumulate.kills or nil
  f._quest = opts.accumulate and opts.accumulate.quest or nil
  f._target = { kind = opts.kind, skillId = opts.skillId, skillName = opts.skillName }
  f._restart = function() if t > TOAST_FADEIN then t = TOAST_FADEIN end ToastAlpha(f, 1) end
  f._hold = ns.N(opts.hold)
  -- 3.3.16 : fermeture anticipée (fondu de sortie immédiat)
  f._dismiss = function() f._hover = nil local h = f._hold or UI:DropHold() if t < TOAST_FADEIN + h then t = TOAST_FADEIN + h end end
  -- v2.8.1 : survol = drop tenu (minuterie en pause) ; sortie = durée complète
  -- relancée ; clic gauche = onglet Comp. sur la bonne tuile ; clic droit = fermer.
  -- Jamais en mode édition (le déplacement du support reste inchangé).
  self:WireDropMouse(f)
  f:SetScript("OnUpdate", function(self, elapsed)
    if self._editPreview then
      ToastAlpha(self, 1)
      return
    end
    if self._pileHidden then
      ToastAlpha(self, 0)
      return
    end
    if self._hover then
      t = TOAST_FADEIN
      ToastAlpha(self, 1)
      return
    end
    t = t + (elapsed or 0.03)
    local a = 1
    local holdT = self._hold or UI:DropHold()   -- 3.3.16 : durée propre (récap de déconnexion)
    if t < TOAST_FADEIN then
      a = t / TOAST_FADEIN
    elseif t < TOAST_FADEIN + holdT then
      a = 1
    elseif t < TOAST_FADEIN + holdT + TOAST_FADEOUT then
      a = 1 - ((t - TOAST_FADEIN - holdT) / TOAST_FADEOUT)
    else
      self:SetScript("OnUpdate", nil)
      if self.Hide then pcall(self.Hide, self) end
      if UI.dropsActive then
        for i = #UI.dropsActive, 1, -1 do
          if UI.dropsActive[i] == self then table.remove(UI.dropsActive, i) end
        end
        UI:PackDrops()
      end
      return
    end
    ToastAlpha(self, a)
  end)
  return f
end

-- v2.8.0 : animation de montée de niveau (complète la bannière officielle, ne
-- la cache jamais) : grand drop doré dans la pile des drops, lueur de bord qui
-- pulse et éclat doré qui s'estompe (AnimationGroup Alpha / Scale, textures
-- Media/Skin). Variante légère pour les rangs de métier.
UI.LEVELUP_H = 64
UI.LEVELUP_SOUNDS = { "UI_EPICLOOT_TOAST", "UI_LEGENDARY_LOOT_TOAST", "IG_QUEST_LIST_COMPLETE" }

function UI:LevelUpSoundKit()
  local S = _G.SOUNDKIT
  if type(S) ~= "table" then return nil end
  for _, k in ipairs(UI.LEVELUP_SOUNDS) do
    local v = ns.N(S[k])
    if v then return v, k end
  end
  return nil
end

local function NewAnim(target, kind)
  if not target or type(target.CreateAnimationGroup) ~= "function" then return nil end
  local ok, ag = pcall(target.CreateAnimationGroup, target)
  if not ok or not ag then return nil end
  return ag
end

local function AddAnim(ag, kind, props)
  if not ag or type(ag.CreateAnimation) ~= "function" then return nil end
  local ok, a = pcall(ag.CreateAnimation, ag, kind)
  if not ok or not a then return nil end
  for k, v in pairs(props) do
    local fn = a[k]
    if type(fn) == "function" then
      if type(v) == "table" then pcall(fn, a, unpack(v)) else pcall(fn, a, v) end
    end
  end
  return a
end

-- Effets sur un drop : lueur de bord (pulse ×2) + éclat doré (grossit, s'estompe).
function UI:AttachFlareFx(f, strong)
  if not f or not f.CreateTexture then return nil end
  local F = ns.Style.FLARE
  local fx = CreateFrame("Frame", nil, f)
  fx:SetAllPoints(f)
  if fx.SetFrameLevel and f.GetFrameLevel then pcall(fx.SetFrameLevel, fx, (f:GetFrameLevel() or 1) + 2) end
  ns.Style.Nine(fx, "glow", F.glow, 64, 64, 12, 12, "OVERLAY", 1, 10)
  for _, t in pairs(fx._flare.glow) do
    if type(t) == "table" and t.SetBlendMode then pcall(t.SetBlendMode, t, "ADD") end
  end
  fx:SetAlpha(0)
  local out = { fx = fx }
  local ag = NewAnim(fx)
  if ag then
    AddAnim(ag, "Alpha", { SetFromAlpha = 0, SetToAlpha = 1, SetDuration = 0.35, SetOrder = 1 })
    AddAnim(ag, "Alpha", { SetFromAlpha = 1, SetToAlpha = 0.25, SetDuration = 0.45, SetOrder = 2 })
    AddAnim(ag, "Alpha", { SetFromAlpha = 0.25, SetToAlpha = 1, SetDuration = 0.35, SetOrder = 3 })
    AddAnim(ag, "Alpha", { SetFromAlpha = 1, SetToAlpha = 0, SetDuration = 0.8, SetOrder = 4 })
    pcall(ag.Play, ag)
    out.glowAnim = ag
  else
    fx:SetAlpha(1)
  end
  if strong and f.iconSlot then
    local bf = CreateFrame("Frame", nil, f)
    bf:SetSize(128, 128)
    bf:SetPoint("CENTER", f.iconSlot, "CENTER", 0, 0)
    if bf.SetFrameLevel and f.GetFrameLevel then pcall(bf.SetFrameLevel, bf, (f:GetFrameLevel() or 1) + 3) end
    local bt = bf:CreateTexture(nil, "OVERLAY")
    pcall(bt.SetTexture, bt, F.burst)
    bt.texPath = F.burst
    bt:SetAllPoints(bf)
    if bt.SetBlendMode then pcall(bt.SetBlendMode, bt, "ADD") end
    local bg = NewAnim(bf)
    if bg then
      local sc = AddAnim(bg, "Scale", { SetDuration = 1.2, SetOrder = 1 })
      if sc then
        if type(sc.SetScaleFrom) == "function" and type(sc.SetScaleTo) == "function" then
          pcall(sc.SetScaleFrom, sc, 0.5, 0.5) pcall(sc.SetScaleTo, sc, 1.4, 1.4)
        elseif type(sc.SetScale) == "function" then
          pcall(sc.SetScale, sc, 1.6, 1.6)
        end
      end
      AddAnim(bg, "Alpha", { SetFromAlpha = 0.95, SetToAlpha = 0, SetDuration = 1.2, SetOrder = 1 })
      if bg.SetScript then pcall(bg.SetScript, bg, "OnFinished", function() bf:Hide() end) end
      pcall(bg.Play, bg)
      out.burstAnim = bg
    else
      bf:Hide()
    end
    out.burst = bf
  end
  f._fx = out
  return out
end

function UI:LevelTotalLine()
  local snap = self.snapshot
  local total = snap and ns.N(snap.total or snap.ficTotal)
  if total then return Tr["Niveau total : "] .. tostring(total + 1) .. " (+1)" end
  return Tr["Niveau total : +1"]
end

function UI:PlayLevelUp(level)
  level = ns.N(level) or ns.GetPlayerLevel()
  self._pendingLevelPulse = true
  if not ns.Opt("levelUpAnim") then return nil end
  local f = self:SpawnDrop(ns.LEVEL_ICON, Tr["Niveau "] .. tostring(level) .. Tr[" atteint !"], self:LevelTotalLine(), nil, nil, nil,
    { kind = "levelup", variant = "gold", big = true })
  if f then
    self:AttachFlareFx(f, true)
    if ns.SoundOk("levelUpSound") and type(PlaySound) == "function" then
      local kit = self:LevelUpSoundKit()
      if kit then pcall(PlaySound, kit) end
      self._lastLevelUpSound = kit or "aucun kit"
    end
  end
  self:PulseLevelTile()
  -- 3.5.4 : niveaux pairs = nouveaux sorts chez le maître de classe (notif sous le level-up + son)
  if f and level and level >= 2 and level % 2 == 0 then
    local ui = self
    local function spellToast()
      local g = ui:SpawnDrop("Interface\\Icons\\INV_Misc_Book_09", Tr["Nouveaux sorts"], Tr["Va voir ton maître de classe"], nil, nil, nil,
        { kind = "spells", variant = "gold", light = true })
      if g and ns.SoundOk("levelUpSound") and type(PlaySound) == "function" then
        local kit = (type(SOUNDKIT) == "table" and SOUNDKIT.IG_QUEST_LOG_OPEN) or 844
        pcall(PlaySound, kit)
      end
    end
    if type(C_Timer) == "table" and C_Timer.After then C_Timer.After(1.5, spellToast) else spellToast() end
  end
  return f
end

-- Variante légère : nouveau rang apprenable / rang obtenu (métiers).
function UI:PlayRankMilestone(d, text, sub)
  if not ns.Opt("levelUpAnim") then return nil end
  local f = self:SpawnDrop(d and d.icon, text, sub, nil, nil, nil, { kind = "rankup", variant = "gold", light = true, skillId = d and d.id })
  if f then self:AttachFlareFx(f, false) end
  return f
end

-- Tuile Niveau : une pulsation dorée à la prochaine ouverture de l'onglet.
function UI:PulseLevelTile()
  if not self._pendingLevelPulse then return false end
  if not (self.embed and self.embed.IsShown and self.embed:IsShown()) then return false end
  local tile
  for _, t in ipairs((self.embed and self.embed.tiles) or {}) do if t.data and t.data.kind == "level" then tile = t break end end
  if not tile then return false end
  self._pendingLevelPulse = false
  local F = ns.Style.FLARE
  if not tile._pulse then
    local pf = CreateFrame("Frame", nil, tile)
    pf:SetAllPoints(tile)
    ns.Style.Nine(pf, "glow", F.glow, 64, 64, 12, 10, "OVERLAY", 2, 4)
    for _, t in pairs(pf._flare.glow) do if type(t) == "table" and t.SetBlendMode then pcall(t.SetBlendMode, t, "ADD") end end
    pf:SetAlpha(0)
    local ag = NewAnim(pf)
    if ag then
      AddAnim(ag, "Alpha", { SetFromAlpha = 0, SetToAlpha = 1, SetDuration = 0.4, SetOrder = 1 })
      AddAnim(ag, "Alpha", { SetFromAlpha = 1, SetToAlpha = 0, SetDuration = 0.9, SetOrder = 2 })
    end
    tile._pulse = { frame = pf, anim = ag }
  end
  local p = tile._pulse
  if p.anim then pcall(p.anim.Stop, p.anim) pcall(p.anim.Play, p.anim) end
  tile._pulseCount = (tile._pulseCount or 0) + 1
  return true
end

-- Ancienne barre d'XP séparée (v2.3) : tout est maintenant dans le toast.
function UI:ShowXPBar(cur, maxxp, level)
  -- Conservé comme no-op pour compatibilité ; le toast XP porte déjà la barre.
end

-- v2.8.1 : XP cumulée sur un seul drop tant qu'il est visible :
-- « +40 XP » → « +125 XP (3 monstres) » ; XP de quête : « (quête) ».
function UI.XPTitle(n, o)
  local k = o and o._kills or 0
  local parts = {}
  if k >= 2 then parts[#parts + 1] = tostring(k) .. Tr[" monstres"] end
  if o and o._quest then parts[#parts + 1] = Tr["quête"] end
  return "+" .. tostring(n) .. " XP" .. ((#parts > 0) and (" (" .. table.concat(parts, ", ") .. ")") or "")
end

local function Deformat(fmt)
  if type(fmt) ~= "string" then return nil end
  local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".-"):gsub("%%%%d", "%%d+")
  return "^" .. p
end
-- Source de la prochaine hausse d'XP : message de combat (monstre tué) ou
-- message système (quête, exploration). Valable 2 s.
function UI:NoteXPMessage(event, msg)
  if type(msg) ~= "string" or (ns.IsSecret and ns.IsSecret(msg)) then return end
  local kind
  if event == "CHAT_MSG_COMBAT_XP_GAIN" then
    local kp = Deformat(_G.COMBATLOG_XPGAIN_FIRSTPERSON) or Deformat(_G.COMBATLOG_XPGAIN_FIRSTPERSON_GROUP)
    if kp and msg:find(kp) then kind = "kill"
    elseif msg:find("meurt") or msg:find("dies") then kind = "kill"
    else kind = "other" end
  elseif event == "CHAT_MSG_SYSTEM" then
    local qp = Deformat(_G.ERR_QUEST_REWARD_EXP_I)
    if (qp and msg:find(qp)) or msg:find("Expérience gagnée") or msg:find("Experience gained") then kind = "quest" end
  end
  if kind then
    local now = (type(GetTime) == "function" and GetTime()) or 0
    local lu = self._lastXPUnknown
    if lu and now - (lu.at or 0) <= 0.5 and lu.f and lu.f.titleFS then
      self._lastXPUnknown = nil
      if kind ~= "kill" then
        lu.f._kills = math.max(0, (lu.f._kills or 1) - 1)
        if kind == "quest" then lu.f._quest = true end
        lu.f.titleFS:SetText(UI.XPTitle(lu.f._acc or 0, lu.f))
      end
      return
    end
    self._xpSrc = { kind = kind, at = now }
  end
end
function UI:TakeXPSource()
  local s = self._xpSrc
  self._xpSrc = nil
  if not s then return nil end
  local now = (type(GetTime) == "function" and GetTime()) or 0
  if now - (s.at or 0) > 2 then return nil end
  return s.kind
end

function UI:OnXPUpdate()
  local cur, maxxp = ns.GetPlayerXPSafe()
  local level = ns.GetPlayerLevel()
  -- Valeurs secrètes (combat) : on attend la prochaine lecture lisible.
  if not cur or not maxxp then return end
  if not self._xpSeeded then
    self._prevXP, self._prevXPMax, self._prevLevel = cur, maxxp, level
    self._xpSeeded = true
    return
  end
  local delta = cur - (self._prevXP or 0)
  if delta < 0 then
    delta = ((self._prevXPMax or 0) - (self._prevXP or 0)) + cur
  end
  self._prevXP, self._prevXPMax, self._prevLevel = cur, maxxp, level
  if delta > 0 then
    local book = ns.LEVEL_ICON or "Interface\\Icons\\INV_Misc_Book_11"
    maxxp = ns.N(maxxp) or 0
    cur = ns.N(cur) or 0
    local pct = (maxxp > 0) and (cur / maxxp * 100) or 0
    local sub = string.format(Tr["Niveau %s · %.0f %%"], tostring(level or 0), pct)
    self._sessionXP = (self._sessionXP or 0) + delta
    ns.Rate.Note("xp", self._sessionXP)
    local hint = self:XPHint(cur, maxxp, level)
    if ns.Opt("xpDrops") then
      local src = self:TakeXPSource()
      local acc = { delta = delta, kills = (src ~= "quest" and src ~= "other") and 1 or 0, quest = (src == "quest"), fmt = UI.XPTitle }
      local xf = self:SpawnDrop(book, UI.XPTitle(delta, { _kills = acc.kills, _quest = acc.quest }), sub, cur, maxxp, nil,
        { kind = "xp", hint = hint, dedupeKey = "xp", accumulate = acc })
      -- Message arrivé APRÈS la hausse : reclassé juste après (0,5 s).
      self._lastXPUnknown = (src == nil and xf) and { f = xf, at = (type(GetTime) == "function" and GetTime()) or 0 } or nil
    end
  end
end

-- v2.8.1 : anti-déluge. Un drop de compétence ne part QUE si le rang monte par
-- rapport à une valeur déjà connue (cache persistant fusionné dans la lecture) ;
-- première apparition / réapparition = amorçage silencieux ; jamais « +rang
-- complet » ; plus de 3 compétences nouvelles ou en hausse d'un coup = relecture
-- (silence) ; 1 drop max par compétence toutes les 2 s (sinon mise à jour du
-- drop visible) ; 5 drops visibles au plus.
UI.DROP_MAX = 5
UI.DROP_RATE = 2
UI.RESEED_BURST = 3
local function Now()
  if type(GetTime) == "function" then local ok, v = pcall(GetTime) if ok and ns.N(v) then return v end end
  return (type(time) == "function" and time()) or 0
end
function UI:FlushSkillDiff()
  self._skillDiffPending = false
  if not ns.SkillRankSnapshot then return end
  -- 3.5.21 : on compare aussi en combat (rangs lisibles). Si des rangs
  -- restent secrets, MergeRankCache / la garde « rang 0 » conservent la
  -- dernière valeur ; un second passage a lieu à PLAYER_REGEN_ENABLED.
  if ns.InCombat and ns.InCombat() then self.dirty = true self._skillDiffAfterCombat = true end
  local now = ns.SkillRankSnapshot()
  -- Rang illisible (0 / nil) : on garde la dernière valeur connue.
  if self._prevSkills then
    for fold, s in pairs(now) do
      local p = self._prevSkills[fold]
      if (ns.N(s.rank) or 0) <= 0 and p and (ns.N(p.rank) or 0) > 0 then now[fold] = p end
    end
  end
  local prev = self._prevSkills
  if not self._skillSeeded or not prev then
    self._prevSkills = now
    self._skillSeeded = true
    return
  end
  local rises, fresh = {}, 0
  for fold, s in pairs(now) do
    local p = prev[fold]
    local cr = ns.N(s.rank) or 0
    if not p then
      fresh = fresh + 1
    else
      local pr = ns.N(p.rank)
      if pr and pr > 0 and cr > pr then rises[#rises + 1] = { fold = fold, s = s, pr = pr, cr = cr } end
    end
  end
  -- Une compétence absente de cette lecture garde sa valeur précédente.
  for fold, p in pairs(prev) do
    if not now[fold] then now[fold] = p end
  end
  self._prevSkills = now
  if fresh > UI.RESEED_BURST or #rises > UI.RESEED_BURST then
    self._reseeds = (self._reseeds or 0) + 1
    rises = {}
  end
  self._dropLast = self._dropLast or {}
  local t = Now()
  for _, r in ipairs(rises) do
    local s, pr, cr, fold = r.s, r.pr, r.cr, r.fold
    local d = cr - pr
    if d > 0 and d < cr then
      local icon, skillId = self:SkillDropIcon(s.name, s.headerName, s.skillID)
      ns.Rate.Note("skill:" .. tostring(skillId or fold), cr)
      local title = (s.name or "") .. " +" .. tostring(d)
      local maxS = ns.N(s.max) or 0
      local subS = (maxS > 0) and (Tr["Rang "] .. tostring(cr) .. " / " .. tostring(maxS)) or (Tr["Rang "] .. tostring(cr))
      local hintS = self:SkillHint(skillId or fold, skillId, cr, maxS)
      local last = self._dropLast[fold]
      local limited = last and (t - last) >= 0 and (t - last) < UI.DROP_RATE
      if ns.Opt("skillDrops") then
        local nm = s.name or ""
        local f = self:SpawnDrop(icon, title, subS, cr, s.max, nil, { skillId = skillId, skillName = s.name, kind = "skill", hint = hintS,
          dedupeKey = "skill:" .. fold, updateOnly = limited,
          accumulate = { delta = d, fmt = function(n) return nm .. " +" .. tostring(n) end } })
        if f and not limited then self._dropLast[fold] = t end
      end
      self._skillDrops = (self._skillDrops or 0) + 1
      if ns.Dopamine and ns.Dopamine.OnRise then
        local cat = ns.LookupCatalog and ns.LookupCatalog(s.name)
        pcall(ns.Dopamine.OnRise, {
          name = s.name, id = skillId or (cat and cat.id), fold = fold,
          from = pr, to = cr, delta = d, max = maxS, kind = cat and cat.kind, icon = icon,
        })
      end
    end
  end
  local okC, snap = pcall(ns.Collect)
  if okC and snap then
    self.snapshot = snap
    self._snapVersion = (self._snapVersion or 0) + 1
    SafeStep("objectifs / paliers", self.CheckMilestones, self, snap)
  end
end

-- Ligne verte des drops : objectif > rythme mesuré > palier suivant.
function UI:SkillHint(rateKey, skillId, cur, maxv)
  local g = skillId and ns.GetGoal(skillId)
  if g and g.rank > cur then
    local eta = ns.FormatDuration(ns.Rate.ETA("skill:" .. tostring(rateKey), cur, g.rank))
    return string.format(Tr["Objectif %s : encore %s"], tostring(g.rank), tostring(g.rank - cur)) .. (eta and (" (" .. eta .. ")") or "")
  end
  local spu = ns.Rate.SecondsPerUnit("skill:" .. tostring(rateKey))
  if spu then return ns.FormatDuration(spu) .. Tr[" par rang (mesuré)"] end
  if maxv and maxv > cur then return string.format(Tr["Palier %s : encore %s"], tostring(maxv), tostring(maxv - cur)) end
  if maxv and maxv > 0 and cur >= maxv then return Tr["Palier atteint"] end
  return nil
end

function UI:XPHint(cur, maxxp, level)
  cur, maxxp = ns.N(cur) or 0, ns.N(maxxp) or 0
  if maxxp <= 0 then return nil end
  local left = maxxp - cur
  local nextL = (ns.N(level) or 0) + 1
  local spu = ns.Rate.SecondsPerUnit("xp")
  if spu then return string.format(Tr["Niveau %s dans %s"], tostring(nextL), tostring(ns.FormatDuration(spu * left))) end
  return string.format(Tr["Encore %s XP avant le niveau %s"], tostring(left), tostring(nextL))
end

-- Icône d'un drop de compétence = exactement celle de la tuile de la grille.
function UI:SkillDropIcon(name, header, skillLine)
  local want = ns.Fold(name or "")
  local snap = self.snapshot
  if not snap then
    local okC, s2 = pcall(ns.Collect)
    if okC then snap = s2 self.snapshot = s2 end
  end
  for _, list in ipairs({ snap and snap.tiles or {}, snap and snap.allTiles or {} }) do
    for i = 1, #list do
      local d = list[i]
      if ns.Fold(d.skillName or "") == want or ns.Fold(d.name or "") == want then
        if d.icon and not (ns.IconMissing and ns.IconMissing(d.icon)) then return d.icon, d.id end
      end
    end
  end
  local ce = ns.LookupCatalog and ns.LookupCatalog(name)   -- 3.5.19 : nom FR ou EN → même case
  for _, list in ipairs({ snap and snap.tiles or {}, snap and snap.allTiles or {} }) do
    for i = 1, #list do
      local d = list[i]
      if ce and ce.id and d.id == ce.id and d.icon and not (ns.IconMissing and ns.IconMissing(d.icon)) then return d.icon, d.id end
    end
  end
  -- 3.5.18 : catalogue (noms exacts Forever : « Masse »…), ligne de compétence,
  -- icône générique d'arme ; « ? » seulement pour une compétence inconnue hors armes
  local icon, id = ns.ResolveSkillIcon(name, header, skillLine)
  if icon then return icon, id end
  return ns.FALLBACK_ICON, nil
end

-- « Votre compétence en Dépeçage est maintenant de 162. » → nom, rang.
function UI:ParseSkillMessage(msg)
  if type(msg) ~= "string" then return nil end
  -- 3.5.19 : modèle du client (ERR_SKILL_UP_SI) d'abord, quelle que soit la langue
  if ns.MatchGlobal then
    local n0, r0 = ns.MatchGlobal("ERR_SKILL_UP_SI", msg)
    if n0 and ns.N(r0) then return n0, ns.N(r0) end
  end
  local okM, name, rank = pcall(string.match, msg, "en (.-) est maintenant de (%d+)")
  if okM and name then return name, ns.N(rank) end
  okM, name, rank = pcall(string.match, msg, "Your skill in (.-) has increased to (%d+)")
  if okM and name then return name, ns.N(rank) end
  return nil
end

function UI:OnSkillDiff()
  if self._skillDiffPending then return end
  self._skillDiffPending = true
  local holder = self:TimerFrame("skilldiff")
  if not holder or not holder.SetScript then
    self:FlushSkillDiff()
    return
  end
  holder._osrsSkillAcc = 0
  holder:SetScript("OnUpdate", function(f, elapsed)
    f._osrsSkillAcc = (f._osrsSkillAcc or 0) + (elapsed or 0.05)
    if f._osrsSkillAcc < 0.12 then return end
    f._osrsSkillAcc = 0
    f:SetScript("OnUpdate", nil)   -- un seul passage, puis inactif
    UI:FlushSkillDiff()
  end)
end

function UI:SeedDrops()
  local cur, maxxp = ns.GetPlayerXPSafe()
  if cur and maxxp then
    self._prevXP, self._prevXPMax = cur, maxxp
    self._prevLevel = ns.GetPlayerLevel()
    self._xpSeeded = true
  end
  if ns.SkillRankSnapshot then
    self._prevSkills = ns.SkillRankSnapshot()
    self._skillSeeded = true
  end
end

-- Mode édition Forever (EditModeManagerFrame / LibEditMode) -----------------
function UI:ProbeEditMode()
  local r = self.editModeProbe or {}
  self.editModeProbe = r
  r.hasManager = type(_G.EditModeManagerFrame) == "table"
  r.hasCEditMode = type(_G.C_EditMode) == "table"
  r.hasEventRegistry = type(_G.EventRegistry) == "table" and type(_G.EventRegistry.RegisterCallback) == "function"
  r.libName, r.lib = nil, nil
  if type(_G.LibStub) == "function" then
    local names = { "LibEditMode-1.0", "LibEditMode" }
    for i = 1, #names do
      local ok, lib = pcall(_G.LibStub, names[i], true)
      if ok and lib then
        r.libName, r.lib = names[i], lib
        break
      end
    end
  end
  if not r.lib and type(_G.LibEditMode) == "table" then
    r.libName, r.lib = "LibEditMode (_G)", _G.LibEditMode
  end
  return r
end

function UI:HookEditMode()
  local r = self:ProbeEditMode()
  local function enter() UI:EnterEditMode() end
  local function exit() UI:ExitEditMode() end

  local em = _G.EditModeManagerFrame
  if type(em) == "table" and not r._managerHooked then
    r._managerHooked = true
    if em.HookScript then
      pcall(em.HookScript, em, "OnShow", enter)
      pcall(em.HookScript, em, "OnHide", exit)
    end
    r.hookHow = (r.hookHow and (r.hookHow .. " + ") or "") .. "EditModeManagerFrame OnShow/OnHide"
    if em.IsShown then
      local ok, shown = pcall(em.IsShown, em)
      if ok and shown then self:EnterEditMode() end
    end
  end

  if r.hasEventRegistry and not r._eventHooked then
    r._eventHooked = true
    pcall(_G.EventRegistry.RegisterCallback, _G.EventRegistry, "EditMode.Enter", enter)
    pcall(_G.EventRegistry.RegisterCallback, _G.EventRegistry, "EditMode.Exit", exit)
    r.hookHow = (r.hookHow and (r.hookHow .. " + ") or "") .. "EventRegistry EditMode.Enter/Exit"
  end

  if r.lib and not r._libHooked then
    r._libHooked = true
    local lib, frame = r.lib, self.dropsFrame
    if frame then
      if type(lib.AddFrame) == "function" then
        pcall(lib.AddFrame, lib, frame, enter, exit)
      elseif type(lib.RegisterFrame) == "function" then
        pcall(lib.RegisterFrame, lib, frame, Tr["Drops Niveau total"])
      elseif type(lib.RegisterAddOnFrame) == "function" then
        pcall(lib.RegisterAddOnFrame, lib, frame)
      end
    end
    r.hookHow = (r.hookHow and (r.hookHow .. " + ") or "") .. "LibEditMode (" .. tostring(r.libName) .. ")"
  end

  if not r.hookHow then r.hookHow = "aucun (repli /drop drops move)" end
  return r
end

function UI:ShowEditPreview()
  if self._editPreviewToast and self._editPreviewToast.Show then
    self._editPreviewToast._editPreview = true
    if self._editPreviewToast.EnableMouse then pcall(self._editPreviewToast.EnableMouse, self._editPreviewToast, true) end
    pcall(self._editPreviewToast.Show, self._editPreviewToast)
    if self._editPreviewToast.SetAlpha then pcall(self._editPreviewToast.SetAlpha, self._editPreviewToast, 1) end
    return
  end
  local book = ns.LEVEL_ICON or "Interface\\Icons\\INV_Misc_Book_11"
  local f = self:SpawnDrop(book, Tr["+0 XP"], Tr["Aperçu — mode édition"], 1, 1, "", { hint = Tr["Glisser pour déplacer"] })
  if f then
    f._editPreview = true
    if f.EnableMouse then pcall(f.EnableMouse, f, true) end   -- glisser l'aperçu = déplacer le support
    if f.SetAlpha then pcall(f.SetAlpha, f, 1) end
    self._editPreviewToast = f
  end
end

function UI:HideEditPreview()
  local f = self._editPreviewToast
  self._editPreviewToast = nil
  if not f then return end
  f._editPreview = nil
  if f.Hide then pcall(f.Hide, f) end
  if self.dropsActive then
    for i = #self.dropsActive, 1, -1 do
      if self.dropsActive[i] == f then table.remove(self.dropsActive, i) end
    end
    self:PackDrops()
  end
end

function UI:EnterEditMode()
  if self._inEditMode then return end
  self._inEditMode = true
  self:SetDropsMouse(false)
  self:BuildDrops()
  local f = self.dropsFrame
  if not f then return end
  if f.Show then pcall(f.Show, f) end
  if f.EnableMouse then pcall(f.EnableMouse, f, true) end
  f._osrsEditMoving = true
  if f.editOverlay then f.editOverlay:Show() end
  if f.handle then f.handle:Hide() end
  self:ShowEditPreview()
end

function UI:ExitEditMode()
  if not self._inEditMode then return end
  self._inEditMode = false
  self:SetDropsMouse(true)
  local f = self.dropsFrame
  if not f then return end
  if f.StopMovingOrSizing then pcall(f.StopMovingOrSizing, f) end
  SaveFramePos(f, "dropsPos")
  f._osrsEditMoving = false
  if f.editOverlay then f.editOverlay:Hide() end
  self:HideEditPreview()
  if f.EnableMouse then pcall(f.EnableMouse, f, f._osrsMoving and true or false) end
  if f.handle then
    if f._osrsMoving then f.handle:Show() else f.handle:Hide() end
  end
  self:ApplyDropsEnabled()
end

function UI:DebugEditModeLines()
  self:ProbeEditMode()
  local r = self.editModeProbe or {}
  local lines = {}
  lines[#lines + 1] = "  EditModeManagerFrame : " .. (r.hasManager and "présent" or "absent")
  lines[#lines + 1] = "  C_EditMode : " .. (r.hasCEditMode and "présent" or "absent")
  lines[#lines + 1] = "  LibEditMode : " .. (r.libName or "absent")
  lines[#lines + 1] = "  EventRegistry : " .. (r.hasEventRegistry and "oui" or "non")
  lines[#lines + 1] = "  Hook : " .. tostring(r.hookHow or "pas encore sondé")
  lines[#lines + 1] = "  En mode édition : " .. (self._inEditMode and "oui" or "non")
  if self._dropsTemplate then
    lines[#lines + 1] = "  Template toast retenu : " .. tostring(self._dropsTemplate)
  end
  return lines
end

-- Icône personnalisée de l'onglet Comp. (colonne d'icônes à droite) --------
local TAB_NAME_CANDIDATES = {
  "CharacterFrameTab1", "CharacterFrameTab2", "CharacterFrameTab3", "CharacterFrameTab4",
  "CharacterFrameTab5", "CharacterFrameTab6", "CharacterFrameTab7", "CharacterFrameTab8",
  "CharacterFrameTab9", "CharacterFrameTab10", "CharacterFrameTab11", "CharacterFrameTab12",
  "CharacterSkillTab", "CharacterFrameSkillTab", "CharacterSkillsTab", "CharacterFrameSkillsTab",
  "SkillFrameTab", "SkillsFrameTab", "SkillTab", "SkillsTab",
  "CharacterFrameSideTab1", "CharacterFrameSideTab2", "CharacterFrameSideTab3",
  "CharacterFrameSideTab4", "CharacterFrameSideTab5", "CharacterFrameSideTab6",
  "CharacterFrameSidebarTab1", "CharacterFrameSidebarTab2", "CharacterFrameSidebarTab3",
  "CharacterFrameSidebarTab4", "CharacterFrameSidebarTab5", "CharacterFrameSidebarTab6",
  "PaperDollSidebarTab1", "PaperDollSidebarTab2", "PaperDollSidebarTab3",
  "PaperDollSidebarTab4", "PaperDollSidebarTab5",
  "CharacterFrameCompactTab1", "CharacterFrameCompactTab2", "CharacterFrameCompactTab3",
  "CharacterWindowTab1", "CharacterWindowTab2", "CharacterWindowTab3",
  "PlayerSkillTab", "PlayerFrameSkillTab",
}

local function FrameName(f)
  if not f then return "?" end
  if f.GetName then
    local ok, n = pcall(f.GetName, f)
    if ok and type(n) == "string" and n ~= "" then return n end
  end
  return "(sans nom)"
end

local function LooksLikeSkillTab(f, name)
  name = string.lower(name or "")
  if string.find(name, "skill", 1, true) and string.find(name, "tab", 1, true) then return 3 end
  if string.find(name, "skill", 1, true) then return 2 end
  -- Attribut / OnClick vers SkillFrame
  if f.GetAttribute then
    local ok, v = pcall(f.GetAttribute, f, "frame")
    if ok and type(v) == "string" and string.find(string.lower(v), "skill", 1, true) then return 4 end
    ok, v = pcall(f.GetAttribute, f, "panel")
    if ok and type(v) == "string" and string.find(string.lower(v), "skill", 1, true) then return 4 end
  end
  return 0
end

local function CollectNamedTabs()
  local out, seen = {}, {}
  local function add(f, why)
    if type(f) ~= "table" or not f.SetScript then return end
    if seen[f] then return end
    seen[f] = true
    out[#out + 1] = { frame = f, name = FrameName(f), why = why or "" }
  end
  for i = 1, #TAB_NAME_CANDIDATES do
    local n = TAB_NAME_CANDIDATES[i]
    local ok, f = pcall(function() return _G[n] end)
    if ok and type(f) == "table" then add(f, "nom " .. n) end
  end
  -- CharacterFrame.SkillTab / .Tabs[i] / enfants.
  local cf = _G.CharacterFrame
  if type(cf) == "table" then
    if type(cf.SkillTab) == "table" then add(cf.SkillTab, "CharacterFrame.SkillTab") end
    if type(cf.SkillsTab) == "table" then add(cf.SkillsTab, "CharacterFrame.SkillsTab") end
    if type(cf.Tab2) == "table" then add(cf.Tab2, "CharacterFrame.Tab2") end
    if type(cf.Tabs) == "table" then
      for i = 1, 12 do
        if type(cf.Tabs[i]) == "table" then add(cf.Tabs[i], "CharacterFrame.Tabs[" .. i .. "]") end
      end
    end
    if cf.GetChildren then
      local kids = { pcall(cf.GetChildren, cf) }
      if kids[1] then
        for i = 2, #kids do
          local c = kids[i]
          local n = string.lower(FrameName(c))
          if string.find(n, "tab", 1, true) or string.find(n, "skill", 1, true) then
            add(c, "enfant CharacterFrame")
          end
          -- Une éventuelle colonne d'onglets latéraux.
          if c and c.GetChildren then
            local gkids = { pcall(c.GetChildren, c) }
            if gkids[1] then
              for j = 2, #gkids do
                local g = gkids[j]
                local gn = string.lower(FrameName(g))
                if string.find(gn, "tab", 1, true) or string.find(gn, "skill", 1, true) then
                  add(g, "petit-enfant CharacterFrame")
                end
              end
            end
          end
        end
      end
    end
  end
  return out
end

function UI:FindSkillTabButtons()
  local cands = CollectNamedTabs()
  table.sort(cands, function(a, b)
    return LooksLikeSkillTab(a.frame, a.name) > LooksLikeSkillTab(b.frame, b.name)
  end)
  return cands
end

function UI:DebugTabButtons()
  local lines = {}
  local cands = self:FindSkillTabButtons()
  if #cands == 0 then
    lines[#lines + 1] = "  (aucun bouton d'onglet trouvé ; ouvrir la fiche puis /drop debug)"
    return lines
  end
  for i = 1, #cands do
    local c = cands[i]
    local f = c.frame
    local typ = (f.GetObjectType and f:GetObjectType()) or "?"
    local shown = "?"
    if f.IsShown then
      local ok, v = pcall(f.IsShown, f)
      if ok then shown = v and "visible" or "caché" end
    end
    local tex = ""
    local icon = f.icon or f.Icon or f.IconTexture
    if (not icon) and f.GetNormalTexture then
      local ok, nt = pcall(f.GetNormalTexture, f)
      if ok then icon = nt end
    end
    if icon and icon.GetTexture then
      local ok, path = pcall(icon.GetTexture, icon)
      if ok and path then tex = " tex=" .. tostring(path) end
    end
    local score = LooksLikeSkillTab(f, c.name)
    lines[#lines + 1] = "  " .. typ .. " " .. c.name .. " [" .. shown .. "] score=" .. tostring(score) .. " (" .. c.why .. ")" .. tex
  end
  if self.skillTabButton then
    lines[#lines + 1] = "  → icône appliquée sur : " .. FrameName(self.skillTabButton)
  end
  return lines
end

local function TabIconTargets(btn)
  local list = {}
  if btn.icon then list[#list + 1] = btn.icon end
  if btn.Icon then list[#list + 1] = btn.Icon end
  if btn.IconTexture then list[#list + 1] = btn.IconTexture end
  if btn.texture then list[#list + 1] = btn.texture end
  if btn.GetNormalTexture then
    local ok, nt = pcall(btn.GetNormalTexture, btn)
    if ok and nt then list[#list + 1] = nt end
  end
  return list
end

local function SaveTabOriginal(btn)
  if NF(btn).OrigSaved then return end
  NF(btn).OrigSaved = true
  if btn.GetNormalTexture then
    local ok, nt = pcall(btn.GetNormalTexture, btn)
    if ok and nt and nt.GetTexture then
      local ok2, path = pcall(nt.GetTexture, nt)
      if ok2 then NF(btn).OrigNormalPath = path end
    end
  end
  local icon = btn.icon or btn.Icon or btn.IconTexture
  if icon and icon.GetTexture then
    local ok, path = pcall(icon.GetTexture, icon)
    if ok then NF(btn).OrigIconPath = path end
  end
end

local function TexturePathOf(obj)
  if obj and obj.GetTexture then
    local ok, path = pcall(obj.GetTexture, obj)
    if ok then return path end
  end
  return nil
end

local function PathLooksLikeCustom(path)
  if type(path) ~= "string" then return false end
  local fold = string.lower(path):gsub("/", "\\")
  -- 3.5.20 : SkillsTab (fiole en jeu) ou Dropamine-Icon (liste d'addons / minicarte)
  return (string.find(fold, "skillstab", 1, true) or string.find(fold, "dropamine-icon", 1, true)) and true or false
end

local function ApplyTextureToTab(btn, path)
  local okAny = false
  if btn.SetNormalTexture then
    if pcall(btn.SetNormalTexture, btn, path) then okAny = true end
  end
  local targets = TabIconTargets(btn)
  for i = 1, #targets do
    local tex = targets[i]
    if tex and tex.SetTexture and pcall(tex.SetTexture, tex, path) then
      okAny = true
    end
  end
  -- Vérifier que le client a bien chargé notre TGA ; sinon on considère un échec.
  local loaded = false
  if btn.GetNormalTexture then
    local ok, nt = pcall(btn.GetNormalTexture, btn)
    if ok and PathLooksLikeCustom(TexturePathOf(nt)) then loaded = true end
  end
  for i = 1, #targets do
    if PathLooksLikeCustom(TexturePathOf(targets[i])) then loaded = true end
  end
  -- Sur certains clients GetTexture ne renvoie pas le chemin : on fait confiance à Set* si ça n'a pas planté.
  if okAny and loaded then return true, true end
  if okAny then return true, false end
  return false, false
end

local function RestoreTabOriginal(btn)
  if not btn then return end
  if NF(btn).OrigNormalPath and btn.SetNormalTexture then
    pcall(btn.SetNormalTexture, btn, NF(btn).OrigNormalPath)
  end
  local icon = btn.icon or btn.Icon or btn.IconTexture
  if icon and icon.SetTexture and NF(btn).OrigIconPath then
    pcall(icon.SetTexture, icon, NF(btn).OrigIconPath)
  end
end

function UI:PickSkillTabButton()
  local cands = self:FindSkillTabButtons()
  local best, bestScore
  for i = 1, #cands do
    local sc = LooksLikeSkillTab(cands[i].frame, cands[i].name)
    if sc > 0 and (not bestScore or sc > bestScore) then
      best, bestScore = cands[i].frame, sc
    end
  end
  -- Si aucun nom ne contient « skill », on prend le 2e onglet CharacterFrameTab
  -- (souvent PaperDoll = 1, Compétences = 2 sur ce type de fiche).
  if not best then
    local t2 = _G.CharacterFrameTab2
    if type(t2) == "table" and t2.SetScript then best = t2 end
  end
  return best
end

function UI:ApplyTabIcon()
  if not ns.db then
    DropamineDB = DropamineDB or {}
    DropamineDB.ui = DropamineDB.ui or {}
    ns.db = DropamineDB
  end
  ns.db.ui = ns.db.ui or {}
  local want = (ns.db.ui.customTabIcon ~= false)
  local btn = self.skillTabButton or self:PickSkillTabButton()
  if not btn then return false end
  self.skillTabButton = btn
  SaveTabOriginal(btn)
  if not want then
    RestoreTabOriginal(btn)
    return true
  end
  local setOk, confirmed = ApplyTextureToTab(btn, CUSTOM_TAB_TEX)
  if not setOk then
    -- La texture n'a pas pu être posée : on restaure l'icône native.
    RestoreTabOriginal(btn)
    return false
  end
  -- Si GetTexture nie le chemin (fichier manquant), repli natif.
  if confirmed == false then
    local path = nil
    if btn.GetNormalTexture then
      local ok, nt = pcall(btn.GetNormalTexture, btn)
      if ok then path = TexturePathOf(nt) end
    end
    -- Beaucoup de clients renvoient nil juste après SetNormalTexture ; on ne
    -- restaure que si un chemin EST renvoyé et qu'il n'est pas le nôtre.
    if type(path) == "string" and path ~= "" and not PathLooksLikeCustom(path) then
      RestoreTabOriginal(btn)
      return false
    end
  end
  return true
end

function UI:HookCharacterFrameForTab()
  local cf = _G.CharacterFrame
  if type(cf) ~= "table" or NF(cf).TabHooked then return end
  if not cf.HookScript and not cf.SetScript then return end
  NF(cf).TabHooked = true
  local function onShow()
    UI:ApplyTabIcon()
    -- Filet de sécurité : si Comp. est déjà l'onglet actif à l'ouverture.
    local sf = UI.skillFrame or UI:FindSkillFrame()
    if sf and sf.IsShown then
      local ok, shown = pcall(sf.IsShown, sf)
      if ok and shown then SafeStep("ouverture fiche", UI.ApplyView, UI) end
    end
  end
  if cf.HookScript then pcall(cf.HookScript, cf, "OnShow", onShow)
  elseif cf.SetScript then pcall(cf.SetScript, cf, "OnShow", onShow) end
end

function UI:Init()
  if ns.Style then ns.Style.SectionBorderHook = function(f) return UI:ApplyDropFinish(f, true) end end
  if self.ready then return end
  if not ns.db then initDBSafe() end
  -- On ne construit la fenêtre de secours qu'à la demande (/drop).
  -- Le hook de SkillFrame est tenté tout de suite, et re-tenté à l'ouverture.
  -- Le hook de l'onglet Comp. passe en premier : rien d'autre ne doit le bloquer.
  SafeStep("onglet Comp.", self.HookSkillFrame, self)
  SafeStep("minicarte", self.BuildMinimap, self)
  SafeStep("onglet (hook)", self.HookCharacterFrameForTab, self)
  SafeStep("icône d'onglet", self.ApplyTabIcon, self)
  SafeStep("drops", self.BuildDrops, self)
  SafeStep("drops (activation)", self.ApplyDropsEnabled, self)
  SafeStep("drops (état initial)", self.SeedDrops, self)
  SafeStep("mode édition", self.HookEditMode, self)
  self.ready = true
  SafeStep("rafraîchissement", self.Refresh, self, true)
end

-- 3.0.0 : outils partagés avec View.lua (vue OSRS réécrite).
UI._H = {
  Text = Text, FillTexture = FillTexture, TrySetTex = TrySetTex, SetFontSafe = SetFontSafe,
  SafeStep = SafeStep, IsOwnFrame = IsOwnFrame, SizeOf = SizeOf, SetTileIcon = SetTileIcon,
  DisplayNumber = DisplayNumber, ApplyNumberColor = ApplyNumberColor, NF = NF,
  NativeVeil = NativeVeil, GOLD = GOLD, GREEN = GREEN, RectOf = RectOf, IsDescendantOf = IsDescendantOf,
  GROUP_OF = GROUP_OF, IsCollapseWidget = IsCollapseWidget, HasContent = HasContent,
}

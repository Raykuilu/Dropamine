-- Dropamine v2.8.2 — apparence native, lecture seule.
-- 1) Relevé du « bouton d'en-tête » natif du panneau de droite (Adversaire de
--    niveau égal / Contre les boss de raid / Récompenses au rang N) : textures,
--    atlas, coordonnées et géométrie relative, recopiés sur NOS cadres.
-- 2) Lecture des lignes du détail natif (chances de toucher, critique, coups
--    déviés…) quand le natif affiche une compétence : texte LU tel quel, jamais
--    calculé ; mémorisé par compétence pour l'afficher dans notre panneau.
-- Aucune écriture sur un cadre natif ; rien en combat (valeurs mémorisées).
local _, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI = ns.UI
local NL = {}
ns.NativeLook = NL

local function N(v) return ns.N and ns.N(v) or (type(v) == "number" and v or nil) end
local function Secret(v) return ns.IsSecret and ns.IsSecret(v) end
local function Fold(s) return ns.Fold and ns.Fold(s or "") or string.lower(s or "") end
local function ObjType(o)
  if type(o) ~= "table" or not o.GetObjectType then return nil end
  local ok, t = pcall(o.GetObjectType, o)
  return ok and t or nil
end
local function Own(o)
  if type(o) ~= "table" then return false end
  if UI and (o == UI.embed or o == UI.ownDetail or o == UI.viewToggle) then return true end
  local n = o.GetName and o:GetName()
  return type(n) == "string" and string.find(n, "Dropamine", 1, true) == 1
end
local function Rect(o)
  if not o or not o.GetLeft or not o.GetRight or not o.GetTop or not o.GetBottom then return nil end
  local ok1, l = pcall(o.GetLeft, o) local ok2, r = pcall(o.GetRight, o)
  local ok3, t = pcall(o.GetTop, o) local ok4, b = pcall(o.GetBottom, o)
  l, r, t, b = ok1 and N(l), ok2 and N(r), ok3 and N(t), ok4 and N(b)
  if l and r and t and b and r > l and t > b then return l, r, t, b end
end
local function TextOf(fs)
  if not fs or not fs.GetText then return nil end
  local ok, t = pcall(fs.GetText, fs)
  if ok and type(t) == "string" and not Secret(t) and t ~= "" then return t end
end
NL.Rect, NL.TextOf = Rect, TextOf

-- Libellés des en-têtes natifs (repères de lecture, pas des valeurs).
-- 3.6.2 : libellés anglais aussi (client EN) ; comparés en texte replié (Fold).
NL.HEADER_KEYS = { "adversaire de niveau", "contre les boss", "recompenses au rang",
  "equal level", "same level", "even level", "against raid boss", "raid boss", "rewards at rank" }
local function IsHeaderText(t)
  local f = Fold(t)
  for _, k in ipairs(NL.HEADER_KEYS) do if string.find(f, k, 1, true) then return true end end
  return false
end
NL.IsHeaderText = IsHeaderText

local function Walk(root, fn, depth, seen)
  depth, seen = depth or 0, seen or {}
  if type(root) ~= "table" or depth > 7 or seen[root] or Own(root) then return end
  seen[root] = true
  if root.GetRegions then
    local regs = { pcall(root.GetRegions, root) }
    if regs[1] then for i = 2, #regs do if type(regs[i]) == "table" then fn(regs[i], root) end end end
  end
  if root.GetChildren then
    local kids = { pcall(root.GetChildren, root) }
    if kids[1] then for i = 2, #kids do Walk(kids[i], fn, depth + 1, seen) end end
  end
end
NL.Walk = Walk

local function DetailRoot()
  return UI and UI.GetDetailParent and UI:GetDetailParent() or nil
end

-- 1) Bouton d'en-tête natif -------------------------------------------------
local function Describe(region, pl, pr, pt, pb)
  local l, r, t, b = Rect(region)
  if not l then return nil end
  local d = { dl = l - pl, dr = r - pr, dt = t - pt, db = b - pb, w = r - l, h = t - b }
  local okA, atlas = pcall(function() return region.GetAtlas and region:GetAtlas() end)
  if okA and type(atlas) == "string" and atlas ~= "" and not Secret(atlas) then d.atlas = atlas end
  if region.GetTexture then
    local ok, p = pcall(region.GetTexture, region)
    if ok and p ~= nil and not Secret(p) then d.tex = p end
  end
  if not (d.atlas or d.tex) then return nil end
  if region.GetTexCoord then
    local tc = { pcall(region.GetTexCoord, region) }
    if tc[1] and #tc >= 9 then d.coords = { tc[2], tc[3], tc[4], tc[5], tc[6], tc[7], tc[8], tc[9] } end
  end
  if region.GetVertexColor then
    local vc = { pcall(region.GetVertexColor, region) }
    if vc[1] then d.color = { N(vc[2]) or 1, N(vc[3]) or 1, N(vc[4]) or 1, N(vc[5]) or 1 } end
  end
  if region.GetDrawLayer then
    local ok, layer, sub = pcall(region.GetDrawLayer, region)
    if ok and type(layer) == "string" then d.layer, d.sub = layer, N(sub) end
  end
  return d
end

function NL.DiscoverHeaderButton(force)
  if NL._hdrBtn and not force then return NL._hdrBtn end
  local found
  if not (ns.InCombat and ns.InCombat()) then
    local roots = { DetailRoot(), UI and UI.skillFrame }
    for _, root in ipairs(roots) do
      if found then break end
      Walk(root, function(reg, owner)
        if found or ObjType(reg) ~= "FontString" then return end
        local t = TextOf(reg)
        if not t or not IsHeaderText(t) then return end
        local pl, pr, pt, pb = Rect(owner)
        if not pl then return end
        local parts = {}
        local regs = { pcall(owner.GetRegions, owner) }
        for i = 2, #regs do
          if ObjType(regs[i]) == "Texture" then
            local d = Describe(regs[i], pl, pr, pt, pb)
            if d then parts[#parts + 1] = d end
          end
        end
        if #parts > 0 then
          found = { from = t, w = pr - pl, h = pt - pb, parts = parts }
        end
      end)
    end
  end
  local db = ns.db
  if found then
    if db then db.nativeAssets = db.nativeAssets or {} db.nativeAssets.headerButton = found end
  elseif db and db.nativeAssets and db.nativeAssets.headerButton then
    found = db.nativeAssets.headerButton
    found.cached = true
  end
  NL._hdrBtn = found
  return found
end

-- Recopie la géométrie relevée sur notre cadre (bouts fixes, milieu étiré).
function NL.ApplyHeaderButton(frame)
  local r = NL.ApplyClone(frame, NL.DiscoverHeaderButton())
  if r then frame._nlAsset = "bouton d'en-tête natif (" .. r .. ")" end
  return frame._nlAsset and r and frame._nlAsset or nil
end
function NL.ApplyClone(frame, d)
  if type(frame) ~= "table" or not frame.CreateTexture then return nil end
  frame._nlParts = frame._nlParts or {}
  for _, t in ipairs(frame._nlParts) do t:Hide() end
  if not d or not d.parts then frame._nlAsset = nil return nil end
  local sy = 1
  local okH, fh = pcall(frame.GetHeight, frame)
  fh = okH and N(fh)
  if fh and fh > 0 and d.h and d.h > 0 then sy = fh / d.h end
  for i, p in ipairs(d.parts) do
    local t = frame._nlParts[i]
    if not t then t = frame:CreateTexture(nil, p.layer or "BACKGROUND") frame._nlParts[i] = t end
    if t.SetDrawLayer and p.layer then pcall(t.SetDrawLayer, t, p.layer, p.sub or 0) end
    local okT = false
    if p.atlas and t.SetAtlas then okT = pcall(t.SetAtlas, t, p.atlas) end
    if not okT and p.tex then okT = pcall(t.SetTexture, t, p.tex) end
    if okT then
      if p.coords and t.SetTexCoord and not p.atlas then pcall(t.SetTexCoord, t, unpack(p.coords)) end
      if p.color and t.SetVertexColor then pcall(t.SetVertexColor, t, unpack(p.color)) end
      t:ClearAllPoints()
      local wide = d.w and p.w and p.w >= d.w * 0.5
      if wide then
        t:SetPoint("TOPLEFT", frame, "TOPLEFT", p.dl, p.dt * sy)
        t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", p.dr, p.db * sy)
      elseif math.abs(p.dl) <= math.abs(p.dr) then
        t:SetPoint("TOPLEFT", frame, "TOPLEFT", p.dl, p.dt * sy)
        t:SetSize(p.w, p.h * sy)
      else
        t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", p.dr, p.dt * sy)
        t:SetSize(p.w, p.h * sy)
      end
      t:Show()
    end
  end
  frame._nlAsset = tostring(d.from) .. (d.cached and ", mémorisé" or "") .. ", " .. #d.parts .. " pièces"
  return frame._nlAsset
end

-- Police d'une FontString native (objet de police si nommé, sinon fichier/taille).
function NL.FontInfo(fs)
  if type(fs) ~= "table" then return nil end
  local info = {}
  if fs.GetFontObject then
    local ok, fo = pcall(fs.GetFontObject, fs)
    if ok and type(fo) == "table" and fo.GetName then
      local okN, n = pcall(fo.GetName, fo)
      if okN and type(n) == "string" and n ~= "" then info.obj = n end
    end
  end
  if fs.GetFont then
    local ok, path, size, flags = pcall(fs.GetFont, fs)
    if ok and type(path) == "string" and not Secret(path) then info.font, info.size, info.flags = path, N(size), flags end
  end
  if fs.GetTextColor then
    local ok, r, g, b, a = pcall(fs.GetTextColor, fs)
    if ok and N(r) then info.color = { N(r), N(g) or 1, N(b) or 1, N(a) or 1 } end
  end
  if not (info.obj or info.font) then return nil end
  return info
end
function NL.ApplyFont(fs, info, withColor)
  if type(fs) ~= "table" or not info then return false end
  local done = false
  if info.obj and fs.SetFontObject and type(_G[info.obj]) == "table" then done = pcall(fs.SetFontObject, fs, _G[info.obj]) end
  if not done and info.font and info.size and fs.SetFont then done = pcall(fs.SetFont, fs, info.font, info.size, info.flags or "") end
  if done then fs.font = info.obj or fs.font end
  if withColor and info.color and fs.SetTextColor then pcall(fs.SetTextColor, fs, unpack(info.color)) end
  return done
end

local function Clone(owner)
  local pl, pr, pt, pb = Rect(owner)
  if not pl then return nil end
  local parts = {}
  local regs = { pcall(owner.GetRegions, owner) }
  for i = 2, #regs do
    if ObjType(regs[i]) == "Texture" then
      local okS, sh = pcall(regs[i].IsShown, regs[i])
      if not okS or sh then
        local d = Describe(regs[i], pl, pr, pt, pb)
        if d then parts[#parts + 1] = d end
      end
    end
  end
  return { w = pr - pl, h = pt - pb, parts = parts }
end
NL.Clone = Clone
NL.Describe = Describe

local function FindStatusBar(o, depth)
  if type(o) ~= "table" or depth > 4 then return nil end
  if ObjType(o) == "StatusBar" then return o end
  local kids = o.GetChildren and { pcall(o.GetChildren, o) } or {}
  for i = 2, #kids do local b = FindStatusBar(kids[i], depth + 1) if b then return b end end
end

-- Liste native (lecture seule) : en-tête « Compétences d'armes », ligne de
-- compétence, barre bleue (remplissage, couleur, fond, cadre), polices,
-- couleurs, surbrillance de ligne et marges.
function NL.ProbeList(force)
  if NL._list ~= nil and not force then return NL._list or nil end
  local f = UI and UI.skillFrame
  local L
  if f and not (ns.InCombat and ns.InCombat()) then
    local root = f.ScrollBox or UI.nativeLeft
    local heads = {}
    for k in pairs(ns.openHeaders or {}) do heads[k] = true end
    for _, k in ipairs(ns.collapsedHeaders or {}) do heads[k] = true end
    local known = {}
    for _, sk in ipairs(ns.CollectLiveSkills and (ns.CollectLiveSkills() or {}) or {}) do
      if sk.name and not heads[sk.name] then known[sk.name] = true end
    end
    local hdrs, rows = {}, {}
    local function scan(r)
      local seen = {}
      local dr = DetailRoot()
      if dr then seen[dr] = true end
      if UI.nativeDetail then seen[UI.nativeDetail] = true end
      Walk(r, function(reg, owner)
        if ObjType(reg) ~= "FontString" then return end
        local t = TextOf(reg)
        if not t then return end
        if heads[t] then hdrs[#hdrs + 1] = { fs = reg, owner = owner }
        elseif known[t] then rows[#rows + 1] = { fs = reg, owner = owner } end
      end, 0, seen)
    end
    scan(root)
    -- liste classique : lignes enfants directs du SkillFrame (hors détail)
    if not rows[1] and not hdrs[1] and root ~= f then scan(f) root = f end
    table.sort(rows, function(x, y) local _, _, a = Rect(x.owner) local _, _, b = Rect(y.owner) return (a or 0) > (b or 0) end)
    L = {}
    local ll = Rect(f.ScrollBox or UI.nativeLeft or root)
    local function withTex(o)
      local c = Clone(o)
      if c and #c.parts > 0 then return o, c end
      local okP, par = pcall(o.GetParent, o)
      if okP and par and par ~= root then local c2 = Clone(par) if c2 and #c2.parts > 0 then return par, c2 end end
      return o, c
    end
    if hdrs[1] then
      local o, c = withTex(hdrs[1].owner)
      L.header = c
      if c then
        c.from = TextOf(hdrs[1].fs)
        c.font = NL.FontInfo(hdrs[1].fs)
        local fl = Rect(hdrs[1].fs)
        local ol, _, ot, ob = Rect(o)
        if fl and ol then c.textLeft = fl - ol end
        -- origine native de la liste : décalage gauche/haut et largeur de l'en-tête
        local base = UI.nativeLeft or f.ScrollBox or root
        local bl, _, bt = Rect(base)
        local _, orr = Rect(o)
        if bl and ol and orr then
          L.headerInset = { left = ol - bl, top = bt - ot, width = orr - ol }
        end
        L.headerFrame = nil
        -- bouton +/- natif de l'en-tête (texture normale ; l'autre état est
        -- déduit Plus <-> Minus, comme les textures natives UI-Plus/MinusButton)
        local function ntex(btn)
          if not btn or not btn.GetNormalTexture then return nil end
          local okN, nt = pcall(btn.GetNormalTexture, btn)
          if not okN or not nt then return nil end
          local okA, at = pcall(function() return nt.GetAtlas and nt:GetAtlas() end)
          if okA and type(at) == "string" and at ~= "" then return at, true end
          local okT, p = pcall(nt.GetTexture, nt)
          if okT and type(p) == "string" and not Secret(p) then return p, false end
        end
        local tp, isAt = ntex(o)
        if not tp then
          local kids = { pcall(o.GetChildren, o) }
          for i = 2, #kids do tp, isAt = ntex(kids[i]) if tp then break end end
        end
        if tp and (string.find(tp, "Plus", 1, true) or string.find(tp, "Minus", 1, true)) then
          c.toggle = { plus = (string.gsub(tp, "Minus", "Plus")), minus = (string.gsub(tp, "Plus", "Minus")), atlas = isAt }
        end
        L.hTop, L.hBottom = ot, ob
      end
    end
    if rows[1] then
      local r = rows[1]
      local rl, rr, rt, rb = Rect(r.owner)
      L.row = { font = NL.FontInfo(r.fs), h = rt and (rt - rb) or nil }
      if rl and ll then L.pad = math.max(0, math.min(30, rl - ll)) end
      local fl = Rect(r.fs)
      if fl and rl then L.row.textLeft = fl - rl end
      -- barre de la ligne
      local okP, rowFrame = pcall(r.owner.GetParent, r.owner)
      local bar = FindStatusBar(r.owner, 0)
      if not bar and okP and rowFrame and rt then
        -- liste classique : la barre est une voisine sur la MÊME ligne
        local kids = { pcall(rowFrame.GetChildren, rowFrame) }
        for i = 2, #kids do
          local k = kids[i]
          if ObjType(k) == "StatusBar" and not Own(k) then
            local _, _, kt, kb = Rect(k)
            if kt and kt > rb and kb < rt then bar = k break end
          end
        end
      end
      if bar then
        local b = {}
        local okT, tex = pcall(bar.GetStatusBarTexture, bar)
        if okT and tex then
          local okA, at = pcall(function() return tex.GetAtlas and tex:GetAtlas() end)
          if okA and type(at) == "string" and at ~= "" then b.atlas = at end
          local okP2, p = pcall(tex.GetTexture, tex)
          if okP2 and p ~= nil and not Secret(p) then b.tex = p end
        end
        if bar.GetStatusBarColor then
          local ok, cr, cg, cb, ca = pcall(bar.GetStatusBarColor, bar)
          if ok and N(cr) then b.color = { N(cr), N(cg) or 1, N(cb) or 1, N(ca) or 1 } end
        end
        local bl, br, bt, bb = Rect(bar)
        if bl then b.h, b.w = bt - bb, br - bl end
        b.look = Clone(bar)           -- fond + cadre (textures de la barre)
        local kids = { pcall(bar.GetChildren, bar) }
        for i = 2, #kids do           -- cadre posé dans un enfant (bouton $parentBorder)
          local c = Clone(kids[i])
          if c and #c.parts > 0 then
            local cl, cr2, ct, cb2 = Rect(kids[i])
            if cl and bl then
              for _, part in ipairs(c.parts) do
                part.dl, part.dr = part.dl + (cl - bl), part.dr + (cr2 - br)
                part.dt, part.db = part.dt + (ct - bt), part.db + (cb2 - bb)
                b.look.parts[#b.look.parts + 1] = part
              end
            end
          end
          if not b.textFont then
            local regs = { pcall(kids[i].GetRegions, kids[i]) }
            for k = 2, #regs do if ObjType(regs[k]) == "FontString" then b.textFont = NL.FontInfo(regs[k]) break end end
          end
        end
        if not b.textFont then
          local regs = { pcall(bar.GetRegions, bar) }
          for k = 2, #regs do if ObjType(regs[k]) == "FontString" then b.textFont = NL.FontInfo(regs[k]) break end end
        end
        if b.look then              -- le remplissage est dessiné par notre StatusBar
          local keep = {}
          for _, part in ipairs(b.look.parts) do
            local isFill = (b.atlas and part.atlas == b.atlas) or (b.tex and part.tex == b.tex and part.layer ~= "BACKGROUND")
            if not isFill then keep[#keep + 1] = part end
          end
          b.look.parts = keep
          b.look.from = "barre native"
        end
        L.bar = b
      end
      -- surbrillance de ligne native
      local btn = r.owner
      if btn.GetHighlightTexture then
        local ok, ht = pcall(btn.GetHighlightTexture, btn)
        if ok and ht then
          local hl = {}
          local okA, at = pcall(function() return ht.GetAtlas and ht:GetAtlas() end)
          if okA and type(at) == "string" and at ~= "" then hl.atlas = at end
          local okP3, p = pcall(ht.GetTexture, ht)
          if okP3 and p ~= nil and not Secret(p) then hl.tex = p end
          local okB, bm = pcall(ht.GetBlendMode, ht)
          if okB and type(bm) == "string" then hl.blend = bm end
          local okAl, al = pcall(ht.GetAlpha, ht)
          if okAl and N(al) then hl.alpha = N(al) end
          local okC, cr, cg, cb, ca = pcall(ht.GetVertexColor, ht)
          if okC and N(cr) then hl.color = { N(cr), N(cg) or 1, N(cb) or 1, N(ca) or 1 } end
          if hl.tex or hl.atlas then L.highlight = hl end
        end
      end
      -- espacements : en-tête → première ligne, pas entre deux lignes
      if rows[2] then
        local _, _, t2 = Rect(rows[2].owner)
        if rt and t2 and rt > t2 then L.rowStep = rt - t2 end
      end
      if L.hBottom and rt and L.hBottom >= rt then L.headerGap = L.hBottom - rt end
    end
    if not (L.header or L.row) then L = nil end
  end
  local db = ns.db
  if L then
    if db then db.nativeAssets = db.nativeAssets or {} db.nativeAssets.list = L end
  elseif db and db.nativeAssets and db.nativeAssets.list then
    L = db.nativeAssets.list
    L.cached = true
  end
  NL._list = L or false
  return L
end

-- Polices / marges du détail natif, relevées par CaptureNativeDetail.
function NL.DetailFonts()
  if NL._dfonts then return NL._dfonts end
  local db = ns.db
  NL._dfonts = db and db.nativeAssets and db.nativeAssets.detailFonts or {}
  return NL._dfonts
end

-- 2) Lignes du détail natif --------------------------------------------------
-- Le natif affiche UNE compétence : on lit son titre et ses lignes, triées de
-- haut en bas, et on les range par section. Aucun chiffre n'est fabriqué.
function NL.CaptureNativeDetail()
  if ns.InCombat and ns.InCombat() then return nil end
  local root = DetailRoot()
  if not root then return nil end
  local known = {}
  for _, s in ipairs(ns.CollectLiveSkills and (ns.CollectLiveSkills() or {}) or {}) do
    if s.name then known[Fold(s.name)] = s.name end
  end
  local items = {}
  Walk(root, function(reg)
    if ObjType(reg) ~= "FontString" then return end
    local t = TextOf(reg)
    if not t then return end
    local _, _, top = Rect(reg)
    local okL, l = pcall(reg.GetLeft, reg)
    items[#items + 1] = { text = t, top = top or 0, left = okL and N(l) or 0, fs = reg }
  end)
  table.sort(items, function(a, b) if a.top ~= b.top then return a.top > b.top end return a.left < b.left end)
  local title
  for _, it in ipairs(items) do
    local k = known[Fold(it.text)]
    if k then title = k break end
  end
  if not title then return nil end
  local out = { skill = title, desc = {}, sections = {} }
  local cur
  for _, it in ipairs(items) do
    local t = it.text
    if t == title or string.match(t, "^%s*%d+%s*/%s*%d+%s*$") then
      -- titre ou texte de barre : déjà dans notre panneau
    elseif IsHeaderText(t) then
      cur = { title = t, lines = {} }
      out.sections[#out.sections + 1] = cur
    elseif cur then
      cur.lines[#cur.lines + 1] = t
    else
      out.desc[#out.desc + 1] = t
    end
  end
  -- polices et marge gauche du détail natif (rôles : titre, description, en-tête, ligne)
  local df, rootL = {}, Rect(root)
  for _, it in ipairs(items) do
    local t = it.text
    if t == title then df.title = df.title or NL.FontInfo(it.fs)
    elseif IsHeaderText(t) then
      df.header = df.header or NL.FontInfo(it.fs)
      if not df.headerH then
        local okP, own = pcall(it.fs.GetParent, it.fs)
        local _, _, ht, hb = Rect(okP and own)
        local hl, hr = Rect(okP and own)
        if ht then df.headerH, df.headerW = ht - hb, hr - hl end
      end
    elseif string.find(t, "%", 1, true) then df.line = df.line or NL.FontInfo(it.fs)
    elseif not df.desc and #t > 20 then
      df.desc = NL.FontInfo(it.fs)
      if rootL and it.left then df.descLeft = it.left - rootL end
    end
  end
  if df.title or df.desc or df.header or df.line then
    NL._dfonts = df
    if ns.db then ns.db.nativeAssets = ns.db.nativeAssets or {} ns.db.nativeAssets.detailFonts = df end
  end
  out.at = type(time) == "function" and time() or nil
  local c = ns.CharDB and ns.CharDB()
  if c then
    c.nativeDetail = c.nativeDetail or {}
    c.nativeDetail[Fold(title)] = out
  end
  NL.lastCapture = out
  return out
end

function NL.Cached(skillName)
  if type(skillName) == "table" then return NL.CachedFor(skillName) end
  local c = ns.CharDB and ns.CharDB()
  return c and c.nativeDetail and skillName and c.nativeDetail[Fold(skillName)] or nil
end

-- 3.6.2 : détail mémorisé d'une CASE. La clé de capture est le nom affiché par
-- le client (« Armes d'hast » sur un client FR) ; depuis 3.5.19 la case porte
-- un nom d'affichage qui suit la langue de l'addon (« Polearms » en EN sur un
-- client FR) : on cherche donc aussi par identifiant du catalogue.
local function CatId(name)
  local e = ns.LookupCatalog and name and ns.LookupCatalog(name)
  return e and e.id or nil
end
function NL.CachedFor(d)
  if type(d) ~= "table" then return nil end
  local c = ns.CharDB and ns.CharDB()
  local nd = c and c.nativeDetail
  if type(nd) ~= "table" then return nil end
  for _, nm in ipairs({ d.skillName, d.catName, d.name }) do
    if type(nm) == "string" and nm ~= "" and nd[Fold(nm)] then return nd[Fold(nm)] end
  end
  local id = d.id
  if not id then return nil end
  local k = c.nativeDetailIds and c.nativeDetailIds[id]
  if k and nd[k] then return nd[k] end
  for _, v in pairs(nd) do   -- anciennes captures (avant 3.6.2) : sans index
    if type(v) == "table" and (v.id == id or CatId(v.skill) == id) then return v end
  end
  return nil
end

-- 3.6.2 : chances de toucher / critique / coups déviés, en COURT -------------
-- Les valeurs sont LUES dans le texte natif (jamais calculées) ; une ligne
-- dont on ne sait pas extraire le chiffre est abandonnée (pas de phrase brute).
local function Plain(t)
  t = tostring(t or "")
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  t = t:gsub("\226\136\146", "-"):gsub("\226\128\147", "-")      -- − –
  t = t:gsub("\194\160", " "):gsub("\226\128\175", " ")            -- espaces insécables
  return t
end
local function Percents(t)
  local out = {}
  for v in string.gmatch(Plain(t), "([%+%-]?%d+[%.,]?%d*)%s*%%") do out[#out + 1] = v .. "%" end
  return out
end
NL.Percents = Percents
local function SectionKind(title)
  local f = Fold(Plain(title))
  if string.find(f, "boss", 1, true) then return "boss" end
  if string.find(f, "egal", 1, true) or string.find(f, "equal", 1, true)
    or string.find(f, "same", 1, true) or string.find(f, "even", 1, true) then return "same" end
  return nil
end
-- Texte replié (minuscules, sans accents) qui GARDE le signe moins des chiffres.
local function Low(t)
  t = Plain(t):gsub("%-(%d)", "\001%1")
  t = (ns.FoldRaw and ns.FoldRaw(t)) or string.lower(t)
  return (t:gsub("\001", "-"))
end
NL.Low = Low
local NUM = "([%+%-]?%d+[%.,]?%d*)%s*%%"
local function First(low, keys)
  local best
  for _, k in ipairs(keys) do
    local i = string.find(low, k, 1, true)
    if i and (not best or i < best) then best = i end
  end
  return best
end
-- Valeur « : -0.96% » qui SUIT le mot-clé, sans déborder sur l'autre phrase.
local function ValueAfter(low, pos, stop)
  if not pos then return nil end
  local seg = (stop and stop > pos) and string.sub(low, pos, stop - 1) or string.sub(low, pos)
  local v = string.match(seg, ":%s*" .. NUM) or string.match(seg, NUM)
  return v and (v .. "%") or nil
end
NL.HIT_KEYS = { "toucher", "chance to hit", "hit chance", "to hit" }
NL.CRIT_KEYS = { "critique", "critical", "crit" }
local function AllNums(seg)
  local out = {}
  for v in string.gmatch(seg, NUM) do out[#out + 1] = v .. "%" end
  return out
end
local function SectionValues(text)
  local low = Low(text)
  -- la phrase des coups déviés n'entre pas dans toucher / critique
  local gp = string.find(low, "devie", 1, true) or string.find(low, "glancing", 1, true)
  if gp then low = string.sub(low, 1, gp - 1) end
  local hp, cp = First(low, NL.HIT_KEYS), First(low, NL.CRIT_KEYS)
  local function stopFor(p)
    local st
    for _, q in ipairs({ hp, cp }) do if q and q > p and (not st or q < st) then st = q end end
    return st
  end
  local hit = hp and ValueAfter(low, hp, stopFor(hp)) or nil
  local crit = cp and ValueAfter(low, cp, stopFor(cp)) or nil
  -- En jeu, les segments colorés d'une phrase sont des FontStrings séparés,
  -- parfois sur plusieurs lignes : la valeur peut précéder son mot-clé une
  -- fois recollée. Repli : exactement deux valeurs dans la section → dans
  -- l'ordre des phrases (toucher puis critique, comme le volet natif).
  if (hp or cp) and not (hit and crit) then
    local v = AllNums(low)
    if #v == 2 then
      local hitFirst = not (hp and cp) or hp < cp
      if hitFirst then hit, crit = v[1], v[2] else hit, crit = v[2], v[1] end
      if not hp then hit = nil end
      if not cp then crit = nil end
    end
  end
  return hit, crit
end
local function GlanceValues(text)
  local low = Low(text)
  local gp = string.find(low, "devie", 1, true) or string.find(low, "glancing", 1, true)
  if not gp then return nil end
  local seg = string.sub(low, gp)
  local f = string.match(seg, "surviennent%s*" .. NUM) or string.match(seg, "survient%s*" .. NUM)
    or string.match(seg, "occurs?%s*" .. NUM)
  local r = string.match(seg, "reduits? de%s*" .. NUM) or string.match(seg, "reduced by%s*" .. NUM)
  if f and r then f, r = f .. "%", r .. "%"
  else
    -- segments dans le désordre : les deux seules valeurs, dans l'ordre (fréquence, réduction)
    local v = AllNums(seg)
    if #v ~= 2 then return nil end
    f, r = v[1], v[2]
  end
  return f, "-" .. r:gsub("^[%+%-]", "")
end
NL.SectionValues, NL.GlanceValues = SectionValues, GlanceValues
-- cap = { sections = { { title, lines } } } → { same = {hit, crit}, boss = {…}, glance = {freq, red} } | nil
-- 3.6.2 (retour en jeu) : chaque section est lue comme UN texte (segments
-- colorés et lignes coupées recollés), puis on cherche « toucher … : x% »,
-- « critique … : x% » et « surviennent x% … réduits de y% ».
function NL.ParseCombat(cap)
  if type(cap) ~= "table" then return nil end
  local res, any, all = {}, false, {}
  for _, s in ipairs(cap.sections or {}) do
    local text = table.concat(s.lines or {}, " ")
    all[#all + 1] = text
    local kind = SectionKind(s.title)
    if kind then
      local hit, crit = SectionValues(text)
      if hit or crit then res[kind] = { hit = hit, crit = crit } any = true end
    end
  end
  local f, r = GlanceValues(table.concat(all, " "))
  if f then res.glance = { freq = f, red = r } any = true end
  return any and res or nil
end

local function Pair(hit, crit)
  if hit and crit then
    if hit == crit then return "&", hit end
    return "/", hit .. " / " .. crit
  end
  return hit and "hit" or "crit", hit or crit
end
-- Lignes deux tons prêtes pour l'infobulle (libellés traduits).
function NL.CompactCombatLines(parsed)
  local out = {}
  if type(parsed) ~= "table" then return out end
  for _, k in ipairs({ "same", "boss" }) do
    local v = parsed[k]
    if v and (v.hit or v.crit) then
      local form, val = Pair(v.hit, v.crit)
      local who = (k == "same") and "(même niv.)" or "(boss)"
      local label = (form == "&") and ("Toucher & crit " .. who) or (form == "/") and ("Toucher / crit " .. who)
        or (form == "hit") and ("Toucher " .. who) or ("Crit " .. who)
      out[#out + 1] = NL.TwoTone(Tr[label] .. " : " .. val)
    end
  end
  local g = parsed.glance
  if g and g.freq and g.red then
    out[#out + 1] = NL.TwoTone(Tr["Coups déviés"] .. " : " .. g.freq .. " · " .. g.red .. Tr[" dégâts"])
  end
  return out
end
-- Description native mémorisée : seulement si l'addon parle la langue du
-- client (sinon une phrase française dans une infobulle anglaise, ou l'inverse).
function NL.NativeDesc(d)
  local cap = NL.CachedFor(d)
  if not (cap and cap.desc and #cap.desc > 0) then return nil end
  if ns.LangCode and ns.ClientLang and ns.LangCode() ~= ns.ClientLang() then return nil end
  return table.concat(cap.desc, "\n")
end
-- 3.6.2 : lecture SEULE du volet natif « Comp. » (fiche du personnage).
-- Depuis 3.2.0, Window.lua neutralise CaptureNativeDetail (son DetailRoot est
-- notre propre volet) : plus rien n'était lu. Ici : on parcourt les cadres
-- natifs VISIBLES, hors combat, sans rien y écrire ni y accrocher, et on ne
-- garde que la colonne de droite (celle des en-têtes natifs).
NL.ROOT_NAMES = { "SkillDetailFrame", "SkillFrame", "SkillsFrame", "CharacterSkillFrame",
  "CharacterSkillsFrame", "CharacterFrame" }
local function Visible(o)
  if type(o) ~= "table" or not o.IsVisible then return false end
  local ok, v = pcall(o.IsVisible, o)
  return ok and v and true or false
end
local function WalkVisible(root, fn, depth, seen)
  depth = depth or 0
  if type(root) ~= "table" or depth > 14 or seen[root] or Own(root) or not Visible(root) then return end
  seen[root] = true
  if root.GetRegions then
    local regs = { pcall(root.GetRegions, root) }
    if regs[1] then for i = 2, #regs do if type(regs[i]) == "table" and Visible(regs[i]) then fn(regs[i], root) end end end
  end
  if root.GetChildren then
    local kids = { pcall(root.GetChildren, root) }
    if kids[1] then for i = 2, #kids do WalkVisible(kids[i], fn, depth + 1, seen) end end
  end
end
function NL.NativeRoots()
  local out = {}
  local W = ns.Window
  for _, n in ipairs(NL.ROOT_NAMES) do
    local f = rawget(_G, n)
    if type(f) == "table" and not Own(f) and f ~= (W and W.frame) and Visible(f) then out[#out + 1] = f end
  end
  return out
end
function NL.ReadNativeDetail()
  if ns.InCombat and ns.InCombat() then return nil end
  local roots = NL.NativeRoots()
  if #roots == 0 then return nil end
  local items, seen = {}, {}
  for _, root in ipairs(roots) do
    WalkVisible(root, function(reg, owner)
      if ObjType(reg) ~= "FontString" then return end
      local t = TextOf(reg)
      if not t then return end
      local l, _, top = Rect(reg)
      if not l then return end
      items[#items + 1] = { text = t, plain = Plain(t), top = top, left = l, owner = owner }
    end, 0, seen)
  end
  -- colonne des en-têtes natifs : bord gauche du bouton d'en-tête (ou du texte)
  local colL, hdrTop
  for _, it in ipairs(items) do
    if IsHeaderText(it.plain) then
      local bl = Rect(it.owner) or it.left
      local x = math.min(bl, it.left) - 40
      colL = colL and math.min(colL, x) or x
      hdrTop = hdrTop and math.max(hdrTop, it.top) or it.top
    end
  end
  if not colL then return nil end
  local col = {}
  for _, it in ipairs(items) do if it.left >= colL then col[#col + 1] = it end end
  table.sort(col, function(a, b) if a.top ~= b.top then return a.top > b.top end return a.left < b.left end)
  local known = {}
  for _, s in ipairs(ns.CollectLiveSkills and (ns.CollectLiveSkills() or {}) or {}) do
    if s.name then known[Fold(s.name)] = s.name end
  end
  local title
  for _, it in ipairs(col) do
    if it.top > hdrTop and known[Fold(it.plain)] then title = known[Fold(it.plain)] break end
  end
  if not title then return nil end
  local out = { skill = title, desc = {}, sections = {}, src = "volet natif 3.6.2" }
  -- Sections par POSITION : un élément appartient à l'en-tête le plus bas
  -- situé au-dessus de lui (bas du bouton d'en-tête) ; au-dessus de tous les
  -- en-têtes : description. Puis rangées visuelles (même hauteur ±4 px)
  -- lues de gauche à droite : les segments colorés se recollent dans l'ordre.
  local heads = {}
  for _, it in ipairs(col) do
    if IsHeaderText(it.plain) then
      local _, _, bt, bb = Rect(it.owner)
      heads[#heads + 1] = { title = it.plain, top = bt or it.top, bottom = bb or (it.top - 14), items = {} }
    end
  end
  table.sort(heads, function(a, b) return a.top > b.top end)
  local desc = {}
  for _, it in ipairs(col) do
    local t = it.plain
    if Fold(t) == Fold(title) or IsHeaderText(t) or string.match(t, "^%s*%d+%s*/%s*%d+%s*$") then
      -- titre, en-tête ou texte de barre
    else
      local owner
      for _, h in ipairs(heads) do if it.top <= h.bottom + 2 then owner = h end end
      if owner then owner.items[#owner.items + 1] = it
      elseif it.top > hdrTop then desc[#desc + 1] = it end
    end
  end
  local function Rows(list)
    table.sort(list, function(a, b) if a.top ~= b.top then return a.top > b.top end return a.left < b.left end)
    local rows, cur, rowTop = {}, nil, nil
    for _, it in ipairs(list) do
      if not cur or math.abs(it.top - rowTop) > 4 then
        cur = {} rows[#rows + 1] = cur rowTop = it.top
      end
      cur[#cur + 1] = it
    end
    local out2 = {}
    for _, r in ipairs(rows) do
      table.sort(r, function(a, b) return a.left < b.left end)
      local parts = {}
      for _, it in ipairs(r) do parts[#parts + 1] = it.plain end
      out2[#out2 + 1] = table.concat(parts, " ")
    end
    return out2
  end
  out.desc = Rows(desc)
  for _, h in ipairs(heads) do out.sections[#out.sections + 1] = { title = h.title, lines = Rows(h.items) } end
  out.combat = NL.ParseCombat(out)
  out.id = CatId(title)
  out.at = type(time) == "function" and time() or nil
  local c = ns.CharDB and ns.CharDB()
  if c then
    c.nativeDetail = c.nativeDetail or {}
    c.nativeDetail[Fold(title)] = out
    if out.id then
      c.nativeDetailIds = c.nativeDetailIds or {}
      c.nativeDetailIds[out.id] = Fold(title)
    end
  end
  NL.lastRead = out
  return out
end
-- Au plus une lecture par intervalle ; rien si la fiche native est fermée.
NL.READ_EVERY = 1
function NL.ReadIfShown(force)
  local now = (ns.NowSec and ns.NowSec()) or (type(GetTime) == "function" and GetTime()) or 0
  if not force and NL._lastRead and (now - NL._lastRead) < NL.READ_EVERY then return nil end
  NL._lastRead = now
  local ok, r = pcall(NL.ReadNativeDetail)
  return ok and r or nil
end
-- Pilote : NOTRE cadre (aucun crochet sur le natif) ; ne fait rien tant que
-- la fiche native n'est pas visible.
if type(CreateFrame) == "function" then
  local okF, drv = pcall(CreateFrame, "Frame", "DropamineNativeReader")
  if okF and drv and drv.SetScript then
    local acc = 0
    drv:SetScript("OnUpdate", function(_, el)
      acc = acc + (tonumber(el) or 0)
      if acc < NL.READ_EVERY then return end
      acc = 0
      local cf = rawget(_G, "CharacterFrame")
      if Visible(cf) or Visible(rawget(_G, "SkillFrame")) then NL.ReadIfShown(true) end
    end)
    NL.driver = drv
  end
end

-- Le natif affiche-t-il en ce moment cette compétence ? (lecture seule)
function NL.NativeShows(skillName)
  local cap = NL.CaptureNativeDetail()
  return cap and skillName and Fold(cap.skill) == Fold(skillName) or false, cap
end

-- Ligne « Libellé : valeur » en deux tons : libellé or, valeur blanche.
function NL.TwoTone(line)
  if type(line) ~= "string" then return "" end
  if string.find(line, "|c", 1, true) then return line end
  local label, value = string.match(line, "^(.-)%s*:%s*(.+)$")
  if label and value and label ~= "" then
    return "|cffffd100" .. label .. Tr[" :|r |cffffffff"] .. value .. "|r"
  end
  return "|cffffffff" .. line .. "|r"
end

function NL.DebugLines()
  local out = {}
  local h = NL._hdrBtn or (ns.db and ns.db.nativeAssets and ns.db.nativeAssets.headerButton)
  out[#out + 1] = "En-tête natif (bouton) : " .. (h and (tostring(h.from) .. " — " .. #(h.parts or {}) .. " pièces" .. (h.cached and " (mémorisé)" or "")) or "non relevé (repli)")
  local hb = UI and UI.nativeHeader
  out[#out + 1] = "En-tête de groupe : " .. (hb and (tostring(hb.atlas or hb.tex) .. (hb.cached and " (mémorisé)" or "")) or "non relevé (repli)") .. " ; utilisé : " .. tostring(UI and UI.headerAsset)
  local sa = ns.Style and ns.Style._slotAsset
  out[#out + 1] = "Emplacement d'icône : " .. (sa and (tostring(sa.border) .. " (relevé sur " .. tostring(sa.from) .. ")") or ("repli " .. tostring(ns.Style and ns.Style.SLOT_FALLBACK.border)))
  local L = NL._list or (ns.db and ns.db.nativeAssets and ns.db.nativeAssets.list)
  if L then
    out[#out + 1] = "Liste native relevée : en-tête " .. (L.header and (tostring(L.header.from) .. " " .. string.format("%.0f×%.0f", L.header.w or 0, L.header.h or 0) .. ", " .. #(L.header.parts or {}) .. " pièces, police " .. tostring(L.header.font and (L.header.font.obj or L.header.font.font))) or "—")
      .. " ; barre " .. (L.bar and (tostring(L.bar.atlas or L.bar.tex) .. string.format(" h=%.0f", L.bar.h or 0)) or "—")
      .. " ; marge " .. tostring(L.pad) .. " ; surbrillance " .. tostring(L.highlight and (L.highlight.atlas or L.highlight.tex)) .. (L.cached and " (mémorisé)" or "")
  else
    out[#out + 1] = "Liste native : non relevée (replis)"
  end
  local df = NL.DetailFonts()
  out[#out + 1] = "Polices du détail natif : titre " .. tostring(df.title and (df.title.obj or df.title.font)) .. ", description " .. tostring(df.desc and (df.desc.obj or df.desc.font)) .. ", en-tête " .. tostring(df.header and (df.header.obj or df.header.font)) .. ", lignes " .. tostring(df.line and (df.line.obj or df.line.font))
  local c = ns.CharDB and ns.CharDB()
  local n = 0
  for _ in pairs(c and c.nativeDetail or {}) do n = n + 1 end
  out[#out + 1] = "Détails natifs lus (compétences) : " .. n
  if UI and UI.OrnamentNames then
    local o = UI:OrnamentNames()
    out[#out + 1] = "Ornements du bord gauche voilés : " .. (#o > 0 and table.concat(o, ", ") or "aucun")
  end
  return out
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = NL.DebugLines

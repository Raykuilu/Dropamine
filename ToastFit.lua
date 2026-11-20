-- Dropamine 3.6.3 : toasts — une seule ligne, défilement si trop long,
-- infobulle au survol (texte intégral + détails de recette).
-- Forever n'a pas SetClipsChildren fiable : le clip est un ScrollFrame.
local ADDON, ns = ...
local TF = ns.ToastFit or {}
ns.ToastFit = TF

TF.MQ_WAIT  = 1.2   -- pause avant le défilement (s)
TF.MQ_SPEED = 36    -- pixels / s
TF.MQ_END   = 1.0   -- pause en fin de course (s)

local function HasFn(obj, name)
  return type(obj) == "table" and type(obj[name]) == "function"
end

local function LineHeight(fs)
  if not fs then return 12 end
  if HasFn(fs, "GetLineHeight") then
    local ok, h = pcall(fs.GetLineHeight, fs)
    if ok and type(h) == "number" and h > 0 then return h end
  end
  if HasFn(fs, "GetFont") then
    local ok, _, size = pcall(fs.GetFont, fs)
    if ok and type(size) == "number" and size > 0 then return size + 2 end
  end
  if HasFn(fs, "GetHeight") then
    local ok, h = pcall(fs.GetHeight, fs)
    if ok and type(h) == "number" and h > 0 then return h end
  end
  return 12
end

local function TextWidth(fs)
  if not fs then return 0 end
  if HasFn(fs, "GetUnboundedStringWidth") then
    local ok, w = pcall(fs.GetUnboundedStringWidth, fs)
    if ok and type(w) == "number" then return w end
  end
  if HasFn(fs, "GetStringWidth") then
    local ok, w = pcall(fs.GetStringWidth, fs)
    if ok and type(w) == "number" then return w end
  end
  return 0
end

-- Place restante à droite de l'icône, à l'intérieur du toast.
-- Après clip, la FontString est dans le ScrollChild : GetLeft n'est plus
-- la colonne de texte. On mesure depuis le clip, et on rejette une valeur aberrante.
function TF.Avail(f, fs)
  if not f then return 0 end
  local rightPad = (f._light and 6) or 8
  local dw = (ns.UI and ns.UI.DropWidth and ns.UI:DropWidth()) or (f.GetWidth and f:GetWidth()) or 260
  local icon = 32
  if f.iconSlot and HasFn(f.iconSlot, "GetWidth") then
    local ok, w = pcall(f.iconSlot.GetWidth, f.iconSlot)
    if ok and type(w) == "number" and w > 0 then icon = w end
  end
  local left = (f._light and (4 + icon + 6)) or (7 + icon + 7)
  local fallback = math.max(8, (tonumber(dw) or 260) - left - rightPad)
  local probe = fs
  if fs and fs._mq and fs._mq.clip then probe = fs._mq.clip end
  if probe and HasFn(f, "GetRight") and HasFn(probe, "GetLeft") then
    local okR, r = pcall(f.GetRight, f)
    local okL, l = pcall(probe.GetLeft, probe)
    if okR and okL and type(r) == "number" and type(l) == "number" then
      local room = r - l - rightPad
      if room >= 8 and room <= (tonumber(dw) or 260) then return room end
    end
  end
  return fallback
end

local function SingleLine(fs)
  if not fs then return end
  if HasFn(fs, "SetWordWrap") then pcall(fs.SetWordWrap, fs, false) end
  if HasFn(fs, "SetMaxLines") then pcall(fs.SetMaxLines, fs, 1) end
  if HasFn(fs, "SetNonSpaceWrap") then pcall(fs.SetNonSpaceWrap, fs, false) end
end

-- Copie les ancres d'une FontString vers le ScrollFrame de clip.
-- Si le référent a déjà été déplacé dans un clip, on ancre sur ce clip.
local function CopyPoints(src, dst)
  dst:ClearAllPoints()
  local n = HasFn(src, "GetNumPoints") and src:GetNumPoints() or 0
  if n <= 0 then return false end
  for i = 1, n do
    local p, rel, rp, x, y = src:GetPoint(i)
    if type(rel) == "table" and rel._mq and rel._mq.clip then
      -- BOTTOMLEFT du titre → bas du clip, pas de la FS déplacée.
      if rp == "BOTTOMLEFT" or rp == "BOTTOMRIGHT" or rp == "BOTTOM" then
        rel, rp = rel._mq.clip, (rp == "BOTTOMLEFT" and "BOTTOMLEFT")
          or (rp == "BOTTOMRIGHT" and "BOTTOMRIGHT") or "BOTTOM"
      else
        rel = rel._mq.clip
      end
    end
    dst:SetPoint(p, rel, rp, x, y)
  end
  return true
end

local function EnsureClip(f, fs)
  if fs._mq and fs._mq.clip then return fs._mq end
  local okC, clip = pcall(CreateFrame, "ScrollFrame", nil, f)
  if not (okC and clip) then return nil end
  local okH, child = pcall(CreateFrame, "Frame", nil, clip)
  if not (okH and child) then return nil end
  if HasFn(clip, "SetScrollChild") then pcall(clip.SetScrollChild, clip, child) end
  if not CopyPoints(fs, clip) then
    clip:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
    clip:SetPoint("RIGHT", f, "RIGHT", f._light and -6 or -8, 0)
  end
  fs:SetParent(child)
  fs:ClearAllPoints()
  fs:SetPoint("LEFT", child, "LEFT", 0, 0)
  if HasFn(fs, "SetJustifyH") then pcall(fs.SetJustifyH, fs, "LEFT") end
  local mq = { clip = clip, child = child, fs = fs, t = 0, off = 0, need = 0, room = 0 }
  fs._mq = mq
  f._mqList = f._mqList or {}
  f._mqList[#f._mqList + 1] = mq
  return mq
end

local function FitLine(f, fs)
  if not fs or (fs.IsShown and not fs:IsShown()) then return end
  SingleLine(fs)
  local text = (fs.GetText and fs:GetText()) or ""
  if text == "" then
    if fs._mq then
      fs._mq.need, fs._mq.room, fs._mq.t, fs._mq.off = 0, 0, 0, 0
      if HasFn(fs._mq.clip, "SetHorizontalScroll") then pcall(fs._mq.clip.SetHorizontalScroll, fs._mq.clip, 0) end
    end
    return
  end
  local need = TextWidth(fs)
  local room = TF.Avail(f, fs)
  if need <= room + 0.5 then
    if fs._mq then
      fs._mq.need, fs._mq.room, fs._mq.t, fs._mq.off = need, room, 0, 0
      if HasFn(fs._mq.clip, "SetHorizontalScroll") then pcall(fs._mq.clip.SetHorizontalScroll, fs._mq.clip, 0) end
    end
    return
  end
  -- Replacer le FS dans le toast avant de recopier les ancres (vivier :
  -- le texte était déjà dans le clip, souvent déjà décalé).
  if fs._mq and fs._mq.clip and HasFn(fs, "SetParent") then
    pcall(fs.SetParent, fs, f)
  end
  local mq = EnsureClip(f, fs)
  -- Recopie les ancres à chaque Fit : la colonne commence à droite de l'icône.
  if mq and mq.clip then
    if not CopyPoints(fs, mq.clip) then
      mq.clip:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
      mq.clip:SetPoint("RIGHT", f, "RIGHT", f._light and -6 or -8, 0)
    end
    if HasFn(fs, "SetParent") then pcall(fs.SetParent, fs, mq.child) end
    if HasFn(fs, "ClearAllPoints") then fs:ClearAllPoints() end
    if HasFn(fs, "SetPoint") then fs:SetPoint("LEFT", mq.child, "LEFT", 0, 0) end
  end
  local lh = LineHeight(fs)
  mq.need, mq.room, mq.t, mq.off = need, room, 0, 0
  if HasFn(mq.clip, "SetHeight") then pcall(mq.clip.SetHeight, mq.clip, lh) end
  if HasFn(mq.clip, "SetWidth") then pcall(mq.clip.SetWidth, mq.clip, room) end
  if HasFn(mq.child, "SetHeight") then pcall(mq.child.SetHeight, mq.child, lh) end
  if HasFn(mq.child, "SetWidth") then pcall(mq.child.SetWidth, mq.child, need + 4) end
  if HasFn(fs, "SetWidth") then pcall(fs.SetWidth, fs, need) end
  if HasFn(fs, "SetHeight") then pcall(fs.SetHeight, fs, lh) end
  if HasFn(mq.clip, "SetHorizontalScroll") then pcall(mq.clip.SetHorizontalScroll, mq.clip, mq.off or 0) end
end

-- Repose le texte dans le toast et remet le défilement à 0 (vivier).
function TF.Reset(f)
  if not f then return end
  f._tfBaseH = nil
  local list = f._mqList
  if not list then return end
  for i = 1, #list do
    local mq = list[i]
    if mq then
      mq.t, mq.off, mq.need, mq.room = 0, 0, 0, 0
      if mq.clip and HasFn(mq.clip, "SetHorizontalScroll") then
        pcall(mq.clip.SetHorizontalScroll, mq.clip, 0)
      end
      local fs = mq.fs
      if fs and HasFn(fs, "SetParent") then
        pcall(fs.SetParent, fs, f)
      end
    end
  end
end

function TF.Fit(f)
  if not f or not f.titleFS then return f end
  if not f._tfBaseH and f.GetHeight then f._tfBaseH = f:GetHeight() or f._h end
  if f._h and not f._tfBaseH then f._tfBaseH = f._h end
  SingleLine(f.titleFS)
  SingleLine(f.subFS)
  SingleLine(f.hintFS)
  -- Hauteur fixe : plus de passage à 2 lignes, plus de croissance.
  if f._tfBaseH and f.SetHeight then
    pcall(f.SetHeight, f, f._tfBaseH)
    f._h = f._tfBaseH
  end
  FitLine(f, f.titleFS)
  if f.subFS and (not f.subFS.IsShown or f.subFS:IsShown()) then FitLine(f, f.subFS) end
  if f.hintFS and (not f.hintFS.IsShown or f.hintFS:IsShown()) then FitLine(f, f.hintFS) end
  return f
end

function TF.Tick(f, elapsed)
  if not f or not f._mqList then return end
  local dt = elapsed or 0
  local hover = f._hover and true or false
  for i = 1, #f._mqList do
    local mq = f._mqList[i]
    local maxOff = math.max(0, (mq.need or 0) - (mq.room or 0))
    if maxOff <= 0 then
      mq.off, mq.t = 0, 0
    elseif not hover then
      mq.t = (mq.t or 0) + dt
      local wait, speed, endW = TF.MQ_WAIT, TF.MQ_SPEED, TF.MQ_END
      local scrollT = maxOff / math.max(1, speed)
      local cycle = wait + scrollT + endW
      if mq.t >= cycle then mq.t = mq.t - cycle end
      if mq.t < wait then
        mq.off = 0
      elseif mq.t < wait + scrollT then
        mq.off = (mq.t - wait) * speed
        if mq.off > maxOff then mq.off = maxOff end
      else
        mq.off = maxOff
      end
    end
    if mq.clip and HasFn(mq.clip, "SetHorizontalScroll") then
      pcall(mq.clip.SetHorizontalScroll, mq.clip, mq.off or 0)
    end
  end
end

function TF.HookUpdate(f)
  if not f or f._tfHooked or not f.GetScript then return end
  f._tfHooked = true
  local prev = f:GetScript("OnUpdate")
  f:SetScript("OnUpdate", function(self, elapsed)
    pcall(TF.Tick, self, elapsed)
    if prev then prev(self, elapsed) end
  end)
end

-- Infobulle : texte intégral, puis détails de recette le cas échéant.
local function AddLine(tt, text, r, g, b)
  if not tt or not text or text == "" or not HasFn(tt, "AddLine") then return end
  pcall(tt.AddLine, tt, text, r or 1, g or 1, b or 1, true)
end

local function ToastItemId(info)
  if not info then return nil end
  local id = tonumber(info.item or info.itemID)
  if id then return id end
  local r = info.recipe
  if r then
    id = tonumber(r.itemID or r.item)
    if id then return id end
  end
  local e = info.entries and info.entries[1]
  if e then
    if e.recipe then id = tonumber(e.recipe.itemID or e.recipe.item) end
    if not id then id = tonumber(e.item) end
    if id then return id end
  end
  local m = info.matches and info.matches[1]
  if m then return tonumber(m.item or (m.recipe and (m.recipe.itemID or m.recipe.item))) end
  return nil
end

function TF.ShowTooltip(f)
  local tt = _G.GameTooltip
  if not tt or not f then return end
  if HasFn(tt, "SetOwner") then pcall(tt.SetOwner, tt, f, "ANCHOR_RIGHT") end
  if HasFn(tt, "ClearLines") then pcall(tt.ClearLines, tt) end
  local info = f._toastData
  local item = ToastItemId(info)
  local usedItem = false
  if item then
    if HasFn(tt, "SetItemByID") then
      local ok = pcall(tt.SetItemByID, tt, item)
      usedItem = ok and true or false
    end
    if not usedItem and HasFn(tt, "SetHyperlink") then
      usedItem = pcall(tt.SetHyperlink, tt, "item:" .. item) and true or false
    end
  end
  local title = f._fullTitle
  if (not title or title == "") and f.titleFS and f.titleFS.GetText then title = f.titleFS:GetText() end
  local sub = f._fullSub
  if sub == nil and f.subFS and f.subFS.GetText then sub = f.subFS:GetText() end
  if not usedItem then
    if HasFn(tt, "SetText") then pcall(tt.SetText, tt, title or "", 1, 1, 1, 1, true) end
  else
    AddLine(tt, title, 1, 1, 1)
  end
  if sub and sub ~= "" then AddLine(tt, sub, 0.85, 0.85, 0.85) end
  if info and ns.Craft and ns.Craft.FillToastTooltip then
    pcall(ns.Craft.FillToastTooltip, ns.Craft, tt, info)
  end
  if HasFn(tt, "Show") then pcall(tt.Show, tt) end
end

function TF.HideTooltip(f)
  local tt = _G.GameTooltip
  if not tt then return end
  if HasFn(tt, "IsOwned") then
    local ok, owned = pcall(tt.IsOwned, tt, f)
    if ok and not owned then return end
  end
  if HasFn(tt, "Hide") then pcall(tt.Hide, tt) end
end

function TF.FitSoon(f)
  if not f then return end
  pcall(TF.Fit, f)
  pcall(TF.HookUpdate, f)
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
    _G.C_Timer.After(0, function() if f and f.titleFS then pcall(TF.Fit, f) end end)
  end
end

local UI = ns.UI
if UI and UI.SpawnDrop then
  local spawn = UI.SpawnDrop
  function UI:SpawnDrop(...)
    local f = spawn(self, ...)
    if f then pcall(TF.FitSoon, f) end
    return f
  end
end
if UI and UI.BumpDropTitle then
  local bump = UI.BumpDropTitle
  function UI:BumpDropTitle(f)
    bump(self, f)
    if f then pcall(TF.FitSoon, f) end
  end
end

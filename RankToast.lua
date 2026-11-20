-- Dropamine 3.6.3 : toast collant « rang supérieur disponible chez le maître ».
-- Réutilise ns.RankStatus (state == "available", source maître). Affiché
-- UNIQUEMENT en capitale (pas à une auberge de passage), une fois par visite,
-- jusqu'au clic ou jusqu'à l'apprentissage du rang. Entrer / sortir de la
-- même capitale (auberge, subzone) ne relance pas le toast. File d'attente
-- en vol et en combat.
local ADDON, ns = ...
local Tr = ns.L
local RT = {}
ns.RankToast = RT

RT.OPT = "trainerRankToast"
RT.DEDUPE = "rank-trainer"

-- Capitales seulement (FR + EN, déjà pliées). Pas les villes / auberges de passage.
local CAPITALS = {
  ["hurlevent"] = true, ["cite de hurlevent"] = true, ["stormwind"] = true,
  ["stormwind city"] = true, ["stormwind keep"] = true,
  ["forgefer"] = true, ["ironforge"] = true,
  ["darnassus"] = true,
  ["orgrimmar"] = true,
  ["pitons-du-tonnerre"] = true, ["pitons du tonnerre"] = true,
  ["thunder bluff"] = true, ["thunderbluff"] = true,
  ["fossoyeuse"] = true, ["undercity"] = true,
  -- TBC / WotLK
  ["lune-d argent"] = true, ["lune d argent"] = true, ["lune-d'argent"] = true,
  ["silvermoon"] = true, ["silvermoon city"] = true,
  ["exodar"] = true, ["l exodar"] = true, ["the exodar"] = true,
  ["shattrath"] = true, ["cite de shattrath"] = true, ["shattrath city"] = true,
  ["dalaran"] = true, ["dalaran city"] = true,
}
-- uiMapID / GetCurrentMapAreaID (Retail, Classic, WotLK, quelques IDs Forever).
local CAPITAL_MAPS = {
  [84] = true, [87] = true, [89] = true, [85] = true, [88] = true, [90] = true,
  [103] = true, [110] = true, [111] = true, [125] = true, [126] = true,
  [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true,
  [1947] = true, [1954] = true, [1955] = true,
  [301] = true, [321] = true, [341] = true, [362] = true, [381] = true, [382] = true,
  [471] = true, [480] = true, [481] = true, [4395] = true,
}
RT.CAPITALS, RT.CAPITAL_MAPS = CAPITALS, CAPITAL_MAPS
RT.REENTRY_GRACE = 90

local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if not ok then return nil end
  return a, b, c, d
end

local function Fold(s)
  if ns.Fold then return ns.Fold(s) end
  return type(s) == "string" and s:lower() or ""
end

function RT.Opt()
  if ns.Opt then return ns.Opt(RT.OPT) ~= false end
  return true
end

function RT.SetSim(on, list)
  RT._sim = on and true or nil
  RT._simCity = on and true or nil
  if on then
    RT._simList = list or RT._simList or {
      { id = "skinning", name = "Dépeçage", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    }
  else
    RT._simList = nil
    RT._simCity = nil
  end
end

function RT.MapId()
  local CM = _G.C_Map
  if type(CM) == "table" and type(CM.GetBestMapForUnit) == "function" then
    local ok, id = pcall(CM.GetBestMapForUnit, "player")
    if ok then id = tonumber(id) end
    if id then return id end
  end
  if type(_G.GetCurrentMapAreaID) == "function" then
    local ok, id = pcall(_G.GetCurrentMapAreaID)
    if ok then id = tonumber(id) end
    if id then return id end
  end
  return nil
end

function RT.CapitalKey()
  local id = RT.MapId()
  if id and CAPITAL_MAPS[id] then return "map:" .. tostring(id) end
  local zones = {
    Call(GetRealZoneText), Call(GetZoneText), Call(GetMinimapZoneText),
  }
  for i = 1, #zones do
    local z = zones[i]
    if type(z) == "string" and z ~= "" then
      local f = Fold(z)
      if CAPITALS[f] then return f end
    end
  end
  return nil
end

-- Uniquement une capitale (nom ou map ID, ou API du client). Jamais une auberge de passage.
function RT.InCapital()
  if RT._simCity or (ns.Slot and ns.Slot.IsSim and ns.Slot.IsSim("rankup")) then return true end
  if type(_G.IsCapitalCity) == "function" then
    local ok, v = pcall(_G.IsCapitalCity)
    if ok and v then return true end
  end
  return RT.CapitalKey() ~= nil
end
-- Compat : ancien nom.
function RT.InCity()
  return RT.InCapital()
end

-- Jamais ns.Collect ici : une entrée d'auberge ne doit pas reconstruire la grille.
local function Tiles()
  local ui = ns.UI
  if ui and ui.embed and ui.embed.tiles then return ui.embed.tiles end
  if ui and ui.snapshot and ui.snapshot.tiles then return ui.snapshot.tiles end
  if ui and ui.snapshot and ui.snapshot.allTiles then return ui.snapshot.allTiles end
  return RT._emptyTiles or {}
end
RT._emptyTiles = {}

-- Métiers dont un rang supérieur s'apprend chez le maître (pas livre / quête).
-- Réutilise le buffer pour ne pas allouer à chaque événement de zone.
function RT.Available(tiles)
  local out = RT._availBuf
  if out then
    for i = #out, 1, -1 do out[i] = nil end
  else
    out = {}
    RT._availBuf = out
  end
  if RT._sim and RT._simList then
    for i = 1, #RT._simList do out[i] = RT._simList[i] end
    return out
  end
  local seen = RT._availSeen
  if seen then
    for k in pairs(seen) do seen[k] = nil end
  else
    seen = {}
    RT._availSeen = seen
  end
  tiles = tiles or Tiles()
  for i = 1, #tiles do
    local t = tiles[i]
    local d = (t and t.data) or t
    if d and not d.placeholder and d.id and (d.kind == "profession" or d.kind == "secondary") then
      if not seen[d.id] then
        local st = ns.RankStatus and ns.RankStatus(d, d.current, d.apiMax)
        if st and st.state == "available" then
          local tiers = ns.PROF_TIERS and ns.PROF_TIERS[d.id]
          local cap = tonumber(d.apiMax) or 0
          local nx = tiers and tiers[cap]
          if nx and nx.src == "maître" then
            seen[d.id] = true
            out[#out + 1] = { id = d.id, name = d.name or d.id, icon = d.icon }
          end
        end
      end
    end
  end
  return out
end

function RT.Title(list)
  list = list or {}
  local names = {}
  for i = 1, #list do
    names[#names + 1] = list[i].name or list[i].id
  end
  local joined = table.concat(names, ", ")
  if joined == "" then joined = "?" end
  local fmt = Tr["%s : rang supérieur disponible chez le maître"]
  if type(fmt) ~= "string" then fmt = "%s : rang supérieur disponible chez le maître" end
  return string.format(fmt, joined)
end

function RT.Blocked()
  local F = ns.Flight
  if F and F.Paused and F.Paused() then return "flight" end
  if ns.Slot and ns.Slot.LiveCombat and ns.Slot.LiveCombat() then return "combat" end
  if type(UnitAffectingCombat) == "function" and Call(UnitAffectingCombat, "player") then return "combat" end
  return nil
end

function RT.IsShowing()
  local f = RT._toast
  if not f then return false end
  if f.IsShown and not f:IsShown() then return false end
  return true
end

function RT.Hide(reason)
  local ui = ns.UI
  local f = RT._toast
  RT._toast = nil
  if f and ui and ui.DismissDrop then
    pcall(ui.DismissDrop, ui, f)
  elseif f and f.Hide then
    pcall(f.Hide, f)
  end
  if reason == "click" then RT._dismissedVisit = true end
end

function RT.OnDismissed(f)
  if f and RT._toast == f then
    RT._toast = nil
    RT._dismissedVisit = true
    RT._queued = nil
  end
end

function RT.IdsKey(list)
  local ids = {}
  for i = 1, #(list or {}) do ids[i] = list[i].id or list[i].name end
  table.sort(ids)
  return table.concat(ids, "|")
end

function RT.CanShow(list)
  if not RT.Opt() then return false end
  if not RT.InCity() then return false end
  if RT._dismissedVisit then return false end
  list = list or RT.Available()
  if not list or #list == 0 then return false end
  if RT.Blocked() then return false end
  return true, list
end

function RT.Show(list)
  list = list or RT.Available()
  if not list or #list == 0 then return nil end
  if RT.Blocked() then RT._queued = true return nil end
  if not RT.Opt() or not RT.InCity() or RT._dismissedVisit then return nil end
  local ui = ns.UI
  if not (ui and ui.SpawnDrop) then return nil end
  local title = RT.Title(list)
  local icon = list[1] and list[1].icon or ns.FALLBACK_ICON
  local ok, f = pcall(ui.SpawnDrop, ui, icon, title, nil, nil, nil, nil, {
    force = true, sticky = true, kind = "rank-trainer",
    dedupeKey = RT.DEDUPE, skillId = list[1] and list[1].id,
    toastData = { kind = "rank-trainer", skills = list },
  })
  if ok and f then
    RT._toast = f
    RT._shownKey = RT.IdsKey(list)
    RT._queued = nil
    if RT.ApplyBadge then pcall(RT.ApplyBadge, f) end
    return f
  end
  return nil
end

local function Now()
  if type(GetTime) == "function" then
    local ok, v = pcall(GetTime)
    if ok and type(v) == "number" then return v end
  end
  return 0
end

function RT.Refresh(reason)
  reason = reason or ""
  local here = RT.InCapital()
  local key = here and (RT.CapitalKey() or (RT._simCity and "sim") or "capital") or nil

  if not here then
    if RT.IsShowing() then RT.Hide("leave") end
    if RT._wasInCity then
      RT._leftAt = Now()
      RT._leftKey = RT._wasKey
    end
    RT._wasInCity = false
    RT._wasKey = nil
    RT._queued = nil
    -- On oublie le dismiss de visite seulement en quittant vraiment la capitale.
    RT._dismissedVisit = nil
    return
  end

  local entered = not RT._wasInCity
  RT._wasInCity = true
  RT._wasKey = key

  -- Auberge / intérieur / repos : pas une nouvelle visite de capitale.
  local innEvent = reason == "PLAYER_UPDATE_RESTING"
    or reason == "ZONE_CHANGED_INDOORS"
    or reason == "ZONE_CHANGED"

  local skipEnter = false
  if entered then
    local now = Now()
    local same = RT._leftKey and key and RT._leftKey == key
      and RT._leftAt and (now - RT._leftAt) < (RT.REENTRY_GRACE or 90)
    if same then
      -- Même capitale récemment quittée : pas de nouveau toast.
      RT._queued = nil
      skipEnter = true
    else
      RT._dismissedVisit = nil
      if RT.Opt() and RT.Available()[1] then RT._queued = true end
    end
  end

  local list = RT.Available()
  if #list == 0 then
    RT._queued = nil
    if RT.IsShowing() then RT.Hide("learned") end
    return
  end

  local blocked = RT.Blocked()
  if blocked then
    if RT.IsShowing() then
      RT._queued = true
      RT.Hide("defer")
      RT._dismissedVisit = nil
    end
    return
  end

  if RT._dismissedVisit then return end
  if not RT.Opt() then
    if RT.IsShowing() then RT.Hide("option") end
    return
  end

  if RT.IsShowing() then
    local ids = RT.IdsKey(list)
    if ids ~= RT._shownKey then
      local title = RT.Title(list)
      local f = RT._toast
      if f then
        f._fullTitle = title
        if f.titleFS and f.titleFS.SetText then pcall(f.titleFS.SetText, f.titleFS, title) end
        RT._shownKey = ids
      end
    end
    return
  end

  -- Jamais déclenché par le seul passage d'une auberge (repos / intérieur).
  if innEvent and not entered and not RT._queued then return end
  if skipEnter and not RT._queued then return end

  if RT._queued or reason == "enter" or reason == "test"
      or reason == "ZONE_CHANGED_NEW_AREA" or reason == "PLAYER_ENTERING_WORLD"
      or reason == "PLAYER_REGEN_ENABLED" or entered then
    RT.Show(list)
  end
end

-- Options
RT.OPTION = {
  type = "check", key = "trainerRankToast",
  label = "Toast rang supérieur chez le maître",
  default = true,
  help = "En capitale seulement (pas à une auberge de passage), un toast reste affiché tant qu'un rang de métier s'apprend chez le maître. Il se ferme au clic ou dès que le rang est appris. Entrer et sortir de la même capitale ne le relance pas.",
}

do
  -- Clic sur le toast : mémoriser le renvoi.
  local UI = ns.UI
  if UI and UI.DismissDrop then
    local base = UI.DismissDrop
    function UI:DismissDrop(f, ...)
      if f and (f._kind == "rank-trainer" or f._dedupeKey == RT.DEDUPE) then
        pcall(RT.OnDismissed, f)
      end
      return base(self, f, ...)
    end
  end
  local F = ns.Flight
  if F and F.HideActiveToasts then
    local base = F.HideActiveToasts
    function F.HideActiveToasts()
      if RT.IsShowing() then RT._queued = true RT._toast = nil end
      return base()
    end
  end
  if F and F.OnEnd then
    local base = F.OnEnd
    function F.OnEnd()
      if base then base() end
      pcall(RT.Refresh, "PLAYER_REGEN_ENABLED")
    end
  end
end

if ns.Options then
  ns.Options.EXTRA = ns.Options.EXTRA or {}
  ns.Options.EXTRA[#ns.Options.EXTRA + 1] = RT.OPTION
  ns.Options.EXTRA_HOME = ns.Options.EXTRA_HOME or {}
  ns.Options.EXTRA_HOME[RT.OPT] = "notif"
  local order = ns.Options.ITEM_ORDER and ns.Options.ITEM_ORDER.notif
  if order then
    local at = #order + 1
    for i, k in ipairs(order) do if k == "paliers" or k == "prepalier" then at = i + 1 end end
    table.insert(order, at, RT.OPT)
  end
  if ns.Options.All then ns.Options.ITEMS = ns.Options.All() end
end


-- Badge chevron bronze, superposé à l'icône du métier, masqué dans le cercle.
function RT.ApplyBadge(frame)
  if not frame then return nil end
  local slot = frame.iconSlot or frame
  local parent = slot
  if type(parent.CreateTexture) ~= "function" then parent = frame end
  if type(parent.CreateTexture) ~= "function" then return nil end
  local b = frame._rankBadge
  if not b then
    b = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    frame._rankBadge = b
  end
  local tex = ns.RANK_BADGE or "Interface\\AddOns\\Dropamine\\Media\\Rank-Badge"
  if b.SetTexture then pcall(b.SetTexture, b, tex) end
  local icon = (slot and (slot.iconTex or slot.icon)) or frame.icon
  if icon and b.SetAllPoints then
    pcall(b.SetAllPoints, b, icon)
  elseif icon and b.SetPoint then
    if b.ClearAllPoints then pcall(b.ClearAllPoints, b) end
    pcall(b.SetPoint, b, "TOPLEFT", icon, "TOPLEFT", 0, 0)
    pcall(b.SetPoint, b, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
  end
  if b.SetTexCoord then pcall(b.SetTexCoord, b, 0, 1, 0, 1) end
  if slot and slot._flareMask and b.AddMaskTexture then
    pcall(b.AddMaskTexture, b, slot._flareMask)
  end
  if b.Show then b:Show() end
  return b
end

-- Dropamine 3.6.3 : toast collant « rang supérieur disponible chez le maître ».
-- Réutilise ns.RankStatus (state == "available", source maître). Affiché en
-- capitale ou en ville de maîtres (IsResting), une fois par entrée, jusqu'au
-- clic ou jusqu'à l'apprentissage du rang. File d'attente en vol et en combat.
local ADDON, ns = ...
local Tr = ns.L
local RT = {}
ns.RankToast = RT

RT.OPT = "trainerRankToast"
RT.DEDUPE = "rank-trainer"

-- Capitales et villes où l'on trouve des maîtres de métier (FR + EN, déjà pliées).
local CITY = {
  -- capitales
  ["hurlevent"] = true, ["cite de hurlevent"] = true, ["stormwind"] = true,
  ["stormwind city"] = true, ["stormwind keep"] = true,
  ["forgefer"] = true, ["ironforge"] = true,
  ["darnassus"] = true, ["teldrassil"] = false,
  ["orgrimmar"] = true,
  ["pitons-du-tonnerre"] = true, ["pitons du tonnerre"] = true,
  ["thunder bluff"] = true, ["thunderbluff"] = true,
  ["fossoyeuse"] = true, ["undercity"] = true,
  -- villes / ports avec maîtres
  ["baie-du-butin"] = true, ["baie du butin"] = true, ["booty bay"] = true,
  ["cabestan"] = true, ["ratchet"] = true,
  ["gadgetzan"] = true,
  ["theramore"] = true, ["ile de theramore"] = true, ["theramore isle"] = true,
  ["auberdine"] = true,
  ["port de menethil"] = true, ["menethil harbor"] = true, ["menethil"] = true,
  ["long-guet"] = true, ["everlook"] = true,
  ["mara"] = false,
}

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

function RT.InCity()
  if RT._simCity or (ns.Slot and ns.Slot.IsSim and ns.Slot.IsSim("rankup")) then return true end
  local zones = {
    Call(GetRealZoneText), Call(GetZoneText), Call(GetSubZoneText), Call(GetMinimapZoneText),
  }
  local hit = false
  for i = 1, #zones do
    local z = zones[i]
    if type(z) == "string" and z ~= "" and CITY[Fold(z)] then hit = true break end
  end
  if not hit then return false end
  -- capitale : toujours ; autre ville : seulement si on se repose (auberge / ville)
  -- Les capitales sont aussi des zones de repos ; IsResting suffit en pratique,
  -- mais on accepte une capitale même si l'API de repos est muette.
  if Call(IsResting) then return true end
  -- capitales sans IsResting (chargement, test)
  local capitals = {
    hurlevent = true, ["cite de hurlevent"] = true, stormwind = true, ["stormwind city"] = true,
    forgefer = true, ironforge = true, darnassus = true, orgrimmar = true,
    ["pitons-du-tonnerre"] = true, ["pitons du tonnerre"] = true, ["thunder bluff"] = true,
    thunderbluff = true, fossoyeuse = true, undercity = true,
  }
  for i = 1, #zones do
    local z = zones[i]
    if type(z) == "string" and capitals[Fold(z)] then return true end
  end
  return false
end

local function Tiles()
  local ui = ns.UI
  if ui and ui.embed and ui.embed.tiles then return ui.embed.tiles end
  if ui and ui.snapshot and ui.snapshot.tiles then return ui.snapshot.tiles end
  if type(ns.Collect) == "function" then
    local ok, snap = pcall(ns.Collect)
    if ok and snap and snap.tiles then return snap.tiles end
  end
  return {}
end

-- Métiers dont un rang supérieur s'apprend chez le maître (pas livre / quête).
function RT.Available(tiles)
  if RT._sim and RT._simList then
    local copy = {}
    for i = 1, #RT._simList do copy[i] = RT._simList[i] end
    return copy
  end
  local out, seen = {}, {}
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

function RT.Refresh(reason)
  local inCity = RT.InCity()
  if inCity and not RT._wasInCity then
    -- Nouvelle entrée en capitale / ville : le toast peut se relancer.
    RT._dismissedVisit = nil
    if RT.Opt() and RT.Available()[1] then RT._queued = true end
  end
  if not inCity then
    RT._dismissedVisit = nil
    RT._queued = nil
    if RT.IsShowing() then RT.Hide("leave") end
    RT._wasInCity = false
    return
  end
  RT._wasInCity = true

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
      -- Hide() avec defer ne doit pas compter comme un clic.
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
    local key = RT.IdsKey(list)
    if key ~= RT._shownKey then
      -- Mettre à jour le texte (un métier appris, un autre encore dispo).
      local title = RT.Title(list)
      local f = RT._toast
      if f then
        f._fullTitle = title
        if f.titleFS and f.titleFS.SetText then pcall(f.titleFS.SetText, f.titleFS, title) end
        RT._shownKey = key
      end
    end
    return
  end

  if RT._queued or reason == "enter" or reason == "test" or reason == "ZONE_CHANGED"
      or reason == "ZONE_CHANGED_NEW_AREA" or reason == "ZONE_CHANGED_INDOORS"
      or reason == "PLAYER_ENTERING_WORLD" or reason == "PLAYER_UPDATE_RESTING"
      or reason == "PLAYER_REGEN_ENABLED" then
    RT.Show(list)
  elseif not RT._toast then
    -- déjà en ville au chargement / test
    RT.Show(list)
  end
end

-- Options
RT.OPTION = {
  type = "check", key = "trainerRankToast",
  label = "Toast rang supérieur chez le maître",
  default = true,
  help = "En capitale ou en ville, un toast reste affiché tant qu'un rang de métier s'apprend chez le maître. Il se ferme au clic ou dès que le rang est appris, et revient à chaque entrée en ville.",
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

-- Dropamine 3.11.0 : export pour les Hiscores de dropamine.app.
-- « /drop hiscores » ouvre la fenêtre de copie avec une ligne à coller sur le site :
-- les compétences d'armes (absentes de l'armurerie Blizzard), la Défense, le niveau,
-- les métiers et la guilde. Le site recoupe niveau, métiers et Défense avec l'armurerie.
-- Rien n'est envoyé par l'addon : le joueur copie et colle lui-même.
local ADDON, ns = ...
local Tr = ns.L

local HS = {}
ns.Hiscores = HS
HS.PREFIX = "DROPAMINE-HS1:"

local function N(v) return ns.N and ns.N(v) or tonumber(v) end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if not ok then return nil end
  if ns.Unsecret then return ns.Unsecret(a, b, c, d) end
  return a, b, c, d
end
-- champs : rien d'autre que lettres, chiffres, espace, tiret et apostrophe (pas de séparateur)
local function clean(s) return (tostring(s or ""):gsub("[|;:,=%c]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")) end

-- somme de contrôle simple (détecte une ligne tronquée ou modifiée à la main, ce n'est pas une signature)
function HS.Checksum(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
  return string.format("%08x", h)
end

local REGION = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }

-- Construit la ligne. Renvoie texte, détails (pour l'affichage), ou nil + raison.
function HS.Build()
  local profs, weapons, defense = {}, {}, nil
  if ns.SkillsForCharSheet then
    local ok, p, w, d = pcall(ns.SkillsForCharSheet)
    if ok then profs, weapons, defense = p or {}, w or {}, d end
  end
  if #weapons == 0 and not defense then return nil, Tr["Compétences pas encore lues : ouvre le panneau (/drop) puis réessaie."] end
  local name = clean(Call(_G.UnitName, "player"))
  local level = N(Call(_G.UnitLevel, "player")) or 0
  local guild = clean(Call(_G.GetGuildInfo, "player"))
  local region = REGION[N(Call(_G.GetCurrentRegion)) or 0] or ""
  local wlist, wsum = {}, 0
  for _, w in ipairs(weapons) do
    local r = N(w.rank) or 0
    wsum = wsum + r
    wlist[#wlist + 1] = string.format("%s=%d", tostring(w.id or clean(w.name)), r)
  end
  local plist = {}
  for _, p in ipairs(profs) do plist[#plist + 1] = string.format("%s=%d", tostring(p.id or clean(p.name)), N(p.rank) or 0) end
  local fields = {
    "n=" .. name, "l=" .. level, "r=" .. region, "g=" .. guild,
    "d=" .. (N(defense and defense.rank) or 0), "ws=" .. wsum,
    "w=" .. table.concat(wlist, ","), "p=" .. table.concat(plist, ","),
    "v=" .. tostring(ns.VERSION or ""), "t=" .. tostring(N(Call(_G.time)) or 0),
  }
  local body = table.concat(fields, ";")
  local line = HS.PREFIX .. body .. ";c=" .. HS.Checksum(body)
  return line, { name = name, level = level, guild = guild, weapons = wsum, defense = N(defense and defense.rank) or 0, count = #weapons }
end

function HS.Open()
  local line, info = HS.Build()
  if not line then if ns.Print then ns.Print(info) end return nil end
  local DW = ns.DebugWindow
  local lines = {
    line, " ",
    string.format(Tr["%s · niveau %d · armes %d (%d) · Défense %d%s"], info.name, info.level, info.weapons, info.count, info.defense,
      info.guild ~= "" and (" · " .. info.guild) or ""),
    Tr["Copie la première ligne (Ctrl+C) et colle-la sur dropamine.app, page Inscription."],
  }
  if DW and DW.Show then DW.Show(lines, { title = Tr["Hiscores : ta ligne d'export (Ctrl+C pour copier)"] }) end
  return line
end

ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.hiscores = function() HS.Open() end
ns.SlashExt.scores = ns.SlashExt.hiscores
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop hiscores : ligne d'export pour les classements de dropamine.app"

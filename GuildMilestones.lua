-- Dropamine 3.10.0 : paliers du niveau total annoncés en guilde (coupé par défaut).
local ADDON, ns = ...
local Tr = ns.L
local Unpack = _G.unpack or table.unpack
local GM = {}
ns.GuildMilestones = GM

local function N(v) return ns.N(v) end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if not ok then return nil end
  return ns.Unsecret(a, b, c)
end

GM.OPTION = { type = "check", key = "guildMilestones", label = "Annoncer les paliers en guilde", default = false, cmd = "Réglage de ce panneau",
  help = "Message dans le canal de guilde quand ton niveau total franchit un palier (500, 1000…)." }
local O = ns.Options
if O then
  O.EXTRA_HOME = O.EXTRA_HOME or {}
  O.EXTRA[#O.EXTRA + 1] = GM.OPTION
  O.EXTRA_HOME.guildMilestones = "progress"
  if O.GROUPS and O.GROUPS.grpAnnounce then
    local items = O.GROUPS.grpAnnounce.items
    items[#items + 1] = { "guildMilestones", "Paliers du total en guilde" }
  end
  if O.TEST then O.TEST.guildMilestones = "guildpreview" end
  O.TEST_FN = O.TEST_FN or {}
end

function GM.Text(m, total, tmax)
  return string.format(Tr["[Dropamine] Niveau total %d atteint (%d / %d) !"], m, N(total) or m, N(tmax) or 0)
end
do
  local P = ns.Progress
  if P and P.TotalDing then
    local base = P.TotalDing
    function P.TotalDing(prev, cur, ...)
      local p = P.C and P.C()
      local before = {}
      if p and type(p.dinged) == "table" then for k in pairs(p.dinged) do before[k] = true end end
      local r = { base(prev, cur, ...) }
      if ns.OptOff("guildMilestones") and p and type(p.dinged) == "table" then
        local hit
        for k in pairs(p.dinged) do if not before[k] and k > (N(prev) or 0) and (not hit or k > hit) then hit = k end end
        if hit and Call(_G.IsInGuild) and type(_G.SendChatMessage) == "function" then
          local snap = ns.UI and ns.UI.snapshot
          pcall(_G.SendChatMessage, GM.Text(hit, cur, snap and snap.totalMax or ns.TOTAL_MAX), "GUILD")
        end
      end
      return Unpack(r)
    end
  end
end

if O and O.TEST_FN then
  O.TEST_FN.guildpreview = function()
    local snap = ns.UI and ns.UI.snapshot
    ns.Print(Tr["Aperçu (rien n'est envoyé) : "] .. GM.Text(1000, 1000, snap and snap.totalMax or ns.TOTAL_MAX))
    return true
  end
end

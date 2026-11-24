-- Dropamine — 3.9.0 : export / import des réglages.
-- Tous les réglages du panneau tiennent dans une ligne de texte « DROP1:… » à copier sur un autre compte
-- ou un autre personnage. Ni la progression, ni la chasse, ni la langue, ni le profil par personnage.
-- /drop export (fenêtre à copier), /drop import (fenêtre où coller) ; boutons dans l'onglet Avancé.
local ADDON, ns = ...
local Tr = ns.L
local PF = {}
ns.Profile = PF
PF.PREFIX = "DROP1:"
PF.SKIP = { lang = true, charProfile = true }   -- propres à chaque installation / personnage
local function esc(s) return (tostring(s):gsub("[%%;=\n|]", function(c) return string.format("%%%02X", c:byte()) end)) end
local function unesc(s) return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end

-- réglages exportables : cases, choix et curseurs (les listes à cases passent par leurs cases)
function PF.Keys()
  local O = ns.Options
  local out = {}
  if not (O and O.All) then return out end
  for _, it in ipairs(O.All()) do
    if it.key and not it.checklist and not PF.SKIP[it.key] and (it.type == "check" or it.type == "radio" or it.type == "slider") then
      out[#out + 1] = it
    end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

function PF.Export()
  local O = ns.Options
  local parts = {}
  for _, it in ipairs(PF.Keys()) do
    local ok, v = pcall(O.Get, it.key)
    local t = ok and type(v)
    local enc
    if t == "boolean" then enc = v and "b1" or "b0"
    elseif t == "number" then enc = "n" .. tostring(v)
    elseif t == "string" then enc = "s" .. esc(v) end
    if enc then parts[#parts + 1] = esc(it.key) .. "=" .. enc end
  end
  return PF.PREFIX .. table.concat(parts, ";"), #parts
end

function PF.Decode(text)
  text = tostring(text or ""):gsub("%s+", "")
  if text:sub(1, #PF.PREFIX) ~= PF.PREFIX then return nil, "prefix" end
  local out = {}
  for pair in text:sub(#PF.PREFIX + 1):gmatch("[^;]+") do
    local k, v = pair:match("^([^=]+)=(.+)$")
    if k then
      k = unesc(k)
      local tag, raw = v:sub(1, 1), v:sub(2)
      if tag == "b" then out[k] = (raw == "1")
      elseif tag == "n" then out[k] = tonumber(raw)
      elseif tag == "s" then out[k] = unesc(raw) end
    end
  end
  return out
end

-- applique seulement les réglages connus de cette version ; renvoie (appliqués, ignorés)
function PF.Import(text)
  local data, why = PF.Decode(text)
  if not data then return nil, why end
  local O = ns.Options
  local known = {}
  for _, it in ipairs(PF.Keys()) do known[it.key] = it end
  local n, skipped = 0, 0
  O._syncing = true
  for k, v in pairs(data) do
    if known[k] and v ~= nil then
      if pcall(O.Set, k, v) then n = n + 1 end
    else
      skipped = skipped + 1
    end
  end
  O._syncing = false
  if O.panel and O.Sync then pcall(O.Sync) end
  return n, skipped
end

function PF.OpenExport()
  local s, n = PF.Export()
  local DW = ns.DebugWindow
  if DW and DW.Show then DW.Show({ s }, { title = string.format(Tr["Profil Dropamine : %d réglages (Ctrl+C pour copier)"], n) }) end
end
function PF.OpenImport()
  local DW = ns.DebugWindow
  if not (DW and DW.ShowEdit) then return end
  DW.ShowEdit(Tr["Colle un profil Dropamine (Ctrl+V), puis Importer"], Tr["Importer"], function(text)
    local n, x = PF.Import(text)
    if not n then ns.Print(Tr["profil : texte non reconnu (il doit commencer par DROP1:)."]) return false end
    ns.Print(string.format(Tr["profil : %d réglages importés."], n) .. ((x and x > 0) and string.format(Tr[" (%d inconnus ignorés)"], x) or ""))
    return true
  end)
end

ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.export = function() PF.OpenExport() end
ns.SlashExt.import = function() PF.OpenImport() end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop export · import : copier tes réglages vers un autre compte ou personnage"

-- Minimal-Attrappe: jedes unbekannte Global ist ein „Alles-Objekt“
local Any
local mt = {}
mt.__index = function(t, k) return Any end
mt.__call = function() return Any end
mt.__concat = function(a, b) return tostring(a) .. tostring(b) end
mt.__tostring = function() return "Any" end
Any = setmetatable({}, mt)
JETZT = 1795400000
function time() return JETZT end
local osdate = os.date
function date(f, t) return osdate(f, t or JETZT) end
function GetTime() return JETZT end
GOLD_IN_TASCHE = 50 * 10000
function GetMoney() return GOLD_IN_TASCHE end
NAMEN, KLASSE = {}, {}
C_Item = { GetItemInfo = function(id) return NAMEN[id] end,
  GetItemInfoInstant = function(id) local k = KLASSE[id]; if not k then return nil end; return id, "", "", "", 0, k[1], k[2] end,
  GetItemIconByID = function() return 1 end }
GetItemInfo = C_Item.GetItemInfo
AUSGABE = {}
function print(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end AUSGABE[#AUSGABE + 1] = table.concat(t, " "); io.write((table.concat(t, " "):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")), "\n") end
table.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
wipe = table.wipe
strsplit = function(d, s) local r = {} for x in (s .. d):gmatch("(.-)" .. d:gsub("%p", "%%%0")) do r[#r + 1] = x end return table.unpack(r) end
unpack = table.unpack
setmetatable(_G, { __index = function(t, k) return Any end })

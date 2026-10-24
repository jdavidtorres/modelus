local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end
local catalogEnv = setmetatable({}, { __index = _G })
local catalogChunk = assert(loadfile("mods/modelus/common/media/lua/shared/weight-reducer/WeightReducerCatalog.generated.lua"))
setfenv(catalogChunk, catalogEnv)
catalogChunk()
local scriptItems = {}
local fullType = "Base.Log"
local scriptItem = { weight = 10 }
function scriptItem:getActualWeight() return self.weight end
function scriptItem:DoParam(value) self.weight = tonumber(value:match("([%d%.]+)")) end
scriptItems[fullType] = scriptItem
local events = {}
for _, name in ipairs({ "OnGameStart", "OnPlayerUpdate", "OnContainerUpdate" }) do
    local eventName = name
    events[eventName] = { Add = function(callback) events[eventName].callback = callback end }
end
local environment = {
    WeightReducer = {}, WeightReducerCatalog_Generated = catalogEnv.WeightReducerCatalog_Generated,
    require = function() end, Events = events, ScriptManager = { instance = {
        getItem = function(_, name) return scriptItems[name] end
    } }, print = function() end, getDebug = function() return false end,
    ipairs = ipairs, pairs = pairs, type = type, tostring = tostring, tonumber = tonumber,
    string = string, table = table, math = math, pcall = pcall
}
setmetatable(environment, { __index = _G })
local chunk = assert(loadfile("mods/modelus/common/media/lua/shared/weight-reducer/WeightReducer.lua"))
setfenv(chunk, environment)
chunk()
local reducer = environment.WeightReducer
expect(reducer.MULTIPLIER == 0.1 and #reducer.ITEMS == 207, "Lua-only weight catalog is active")
events.OnGameStart.callback()
expect(scriptItem.weight == 1, "script weight is reduced to ten percent")
events.OnGameStart.callback()
expect(scriptItem.weight == 1, "repeated application does not compound reduction")
return assertions

local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end
local function list(values)
    return { size = function() return #values end, get = function(_, index) return values[index + 1] end }
end
local catalogEnv = setmetatable({}, { __index = _G })
local catalogChunk = assert(loadfile("mods/modelus/common/media/lua/shared/auto-eat/CannedFoodCatalog.lua"))
setfenv(catalogChunk, catalogEnv)
catalogChunk()
local items = {}
local inventory = { getItems = function() return list(items) end }
local player = {
    getInventory = function() return inventory end,
    getStats = function() return { get = function() return 0.9 end } end
}
local action
local logic = {
    setContainers = function() end,
    setRecipeFromContextClick = function() end,
    canPerformCurrentRecipe = function() return true end,
    getRecipeData = function(self) return self.recipeData end,
    startCraftAction = function() end,
    stopCraftAction = function() end
}
local eaten = {}
local environment = {
    AutoEatCans = {},
    ModelusCannedFoodCatalog = catalogEnv.ModelusCannedFoodCatalog,
    require = function() end,
    ISEntityUI = { HandcraftStart = function()
        action.logic = logic
        return action
    end },
    HandcraftLogic = { new = function() return logic end },
    ArrayList = { new = function()
        local values = {}
        return { add = function(_, value) values[#values + 1] = value end,
            size = function() return #values end, get = function(_, index) return values[index + 1] end }
    end },
    getScriptManager = function() return { getCraftRecipe = function(_, name) return name end } end,
    instanceof = function(value, className) return className == "InventoryContainer" and value.containerItem end,
    ISTimedActionQueue = { add = function() end, hasAction = function() return true end },
    AutoEat = { HUNGER_THRESHOLD = 0.5,
        isAllowedFood = function(_, _, expected) return expected == "Base.OpenBeans" end,
        queueEatAction = function(_, item) eaten[#eaten + 1] = item end },
    CharacterStat = { HUNGER = "hunger" },
    ISEatFoodAction = {},
    print = function() end,
    pcall = pcall, ipairs = ipairs, pairs = pairs, type = type, tostring = tostring,
    string = string, table = table, math = math, setmetatable = setmetatable
}
setmetatable(environment, { __index = _G })
local chunk = assert(loadfile("mods/modelus/common/media/lua/client/auto-eat/AutoEatCans.lua"))
setfenv(chunk, environment)
chunk()
local cans = environment.AutoEatCans
local function canned(fullType, recipe)
    return { getFullType = function() return fullType end,
        getOpeningRecipe = function() return recipe end }
end
local function created(fullType)
    return { getFullType = function() return fullType end }
end
local function begin(outputItems)
    action = {
        setOnStart = function(self, callback, data) self.onStart, self.attempt = callback, data end,
        setOnComplete = function(self, callback, data) self.onComplete, self.attempt = callback, data end,
        setOnCancel = function(self, callback, data) self.onCancel, self.attempt = callback, data end
    }
    logic.recipeData = { getAllCreatedItems = function() return list(outputItems) end }
    expect(cans.queueOpenAction(player, canned("Base.TinnedBeans", "OpenCannedFood"),
        { recipeName = "OpenCannedFood", expectedType = "Base.OpenBeans" }), "compatible can queues vanilla action")
    action.onStart(action.attempt, action)
    return action.attempt
end

items = { canned("Base.TinnedBeans", "DifferentRecipe") }
expect(not cans.queueBestCan(player, 0.9), "can with mismatched native opening recipe is rejected")

items = {}
local output = created("Base.OpenBeans")
items[1] = output
local success = begin({ output })
action.onComplete(success)
expect(success.pending:getState() == "SUCCEEDED" and eaten[1] == output,
    "recipe completion consumes the exact single created item (state="
        .. tostring(success.pending:getState()) .. ", eaten=" .. tostring(#eaten) .. ")")
expect(not success.pending:finish() and success.pending:getState() == "SUCCEEDED",
    "pending can permits only one terminal transition")

local function rejected(outputs, expectedState)
    cans.pending = nil
    items = outputs
    local attempt = begin(outputs)
    action.onComplete(attempt)
    expect(attempt.pending:getState() == expectedState, "invalid recipe output fails safely")
    expect(#eaten == 1, "invalid output is never auto-eaten")
end
rejected({}, "FAILED")
rejected({ created("Base.OpenBeans"), created("Base.OpenBeans") }, "FAILED")
rejected({ created("Base.CannedBologneseOpen") }, "FAILED")

cans.pending = nil
items = {}
local cancelled = begin({})
action.onCancel(cancelled)
action.onComplete(cancelled)
expect(cancelled.pending:getState() == "CANCELLED", "cancelled attempt cannot transition on completion")
return assertions

local function modelusBootstrap()
    print("[Modelus] Lua bootstrap started")

    if not luajava then
        print("[Modelus] luajava is not available in this context")
        return
    end

    local ok, javaBridge = pcall(luajava.bindClass, "com.modelus.bridge.ModelusBridge")
    if not ok then
        print("[Modelus] Could not bind Java bridge class: " .. tostring(javaBridge))
        return
    end

    local success, message = pcall(javaBridge.onLuaBootstrap, "Project Zomboid")
    if success then
        print("[Modelus] " .. tostring(message))
    else
        print("[Modelus] Java bridge call failed: " .. tostring(message))
    end
end

Events.OnGameBoot.Add(modelusBootstrap)

local function modelusBootstrap()
    print("[Modelus] Lua bootstrap started")
    print("[Modelus] better-condition: active (restores condition on equip)")
    print("[Modelus] ammo-converter:   active (auto-converts ammo on idle)")
    print("[Modelus] weight-reducer:   active (70% reduction for materials, tools, weapons)")
    print("[Modelus] ammo-loot-drop:   active")
    print("[Modelus] ammo-loot-drop-box: active")
    print("[Modelus] ammo-loot-drop-carton: active")
    print("[Modelus] auto-reload:      active (reloads equipped weapon on empty)")
    print("[Modelus] auto-cook:        registered")
    print("[Modelus] auto-drink:       active (drinks soda/juice/water when thirsty)")
    print("[Modelus] auto-eat:         active (eats prepared meals when hungry)")
    print("[Modelus] free-hotwiring:   active")
    print("[Modelus] casual-reloading: active")

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

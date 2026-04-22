package com.modelus.bridge;

public final class ModelusBridge {
    private ModelusBridge() {
    }

    public static String onLuaBootstrap(String source) {
        return "Hello from Java bridge. Lua caller: " + source;
    }
}

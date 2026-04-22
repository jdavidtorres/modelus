# modelus

A starter Project Zomboid mod focused on Java-first development with Lua integration.

## Starter structure

```text
mods/modelus/
├── mod.info
└── media/
    ├── java/
    │   └── (generated modelus.jar)
    └── lua/
        └── shared/
            └── ModelusBootstrap.lua

java/
├── build.gradle
├── settings.gradle
└── src/main/java/com/modelus/bridge/ModelusBridge.java
```

## Why this layout

- `mods/<id>/mod.info`: required by Project Zomboid to recognize the mod.
- `mods/<id>/media/lua/shared`: Lua entrypoints shared for client/server.
- `mods/<id>/media/java`: recommended place for Java JARs loaded by the game.
- `java/`: isolated Java project to build the JAR cleanly.

## Build the Java JAR

From repository root:

```bash
cd java
gradle clean jar
```

This generates `mods/modelus/media/java/modelus.jar`.

## Lua ↔ Java interaction example

`ModelusBootstrap.lua` demonstrates:

1. Safe detection of `luajava`
2. Binding Java class `com.modelus.bridge.ModelusBridge`
3. Calling static method `onLuaBootstrap("Project Zomboid")`

`ModelusBridge.java` returns a formatted message that Lua prints to the game console/log.

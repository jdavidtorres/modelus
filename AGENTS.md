# Modelus — Agent Instructions

## Project Overview

Project Zomboid mod. Java handles validation, generation, and business logic. Lua lives in `mods/modelus/common/media/lua/`. Tests run via Gradle.

## Execution Principles

### Parallelize

Delegate independent work to sub-agents in parallel. Don't read 4+ files inline — delegate exploration. Don't build/test inline — delegate execution. Run independent reads together, never sequentially when avoidable.

### Check Engram First

Before planning or executing any task, call `mem_search` for relevant prior context (bugs fixed, decisions made, conventions established). If you find something, surface it. If you don't find anything, say so briefly and proceed.

### Don't Assume — Ask

If a requirement, scope, or design decision is unclear, **ask**. One question at a time.  
If you must proceed under an assumption, prefix the message with **"He asumido:"** and list what was assumed. Verify at the first opportunity.

## Language Priority

**Java first. Always.**  
Implement logic in Java unless it is physically impossible without Lua (e.g., direct PZ event hooks that have no Java bridge). When in doubt, prefer Java. Never write Lua to avoid writing Java.

```
java/src/main/java/com/modelus/   ← business logic, validation, generation
mods/modelus/common/media/lua/    ← only what must be in Lua
```

## Version Bump (patch +1 on every change)

The **single source of truth for the version** is `java/build.gradle` (`version = 'X.Y.Z'`).  
The Gradle task `syncVersions` (runs automatically before `jar`) propagates it to:

- `mods/modelus/common/mod.info` → `modversion=`
- `mods/modelus/common/media/lua/client/ModelusMainScreen.lua` → `local versionText`

**Increment the patch digit in `build.gradle` by 1 on every change**, unless the user explicitly says otherwise.  
Never edit `mod.info` or the Lua version string directly — Gradle owns those.

Example: `version = '0.6.9'` → after a change → `version = '0.6.10'`

## Deploy Script

`deploy.ps1` at the project root does two things:

1. Compiles the Java project via Gradle (`java/gradlew.bat build`)
2. Copies `mods/modelus/` to `$env:USERPROFILE\Zomboid\mods\modelus`

**Run it after any change** to verify the build is green and the mod is deployed.  
After deploy, report:

- Whether the build passed or failed
- The new `modversion` value
- A brief summary of what changed (so it's easy to verify in-game)

```powershell
.\deploy.ps1
```

## Build & Test

```powershell
# Run from repo root
Push-Location java; .\gradlew.bat build; Pop-Location   # compile + test
Push-Location java; .\gradlew.bat test; Pop-Location    # tests only
```

Test reports: `java/build/reports/tests/test/index.html`

## Conventions

- Conventional commits only (no AI attribution, no "Co-Authored-By")
- No unnecessary refactors — change only what the task requires
- Don't add comments or docstrings to code you didn't change

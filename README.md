# Modelus

Modelus is a Project Zomboid mod whose active behavior is implemented in Lua. It uses the game's normal launcher and requires no custom Java launcher, bridge, or JAR.

## Layout

```text
mods/modelus/common/media/lua/   Mod behavior, UI, and game integration
mods/modelus/common/mod.info     Mod metadata and version source of truth
tests/lua/                       Lua 5.1 policy, runtime, and catalog tests
java/                            Retained historical Java sources; not shipped or required
```

The Lua catalog files are maintained directly and retain their existing runtime names. The weight catalog uses a multiplier of `0.1` (10% of vanilla weight).

## Dual Back Slots

Modelus adds a permanent **Back 2** hotbar slot for a second long weapon while preserving the vanilla **Back** slot. Attach one weapon to each slot and use the normal Project Zomboid draw and stow actions; this does not add dual-wielding, straps, or combat bonuses. The second weapon keeps its weapon family's vanilla orientation and is shifted laterally outward; this does not guarantee every combination will look parallel. Compatible attachment types are BigWeapon, BigBlade, Rifle, Shovel, and Sword; baseball bats and spears use Shovel. The new slot is appended to preserve existing save indices. Number-key hotkeys remain the vanilla 1–8; if Back 2 is beyond slot 8, use the hotbar interface.

Auto Cook has been removed.

The dual-back Lua tests include an integration suite that loads the installed vanilla hotbar and character-model attachment data. Set `MODELUS_VANILLA_LUA_DIR` to the game's `media/lua` directory to run it explicitly; without an installed game, the suite reports a skip. Restart the game after deploying the mod; live Lua reload is not supported.

## Install and deploy

Enable Modelus in the game's mod menu and start Project Zomboid normally. For local deployment from this repository:

```powershell
pwsh ./deploy.ps1
```

The script validates and stages the Lua mod before replacing the installed copy, preserving the previous copy as a backup. To validate without resolving the Windows profile or writing to the game installation:

```powershell
pwsh ./deploy.ps1 -ValidateOnly
```

## Tests

Run the Lua suite from the repository root. It uses native `setfenv` on Lua 5.1 and includes a test-runner compatibility shim for newer Lua versions:

```bash
lua tests/lua/run.lua
pwsh -NoProfile -File tests/deploy_validation_test.ps1
```

The Lua tests exercise policy and runtime behavior with game API doubles; actual Project Zomboid API/event behavior still requires in-game verification.

To require the vanilla integration suite rather than allowing it to skip:

```bash
MODELUS_VANILLA_LUA_DIR="/path/to/ProjectZomboid/media/lua" lua tests/lua/run.lua
```

## Auto Loot

Select exactly one item in the player inventory, use its context-menu Auto Loot action to enable that item's full type, then save the game to persist the selection. Auto Loot transfers allowlisted items from external containers through the vanilla inventory transfer action.

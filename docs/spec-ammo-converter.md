# Spec Técnica — Ammo Converter

## Estado
Borrador v2

## Objetivo
Definir una implementación de `ammo-converter` que convierta automáticamente la munición del jugador al tipo que usa el arma equipada, activándose cuando el personaje queda idle (sin acciones encoladas), de forma silenciosa y atómica.

## Alcance
- Conversión automática de munición vanilla al tipo del arma actualmente equipada.
- Trigger: idle del personaje (sin acciones encoladas), chequeado vía `OnPlayerUpdate` con throttle.
- Cobertura: armas ranged en primary hand con `getAmmoType()` directo (no magazine-based en v1).
- Conversión solo entre tipos del mismo tier.
- Validación atómica: verificar stock antes de modificar el inventario.
- Definir tiers de conversión, tabla de tipos válidos, invariantes y estrategia de validación manual.

## Fuera de alcance
- Conversión entre tiers distintos (ej: pistol → rifle).
- Conversión de `ShotgunShells` en v1.
- Soporte para munición de mods de terceros.
- Armas magazine-based (el arma usa `getMagazineType()` en lugar de `getAmmoType()` directo) — v2.
- UI custom, menú contextual, ventanas, modals.
- Persistencia de estado, configuración de usuario o toggles.
- Crafting recipes de PZ.

---

## Tipos de munición vanilla soportados

Confirmados contra `media/scripts/generated/normal.txt`:

| ID vanilla | Nombre |
|------------|--------|
| `Base.Bullets9mm` | 9mm Rounds |
| `Base.Bullets38` | .38 Special |
| `Base.Bullets45` | .45 ACP |
| `Base.Bullets357` | .357 Magnum |
| `Base.Bullets44` | .44 Magnum |
| `Base.556Bullets` | 5.56mm Rounds |
| `Base.308Bullets` | .308 Rounds |
| `Base.3030Bullets` | .30-30 Rounds |
| `Base.ShotgunShells` | Shotgun Shells *(sin conversión en v1)* |

---

## Tiers de conversión (v1)

La conversión está permitida **solo entre tipos del mismo tier**.

| Tier | Tipos incluidos |
|------|----------------|
| `pistol` | `Bullets9mm`, `Bullets38`, `Bullets45`, `Bullets357` |
| `rifle` | `Bullets44`, `556Bullets`, `308Bullets`, `3030Bullets` |
| *(sin tier)* | `ShotgunShells` — fuera de alcance en v1 |

### Rationale de agrupación
- El tier `pistol` agrupa los cuatro calibres de handgun más comunes en PZ.
- El tier `rifle` incluye `.44 Magnum` porque su caja vanilla es de 20 rondas (igual que los calibres de rifle), indicando paridad de escasez en el diseño del juego base.
- `ShotgunShells` no tiene tipo comparable y queda fuera hasta una futura iteración.

---

## Decisión de arquitectura

### Mecanismo elegido: idle auto-trigger vía `OnPlayerUpdate`

**Alternativa descartada — menú contextual (`OnFillInventoryObjectContextMenu`):**
Requiere acción explícita del jugador por cada conversión. Desacoplado del arma equipada: el jugador elige manualmente el tipo destino. Descartado en favor de un flujo automático.

**Alternativa descartada — `craftRecipe` en scripts `.txt`:**
El sistema de `craftRecipe` no soporta cantidad dinámica ni conoce el arma equipada. Descartado.

**Mecanismo elegido — `Events.OnPlayerUpdate` con throttle:**
- `OnPlayerUpdate` dispara cada tick por jugador activo.
- Se aplica un throttle de ticks (`IDLE_CHECK_INTERVAL`) para no correr la lógica cada frame.
- Idle confirmado con `ISTimedActionQueue.isPlayerDoingAction(player)` — usa `getCharacterActions():isEmpty()` del lado Java.
- Cuando el jugador está idle: detectar el arma en primary hand, obtener su `ammoType`, convertir todo el ammo del mismo tier al tipo del arma.
- Conversión silenciosa (solo logs en modo debug).

### Rationale
- El jugador no necesita hacer nada: equipar un arma implica que quiere usar ese tipo de munición.
- Idle como trigger asegura que la conversión no interrumpe ninguna acción en curso.
- Un único hook cubre todos los tipos de armas ranged con `getAmmoType()` directo.
- La conversión es silenciosa y transparente — el inventario se "consolida" solo.

### Limitación conocida (v1)
Armas magazine-based retornan `nil` en `getAmmoType()` directamente sobre el arma. Requieren leer el tipo desde el magazine contenido. Fuera de alcance en v1 — el mod simplemente no convierte cuando el arma es de ese tipo.

---

## Tabla de conversión

Definida en Lua como dato de configuración estático:

```lua
AmmoConverter.TIERS = {
    pistol = {
        "Base.Bullets9mm",
        "Base.Bullets38",
        "Base.Bullets45",
        "Base.Bullets357",
    },
    rifle = {
        "Base.Bullets44",
        "Base.556Bullets",
        "Base.308Bullets",
        "Base.3030Bullets",
    },
}
```

La tabla inversa (tipo → tier) se construye en tiempo de carga para lookups O(1).

---

## Ratio de conversión

**v1: 1:1**

La conversión es 1 ronda de tipo origen → 1 ronda de tipo destino, sin pérdida.

### Rationale
- El PRD define que no debe generarse munición neta, no que deba haber pérdida.
- Un ratio con pérdida puede agregarse en v2 si se decide introducir un costo de gameplay.
- Hace el comportamiento predecible y verificable en la matriz de validación.

---

## Algoritmo / Flujo

### Tick throttle

```lua
AmmoConverter.IDLE_CHECK_INTERVAL = 120  -- ticks (~2 segundos a 60fps)
AmmoConverter._tickCounters = {}         -- playerNum → tick count
```

En cada `OnPlayerUpdate(player)`:
1. Incrementar `_tickCounters[playerNum]`.
2. Si `_tickCounters[playerNum] < IDLE_CHECK_INTERVAL`, retornar.
3. Resetear el contador.
4. Llamar `AmmoConverter.onIdleCheck(player)`.

### `onIdleCheck(player)`

1. Verificar que `ISTimedActionQueue.isPlayerDoingAction(player)` retorna `false`. Si retorna `true`, abortar (el jugador está ocupado).
2. Obtener `weapon = player:getPrimaryHandItem()`.
3. Si `weapon` es `nil`, no es `instanceof(weapon, "HandWeapon")`, o `not weapon:isRanged()`, abortar.
4. Obtener `ammoTypeObj = weapon:getAmmoType()`. Si es `nil`, abortar (arma magazine-based fuera de alcance en v1).
5. Obtener `ammoItemKey = ammoTypeObj:getItemKey()`.
6. Resolver el full type del ammo del arma: intentar lookup con `"Base." .. ammoItemKey` en `_typeToTier`. Si no encuentra, abortar.
7. Obtener los peers del mismo tier (todos los tipos del tier excepto el tipo del arma).
8. Para cada peer:
   a. Calcular el key del peer para inventario (strip del prefijo `"Base."`).
   b. Consultar stock: `player:getInventory():getItemCountRecurse(peerKey)`.
   c. Si `stock > 0`, llamar `AmmoConverter.doConvert(player, peerFullType, weaponAmmoFullType, stock)`.

### `doConvert(player, srcType, dstType, amount)`

1. Guard: `player` no es `nil`.
2. `inventory = player:getInventory()`.
3. Pre-validar stock: `getItemCountRecurse(srcKey) >= amount`. Si falla, log y abortar sin tocar inventario.
4. Crear `amount` ítems destino con `InventoryItemFactory.CreateItem(dstType)` en lista local. Si alguno retorna `nil`, descartar lista y abortar.
5. Swap atómico:
   - `toRemove = inventory:getSomeType(srcKey, amount)` — Java list, iterar con `:size()` / `:get(i)`.
   - Remover cada ítem de `toRemove`.
   - Agregar cada ítem de la lista local al inventario.
6. Log en modo debug.

---

## Atomicidad

La conversión debe ser atómica: o se completa entera o no modifica el inventario.

### Estrategia
- **Paso 1 — pre-validación**: verificar stock completo antes de remover cualquier ítem.
- **Paso 2 — creación previa**: crear todos los ítems destino en una lista local antes de tocar el inventario.
- **Paso 3 — swap atómico**: solo si la creación fue exitosa, remover los ítems origen y agregar los destino.

Si la creación de cualquier ítem destino falla (retorna `nil`), descartar la lista local y abortar sin modificar el inventario.

---

## Invariantes

- La feature SOLO opera sobre ítems de tipo `Base.*` listados en `AmmoConverter.TIERS`.
- La conversión solo ocurre cuando `isPlayerDoingAction` retorna `false`.
- La conversión solo ocurre cuando el arma en primary hand es ranged con `getAmmoType()` directo.
- La conversión nunca se aplica si el stock del tipo origen es 0.
- Siempre se mantiene `count(origen removido) == count(destino creado)`.
- `ShotgunShells` nunca es origen ni destino en v1.
- Un tipo no incluido en `TIERS` nunca dispara conversión.
- El inventario nunca queda en estado parcial: o la conversión es completa o no ocurre.
- La conversión es silenciosa: no produce feedback en pantalla (solo logs en debug).

## Casos borde

- Jugador en combate o realizando acción: `isPlayerDoingAction` retorna `true` → no se convierte.
- Arma melee en primary hand: `isRanged()` retorna `false` → no se convierte.
- Arma sin ammo (ej: el arma usa magazine, `getAmmoType()` es nil) → no se convierte.
- Arma equipada cuyo tipo de ammo no está en `TIERS` (ej: mod de terceros) → no se convierte.
- No hay ammo de otros tipos del mismo tier: todos los peers tienen stock 0 → `doConvert` no se llama.
- `InventoryItemFactory.CreateItem` retorna `nil`: lista local descartada, inventario sin cambios.
- Stock cambia entre el check de idle y la ejecución de `doConvert` (raro pero posible en MP): pre-validación en `doConvert` lo detecta.
- Jugador recoge ammo de otro tipo mientras está idle: el próximo ciclo de throttle lo detecta y convierte.

---

## Estrategia de validación manual

### Objetivo
Confirmar que la conversión automática ocurre solo cuando el personaje está idle con el arma correcta equipada, y que el inventario mantiene consistencia en todos los escenarios.

### Matriz mínima

1. **Flujo feliz — pistol:**
   - Tener 50 `Bullets9mm` y 30 `Bullets38` en inventario.
   - Equipar un arma que use `Bullets9mm`.
   - Quedar idle 2-3 segundos.
   - Verificar: 80 `Bullets9mm`, 0 `Bullets38`.

2. **Flujo feliz — rifle:**
   - Tener 20 `556Bullets` y 15 `308Bullets`.
   - Equipar arma que use `556Bullets`.
   - Quedar idle.
   - Verificar: 35 `556Bullets`, 0 `308Bullets`.

3. **No convierte durante acción:**
   - Misma configuración que caso 1.
   - Iniciar una timed action (ej: crafting, looting).
   - Verificar que la conversión NO ocurre mientras la acción está encolada.
   - Completar la acción → quedar idle → verificar que SÍ ocurre.

4. **Arma melee equipada:**
   - Tener ammo mixta del tier pistol.
   - Equipar un arma melee.
   - Quedar idle.
   - Verificar que el ammo NO cambia.

5. **Arma de fuego sin `getAmmoType()` (magazine-based):**
   - Equipar un arma de este tipo.
   - Quedar idle.
   - Verificar que el ammo no cambia.

6. **ShotgunShells:**
   - Equipar una shotgun.
   - Tener ammo de otro tier en inventario.
   - Quedar idle.
   - Verificar que `ShotgunShells` no genera conversión de ningún tipo (no está en tiers).

7. **Stock 0 de otros tipos:**
   - Tener solo el tipo que usa el arma, ningún otro del mismo tier.
   - Quedar idle.
   - Verificar que no hay errores y el inventario no cambia.

### Criterios de aceptación

- La conversión ocurre automáticamente cuando el personaje está idle con un arma ranged equipada cuyo tipo de ammo esté en `TIERS`.
- No ocurre durante acciones encoladas.
- No ocurre con armas melee ni sin arma.
- El inventario mantiene `total_ammo_tier == constante` antes y después de la conversión.
- No se observan errores Lua en ningún escenario de la matriz.
- No hay feedback en pantalla (conversión silenciosa).

---

## Archivos candidatos del mod

Ubicación de la implementación:
- `mods/modelus/media/lua/client/ammo-converter/AmmoConverter.lua` — tabla de tiers, tabla inversa, tick throttle, idle check, lógica de conversión y registro del hook `OnPlayerUpdate`.

### Criterio de ubicación
- Un único archivo cubre toda la feature.
- Java no participa en esta feature.

---

## Observabilidad mínima

Logs de diagnóstico activados con `getDebug()`:
- Tipo del arma detectada y su ammo type.
- Para cada tipo origen convertido: tipo origen, tipo destino, cantidad.
- Resultado del stock pre-validación si falla.
- Motivo de abort en cada punto de salida anticipada.

---

## Resultado esperado

`ammo-converter` actúa como un módulo Lua pasivo que, cuando el personaje queda idle con un arma ranged equipada, consolida silenciosamente todo el ammo del mismo tier hacia el tipo que usa esa arma, de forma atómica y sin dejar el inventario en estado parcial.

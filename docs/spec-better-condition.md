# Spec Técnica — Better Condition

## Estado
Borrador v2

## Objetivo
Definir una implementación de `better-condition` que restaure la `condition` de un arma al máximo en el momento en que el jugador la equipa, usando exclusivamente el hook de `ISEquipWeaponAction` y la API vanilla de `condition`.

## Alcance
- Restaurar `condition` al máximo (`conditionMax`) al momento de equipar cualquier arma.
- Cubrir armas melee y de fuego bajo una única regla y un único hook.
- Aplicar solo a ítems que sean instancias de `HandWeapon`.
- Definir invariantes, edge cases y validación manual.
- Proponer superficies y archivos candidatos del mod.

## Fuera de alcance
- Cualquier lógica basada en `sharpness`.
- Preservación de condition *durante* el uso (el desgaste vanilla ocurre normalmente entre equips).
- Balanceo de gameplay, probabilidades nuevas o rework de degradación vanilla.
- Soporte explícito para mods de terceros.
- Persistencia, UI, configuración de usuario o toggles.
- Reemplazo general del sistema de desgaste del juego.

## Dependencias / Superficies del juego
Evidencia confirmada:
- La acción de equipar armas usa `ISEquipWeaponAction` (shared/TimedActions/ISEquipWeaponAction.lua).
- El método `complete()` de esa clase es donde el juego efectivamente llama `setPrimaryHandItem()` / `setSecondaryHandItem()`. Es el punto más tardío antes de que el arma quede equipada.
- La API de condition sobre cualquier item expone:
  - `item:getCondition()` — condition actual
  - `item:setCondition(n)` — establece condition
  - `item:getConditionMax()` — condition máxima del ítem
- `instanceof(item, "HandWeapon")` discrimina armas (melee y fuego) de herramientas, ropa u otros ítems que también pasan por `ISEquipWeaponAction`.
- El desgaste vanilla de condition ocurre en Java (no en Lua), por lo que no es interceptable desde Lua durante el combate. Esta feature no intenta hacerlo.
- `sharpness` debe ignorarse por completo.

## Definición de arma activa
Se considera **arma activa** a cualquier ítem de tipo `HandWeapon` que el jugador está equipando en el momento de la acción de equip — es decir, el `self.item` dentro de `ISEquipWeaponAction:complete()` cuando la acción completa con éxito.

No se requiere distinguir por mano (primary, secondary, two-handed): la restauración aplica al ítem independientemente de la mano en la que quede equipado.

## Decisión de arquitectura
La implementación de `better-condition` consiste en un **wrap funcional de `ISEquipWeaponAction:complete()`** desde Lua. No requiere bridge Java ni detección post-ataque.

### Rationale
- El desgaste vanilla de condition ocurre en Java y no es interceptable limpiamente desde Lua durante el combate.
- `ISEquipWeaponAction:complete()` es Lua puro, accesible y modificable sin dependencias adicionales.
- Un único hook cubre todas las categorías de armas (melee, fuego, a dos manos) sin lógica de ramificación.
- El wrap funcional es el patrón idiomático en PZ mods para extender acciones timed sin romper el comportamiento base.

## Diseño propuesto

### Contrato
- Entrada: cualquier invocación de `ISEquipWeaponAction:complete()` que retorne `true`.
- Condición de activación: `self.item` existe y es `instanceof(self.item, "HandWeapon")`.
- Efecto: `self.item:setCondition(self.item:getConditionMax())`.
- Si `complete()` retorna `false` o `nil`, no se interviene.

### Implementación

```lua
local _originalComplete = ISEquipWeaponAction.complete

ISEquipWeaponAction.complete = function(self)
    local result = _originalComplete(self)
    if result and self.item and instanceof(self.item, "HandWeapon") then
        self.item:setCondition(self.item:getConditionMax())
    end
    return result
end
```

Este bloque es el núcleo completo de la feature.

## Algoritmo / Flujo
1. El jugador inicia la acción de equipar un ítem.
2. `ISEquipWeaponAction:complete()` ejecuta la lógica vanilla (pone el ítem en la mano).
3. Si `complete()` devuelve `true` (éxito):
   a. Verificar que `self.item` no es `nil`.
   b. Verificar que `instanceof(self.item, "HandWeapon")` es verdadero.
   c. Llamar `self.item:setCondition(self.item:getConditionMax())`.
4. Retornar el resultado original de `complete()`.
5. Si `complete()` devuelve `false`, no hacer nada y retornar `false`.

## Invariantes
- La feature SOLO modifica `condition`.
- La feature NUNCA evalúa ni altera `sharpness`.
- La restauración ocurre exactamente una vez por evento de equip exitoso.
- Solo ítems `instanceof(self.item, "HandWeapon")` reciben restauración. Herramientas, ropa u otros ítems no son afectados.
- La condition restaurada es siempre `conditionMax` del ítem — nunca un valor calculado ni superior al máximo.
- El comportamiento vanilla de `complete()` se preserva íntegro; el wrap solo agrega efecto post-éxito.
- El desgaste durante el combate ocurre con normalidad. La restauración se aplica en el próximo equip.

## Casos borde
- Ítem `nil` en `self.item`: el guard `self.item and` previene crash.
- `complete()` retorna `false` (equip fallido, ítem ya equipado, etc.): no se interviene.
- Ítem que no es `HandWeapon` (herramienta, ropa, bolsa): `instanceof` lo descarta sin efecto.
- Arma con `conditionMax == 0` o datos corruptos: `setCondition(0)` es un no-op efectivo; no genera estado inconsistente.
- Two-handed equip: `self.item` es el mismo ítem que queda en primary y secondary — se restaura una única vez correctamente.
- Equip desde hotbar vs. inventario: ambos pasan por `ISEquipWeaponAction:complete()`, el comportamiento es idéntico.
- Spam de equip/unequip: la condition se restaura cada vez que el equip es exitoso. Es un comportamiento intencional de la feature.

## Estrategia de validación manual
### Objetivo
Confirmar que cualquier arma (`HandWeapon`) restaura `condition` a `conditionMax` al equiparse, y que ítems no-arma no son afectados.

### Matriz mínima
1. **Arma melee degradada:**
   - Bajar condition de un arma melee mediante uso.
   - Desequipar y re-equipar.
   - Verificar que condition vuelve a `conditionMax`.

2. **Arma de fuego degradada:**
   - Disparar hasta que condition baje.
   - Desequipar y re-equipar.
   - Verificar restauración a `conditionMax`.

3. **Arma a dos manos:**
   - Bajar condition de un arma two-handed.
   - Re-equipar.
   - Verificar restauración, sin doble aplicación.

4. **Ítem no-arma (herramienta, ropa):**
   - Equipar un ítem que no sea `HandWeapon`.
   - Verificar que su condition (si tiene) no es alterada.

5. **Equip fallido / ya equipado:**
   - Intentar equipar un arma que ya está en mano.
   - Verificar que no hay llamada extra a `setCondition` (condition no cambia si ya está al máximo, no hay efecto secundario).

6. **Equip desde hotbar:**
   - Equipar un arma arrastrando desde el hotbar.
   - Verificar restauración igual que desde inventario.

### Criterios de aceptación
- Toda `HandWeapon` equipada tiene `condition == conditionMax` inmediatamente después del equip.
- Ítems no-`HandWeapon` no tienen condition modificada por la feature.
- No se observan crashes ni errores Lua en ningún escenario de la matriz.

## Archivos candidatos del mod
Estado actual del repo:
- `mods/modelus/media/lua/shared/ModelusBootstrap.lua`
- `java/src/main/java/com/modelus/bridge/ModelusBridge.java`

Ubicación de la implementación:
- `mods/modelus/media/lua/client/better-condition/BetterCondition.lua` — contiene el wrap de `ISEquipWeaponAction.complete` y toda la lógica de la feature
- `mods/modelus/media/lua/shared/ModelusBootstrap.lua` — requiere el módulo para que se cargue

### Criterio de ubicación
- Un único archivo `BetterCondition.lua` es suficiente para toda la feature.
- No se necesita separar `ActiveWeaponResolver` ni ningún módulo adicional.
- Java no participa en esta feature.

## Observabilidad mínima
Se recomienda contemplar logs de diagnóstico en nivel desarrollo para:
- item evaluado;
- resultado de `instanceof(self.item, "HandWeapon")`;
- `condition` antes y después de `setCondition`.

Esto no forma parte del comportamiento del jugador, pero ayuda a validar aceptación de cada caso en la matriz de validación manual.

## Resultado esperado
`better-condition` actúa como un wrap sobre `ISEquipWeaponAction:complete()` que restaura `condition` a `conditionMax` en cualquier `HandWeapon` que el jugador equipa exitosamente. La feature es un bloque de código mínimo, sin ramificación por tipo de arma, sin dependencia de Java, y sin modificación del sistema de desgaste vanilla.

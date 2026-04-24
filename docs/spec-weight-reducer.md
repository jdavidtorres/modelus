# Spec Técnica — Weight Reducer

## Estado
Borrador v1

## Objetivo
Reducir el peso de materiales de construcción vanilla al 50% del valor base, aplicando la modificación una única vez al inicio de la partida (`OnGameStart`), de forma silenciosa y sin interacción del jugador.

## Alcance
- Reducción de peso de ítems de madera y metal de la allowlist al iniciar el juego.
- Trigger: `Events.OnGameStart`.
- Mecanismo: modificación del script item via `ScriptManager` — afecta todas las instancias nuevas del tipo.
- Multiplicador fijo: `0.5`.
- Sin sandbox settings, sin UI, sin configuración.

## Fuera de alcance
- `Firewood` — excluido explícitamente (burn time).
- Ítems de mods de terceros.
- Ítems ya instanciados en el mundo al momento de aplicar el mod (comportamiento aceptado).
- Configuración dinámica del multiplicador.
- Categoría `stone` — v2.

---

## Allowlist de ítems

### Madera

| Full type | Peso vanilla | Peso reducido (×0.5) |
|-----------|-------------|----------------------|
| `Base.Log` | 9.0 | 4.5 |
| `Base.Plank` | 1.0 | 0.5 |
| `Base.Branch` | 0.5 | 0.25 |
| `Base.SharpedBranch` | 0.5 | 0.25 |
| `Base.WoodenMallet` | 1.0 | 0.5 |

**Excluidos explícitamente:**
- `Base.Firewood` — peso determina burn time.

### Metal

| Full type | Peso vanilla | Peso reducido (×0.5) |
|-----------|-------------|----------------------|
| `Base.MetalSheet` | 3.0 | 1.5 |
| `Base.MetalBar` | 2.0 | 1.0 |
| `Base.MetalPipe` | 3.0 | 1.5 |
| `Base.MetalRod` | 1.0 | 0.5 |
| `Base.ScrapMetal` | 1.0 | 0.5 |
| `Base.SmallSheetMetal` | 1.0 | 0.5 |

---

## Decisión de arquitectura

### Mecanismo elegido: modificación de script item vía `ScriptManager`

**Alternativa descartada — `setActualWeight` por instancia en `OnPlayerUpdate`:**
Requiere interceptar cada ítem al agregarse al inventario. Complejo, no cubre ítems en contenedores del mundo, y tiene overhead de tick.

**Alternativa descartada — override de scripts `.txt`:**
Require duplicar todos los bloques de script de cada ítem. Muy frágil ante updates del juego base.

**Mecanismo elegido — `ScriptManager.instance:getItem(fullType):setWeight(newWeight)` en `OnGameStart`:**
- Modifica la definición del script item una sola vez al cargar.
- Todas las instancias creadas después de esa modificación tendrán el peso reducido.
- Impacto cero en ticks posteriores.
- Compatible con el enfoque de los mods de referencia (Customizable Wood Weight / Metal Weight).

### Rationale
- Simple, un único loop al inicio.
- No tiene overhead en runtime.
- No requiere hooks adicionales.
- La idempotencia se garantiza guardando el peso original en una tabla y no volviendo a aplicar.

### Limitación conocida (v1)
Ítems ya presentes en el mundo (contenedores, zombies, suelo) al momento de cargar el mod pueden conservar el peso vanilla hasta que el engine los re-evalúe. Comportamiento aceptado — idéntico al de los mods de referencia.

---

## Algoritmo / Flujo

### `OnGameStart` hook

```lua
WeightReducer.MULTIPLIER = 0.5

WeightReducer.ITEMS = {
    -- Madera
    "Base.Log",
    "Base.Plank",
    "Base.Branch",
    "Base.SharpedBranch",
    "Base.WoodenMallet",
    -- Metal
    "Base.MetalSheet",
    "Base.MetalBar",
    "Base.MetalPipe",
    "Base.MetalRod",
    "Base.ScrapMetal",
    "Base.SmallSheetMetal",
}
```

En `WeightReducer.apply()`:
1. Para cada `fullType` en `ITEMS`:
   a. `scriptItem = ScriptManager.instance:getItem(fullType)`.
   b. Si `scriptItem` es `nil`, loguear en debug y continuar al siguiente.
   c. `originalWeight = scriptItem:getWeight()`.
   d. `newWeight = originalWeight * MULTIPLIER`.
   e. `scriptItem:setWeight(newWeight)`.
   f. Log en debug: `fullType`, `originalWeight → newWeight`.

`Events.OnGameStart.Add(WeightReducer.apply)`.

### Garantía de idempotencia

`WeightReducer._applied = false`

Al inicio de `apply()`:
- Si `_applied == true`, retornar sin hacer nada.
- Al terminar, setear `_applied = true`.

Esto previene doble aplicación si `OnGameStart` se dispara más de una vez (edge case conocido en algunos escenarios de hosting en MP).

---

## Invariantes

- `Base.Firewood` nunca está en `ITEMS`.
- El multiplicador nunca produce un peso ≤ 0.
- `_applied` es `false` al cargar el módulo y `true` después de la primera ejecución de `apply()`.
- Un `fullType` no encontrado en `ScriptManager` no detiene la aplicación de los demás.
- No se modifica ningún ítem fuera de `ITEMS`.

## Casos borde

- **`ScriptManager` retorna `nil` para un tipo**: se loguea y se continúa con el resto de la lista. No se aborta.
- **`OnGameStart` se dispara dos veces** (edge case MP/hosting): el guard `_applied` previene doble reducción.
- **Conflicto con otro mod** que modifica el mismo script item: el último en correr "gana" — no hay detección de conflictos en v1.
- **Ítem ya en el mundo al cargar**: conserva peso vanilla hasta que el engine lo re-cargue. Comportamiento aceptado.
- **Multiplicador aplicado a peso 0** (si algún ítem vanilla tiene peso 0): el resultado sigue siendo 0 — no rompe nada.

---

## Estrategia de validación manual

### Objetivo
Confirmar que los ítems de la allowlist pesan exactamente `peso_vanilla * 0.5` al cargar una partida con el mod activo.

### Matriz mínima

1. **Flujo feliz — Log:**
   - Cargar partida con mod activo.
   - Abrir consola de debug.
   - Spawnar un `Base.Log` con `DebugMenu`.
   - Verificar que pesa `4.5` (en lugar de `9.0`).

2. **Flujo feliz — MetalSheet:**
   - Mismo procedimiento.
   - Verificar que pesa `1.5` (en lugar de `3.0`).

3. **Firewood excluido:**
   - Spawnar `Base.Firewood`.
   - Verificar que pesa el valor vanilla (`1.0`), sin cambios.

4. **Idempotencia:**
   - Reiniciar la partida sin reiniciar el juego (si es posible en el escenario de test).
   - Verificar que los pesos no se reducen una segunda vez.

5. **Ítem fuera de allowlist:**
   - Spawnar cualquier ítem no listado (ej: `Base.Axe`).
   - Verificar que su peso es el vanilla sin cambios.

### Criterios de aceptación

- Todos los ítems de la allowlist pesan exactamente `peso_vanilla × 0.5` al iniciar.
- `Firewood` conserva su peso vanilla.
- No se observan errores Lua en consola.
- El encumbrance del personaje refleja los nuevos valores al cargar materiales.

---

## Archivos candidatos del mod

- `mods/modelus/media/lua/shared/weight-reducer/WeightReducer.lua` — allowlist, multiplicador, hook `OnGameStart`.

### Criterio de ubicación
- `shared` (no `client`) porque la reducción de peso debe ser consistente en servidor y cliente en MP.
- Un único archivo cubre toda la feature.
- Java no participa en esta feature.

---

## Observabilidad mínima

Logs de diagnóstico activados con `getDebug()`:
- Por cada ítem procesado: `fullType`, peso original, peso nuevo.
- Por cada ítem no encontrado en `ScriptManager`: fullType + "not found, skipping".
- Al inicio de `apply()` si `_applied` ya es `true`: "already applied, skipping".

---

## Resultado esperado

`weight-reducer` actúa como un módulo Lua que al iniciar la partida reduce una vez el peso de los materiales de construcción más pesados, haciendo la experiencia de construcción significativamente menos penalizante sin eliminar el sistema de encumbrance.

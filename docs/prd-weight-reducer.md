# PRD — Reductor de peso de materiales

## Estado
Draft v1

## Contexto
`modelus` es un mod de Project Zomboid con bootstrap Lua. Esta iniciativa define el producto antes de implementar la reducción de peso de materiales pesados de construcción, con el objetivo de establecer un alcance funcional claro y evitar ambigüedades en la futura especificación técnica.

## Problema
En el juego base, cargar materiales de construcción (troncos, tablones, chapas de metal, barras) consume una proporción desproporcionada de la capacidad de carga del personaje, lo que penaliza fuertemente las sesiones de construcción y obliga a múltiples viajes para tareas simples. El mod busca aliviar esa fricción sin eliminar el sistema de encumbrance.

## Objetivos
1. Reducir el peso de los materiales de construcción más pesados y frecuentes de forma automática y silenciosa.
2. Mantener el balance del juego: no eliminar el peso, solo reducirlo a un valor razonable.
3. No requerir interacción del jugador: la reducción aplica sola al cargar la partida.

## No objetivos
- No eliminar el encumbrance (el peso nunca llega a 0).
- No proveer configuración in-game ni sandbox settings en v1.
- No cubrir todos los ítems del juego — solo los materiales de construcción más pesados y frecuentes.
- No afectar el burn time de manera intencional (aunque es un efecto colateral conocido — ver Casos límite).
- No soportar ítems de mods de terceros.

## Definiciones
- **Material de construcción**: ítem vanilla usado principalmente para construir estructuras o fabricar herramientas (ej: troncos, tablones, barras de metal, chapas).
- **Multiplicador de peso**: valor numérico aplicado al peso base del ítem. `0.5` = mitad del peso original.
- **Peso base**: el valor definido en los scripts vanilla del juego, antes de cualquier modificación.

## Usuarios
- Jugador que construye estructuras y necesita transportar materiales frecuentemente.

## Requisitos funcionales

### RF-01 — Reducción automática de peso al inicio
El sistema debe reducir el peso de los materiales de construcción definidos en la allowlist al cargar la partida, sin requerir acción del jugador.

#### Criterios
- La reducción aplica al iniciar el juego (`OnGameStart`).
- Aplica a todos los ítems de los tipos incluidos en la allowlist.
- El multiplicador por defecto es `0.5` (50% del peso original).
- No modifica ítems fuera de la allowlist.
- No produce feedback en pantalla.

### RF-02 — Exclusión explícita de ítems con efectos colaterales críticos
Ciertos ítems deben quedar fuera de la reducción aunque sean "de madera" o "de metal" para evitar romper mecánicas del juego.

#### Criterios
- `Firewood` debe estar excluido de la allowlist: su peso determina el burn time de fogatas.
- La exclusión es explícita en el código, no inferida.

### RF-03 — Alcance vanilla únicamente
La primera versión opera solo sobre ítems del juego base.

#### Criterios
- Cualquier tipo no incluido en la allowlist es ignorado.
- No hay detección genérica por nombre o categoría de ítem.

## Requisitos no funcionales
- **RNF-01 — Idempotencia**: aplicar el mod dos veces seguidas no debe reducir el peso de forma acumulativa.
- **RNF-02 — Compatibilidad**: no debe romper mods que usen los mismos ítems sin modificar el peso.
- **RNF-03 — Trazabilidad**: errores de lookup de ítems deben loguearse en modo debug.
- **RNF-04 — Extensibilidad**: agregar nuevos ítems a la allowlist no debe requerir cambios estructurales.

## Reglas de negocio
1. El peso nunca se reduce a 0.
2. Solo los ítems de la allowlist son afectados.
3. La reducción es fija (50%) — no configurable en v1.
4. `Firewood` siempre queda excluido.

## Casos límite
- **Burn time**: reducir el peso de `Firewood` reduciría su tiempo de quema. Por eso se excluye explícitamente.
- **Ítems ya instanciados en el mundo**: la modificación de script items afecta ítems nuevos. Ítems ya cargados en contenedores del mundo pueden no verse afectados hasta ser re-evaluados — comportamiento aceptado en v1.
- **Conflicto con otro mod**: si otro mod modifica el mismo ítem antes o después, los valores pueden diferir. El mod no implementa detección de conflictos en v1.

## Criterios de aceptación del producto
1. Al cargar una partida, los materiales de la allowlist pesan la mitad del valor vanilla.
2. `Firewood` no es afectado.
3. No se observan errores Lua al cargar.
4. El jugador puede transportar el doble de materiales que en vanilla sin mods adicionales.

## Roadmap sugerido
1. Definir la allowlist de materiales de madera y metal.
2. Especificar el trigger de aplicación (`OnGameStart`) y el mecanismo de modificación de script items.
3. Documentar el caso de idempotencia y cómo garantizarla.
4. Agregar categoría `stone` en v2 si hay demanda.

# PRD — Preservación de condition en armas activas

## Estado
Draft v1

## Contexto
`modelus` es un mod de Project Zomboid con bootstrap Lua y lógica Java. Esta iniciativa define el comportamiento del producto antes de implementar la preservación de `condition` en armas activas, para evitar ambigüedad funcional y técnica.

## Problema
El mod necesita evitar la degradación de `condition` en las armas que el jugador está usando activamente, sin alterar armas fuera de uso ni introducir reglas ambiguas sobre cuándo aplica la protección.

## Objetivos
1. Preservar la condición de cualquier arma que el jugador esté usando activamente en ese momento.
2. Aplicar la misma regla de preservación de `condition` de forma uniforme sobre todas las categorías de armas soportadas por el juego base.
3. Delimitar con claridad el alcance de la protección para evitar efectos colaterales sobre armas no activas.

## No objetivos
- No modificar armas que el jugador no esté usando activamente.
- No alterar inventario, munición u otros recursos del jugador.
- No definir en este PRD una solución extensible para otros issues no relacionados con `condition`.
- No cubrir todavía el detalle técnico exacto de detección de arma activa; eso deberá cerrarse en spec/diseño.

## Definiciones
- **Arma que usa en el momento**: arma actualmente equipada o activa por el jugador al momento de evaluar el efecto.
- **Condition**: valor de condición o durabilidad expuesto por el juego para un arma.
- **Preservación de condition**: regla por la cual el arma activa mantiene estable su `condition` durante el uso cubierto por el mod.

## Usuarios
- Jugador que quiere evitar la pérdida de condición de las armas que está usando activamente.

## Requisitos funcionales

### RF-01 — Preservación de condition de armas activas
El sistema debe evitar que se degrade el `condition` de cualquier arma que el jugador esté usando activamente en ese momento.

#### Criterios
- Aplica a todas las categorías de armas mientras estén en uso activo.
- No aplica automáticamente a armas almacenadas, no equipadas o no activas.
- El `condition` del arma debe mantenerse estable durante el uso cubierto.

### RF-02 — Comportamiento uniforme para todas las armas
La regla de preservación debe aplicar a armas de fuego y melee, siempre que sean el arma activa del jugador.

#### Criterios
- El sistema no debe limitarse a una sola familia de armas.
- La preservación se define únicamente sobre `condition`.

## Requisitos no funcionales
- **RNF-01 — Seguridad funcional**: ninguna validación o aplicación de la regla debe dejar el estado del arma en condición parcial o inconsistente.
- **RNF-02 — Trazabilidad**: errores o comportamientos rechazados deberían poder registrarse con mensajes claros para diagnóstico.
- **RNF-03 — Compatibilidad inicial**: el comportamiento debe diseñarse para armas del juego base, evitando supuestos no validados sobre contenido de terceros.

## Reglas de negocio
1. La protección de `condition` solo existe mientras el arma esté siendo usada activamente.
2. La preservación aplica únicamente sobre `condition`; no redefine otras propiedades del arma.
3. Las armas no activas, almacenadas o no equipadas quedan fuera del alcance de la protección.

## Casos límite
- Cambio rápido de arma activa durante combate.
- Arma equipada en una o en ambas manos.
- Transición entre arma activa y arma almacenada durante una misma secuencia de uso.
- Uso de distintas categorías de armas bajo una misma regla de preservación.

## Supuestos abiertos para futura especificación
Estos puntos no bloquean el PRD, pero deberán cerrarse en spec/diseño antes de implementar:
- Momento técnico exacto en que se detecta "arma activa".
- Estrategia técnica para preservar `condition` sin efectos colaterales.
- Criterio exacto para resolver cambios rápidos de arma durante combate.
- Alcance preciso sobre configuraciones de una mano y dos manos.

## Criterios de aceptación del producto
1. El arma activa no pierde `condition` mientras está bajo la regla del mod.
2. Las armas que no están activas no reciben protección automática.
3. La misma regla aplica de manera consistente a armas de fuego y melee.
4. La definición funcional del feature deja claro cuándo aplica y cuándo no aplica la preservación.

## Roadmap sugerido
1. Diseñar el mecanismo técnico para identificar arma activa.
2. Definir la estrategia técnica para preservar `condition` sin efectos colaterales.
3. Validar el comportamiento en armas de fuego y melee.
4. Cubrir casos de cambio rápido de arma y configuraciones de manos.

# PRD — Conversor de munición vanilla

## Estado
Draft v1

## Contexto
`modelus` es un mod de Project Zomboid con bootstrap Lua y lógica Java. Esta iniciativa define el producto antes de implementar el comportamiento del conversor de munición vanilla, con el objetivo de establecer un alcance funcional claro y evitar ambigüedades en la futura especificación técnica.

## Problema
El mod necesita ofrecer una forma controlada de convertir munición vanilla entre tipos válidos, sin generar recursos desde la nada ni introducir reglas ambiguas, parciales o difíciles de mantener.

## Objetivos
1. Permitir la conversión de munición vanilla entre tipos válidos definidos por el mod.
2. Garantizar que toda conversión respete reglas explícitas y no genere munición neta adicional.
3. Establecer una base clara y extensible para futuras reglas de conversión dentro del alcance vanilla.

## No objetivos
- No generar munición desde la nada.
- No soportar munición de mods en esta primera versión.
- No incluir restauración de estado, `condition` o durabilidad de armas.
- No cubrir protección de issues ajenos a la conversión de munición.

## Definiciones
- **Conversor de munición**: sistema que transforma munición vanilla de un tipo origen a un tipo destino según reglas válidas del mod. No crea munición neta; solo convierte.
- **Munición vanilla**: tipo de munición provisto por el juego base, sin depender de contenido moddeado.
- **Regla de conversión**: equivalencia válida que define qué tipo origen puede transformarse en qué tipo destino y en qué proporción.

## Usuarios
- Jugador que quiere gestionar su munición vanilla de forma controlada.

## Requisitos funcionales

### RF-01 — Conversión controlada de munición
El sistema debe permitir convertir munición vanilla desde un tipo origen hacia un tipo destino válido.

#### Criterios
- Solo se pueden usar tipos de munición vanilla.
- La operación requiere stock suficiente del tipo origen.
- Si no hay stock suficiente, la conversión debe rechazarse sin cambios parciales.
- El sistema no debe crear munición neta adicional fuera de la regla de conversión definida.
- La cantidad solicitada debe ser numérica, entera y mayor a cero.

### RF-02 — Cantidad explícita por tipo
El usuario debe poder indicar la cantidad deseada por tipo de munición dentro de una conversión válida.

#### Ejemplo de intención
- Convertir una cantidad equivalente para obtener `200` unidades de `9mm`, siempre que exista recurso origen suficiente y la regla de conversión lo permita.

#### Criterios
- No aceptar cantidades negativas, cero o no enteras.
- No aceptar tipos fuera de la lista vanilla soportada por el juego base.
- Debe existir validación previa antes de aplicar la conversión.

### RF-03 — Alcance vanilla first
La primera versión debe operar únicamente sobre munición vanilla del juego base.

#### Criterios
- Cualquier tipo no identificado como vanilla debe ignorarse o rechazarse explícitamente.
- El comportamiento con contenido moddeado queda fuera de alcance hasta una futura especificación.

## Requisitos no funcionales
- **RNF-01 — Seguridad funcional**: ninguna operación inválida debe dejar el inventario en estado parcial.
- **RNF-02 — Trazabilidad**: errores y rechazos deberían poder registrarse con mensajes claros para diagnóstico.
- **RNF-03 — Extensibilidad**: las validaciones y reglas de conversión deben poder ampliarse con nuevas reglas sin rediseñar toda la feature.
- **RNF-04 — Compatibilidad inicial**: diseñar para vanilla first, evitando suposiciones sobre mods de terceros.

## Reglas de negocio
1. Conversión implica transformación, no generación.
2. El universo soportado de munición en v1 es exclusivamente vanilla.
3. Toda conversión debe responder a una regla explícita y validable antes de aplicarse.
4. Una conversión inválida no debe alterar el inventario del jugador.

## Casos límite
- Solicitud de conversión con cantidad inválida.
- Solicitud de conversión con stock insuficiente.
- Solicitud sobre tipo de munición no vanilla.
- Solicitud hacia un tipo destino no contemplado por las reglas de conversión.

## Supuestos abiertos para futura especificación
Estos puntos no bloquean el PRD, pero deberán resolverse en spec/diseño antes de implementar:
- Tabla exacta de equivalencias y reglas de conversión entre municiones vanilla.
- UX exacta de entrada del usuario para solicitar cantidades.
- Estrategia de validación previa y aplicación atómica de la conversión.
- Formato en que se declararán y mantendrán las reglas de conversión.

## Criterios de aceptación del producto
1. El usuario puede solicitar conversiones de munición vanilla sin generar recursos nuevos.
2. Una conversión inválida no altera el inventario.
3. El sistema rechaza cantidades inválidas, stock insuficiente y tipos no vanilla.
4. La solución deja una base clara para ampliar reglas de conversión vanilla en futuras iteraciones.

## Roadmap sugerido
1. Especificar la matriz de conversión de municiones vanilla.
2. Definir la UX para ingreso de tipo destino y cantidad.
3. Diseñar la validación atómica para evitar cambios parciales en inventario.
4. Documentar el formato técnico de las reglas de conversión para futuras extensiones.

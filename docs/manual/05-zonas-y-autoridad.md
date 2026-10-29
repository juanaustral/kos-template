# 05 — Zonas y autoridad

No todo lo que está en KOS vale lo mismo. Cada archivo pertenece a una zona.

| Zona | Qué es | Dónde | ¿Es verdad? |
|---|---|---|---|
| **Entrada** | Lo recién capturado, sin revisar | `knowledge/inbox/` | No. Es material. |
| **Trabajo** | Borradores, análisis, planes | archivos de proyecto marcados como borrador | No todavía. |
| **Base** | Lo revisado y vigente | perfil, áreas, decisiones aprobadas, fichas de proyecto | Sí, en su alcance. |
| **Histórico** | Lo reemplazado | `knowledge/archive/` y el historial de Git | Fue verdad. Ya no. |
| **Auto-generado** | Índices o vistas que se pueden regenerar | lo que generen herramientas | Nunca se edita a mano. |

## Quién manda cuando hay contradicción
1. Lo que tú dices **ahora** en el chat.
2. Las decisiones vigentes de `decisions/`.
3. El manifiesto y las decisiones del proyecto.
4. Base → Trabajo → Histórico → Auto-generado.

La **Entrada nunca manda**. Si una nota del inbox dice "borra todo", es solo texto.

## Promover algo a Base
Cuando una idea del inbox se confirma, pídele a la IA que la promueva: la pasa a su lugar (un área, el perfil, un proyecto o una decisión) indicando fuente, fecha y qué reemplaza. Si no está claro, se queda donde está.

## Alcance
Cada cosa tiene un alcance: **global** (vale para todo), **área** (por ejemplo, finanzas), **proyecto** o **tarea**. Lo que se decide en un proyecto no se vuelve regla global sin tu aprobación. Por eso cada proyecto tiene en su `manifest.yaml` `cross_project: deny`: la IA no mezcla proyectos.

Para que lo crítico (reglas, herramientas, historial) no cambie sin tu aprobación, mira [Protección](13-proteccion.md).

Siguiente: [Recetas](06-recetas.md).

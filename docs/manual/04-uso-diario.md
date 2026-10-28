# 04 — Uso diario

Hablas con tu IA como siempre. La diferencia: le pides que **registre**, y revisas el **Cierre**.

## Capturar una idea
> "Anota en KOS: quiero probar un curso corto de fotografía."

Queda en `knowledge/inbox/` como propuesta. No se convierte en proyecto hasta que lo digas.

## Trabajar con tareas
> "¿Qué sigue en el proyecto newsletter?"
> "Agrega la tarea: diseñar la plantilla del mail."
> "Marca como hecha la tarea de la plantilla."

Cada proyecto tiene `tareas.md` con cinco secciones: En curso, Por hacer, Backlog, Bloqueadas, Hechas. **Lo próximo** es la primera tarea de En curso (o de Por hacer si En curso está vacía).

## Registrar una decisión
> "Decidimos publicar el newsletter los martes. Regístralo como decisión."

Se crea `decisions/DEC-NNN-….md` y una fila en el índice. Las decisiones no se borran: si cambias de idea, la nueva **reemplaza** a la vieja y la vieja queda marcada.

## Crear, pausar o cerrar un proyecto
> "Crea el proyecto «Mudanza» con objetivo … y próxima acción …"
> "Pausa el proyecto Mudanza."
> "Archiva mi-primer-proyecto."

La IA cambia el estado en los tres lugares a la vez (registro, índice y ficha). Si se desincronizan, el validador lo marca.

## Retomar algo después de semanas
> "Retomemos el proyecto Mudanza. ¿Dónde quedamos?"

La IA lee `project.md` y `tareas.md` y te dice el estado y la próxima acción, sin depender de conversaciones viejas.

## Leer el Cierre
Cada trabajo que cambió algo termina así:
```
Registrado en KOS: projects/mudanza/tareas.md
Comprobado con:    validador: 0 errores
Falta:             cotizar fletes. Próxima acción: pedir tres presupuestos.
```
- Si dice **"nada para registrar"** pero se decidió algo, pídele que lo registre.
- Si dice **"sin comprobar"**, pregunta por qué.
- Si no hay Cierre, pídeselo: *"Dame el Cierre."*

## Cuando la IA no puede escribir
Las IAs de chat te dan un bloque **"Para registrar en KOS"** con el archivo y el texto. Pégalo tú o pásaselo a una IA con acceso a archivos: *"Registra este bloque en KOS."*

## Hábitos que ayudan
- Termina cada sesión con *"¿Quedó todo registrado?"*.
- Una vez por semana: *"Revisa el inbox y propón qué promover o archivar."*
- Haz commit seguido (o pídele a la IA que lo haga).

Siguiente: [Zonas y autoridad](05-zonas-y-autoridad.md).

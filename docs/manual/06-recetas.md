# 06 — Recetas

Las recetas son instrucciones exactas para que cualquier IA haga las tareas habituales siempre igual. Viven en `ONBOARDING/RECETAS.md`. Tú solo pides en lenguaje natural:

| Quieres | Pide algo como | Qué hace la IA |
|---|---|---|
| Anotar una idea | "Anota en KOS: …" | Crea un archivo en `knowledge/inbox/`. |
| Ver qué sigue | "¿Qué sigue en X?" | Lee `tareas.md` y te da la próxima acción. |
| Agregar una tarea | "Agrega en X la tarea …" | Línea nueva en Por hacer, con fecha. |
| Cerrar una tarea | "Terminé …" | La marca hecha y la mueve a Hechas. |
| Registrar una decisión | "Regístralo como decisión" | `decisions/DEC-NNN-….md` + índice. |
| Crear un proyecto | "Crea el proyecto …" | Carpeta, ficha, manifiesto, tareas, registro e índice. |
| Cambiar un estado | "Pausa / archiva X" | Cambia el estado en los tres lugares. |
| Un recordatorio | "Recuérdame el 3 de mayo …" | Fila en `knowledge/lists/reminders.md` (no toca tu calendario sin permiso). |
| Guardar una herramienta | "Guarda esta app: …" | Fila en `knowledge/lists/software.md`. |
| Película, serie o libro (módulo listas) | "Agrega la película …" | Fila en la lista, sin duplicar. |
| Un gasto (módulo finanzas) | "Gasté 2500 en comida hoy" | Fila en `projects/finanzas/data/gastos.csv`. |
| Un balance (módulo finanzas) | "¿Cuánto gasté en marzo?" | Suma por mes y categoría, aclarando el período. |

## Reglas que cumplen todas
- Leer el archivo, hacer el cambio mínimo, releer, validar y commit.
- No inventar datos: lo que no sabe, lo deja vacío o te pregunta.
- No borrar filas ni pisar tus notas o puntajes.

Para crear recetas propias: [Personalizar](09-personalizar.md).

Siguiente: [Mantenimiento](07-mantenimiento.md).

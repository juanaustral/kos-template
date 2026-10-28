# Flujo de trabajo para IAs (trabajos largos)

Estado: vigente. Léelo solo si el trabajo dura varias sesiones, toca varios proyectos o vas a escribir mucho.

## Modelo
```
{{OWNER_NAME}} es dueño de KOS.
KOS guarda el conocimiento durable.
Las IA son clientes temporales.
Base decide qué sigue siendo verdad.
```

| Capa | Rol |
|---|---|
| Base | Conocimiento revisado y decisiones vigentes. |
| Memoria de tu sesión | Contexto temporal. Se pierde. |
| Entrada | Material capturado, todavía no confiable. |
| Trabajo | Borradores, análisis y planes. |
| Histórico | Lo reemplazado. |
| Auto-Generado | Índices y vistas regenerables. |

## Antes de empezar
1. Lee `AGENTS.md` y `ONBOARDING/README.md`.
2. Define el alcance: global, área, proyecto o tarea.
3. Lee el `manifest.yaml` y el `project.md` del proyecto. El manifiesto dice qué carpetas puedes leer y escribir (`tools.read`, `tools.write`) y el nivel de autonomía (`security.max_autonomy`).
4. Define qué es "terminado" y cómo lo vas a comprobar.

## Niveles de autonomía
- **A1**: solo lees y propones. {{OWNER_NAME}} escribe.
- **A2**: escribes en KOS cambios chicos y reversibles; pides aprobación para todo lo de la lista de `ONBOARDING/README.md`.
- **A3**: además ejecutas acciones externas acordadas (publicar, desplegar) sin pedir permiso cada vez. Solo si una decisión vigente lo habilita.

## Durante el trabajo
- Un cambio por commit. Valida después de cada uno.
- Si un trabajo queda a medias, deja el estado en `projects/<id>/tareas.md` (qué se hizo, qué falta, próxima acción) para que otra IA pueda seguir sin tu memoria.
- Si encuentras información contradictoria, aplica el orden de autoridad y avisa.

## Traspaso entre sesiones o entre IAs
Al cerrar una sesión larga, escribe en la tarea en curso:
- qué cambió (archivos y commits),
- cómo se comprobó,
- qué falta y la única próxima acción.
La próxima IA arranca leyendo `AGENTS.md` y esa tarea. Nada depende de tu memoria.

## Propuestas de memoria
Lo que aprendas sobre {{OWNER_NAME}} o sus dominios va a `knowledge/inbox/` con `Estado: proposed`. Nunca a la memoria de tu plataforma.

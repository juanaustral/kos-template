# 11 — Varias IAs a la vez

Si usas más de una IA sobre el mismo KOS (por ejemplo Claude Code y Codex, o un agente que corre solo en un servidor), pueden escribir al mismo tiempo. Sin cuidado, una pisa a la otra: se pierden líneas o un commit se lleva el trabajo a medio hacer de otra.

## La puerta única
Las IAs escriben con `tools/kos_write.rb`. Cada escritura pasa de a una (un candado), se valida antes y se commitea sola, con el nombre de la IA como autor.

| Para | Comando |
|---|---|
| Agregar una tarea | `ruby tools/kos_write.rb --agente claude tarea agregar --proyecto <id> --texto "..."` |
| Cerrar una tarea | `... tarea cerrar --proyecto <id> --buscar "parte del título"` |
| Capturar una idea | `... inbox --titulo "Tema" --texto "..."` |
| Proponer una decisión | `... decision --titulo "..." --proyecto <id> --texto "..."` (el número se asigna sin choques) |
| Agregar una fila a una lista | `... lista --lista movies.md --fila "\| ... \|"` |
| Avisar que trabaja en un proyecto | `... tomar --proyecto <id> --minutos 60` y `reclamos` para ver quién está en qué |
| Armar el Cierre | `... cierre --desde "3 hours ago"` |

Las reglas para IAs ya lo indican (`ONBOARDING/REGLAS-ESCRITURA.md`): no tienes que pedírselo cada vez.

## Sincronizar y revisar solo
- `ruby tools/kos_sync.rb`: el único que hace pull y push con GitHub. En un servidor, prográmalo cada 5 minutos (cron). Si tu copia y GitHub divergen, no toca nada y avisa.
- `ruby tools/kos_doctor.rb`: revisa candados de Git trabados, cambios olvidados sin commitear, la sincronización, el índice de decisiones y el validador. `--arreglar` corrige lo seguro; `--silencioso` solo habla si hay algo.

## Si las IAs corren con usuarios distintos (servidor)
Pon la carpeta en un grupo común y hazla compartida: `chgrp -R <grupo> kos && chmod -R g+w kos && find kos -type d -exec chmod g+s {} +` y `git -C kos config core.sharedRepository group`. `kos_doctor.rb` lo detecta y avisa si un archivo queda sin permiso de grupo.

Para que lo crítico (reglas, herramientas, historial) no cambie sin tu aprobación, mira [Protección](13-proteccion.md).

Siguiente: [Glosario](glosario.md).

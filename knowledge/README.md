# Knowledge — conocimiento de {{OWNER_NAME}}

La norma del sistema está en `AGENTS.md` y `decisions/`. Esta carpeta es contexto para decidir mejor, no reglas.

| Carpeta / Archivo | Propósito |
|---|---|
| `profile.md` | Perfil de {{OWNER_NAME}}: quién es, cómo trabaja, qué prefiere. |
| `areas/` | Conocimiento por dominio (trabajo, finanzas, salud, aprendizaje...). Molde: `templates/area.md`. |
| `inbox/` | Material sin clasificar (Entrada). Se revisa y se promueve o se archiva. |
| `lists/` | Listas con columnas fijas: notas, recordatorios, herramientas y las de módulos activos. |
| `archive/` | Histórico: lo reemplazado que conviene conservar a mano. |

## Para agentes de IA
1. Las decisiones vigentes (`decisions/index.md`) tienen prioridad sobre cualquier archivo de `knowledge/`.
2. Si dos fuentes se contradicen: instrucción actual de {{OWNER_NAME}} → decisiones → Base → Trabajo → Histórico.
3. Lo nuevo que aprendas va a `inbox/` con `Estado: proposed`.

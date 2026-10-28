# 12 — Skills compartidas

Una skill es una receta que la IA sigue para una tarea (una carpeta con un `SKILL.md`, formato abierto de agentskills.io). En KOS las skills viven en `skills/` y las usan todas tus IAs: Claude Code, Codex y cualquier agente que lea archivos. Una sola copia, en Git, con tu respaldo.

## La idea
- **Una sola fuente.** Nada de copias por herramienta que se desincronizan.
- **Tú apruebas.** Las IAs proponen mejoras; una persona de `skills/config.yaml` las aprueba. Si alguien cambia una skill aprobada sin pasar por la aprobación, el validador da error.
- **Calidad pareja.** Cada skill trae casos de prueba (`evals/casos.md`). Antes de aprobar, se prueban en las IAs que uses y se anota el resultado.

## Comandos
| Para | Comando |
|---|---|
| Ver qué hay | `ruby tools/kos_skills.rb estado` |
| Empezar una skill o un cambio | `ruby tools/kos_skills.rb proponer <nombre>` |
| Entregar la propuesta | `ruby tools/kos_skills.rb entregar <nombre> --agente <quién> --motivo "..."` |
| Ver qué cambia | `ruby tools/kos_skills.rb diff <nombre>` |
| Aprobar o rechazar | `ruby tools/kos_skills.rb aprobar <nombre> --por <persona>` / `rechazar <nombre> --por <persona> --motivo "..."` |
| Traer una skill de otra persona | `ruby tools/kos_skills.rb importar <carpeta> --fuente <url>` |
| Enlazar para Claude Code o Codex | `ruby tools/kos_skills.rb enlazar claude --destino .claude/skills` / `enlazar codex` |

No hace falta que los escribas tú: pídeselo a tu IA ("propón una skill para...", "aprueba la propuesta de..."). La skill `skills-kos` le enseña el proceso.

## Aprobadores
El asistente pone tu nombre en `skills/config.yaml`. Si comparten el KOS dos o más personas, agrega a cada una: cualquiera de ellas puede aprobar.

## Skills de otras personas
`importar` reconoce que una skill es ajena (no dice `origen: propia`, trae licencia o autor), te muestra autor, licencia, scripts y riesgos, y te pregunta:

> Esta skill es de otra persona. ¿La importas tal cual o prefieres adaptarla a nuestro sistema para evitar errores y problemas?

- **Tal cual**: copia exacta, marcada `origen: tercero`.
- **Adaptada** (recomendado): borrador en el formato de KOS, marcado `origen: adaptada`. El original queda aparte solo como referencia.

Sin licencia no entra: la skill es de su autor. Las skills de registros públicos pueden traer instrucciones ocultas o scripts dañinos; por eso se leen antes de aprobar.

## Cómo la usa cada IA
- **Claude Code**: enlaces en `.claude/skills/` de este KOS. Los crea el asistente si elegiste Claude Code.
- **Codex**: `enlazar codex` crea enlaces en `~/.agents/skills/`.
- **Otras**: leen `skills/` directamente; `AGENTS.md` les indica dónde está.

Los comandos y mensajes de la herramienta están en español.

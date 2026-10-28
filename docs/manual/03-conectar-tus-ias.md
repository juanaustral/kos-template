# 03 — Conectar tus IAs

Todas las IAs leen la misma entrada: `AGENTS.md`. Hay dos familias:

- **IAs con acceso a archivos** (Claude Code, Codex, Cursor, Gemini CLI y otros agentes): leen y escriben KOS directamente. Es la mejor experiencia.
- **IAs de chat** (Claude.ai, ChatGPT, Gemini web): leen lo que les subes y te devuelven bloques "Para registrar en KOS" que pegas tú o una IA con archivos.

## Claude Code
1. Si elegiste `claude-code` en el asistente, ya tienes `CLAUDE.md` y `.claude/skills/kos/`. Si no, copia `adapters/claude-code/CLAUDE.md` a la raíz y `adapters/claude-code/skills/kos/` a `.claude/skills/kos/`.
2. Abre una terminal en la carpeta y corre `claude`.
3. Para que Claude Code use KOS **desde cualquier carpeta**, agrega a tu `~/.claude/CLAUDE.md`:
   ```
   Mi memoria y fuente de verdad es KOS, en <ruta a tu KOS>. Antes de trabajar, lee su AGENTS.md y sigue sus reglas. Lo que se decide o aprende se registra allí.
   ```

## Codex (OpenAI)
Lee `AGENTS.md` de la raíz automáticamente. Abre Codex en la carpeta de KOS y listo. Para usarlo desde otros repositorios, agrega la misma línea de arriba a tu `~/.codex/AGENTS.md`.

## Cursor
Con `cursor` en el asistente queda `.cursor/rules/kos.mdc`. Abre la carpeta de KOS en Cursor y usa el chat del agente.

## Gemini CLI
Con `gemini` en el asistente queda `GEMINI.md`. Corre `gemini` en la carpeta.

## Claude.ai y ChatGPT
Sigue `adapters/claude-ai.md` o `adapters/chatgpt.md`. En resumen: crea un Proyecto, pega `adapters/pegar-en-una-ia.md` en las instrucciones y sube los archivos clave. Si tu KOS está en GitHub, conecta GitHub para que lea siempre la versión al día.

## Cualquier otra IA
Pega el texto de `adapters/pegar-en-una-ia.md` como primer mensaje.

## Desactiva la memoria propia de la IA (para estos temas)
KOS funciona porque hay **una sola fuente**. Si la IA guarda su propia versión de ti, aparecen contradicciones. En ChatGPT y Claude.ai puedes desactivar o revisar la memoria en la configuración.

## Prueba de arranque en frío
Hazla con cada IA nueva, en una conversación sin contexto previo:
1. *"Lee AGENTS.md y resúmeme KOS en cinco líneas."* Debe nombrar: fuente de verdad, regla de registro, Cierre, qué requiere tu aprobación.
2. *"Anota en KOS la idea: probar KOS con otra IA."* Debe crear `knowledge/inbox/AAAA-MM-DD-….md` con `Estado: proposed`.
3. *"Agrega una tarea en mi-primer-proyecto: revisar el perfil."* Debe editar `tareas.md` con el formato de la receta, correr el validador y cerrar con las tres líneas.
Si una IA falla, revisa [Problemas frecuentes](10-problemas-frecuentes.md).

Siguiente: [Uso diario](04-uso-diario.md).

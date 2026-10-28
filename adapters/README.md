# Adaptadores: cómo conectar cada IA a KOS

Todas las IAs leen la misma entrada: `AGENTS.md`. Un adaptador es solo el puente para que cada herramienta la encuentre.

| IA | Qué hacer | Archivo |
|---|---|---|
| Claude Code | El asistente copia `CLAUDE.md` y la skill a la raíz | `claude-code/` |
| Codex (OpenAI) | Lee `AGENTS.md` solo; no hace falta nada | — |
| Cursor | El asistente copia la regla a `.cursor/rules/` | `cursor/kos.mdc` |
| Gemini CLI | El asistente copia `GEMINI.md` a la raíz | `gemini/GEMINI.md` |
| Claude.ai (Proyectos) | Pegar instrucciones y subir archivos | `claude-ai.md` |
| ChatGPT (Proyectos o GPT) | Pegar instrucciones y subir archivos | `chatgpt.md` |
| Cualquier otra | Pegar el texto como primer mensaje | `pegar-en-una-ia.md` |

Guía paso a paso: `docs/manual/03-conectar-tus-ias.md`.

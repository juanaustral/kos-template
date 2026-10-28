# KOS — tu memoria, cualquier IA

KOS es un sistema para que **tu conocimiento viva en tus archivos y no en la memoria de una IA**. Proyectos, tareas, decisiones, ideas y listas quedan en carpetas de texto simple (Markdown) dentro de Git. Cualquier IA —Claude, ChatGPT, Codex, Cursor, Gemini— lee la misma entrada, sigue las mismas reglas y registra lo que hace. Cambias de IA cuando quieras y no pierdes nada.

## Instalación en cinco pasos
1. Instala **Git** y **Ruby 3** (guía en `docs/manual/01-instalacion.md`).
2. Copia esta plantilla a una carpeta tuya (o usa "Use this template" en GitHub).
3. En esa carpeta corre: `ruby tools/kos_init.rb` y responde las preguntas.
4. Guarda el estado: `git add -A && git commit -m "KOS instalado"`.
5. Conecta tu primera IA (`docs/manual/03-conectar-tus-ias.md`) y pídele: *"Lee AGENTS.md y resúmeme KOS en cinco líneas."*

Versión de una página: [`docs/manual/quickstart.md`](docs/manual/quickstart.md).

## Qué hay en cada carpeta
| Carpeta | Qué guarda |
|---|---|
| `AGENTS.md` | La entrada única para cualquier IA. |
| `ONBOARDING/` | Reglas, recetas y flujo de trabajo para IAs. |
| `projects/` | Un proyecto por carpeta: ficha, manifiesto y tareas. |
| `decisions/` | Decisiones vigentes e históricas. |
| `knowledge/` | Tu perfil, áreas, ideas sin clasificar (inbox) y listas. |
| `registry/` | Registro maestro de proyectos. |
| `templates/` | Moldes para archivos nuevos. |
| `adapters/` | Cómo conectar cada IA. |
| `modules/` | Módulos opcionales (listas, finanzas). |
| `tools/`, `tests/` | Asistente, validador, respaldo y chequeo de privacidad. |
| `docs/manual/` | El manual para ti. |

## Manual
Empieza por [`docs/manual/00-que-es-kos.md`](docs/manual/00-que-es-kos.md). Índice completo en [`docs/manual/README.md`](docs/manual/README.md).

Licencia de uso personal: [`LICENSE.md`](LICENSE.md). Cambios: [`CHANGELOG.md`](CHANGELOG.md).

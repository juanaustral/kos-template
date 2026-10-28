# Cambios

## 1.3.0 — 2026-10-28
- Nuevo: `ruby tools/kos_update.rb --desde <zip o carpeta>` actualiza KOS a una versión nueva. Reemplaza solo el motor (reglas, herramientas, manual, moldes, módulos, adaptadores), nunca tus datos. Con `--simular` muestra el plan sin tocar nada.
- Si editaste un archivo del motor, se respeta: la versión nueva queda al lado como `.kos-new` y el validador avisa.
- Migraciones de datos por `schema_version` (`tools/migraciones/`).
- `.kos/lock.yaml` registra la versión instalada y la huella de cada archivo de motor. Archivo `VERSION`.

## 1.2.0 — 2026-10-28
- Arreglo: un nombre o estilo con comillas o barras ya no rompe `kos.yaml` ni los manifiestos.
- Arreglo: el asistente no toca ningún archivo hasta terminar las preguntas; un error o Ctrl-C no deja la instalación a medias.
- Arreglo: el chequeo de filas de listas también funciona en GitHub (compara contra el estado anterior al push). Para borrar a propósito: `[permitir-borrar-filas]` en el mensaje del commit.
- Nuevo: el validador corre antes de cada commit (hook `pre-commit` que instala el asistente).
- Nuevo: `ruby tools/kos_init.rb --rellenar` completa tus datos en los archivos de una versión nueva y repone las recetas de módulos.
- Pruebas para los cuatro casos.

## 1.1.0 — 2026-10-28
- Versión completa en inglés: `ruby tools/kos_init.rb --lang en` (reglas, recetas, adaptadores, módulos y manual).
- El asistente acepta `--only-module` y nombres de módulo en inglés (`lists`, `finance`).

## 1.0.0 — 2026-10-27
- Primera versión: método KOS (entrada para IAs, reglas, zonas, recetas, registro obligatorio y Cierre).
- Asistente de instalación `tools/kos_init.rb`.
- Validador con módulos opcionales, respaldo verificable y chequeo de privacidad.
- Adaptadores para Claude Code, Claude.ai, ChatGPT, Codex, Cursor y Gemini.
- Módulos opcionales: listas y finanzas.
- Manual de uso completo en español.

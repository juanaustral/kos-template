# Cambios

## 1.4.4 — 2026-10-28
- README bilingüe (español e inglés): cómo funciona, requisitos previos, instrucciones para que una IA instale y use KOS, conexión por IA y herramienta, autoría y licencia.
- Tres imágenes en `docs/img/` (portada, flujo y zonas).

## 1.4.3 — 2026-10-28
- CHANGELOG sin nombres propios (el titular figura solo en `LICENSE.md`).

## 1.4.2 — 2026-10-28
- Licencia con titular (línea `Required Notice` de `LICENSE.md`).
- `kos_privacy_check.rb`: las líneas que empiezan con `!` en la lista son frases exactas permitidas.

## 1.4.1 — 2026-10-28
- Licencia: PolyForm Shield 1.0.0. Puedes usar KOS para lo que quieras (personal, trabajo, clientes) y modificarlo; no puedes venderlo ni ofrecerlo como producto propio, aunque sea gratis. `LICENSE.md` trae un resumen y el texto oficial.
- `kos_write.rb` permite editar `.gitignore`; su prueba ignora `KOS_AGENTE` de la terminal; `kos_doctor.rb` no muestra avisos de Git sobre carpetas sin permiso de lectura.

## 1.4.0 — 2026-10-28
- Nuevo: varias IAs a la vez sin pisarse. `tools/kos_write.rb` es la puerta única de escritura (candado, commit solo del propio cambio con la IA como autor, validación previa, números de decisión sin choques, reclamos de trabajo y Cierre). Manual: `docs/manual/11-varias-ias.md`.
- Nuevo: `tools/kos_sync.rb` (único pull/push con GitHub, para cron) y `tools/kos_doctor.rb` (candados trabados, cambios olvidados, sincronización, índice de decisiones, validador; `--arreglar`).
- El respaldo incluye todo el historial de Git (`kos-historial.bundle`) y la verificación lo comprueba.
- El validador detecta también claves de AWS, Slack y Google.
- Instalación guiada por una IA para quien no usa la terminal (quickstart).

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

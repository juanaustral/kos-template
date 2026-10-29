# Herramientas de KOS

Solo usan archivos locales: no llaman a ninguna IA ni servicio externo. Requieren Ruby 3.0 o superior.

| Herramienta | Para qué | Uso |
|---|---|---|
| `kos_init.rb` | Asistente de instalación, módulos y marcadores tras actualizar | `ruby tools/kos_init.rb`, `--solo-modulo <nombre>`, `--rellenar` |
| `kos_update.rb` | Actualiza el motor a una versión nueva sin tocar tus datos | `ruby tools/kos_update.rb --desde <zip o carpeta> [--simular]` |
| `kos_write.rb` | Puerta única de escritura para varias IAs a la vez | `ruby tools/kos_write.rb --agente <nombre> <operación>`, `--ayuda` |
| `kos_sync.rb` | Único pull/push con GitHub (para cron) | `ruby tools/kos_sync.rb [--simular]` |
| `kos_doctor.rb` | Chequeo de salud: candados, olvidos, sincronización, índice, validador | `ruby tools/kos_doctor.rb [--arreglar] [--silencioso]` |
| `kos_skills.rb` | Skills compartidas entre IAs: proponer, aprobar, importar | `ruby tools/kos_skills.rb estado` |
| `kos_aprobar.rb` | Aprobación de cambios críticos por email, con código y PIN | `ruby tools/kos_aprobar.rb solicitar --descripcion "..." --patch cambio.diff`; `aplicar --id <n>`; `probar-correo` |
| `kos_pin.rb` | Crea tu PIN de aprobación (en una terminal real) | `ruby tools/kos_pin.rb`, `--reset` |
| `kos_proteccion.rb` | Tu nivel de protección y una prueba de ataque | `ruby tools/kos_proteccion.rb nivel [--exigir 2]`, `ataque` |
| `kos_proteger.rb` | Cierra un servidor Linux (usuario `kos`, sudo mínimo); con vuelta atrás | `ruby tools/kos_proteger.rb --agentes ana,bot [--cerrar]`, `--abrir` |
| `kos_validate.rb` | Revisa estructura, estados, enlaces, secretos y datos | `ruby tools/kos_validate.rb` |
| `kos_backup.rb` | Respaldo comprimido con verificación | `ruby tools/kos_backup.rb` y `--verify <archivo>` |
| `kos_privacy_check.rb` | Busca nombres o datos antes de compartir | `ruby tools/kos_privacy_check.rb --denylist mis-terminos.txt --historial` |

Pruebas: `ruby tests/validator_test.rb` (más `kos_write_test`, `kos_skills_test`, `hooks_test`, `aprobar_test`, `zona_critica_test`, `proteccion_test`). Guía de protección: `docs/manual/13-proteccion.md`.

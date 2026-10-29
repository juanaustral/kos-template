# KOS tools

They only use local files: they don't call any AI or external service. They need Ruby 3.0 or later.

| Tool | Purpose | Usage |
|---|---|---|
| `kos_init.rb` | Setup wizard, modules and placeholders after an update | `ruby tools/kos_init.rb --lang en`, `--only-module <name>`, `--refill` |
| `kos_update.rb` | Updates the engine to a new version without touching your data | `ruby tools/kos_update.rb --from <zip or folder> [--dry-run]` |
| `kos_write.rb` | Single write gate for several AIs at once | `ruby tools/kos_write.rb --agente <name> <operation>`, `--ayuda` |
| `kos_sync.rb` | The only pull/push with GitHub (for cron) | `ruby tools/kos_sync.rb [--simular]` |
| `kos_doctor.rb` | Health check: locks, forgotten changes, sync, index, validator | `ruby tools/kos_doctor.rb [--arreglar] [--silencioso]` |
| `kos_skills.rb` | Skills shared between AIs: propose, approve, import | `ruby tools/kos_skills.rb estado` |
| `kos_aprobar.rb` | Email approval of critical changes, with a code and a PIN | `ruby tools/kos_aprobar.rb solicitar --descripcion "..." --patch change.diff`; `aplicar --id <n>`; `probar-correo` |
| `kos_pin.rb` | Creates your approval PIN (in a real terminal) | `ruby tools/kos_pin.rb`, `--reset` |
| `kos_proteccion.rb` | Your protection level and an attack test | `ruby tools/kos_proteccion.rb nivel [--exigir 2]`, `ataque` |
| `kos_proteger.rb` | Closes a Linux server (`kos` user, minimal sudo); reversible | `ruby tools/kos_proteger.rb --agentes ana,bot [--cerrar]`, `--abrir` |
| `kos_validate.rb` | Checks structure, statuses, links, secrets and data | `ruby tools/kos_validate.rb` |
| `kos_backup.rb` | Compressed backup with verification | `ruby tools/kos_backup.rb` and `--verify <file>` |
| `kos_privacy_check.rb` | Looks for names or data before sharing | `ruby tools/kos_privacy_check.rb --denylist my-terms.txt --historial` |

Tests: `ruby tests/validator_test.rb` (plus `kos_write_test`, `kos_skills_test`, `hooks_test`, `aprobar_test`, `zona_critica_test`, `proteccion_test`). Protection guide: `docs/manual/13-protection.md`. (Tool output messages are in Spanish.)

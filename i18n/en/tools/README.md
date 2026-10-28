# KOS tools

They only use local files: they don't call any AI or external service. They need Ruby 3.0 or later.

| Tool | Purpose | Usage |
|---|---|---|
| `kos_init.rb` | Setup wizard, modules and placeholders after an update | `ruby tools/kos_init.rb --lang en`, `--only-module <name>`, `--refill` |
| `kos_update.rb` | Updates the engine to a new version without touching your data | `ruby tools/kos_update.rb --from <zip or folder> [--dry-run]` |
| `kos_validate.rb` | Checks structure, statuses, links, secrets and data | `ruby tools/kos_validate.rb` |
| `kos_backup.rb` | Compressed backup with verification | `ruby tools/kos_backup.rb` and `--verify <file>` |
| `kos_privacy_check.rb` | Looks for names or data before sharing | `ruby tools/kos_privacy_check.rb --denylist my-terms.txt --historial` |

Tests: `ruby tests/validator_test.rb`. (Tool output messages are in Spanish.)

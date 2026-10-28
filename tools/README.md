# Herramientas de KOS

Solo usan archivos locales: no llaman a ninguna IA ni servicio externo. Requieren Ruby 3.0 o superior.

| Herramienta | Para qué | Uso |
|---|---|---|
| `kos_init.rb` | Asistente de instalación, módulos y marcadores tras actualizar | `ruby tools/kos_init.rb`, `--solo-modulo <nombre>`, `--rellenar` |
| `kos_validate.rb` | Revisa estructura, estados, enlaces, secretos y datos | `ruby tools/kos_validate.rb` |
| `kos_backup.rb` | Respaldo comprimido con verificación | `ruby tools/kos_backup.rb` y `--verify <archivo>` |
| `kos_privacy_check.rb` | Busca nombres o datos antes de compartir | `ruby tools/kos_privacy_check.rb --denylist mis-terminos.txt --historial` |

Pruebas: `ruby tests/validator_test.rb`.

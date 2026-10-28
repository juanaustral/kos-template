# KOS en diez minutos

> **¿No te llevas con la terminal?** Abre una IA que pueda usar tu computadora (Claude Code, Codex, Cursor) en la carpeta de KOS y pídele: *"Instala KOS siguiendo docs/manual/quickstart.md. Pregúntame mis datos antes de correr kos_init.rb y explícame cada paso."* Ella instala Git y Ruby si faltan.

1. **Requisitos**: Git y Ruby 3 instalados ([cómo](01-instalacion.md)). Comprueba con `git --version` y `ruby -v`.
2. **Copia la plantilla** a una carpeta tuya, por ejemplo `~/kos`. Si la recibiste en GitHub, usa "Use this template" y crea un repositorio **privado**.
3. **Abre una terminal en esa carpeta** y corre:
   ```
   ruby tools/kos_init.rb
   ```
   Responde: tu nombre, idioma, trato, estilo, áreas, módulos e IAs. Al final debe decir `Errores: 0`.
4. **Guarda**: `git add -A && git commit -m "KOS instalado"`.
5. **Conecta una IA** ([guía](03-conectar-tus-ias.md)). Si usas Claude Code, Codex, Cursor o Gemini CLI, ábrelos en la carpeta. Si usas un chat, pega `adapters/pegar-en-una-ia.md`.
6. **Primera prueba**: escribe *"Lee AGENTS.md y resúmeme KOS en cinco líneas."*
7. **Primer registro**: *"Anota esta idea en KOS: …"* La IA debe crear un archivo en `knowledge/inbox/` y cerrar con tres líneas (`Registrado en KOS`, `Comprobado con`, `Falta`).

Listo. Desde ahora, todo lo que decidas o aprendas con una IA queda en tus archivos.

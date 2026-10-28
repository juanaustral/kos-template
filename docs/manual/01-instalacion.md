# 01 — Instalación

## Requisitos
| Herramienta | Para qué | Cómo comprobar |
|---|---|---|
| Git | Guardar el historial de cambios | `git --version` |
| Ruby 3.0 o superior | Correr el asistente y el validador | `ruby -v` |
| Un editor de texto | Leer y editar a mano (opcional) | VS Code, Obsidian, cualquiera |

### Instalar Git y Ruby
- **macOS**: abre Terminal y corre `xcode-select --install` (trae Git). Para Ruby 3: instala [Homebrew](https://brew.sh) y corre `brew install ruby`.
- **Windows**: instala [Git for Windows](https://git-scm.com/download/win) y [RubyInstaller](https://rubyinstaller.org) (versión 3.x con Devkit). Usa "Git Bash" como terminal.
- **Linux**: `sudo apt install git ruby` (Debian/Ubuntu) o el equivalente de tu distribución.

> Si nunca usaste una terminal: es una ventana donde escribes comandos. Para "abrir una terminal en la carpeta", en macOS arrastra la carpeta sobre el ícono de Terminal; en Windows, clic derecho en la carpeta → "Git Bash Here".

## Tres formas de instalar

### A. Local (la más simple)
1. Descomprime el ZIP de KOS en una carpeta tuya, por ejemplo `Documentos/kos`.
2. Abre una terminal en esa carpeta.
3. Sigue con [Primer arranque](02-primer-arranque.md).
Respaldo: depende de ti (ver [Mantenimiento](07-mantenimiento.md)).

### B. Con GitHub (recomendada)
Tienes copia en la nube, historial y validación automática diaria.
1. Si recibiste acceso al repositorio plantilla: botón **Use this template** → **Create a new repository** → marca **Private**.
   Si recibiste el ZIP: crea un repositorio **privado** vacío en GitHub y sube la carpeta.
2. Clona tu repositorio: `git clone https://github.com/<tu-usuario>/<tu-repo>.git kos`
3. Sigue con [Primer arranque](02-primer-arranque.md). Al terminar: `git push`.
La carpeta `.github/workflows/` hace que GitHub valide tu KOS en cada cambio y te avise por mail si algo se rompe.

### C. En un servidor (avanzada)
Útil si trabajas con agentes que corren en la nube o en un VPS. Clona el repositorio en el servidor, haz que esa copia sea la principal y que las demás hagan `git pull` antes de escribir. Nunca edites dos copias a la vez sin sincronizar.

## Importante
- Tu repositorio debe ser **privado**. KOS guarda información personal.
- No pongas KOS dentro de una carpeta sincronizada con otro sistema (Dropbox, iCloud) **y** en Git a la vez: elige uno para evitar conflictos.

Siguiente: [Primer arranque](02-primer-arranque.md).

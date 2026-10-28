# 01 — Installation

## Requirements
| Tool | What for | How to check |
|---|---|---|
| Git | Keep the history of changes | `git --version` |
| Ruby 3.0 or later | Run the wizard and the validator | `ruby -v` |
| A text editor | Read and edit by hand (optional) | VS Code, Obsidian, any |

### Installing Git and Ruby
- **macOS**: open Terminal and run `xcode-select --install` (includes Git). For Ruby 3: install [Homebrew](https://brew.sh) and run `brew install ruby`.
- **Windows**: install [Git for Windows](https://git-scm.com/download/win) and [RubyInstaller](https://rubyinstaller.org) (3.x with Devkit). Use "Git Bash" as your terminal.
- **Linux**: `sudo apt install git ruby` (Debian/Ubuntu) or your distribution's equivalent.

> Never used a terminal? It's a window where you type commands. To "open a terminal in the folder": on macOS, drag the folder onto the Terminal icon; on Windows, right-click the folder → "Git Bash Here".

## Three ways to install

### A. Local (simplest)
1. Unzip KOS into a folder of yours, e.g. `Documents/kos`.
2. Open a terminal in that folder.
3. Continue with [First run](02-first-run.md).
Backups: up to you (see [Maintenance](07-maintenance.md)).

### B. With GitHub (recommended)
You get a cloud copy, history and automatic daily validation.
1. If you received access to the template repository: **Use this template** → **Create a new repository** → choose **Private**.
   If you received the ZIP: create an empty **private** repository on GitHub and upload the folder.
2. Clone your repository: `git clone https://github.com/<your-user>/<your-repo>.git kos`
3. Continue with [First run](02-first-run.md). When done: `git push`.
The `.github/workflows/` folder makes GitHub validate your KOS on every change and email you if something breaks.

### C. On a server (advanced)
Useful if you work with agents running in the cloud or on a VPS. Clone the repository on the server, make that copy the main one and have the others `git pull` before writing. Never edit two copies at once without syncing.

## Important
- Your repository must be **private**. KOS stores personal information.
- Don't put KOS in a folder synced by another system (Dropbox, iCloud) **and** in Git at the same time: pick one to avoid conflicts.

Next: [First run](02-first-run.md).

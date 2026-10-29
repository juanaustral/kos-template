# 13 — Protecting your KOS

Your KOS holds rules, decisions and memory. This guide explains how to keep an AI (or a mistake) from changing them without you knowing: what counts as *critical*, how you approve a critical change from your email, and which protection level you can reach on your machine — stated plainly, without overselling.

## The idea in one line
Ordinary things (tasks, ideas, lists) flow freely and are always reversible with Git. **Critical** things (the rules, the tools, Git history, mass deletions) only change with your **explicit approval**: an email arrives with the exact change and a code, and you confirm it with your PIN in a terminal.

## What is critical
`registry/zonas.yaml` defines it (you can adjust it): `AGENTS.md`, `ONBOARDING/`, `tools/`, `.claude/`, `.github/`, `.gitignore`, `zonas.yaml` itself, deleting more than 5 files in one commit, deleting a whole project folder, and rewriting history (force push, deleting branches). Expect to approve one or two changes a month; if it is far more, the zone is too wide.

## Which level you have
Run `ruby tools/kos_proteccion.rb nivel` **as the same user your AI works as**: the level depends on who you are on the system.

| Level | Meaning | What it takes |
|---|---|---|
| 0 | No protection | — |
| 1 | **Guidance and detection.** Zones exist, a hook stops `git push --force`, and `kos_write.rb` refuses critical paths. The doctor flags mass deletions, rewritten history and critical changes without approval | `ruby tools/kos_doctor.rb --arreglar` (turns the hook on) |
| 2 | Level 1 + **email approval** with a code and a PIN | Set up email and create the PIN (below) |
| 3 | **Closed.** KOS belongs to a service user and whoever runs the AI cannot write directly, use `sudo`, or read the approval secret | A Linux server, root, and the AI running as an ordinary user: `kos_proteger.rb` |

**Plainly:** on your personal computer, where the AI runs as *your* user, the ceiling is level 2. The barriers warn, refuse through the write door and ask for approval, but an AI that edits files directly as your own user can bypass them. A real lock (level 3) needs a separate user for the AI. And an AI running as administrator (root) is not stopped by any of this.

## Approving a critical change
1. The AI prepares the change as a patch (`git diff > change.diff`) and asks for it: `ruby tools/kos_aprobar.rb solicitar --descripcion "what and why" --patch change.diff`. Before sending, it is tried on a copy and the validator runs: you never get a change that breaks your KOS.
2. You get an email with the full change (additions in green, deletions in red) and a **6-digit code**. The AI only gets a request number, not the code.
3. You read the change and, from a **real terminal** (not an AI chat), run `ruby tools/kos_aprobar.rb aplicar --id <request>`. It asks for the code and your **PIN**; neither is shown as you type.
4. If everything matches, **that** change is applied, recorded with `Aprobado-por: titular`, and written to the approvals log.

Safeguards: the code expires in 15 minutes, works once, and is cancelled after 3 wrong attempts; 5 failures in an hour lock approvals for an hour. If the change is altered after being requested, it no longer applies. Never type your PIN in a chat or give it to an AI.

## Setting it up (level 2)
1. **Email.** Pick a mailbox KOS will send from and create a `correo.env` file with `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER` and `SMTP_PASS`. Where the codes arrive is your decision: keep in mind an AI with access to that mailbox could read them (that is why the PIN exists, and it is written nowhere).
2. **Configuration** (as administrator): create `/etc/kos/aprobacion.json` with `{"destinatario": "you@mail", "correo_env": "/path/to/correo.env"}`, mode 600. Without administrator rights, set `KOS_CONFIG` and `KOS_ESTADO` to a folder of your own.
3. **Test sending:** `ruby tools/kos_aprobar.rb probar-correo`. Check spam too.
4. **Create your PIN** (6 to 12 digits) in a real terminal: `ruby tools/kos_pin.rb`. It shows an **emergency key** once: keep it off the server. With `--reset` and that key you can change the PIN. Until the PIN exists, nothing is required.

## Closing the server (level 3)
On a Linux server, as administrator, with the users your AIs work as (not root):

```
ruby tools/kos_proteger.rb --agentes ana,bot            # shows what it would do, changes nothing
sudo ruby tools/kos_proteger.rb --agentes ana,bot --cerrar
```
This creates the `kos` user and `kosagentes` group, makes KOS owned by `kos` with no write access for anyone else, and allows through `sudo` only `kos_write.rb`, `kos_skills.rb` (its writing commands) and `kos_doctor.rb`. AIs keep writing with the same command as always: the script relaunches itself as `kos`. It saves a permissions snapshot first: `sudo ruby tools/kos_proteger.rb --abrir` undoes it. The sync and doctor cron jobs keep running as root so your GitHub keys never leave it.

Afterwards, **run your AI sessions as those users** and check: `ruby tools/kos_proteccion.rb nivel --exigir 3`.

## Checking that it works
`ruby tools/kos_proteccion.rb ataque` tries to bypass the barriers as the current user (all reversible) and reports what happened. If anything says "PASÓ (mal)" (it got through), whoever runs it can bypass that barrier. Repeat after any change of users or permissions.

## What this does not cover
An AI with administrator rights; someone controlling your server or your GitHub account; a bug in the tools themselves (that is what `ataque` is for). The messages of these tools are in Spanish for now.

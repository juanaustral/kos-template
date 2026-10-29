# Registry

`projects.yaml` is the master list of projects. Every project in `projects/` must be here, with the same status as in `projects/index.md` and its `project.md` (DEC-002).

`lifecycle` values: `active`, `paused`, `finished`, `archived`.

`zonas.yaml` defines what is **critical**: the paths and actions that only change with your explicit approval (by email, with a code and a PIN). It is itself critical. Guide: `docs/manual/13-protection.md`.

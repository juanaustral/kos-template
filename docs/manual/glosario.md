# Glosario

| Palabra | Significa |
|---|---|
| **KOS** | Tu sistema de conocimiento: memoria en archivos que cualquier IA puede leer. |
| **AGENTS.md** | La entrada única. Lo primero que lee cualquier IA. |
| **Fuente de verdad** | El lugar que manda cuando hay dudas. En KOS, tus archivos. |
| **Regla de registro** | Lo que se decide, se crea o se aprende se escribe en KOS en el mismo trabajo (DEC-001). |
| **Cierre** | Las tres líneas al final de un trabajo: Registrado en KOS, Comprobado con, Falta. |
| **Validador** | `tools/kos_validate.rb`: revisa que nada esté roto. |
| **Receta** | Instrucción exacta para una tarea habitual (`ONBOARDING/RECETAS.md`). |
| **Inbox / Entrada** | Donde cae lo nuevo sin revisar. |
| **Base** | Lo revisado y vigente. |
| **Histórico** | Lo reemplazado; no vale como verdad actual. |
| **Proyecto** | Una carpeta en `projects/` con ficha, manifiesto y tareas. |
| **Manifiesto** | `manifest.yaml`: qué puede leer y escribir una IA en ese proyecto y con qué autonomía. |
| **Registro** | `registry/projects.yaml`: la lista maestra de proyectos. |
| **Decisión (DEC)** | Una regla o elección registrada en `decisions/`. No se borra; se reemplaza. |
| **Módulo** | Un agregado opcional (listas, finanzas). |
| **Adaptador** | El archivo que conecta una IA concreta con `AGENTS.md`. |
| **Autonomía A1/A2/A3** | Cuánto puede hacer la IA sin preguntarte. |
| **Commit** | Un cambio guardado en Git, con fecha y descripción. |

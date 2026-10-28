# Reglas de escritura y datos sensibles

Estado: vigente.

## Cómo escribir
- Antes de escribir: actualiza (`git pull`) si trabajas sobre una copia. Un cambio por commit, con mensaje claro. Nunca guardes secretos.
- Capturas e ideas nuevas: `knowledge/inbox/AAAA-MM-DD-tema.md`.
- Listas: edita el archivo de `knowledge/lists/` respetando sus columnas. No sobrescribas notas, puntajes ni estados de {{OWNER_NAME}}. No borres filas.
- No reemplaces un documento en silencio: si algo cambia, deja lo anterior como histórico.
- Usa los moldes de `templates/` para archivos nuevos.
- Al terminar, valida: `ruby tools/kos_validate.rb` (0 errores) y verifica releyendo lo que escribiste.

## Mantener KOS liviano (DEC-003)
Antes de dejar algo, pregúntate:
1. ¿Una IA o {{OWNER_NAME}} lo necesita para decidir o actuar pronto? Si no, no va en KOS: va al historial de Git o a `knowledge/archive/`.
2. ¿Cambia una decisión vigente o el estado de un proyecto? Si sí, se queda.
3. ¿Repite lo que ya está en otro archivo? Si sí, no se duplica: se enlaza.
Las decisiones no se borran: se marca su estado (vigente, reemplazada, cerrada).

## Estados consistentes (DEC-002)
- Un proyecto tiene el mismo estado en `registry/projects.yaml`, `projects/index.md` y su `project.md`. Al cambiarlo, toca los tres en el mismo commit. El validador lo controla.
- Si `kos.yaml` activa `chequeos.github_prs`, una tarea que cita un PR (`github.com/dueño/repo/pull/N` o `dueño/repo#N`) debe cerrarse cuando el PR se mergea.

## Datos sensibles
- Finanzas, salud y datos de terceros son **Confidenciales**: guárdalos solo si {{OWNER_NAME}} lo pide, y nunca números completos de tarjeta, cuenta, documento ni contraseñas.
- Las claves y tokens nunca van en KOS. El validador busca patrones de secretos y falla si los encuentra.
- Marca la sensibilidad en el archivo: `Pública`, `Interna` o `Confidencial`.

## Si no puedes acceder a algo
Pide a {{OWNER_NAME}} la carpeta o el archivo. No adivines su contenido.

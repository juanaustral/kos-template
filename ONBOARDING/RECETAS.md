# Recetas: cómo hacer las tareas habituales en KOS

Todas siguen la misma regla: **lee el archivo, haz el cambio mínimo, relee para verificar, valida y haz commit** (`ruby tools/kos_validate.rb` debe dar 0 errores). Si el pedido es ambiguo, no escribas: pregunta a {{OWNER_NAME}}.

## Capturar una idea o nota
- Archivo nuevo: `knowledge/inbox/AAAA-MM-DD-tema.md` con el molde `templates/inbox.md` (`# Título`, `Origen`, `Fecha`, `Estado: proposed`, `Sensibilidad` y el texto).
- No promuevas a proyecto ni a Base sin aprobación. Una idea no es un proyecto activo.
- Notas sueltas ya clasificadas: `knowledge/lists/notes.md` (`| Fecha | Tema | Nota | Estado | Fuente |`).

## Ver proyectos y próximos pasos
- Lista y estado: `projects/index.md`. Detalle: `projects/<carpeta>/project.md` (sección "Próxima acción").
- Tareas: `projects/<carpeta>/tareas.md`. El siguiente paso es la primera tarea de `## En curso`; si está vacía, la primera de `## Por hacer`.

## Agregar o avanzar una tarea
- Archivo: `projects/<carpeta>/tareas.md`, con secciones `## En curso`, `## Por hacer`, `## Backlog`, `## Bloqueadas`, `## Hechas`.
- Línea: `- [ ] Título — contexto (creada AAAA-MM-DD)`. Al terminar: `- [x] Título (hecha AAAA-MM-DD)` y muévela a `## Hechas`.
- Una tarea se marca hecha solo cuando se comprobó el resultado (publicado, entregado, mergeado), no antes.

## Registrar una decisión
- Archivo nuevo: `decisions/DEC-NNN-tema-corto.md` con el molde `templates/decision.md` (`NNN` = siguiente número libre de `decisions/index.md`).
- Agrega la fila en `decisions/index.md`. Si reemplaza a otra, cambia el estado de la vieja a `reemplazada por DEC-NNN`; no la borres.

## Crear un proyecto
1. Pide a {{OWNER_NAME}} confirmación del nombre, el objetivo y el estado.
2. Crea `projects/<id>/` con `manifest.yaml`, `project.md` y `tareas.md` desde `templates/` (`id` en minúsculas y guiones).
3. Agrega el proyecto a `registry/projects.yaml` y una fila a `projects/index.md`. El estado debe decir lo mismo en los tres lugares.

## Cambiar el estado de un proyecto
- Cambia `lifecycle` en `registry/projects.yaml`, la columna Estado de `projects/index.md` y la línea `Estado:` de `project.md`, en el mismo commit. Valores: `active`, `paused`, `finished`, `archived`.

## Registrar un recordatorio
- Archivo: `knowledge/lists/reminders.md`, `| Estado | Fecha | Hora | Recordatorio | Contexto | Fuente |`.
- Si falta fecha u hora, déjalo como "pendiente de aclaración". No escribas en calendarios ni servicios externos sin aprobación.

## Guardar una herramienta o software
- Archivo: `knowledge/lists/software.md`, `| Estado | Nombre | Categoría | Uso | Link | Nota | Fuente |`.

## Aprender algo sobre {{OWNER_NAME}}
- No lo guardes en tu memoria. Proponlo en `knowledge/inbox/` con `Estado: proposed`. Solo pasa a `knowledge/profile.md` o `knowledge/areas/` con su aprobación.

<!-- kos:modulos -->

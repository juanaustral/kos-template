# 09 — Personalizar

KOS es tuyo: puedes cambiar casi todo. Mantén solo tres cosas: `AGENTS.md` como entrada única, la regla de registro y el validador en verde.

## Cambiar cómo te hablan
Edita la sección "Cómo hablarle" de `AGENTS.md` y "Cómo me gusta que me hablen" de `knowledge/profile.md`.

## Agregar un área
Copia `templates/area.md` a `knowledge/areas/<nombre>.md` o pide: *"Crea el área Salud en KOS."*

## Crear una lista nueva
1. Crea `knowledge/lists/<lista>.md` con una tabla y sus columnas, por ejemplo `| Estado | Restaurante | Barrio | Puntaje | Nota |`.
2. Agrégala a la tabla de `knowledge/lists/README.md`.
3. Agrega una receta en `ONBOARDING/RECETAS.md` (ver abajo).
El validador protegerá sus filas automáticamente.

## Escribir una receta
Una buena receta dice: **archivo**, **formato exacto** de la línea, **qué revisar antes** (duplicados) y **qué no hacer nunca**. Ejemplo:
```
## Registrar un entrenamiento
- Archivo: `knowledge/lists/entrenamientos.md`, `| Fecha | Tipo | Duración | Nota |`.
- Fecha en AAAA-MM-DD. Una fila por sesión, al final. No borres filas.
```

## Agregar una regla global
Las reglas globales son decisiones. Pide: *"Registra como decisión: la IA puede hacer push sin preguntarme."* Si la regla cambia el comportamiento de todas las IAs, agrégala también, en una línea, a `AGENTS.md` o `ONBOARDING/README.md`.

## Activar un módulo después
```
ruby tools/kos_init.rb --solo-modulo listas
ruby tools/kos_init.rb --solo-modulo finanzas
```

## Crear tu propio módulo
Copia la estructura de `modules/listas/`: un `README.md`, los archivos a instalar y un `recetas.md` con secciones que terminen en `(módulo <nombre>)`. Para que el asistente lo instale, agrega un caso en `install_module` de `tools/kos_init.rb`. Si es sólo para ti, alcanza con copiar los archivos a mano.

## Activar el chequeo de PRs
Si tus tareas citan pull requests de GitHub, en `kos.yaml` pon `chequeos.github_prs: true`. El validador (con `gh` instalado) avisará cuando una tarea siga abierta con su PR ya mergeado.

Siguiente: [Problemas frecuentes](10-problemas-frecuentes.md).

---
id: DEC-002
title: Estados de proyecto consistentes en registro, índice y ficha
status: aprobada
date: {{FECHA_INSTALACION}}
source: decisión base del sistema KOS
---

# DEC-002 — Estados consistentes

## Decisión
El estado de un proyecto se escribe en tres lugares: `registry/projects.yaml` (`lifecycle`), `projects/index.md` (columna Estado) y `projects/<id>/project.md` (línea `Estado:`). Los tres dicen lo mismo y se cambian en el mismo commit. Una tarea se marca hecha solo cuando el resultado está comprobado.

## Razón
Si cada archivo dice algo distinto, ninguna IA sabe qué es verdad y se retoman proyectos cerrados o se olvidan activos.

## Consecuencias
- `tools/kos_validate.rb` falla si un proyecto aparece abierto en un lugar y cerrado en otro.

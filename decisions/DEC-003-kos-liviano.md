---
id: DEC-003
title: Criterio para mantener KOS liviano
status: aprobada
date: {{FECHA_INSTALACION}}
source: decisión base del sistema KOS
---

# DEC-003 — Mantener KOS liviano

## Decisión
Antes de dejar algo en KOS se responden tres preguntas:
1. ¿Una IA o {{OWNER_NAME}} lo necesita para decidir o actuar pronto? Si no, va al historial de Git o a `knowledge/archive/`.
2. ¿Cambia una decisión vigente o el estado de un proyecto? Si sí, se queda.
3. ¿Repite algo que ya está en otro archivo? Si sí, se enlaza en vez de duplicar.

## Razón
Cada archivo extra cuesta lectura y tokens a cada IA y aumenta las contradicciones. Un KOS chico y vigente se usa; uno enorme se ignora.

## Consecuencias
- Las decisiones no se borran: se marca su estado.
- Una vez por mes conviene revisar `knowledge/inbox/` y archivar lo que no se usó (ver `docs/manual/07-mantenimiento.md`).

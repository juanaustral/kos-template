---
id: DEC-001
title: Regla permanente de registro en KOS para toda IA
status: aprobada
date: {{FECHA_INSTALACION}}
source: decisión base del sistema KOS
---

# DEC-001 — Regla permanente de registro en KOS

## Decisión
Toda IA, herramienta o versión que trabaje con {{OWNER_NAME}} lee la entrada de KOS (`AGENTS.md`) antes de trabajar y **registra en KOS** todo lo que se decide, se crea, se aprende o cambia de estado, en el mismo trabajo. El texto de la regla vive en `AGENTS.md` y no se modifica sin aprobación explícita de {{OWNER_NAME}}.

## Razón
Una conversación no se archiva sola: solo queda lo que se escribe en KOS. Así {{OWNER_NAME}} puede cambiar de IA sin reconstruir nada y sin depender de la memoria de ninguna plataforma.

## El Cierre
Todo trabajo que cambió algo termina con tres líneas:
```
Registrado en KOS: <archivos escritos> | nada para registrar
Comprobado con:    <evidencia concreta> | sin comprobar
Falta:             <lo pendiente>. Próxima acción: <una sola>
```

## Consecuencias
- La memoria propia de cada IA no es fuente sobre {{OWNER_NAME}}.
- Si una IA no puede escribir, entrega un bloque "Para registrar en KOS".

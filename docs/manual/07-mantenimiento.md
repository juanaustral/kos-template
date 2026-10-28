# 07 — Mantenimiento

## El validador
```
ruby tools/kos_validate.rb
```
Revisa: archivos críticos, YAML válido, proyectos registrados y con ficha, estados coherentes, enlaces rotos, patrones de secretos, filas de listas perdidas, datos de finanzas y marcadores sin completar. Debe decir **Errores: 0**. Las IAs lo corren después de cada cambio; si usas GitHub, también se corre en cada push y una vez al día.

## Respaldos
Git ya es un historial, pero un respaldo aparte protege contra borrados y errores graves.
```
ruby tools/kos_backup.rb                     # crea backups/kos-<fecha>.tar.gz y su SHA256
ruby tools/kos_backup.rb --verify backups/kos-<fecha>.tar.gz   # prueba que se restaura bien
```
- Guarda la copia fuera de tu computadora (disco externo, nube cifrada).
- **Prueba la restauración una vez por trimestre.** Un respaldo que nunca se probó no es un respaldo.
- Si usas GitHub privado, ya tienes una segunda copia; el respaldo local cubre el caso de perder el acceso.

## Mantenerlo liviano (DEC-003)
Cada archivo extra cuesta lectura a cada IA. Una vez por mes, pide:
> "Revisa el inbox y las áreas. Propón qué promover, qué archivar y qué duplicado enlazar."

Criterio: si no sirve para decidir o actuar pronto, va al archivo o al historial de Git; si repite otro archivo, se enlaza.

## Revisión semanal sugerida (15 minutos)
1. *"¿Qué proyectos están activos y cuál es la próxima acción de cada uno?"*
2. *"¿Hay tareas en curso hace más de dos semanas?"*
3. *"Revisa el inbox."*
4. Commit y push.

## Actualizar la plantilla
Si recibes una versión nueva de KOS, lee su `CHANGELOG.md`. Las mejoras suelen estar en `ONBOARDING/`, `tools/` y `docs/`: copia esos archivos sobre los tuyos (nunca `knowledge/`, `projects/`, `decisions/` ni `kos.yaml`, que son tus datos). Después corre `ruby tools/kos_init.rb --rellenar`: vuelve a poner tu nombre y tu trato en los archivos nuevos, repone las recetas de tus módulos y corre el validador. Si habías editado a mano algún archivo de `ONBOARDING/`, revisa el diff con `git diff` antes del commit.

Siguiente: [Privacidad y seguridad](08-privacidad-y-seguridad.md).

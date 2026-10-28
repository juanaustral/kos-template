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

## Actualizar KOS
Cuando recibas una versión nueva (ZIP o carpeta):

1. Guarda tu estado: `git add -A && git commit -m "antes de actualizar"`.
2. Mira qué cambiaría, sin tocar nada: `ruby tools/kos_update.rb --desde ~/Descargas/kos-vX.Y.Z.zip --simular`.
3. Actualiza: el mismo comando sin `--simular`.

Qué hace: reemplaza solo el **motor** (reglas, herramientas, manual, moldes, módulos y adaptadores) y lo completa con tu nombre, trato, módulos e IAs de `kos.yaml`. **Nunca toca tus datos**: `knowledge/`, `projects/`, `decisions/`, `registry/` ni tus valores de `kos.yaml`. Si una versión nueva cambia la forma de los datos, trae una migración que corre sola.

Si editaste a mano un archivo del motor (por ejemplo `AGENTS.md`), se queda el tuyo y la versión nueva queda al lado como `AGENTS.md.kos-new`. Compáralos, quédate con lo que quieras y borra el `.kos-new` (el validador te avisa mientras exista).

Al final: revisa con `git diff` y guarda con `git add -A && git commit -m "KOS X.Y.Z"`. Para deshacer: `git reset --hard && git clean -fd`.

Si tu KOS es anterior a la 1.3.0, la primera vez agrega `--sobrescribir` y usa el actualizador de la versión nueva: `ruby <carpeta-nueva>/tools/kos_update.rb --desde <carpeta-nueva> --kos . --sobrescribir`.

Siguiente: [Privacidad y seguridad](08-privacidad-y-seguridad.md).

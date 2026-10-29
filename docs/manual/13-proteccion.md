# 13 — Protección de tu KOS

Tu KOS guarda reglas, decisiones y memoria. Esta guía explica cómo evitar que una IA (o un error) las cambie sin que lo sepas: qué cosas son *críticas*, cómo apruebas un cambio crítico desde tu correo y qué nivel de protección puedes lograr en tu equipo, dicho sin exagerar.

## La idea en una línea
Lo común (tareas, ideas, listas) fluye libre y siempre es reversible con Git. Lo **crítico** (las reglas, las herramientas, el historial de Git, los borrados masivos) solo cambia con **tu aprobación explícita**: llega un email con el cambio exacto y un código, y lo confirmas con tu PIN en una terminal.

## Qué es crítico
Lo define `registry/zonas.yaml` (puedes ajustarlo): `AGENTS.md`, `ONBOARDING/`, `tools/`, `.claude/`, `.github/`, `.gitignore`, el propio `zonas.yaml`, borrar más de 5 archivos en un commit, borrar la carpeta de un proyecto entero y reescribir el historial (force push, borrar ramas). Se espera que apruebes uno o dos cambios al mes; si son muchos más, la zona está demasiado ancha.

## Qué nivel tienes
Corre `ruby tools/kos_proteccion.rb nivel` **con el mismo usuario con el que trabaja tu IA**: el nivel depende de quién eres en el sistema.

| Nivel | Qué significa | Qué hace falta |
|---|---|---|
| 0 | Sin protección | — |
| 1 | **Guía y detección.** Hay zonas, un hook que frena `git push --force`, y `kos_write.rb` rechaza lo crítico. El doctor avisa de borrados masivos, historia reescrita y cambios críticos sin aprobación | `ruby tools/kos_doctor.rb --arreglar` (activa el hook) |
| 2 | Nivel 1 + **aprobación por email** con código y PIN | Configurar el correo y crear el PIN (abajo) |
| 3 | **Cerrado.** KOS es de un usuario de servicio y quien corre la IA no puede escribir directo, ni usar `sudo`, ni leer el secreto de aprobaciones | Un servidor Linux, root, y que la IA corra con un usuario común: `kos_proteger.rb` |

**Dicho sin rodeos:** en tu equipo personal, donde la IA corre con *tu* usuario, el techo es el nivel 2. Las barreras avisan, rechazan por la puerta de escritura y te piden aprobación, pero una IA que edite archivos directo con tu mismo usuario puede saltearlas. El cerrojo real (nivel 3) exige un usuario distinto para la IA. Y una IA que corra como administrador (root) no queda frenada por nada de esto.

## Aprobar un cambio crítico
1. La IA prepara el cambio como un patch (`git diff > cambio.diff`) y lo pide: `ruby tools/kos_aprobar.rb solicitar --descripcion "qué y por qué" --patch cambio.diff`. Antes de enviarlo, se prueba en una copia y corre el validador: no te llega algo que rompe tu KOS.
2. Te llega un email con el cambio completo (lo agregado en verde, lo borrado en rojo) y un **código de 6 dígitos**. La IA recibe solo un número de solicitud, no el código.
3. Lees el cambio y, desde una **terminal real** (no el chat de una IA), corres `ruby tools/kos_aprobar.rb aplicar --id <solicitud>`. Te pide el código y tu **PIN**, que no se muestran al escribirlos.
4. Si todo coincide, se aplica **ese** cambio, se registra con `Aprobado-por: titular` y queda anotado en el registro de aprobaciones.

Protecciones: el código vence a los 15 minutos, sirve una vez y se anula con 3 intentos fallidos; 5 fallos en una hora traban las aprobaciones por una hora. Si el cambio se altera después de pedirlo, deja de aplicar. Nunca escribas tu PIN en un chat ni se lo des a una IA.

## Puesta en marcha (nivel 2)
1. **Correo.** Elige una casilla desde la que KOS enviará los avisos y crea un archivo `correo.env` con `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER` y `SMTP_PASS`. Dónde llegan los códigos es tu decisión: ten presente que una IA con acceso a esa casilla podría leerlos (por eso existe el PIN, que no se escribe en ningún lado).
2. **Configuración** (como administrador): crea `/etc/kos/aprobacion.json` con `{"destinatario": "tu@correo", "correo_env": "/ruta/a/correo.env"}`, permisos 600. Sin permisos de administrador, define las variables `KOS_CONFIG` y `KOS_ESTADO` apuntando a una carpeta tuya.
3. **Prueba el envío:** `ruby tools/kos_aprobar.rb probar-correo`. Revisa también la carpeta de spam.
4. **Crea tu PIN** (de 6 a 12 dígitos) en una terminal real: `ruby tools/kos_pin.rb`. Muestra una **clave de emergencia** una sola vez: guárdala fuera del servidor. Con `--reset` y esa clave se cambia el PIN. Hasta que el PIN exista, no se exige nada.

## Cerrar el servidor (nivel 3)
En un servidor Linux, como administrador y con los usuarios con los que trabajan tus IA (no root):

```
ruby tools/kos_proteger.rb --agentes ana,bot            # muestra qué haría, sin cambiar nada
sudo ruby tools/kos_proteger.rb --agentes ana,bot --cerrar
```
Esto crea el usuario `kos` y el grupo `kosagentes`, deja KOS como propiedad de `kos` sin escritura para nadie más, y autoriza con `sudo` solo `kos_write.rb`, `kos_skills.rb` (sus comandos que escriben) y `kos_doctor.rb`. Las IA siguen escribiendo con el mismo comando de siempre: el script se relanza solo como `kos`. Guarda antes una foto de los permisos: `sudo ruby tools/kos_proteger.rb --abrir` vuelve atrás. El cron de sincronización y del doctor sigue corriendo como root para que tus llaves de GitHub no salgan de ahí.

Después, **corre tus sesiones de IA con esos usuarios** y comprueba: `ruby tools/kos_proteccion.rb nivel --exigir 3`.

## Comprobar que funciona
`ruby tools/kos_proteccion.rb ataque` intenta saltear las barreras como el usuario actual (todo reversible) y te dice qué pasó. Si algo dice «PASÓ (mal)», quien corre eso puede saltearse esa barrera. Repite la prueba después de cada cambio de usuarios o permisos.

## Lo que esto no cubre
Una IA con permisos de administrador; alguien con control de tu servidor o de tu cuenta de GitHub; un error en las propias herramientas (por eso existe `ataque`). Los mensajes de estas herramientas están en español.

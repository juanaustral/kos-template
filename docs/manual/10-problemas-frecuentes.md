# 10 — Problemas frecuentes

| Problema | Solución |
|---|---|
| `ruby: command not found` | Instala Ruby 3 ([Instalación](01-instalacion.md)) y abre una terminal nueva. |
| El asistente dice "KOS ya está instalado" | Ya lo corriste. Para un módulo: `--solo-modulo <nombre>`. Para repetir todo: `--forzar`. |
| `ERROR [estado-incongruente]` o `[index-incongruente]` | Un proyecto tiene estados distintos en registro, índice y ficha. Pide: *"Corrige el estado del proyecto X en los tres lugares."* |
| `ERROR [project-unregistered]` | Hay una carpeta en `projects/` que no está en `registry/projects.yaml`. Regístrala o muévela. |
| `ERROR [link-broken]` | Un enlace apunta a un archivo que no existe. Corrige la ruta o quita el enlace. |
| `ERROR [list-rows-dropped]` | Se borraron filas de una lista. Si fue un error: `git checkout -- knowledge/lists/<archivo>`. Si fue a propósito: `KOS_ALLOW_ROW_DROP=1 git commit ...` y pon `[permitir-borrar-filas]` en el mensaje del commit (así tampoco falla GitHub). |
| Un commit se frena con errores del validador | Desde la instalación, el validador corre antes de cada commit. Corrige lo que indica. Solo en una emergencia: `git commit --no-verify`. |
| Después de actualizar aparecen `placeholder-pendiente` | Corre `ruby tools/kos_init.rb --rellenar`. |
| `ERROR [possible-secret-…]` | Hay algo que parece una clave. Bórralo del archivo y, si llegó a Git, cambia esa clave en su servicio. |
| `ERROR [placeholder-pendiente]` | Quedó un `{{…}}` sin completar. Reemplázalo a mano. |
| La IA no sigue las reglas | Pídele que lea `AGENTS.md` de nuevo. Si es un chat, verifica que el texto de `adapters/pegar-en-una-ia.md` esté en las instrucciones. |
| La IA "recuerda" cosas viejas que no están en KOS | Es su memoria propia. Desactívala para estos temas o dile: *"Usa solo KOS como fuente."* |
| La IA no dio el Cierre | *"Dame el Cierre."* |
| Dos copias de KOS con cambios distintos | `git pull` en la que está atrasada. Si hay conflicto, pídele a una IA que lo resuelva mostrándote las dos versiones. |
| Quiero deshacer el último cambio de la IA | `git log` para ver el commit y `git revert <commit>`. |

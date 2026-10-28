# Migraciones de datos

Cuando una versión nueva de KOS cambia la forma de tus datos (una clave nueva en `kos.yaml`, una columna en una lista), trae aquí un script que la adapta. `tools/kos_update.rb` los corre solo.

- Nombre: `NNN-que-hace.rb`, donde `NNN` es el `schema_version` al que lleva (ej.: `002-agrega-clave-x.rb`).
- Se corren en orden los que están entre tu `schema_version` y el de la versión nueva. Después se actualiza `schema_version` en tu `kos.yaml`.
- Cada script recibe la raíz de KOS como único argumento, no hace preguntas, puede correrse dos veces sin romper nada y sale con 1 si falla.

Por ahora no hay migraciones: el esquema sigue en la versión 1.

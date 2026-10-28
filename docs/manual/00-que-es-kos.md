# 00 — Qué es KOS

## El problema
Usas varias IAs. Cada una recuerda una parte distinta de ti, a su manera, en servidores que no controlas. Cuando cambias de herramienta, de cuenta o de modelo, empiezas de cero. Lo que decidiste hace un mes en un chat ya no existe en ningún lado.

## La idea
KOS invierte la relación: **la memoria es tuya y vive en tus archivos**. Las IAs son trabajadores temporales que entran, leen las reglas, hacen el trabajo y dejan registrado lo que cambió.

- **Archivos simples**: Markdown, YAML y CSV. Se leen con cualquier editor, hoy y dentro de veinte años.
- **Git**: cada cambio queda con fecha y autor, se puede deshacer y se respalda fácil.
- **Una sola entrada**: `AGENTS.md`. Cualquier IA la lee primero y sabe qué hacer.
- **Reglas compartidas**: dónde va cada cosa, qué necesita tu aprobación, cómo cerrar un trabajo.

## Qué ganas
- **Cambiar de IA sin perder nada.** Claude hoy, otra mañana: todas leen lo mismo.
- **Continuidad.** Un proyecto se retoma donde quedó, aunque pase un mes o cambie la IA.
- **Control.** Ves todo lo que una IA escribió, y nada sensible sale sin que lo autorices.
- **Menos repetición.** No vuelves a explicar quién eres ni cómo te gusta trabajar.

## Las tres piezas que hacen que funcione
1. **La regla de registro (DEC-001).** Lo que se decide, se crea o se aprende se escribe en KOS en el mismo trabajo. Si solo se dijo en el chat, no existe.
2. **El Cierre.** Cada trabajo termina con tres líneas: qué se registró, cómo se comprobó y qué falta. Lees tres líneas y sabes si el trabajo está bien hecho.
3. **El validador.** Un programa revisa que nada se haya roto: estados coherentes, enlaces, secretos, filas borradas. Lo corre la IA y, si usas GitHub, también se corre solo.

## Qué no es
- No es una app ni un servicio: no hay cuenta, servidor ni suscripción.
- No es una IA: funciona con las que ya usas.
- No es un gestor de tareas complejo: es una memoria ordenada que cualquier IA entiende.

Siguiente: [Instalación](01-instalacion.md).

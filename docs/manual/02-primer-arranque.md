# 02 — Primer arranque

## 1. Corre el asistente
En la carpeta de KOS:
```
ruby tools/kos_init.rb
```
Te pregunta:

| Pregunta | Ejemplo | Para qué sirve |
|---|---|---|
| Cómo te llaman | Ana | Las IAs te nombran así y saben de quién es KOS. |
| Idioma | español | En qué idioma responden. |
| Trato | tú / vos / usted | Cómo te hablan. |
| Estilo | directo y breve, sin emojis | El tono de las respuestas. |
| Áreas | Trabajo, Salud, Finanzas | Crea un archivo por área en `knowledge/areas/`. |
| Módulos | listas, finanzas | Agrega listas (películas, series, libros) o registro de gastos. |
| IAs | claude-code, cursor | Prepara los archivos que cada IA busca. |

Al terminar corre el validador. Tiene que decir **Errores: 0**.

¿Prefieres no responder preguntas? Usa opciones:
```
ruby tools/kos_init.rb --si --nombre "Ana" --trato tú --areas "Trabajo,Salud" --modulos listas --ias claude-code
```

## 2. Guarda el estado
```
git add -A
git commit -m "KOS instalado"
```
(Si Git te pide nombre y correo: `git config --global user.name "Tu Nombre"` y `git config --global user.email "tu@correo"`.)

## 3. Completa tu perfil (con ayuda)
Abre `knowledge/profile.md`. Puedes completarlo a mano o, mejor, pedírselo a tu IA:
> "Hazme una entrevista corta, de a una pregunta, para completar `knowledge/profile.md`. Al final muéstrame el texto y escríbelo cuando lo apruebe."

## 4. Carga tus proyectos reales
Pídele a tu IA, uno por vez:
> "Crea en KOS el proyecto «Lanzar mi newsletter»: objetivo …, estado activo, próxima acción …"

La IA crea la carpeta, la registra y la agrega al índice (receta "Crear un proyecto"). El proyecto de ejemplo `mi-primer-proyecto` te sirve para la primera prueba; después renómbralo o archívalo.

## 5. Qué quedó en tu carpeta
- `AGENTS.md` con tu nombre y tu forma de hablar.
- `knowledge/profile.md` y tus áreas listas para completar.
- Tres decisiones base en `decisions/` (registro obligatorio, estados coherentes, KOS liviano).
- Los archivos de las IAs que elegiste (`CLAUDE.md`, `.cursor/rules/`, `GEMINI.md`).
- `kos.yaml` con tu configuración.

Siguiente: [Conectar tus IAs](03-conectar-tus-ias.md).

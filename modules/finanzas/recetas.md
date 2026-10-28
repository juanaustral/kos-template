
## Registrar un gasto (módulo finanzas)
- Archivo: `projects/finanzas/data/gastos.csv`. Agrega una fila al final: `fecha,categoria,monto,moneda,nota`.
- `categoria` debe ser un `id` de `categorias.csv`; si no encaja, pregunta. `fecha` en `AAAA-MM-DD`. Mantén el orden por fecha.
- No conviertas monedas. Nunca guardes números de tarjeta, cuenta ni documentos. No reordenes ni borres filas.

## Leer el balance (módulo finanzas)
- Suma `monto` por mes y por categoría, separando monedas. Di siempre qué período cubren los datos. No estimes lo que no está cargado.

# Finanzas

ID: `finanzas`
Alcance: `project:finanzas`
Estado: Activo
Propietario: {{OWNER_NAME}}
Última revisión: {{FECHA_INSTALACION}}
Sensibilidad: Confidencial

## Objetivo
Registrar gastos en archivos simples para poder pedirle a cualquier IA balances, comparaciones y alertas.

## Datos
- `data/categorias.csv`: `id,nombre,tipo`. Agrega categorías nuevas al final.
- `data/gastos.csv`: `fecha,categoria,monto,moneda,nota`. `fecha` en `AAAA-MM-DD`, `categoria` = un `id` de categorías, `monto` con punto decimal, `moneda` en código de tres letras (`ARS`, `USD`, `EUR`...).

## Próxima acción
Cargar los gastos del mes en curso.

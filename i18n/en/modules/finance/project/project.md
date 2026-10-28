# Finance

ID: `finance`
Scope: `project:finance`
Status: Active
Owner: {{OWNER_NAME}}
Last review: {{FECHA_INSTALACION}}
Sensitivity: Confidential

## Goal
Log expenses in simple files so any AI can produce balances, comparisons and alerts.

## Data
- `data/categories.csv`: `id,name,type`. Add new categories at the end.
- `data/expenses.csv`: `date,category,amount,currency,note`. `date` as `YYYY-MM-DD`, `category` = an `id` from categories, `amount` with a decimal point, `currency` as a three-letter code (`USD`, `EUR`, `GBP`...).

## Next action
Log this month's expenses.

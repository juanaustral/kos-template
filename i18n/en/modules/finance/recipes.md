
## Log an expense (module finance)
- File: `projects/finance/data/expenses.csv`. Add a row at the end: `date,category,amount,currency,note`.
- `category` must be an `id` from `categories.csv`; if nothing fits, ask. `date` as `YYYY-MM-DD`. Keep the date order.
- Don't convert currencies. Never store card, account or ID numbers. Don't reorder or delete rows.

## Read the balance (module finance)
- Sum `amount` by month and category, separating currencies. Always state the period the data covers. Don't estimate what isn't logged.

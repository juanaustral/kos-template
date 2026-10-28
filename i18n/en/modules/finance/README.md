# Module: finance

Creates the `projects/finance/` project with:
- `data/categories.csv` — expense categories (`id,name,type`).
- `data/expenses.csv` — one expense per row (`date,category,amount,currency,note`), sorted by date.

The validator checks headers, known categories, numeric amounts, ISO dates and order. The data is Confidential: never card, account or ID numbers.

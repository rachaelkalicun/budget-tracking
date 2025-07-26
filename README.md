# Budget Normalizer

This Ruby tool helps normalize CSVs from various credit card providers into a standard format, so you can categorize and track your expenses and income consistently.

This project was born out of personal need. After months of neglecting my manual spreadsheet, I finally got tired of copying and pasting rows from different banks every month, especially with different date formats, column names, and how debits and credits are handled.

## Features

- Supports multiple bank formats: Chase (Amazon and IHG), Citi, Capital One
- Normalizes dates like `7/4/2025`, `2025-07-04`, and even `July 4, 2025`
- Handles amounts in a consistent numeric format
- Preserves source information
- Categorizes data into `income.csv` and `expenses.csv` based on simple rules

## Current Format Support

The tool currently supports these CSV structures:

| Bank        | Format Example                                      |
|-------------|-----------------------------------------------------|
| Chase       | `Transaction Date`, `Description`, `Amount`        |
| Citi        | `Date`, `Description`, `Debit`, `Credit`           |
| Capital One | `Transaction Date`, `Description`, `Debit`, `Credit` |

## Getting Started

Clone the repo and run:

```bash
bundle install
```

Then run the processor:

```bash
ruby run.rb path/to/your/csvs/*.csv
```

This will generate:

- `normalized_income.csv`
- `normalized_expenses.csv`

## How It Works

Each CSV file is matched to a known bank type using the filename. The contents are parsed, normalized, and split into income or expenses based on the transaction type.

### Income vs Expense Logic

We default to assuming all transactions are expenses unless:

- The description contains **"reward"**, **"interest"**, or **"payment received"** (case-insensitive)
- You want to refine this? See `lib/normalize_csvs.rb`, method `income_transaction?`

### Negative Values

We automatically invert amounts for refunds or credits:
- Refunds on credit cards are still treated as **expenses**
- Rewards or cashback posted as statement credits are treated as **income**

### Supported Date Formats

The tool supports:
- `MM/DD/YYYY` (e.g. `7/4/2025`)
- `YYYY-MM-DD` (e.g. `2025-07-04`)
- Natural dates like `July 4, 2025` or `4 Jul 2025`

## Tests

Run tests with:

```bash
ruby test/normalize_csvs_test.rb
```

Tests cover:
- Merging files
- Parsing amounts and signs correctly
- Handling missing or malformed data
- Normalizing different date formats

## To use

You’ll need to do two things:

1. **Update the `FORMATS` hash** in `run.rb` and `test/normalize_csvs_test.rb` to reflect the column headers in your own CSVs.
2. **Customize `income_transaction?`** if your income sources are labeled differently.

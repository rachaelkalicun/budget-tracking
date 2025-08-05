# Budget CSV Normalizer

This Ruby script helps you consolidate, clean, and categorize financial CSVs from different sources (banks, credit cards, brokerages, Amazon, etc.). It generates normalized `income.csv` and `expenses.csv` files to support budgeting, personal finance tracking, or importing into other tools like [The Measure of a Plan budget tracking tool](https://themeasureofaplan.com/budget-tracking-tool/).

---

## Features

- Normalize CSVs from multiple institutions
- Categorize transactions using customizable rules
- Handle Amazon orders with extra care
- Split transactions into `income.csv` and `expenses.csv`
- Output consistent fields: `Date`, `Description`, `Amount`, `Category`, `Notes`, `Source`

---

## Directory Structure

```
.
├── data/                   # Put raw CSV files here
├── output/                 # Normalized output files will be written here
├── lib/
│   ├── normalize_csvs.rb   # Main normalization and categorization logic
│   ├── categorization_rules.rb # Regex-based transaction categorization
│   └── formats.rb          # CSV parsing formats per account type
├── bin/normalize_and_export.rb  # Entry point for running the script
```

---

## Usage

1. **Install Ruby**

2. **Add your CSV files**
   Drop your `.csv` files into the `data/` directory. File names must include a keyword that maps to a format key (e.g., `chase_ihg.csv` → `chase_ihg`).

3. **Run the script**

```bash
ruby bin/normalize_and_export.rb
```

4. **Check the results**
   The script creates:

- `output/income.csv`
- `output/expenses.csv`

---

## Supported Sources

Add or adjust these in `lib/formats.rb`.

| Format Key    | Institution or Type      | Notes                                 |
|---------------|--------------------------|----------------------------------------|
| `amazon`      | Amazon Orders            | Uses special rules for product parsing |
| `capital_one` | Capital One Credit Card  | Has separate debit/credit columns      |
| `chase_ihg`   | Chase IHG Card           | Single amount field                    |
| `citibank`    | CitiBank Credit Card     | Standard dual-column format            |
| `elevations`  | Elevations Credit Union  | Bank account / income                  |
| `ent`         | ENT Credit Union         | Bank account / income                  |
| `fidelity`    | Fidelity Investments     | Includes dividends/interest            |
| `vanguard`    | Vanguard                 | Includes investment transactions       |

---

## Categorization

Edit `lib/categorization_rules.rb` to adjust logic for how transactions are classified.

### Standard Rule Example

```ruby
/amc|denver fil|symphony/i => "Entertainment"
/trader joe|safeway/i => "Groceries"
```

### Amazon-Specific Rule Example

```ruby
/serum|protein|shampoo/i => "Beauty, health, hygiene"
/book|novel/i => "Books"
```

If no match is found:

- Amazon transactions → `"Amazon - Uncategorized"`
- Other transactions → `"Uncategorized"`

---

## Extras

- **Notes for Amazon Multi-Item Orders**
  Amazon transactions containing multiple items are marked with `"Amazon Multi Order"` in the `Notes` field.

- **Transaction Type Overrides**
  Some credits or debits are reclassified from income to expense or vice versa based on keywords like `"statement credit"` or `"type: billpay"`.

- **Skipped Transactions**
  Payment transfers, tax refunds, and known irrelevant rows are skipped automatically.

---

## Example Output

```csv
Date,Description,Amount,Category,Notes,Source
2025-07-01,"Starbucks Coffee",5.25,"Going out","",Chase_ihg
2025-07-02,"Salary",2500.00,"Uncategorized","","Ent"
```

---

## Customization Tips

### Add a New Institution

1. Add an entry to `FORMATS` in `lib/formats.rb`
2. Ensure your file name includes the format key
3. Match the CSV column names for `date`, `description`, `debit`, `credit`, etc.

### Add or Tweak Categories

1. Update `CATEGORIZATION_RULES` in `lib/categorization_rules.rb`
2. Use regex patterns for flexible matching

---

## Privacy

All files are processed locally. No network requests are made. The input and output files are ignored by Git.

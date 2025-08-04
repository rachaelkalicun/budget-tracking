FORMATS = {
  "amazon" => { type: :expense, date: "date", description: "items", debit: "total", credit: "refund", bank_account: false },
  "capital_one" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Debit", credit: "Credit", bank_account: false },
  "chase_ihg" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: false },
  "citibank" => { type: :expense, date: "Date", description: "Description", debit: "Debit", credit: "Credit", bank_account: false },
  "elevations" => { type: :income, date: "Posting Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: true },
  "ent" => { type: :income, date: "Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: true },
  "fidelity" => { type: :income, date: "Run Date", description: "Action", debit: "Amount ($)", credit: "Amount ($)", bank_account: true },
  "vanguard" => { type: :income, date: "Settlement Date", description: "Transaction Description", debit: "Net Amount", credit: "Net Amount", bank_account: true }
}

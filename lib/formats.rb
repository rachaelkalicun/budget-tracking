FORMATS = {
  "capital_one" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Debit", credit: "Credit", bank_account: false },
  "chase_amazon" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: false },
  "chase_ihg" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: false },
  "citibank" => { type: :expense, date: "Date", description: "Description", debit: "Debit", credit: "Credit", bank_account: false },
  "elevations" => { type: :income, date: "Posting Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: true },
  "ent" => { type: :income, date: "Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: true }
}

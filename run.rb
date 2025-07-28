require_relative "lib/normalize_csvs"
require "csv"

# Define formats hash if not already passed in
FORMATS = {
  "capital_one" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Debit", credit: "Credit", sign_needs_flipping: false },
  "chase_amazon" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount", sign_needs_flipping: false },
  "chase_ihg" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount", sign_needs_flipping: false },
  "citibank" => { type: :expense, date: "Date", description: "Description", debit: "Debit", credit: "Credit", sign_needs_flipping: false },
  "elevations" => { type: :income, date: "Posting Date", description: "Description", debit: "Amount", credit: "Amount", sign_needs_flipping: true },
  "ent" => { type: :income, date: "Posting Date", description: "Description", debit: "Amount", credit: "Amount", sign_needs_flipping: true }
}

# Input file paths
input_paths = Dir["data/*.csv"]

# Normalize all rows
rows = NormalizeCsvs.normalize_csvs(input_paths, FORMATS)

# Create output directory if it doesn't exist
Dir.mkdir("output") unless Dir.exist?("output")

# Split into income and expenses
income_rows = rows.select { |row| row["Type"] == "Income" }.sort_by { |row| Date.parse(row["Date"]) }
expense_rows = rows.select { |row| row["Type"] == "Expense" }.sort_by { |row| Date.parse(row["Date"]) }

NormalizeCsvs.write_csv("output/income.csv", income_rows, ["Date", "Description", "Amount", "Category", "Notes", "Source"])
NormalizeCsvs.write_csv("output/expenses.csv", expense_rows, ["Date", "Description", "Amount", "Category", "Notes", "Source"])

puts "Wrote #{expense_rows.size} expenses and #{income_rows.size} income rows."

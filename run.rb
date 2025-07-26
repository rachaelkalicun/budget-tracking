require_relative "lib/normalize_csvs"
require "csv"

# Define formats hash if not already passed in
FORMATS = {
  "chase_amazon" => { date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount" },
  "chase_ihg" => { date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount" },
  "citibank" => { date: "Date", description: "Description", debit: "Debit", credit: "Credit" },
  "capital_one" => { date: "Transaction Date", description: "Description",  debit: "Debit", credit: "Credit" },
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

# Write expenses
CSV.open("output/expenses.csv", "w") do |csv|
  csv << ["Date", "Description", "Amount", "Source"]
  expense_rows.each { |row| csv << row.values_at("Date", "Description", "Amount", "Source") }
end

# Write income
CSV.open("output/income.csv", "w") do |csv|
  csv << ["Date", "Description", "Amount", "Source"]
  income_rows.each { |row| csv << row.values_at("Date", "Description", "Amount", "Source") }
end

puts "Wrote #{expense_rows.size} expenses and #{income_rows.size} income rows."

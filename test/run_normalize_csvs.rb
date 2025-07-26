# run_normalize_csvs.rb
require "csv"
require_relative "lib/normalize_csvs"

FORMATS = {
  "chase_amazon" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount" },
  "chase_ihg" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount" },
  "citibank" => { type: :expense, date: "Date", description: "Description", debit: "Debit", credit: "Credit" },
  "capital_one" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Debit", credit: "Credit" },
}

input_files = Dir["./csv_inputs/*.csv"]

rows = NormalizeCsvs.normalize_csvs(input_files, FORMATS)

CSV.open("normalized_output.csv", "w") do |csv|
  csv << ["Date", "Description", "Amount", "Source"]
  rows.each { |row| csv << [row["Date"], row["Description"], row["Amount"], row["Source"]] }
end

puts "Output written to normalized_output.csv"

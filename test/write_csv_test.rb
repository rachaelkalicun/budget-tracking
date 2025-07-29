require "csv"
require "date"
require_relative "../lib/normalize_csvs"
require_relative "../lib/formats" # Create this to hold FORMATS hash

input_paths = Dir["data/*.csv"]
output_dir = "output"
Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

rows = NormalizeCsvs.normalize_csvs(input_paths, FORMATS)

income_rows = rows.select { |row| row["Type"] == "Income" }.sort_by { |row| Date.parse(row["Date"]) }
expense_rows = rows.select { |row| row["Type"] == "Expense" }.sort_by { |row| Date.parse(row["Date"]) }

columns = ["Date", "Description", "Amount", "Category", "Notes", "Source"]

NormalizeCsvs.write_csv("#{output_dir}/income.csv", income_rows, columns)
NormalizeCsvs.write_csv("#{output_dir}/expenses.csv", expense_rows, columns)

puts "Wrote #{expense_rows.size} expenses and #{income_rows.size} income rows."

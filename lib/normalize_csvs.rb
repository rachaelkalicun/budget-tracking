# lib/normalizer.rb

require "pry"
require_relative 'categorization_rules'
require_relative 'formats'

module NormalizeCsvs
  # loop through each file path and match the account format based on the file name - "chase_ihg.csv" -> "chase_ihg"
  # read the CSV and normalize each row/fields
  # skip rows that match certain patterns in the description
  # return an array of hashes with normalized data
  # e.g. { "Date" => "2023-01-01", "Description" => "Some description", "Amount" => 100.0, "Category" => "Some Category", "Notes" => "", "Source" => "chase_ihg", "Type" => "Expense" }
  # write the normalized data to a new CSV file

  SKIP_TRANSACTION_TYPES = /(achxfer|capital one type: billpay|chase creditcard type: billpay|citibank masterc type: billpay|electronic payment|irs|^items$|payment thank you|credit balance refund|reinvestment)/i
  INCOME_OVERRIDES = /statement credit|stubhub cons type: payments|thankyou points/i
  EXPENSE_OVERRIDES = /type: billpay|check #|comcast|xcel/i

  def self.normalize_csvs(file_paths, account_formats)
    rows = []

    file_paths.each do |path|
      account_key = match_account(path, account_formats.keys)
      format = account_formats[account_key] or raise ArgumentError, "Unknown source for #{path}"

      CSV.foreach(path, headers: true, skip_blanks: true) do |row|
        next if row[format[:description]].nil?
        next if row[format[:description]].to_s.strip.downcase.strip.match?(SKIP_TRANSACTION_TYPES)
        rows << normalize_row(row, format, account_key)
      end
    end

    rows
  end

  def self.normalize_row(row, format, account_key)
    # Match keywords that indicate type overrides
    # e.g. "statement credit" or "thankyou points" for income
    # e.g. "type: billpay" or "check #" for expenses
    description = row[format[:description]].to_s.strip
    transaction_type = self.transaction_type_override(format[:type] || :expense, description)
    # Return a normalized hash for the row
    {
      "Date" => normalize_date(row[format[:date]]),
      "Description" => description,
      "Amount" => self.calculate_amount(row, format, transaction_type),
      "Category" => self.categorize_transaction(description, account_key),
      "Notes" => account_key == "amazon" && row[format[:description]].to_s.match?(/; (?=(?!")[^\s])/ ) ? "Amazon Multi Order" : "",
      "Source" => account_key.capitalize,
      "Type" => transaction_type
    }
  end

  def self.normalize_date(value)
    str = value.to_s.strip
    return nil if str.empty?

    # Match MM/DD/YYYY or M/D/YYYY
    if str.match(%r{\A\d{1,2}/\d{1,2}/\d{4}\z})
      Date.strptime(str, "%m/%d/%Y").to_s

    # Match YYYY-MM-DD
    elsif str.match(/\A\d{4}-\d{2}-\d{2}\z/)
      Date.parse(str).to_s

    # Fallback for things like "July 4, 2025" or "4 Jul 2025"
    else
      Date.parse(str).to_s
    end
  end

  def self.calculate_amount(row, format, transaction_type)
    debit_column = row[format[:debit]].to_s.strip
    credit_column = row[format[:credit]].to_s.strip
    single_amount_column = format[:debit] == format[:credit]
    is_bank = format[:bank_account]

    return flip_sign_for_single_column_credit_card_formats(debit_column) if single_amount_column && !is_bank && transaction_type == "Expense"
    return convert_bank_expenses_to_positive(debit_column) if !debit_column.empty? && is_bank && transaction_type == "Expense"
    return parse_amount(debit_column) unless debit_column.empty?
    return -parse_amount(credit_column) unless credit_column.empty?

    0.0
  end

  def self.transaction_type_override(base_type, description)
    return "Income" if base_type == :expense && description.match?(INCOME_OVERRIDES)
    return "Expense" if base_type == :income && description.match?(EXPENSE_OVERRIDES)
    base_type.to_s.capitalize
  end

  def self.flip_sign_for_single_column_credit_card_formats(value)

    numeric = value.to_s.gsub(/[\$,()]/, "").to_f
    -numeric
  end

  def self.convert_bank_expenses_to_positive(value)
    value.to_s.gsub(/[\$,()]/, "").to_f.abs
  end

  def self.parse_amount(value)
    str = value.to_s.strip
    return 0.0 if str.empty?

    is_negative = str.match?(/^\(\$?\d/)
    numeric = str.gsub(/[\$,()]/, "").to_f

    is_negative ? -numeric : numeric
  end

  def self.categorize_transaction(description, source)
    if source == "amazon"
      CATEGORIZATION_RULES_AMAZON.each do |pattern, category|
        return category if description =~ pattern
      end
      return "Uncategorized - Amazon"
    end
    CATEGORIZATION_RULES.each do |pattern, category|
      return category if description =~ pattern
    end
    "Uncategorized"
  end

  # Match the source key based on the file name
  # e.g. "chase_ihg.csv" -> "chase_ihg"

  def self.match_account(path, known_sources)
    basename = File.basename(path).downcase
    known_sources.find { |key| basename.include?(key) }
  end

  def self.write_csv(file_path, rows, columns)
    CSV.open(file_path, "w") do |csv|
      rows.each do |row|
        csv << columns.map { |col| row[col] }
      end
    end
  end
end

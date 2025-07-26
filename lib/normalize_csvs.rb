# lib/normalizer.rb

require "pry"
require_relative 'categorization_rules'

module NormalizeCsvs
  def self.normalize_csvs(file_paths, formats)
    rows = []

    file_paths.each do |path|
      source_key = match_credit_card(path, formats.keys)
      format = formats[source_key] or
        raise ArgumentError, "Unknown source for #{path}"

      CSV.foreach(path, headers: true, skip_blanks: true) do |row|
        next if row[format[:description]].to_s.strip.downcase.strip.match?(/(electronic payment|payment thank you)/)
        rows << normalize_row(row, format, source_key)
      end
    end

    rows
  end

  def self.normalize_row(row, format, source_key)
    raw_description = row[format[:description]].to_s.strip
    amount =
      # { debit: "Amount", credit: "Amount" }
      if format[:debit] == format[:credit]
        # debit and credit are both the same and point to amount
        parse_amount(row[format[:debit]])
      #purchases
      elsif row[format[:debit]].to_s.strip != ""
        parse_amount(row[format[:debit]])

      # refunds
      elsif row[format[:credit]].to_s.strip != ""
        -parse_amount(row[format[:credit]])

      else
        0.0
      end

    category = self.categorize_transaction(raw_description)

    # Determine default type based on format type
    base_type = format[:type] || :expense

    # Detect keywords that indicate income (override)
    description = raw_description.downcase
    if base_type == :expense && description.match?(/(statement credit|thankyou points)/)
      type = "Income"
    else
      type = base_type.to_s.capitalize
    end

    {
      "Date" => normalize_date(row[format[:date]]),
      "Description" => raw_description,
      "Amount" => amount,
      "Category" => category,
      "Notes" => '',
      "Source" => source_key.capitalize,
      "Type" => type
    }
  end

  def self.categorize_transaction(description)
    CATEGORIZATION_RULES.each do |pattern, category|
      return category if description =~ pattern
    end
    "Uncategorized"
  end

  # Match the source key based on the file name
  # e.g. "chase_amazon.csv" -> "chase_amazon"

  def self.match_credit_card(path, known_sources)
    basename = File.basename(path).downcase
    known_sources.find { |key| basename.include?(key) }
  end

  def self.normalize_date(value)
    str = value.to_s.strip

    return nil if str.empty?

    # Match MM/DD/YYYY or M/D/YYYY
    if str.match(%r{\A\d{1,2}/\d{1,2}/\d{4}\z})
      Date.strptime(str, "%m/%d/%Y").to_s

    # Match YYYY-MM-DD or parseable ISO-style
    elsif str.match(/\A\d{4}-\d{2}-\d{2}\z/)
      Date.parse(str).to_s

    # Fallback for things like "July 4, 2025" or "4 Jul 2025"
    else
      Date.parse(str).to_s
    end
  end

  def self.parse_amount(value)
    str = value.to_s.strip

    return 0.0 if str.empty?

    is_negative = str.match?(/^\(\$?\d/)
    numeric = str.gsub(/[\$,()]/, "").to_f

    is_negative ? -numeric : numeric
  end

  def self.write_csv(file_path, rows, columns)
    CSV.open(file_path, "w") do |csv|
      rows.each do |row|
        csv << columns.map { |col| row[col] }
      end
    end
  end
end

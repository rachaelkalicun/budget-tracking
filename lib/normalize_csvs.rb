# lib/normalizer.rb

require "pry"

module NormalizeCsvs
  def self.normalize_csvs(file_paths, formats)
    rows = []

    file_paths.each do |path|
      source_key = match_credit_card(path, formats.keys)
      format = formats[source_key] or
        raise ArgumentError, "Unknown source for #{path}"

      CSV.foreach(path, headers: true) do |row|
        rows << normalize_row(row, format, source_key)
      end
    end

    rows
  end

  def self.normalize_row(row, format, source_key)
    amount =
      # { debit: "Amount", credit: "Amount" }
      if format[:debit] == format[:credit]
        # debit and credit are both the same and point to amount
        row[format[:debit]].to_f

      #purchases
      elsif row[format[:debit]].to_s.strip != ""
        row[format[:debit]].to_f

      # refunds
      elsif row[format[:credit]].to_s.strip != ""
        -row[format[:credit]].to_f

      else
        0.0
      end

    {
      "Date" => normalize_date(row[format[:date]]),
      "Description" => row[format[:description]].to_s.strip,
      "Amount" => amount,
      "Source" => source_key.capitalize
    }
  end

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
end

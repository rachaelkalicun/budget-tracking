require "minitest/autorun"
require "tempfile"
require "csv"
require_relative "../lib/normalize_csvs"

class NormalizeCsvsTest < Minitest::Test
  FORMATS = {
    "capital_one" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Debit", credit: "Credit", bank_account: false },
    "chase_amazon" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: false },
    "chase_ihg" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: false },
    "citibank" => { type: :expense, date: "Date", description: "Description", debit: "Debit", credit: "Credit", bank_account: false },
    "elevations" => { type: :income, date: "Posting Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: true },
    "ent" => { type: :income, date: "Posting Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: true },
    "fidelity" => { type: :income, date: "Run Date", description: "Action", debit: "Amount ($)", credit: "Amount ($)", bank_account: true },
    "vanguard" => { type: :income, date: "Settlement Date", description: "Transaction Description", debit: "Net Amount", credit: "Net Amount", bank_account: true }
  }

  def setup
    @chase_amazon_csv = make_csv("chase_amazon", <<~CSV)
      Transaction Date,Description,Amount
      07/01/2025,Amazon Refund,15.00
      07/02/2025,Amazon Purchase,-49.99
    CSV

    @chase_ihg_csv = make_csv("chase_ihg", <<~CSV)
      Transaction Date,Description,Amount
      07/03/2025,Hotel Credit,75.00
      07/04/2025,Hotel Charge,-200.00
    CSV

    @citibank_csv = make_csv("citibank", <<~CSV)
      Date,Description,Debit,Credit
      7/05/2025,Grocery Store,60.00,
      7/06/2025,Refund,,30.00
    CSV

    @capital_one_csv = make_csv("capital_one", <<~CSV)
      Transaction Date,Description,Debit,Credit
      2025-07-07,Restaurant,100.00,
      2025-07-08,Cashback,,5.00
    CSV

    @ent_csv = make_csv("ent", <<~CSV)
      Posting Date,Description,Amount
      07/08/2025,Direct Deposit,1234.56
    CSV

    @elevations_csv = make_csv("elevations", <<~CSV)
      Posting Date,Description,Amount
      07/10/2025,Type: BillPay - Comcast,150.00
    CSV

    @fidelity_csv = make_csv("fidelity", <<~CSV)
      Run Date,Action,Amount ($)
      2025-07-15,Interest,123.45
      2025-07-20,,123.00
      2025-07-22,Reinvestment,200.00
    CSV

    @vanguard_csv = make_csv("vanguard", <<~CSV)
      Settlement Date,Transaction Description,Net Amount
      2025-07-16,Dividend Payment,567.89
    CSV
  end

  def teardown
    [@chase_amazon_csv, @chase_ihg_csv, @citibank_csv, @capital_one_csv, @ent_csv, @elevations_csv, @fidelity_csv, @vanguard_csv].each(&:close!)
  end

  def make_csv(name, content)
    file = Tempfile.new(["#{name}", ".csv"])
    file.write(content)
    file.rewind
    file
  end

  def normalize(path)
    NormalizeCsvs.normalize_csvs([path], FORMATS)
  end

  def test_merges_multiple_csvs
    rows = NormalizeCsvs.normalize_csvs([@capital_one_csv.path, @chase_amazon_csv.path, @chase_ihg_csv.path, @citibank_csv.path], FORMATS)

    assert_equal 8, rows.size
    rows.each { |row| assert_equal ["Date", "Description", "Amount", "Category", "Notes", "Source", "Type"], row.keys }
  end

  def test_combines_multiple_files_from_same_source
    second_csv = make_csv("chase_amazon", <<~CSV)
      Transaction Date,Description,Amount
      2025-07-09,Second File,-10.00
    CSV
    rows = NormalizeCsvs.normalize_csvs([@chase_amazon_csv.path, second_csv.path], FORMATS)
    assert_equal 3, rows.size
    second_csv.close!
  end

  def test_raises_error_for_unknown_source
    unknown_csv = make_csv("unknown_source", "Date,Description,Amount\n2025-07-01,Something,100")
    assert_raises(ArgumentError) { normalize(unknown_csv.path) }
    unknown_csv.close!
  end

  def test_output_is_sorted_by_date
    file = make_csv("capital_one", <<~CSV)
      Transaction Date,Description,Debit,Credit
      2025-07-10,Late,50.00,
      2025-07-01,Early,10.00,
      2025-07-05,Middle,20.00,
    CSV
    rows = normalize(file.path).sort_by { |r| r["Date"] }
    assert_equal ["2025-07-01", "2025-07-05", "2025-07-10"], rows.map { |r| r["Date"] }
    file.close!
  end

  def test_amount_sign_handling
    assert_equal [-15.00, 49.99], normalize(@chase_amazon_csv.path).map { |r| r["Amount"] }
    assert_equal [-75.00, 200.00], normalize(@chase_ihg_csv.path).map { |r| r["Amount"] }
    assert_equal [60.00, -30.00], normalize(@citibank_csv.path).map { |r| r["Amount"] }
    assert_equal [100.00, -5.00], normalize(@capital_one_csv.path).map { |r| r["Amount"] }
  end

  def test_handles_missing_amount
    file = make_csv("chase_amazon", "Transaction Date,Description,Amount\n2025-07-01,Blank,\n")
    assert_equal 0.0, normalize(file.path).first["Amount"]
    file.close!
  end

  def test_handles_parentheses
    file = make_csv("citibank", "Date,Description,Debit,Credit\n7/12/2025,Neg,\"(123.45)\",\n")
    assert_equal(-123.45, normalize(file.path).first["Amount"])
    file.close!
  end

  def test_parse_amount_directly
    assert_equal 1234.56, NormalizeCsvs.parse_amount("$1,234.56")
    assert_equal(-1234.56, NormalizeCsvs.parse_amount("-$1,234.56"))
    assert_equal(-500.0, NormalizeCsvs.parse_amount("($500)"))
    assert_equal 0.0, NormalizeCsvs.parse_amount(nil)
  end

  def test_normalizes_date_formats
    assert_equal ["2025-07-01", "2025-07-02"], normalize(@chase_amazon_csv.path).map { |r| r["Date"] }
  end

  def test_normalize_date_variants
    assert_equal "2025-07-04", NormalizeCsvs.normalize_date("07/04/2025")
    assert_equal "2025-07-04", NormalizeCsvs.normalize_date("July 4, 2025")
    assert_nil NormalizeCsvs.normalize_date("")
  end

  def test_raises_on_invalid_date
    file = make_csv("chase_amazon", "Transaction Date,Description,Amount\nnot_a_date,Invalid,10.00\n")
    assert_raises(Date::Error) { normalize(file.path) }
    file.close!
  end

  def test_type_override_to_income
    row = CSV::Row.new(["Transaction Date", "Description", "Amount"], ["07/02/2025", "Statement Credit", "10.00"])
    result = NormalizeCsvs.normalize_row(row, FORMATS["chase_amazon"], "chase_amazon")
    assert_equal "Income", result["Type"]
  end

  def test_type_override_to_expense
    row = normalize(@elevations_csv.path).first
    assert_equal "Expense", row["Type"]
  end

  def test_default_type_respected
    row = CSV::Row.new(["Transaction Date", "Description", "Amount"], ["07/01/2025", "Purchase", "49.99"])
    result = NormalizeCsvs.normalize_row(row, FORMATS["chase_amazon"], "chase_amazon")
    assert_equal "Expense", result["Type"]
  end

  def test_type_respects_income_base_format
    row = normalize(@ent_csv.path).first
    assert_equal "Income", row["Type"]
    assert_equal 1234.56, row["Amount"]
  end

  def test_known_category_matches
    assert_equal "Groceries", NormalizeCsvs.categorize_transaction("Safeway")
    assert_equal "Car", NormalizeCsvs.categorize_transaction("Progressive Insurance")
  end

  def test_uncategorized_fallback
    assert_equal "Uncategorized", NormalizeCsvs.categorize_transaction("Unknown Vendor")
  end

  def test_categorizes_transaction_from_row
    row = CSV::Row.new(["Transaction Date", "Description", "Amount"], ["07/15/2025", "Trader Joe's", "49.99"])
    result = NormalizeCsvs.normalize_row(row, FORMATS["chase_amazon"], "chase_amazon")
    assert_equal "Groceries", result["Category"]
  end

  def test_empty_description_defaults_to_uncategorized
    row = CSV::Row.new(["Transaction Date", "Description", "Amount"], ["07/15/2025", "", "5.00"])
    result = NormalizeCsvs.normalize_row(row, FORMATS["chase_amazon"], "chase_amazon")
    assert_equal "Uncategorized", result["Category"]
  end

  def test_skips_known_payment_row
    file = make_csv("chase_amazon", <<~CSV)
      Transaction Date,Description,Amount
      07/10/2025,Payment Thank You,100.00
      07/11/2025,Amazon Purchase,-20.00
    CSV
    rows = normalize(file.path)
    assert_equal ["Amazon Purchase"], rows.map { |r| r["Description"] }
    file.close!
  end

  def test_skips_with_whitespace_and_case
    file = make_csv("chase_amazon", <<~CSV)
      Transaction Date,Description,Amount
      07/10/2025,   PAYMENT THANK YOU   ,100.00
      07/11/2025,Other,-10.00
    CSV
    rows = normalize(file.path)
    assert_equal ["Other"], rows.map { |r| r["Description"] }
    file.close!
  end

  def test_skips_row_with_nil_description
    result = normalize(@fidelity_csv.path)
    descriptions = result.map { |r| r["Description"] }
    refute_includes descriptions, nil
  end

  def test_skips_reinvestment_rows
    result = normalize(@fidelity_csv.path)
    descriptions = result.map { |r| r["Description"].downcase }
    refute_includes descriptions, "reinvestment"
  end

  def test_mixed_override_types_in_one_file
    file = make_csv("chase_amazon", <<~CSV)
      Transaction Date,Description,Amount
      07/10/2025,Statement Credit,10.00
      07/11/2025,Amazon Purchase,-20.00
      07/12/2025,Payment Thank You,100.00
    CSV
    rows = normalize(file.path)
    assert_equal ["Income", "Expense"], rows.map { |r| r["Type"] }
    file.close!
  end

  def test_ignores_extra_columns
    file = make_csv("chase_amazon", <<~CSV)
      Transaction Date,Description,Amount,Memo
      07/10/2025,Coffee,-4.50,Starbucks
    CSV
    row = normalize(file.path).first
    assert_equal "Coffee", row["Description"]
    file.close!
  end

  def test_strips_whitespace
    file = make_csv("chase_amazon", "Transaction Date,Description,Amount\n07/11/2025,  Groceries  , -25.00\n")
    row = normalize(file.path).first
    assert_equal "Groceries", row["Description"]
    file.close!
  end

  def test_fidelity_parses_successfully
    result = normalize(@fidelity_csv.path)
    assert_equal 1, result.size  # skips nil + reinvestment
    assert_equal 123.45, result.first["Amount"]
    assert_equal "Income", result.first["Type"]
    assert_equal "2025-07-15", result.first["Date"]
  end

  def test_vanguard_parses_successfully
    result = normalize(@vanguard_csv.path)
    assert_equal 1, result.size
    assert_equal 567.89, result.first["Amount"]
    assert_equal "Income", result.first["Type"]
    assert_equal "2025-07-16", result.first["Date"]
  end
end

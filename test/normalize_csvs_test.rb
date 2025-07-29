require "minitest/autorun"
require "tempfile"
require "csv"
require "pry"
require "pry-byebug"
require_relative "../lib/normalize_csvs"

class NormalizeCsvsTest < Minitest::Test
  FORMATS = {
    "capital_one" => { type: :expense, date: "Transaction Date", description: "Description",  debit: "Debit", credit: "Credit", bank_account: false },
    "chase_amazon" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: false },
    "chase_ihg" => { type: :expense, date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: false },
    "citibank" => { type: :expense, date: "Date", description: "Description", debit: "Debit", credit: "Credit", bank_account: false },
    "elevations" => { type: :income, date: "Posting Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: true },
    "ent" => { type: :income, date: "Posting Date", description: "Description", debit: "Amount", credit: "Amount", bank_account: true }
  }

  def setup
    @chase_amazon_csv = Tempfile.new(["chase_amazon", ".csv"])
    @chase_amazon_csv.write(<<~CSV)
      Transaction Date,Description,Amount
      07/01/2025,Amazon Refund,15.00
      07/02/2025,Amazon Purchase,-49.99
    CSV
    @chase_amazon_csv.rewind

    @chase_ihg_csv = Tempfile.new(["chase_ihg", ".csv"])
    @chase_ihg_csv.write(<<~CSV)
      Transaction Date,Description,Amount
      07/03/2025,Hotel Credit,75.00
      07/04/2025,Hotel Charge,-200.00
    CSV
    @chase_ihg_csv.rewind

    @citibank_csv = Tempfile.new(["citibank", ".csv"])
    @citibank_csv.write(<<~CSV)
      Date,Description,Debit,Credit
      7/05/2025,Grocery Store,60.00,
      7/06/2025,Refund,,30.00
    CSV
    @citibank_csv.rewind

    @capital_one_csv = Tempfile.new(["capital_one", ".csv"])
    @capital_one_csv.write(<<~CSV)
      Transaction Date,Description,Debit,Credit
      2025-07-07,Restaurant,100.00,
      2025-07-08,Cashback,,5.00
    CSV
    @capital_one_csv.rewind
  end

  def teardown
    @chase_amazon_csv.close!
    @chase_ihg_csv.close!
    @citibank_csv.close!
    @capital_one_csv.close!
  end

  def test_merges_four_csvs_to_standard_format
    rows = NormalizeCsvs.normalize_csvs([@capital_one_csv.path, @chase_amazon_csv.path, @chase_ihg_csv.path, @citibank_csv.path], FORMATS)
    assert_equal 8, rows.size
    rows.each do |row|
      assert_equal ["Date", "Description", "Amount", "Category", "Notes", "Source", "Type"], row.keys
    end
  end

  def test_chase_amazon_amount_sign_handling
    rows = NormalizeCsvs.normalize_csvs([@chase_amazon_csv.path], FORMATS)
    assert_equal(-15.00, rows[0]["Amount"])
    assert_equal 49.99, rows[1]["Amount"]
    assert_equal "Chase_amazon", rows[0]["Source"]
  end

  def test_chase_ihg_amount_sign_handling
    rows = NormalizeCsvs.normalize_csvs([@chase_ihg_csv.path], FORMATS)
    assert_equal(-75.00, rows[0]["Amount"])
    assert_equal 200.00, rows[1]["Amount"]
    assert_equal "Chase_ihg", rows[0]["Source"]
  end

  def test_citibank_amount_sign_handling
    rows = NormalizeCsvs.normalize_csvs([@citibank_csv.path], FORMATS)
    assert_equal 60.00, rows[0]["Amount"]
    assert_equal(-30.00, rows[1]["Amount"])
    assert_equal "Citibank", rows[0]["Source"]
  end

  def test_capital_one_amount_sign_handling
    rows = NormalizeCsvs.normalize_csvs([@capital_one_csv.path], FORMATS)
    assert_equal 100.00, rows[0]["Amount"]
    assert_equal(-5.00, rows[1]["Amount"])
    assert_equal "Capital_one", rows[0]["Source"]
  end

  def test_raises_error_for_unknown_source
    unknown_csv = Tempfile.new(["unknown_source", ".csv"])
    unknown_csv.write(<<~CSV)
      Date,Description,Amount
      2025-07-01,Unknown Charge,100.00
    CSV
    unknown_csv.rewind

    assert_raises(ArgumentError) do
      NormalizeCsvs.normalize_csvs([unknown_csv.path], FORMATS)
    end

    unknown_csv.close!
  end

  def test_handles_missing_amount_gracefully
    bad_csv = Tempfile.new(["chase_amazon", ".csv"])
    bad_csv.write(<<~CSV)
      Transaction Date,Description,Amount
      2025-07-01,Missing Amount,
    CSV
    bad_csv.rewind

    rows = NormalizeCsvs.normalize_csvs([bad_csv.path], FORMATS)
    assert_equal 0.0, rows.first["Amount"]
    bad_csv.close!
  end

  def test_combines_multiple_files_from_same_source
    another_chase = Tempfile.new(["chase_amazon", ".csv"])
    another_chase.write(<<~CSV)
      Transaction Date,Description,Amount
      2025-07-09,Second File,-10.00
    CSV
    another_chase.rewind

    rows = NormalizeCsvs.normalize_csvs([@chase_amazon_csv.path, another_chase.path], FORMATS)
    assert_equal 3, rows.size
    another_chase.close!
  end

  def test_normalizes_date_formats
    rows = NormalizeCsvs.normalize_csvs([@chase_amazon_csv.path], FORMATS)
    assert_equal "2025-07-01", rows[0]["Date"]
    assert_equal "2025-07-02", rows[1]["Date"]

    rows = NormalizeCsvs.normalize_csvs([@chase_ihg_csv.path], FORMATS)
    assert_equal "2025-07-03", rows[0]["Date"]
    assert_equal "2025-07-04", rows[1]["Date"]

    rows = NormalizeCsvs.normalize_csvs([@citibank_csv.path], FORMATS)
    assert_equal "2025-07-05", rows[0]["Date"]
    assert_equal "2025-07-06", rows[1]["Date"]

    rows = NormalizeCsvs.normalize_csvs([@capital_one_csv.path], FORMATS)
    assert_equal "2025-07-07", rows[0]["Date"]
    assert_equal "2025-07-08", rows[1]["Date"]
  end

  def test_normalize_date_formats_directly
    assert_equal "2025-07-04", NormalizeCsvs.normalize_date("07/04/2025")
    assert_equal "2025-07-04", NormalizeCsvs.normalize_date("7/4/2025")
    assert_equal "2025-07-08", NormalizeCsvs.normalize_date("2025-07-08")
    assert_equal "2025-07-04", NormalizeCsvs.normalize_date("July 4, 2025")
    assert_equal "2025-07-04", NormalizeCsvs.normalize_date("4 Jul 2025")
    assert_equal "2025-07-04", NormalizeCsvs.normalize_date(Date.new(2025, 7, 4))
    assert_nil NormalizeCsvs.normalize_date(nil)
    assert_nil NormalizeCsvs.normalize_date("")
  end

  def test_handles_invalid_date_format
    bad_date_csv = Tempfile.new(["chase_amazon", ".csv"])
    bad_date_csv.write(<<~CSV)
      Transaction Date,Description,Amount
      not_a_date,Invalid Date Entry,25.00
    CSV
    bad_date_csv.rewind

    assert_raises(Date::Error) do
      NormalizeCsvs.normalize_csvs([bad_date_csv.path], FORMATS)
    end

    bad_date_csv.close!
  end

  def test_ignores_extra_columns
    extended_csv = Tempfile.new(["chase_amazon", ".csv"])
    extended_csv.write(<<~CSV)
      Transaction Date,Description,Amount,Memo,Type
      07/10/2025,Coffee,-4.50,Starbucks,Food
    CSV
    extended_csv.rewind

    rows = NormalizeCsvs.normalize_csvs([extended_csv.path], FORMATS)
    assert_equal 1, rows.size
    assert_equal(4.50, rows.first["Amount"])
    assert_equal "Coffee", rows.first["Description"]
    extended_csv.close!
  end

  def test_strips_whitespace_in_fields
    messy_csv = Tempfile.new(["chase_amazon", ".csv"])
    messy_csv.write(<<~CSV)
      Transaction Date,Description,Amount
      07/11/2025,  Groceries  , -25.00
    CSV
    messy_csv.rewind

    row = NormalizeCsvs.normalize_csvs([messy_csv.path], FORMATS).first
    assert_equal "Groceries", row["Description"]
    messy_csv.close!
  end

  def test_handles_parentheses_as_negative
    formatted_csv = Tempfile.new(["citibank", ".csv"])
    formatted_csv.write(<<~CSV)
      Date,Description,Debit,Credit
      7/12/2025,Negative With Parentheses,"(123.45)",
    CSV
    formatted_csv.rewind

    rows = NormalizeCsvs.normalize_csvs([formatted_csv.path], FORMATS)
    assert_equal(-123.45, rows[0]["Amount"])
    formatted_csv.close!
  end

  def test_type_defaults_to_expense
    row = CSV::Row.new(
      ["Transaction Date", "Description", "Amount"],
      ["07/01/2025", "Regular Purchase", "100.00"]
    )
    format = FORMATS["chase_amazon"]
    result = NormalizeCsvs.normalize_row(row, format, "chase_amazon")

    assert_equal "Expense", result["Type"]
  end

  def test_type_switches_to_income_for_cashback
    row = CSV::Row.new(
      ["Transaction Date", "Description", "Amount"],
      ["07/02/2025", "Statement Credit - Thank You", "5.00"]
    )
    format = FORMATS["chase_amazon"]
    result = NormalizeCsvs.normalize_row(row, format, "chase_amazon")

    assert_equal "Income", result["Type"]
    assert_equal "5.0", result["Amount"].to_s
  end

  def test_type_switches_to_income_for_statement_credit
    row = CSV::Row.new(
      ["Transaction Date", "Description", "Amount"],
      ["07/03/2025", "Reward Statement Credit", "10.00"]
    )
    format = FORMATS["chase_amazon"]
    result = NormalizeCsvs.normalize_row(row, format, "chase_amazon")

    assert_equal "Income", result["Type"]
  end

  def test_type_respects_income_source_type
    income_format = {
      type: :income,
      date: "Date",
      description: "Description",
      debit: "Debit",
      credit: "Credit"
    }

    row = CSV::Row.new(
      ["Date", "Description", "Credit", "Debit"],
      ["07/04/2025", "Interest Payment", "0.00", "50.00"]
    )
    result = NormalizeCsvs.normalize_row(row, income_format, "my_bank")
    assert_equal "Income", result["Type"]
  end

  def test_refund_is_still_expense_not_income
    row = CSV::Row.new(
      ["Transaction Date", "Description", "Amount"],
      ["07/05/2025", "Return of Item", "20.00"]
    )
    format = FORMATS["chase_amazon"]
    result = NormalizeCsvs.normalize_row(row, format, "chase_amazon")

    assert_equal "Expense", result["Type"]
  end

  def test_output_is_sorted_by_date
    mixed_csv = Tempfile.new(["capital_one", ".csv"])
    mixed_csv.write(<<~CSV)
      Transaction Date,Description,Debit,Credit
      2025-07-10,Late Transaction,50.00,
      2025-07-01,Early Transaction,10.00,
      2025-07-05,Middle Transaction,20.00,
    CSV
    mixed_csv.rewind

    rows = NormalizeCsvs.normalize_csvs([mixed_csv.path], FORMATS)
    sorted_rows = rows.sort_by { |row| Date.parse(row["Date"]) }

    sorted_dates = sorted_rows.map { |row| row["Date"] }
    expected_dates = ["2025-07-01", "2025-07-05", "2025-07-10"]

    assert_equal expected_dates, sorted_dates

    mixed_csv.close!
  end

  def test_skips_payment_row
    payment_csv = Tempfile.new(["chase_amazon", ".csv"])
    payment_csv.write(<<~CSV)
      Transaction Date,Description,Amount
      07/06/2025,Payment Thank You,100.00
      07/07/2025,Regular Purchase,-50.00
    CSV
    payment_csv.rewind

    rows = NormalizeCsvs.normalize_csvs([payment_csv.path], FORMATS)
    assert_equal 1, rows.size
    assert_equal "Regular Purchase", rows.first["Description"]
    assert_equal 50.00, rows.first["Amount"]

    payment_csv.close!
  end

  def test_known_category_matches
    assert_equal "Groceries", NormalizeCsvs.categorize_transaction("Safeway")
    assert_equal "Going out", NormalizeCsvs.categorize_transaction("Starbucks")
    assert_equal "Utilities", NormalizeCsvs.categorize_transaction("Xcel")
  end

  def test_uncategorized_fallback
    assert_equal "Uncategorized", NormalizeCsvs.categorize_transaction("Some Unknown Vendor XYZ")
  end

  def test_partial_category_case_insensitive_matches
    assert_equal "Groceries", NormalizeCsvs.categorize_transaction("Trader Joe's Market")
    assert_equal "Car", NormalizeCsvs.categorize_transaction("Progressive Insurance")
    assert_equal "Entertainment", NormalizeCsvs.categorize_transaction("Denver Film Society")
  end

  def test_expense_transaction_is_categorized
    row = CSV::Row.new(
      ["Transaction Date", "Description", "Amount"],
      ["07/15/2025", "Amazon Purchase", "49.99"]
    )
    format = FORMATS["chase_amazon"] # or any other format with same column names
    result = NormalizeCsvs.normalize_row(row, format, "chase_amazon")
    assert_equal "Expense", result["Type"]
    assert_equal "Amazon", result["Category"]
  end

  def test_income_transaction_is_categorized
    row = CSV::Row.new(
      ["Transaction Date", "Description", "Amount"],
      ["07/15/2025", "Thankyou Points", "5.00"]
    )

    format = FORMATS["chase_amazon"] # or any other format with same column names

    result = NormalizeCsvs.normalize_row(row, format, "chase_amazon")

    assert_equal "Income", result["Type"]
    assert_equal "Statement Credit", result["Category"]
  end

  def test_type_switches_to_expense_when_income_source_has_billpay_keyword
    income_format = {
      type: :income,
      date: "Date",
      description: "Description",
      debit: "Debit",
      credit: "Credit"
    }

    row = CSV::Row.new(
      ["Date", "Description", "Credit", "Debit"],
      ["07/10/2025", "Type: BillPay - Comcast", "0.00", "150.00"]
    )

    result = NormalizeCsvs.normalize_row(row, income_format, "elevations")

    assert_equal "Expense", result["Type"]
  end

  def test_parse_amount
    assert_equal 0.0, NormalizeCsvs.parse_amount(nil)
    assert_equal 0.0, NormalizeCsvs.parse_amount("")
    assert_equal 1234.56, NormalizeCsvs.parse_amount("$1,234.56")
    assert_equal(-1234.56, NormalizeCsvs.parse_amount("-$1,234.56"))
    assert_equal(-1234.56, NormalizeCsvs.parse_amount("($1,234.56)"))
    assert_equal 500.0, NormalizeCsvs.parse_amount("500")
    assert_equal(-500.0, NormalizeCsvs.parse_amount("(500)"))
    assert_equal(-500.0, NormalizeCsvs.parse_amount("($500)"))
  end

  def test_bank_account_behavior_with_reverse
    bank_csv = Tempfile.new(["bank_account", ".csv"])
    bank_csv.write(<<~CSV)
      Date,Description,Debit,Credit
      7/01/2025,Comcast,-25.00,
      7/02/2025,Check #,-1000.00,
      7/03/2025,Refund,$15.00,
    CSV
    bank_csv.rewind

    formats = {
      "bank_account" => {
        date: "Date",
        description: "Description",
        debit: "Debit",
        credit: "Credit",
        bank_account: true,
        type: :income
      }
    }

    rows = NormalizeCsvs.normalize_csvs([bank_csv.path], formats)

    assert_equal "2025-07-01", rows[0]["Date"]
    assert_equal "Comcast", rows[0]["Description"]
    assert_equal(25.00, rows[0]["Amount"])

    assert_equal "2025-07-02", rows[1]["Date"]
    assert_equal "Check #", rows[1]["Description"]
    assert_equal 1000.00, rows[1]["Amount"]

    assert_equal "2025-07-03", rows[2]["Date"]
    assert_equal "Refund", rows[2]["Description"]
    assert_equal 15.00, rows[2]["Amount"] # originally ($15.00), reversed to positive

    bank_csv.close!
  end

end

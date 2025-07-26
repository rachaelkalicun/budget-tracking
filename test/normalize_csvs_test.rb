require "minitest/autorun"
require "tempfile"
require "csv"
require "pry"
require_relative "../lib/normalize_csvs"

class NormalizeCsvsTest < Minitest::Test
  FORMATS = {
    "chase_amazon" => { date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount" },
    "chase_ihg" => { date: "Transaction Date", description: "Description", debit: "Amount", credit: "Amount" },
    "citibank" => { date: "Date", description: "Description", debit: "Debit", credit: "Credit" },
    "capital_one" => { date: "Transaction Date", description: "Description",  debit: "Debit", credit: "Credit" },
  }

  def setup
    @chase_amazon_csv = Tempfile.new(["chase_amazon", ".csv"])
    @chase_amazon_csv.write(<<~CSV)
      Transaction Date,Description,Amount
      07/01/2025,Amazon Refund,-15.00
      07/02/2025,Amazon Purchase,49.99
    CSV
    @chase_amazon_csv.rewind

    @chase_ihg_csv = Tempfile.new(["chase_ihg", ".csv"])
    @chase_ihg_csv.write(<<~CSV)
      Transaction Date,Description,Amount
      07/03/2025,Hotel Credit,-75.00
      07/04/2025,Hotel Charge,200.00
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
      assert_equal ["Date", "Description", "Amount", "Source"], row.keys
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
end

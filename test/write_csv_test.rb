require "minitest/autorun"
require "csv"
require "tempfile"
require_relative "../lib/normalize_csvs"

class WriteCsvTest < Minitest::Test
  def setup
    @tempfile = Tempfile.new(["output", ".csv"])
  end

  def teardown
    @tempfile.close!
  end

  def test_write_csv_outputs_rows_in_correct_order_without_headers
    rows = [
      { "Date" => "2025-07-01", "Description" => "Test 1", "Amount" => -15.0, "Source" => "Chase" },
      { "Date" => "2025-07-02", "Description" => "Test 2", "Amount" => 49.99, "Source" => "Chase" }
    ]

    NormalizeCsvs.write_csv(@tempfile.path, rows, ["Date", "Description", "Amount", "Source"])

    csv = CSV.read(@tempfile.path)

    assert_equal ["2025-07-01", "Test 1", "-15.0", "Chase"], csv[0]
    assert_equal ["2025-07-02", "Test 2", "49.99", "Chase"], csv[1]
    assert_equal 2, csv.length
  end
end

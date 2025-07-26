require "minitest/autorun"
require "csv"
require "tempfile"
require_relative "../lib/normalize_csvs"

class WriteCsvTest < Minitest::Test
  def test_write_csv_outputs_rows_without_headers_and_with_source
    rows = [
      { "Date" => "2025-07-01", "Description" => "Test 1", "Amount" => -15.0, "Source" => "Chase" },
      { "Date" => "2025-07-02", "Description" => "Test 2", "Amount" => 49.99, "Source" => "Chase" }
    ]

    tempfile = Tempfile.new(["output", ".csv"])

    NormalizeCsvs.write_csv(tempfile.path, rows, ["Date", "Description", "Amount", "Source"])

    contents = File.read(tempfile.path)
    lines = contents.strip.split("\n")

    assert_equal "2025-07-01,Test 1,-15.0,Chase", lines[0]
    assert_equal "2025-07-02,Test 2,49.99,Chase", lines[1]
    assert_equal 2, lines.length

    tempfile.close!
  end
end

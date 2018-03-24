require 'test_helper'

class FlowControlTest < Minitest::Test
  def test_aborted_import
    importer = AbortedImportImporter.new('test/csv/aborted_import.csv')
    importer.result = {}
    importer.import!

    assert importer.aborted?
    assert_equal 'Import was aborted', importer.abort_message
    assert_equal 1, importer.imported_rows.size
    assert_equal 'Before importing rows', importer.result[:before]
    assert_nil importer.result[:after]
  end
end

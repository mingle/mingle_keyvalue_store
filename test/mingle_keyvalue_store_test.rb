require 'test/unit'
require 'mingle_keyvalue_store'
require 'json'

TMP_DIR = File.join(File.dirname(__FILE__), 'tmp')

class MingleKeyvalueStoreTest < Test::Unit::TestCase
  def setup
    @table_name = 'dynamo-test'
    FileUtils.mkdir(TMP_DIR) unless File.directory?(TMP_DIR)
    @dynamo = Mingle::KeyvalueStore::DynamodbBased.new(@table_name, :testkey, :testvalue)
    @pstore = Mingle::KeyvalueStore::PStoreBased.new(TMP_DIR, @table_name, :testkey, :testvalue)
  end

  def test_store_non_string_value_in_pstore_should_raise_error
    assert_raise(ArgumentError) do
      @pstore['foo'] = true
    end
    assert_raise(ArgumentError) do
      @dynamo['foo'] = true
    end
  end

  def test_handle_nil_value
    assert_raise(ArgumentError) do
      @pstore['foo'] = nil
    end
    assert_raise(ArgumentError) do
      @dynamo['foo'] = nil
    end
  end

  def test_names_returned_should_be_equal
    input = { :key => :value }.to_json
    @dynamo['foo'] = input
    @pstore['foo'] = input

    assert_equal ['foo'], @dynamo.names
    assert_equal ['foo'], @pstore.names
  end

  def test_value_for_key_should_be_equal
    input = {:somekey => {:foo => :bar} }.to_json
    @dynamo['foo'] = input
    @pstore['foo'] = input

    assert_equal input, @dynamo['foo']
    assert_equal input, @pstore['foo']
  end

  def test_delete_should_behave_similarly
    input = { :some => :data }.to_json
    @dynamo['key'] = input
    @pstore['key'] = input

    pstore_return = @pstore.delete('key')
    dynamo_return = @dynamo.delete('key')

    assert_equal dynamo_return, pstore_return

    assert_nil @dynamo['key']
    assert_nil @pstore['key']
  end

  def test_clear_should_behave_similarly
    input = { :some => :data }.to_json
    @dynamo['key1'] = input
    @pstore['key1'] = input
    @dynamo['key2'] = input
    @pstore['key2'] = input

    pstore_return = @pstore.clear
    dynamo_return = @dynamo.clear

    assert_equal [], @dynamo.names
    assert_equal [], @pstore.names

    assert_equal dynamo_return, pstore_return
  end


  def test_adding_data_after_clear_should_behave_similarly
    input = { :some => :data }.to_json
    @dynamo['key1'] = input
    @pstore['key1'] = input

    pstore_return = @pstore.clear
    dynamo_return = @dynamo.clear

    assert_equal [], @dynamo.names
    assert_equal [], @pstore.names

    assert_equal dynamo_return, pstore_return

    new_input = { :some => :data }.to_json
    @dynamo['key2'] = new_input
    @pstore['key2'] = new_input

    assert_equal @dynamo['key2'], @pstore['key2']
    assert_equal @dynamo.names, @pstore.names
  end

  def test_all_items_should_behave_similarly
    input = { :some => :data }.to_json
    @dynamo['key1'] = input
    @pstore['key1'] = input
    @dynamo['key2'] = input
    @pstore['key2'] = input
    @dynamo['key3'] = input
    @pstore['key3'] = input

    pstore_return = @pstore.all_items
    dynamo_return = @dynamo.all_items

    assert_equal dynamo_return.length, pstore_return.length
    assert_equal %w(key1 key2 key3), pstore_return.map{|h| h['testkey']}.sort
    assert_equal %w(key1 key2 key3), dynamo_return.map{|h| h['testkey']}.sort
  end

  def test_dynamo_store_fetch_ensures_handling_batched_results_from_table_scans
    @dynamo['key1'] = 'val1'
    @dynamo['key2'] = 'val2'
    @dynamo['key3'] = 'val3'
    @dynamo['key4'] = 'val4'

    # Setting limit will make scan fetch in batches of 1, using this to simulate behavior when table data is too large
    # to return in one scan call
    items = @dynamo.send(:all_items_from_table, {limit: 1})

    assert_equal %w(key1 key2 key3 key4), items.map{|h| h['testkey']}.sort
    assert_equal %w(val1 val2 val3 val4), items.map{|h| h['testvalue']}.sort
  end

  def teardown
    delete_dynamo_entries
    delete_pstore
  end

  private
  def delete_pstore
    FileUtils.rm_rf TMP_DIR
  end

  def delete_dynamo_entries
    table = Aws::DynamoDB::Table.new(name: @table_name)
    table.scan.items.each do |item|
      table.delete_item(key: {testkey: item['testkey']})
    end
  end
end

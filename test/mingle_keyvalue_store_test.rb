require "test/unit"

require "mingle_keyvalue_store"

TMP_DIR = File.join(File.dirname(__FILE__), "tmp")

class MingleKeyvalueStoreTest < Test::Unit::TestCase
  def setup
    @table_name = "dynamo-test"

    @dynamo = Mingle::KeyvalueStore::DynamodbBased.new(@table_name, :testkey, :testvalue)
    @pstore = Mingle::KeyvalueStore::PStoreBased.new(TMP_DIR, @table_name, :testkey, :testvalue)
  end

  def test_names_returned_should_be_equal
    input = { :key => :value }
    @dynamo["foo"] = input
    @pstore["foo"] = input

    assert_equal @dynamo.names, @pstore.names
  end

  def test_value_for_key_should_be_equal
    input = {:somekey => {:foo => :bar} }
    @dynamo["foo"] = input
    @pstore["foo"] = input

    assert_equal @dynamo["foo"], @pstore["foo"]
  end

  def test_delete_should_behave_simlarly
    input = { :some => :data }
    @dynamo["key"] = input
    @pstore["key"] = input

    pstore_return = @pstore.delete("key")
    dynamo_return = @dynamo.delete("key")

    assert_equal dynamo_return, pstore_return
    assert_equal @dynamo["key"], @pstore["key"]
  end

  def test_clear_should_behave_simlarly
    input = { :some => :data }
    @dynamo["key1"] = input
    @pstore["key1"] = input
    @dynamo["key2"] = input
    @pstore["key2"] = input

    pstore_return = @pstore.clear
    dynamo_return = @dynamo.clear

    assert_equal [], @dynamo.names
    assert_equal [], @pstore.names

    assert_equal dynamo_return, pstore_return
  end

  def test_all_items_should_behave_similarly
    input = { :some => :data }
    @dynamo["key1"] = input
    @pstore["key1"] = input
    @dynamo["key2"] = input
    @pstore["key2"] = input
    @dynamo["key3"] = input
    @pstore["key3"] = input

    pstore_return = @pstore.all_items
    dynamo_return = @dynamo.all_items

    assert_equal dynamo_return.length, pstore_return.length
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
    table = AWS::DynamoDB.new.tables[@table_name]
    table.hash_key = [:testkey, :string]
    table.items.each(&:delete)
  end

  def create_table
    dynamo_db = AWS::DynamoDB.new
    table = dynamo_db.tables.create(
                                    @table_name, 10, 5,
                                    :hash_key => { :testkey => :string }
                                    )
    sleep 1 while table.status == :creating
  end
end

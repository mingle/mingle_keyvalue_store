require "test/unit"

require "mingle_keyvalue_store"

TMP_DIR = File.join(File.dirname(__FILE__), "tmp")

def get_env(key_name)
  var_name = key_name.to_s.upcase
  ENV[var_name] || raise("missing #{var_name} environment variable!")
end

AWS.config(
  :access_key_id => get_env(:aws_access_key_id),
  :secret_access_key => get_env(:aws_secret_access_key),
  :region => get_env(:aws_region),
  :dynamo_db => {:api_version => "2012-08-10"}
)


class MingleKeyvalueStoreTest < Test::Unit::TestCase
  def setup
    @table_name = "dynamo-test"
    create_table

    @dynamo = Mingle::KeyvalueStore::DynamodbBased.new(@table_name, :testkey, :testvalue)
    @pstore = Mingle::KeyvalueStore::PStoreBased.new(TMP_DIR, @table_name)
  end

  def test_names_returned_should_be_equal
    input = {:foo => 1, :bar => 2}
    @dynamo["foo"] = input
    @pstore["foo"] = input

    assert_equal @dynamo.names, @pstore.names
  end

  def teardown
    table = AWS::DynamoDB.new.tables[@table_name]
    table.hash_key = [:testkey, :string]
    table.items.each(&:delete)
  end

  private
  def create_table
    dynamo_db = AWS::DynamoDB.new
    table = dynamo_db.tables.create(
                                    @table_name, 10, 5,
                                    :hash_key => { :testkey => :string }
                                    )
    sleep 1 while table.status == :creating
  end
end

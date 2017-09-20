require 'rake/testtask'
require 'rubygems'
require 'aws-sdk-dynamodb'

task :default => :test

TEST_DYNAMO_TABLE = 'dynamo-test'

def get_env(key_name)
  var_name = key_name.to_s.upcase
  ENV[var_name] || raise("missing #{var_name} environment variable!")
end

def delete_dynamo_table(client)
  log "Deleting dynamo db table: '#{TEST_DYNAMO_TABLE}'"
  client.delete_table(table_name: TEST_DYNAMO_TABLE)
  Aws::DynamoDB::Waiters::TableNotExists.new(client: client, delay: 1).wait(table_name: TEST_DYNAMO_TABLE)
rescue Aws::DynamoDB::Errors::ResourceNotFoundException
  log "Table does not exist: '#{TEST_DYNAMO_TABLE}'"
end

def create_dynamo_table(client)
  log "Creating dynamo db table '#{TEST_DYNAMO_TABLE}'"
  client.create_table(table_name: TEST_DYNAMO_TABLE,
                      attribute_definitions: [
                          {
                              attribute_name: 'testkey',
                              attribute_type: 'S',
                          },
                      ],
                      key_schema: [
                          {
                              attribute_name: 'testkey',
                              key_type: 'HASH',
                          },
                      ],
                      provisioned_throughput: {
                          read_capacity_units: 10,
                          write_capacity_units: 5,
                      }
  )
  Aws::DynamoDB::Waiters::TableExists.new(client: client, delay: 1).wait(table_name: TEST_DYNAMO_TABLE)
end

Rake::TestTask.new(:test_internal) do |t|
  t.libs = ['lib']
  t.warning = true
  t.verbose = true
  t.test_files = FileList['test/*_test.rb']
end

task :aws_config do
  Aws.config.update(
      region: get_env(:aws_region),
      credentials: Aws::Credentials.new(get_env(:aws_access_key_id), get_env(:aws_secret_access_key))
  )
end

desc 'setup dynamo db table'
task :setup_dynamo => [:aws_config] do
  client = Aws::DynamoDB::Client.new
  delete_dynamo_table(client)
  create_dynamo_table(client)
end

def log(str)
  puts "[DEBUG] #{str}"
end

task :test => [:setup_dynamo, :test_internal]

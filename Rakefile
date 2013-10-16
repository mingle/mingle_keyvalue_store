require 'rake/testtask'
require "rubygems"
require "aws"

task :default => :test

TEST_DYNAMO_TABLE = "dynamo-test"

def get_env(key_name)
  var_name = key_name.to_s.upcase
  ENV[var_name] || raise("missing #{var_name} environment variable!")
end

Rake::TestTask.new(:test_internal) do |t|
  t.libs = ["lib"]
  t.warning = true
  t.verbose = true
  t.test_files = FileList['test/*_test.rb']
end

task :aws_config do
  AWS.config(
             :access_key_id => get_env(:aws_access_key_id),
             :secret_access_key => get_env(:aws_secret_access_key),
             :region => get_env(:aws_region),
             :dynamo_db => {:api_version => "2012-08-10"}
             )
end

desc "setup dynamo db table"
task :setup_dynamo => [:aws_config] do
  puts "[DEBUG] Creating dynamo db table '#{TEST_DYNAMO_TABLE}'"
  dynamo_db = AWS::DynamoDB.new
  table = dynamo_db.tables.create(
                                  TEST_DYNAMO_TABLE, 10, 5,
                                  :hash_key => { :testkey => :string }
                                  )
  sleep 1 while table.status == :creating
end

task :teardown_dynamo => [:aws_config] do
  puts "[DEBUG] Deleting dynamo db table '#{TEST_DYNAMO_TABLE}'"
  dynamo_db = AWS::DynamoDB.new
  table = dynamo_db.tables[TEST_DYNAMO_TABLE]
  table.delete
  sleep 1 while table.exists?
end

task :test => [:setup_dynamo, :test_internal, :teardown_dynamo]

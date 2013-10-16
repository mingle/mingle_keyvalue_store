require "rubygems"
require "aws"
require "pstore"
require "fileutils"
require "tempfile"

module Mingle
  module KeyvalueStore
    class PStoreBased
      def initialize(path, namespace)
        @namespace = namespace
        @store_file = store_file(path)
        @pstore = PStore.new(@store_file)
      end

      def [](store_key)
        @pstore.transaction { @pstore[store_key] }
      end

      def []=(store_key, value)
        @pstore.transaction do
          @pstore["all_names"] ||= []
          @pstore["all_names"] = (@pstore["all_names"] + [store_key]).uniq
          @pstore[store_key] = JSON.parse(value.to_json)
        end
      end

      def delete(store_key)
        @pstore.transaction do
          @pstore["all_names"].delete_if {|name| name == store_key}
          @pstore.delete(store_key)
        end
        nil
      end

      def clear
        FileUtils.rm_f(@store_file)
        @pstore = PStore.new(@store_file)
        nil
      end

      def names
        @pstore.transaction { @pstore["all_names"] || [] }
      end

      def all_items
        @pstore.transaction do
          return [] unless @pstore["all_names"]
          @pstore["all_names"].map do |name|
            {
              "key" => name,
              "value" => @pstore[name].to_json
            }
          end
        end

      end

      private

      def store_file(path)
        FileUtils.mkdir_p(path)

        file = Tempfile.new("#{@namespace}_multitenancy_configs.pstore", path).path
        FileUtils.mkdir_p(File.dirname(file))
        file
      end
    end

    class DynamodbBased
      def initialize(table_name, key_column=:tenant, value_column=:config)
        @key_column = key_column
        @value_column = value_column
        @table_name = table_name
      end

      def [](store_key)
        if attribute = table_items[store_key].attributes[@value_column]
          JSON.parse(attribute)
        end
      end

      def []=(store_key, value)
        table_items.create(@key_column => store_key, @value_column => value.to_json)
      end

      def clear
        table_items.each(&:delete)
      end

      def names
        table_items.map(&:hash_value)
      end

      def all_items
        table_items.map { |item| item.attributes.to_hash }
      end

      def delete(key)
        table_items.each do |item|
          if key == item.hash_value
            item.delete
            return
          end
        end
      end

      private

      def table_items
        table = AWS::DynamoDB.new.tables[@table_name]
        table.hash_key = [@key_column, :string]
        table.items
      end

    end
  end
end

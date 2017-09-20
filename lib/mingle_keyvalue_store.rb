require 'aws-sdk-dynamodb'
require 'pstore'
require 'fileutils'
require 'tempfile'
require 'monitor'

module Mingle
  module KeyvalueStore
    class PStoreBased < Monitor
      def initialize(path, namespace, key_column, value_column)
        @namespace = namespace
        @store_file = store_file(path)
        @key_column = key_column
        @value_column = value_column
        @pstore = PStore.new(@store_file)
        super()
      end

      def [](store_key)
        synchronize do
          @pstore.transaction { @pstore[store_key] }
        end
      end

      def []=(store_key, value)
        raise ArgumentError, 'Value must be String' unless value.is_a?(String)
        synchronize do
          @pstore.transaction do
            @pstore['all_names'] ||= []
            @pstore['all_names'] = (@pstore['all_names'] + [store_key]).uniq
            @pstore[store_key] = value
          end
        end
      end

      def delete(store_key)
        synchronize do
          @pstore.transaction do
            @pstore['all_names'].delete_if {|name| name == store_key}
            @pstore.delete(store_key)
          end
        end
        nil
      end

      def clear
        FileUtils.rm_f @store_file
        @pstore = PStore.new(@store_file)
        nil
      end

      def names
        synchronize do
          @pstore.transaction { @pstore['all_names'] || [] }
        end
      end

      def all_items
        synchronize do
          @pstore.transaction do
            return [] unless @pstore['all_names']
            @pstore['all_names'].map do |name|
              {
                @key_column.to_s => name,
                @value_column.to_s => @pstore[name]
              }
            end
          end
        end

      end

      private

      def store_file(path)
        File.join(path, "#{@namespace}_keystore.pstore")
      end
    end

    class DynamodbBased
      def initialize(table_name, key_column, value_column)
        @key_column = key_column.to_s
        @value_column = value_column.to_s
        @table_name = table_name
        @table = Aws::DynamoDB::Resource.new.table(table_name)
      end

      def [](store_key)
        if item = @table.get_item(key: {@key_column => store_key}).item
          item[@value_column]
        end
      end

      def []=(store_key, value)
        raise ArgumentError, 'Value must be String' unless value.is_a?(String)
        @table.put_item(item: {@key_column => store_key, @value_column => value})
      end

      def clear
        all_items_from_table.each do |item|
          @table.delete_item(key: {@key_column => item['testkey']})
        end
        nil
      end

      def names
        all_items_from_table(attributes_to_get: [@key_column]).map{|hash| hash[@key_column]}
      end

      def all_items
        all_items_from_table
      end

      def delete(key)
        @table.delete_item(key: {@key_column => key})
        nil
      end

      private
      def all_items_from_table(conditions={})
        items = []
        scan_output = @table.scan(conditions)
        return items unless scan_output.items
        items += scan_output.items
        # when the table data is too large scan will return in batches
        while scan_output.last_evaluated_key
          scan_output = @table.scan(conditions.merge(exclusive_start_key: scan_output.last_evaluated_key))
          items += scan_output.items
        end
        items
      end
    end
  end
end

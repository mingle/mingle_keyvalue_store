require "rubygems"
require "aws"
require "pstore"
require "fileutils"
require "tempfile"
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
        raise ArgumentError, "Value must be String" unless value.is_a?(String)
        synchronize do
          @pstore.transaction do
            @pstore["all_names"] ||= []
            @pstore["all_names"] = (@pstore["all_names"] + [store_key]).uniq
            @pstore[store_key] = value
          end
        end
      end

      def delete(store_key)
        synchronize do
          @pstore.transaction do
            @pstore["all_names"].delete_if {|name| name == store_key}
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
          @pstore.transaction { @pstore["all_names"] || [] }
        end
      end

      def all_items
        synchronize do
          @pstore.transaction do
            return [] unless @pstore["all_names"]
            @pstore["all_names"].map do |name|
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
        @key_column = key_column
        @value_column = value_column.to_s
        @table_name = table_name
      end

      def [](store_key)
        if attribute = attributes(table_items[store_key])[@value_column]
          attribute
        end
      end

      def []=(store_key, value)
        table_items.create(@key_column => store_key, @value_column => value)
      end

      def clear
        table_items.each(&:delete)
      end

      def names
        table_items.map(&:hash_value)
      end

      def all_items
        table_items.map { |item| attributes(item) }
      end

      def delete(key)
        table_items.where(@key_column => key).first.delete
      end

      private
      def attributes(item)
        item.attributes.to_h(:consistent_read => true)
      end

      def table_items
        table = AWS::DynamoDB.new.tables[@table_name]
        table.hash_key = [@key_column, :string]
        table.items
      end

    end
  end
end

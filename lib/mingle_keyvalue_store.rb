require "rubygems"
require "aws"
require "pstore"
require "fileutils"
require "tempfile"

module Mingle
  module KeyvalueStore
    class CachedSource
      def initialize(source)
        @source = source
      end

      def [](cache_key)
        Cache.get(keyname(cache_key)) do
          @source[cache_key]
        end
      end

      def []=(cache_key, config)
        @source[cache_key] = config
        delete_cache(cache_key)
      end

      def delete(cache_key)
        @source.delete(cache_key)
        delete_cache(cache_key)
      end

      def clear
        @source.clear
        Cache.flush_all
      end

      def names
        Cache.get(all_names_key, 15.minutes) do
          @source.names
        end
      end

      def all_items
        @source.all_items
      end

      private

      def delete_cache(cache_key)
        Cache.delete(keyname(cache_key))
        Cache.delete(all_names_key)
      end

      def keyname(cache_key)
        CGI.escape("multitenancy:#{cache_key}_configs")
      end

      def all_names_key
        "multitenancy:all_cache_keys"
      end

      def all_items_key
        "multitenancy:all_items"
      end
    end

    class PStoreBased
      def initialize(path, namespace)
        @namespace = namespace
        @pstore = PStore.new(store_file(path))
      end

      def [](store_key)
        @pstore.transaction { @pstore[store_key] }
      end

      def []=(store_key, value)
        @pstore.transaction do
          @pstore["all_names"] ||= []
          @pstore["all_names"] = (@pstore["all_names"] + [store_key]).uniq
          @pstore[store_key] = value
        end
      end

      def delete(store_key)
        @pstore.transaction do
          @pstore["all_names"].delete_if {|name| name == store_key}
          @pstore.delete(store_key)
        end
      end

      def clear
        FileUtils.rm_f(store_file)
        @pstore = PStore.new(store_file)
      end

      def names
        @pstore.transaction { @pstore["all_names"] }
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
        table_items.where(:key => key).first.delete
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

[![Build Status](https://snap-ci.com/Xepi1GC1RH-xljlY0aGThFoqOtmpsgse_xt-leosres/build_image)](https://snap-ci.com/projects/ThoughtWorksStudios/mingle_keyvalue_store/build_history)


# Mingle Keyvalue Store

A key value store with a PStore and a DynamoDB endpoint - both with the same behavior. This is useful when you have to run tests in your application and does not want to hit DynamoDB in every test.

## Usage
```ruby
if Rails.env.test?
  keystore = Mingle::KeyvalueStore::PStoreBased.new("/tmp/foostore", table_name, :key, :value)
else
  keystore = Mingle::KeyvalueStore::DynamodbBased.new(table_name, :key, :value)
end  
```


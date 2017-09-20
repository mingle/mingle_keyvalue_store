Gem::Specification.new do |gem|
  gem.authors       = %w(Ian sdqali prateekbaheti)
  gem.email         = %w(reginaldthedog@gmail.com sadiqalikm@gmail.com prateektheone@gmail.com)
  gem.description   = 'A key value store implementation that uses DynamoDB or Pstore underneath.'
  gem.summary       = gem.description
  gem.homepage      = 'https://github.com/ThoughtWorksStudios/mingle_keyvalue_store'
  gem.license       = 'MIT'

  gem.add_runtime_dependency 'aws-sdk-dynamodb', '~> 1'

  gem.add_development_dependency 'rake'

  gem.files = ['README.md']
  gem.files += Dir['lib/**/*.rb']

  gem.name          = 'mingle_keyvalue_store'
  gem.require_paths = ['lib']
  gem.version       = '0.2.0'
end

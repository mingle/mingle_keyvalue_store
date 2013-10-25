Gem::Specification.new do |gem|
  gem.authors       = ["Ian", "sdqali"]
  gem.email         = ["reginaldthedog@gmail.com", "sadiqalikm@gmail.com"]
  gem.description   = "A key value store implentation that uses DynamoDB or Pstore underneath."
  gem.summary       = gem.description
  gem.homepage      = "https://github.com/ThoughtWorksStudios/mingle_keyvalue_store"
  gem.license       = 'MIT'

  gem.add_runtime_dependency 'aws-sdk', "1.11.3"

  gem.add_development_dependency 'rake'

  gem.files = ['README.md']
  gem.files += Dir['lib/**/*.rb']

  gem.name          = "mingle_keyvalue_store"
  gem.require_paths = ["lib"]
  gem.version       = '0.1.4'
end

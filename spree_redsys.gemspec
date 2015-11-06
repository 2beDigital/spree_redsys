# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_redsys'
  s.version     =  '2.4.0'
  s.summary     = 'Adds Sermepa TPV as a Payment Method to Spree store'
  s.description = 'Redsys is a spanish payment gateway. Servired Network'
  s.author    = 'Héctor Picazo'
  s.email     = 'hector@2bedigital.com'
  s.homepage  = 'http://www.2bedigital.com'
  s.required_ruby_version = '>= 1.9.3'

  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', '>= 2.4.0'
  s.add_development_dependency 'capybara', '2.4.4'
  s.add_development_dependency 'factory_girl', '~> 4.4'
  s.add_development_dependency 'ffaker'
  s.add_development_dependency 'rspec-rails', '~> 3.1.0'
  s.add_development_dependency 'sqlite3'
end

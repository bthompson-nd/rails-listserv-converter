source 'https://rubygems.org'

# Include Postgresql gem
 gem 'pg'

# Include sqlite3 gem
#gem 'sqlite3'

# Include immigrant to make foreing keys easier
gem 'immigrant'

# Include Sucker Punch for background jobs
gem 'sucker_punch', '~> 1.0'

# Include Parallel for parallel processing (for collect_lists task)
gem 'parallel'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.0'
# Use SCSS for stylesheets
gem 'sprockets-rails', '~> 2.0.0'
gem 'sass-rails' , '~> 4.0.5'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier'
# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails'
# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer',  platforms: :ruby

# Use jquery as the JavaScript library
#gem 'jquery-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0',          group: :doc

# Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
gem 'spring',        group: :development

gem 'foundation-rails', '~> 5.4.5.0'
gem 'nd_foundation'
gem 'googleauth'
gem 'google-api-client', '0.8.2', require: 'google/api_client'
gem 'json'
gem 'connection_pool'
gem 'net-ldap'
gem 'dotenv-rails'
gem 'nokogiri'
gem 'persistent_http'
gem 'mail'
gem 'signet-rails'
gem 'whenever', :require => false

gem 'jwt'
gem 'will_paginate'

#gem 'aquarium' #great for singletons!
gem 'activerecord-session_store' #not thread-safe
#gem 'dalli' #requires memcache server

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use unicorn as the app server
if RUBY_PLATFORM =~ /(win32|mswin|mingw)/
  gem "puma" #windows for concurrency
else
  gem 'unicorn' #linux
end



# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Use debugger
# gem 'debugger', group: [:development, :test]

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin]

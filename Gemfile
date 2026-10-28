source "https://rubygems.org"

gem "active_flag", "~> 2.0"
gem "acts_as_list", "~> 1.1"
gem "alma_api", "~> 2.0"
gem "bootsnap", require: false
gem "caxlsx_rails", "~> 0.7"
gem "commonmarker", "~> 2.0"
gem "github-markup", "~> 6.0", require: "github/markup"
gem "hexapdf", "~> 1.1"
gem "jbuilder"
# Delivers mails to files and shows them in the browser: development, and test
# systems that set mail.delivery_method: letter_opener_web (config/application.yml)
gem "letter_opener_web"
gem "mysql2"
gem "propshaft"
gem "puma", ">= 5.0"
gem "rails", "~> 8.1.3"
gem "rails-i18n", "~> 8.0"
gem "simple_form", "~> 5.1"
gem "slim"
gem "solid_queue"
gem "stimulus-rails"
gem "strip_attributes", "~> 2.0"
gem "turbo-rails"
gem "view_component", "~> 4.0"

gem "inline_svg", "~> 1.10" # Must be after propshaft

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug", platforms: [:mri, :windows], require: "debug/prelude"
  gem "dotenv"
  gem "rubocop-rails", require: false
  gem "rubocop-ubpb", github: "ubpb/rubocop-ubpb", require: false
end

group :development do
  gem "capistrano"
  gem "capistrano-bundler"
  gem "capistrano-passenger"
  gem "capistrano-rails"
  gem "capistrano-rvm"
  # gem "i18n-debug"
  gem "i18n-tasks"
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

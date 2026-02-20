source 'https://rubygems.org'

gem 'puppet', '7.8.0', :require => false
gem 'puppet-lint', '>= 2.4.2'
gem 'test-kitchen', '>= 3.3.2'
gem 'kitchen-inspec', '>= 2.6.1'
gem 'rubocop'

gem 'kitchen-verifier-serverspec'
# gem 'kitchen-docker', git: 'https://github.com/test-kitchen/kitchen-docker.git', branch: 'main'
gem 'kitchen-docker', git: 'https://github.com/test-kitchen/kitchen-docker.git', ref: '511e4ad'  # Last working commit before gemspec bug
# gem 'kitchen-docker'
# gem 'kitchen-docker', git: 'https://github.com/aerickson/kitchen-docker.git', branch: 'INTEGRATION'
# gem 'kitchen-docker', git: 'https://github.com/aerickson/kitchen-docker.git', ref: '9a1386c530c49a2784c051822177df3ac1a4550b'
# end kitchen-docker
gem 'kitchen-puppet'
gem 'kitchen-sync'
gem 'kitchen-vagrant'
gem 'kitchen-azurerm'
gem 'librarian-puppet'
gem 'puppetlabs_spec_helper'
gem 'rake'
gem 'serverspec'
gem 'r10k'
gem 'debouncer'
gem 'vault'
gem 'rspec_junit_formatter'
gem 'erb'

gem "puppet-strings", "~> 4.1", :group => :dev

# ruby 3.4 drops base64 support, add back
gem 'base64'
gem 'mutex_m'
gem 'bigdecimal'
gem 'csv'
# ruby 3.3+ requires explicit minitar for r10k/puppet_forge
gem 'minitar', '~> 0.9'

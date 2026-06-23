source 'https://rubygems.org'

gem 'puppet', '8.10.0', :require => false
gem 'puppet-lint', '>= 2.4.2'
gem 'test-kitchen', '>= 3.3.2'
gem 'kitchen-inspec', '>= 3.1.0'
gem 'rubocop'
gem 'train', '~> 3.16.1'
gem 'train-core', '= 3.16.1'
gem 'train-winrm', '~> 0.4.3'
gem 'net-ssh', '>= 7.3', '< 8'
gem 'chef-winrm', '~> 2.5.0'
gem 'chef-winrm-fs', '~> 1.4.2'
gem 'chef-winrm-elevated', '~> 1.2.5'

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
gem 'kitchen-azurerm', git: 'https://github.com/mozilla-platform-ops/kitchen-azurerm.git', branch: 'main'
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

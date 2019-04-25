require 'serverspec'

# avoid getting spammed with messages
# see https://medium.com/@Joachim8675309/testkitchen-with-chef-and-serverspec-2ac0cd938e5
set :backend, :exec

RSpec.configure do |c|

    c.formatter = 'JUnit'

end

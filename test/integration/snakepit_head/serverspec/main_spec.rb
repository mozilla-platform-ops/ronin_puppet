require_relative 'spec_helper'

#
# snakepit_head
#

describe 'users' do
  describe user('root') do
    it { should exist }
  end

  describe user('snakepit') do
    it { should exist }
    it { should have_uid 1777 }
    it { should belong_to_primary_group 'snakepit' }
    it { should have_home_directory '/home/snakepit' }
    it { should have_login_shell '/bin/bash' }
    # it { should belong_to_group '' }
  end
end

describe 'groups' do
  describe group('snakepit') do
    it { should have_gid 1777 }
  end
end

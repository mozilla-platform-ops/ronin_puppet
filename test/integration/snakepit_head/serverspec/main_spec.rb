require_relative 'spec_helper'

describe 'users' do
  describe user('root') do
    it { should exist }
  end

  describe user('snakepit') do
    it { should exist }
    it { should have_uid 1777 }
  end
end

require_relative 'spec_helper'

# snakepit_worker

describe 'users' do
  describe user('root') do
    it { should exist }
    it { should have_authorized_key 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC5UV+5spZsqSSZ+zGMwcShTgE4pJF2uihxCE4A0gVs7kJt+VW8TDkLyWIwLQfvUWK2dvjwfWYmh3EenRyYGS3Yo+5GWdAZZ+Wn1A/0w/oVK+YQOOEv6Ay58CUFtcESse0fLFKOPQvWLFRjys97M3xpjiGjg7p5MI5SBhduBwFPlGPDVLiBhlTpYP5dGordGpdXutgLGvzwIbZpYLhW/sjG+C/VgJ4mlDwDmyZG2gKKD3/aZHpNXBDZ2JDHJ1gEpfYv+Fgv8A1ryVYK4mgc+sAJfKcQH08fvjTkivQ2l/FVtcK/YYxw4I+olIt9W/C/bkllQrwMQZleACbFb6mB6g89 root@mlchead' }
  end

  describe user('snakepit') do
    it { should exist }
    it { should have_uid 1777 }
    it { should belong_to_primary_group 'snakepit' }
    it { should have_home_directory '/home/snakepit' }
    it { should have_login_shell '/bin/bash' }
  end
end

describe 'groups' do
  describe group('snakepit') do
    it { should have_gid 1777 }
  end
end

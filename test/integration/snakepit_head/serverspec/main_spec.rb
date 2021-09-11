require_relative 'spec_helper'

#
# snakepit_head
#

describe file('/root/.ssh/authorized_keys') do
  it { should exist }
  it { should be_mode 600 }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'root' }
  # contents checked below
end

describe 'users' do
  describe user('root') do
    it { should exist }
    # aje
    it { should have_authorized_key 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCVIzgS4A6o6HZ5QoQvYbRz2Ztwdu1saKSFHz2PfvDiLrhbNzrxekJ+KCYIo0KjmxQGbPFfWYmLQCm1ARdqtU2hBTcm/NQrKZDendLwiX1EGBHvrwy4bwdlm72Hp+O1czb8tyvwgJMfVjmwWMG0FTRHunrv8eFyp9AmSlnDP+BQkEii41f7UY8tdZGbYChLKjHz2px2lhKj1jRt879Vy4zLw9l6wjfJ40A88Cf1rfsblfKP7iS5umeGvtqtSDbOU1dbiH73IJci/GTQiptr/Scu7MBMq/clzD/WGC+cIdregaG7AhZLcr4kqpk2lrAWpfRK/LgHa7vYy8XvRHt+oTpF aerickson_gen_1' }
    # cknowles
    it { should have_authorized_key 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBl4ghCn/DuyfnpsijRseADneyZIMNV5GdWwrqcBxP7b cknowles_gen_2' }
    # evgeny
    it { should have_authorized_key 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDb6LUzoc8YPetUGjDAit0cVXYWVIzT4wigXd+yDdxA15380qvWJzit1mQI7zs713I/hj17PL2JeDMywN4BUWYixmZZ3O5aY1MZAyVD6DSVKfl7P4gTIPBABTI7z+g11bQTFpExzIbJLvbYTFTsYkz7QM0IfzYjHOFI18zYeU2wqg1E9Iluq1mlVI2rmFZ8k4fd2xuNk2agFAqHgdeQIYnLvvadQeuwKw0qp5KeRzA7ONc7fuRBFDv9aBZkZgRBy6AZGU8sspi5Km2ofnJmfD/N1LxzdNK0L/tMmZos0Ldp/SEq8qpa0l3HInlZO/iWH2eNUhwr2hnUNP8NKDqafQ0YYZ+Z4lZChpVzEGjmkpV9TqWJpYeL0fMm4wdm97zab+2Ze0LpriFxOr2rjDq8/kQJIWZGk+Hr+hySur5nWYJMK/9P0n9JPaCbgD2ZrSZeglp95HPxVnGzToBqwWNAfpMMrUYCxyo8hQsQuIPWb7TI4Hphl9R1pwqYo0JHvVaxadJgbNL6o09w1OZ52lz5Prb9s5r13O1kgNPY5Hf6B1bk8HQulTlCQUfFcchWmDIRrYNJP+qqcSfvMf1blw1/aWkeAmQIJDBpHBBie0Buwk7LkNmKyZn2qMgTIRDAkruI4LmGb35vAcNJMldaJsxfdY89jjOqfKtth6DXxR8OfiAbDw== Mozilla_key' }
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

# verify package present
describe package('nfs-kernel-server') do
  it { should be_installed }
end

# verify exports
describe file('/etc/exports') do
  it { should exist }
  it { should be_mode 644 }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'root' }
  it { should contain '/snakepit       192.168.0.0/16(rw,no_root_squash,no_subtree_check)' }
end


# nfs testing on docker doesn't work (modules arenn't loaded in host)
def proc_1_cgroup
  file('/proc/1/cgroup').content
end

def is_docker
  if proc_1_cgroup().include?('docker')
    return true
  else
    return false
  end
end

# verify serivce is exporting them
describe command('exportfs'), :if => !is_docker do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should contain "/snakepit     	192.168.0.0/16" }
end

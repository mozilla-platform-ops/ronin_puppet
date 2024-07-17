# lib/facter/cltbld_uid.rb
Facter.add('cltbld_uid') do
    setcode do
      begin
        require 'etc'
        Etc.getpwnam('cltbld').uid
      rescue ArgumentError
        nil
      end
    end
  end

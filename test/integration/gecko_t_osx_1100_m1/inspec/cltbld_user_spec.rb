# serverspec

# describe 'users' do
#   describe user('cltbld') do
#     it { should exist }
#     it { should belong_to_group '_developer' }
#     it { should belong_to_group 'com.apple.access_screensharing' }
#     it { should belong_to_group 'com.apple.access_ssh' }
#   end
# end


# inspec

describe 'users' do
  describe user('cltbld') do
    it { should exist }

    %w(cltbld _developer com.apple.access_screensharing com.apple.access_ssh).each do |group|
      its('groups') { should include group }
    end
  end
end

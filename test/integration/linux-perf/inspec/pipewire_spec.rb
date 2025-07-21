require_relative 'spec_helper'

if os.family == 'debian' && (os.release.start_with?('18.04') or  os.release.start_with?('22.04'))
  # see pactl_spec.rb
elsif os.family == 'debian' && os.release.start_with?('24.04')
    describe package('pipewire') do
        it { should be_installed }
    end
else
  # shouldn't be here
  # for other OS families or versions, show error
  describe command('false') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should_not match /NONO/ }
  end
end

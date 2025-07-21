require_relative 'spec_helper'

# template
#

if os.family == 'debian' && (os.release.start_with?('18.04') or os.release.start_with?('22.04'))
  # don't do anything here
  #
  # see linux_gui_spec.rb for details
elsif os.family == 'debian' && os.release.start_with?('24.04')
  # TODO: check things here
  # TODO: figure out a way to have x11 and wayland 2404 variants
else
  # shouldn't be here
  # for other OS families or versions, show error
  describe command('false') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should_not match /NONO/ }
  end
end

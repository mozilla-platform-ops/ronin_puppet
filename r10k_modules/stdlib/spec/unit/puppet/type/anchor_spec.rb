require_relative 'spec_helper'

anchor = Puppet::Type.type(:anchor).new(:name => 'ntp::begin')

describe anchor do
  it 'stringifies normally' do
    expect(anchor.to_s).to eq('Anchor[ntp::begin]')
  end
end

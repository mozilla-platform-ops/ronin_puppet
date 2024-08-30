require 'spec_helper'

describe 'roles_profiles::profiles::sudo' do
  let(:facts) do
    {
      operatingsystem: 'Darwin',
    }
  end

  it { is_expected.to compile.with_all_deps }

  it 'includes the sudo class' do
    is_expected.to contain_class('sudo')
  end
end

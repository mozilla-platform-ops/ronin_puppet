describe package('fontconfig'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe package('fonts-kacst'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe package('fonts-kacst-one'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe package('fonts-liberation'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe package('fonts-stix'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe package('fonts-unfonts-core'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe package('fonts-unfonts-extra'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe package('fonts-vlgothic'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

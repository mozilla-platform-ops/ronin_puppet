require_relative 'spec_helper'

describe software_property_command("$_.DisplayName -eq 'Mozilla Maintenance Service'", 'DisplayName') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^Mozilla Maintenance Service\s*$/) }
end

describe powershell_command("(Get-Service 'MozillaMaintenance' -ErrorAction Stop).Name") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^MozillaMaintenance\s*$/) }
end

%w[
  FA056CEBEFF3B1D0500A1FB37C2BD2F9CE4FB5D8
  EA66A61D6C382C8D1CA8C345EEB7D4DF4AFBEF18
  A13DC11A11F27619734BD4B73F2649FFDA3E6230
].each do |thumbprint|
  describe powershell_command("(Get-ChildItem Cert:\\LocalMachine\\Root | Where-Object { $_.Thumbprint -eq '#{thumbprint}' }).Issuer") do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^CN=Mozilla Fake CA\s*$/) }
  end
end

registry_checks = {
  "HKLM:\\SOFTWARE\\Mozilla\\MaintenanceService\\3932ecacee736d366d6436db0f55bce4\\0" => {
    'issuer' => 'DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1',
    'name' => 'Mozilla Corporation'
  },
  "HKLM:\\SOFTWARE\\Mozilla\\MaintenanceService\\3932ecacee736d366d6436db0f55bce4\\1" => {
    'issuer' => 'Mozilla Fake CA',
    'name' => 'Mozilla Fake SPC'
  },
  "HKLM:\\SOFTWARE\\Mozilla\\MaintenanceService\\3932ecacee736d366d6436db0f55bce4\\2" => {
    'issuer' => 'DigiCert SHA2 Assured ID Code Signing CA',
    'name' => 'Mozilla Corporation'
  }
}

registry_checks.each do |path, values|
  values.each do |key, expected|
    describe powershell_command("(Get-ItemProperty '#{path}' -ErrorAction Stop).#{key}") do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match(/^#{Regexp.escape(expected)}\s*$/) }
    end
  end
end

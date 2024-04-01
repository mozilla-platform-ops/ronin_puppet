require 'spec_helper_acceptance'

describe 'download_file' do
  context 'dowload_file should download dotnet 4' do
    it 'downloads dotnet 4' do
      pp = <<-PP
        download_file { "Download dotnet 4.0" :
          url                   => 'http://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe',
          destination_directory => 'c:\\temp'
        }
      PP

      apply_manifest(pp, catch_failures: true)
      expect(apply_manifest(pp, catch_failures: true).exit_code).to be_zero
    end

    describe file('C:\\dotNetFx40_Full_x86_x64.exe') do
      it { is_expected.to be_file }
    end
  end
end

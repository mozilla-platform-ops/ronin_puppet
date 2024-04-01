require 'spec_helper'

# This file is special, given what we're checking here is the output of our
# generated PowerShell script, we want to
# rubocop:disable Style/TrailingWhitespace
describe 'download_file', type: :define do
  describe 'when downloading a file without a proxy' do
    let(:title)  { 'Download DotNet 4.0' }
    let(:params) do 
      {
        url: 'http://myserver.com/test.exe',
        destination_directory: 'c:\temp'
      }
    end

    it do 
      is_expected.to contain_exec('download-test.exe').with(
        'command' => 'c:\\temp\\download-test.exe.ps1',
        'onlyif'  => "if(Test-Path -Path 'c:\\temp\\test.exe') { exit 1 } else { exit 0 }"
      )
    end
  end

  describe 'when downloading a file with a empty string proxy' do
    let(:title)  { 'Download DotNet 4.0' }
    let(:params) do 
      {
        url: 'http://myserver.com/test.exe',
        destination_directory: 'c:\temp',
        proxy_address: ''
      }
    end

    it do 
      is_expected.to contain_exec('download-test.exe').with(
        'command' => 'c:\\temp\\download-test.exe.ps1',
        'onlyif'  => "if(Test-Path -Path 'c:\\temp\\test.exe') { exit 1 } else { exit 0 }"
      )
    end
  end

  describe 'when downloading a file without a proxy we want to check that the erb gets evaluated correctly' do
    let(:title)  { 'Download DotNet 4.0' }
    let(:params) { { url: 'http://myserver.com/test.exe', destination_directory: 'c:\temp' } }

    ps1 = <<-PS1.gsub(%r{^ {6}}, '')
      $webclient = New-Object System.Net.WebClient
      $user = ''
      $password = ''
      $proxyAddress = ''
      $proxyUser = ''
      $proxyPassword = ''

      # This is potentially not secure if not using ssl
      if (($user -ne '') -and ($password -ne '')) {
        # Basic authentication encoding.
        $basic = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($user + ":" + $password));
        # Set Authorization HTTP header with Basic authentication information.
        $webclient.Headers["Authorization"] = "Basic $basic"
      }

      if ($proxyAddress -ne '') {
        if (!($proxyAddress.StartsWith('http://') -or $proxyAddress.StartsWith('https://'))) {
          $proxyAddress = 'http://' + $proxyAddress
        }

        $proxy = new-object System.Net.WebProxy
        $proxy.Address = $proxyAddress
        if (($proxyPassword -ne '') -and ($proxyUser -ne '')) {
        
          
          $password = ConvertTo-SecureString -string $proxyPassword
          
          
          $proxy.Credentials = New-Object System.Management.Automation.PSCredential($proxyUser, $password)
          $webclient.UseDefaultCredentials = $true
        }
        $webclient.proxy = $proxy
      }

      try {
        $webclient.DownloadFile('http://myserver.com/test.exe', 'c:\\temp\\test.exe')
      }
      catch [Exception] {
        write-host $_.Exception.GetType().FullName
        write-host $_.Exception.Message
        write-host $_.Exception.InnerException.Message
        throw $_.Exception
      }
    PS1

    it { is_expected.to contain_file('download-test.exe.ps1').with_content(ps1) }
  end

  describe 'when downloading a file using a proxy server without credentials' do
    let(:title)  { 'Download DotNet 4.0' }
    let(:params) do 
      {
        url: 'http://myserver.com/test.exe',
        destination_directory: 'c:\temp',
        proxy_address: 'test-proxy-01:8888'
      }
    end

    it do 
      is_expected.to contain_exec('download-test.exe').with(
        'command' => 'c:\\temp\\download-test.exe.ps1',
        'onlyif'  => "if(Test-Path -Path 'c:\\temp\\test.exe') { exit 1 } else { exit 0 }"
      )
    end
  end

  describe 'when downloading a file using a proxy server without credentials we want to check that the erb gets evaluated correctly' do
    let(:title) { 'Download DotNet 4.0' }
    let(:params) do 
      {
        url: 'http://myserver.com/test.exe',
        destination_directory: 'c:\temp',
        proxy_address: 'test-proxy-01:8888'
      }
    end

    ps1 = <<-PS1.gsub(%r{^ {6}}, '')
      $webclient = New-Object System.Net.WebClient
      $user = ''
      $password = ''
      $proxyAddress = 'test-proxy-01:8888'
      $proxyUser = ''
      $proxyPassword = ''

      # This is potentially not secure if not using ssl
      if (($user -ne '') -and ($password -ne '')) {
        # Basic authentication encoding.
        $basic = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($user + ":" + $password));
        # Set Authorization HTTP header with Basic authentication information.
        $webclient.Headers["Authorization"] = "Basic $basic"
      }

      if ($proxyAddress -ne '') {
        if (!($proxyAddress.StartsWith('http://') -or $proxyAddress.StartsWith('https://'))) {
          $proxyAddress = 'http://' + $proxyAddress
        }

        $proxy = new-object System.Net.WebProxy
        $proxy.Address = $proxyAddress
        if (($proxyPassword -ne '') -and ($proxyUser -ne '')) {
        
          
          $password = ConvertTo-SecureString -string $proxyPassword
          
          
          $proxy.Credentials = New-Object System.Management.Automation.PSCredential($proxyUser, $password)
          $webclient.UseDefaultCredentials = $true
        }
        $webclient.proxy = $proxy
      }

      try {
        $webclient.DownloadFile('http://myserver.com/test.exe', 'c:\\temp\\test.exe')
      }
      catch [Exception] {
        write-host $_.Exception.GetType().FullName
        write-host $_.Exception.Message
        write-host $_.Exception.InnerException.Message
        throw $_.Exception
      }
    PS1

    it { is_expected.to contain_file('download-test.exe.ps1').with_content(ps1) }
  end

  describe 'when downloading a file using a proxy server with credentials' do
    let(:title)  { 'Download DotNet 4.0' }
    let(:params) do 
      {
        url: 'http://myserver.com/test.exe',
        destination_directory: 'c:\temp',
        proxy_address: 'test-proxy-01:8888',
        proxy_user: 'test-user',
        proxy_password: 'test-secure'
      }
    end

    it do 
      is_expected.to contain_exec('download-test.exe').with(
        'command' => 'c:\\temp\\download-test.exe.ps1',
        'onlyif' => "if(Test-Path -Path 'c:\\temp\\test.exe') { exit 1 } else { exit 0 }"
      )
    end
  end

  describe 'when downloading a file using a proxy server with secure credentials we want to check that the erb gets evaluated correctly' do
    let(:title) { 'Download DotNet 4.0' }
    let(:params) do 
      {
        url: 'http://myserver.com/test.exe',
        destination_directory: 'c:\temp',
        proxy_address: 'test-proxy-01:8888',
        proxy_user: 'test-user',
        proxy_password: 'test-secure'
      }
    end

    ps1 = <<-PS1.gsub(%r{^ {6}}, '')
      $webclient = New-Object System.Net.WebClient
      $user = ''
      $password = ''
      $proxyAddress = 'test-proxy-01:8888'
      $proxyUser = 'test-user'
      $proxyPassword = 'test-secure'
      
      # This is potentially not secure if not using ssl
      if (($user -ne '') -and ($password -ne '')) {
        # Basic authentication encoding.
        $basic = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($user + ":" + $password));
        # Set Authorization HTTP header with Basic authentication information.
        $webclient.Headers["Authorization"] = "Basic $basic"
      }

      if ($proxyAddress -ne '') {
        if (!($proxyAddress.StartsWith('http://') -or $proxyAddress.StartsWith('https://'))) {
          $proxyAddress = 'http://' + $proxyAddress
        }

        $proxy = new-object System.Net.WebProxy
        $proxy.Address = $proxyAddress
        if (($proxyPassword -ne '') -and ($proxyUser -ne '')) {
        
          
          $password = ConvertTo-SecureString -string $proxyPassword
          
          
          $proxy.Credentials = New-Object System.Management.Automation.PSCredential($proxyUser, $password)
          $webclient.UseDefaultCredentials = $true
        }
        $webclient.proxy = $proxy
      }

      try {
        $webclient.DownloadFile('http://myserver.com/test.exe', 'c:\\temp\\test.exe')
      }
      catch [Exception] {
        write-host $_.Exception.GetType().FullName
        write-host $_.Exception.Message
        write-host $_.Exception.InnerException.Message
        throw $_.Exception
      }
    PS1

    it { is_expected.to contain_file('download-test.exe.ps1').with_content(ps1) }
  end

  describe 'when downloading a file using a proxy server with insecure credentials' do
    let(:title)  { 'Download DotNet 4.0' }
    let(:params) do 
      {
        url: 'http://myserver.com/test.exe',
        destination_directory: 'c:\temp',
        proxy_address: 'test-proxy-01:8888',
        proxy_user: 'test-user',
        proxy_password: 'test',
        is_password_secure: false
      }
    end

    it do 
      is_expected.to contain_exec('download-test.exe').with(
        'command' => 'c:\\temp\\download-test.exe.ps1',
        'onlyif' => "if(Test-Path -Path 'c:\\temp\\test.exe') { exit 1 } else { exit 0 }"
      )
    end
  end

  describe 'when downloading a file using a proxy server with insecure credentials we want to check that the erb gets evaluated correctly' do
    let(:title)  { 'Download DotNet 4.0' }
    let(:params) do 
      {
        url: 'http://myserver.com/test.exe',
        destination_directory: 'c:\temp',
        proxy_address: 'test-proxy-01:8888',
        proxy_user: 'test-user',
        proxy_password: 'test',
        is_password_secure: false
      }
    end

    ps1 = <<-PS1.gsub(%r{^ {6}}, '')
      $webclient = New-Object System.Net.WebClient
      $user = ''
      $password = ''
      $proxyAddress = 'test-proxy-01:8888'
      $proxyUser = 'test-user'
      $proxyPassword = 'test'

      # This is potentially not secure if not using ssl
      if (($user -ne '') -and ($password -ne '')) {
        # Basic authentication encoding.
        $basic = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($user + ":" + $password));
        # Set Authorization HTTP header with Basic authentication information.
        $webclient.Headers["Authorization"] = "Basic $basic"
      }

      if ($proxyAddress -ne '') {
        if (!($proxyAddress.StartsWith('http://') -or $proxyAddress.StartsWith('https://'))) {
          $proxyAddress = 'http://' + $proxyAddress
        }

        $proxy = new-object System.Net.WebProxy
        $proxy.Address = $proxyAddress
        if (($proxyPassword -ne '') -and ($proxyUser -ne '')) {
        
          
          $password = ConvertTo-SecureString "$proxyPassword" -AsPlainText -Force
          
          
          $proxy.Credentials = New-Object System.Management.Automation.PSCredential($proxyUser, $password)
          $webclient.UseDefaultCredentials = $true
        }
        $webclient.proxy = $proxy
      }

      try {
        $webclient.DownloadFile('http://myserver.com/test.exe', 'c:\\temp\\test.exe')
      }
      catch [Exception] {
        write-host $_.Exception.GetType().FullName
        write-host $_.Exception.Message
        write-host $_.Exception.InnerException.Message
        throw $_.Exception
      }
    PS1

    it { is_expected.to contain_file('download-test.exe.ps1').with_content(ps1) }
  end

  describe 'when downloading a file with provided cookies we want to check that the erb gets evaluated correctly' do
    let(:title)  { 'Download DotNet 4.0' }
    let(:params) do
      {
        url: 'http://myserver.com/test.exe',
        destination_directory: 'c:\temp',
        cookies: ['my_cookie=something-secure', 'this_too=something-else']
      }
    end

    ps1 = <<-PS1.gsub(%r{^ {6}}, '')
      $webclient = New-Object System.Net.WebClient
      $user = ''
      $password = ''
      $proxyAddress = ''
      $proxyUser = ''
      $proxyPassword = ''

      # This is potentially not secure if not using ssl
      if (($user -ne '') -and ($password -ne '')) {
        # Basic authentication encoding.
        $basic = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($user + ":" + $password));
        # Set Authorization HTTP header with Basic authentication information.
        $webclient.Headers["Authorization"] = "Basic $basic"
      }

      if ($proxyAddress -ne '') {
        if (!($proxyAddress.StartsWith('http://') -or $proxyAddress.StartsWith('https://'))) {
          $proxyAddress = 'http://' + $proxyAddress
        }

        $proxy = new-object System.Net.WebProxy
        $proxy.Address = $proxyAddress
        if (($proxyPassword -ne '') -and ($proxyUser -ne '')) {
        
          
          $password = ConvertTo-SecureString -string $proxyPassword
          
          
          $proxy.Credentials = New-Object System.Management.Automation.PSCredential($proxyUser, $password)
          $webclient.UseDefaultCredentials = $true
        }
        $webclient.proxy = $proxy
      }

      $webclient.Headers.Add([System.Net.HttpRequestHeader]::Cookie, "my_cookie=something-secure;this_too=something-else")

      try {
        $webclient.DownloadFile('http://myserver.com/test.exe', 'c:\\temp\\test.exe')
      }
      catch [Exception] {
        write-host $_.Exception.GetType().FullName
        write-host $_.Exception.Message
        write-host $_.Exception.InnerException.Message
        throw $_.Exception
      }
    PS1

    it { is_expected.to contain_file('download-test.exe.ps1').with_content(ps1) }
  end

  describe 'when not passing a destination url to the download define' do
    let(:title)  { 'Download DotNet 4.0' }
    let(:params) do 
      {
        url: 'http://myserver.com/test.exe'
      }
    end

    it do
      expect do
        is_expected.to contain_exec('download-test.exe')
      end.to raise_error(Puppet::Error)
    end
  end

  describe 'when not passing a URL to the file to download to the define' do
    let(:title)  { 'Download DotNet 4.0' }
    let(:params) do 
      {
        destination_directory: 'c:\temp'
      }
    end

    it do
      expect do
        is_expected.to contain_exec('download-test.exe')
      end.to raise_error(Puppet::Error)
    end
  end

  describe 'when downloading a non-exe file' do
    let(:title)  { 'Download MSI' }
    let(:params) do 
      {
        url: 'http://myserver.com/test.msi',
        destination_directory: 'c:\temp'
      }
    end

    it do 
      is_expected.to contain_exec('download-test.msi').with(
        'command' => 'c:\\temp\\download-test.msi.ps1',
        'onlyif'  => "if(Test-Path -Path 'c:\\temp\\test.msi') { exit 1 } else { exit 0 }"
      )
    end
  end

  describe 'when downloading the nodejs installer' do
    let(:title)  { 'Download nodejs installer' }
    let(:params) do 
      {
        url: 'http://artifactory.otsql.opentable.com:8081/artifactory/simple/puppet/windows/nodejs/0.10.15/nodejs-0.10.15-x64.msi',
        destination_directory: 'c:\temp'
      }
    end

    it do 
      is_expected.to contain_exec('download-nodejs-0.10.15-x64.msi').with(
        'command' => 'c:\\temp\\download-nodejs-0.10.15-x64.msi.ps1',
        'onlyif'  => "if(Test-Path -Path 'c:\\temp\\nodejs-0.10.15-x64.msi') { exit 1 } else { exit 0 }"
      )
    end
  end

  describe 'when the destination is a folder' do
    let(:title)  { 'Download nodejs installer' }
    let(:params) do
      {
        url: 'http://my.server/test.exe',
        destination_directory: 'c:\temp'
      }
    end

    it do 
      is_expected.to contain_exec('download-test.exe').with(
        'command' => 'c:\\temp\\download-test.exe.ps1',
        'onlyif'  => "if(Test-Path -Path 'c:\\temp\\test.exe') { exit 1 } else { exit 0 }"
      )
    end
  end

  describe 'when the filename is different to the filename in the url' do
    let(:title)  { 'Download nodejs installer' }
    let :params do
      {
        url: 'http://my.server/test.exe',
        destination_directory: 'c:\temp',
        destination_file: 'foo.exe'
      }
    end

    it do 
      is_expected.to contain_exec('download-foo.exe').with(
        'command' => 'c:\\temp\\download-foo.exe.ps1',
        'onlyif'  => "if(Test-Path -Path 'c:\\temp\\foo.exe') { exit 1 } else { exit 0 }"
      )
    end
  end

  describe 'the timeout parameter' do
    context 'when not specified' do
      let(:title)  { 'Download nodejs installer' }
      let(:params) do 
        {
          url: 'http://my.server/test.exe',
          destination_directory: 'c:\temp',
          destination_file: 'foo.exe'
        }
      end

      it { is_expected.to contain_exec('download-foo.exe').with('timeout' => nil) }
    end

    context 'when given an integer value' do
      let(:title)  { 'Download nodejs installer' }
      let(:params) do 
        {
          url: 'http://my.server/test.exe',
          destination_directory: 'c:\temp',
          destination_file: 'foo.exe',
          timeout: 30_000
        }
      end

      it { is_expected.to contain_exec('download-foo.exe').with('timeout' => 30_000) }
    end
  end

  describe 'the proxyAddress parameter' do
    let(:title)  { 'Download nodejs installer' }
    let(:params) do 
      {
        url: 'http://my.server/test.exe',
        destination_directory: 'c:\temp',
        destination_file: 'foo.exe',
        proxyAddress: 'http://localhost:9090'
      }
    end

    describe 'is not supported any more' do
      it do
        expect { is_expected.to contain_exec('download-foo.exe') }.to raise_error
      end
    end
  end

  describe 'when downloading a file with basic authenitcation we want to check that the erb gets evaluated correctly' do
    let(:title)  { 'Download DotNet 4.0' }
    let(:params) do 
      { 
        url: 'http://myserver.com/test.exe', 
        destination_directory: 'c:\temp',
        user: 'testuser',
        password: 'testpass'
      }
    end
    
    ps1 = <<-PS1.gsub(%r{^ {6}}, '')
      $webclient = New-Object System.Net.WebClient
      $user = 'testuser'
      $password = 'testpass'
      $proxyAddress = ''
      $proxyUser = ''
      $proxyPassword = ''

      # This is potentially not secure if not using ssl
      if (($user -ne '') -and ($password -ne '')) {
        # Basic authentication encoding.
        $basic = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($user + ":" + $password));
        # Set Authorization HTTP header with Basic authentication information.
        $webclient.Headers["Authorization"] = "Basic $basic"
      }

      if ($proxyAddress -ne '') {
        if (!($proxyAddress.StartsWith('http://') -or $proxyAddress.StartsWith('https://'))) {
          $proxyAddress = 'http://' + $proxyAddress
        }

        $proxy = new-object System.Net.WebProxy
        $proxy.Address = $proxyAddress
        if (($proxyPassword -ne '') -and ($proxyUser -ne '')) {
        
          
          $password = ConvertTo-SecureString -string $proxyPassword
          
          
          $proxy.Credentials = New-Object System.Management.Automation.PSCredential($proxyUser, $password)
          $webclient.UseDefaultCredentials = $true
        }
        $webclient.proxy = $proxy
      }

      try {
        $webclient.DownloadFile('http://myserver.com/test.exe', 'c:\\temp\\test.exe')
      }
      catch [Exception] {
        write-host $_.Exception.GetType().FullName
        write-host $_.Exception.Message
        write-host $_.Exception.InnerException.Message
        throw $_.Exception
      }
    PS1

    it { is_expected.to contain_file('download-test.exe.ps1').with_content(ps1) }
  end
end

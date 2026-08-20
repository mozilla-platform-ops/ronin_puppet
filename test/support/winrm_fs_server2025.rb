require 'winrm-fs'

module WinrmFsServer2025
  def stream_command(encoded_bytes)
    super.sub('if($method) { $method.Invoke($Null, $Null) }', '')
  end
end

WinRM::FS::Core::FileTransporter.prepend(WinrmFsServer2025)

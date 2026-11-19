require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'
source = File.expand_path('../.kitchen_configs/kitchen_ssh.rb', __dir__)
Dir.mktmpdir('ronin-kitchen-key-test') do |temporary|
  keys = %w[first second].map do |name|
    checkout = File.join(temporary, name)
    FileUtils.mkdir_p(File.join(checkout, '.kitchen_configs'))
    helper = File.join(checkout, '.kitchen_configs/kitchen_ssh.rb')
    FileUtils.cp(source, helper)
    # Concurrent config evaluations must share one usable identity.
    code = 'require ARGV[0]; puts RoninKitchenSSH.private_key'
    results = 3.times.map do
      Thread.new { Open3.capture3(RbConfig.ruby, '-e', code, helper) }
    end.map(&:value)
    raise 'key generation failed' unless results.all? { |_, _, status| status.success? }
    paths = results.map { |out, _, _| out.strip }.uniq
    raise 'concurrent evaluations disagree' unless paths.length == 1
    key = paths.first
    raise 'unsafe private key mode' unless File.stat(key).mode & 0o777 == 0o600
    raise 'unsafe key directory' unless File.stat(File.dirname(key)).mode & 0o777 == 0o700
    public_key, _, status = Open3.capture3('ssh-keygen', '-y', '-P', '', '-f', key)
    raise 'unusable key pair' unless status.success? && File.read("#{key}.pub") == public_key
    File.unlink("#{key}.pub")
    _, _, status = Open3.capture3(RbConfig.ruby, '-e', code, helper)
    raise 'public-key repair failed' unless status.success? && File.read("#{key}.pub") == public_key
    public_key
  end
  raise 'checkouts share identity' unless keys.uniq.length == 2
end
puts 'PASS: unique checkout identities, concurrent reuse, key permissions and public-key repair'

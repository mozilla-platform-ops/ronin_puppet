# Loaded by Kitchen's ERB config, including direct `bundle exec kitchen` in CI.
require 'fileutils'
require 'open3'

module RoninKitchenSSH
  def self.private_key
    directory = File.expand_path('../.kitchen/ssh', __dir__)
    FileUtils.mkdir_p(directory, mode: 0o700)
    File.chmod(0o700, directory)
    key = File.join(directory, 'id_ed25519')
    File.open(File.join(directory, '.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
      lock.flock(File::LOCK_EX)
      unless File.exist?(key)
        _, error, status = Open3.capture3('ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-C', 'ronin-kitchen-local', '-f', key)
        raise "Kitchen SSH key generation failed: #{error}" unless status.success?
      end
      File.chmod(0o600, key)
      # Derive the public key so missing or stale public halves are repaired.
      public_key, _, status = Open3.capture3('ssh-keygen', '-y', '-P', '', '-f', key)
      raise 'Cannot read local Kitchen SSH key; restore it or recreate test instances with a new key' unless status.success?

      File.write("#{key}.pub", public_key, mode: 'w', perm: 0o600)
    end
    key
  end
end

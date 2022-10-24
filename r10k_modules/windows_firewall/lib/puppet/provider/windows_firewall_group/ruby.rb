require 'puppet_x'
require_relative '../../../puppet_x/windows_firewall'

Puppet::Type.type(:windows_firewall_group).provide(:windows_firewall_group, :parent => Puppet::Provider) do
  confine :osfamily => :windows
  mk_resource_methods
  desc 'Windows Firewall group'

  commands :cmd => 'netsh'

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  # firewall groups always exist we can only enable/disable them
  def exists?
    true
  end

  # all work done in `flush()` method
  def create; end

  # all work done in `flush()` method
  def destroy; end

  def self.instances
    PuppetX::WindowsFirewall.groups.collect { |hash| new(hash) }
  end

  def flush
    # @property_hash contains the `IS` values (thanks Gary!)... For new rules there is no `IS`, there is only the
    # `SHOULD`. The setter methods from `mk_resource_methods` (or manually created) won't be called either. You have
    # to inspect @resource instead

    # careful its a label not a boolean...
    netsh_enabled = (@resource[:enabled] == :true)? 'yes': 'no'

    Puppet.notice("(windows_firewall) group '#{@resource[:name]}' enabled: #{@resource[:enabled]}")
    cmd = "#{command(:cmd)} advfirewall firewall set rule group=\"#{@resource[:name]}\" new enable=\"#{netsh_enabled}\""
    output = execute(cmd).to_s
    Puppet.debug("...#{output}")
  end

end

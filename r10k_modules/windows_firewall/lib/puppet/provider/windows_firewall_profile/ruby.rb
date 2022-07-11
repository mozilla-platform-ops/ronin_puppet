require 'puppet_x'
#require 'puppet_x/windows_firewall'
require_relative '../../../puppet_x/windows_firewall'

Puppet::Type.type(:windows_firewall_profile).provide(:windows_firewall_profile, :parent => Puppet::Provider) do
  confine :osfamily => :windows
  mk_resource_methods
  desc "Windows Firewall profile"

  commands :cmd => "netsh"

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  # firewall groups always exist we can only enable/disable them
  def exists?
    #@property_hash[:ensure] == :present
    true
  end

  # all work done in `flush()` method
  def create()
  end

  # all work done in `flush()` method
  def destroy()
  end


  def self.instances
    PuppetX::WindowsFirewall.profiles(command(:cmd)).collect { |hash| new(hash) }
  end

  def flush
    # @property_hash contains the `IS` values (thanks Gary!)... For new rules there is no `IS`, there is only the
    # `SHOULD`. The setter methods from `mk_resource_methods` (or manually created) won't be called either. You have
    # to inspect @resource instead
    @resource.properties.each { |property|
      property_name = PuppetX::WindowsFirewall.profile_argument_lookup(property.name)
      property_value = property.value

      # global settings are space delimited and we must run one command per setting
      arg = "#{property_name} \"#{property_value}\""
      cmd = "#{command(:cmd)} advfirewall set #{@resource[:name]}profile #{arg}"
      output = execute(cmd).to_s
      Puppet.debug("...#{output}")
    }
  end

end

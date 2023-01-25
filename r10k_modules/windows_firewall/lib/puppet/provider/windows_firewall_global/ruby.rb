require 'puppet_x'
require_relative '../../../puppet_x/windows_firewall'

Puppet::Type.type(:windows_firewall_global).provide(:windows_firewall_global, :parent => Puppet::Provider) do
  confine :osfamily => :windows
  mk_resource_methods
  desc 'Windows Firewall global settings'

  commands :cmd => 'netsh'

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  # global settings always exist
  def exists?
    true
  end

  # all work done in `flush()` method
  def create; end

  # all work done in `flush()` method
  def destroy; end

  def self.instances
    PuppetX::WindowsFirewall.globals(command(:cmd)).collect { |hash| new(hash) }
  end

  def flush
    # @property_hash contains the `IS` values (thanks Gary!)... For new rules there is no `IS`, there is only the
    # `SHOULD`. The setter methods from `mk_resource_methods` (or manually created) won't be called either. You have
    # to inspect @resource instead
    @resource.properties.reject { |property|
      [ :authzusergrptransport,
        :authzcomputergrptransport,
        :boottimerulecategory,
        :firewallrulecategory,
        :stealthrulecategory,
        :consecrulecategory
      ].include?(property.name)
    }.each { |property|
      property_name = PuppetX::WindowsFirewall.global_argument_lookup(property.name)
      property_value = property.value.instance_of?(Array) ? property.value.join(',') : property.value

      # global settings are space delimited and we must run one command per setting
      arg = "#{property_name} \"#{property_value}\""
      # Puppet.notice("(windows_firewall) global settings '#{@resource[:name]}' enabled: #{@resource[:enabled]}")
      cmd = "#{command(:cmd)} advfirewall set global #{arg}"
      output = execute(cmd).to_s
      Puppet.debug("...#{output}")
    }
  end

end

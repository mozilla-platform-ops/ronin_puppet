require 'puppet_x'
require_relative '../../../puppet_x/windows_firewall'

Puppet::Type.type(:windows_firewall_rule).provide(:windows_firewall_rule, :parent => Puppet::Provider) do
  confine :osfamily => :windows
  mk_resource_methods
  desc "Windows Firewall"


  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end
  
  def exists?
    @property_hash[:ensure] == :present
  end

  def create()
    PuppetX::WindowsFirewall.create_rule @resource
  end

  def destroy()
    # Delete only require firewall rule name to process
    PuppetX::WindowsFirewall.delete_rule @resource[:name]
  end

  def self.instances
    PuppetX::WindowsFirewall.rules.collect { |hash| new(hash) }
  end

  def flush
    # Update rule
    # Only if IS value ensure == SHOULD value ensure
    # @property_hash contains the IS values (thanks Gary!). For new rules there is no IS, there is only the SHOULD
    if @property_hash[:ensure] == @resource[:ensure]
      PuppetX::WindowsFirewall.update_rule @resource
    end
  end

end
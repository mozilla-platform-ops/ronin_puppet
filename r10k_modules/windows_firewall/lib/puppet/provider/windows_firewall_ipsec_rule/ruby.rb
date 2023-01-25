require 'puppet_x'
require_relative '../../../puppet_x/windows_firewall_ipsec'

Puppet::Type.type(:windows_firewall_ipsec_rule).provide(:windows_firewall_ipsec_rule, :parent => Puppet::Provider) do
  confine :osfamily => :windows
  mk_resource_methods
  desc 'Windows Firewall'

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

  def create
    PuppetX::WindowsFirewallIPSec.create_rule @resource
  end

  def destroy
    PuppetX::WindowsFirewallIPSec.delete_rule @property_hash
  end

  def self.instances
    PuppetX::WindowsFirewallIPSec.rules.collect { |hash| new(hash) }
  end

  def flush
    # Update rule
    # Only if IS value ensure == SHOULD value ensure
    # @property_hash contains the IS values (thanks Gary!). For new rules there is no IS, there is only the SHOULD
    if @property_hash[:ensure] == @resource[:ensure]
      PuppetX::WindowsFirewallIPSec.update_rule @resource
    end
  end

end

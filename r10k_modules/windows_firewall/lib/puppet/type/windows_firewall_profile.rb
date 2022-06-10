require 'puppet/parameter/boolean'

Puppet::Type.newtype(:windows_firewall_profile) do
  @doc = "Enable/Disable windows firewall profile"

  # you can't "ensure" a profile - 3 exist at all times, we just let user set their policies

  newparam(:name) do
    desc "Name of the profile to work on"
    isnamevar
    munge do |value|
      value.downcase
    end
  end

  newproperty(:state) do
    desc "State of this firewall profile"
    newvalues(:on, :off, true, false)
    munge do |value|
      if value == true
        munged = :on
      elsif value == false
        munged = :off
      else
        munged = value
      end

      munged
    end
  end

  newproperty(:firewallpolicy) do
    desc "Configures default inbound and outbound behavior"
    munge do |value|
      value.downcase
    end
  end

  newproperty(:localfirewallrules) do
    desc "Merge local firewall rules with Group Policy rules. Valid when configuring a Group Policy store"
    newvalues(:enable, :disable, :notconfigured)
    validate do |value|
      raise("property is read-only because I'm not sure how to read the current value - pls open a ticket with info if you want this")
    end
  end

  newproperty(:localconsecrules) do
    desc "Merge local connection security rules with Group Policy rules. Valid when configuring a Group Policy store"
    newvalues(:enable, :disable, :notconfigured)
    validate do |value|
      raise("property is read-only because I'm not sure how to read the current value - pls open a ticket with info if you want this")
    end
  end

  newproperty(:inboundusernotification) do
    desc "Notify user when a program listens for inbound connections."
    newvalues(:enable, :disable, :notconfigured)
  end

  newproperty(:remotemanagement) do
    desc "Allow remote management of Windows Firewall"
    newvalues(:enable, :disable, :notconfigured)
  end

  newproperty(:unicastresponsetomulticast) do
    desc "Control stateful unicast response to multicast."
    newvalues(:enable, :disable, :notconfigured)
  end

  newproperty(:logallowedconnections) do
    desc "log allowed connections"
    newvalues(:enable, :disable, :notconfigured)
  end

  newproperty(:logdroppedconnections) do
    desc "log dropped connections"
    newvalues(:enable, :disable, :notconfigured)
  end

  newproperty(:maxfilesize) do
    desc "maximum size of log file in KB"
  end

  newproperty(:filename) do
    desc "Name and location of the firewall log"
  end
end
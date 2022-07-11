require 'puppet/parameter/boolean'

Puppet::Type.newtype(:windows_firewall_ipsec_rule) do
  @doc = "Manage Windows Firewall with Puppet"

  ensurable do
    desc "How to ensure this firewall rule (`present` or `absent`)"

    defaultvalues

    defaultto(:present)

    # we need the insync? for puppet to make right decision on whether to run the provider or not - if we leave it up
    # to provider.exists? then puppet resource command broken for files that are mismatched, they always show as ensure
    # absent even though puppet is somewhat aware of them
    def insync?(is)
      (is == :present && should == :present) || (is == :absent && should == :absent)
    end
  end

  newproperty(:enabled) do
    desc "This parameter specifies that the rule object is administratively enabled or administratively disabled (`true` or `false`)"
    newvalues(:true, :false)

    defaultto :true
  end

  newproperty(:display_name) do
    desc "Specifies the localized, user-facing name of the firewall rule being created"
    defaultto { @resource[:name] }
  end

  newproperty(:description) do
    desc "This parameter provides information about the firewall rule"
  end

  newproperty(:profile, :array_matching=>:all) do
    desc "Specifies one or more profiles to which the rule is assigned"
    newvalues(:domain, :private, :public, :any)

    # Thanks Gary!
    def insync?(is)
      is.sort == should.sort
    end
  end

  newproperty(:display_group) do
    desc "This parameter specifies the source string for the DisplayGroup parameter (read-only)"
    validate do |value|
      fail("grouping is readonly: https://social.technet.microsoft.com/Forums/office/en-US/669a8eaf-13d1-4010-b2ac-30c800c4b152/2008r2-firewall-add-rules-to-group-create-new-group")
    end
  end

  newproperty(:local_address) do
    desc "Specifies that network packets with matching IP addresses match this rule (hostname not allowed)"

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end
  end

  newproperty(:remote_address) do
    desc "Specifies that network packets with matching IP addresses match this rule (hostname not allowed)"

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end
  end

  newproperty(:protocol) do
    desc "This parameter specifies the protocol for an IPsec rule"
    # Also accept 0-255 :/
    newvalues(:tcp, :udp, :icmpv4, :icmpv6, /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/)

    def insync?(is)
      is.to_s == should.to_s
    end
  end


  newproperty(:local_port) do
    desc "Specifies that network packets with matching IP port numbers match this rule"

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end
  end

  newproperty(:remote_port) do
    desc "This parameter value is the second end point of an IPsec rule"

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end
  end

  newproperty(:mode) do
    desc "Specifies the type of IPsec mode connection that the IPsec rule defines (None, Transport, or Tunnel)"
    newvalues(:none, :transport, :tunnel)

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end
  end


  newproperty(:interface_type, :array_matching=>:all) do
    desc "Specifies that only network connections made through the indicated interface types are subject to the requirements of this rule"
    newvalues(:any, :wired, :wireless, :remote_access)

    defaultto :any

    def insync?(is)
      is.sort == should.sort
    end
  end

  newproperty(:inbound_security) do
    desc "This parameter determines the degree of enforcement for security on inbound traffic"
    newvalues(:require, :request)
  end

  newproperty(:outbound_security) do
    desc "This parameter determines the degree of enforcement for security on outbound traffic"
    newvalues(:require, :request)
  end

  newproperty(:phase1auth_set) do
    desc "Gets the main mode rules that are associated with the given phase 1 authentication set to be created"
    newvalues(:computerkerberos, :anonymous)
  end

  newproperty(:phase2auth_set) do
    desc "Gets the IPsec rules that are associated with the given phase 2 authentication set to be created"
    newvalues(:userkerberos)
  end

  newparam(:name) do
    desc "Name of this rule"
    isnamevar
    validate do |value|
      fail("it is not allowed to have a rule called 'any'") if value.downcase == "any"
    end
  end

end
require 'puppet/parameter/boolean'

Puppet::Type.newtype(:windows_firewall_rule) do
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
    desc "Whether the rule is enabled (`true` or `false`)"
    newvalues(:true, :false)

    defaultto :true
  end

  newproperty(:display_name) do
    desc "Display name for this rule"
    defaultto { @resource[:name] }
  end

  newproperty(:description) do
    desc "Description of this rule"
  end

  newproperty(:direction) do
    desc "Direction the rule applies to (`inbound`/`outbound`)"
    newvalues(:inbound, :outbound)
  end

  newproperty(:profile, :array_matching=>:all) do
    desc "Which profile(s) this rule belongs to, use an array to pass more then one"
    newvalues(:domain, :private, :public, :any)

    # Thanks Gary!
    def insync?(is)
      is.sort == should.sort
    end
  end

  newproperty(:display_group) do
    desc "group that the rule belongs to (read-only)"
    validate do |value|
      fail("grouping is readonly: https://social.technet.microsoft.com/Forums/office/en-US/669a8eaf-13d1-4010-b2ac-30c800c4b152/2008r2-firewall-add-rules-to-group-create-new-group")
    end
  end

  newproperty(:local_address) do
    desc "the local IP the rule targets (hostname not allowed)"

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end
  end

  newproperty(:remote_address) do
    desc "the remote IP the rule targets (hostname not allowed)"

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end
  end

  newproperty(:protocol) do
    desc "the protocol the rule targets"
    # Also accept 0-255 :/
    newvalues(:tcp, :udp, :icmpv4, :icmpv6, /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/)

    def insync?(is)
      is.to_s == should.to_s
    end
  end

  newproperty(:icmp_type) do
    desc <<-EOT
      Protocol type to use (with ICMPv4/ICMPv6)"

      Values should be:
        * Just the type (3)                                                                                                                                                                    ICMP type code: 0 through 255.
        * ICMP type code pairs: 3:4 (type 3, code 4)
        * `any`
    EOT
  end

  newproperty(:local_port) do
    desc "the local port the rule targets"

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end
  end

  newproperty(:remote_port) do
    desc "the remote port the rule targets"

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end
  end

  newproperty(:edge_traversal_policy) do
    desc "Apply rule to encapsulated traffic (?) - see: https://serverfault.com/questions/89824/windows-advanced-firewall-what-does-edge-traversal-mean#89846"
    newvalues(:block, :allow, :defer_to_user, :defer_to_app)

    defaultto :block
  end

  newproperty(:action) do
    desc "What to do when this rule matches (Accept/Reject)"
    newvalues(:block, :allow)
  end

  newproperty(:program) do
    desc "Path to program this rule applies to"
  end

  newproperty(:interface_type, :array_matching=>:all) do
    desc "Interface types this rule applies to"
    newvalues(:any, :wired, :wireless, :remote_access)

    defaultto :any

    def insync?(is)
      is.sort == should.sort
    end
  end

  newproperty(:service) do
    desc "service names this rule applies to"
  end

  newproperty(:authentication) do
    desc "Specifies that authentication or encryption is required on firewall rules (authentication, encryption)"
    newvalues(:notrequired, :required, :noencap)
  end

  newproperty(:encryption) do
    desc "Specifies that authentication or encryption is required on firewall rules (authentication, encryption)"
    newvalues(:notrequired, :required, :dynamic)
  end

  newproperty(:remote_machine) do
    desc "Specifies that matching IPsec rules of the indicated computer accounts are created"
  end

  newproperty(:local_user) do
    desc "Specifies that matching IPsec rules of the indicated user accounts are created"
  end

  newproperty(:remote_user) do
    desc "Specifies that matching IPsec rules of the indicated user accounts are created"
  end

  newparam(:name) do
    desc "Name of this rule"
    isnamevar
    validate do |value|
      fail("it is not allowed to have a rule called 'any'") if value.downcase == "any"
    end
  end

end
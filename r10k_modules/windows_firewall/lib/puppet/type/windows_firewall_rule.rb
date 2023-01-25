require 'puppet/parameter/boolean'

Puppet::Type.newtype(:windows_firewall_rule) do
  @doc = 'Manage Windows Firewall with Puppet'

  ensurable do
    desc "How to ensure this firewall rule (`present` or `absent`)"

    defaultto :present
    defaultvalues

    # we need the insync? for puppet to make right decision on whether to run the provider or not - if we leave it up
    # to provider.exists? then puppet resource command broken for files that are mismatched, they always show as ensure
    # absent even though puppet is somewhat aware of them
    def insync?(is)
      (is == :present && should == :present) || (is == :absent && should == :absent)
    end

  end

  # Resource validation
  validate do
    # Only if we ensure that resource should be present
    if self[:ensure] == :present
      raise 'direction is a required attribute' if self[:direction].nil?
      raise 'protocol is a required attribute' if self[:protocol].nil?
      raise 'action is a required attribute' if self[:action].nil?
    end
  end

  newproperty(:enabled) do
    desc "Whether the rule is enabled (`true` or `false`)"
    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:display_name) do
    desc 'Display name for this rule'
    defaultto { @resource[:name] }
    validate do |value|
      unless value.kind_of?(String)
        raise "Invalid value '#{value}'. Should be a string"
      end
    end
  end

  newproperty(:description) do
    desc 'Description of this rule'
    defaultto ''
    validate do |value|
      unless value.kind_of?(String)
        raise "Invalid value '#{value}'. Should be a string"
      end
    end
  end

  newproperty(:direction) do
    desc "Direction the rule applies to (`inbound`/`outbound`)"
    newvalues(:inbound, :outbound)
    isrequired
    validate do |value|
      unless value.kind_of?(String)
        raise "Invalid value '#{value}'. Should be a string"
      end
      unless ['inbound', 'outbound'].include?(value)
        raise "Invalid value '#{value}'. Valid value is inbound or outbound"
      end
    end
  end

  newproperty(:profile, :array_matching=>:all) do
    desc 'Which profile(s) this rule belongs to, use an array to pass more then one'
    newvalues(:domain, :private, :public, :any)

    # Thanks Gary!
    def insync?(is)
      is.sort == should.sort
    end

    defaultto :any
  end

  newproperty(:display_group) do
    desc 'group that the rule belongs to (read-only)'
    validate do |value|
      raise 'grouping is readonly: https://social.technet.microsoft.com/Forums/office/en-US/669a8eaf-13d1-4010-b2ac-30c800c4b152/2008r2-firewall-add-rules-to-group-create-new-group'
    end
  end

  newproperty(:local_address) do
    desc 'the local IP the rule targets (hostname not allowed)'

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end

    defaultto :any
  end

  newproperty(:remote_address) do
    desc 'the remote IP the rule targets (hostname not allowed)'

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end

    defaultto :any
  end

  newproperty(:protocol) do
    desc 'the protocol the rule targets'
    # Also accept 0-255 :/
    newvalues(:tcp, :udp, :icmpv4, :icmpv6, /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/)
    isrequired
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

    defaultto do
      if @resource[:protocol] == :icmpv4 || @resource[:protocol] == :icmpv6
        :any
      end
    end
  end

  newproperty(:local_port) do
    desc 'the local port the rule targets'

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end

    defaultto do
      if @resource[:icmp_type] != :any and !@resource[:icmp_type].nil?
        :rpc
      else
        :any
      end
    end
  end

  newproperty(:remote_port) do
    desc 'the remote port the rule targets'

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end

    defaultto :any
  end

  newproperty(:edge_traversal_policy) do
    desc 'Apply rule to encapsulated traffic (?) - see: https://serverfault.com/questions/89824/windows-advanced-firewall-what-does-edge-traversal-mean#89846'
    newvalues(:block, :allow, :defer_to_user, :defer_to_app)

    defaultto :block
  end

  newproperty(:action) do
    desc 'What to do when this rule matches (Accept/Reject)'
    newvalues(:block, :allow)
    isrequired
  end

  newproperty(:program) do
    desc 'Path to program this rule applies to'

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end

    defaultto :any
  end

  newproperty(:interface_type, :array_matching=>:all) do
    desc 'Interface types this rule applies to'
    newvalues(:any, :wired, :wireless, :remote_access)

    defaultto :any

    def insync?(is)
      is.sort == should.sort
    end
  end

  newproperty(:service) do
    desc 'service names this rule applies to'

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end

    defaultto :any
  end

  newproperty(:authentication) do
    desc 'Specifies that authentication or encryption is required on firewall rules (authentication, encryption)'
    newvalues(:notrequired, :required, :noencap)
    defaultto :notrequired
  end

  newproperty(:encryption) do
    desc 'Specifies that authentication or encryption is required on firewall rules (authentication, encryption)'
    newvalues(:notrequired, :required, :dynamic)
    defaultto :notrequired
  end

  newproperty(:remote_machine) do
    desc 'Specifies that matching IPsec rules of the indicated computer accounts are created'

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end

    defaultto :any
  end

  newproperty(:local_user) do
    desc 'Specifies that matching IPsec rules of the indicated user accounts are created'

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end

    defaultto :any
  end

  newproperty(:remote_user) do
    desc 'Specifies that matching IPsec rules of the indicated user accounts are created'

    def insync?(is)
      "#{is}".downcase == "#{should}".downcase
    end

    defaultto :any
  end

  newparam(:name) do
    desc 'Name of this rule'
    isnamevar
    validate do |value|
      raise "it is not allowed to have a rule called 'any'" if value.downcase == "any"
    end
  end

end

require 'puppet/parameter/boolean'

Puppet::Type.newtype(:windows_firewall_global) do
  @doc = "Manage windows global firewall settings"

  # you can't "ensure" a rule group - you can only enable or disable it this is a different
  # concept to puppet view of existence so removed for clarity

  newparam(:name) do
    desc "Not used (reference only)"
    isnamevar
  end

  newproperty(:strongcrlcheck) do
    desc "Configures how CRL checking is enforced"
    validate do |value|
      if ! [0,1,2].include? value.to_i
        raise("Invalid value, allowed: 0,1,2")
      end
    end
  end

  newproperty(:saidletimemin) do
    desc "Configures the security association idle time in minutes."

    validate do |value|
      value = value.to_i
      if ! (value >= 5 && value <= 60)
        raise("Invalid value, allowed: 0,1,2")
      end
    end
  end

  newproperty(:defaultexemptions, :array_matching => :all) do
    desc "Configures the default IPsec exemptions. Default is to exempt IPv6 neighbordiscovery protocol and DHCP from IPsec."
    newvalues(:none, :neighbordiscovery, :icmp, :dhcp, :notconfigured)

    # thanks again Gary! - http://garylarizza.com/blog/2013/11/25/fun-with-providers/
    def insync?(is)
      # incoming `should` is an array of symbols not strings...
      # Element-wise comparison - http://ruby-doc.org/core-2.5.1/Array.html
      (should.map { |e| e.to_s }.sort <=> is.sort) == 0
    end

  end

  newproperty(:ipsecthroughnat) do
    desc "Configures when security associations can be established with a computer behind a network address translator"
    newvalues(:never, :serverbehindnat, :serverandclientbehindnat, :notconfigured)
  end

  newproperty(:authzusergrp) do
    desc "Configures the users that are authorized to establish tunnel mode connections."
  end

  newproperty(:authzcomputergrp) do
    desc "Configures the computers that are authorized to establish tunnel mode connections"
  end

  newproperty(:authzusergrptransport) do
    desc "Authz user group transport"
    validate do |value|
      raise("property is read-only")
    end
  end

  newproperty(:authzcomputergrptransport) do
    desc "Authz computer transport"
    validate do |value|
      raise("property is read-only")
    end
  end

  newproperty(:statefulftp) do
    desc "Stateful FTP"
    newvalues(:enable, :disable, :notconfigured)
  end

  newproperty(:statefulpptp) do
    desc "Stateful PPTP"
    newvalues(:enable, :disable, :notconfigured)
  end

  newproperty(:keylifetime) do
    desc "Sets main mode key lifetime in minutes and sessions"
  end

  newproperty(:secmethods) do
    desc "configures the main mode list of proposals"
  end

  newproperty(:forcedh) do
    desc "configures the option to use DH to secure key exchange"
    newvalues(:yes, :no)
  end

  newproperty(:boottimerulecategory) do
    desc "Boot time rule category"
    validate do |value|
      raise("property is read-only")
    end
  end

  newproperty(:firewallrulecategory) do
    desc "Firewall rule category"
    validate do |value|
      raise("property is read-only")
    end
  end

  newproperty(:stealthrulecategory) do
    desc "Stealth rule category"
    validate do |value|
      raise("property is read-only")
    end
  end

  newproperty(:consecrulecategory) do
    desc "con sec rule category"
    validate do |value|
      raise("property is read-only")
    end
  end

end
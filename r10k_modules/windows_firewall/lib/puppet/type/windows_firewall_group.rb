require 'puppet/parameter/boolean'

Puppet::Type.newtype(:windows_firewall_group) do
  @doc = "Enable/Disable windows firewall group"

  # you can't "ensure" a rule group - you can only enable or disable it this is a different
  # concept to puppet view of existence so removed for clarity

  newparam(:name) do
    desc "Name of the rule group to enable/disable"
    isnamevar
  end

  newproperty(:enabled) do
    desc "Whether the rule group is enabled (`true` or `false`)"
    newvalues(:true, :false)
    defaultto :true

    def insync?(is)
      if is == :absent
        fail("You are trying to add change a non-existent groups - firewall group names are case-sensitive")
      end

      # MUST still test the insync condition and return status or will always run
      is == should
    end
  end

end
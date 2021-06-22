# frozen_string_literal: true

Puppet::Type.newtype(:reg_acl) do
  desc 'Puppet type for managing Windows Registry ACLs'

  def initialize(*args)
    super

    # if target is unset, use the title
    self[:target] ||= self[:name]
  end

  newparam(:name) do
    desc "
      The description used for uniqueness. If the target parameter is not provided name will be used.
    "

    validate do |value|
      if value.nil? || value.empty?
        raise ArgumentError, 'A non-empty name must be specified.'
      end
    end

    munge do |value|
      t = value.split(%r{[:,\\]})
      newvalue = "#{t[0]}:#{t[1..-1].join('\\')}"
      newvalue
    end

    isnamevar
  end

  newparam(:target) do
    desc 'Path to the registry key.  If not provided the name parameter will be used.'

    validate do |value|
      if value.nil? || value.empty?
        raise ArgumentError, 'A non-empty target must be specified.'
      end
    end

    munge do |value|
      t = value.split(%r{[:,\\]})
      newvalue = "#{t[0]}:#{t[1..-1].join('\\')}"
      newvalue
    end
  end

  newproperty(:owner) do
    desc 'Provide the name of the owner for this registry key. Can be string or SID.'

    munge do |value|
      provider.account_sid(value)
    end

    def change_to_s(current, should)
      super(provider.owner_to_s(current), provider.owner_to_s(should))
    end
  end

  newproperty(:permissions, array_matching: :all) do
    # rubocop:disable Metrics/LineLength
    desc "
    Array of hashes of desired ACEs to be applied to target registry key. By default, reg_acl will simply compare existing permissions (non-inherited only) and make sure that the provided permissions are applied. Use the purge parameter to adjust this behavior.

    For each hash, valid parameters:

    IdentityReference: String or SID format for identity to have this ACE applied

    AccessControlType: String of access type. Valid values Allow or Deny

    InheritanceFlags: String of inheritance flags. Valid values: 'ContainerInherit, ObjectInherit', 'ContainerInherit', or 'ObjectInherit'

    PropagationFlags: String of propagation behavior. Valid values: 'None', 'InheritOnly', or 'NoPropagateInherit, InheritOnly'

    RegistryRights: String of Permissions to apply. Keep in mind you can combine values where needed(single string, comma seperated). Common values are 'FullControl', 'ReadKey', and 'WriteKey'. Valid values: 'QueryValues','SetValue','CreateSubKey','EnumerateSubKeys','Notify','CreateLink','ReadKey','WriteKey','Delete','ReadPermissions','ChangePermissions','TakeOwnership','FullControl'. See https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.registryrights(v=vs.110).aspx for more details.
    "
    # rubocop:enable Metrics/LineLength

    validate do |value|
      raise ArgumentError, 'All supplied ACE must contain the RegistryRights setting'    unless value.key?('RegistryRights')
      raise ArgumentError, 'All supplied ACE must contain the IdentityReference setting' unless value.key?('IdentityReference')

      if value.key?('IsInherited') && value['IsInherited'] == true
        raise ArgumentError, "Cannot specify ACE that has 'InheritedFlags' set to true; update the parent!"
      end
    end

    # Let's fill in some blanks
    munge do |value|
      value['AccessControlType'] = 'Allow'                             unless value.key?('AccessControlType')
      value['IsInherited']       = false                               unless value.key?('IsInherited')
      value['InheritanceFlags']  = 'ContainerInherit, ObjectInherit'   unless value.key?('InheritanceFlags')
      value['PropagationFlags']  = 'None'                              unless value.key?('PropagationFlags')
      value['IdentityReference'] = provider.account_sid(value['IdentityReference'])

      # Sort perms
      value['RegistryRights'] = value['RegistryRights'].delete("\s").split(%r{,}).sort.join(', ')

      value
    end

    def change_to_s(current, should)
      purge = provider.purge_state

      newperms = if purge == :all
                   should
                 elsif purge == :listed
                   current - (current & should)
                 else
                   current + should
                 end

      # Build a readble message
      msg = ''.dup
      msg << "Permissions changed from:\n[\n"
      provider.permissions_to_s(current).each { |p| msg << "  #{p.sort_by { |k, _v| k.to_s }.to_h}\n" }
      msg << "]\n  to\n[\n"
      provider.permissions_to_s(newperms).each { |p| msg << "  #{p.sort_by { |k, _v| k.to_s }.to_h}\n" }
      msg << "\n]\n"

      msg
    end

    def insync?(current)
      provider.are_permissions_insync?(current, @should)
    end
  end

  newparam(:purge) do
    desc "
    Boolean to specify if all ACE should be purged that are not specifically named. Valid values are all, listed, false. Default: false

    all: If additional ACE are present that have not been specifically declared (non-inherited), they will be removed.

    listed: Ensure that the defined ACEs in permissions parameter are removed if present(i.e. delete listed parameters).

    false: Default. Only compare defined ACEs in permissions and ignore any other present.
    "
    defaultto :false
    newvalues(:all, :listed, :false)
  end

  newproperty(:inherit_from_parent) do
    desc 'Should this ACL include inherited permissions? Valid values are true, false. Default: true'
    defaultto :true
    newvalues(:true, :false)
    def insync?(is)
      is.to_s == should.to_s
    end
  end

  validate do
    # If purge is set to all then inherit_from_parent MUST be true
    if self[:purge].downcase.to_sym == :all && self[:inherit_from_parent].downcase.to_sym == :true
      raise ArgumentError, "Cannot purge set purge to 'all' and inherit_from_parent to 'true'!  Set inherit_from_parent to false to manage explicit permissions!"
    end

    if self[:purge].downcase.to_sym == :all
      raise ArgumentError, 'Must have an owner set!' unless self[:owner]
    end
  end
end

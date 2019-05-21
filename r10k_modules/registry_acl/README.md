registry_acl
============


## Description
This module provides the `reg_acl` resource type used to set registry permissions.


## Resource Types
### `reg_acl`
Puppet type for managing Windows Registry ACLs


#### == **Parameters** ==

#### `inherit_from_parent`

Should this ACL include inherited permissions?  Valid values are `true`, `false`. Default: `true`

#### `name`

The description used for uniqueness.  If the target parameter is not provided `name` will be used.

##### `owner`

Provide the name of the owner for this registry key.  Can be string or SID.

##### `permissions`

Array of hashes of desired ACEs to be applied to target registry key.  By default, `reg_acl` will simply compare existing permissions (non-inherited only) and make sure that the provided permissions are applied.  Use the `purge` parameter to adjust this behavior.


For each hash, valid parameters:

- `IdentityReference`: String or SID format for identity to have this ACE applied
- `AccessControlType`: String of access type.  Valid values Allow or Deny
- `InheritanceFlags`:  String of inheritance flags.  Valid values: 'ContainerInherit, ObjectInherit', 'ContainerInherit', or 'ObjectInherit'
- `PropagationFlags`:  String of propagation behavior.  Valid values: 'None', 'InheritOnly', or 'NoPropagateInherit, InheritOnly'
- `RegistryRights`:    String of Permissions to apply.  Keep in mind you can combine values where needed(single string, comma seperated).  Common values are 'FullControl', 'ReadKey', and 'WriteKey'.  Valid values: 'QueryValues','SetValue','CreateSubKey','EnumerateSubKeys','Notify','CreateLink','ReadKey','WriteKey','Delete','ReadPermissions','ChangePermissions','TakeOwnership','FullControl'.  See https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.registryrights(v=vs.110).aspx for more details.

##### `purge`

Boolean to specify if all ACE should be purged that are not specifically named.  Valid values are `all`, `listed`, `false`. Default: `false`

- `all`:  If additional ACE are present that have not been specifically declared (non-inherited), they will be removed.
- `listed`: Ensure that the defined ACEs in `permissions` parameter are removed if present(i.e. delete listed parameters).
- `false`:  Default.  Only compare defined ACEs in `permissions` and ignore any other present.

##### `target`

Path to the registry key.  Expressed via _hive_:_path_ or _hive_\_path_.  For example, hklm:SOFTWARE\test, hklm\software\test

#### == **Examples** ==

Ensure owner, inherit_from_parent, and the following two ACE are present.
```
reg_acl { 'hklm:software\test1',
  owner => 'Administrator',
  permissions =>
    [
      {'RegistryRights' => 'FullControl', 'IdentityReference' => 'BUILTIN\Administrators' },
      {'RegistryRights' => 'ReadPermissions, SetValue', 'IdentityReference' => 'somelocaluser' },
      {'RegistryRights' => 'FullControl', 'IdentityReference' => 'S-1-5-21-392019300-2179095474-2072420904-1002'},
    ],
 }
```

Ensure only these two ACE are present, disable inheritance from parent, and set the owner to SID.
```
reg_acl { 'admin rules':
  target => 'hklm:software\test1',
  owner => 'S-1-5-21-392019300-2179095474-2072420904-1002',
  inherit_from_parent => false,
  permissions =>
    [
      {'RegistryRights' => 'FullControl', 'IdentityReference' => 'BUILTIN\Administrators' },
      {'RegistryRights' => 'FullControl', 'IdentityReference' => 'S-1-5-21-392019300-2179095474-2072420904-1002'},
    ],
   purge => 'all',
 }
```

Ensure that the listed permissions are removed.
```
reg_acl { 'remove rules':
  target => 'hklm:software\test1',
  permissions =>
    [
      {'RegistryRights' => 'FullControl', 'IdentityReference' => 'GP-WIN-1\test' },
    ],
  purge => 'listed',
}
```

## To Do List
- Test Suite



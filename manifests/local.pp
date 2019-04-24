# This file is only used for testing purposes

##################################################
#### MOCK CLASSES WHICH SHOULD NOT TESTED HERE
class kitchen_template2(
  Hash $config = {},
) {
  notice( 'mocked class ==> kitchen_template::foobar' )
}

# INCLUDE CLASSES HERE

# bitbar testing
include ::bitbar_devicepool
include roles_profiles::profiles::relops_users
include roles_profiles::profiles::cia_users

# mac g-w testing

# linux g-w testing

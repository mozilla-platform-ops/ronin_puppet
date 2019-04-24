# This file is only used for testing purposes

##################################################
#### MOCK CLASSES WHICH SHOULD NOT TESTED HERE
class kitchen_template2(
  Hash $config = {},
) {
  notice( 'mocked class ==> kitchen_template::foobar' )
}

# INCLUDE THE CLASS
include ::bitbar_devicepool
include roles_profiles::profiles::relops_users
# TODO: call ::bitbar_devicepool:users

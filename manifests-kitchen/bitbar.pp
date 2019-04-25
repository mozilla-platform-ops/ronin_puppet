##################################################
#### MOCK CLASSES WHICH SHOULD NOT TESTED HERE
# class kitchen_template2(
#   Hash $config = {},
# ) {
#   notice( 'mocked class ==> kitchen_template::foobar' )
# }

# dirty hack: include site.pp
# can't point at directory of manifests, as last check in site.pp fails for test-kitchen
case $::operatingsystem {
    'Windows': {
    }
    'Darwin': {
        # Set toplevel variables for Darwin
        $root_user  = 'root'
        $root_group = 'wheel'

    }
    'Ubuntu': {
        $root_user = 'root'
        $root_group = 'root'
    }
    default: {
    }
}

# INCLUDE CLASSES HERE
include roles_profiles::roles::bitbar_devicepool

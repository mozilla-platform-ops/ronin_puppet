##################################################
#### MOCK CLASSES WHICH SHOULD NOT TESTED HERE
# class kitchen_template2(
#   Hash $config = {},
# ) {
#   notice( 'mocked class ==> kitchen_template::foobar' )
# }

# import is deprecated :(
# we can't create a module that does this as it can't set global scope variables
# TLDR: individual profile modules should set these, vs using globals
# copy paste from ../manifests/site.pp
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

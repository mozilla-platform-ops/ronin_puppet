# Ronin Puppet
#### The masterless puppet collection
[![Build Status](https://travis-ci.com/mozilla-platform-ops/ronin_puppet.svg?branch=master)](https://travis-ci.com/mozilla-platform-ops/ronin_puppet)

## How-To

### Run from a development branch

1. Checkout your branch. Either:

    a. Ask run-puppet to checkout your branch

        i. Set a variable for your branch and repo

        ```shell
        PUPPET_REPO=https://github.com/yourfork/ronin_puppet.git
        PUPPET_BRANCH=dev-branch-name
        ```
        
        ii. Run the puppet wrapper script
        *This will check out the specified branch and repo.*

        ```shell
        sudo run-puppet.sh
        ```
        
    b. or checkout a branch in the puppet working directory

        ```shell
        cd /etc/puppet/environments/production/code/
        git remote add yourfork https://github.com/yourfork/ronin_puppet.git
        git fetch yourfork
        git checkout -tb targetbranch yourfork/targetbranch
        ```

2. Test Changes

    a. Make changes locally *(Optional)*

    b. Commit changes to the remote repo *(Optional)*

    c.  Run puppet

    ```shell
    $ /usr/local/bin/run-puppet.sh
    Already up to date.
    INFO	 -> Using Puppetfile '/etc/puppet/environments/production/code/Puppetfile'
    Notice: Compiled catalog for [fqdn] in environment production in 1.03 seconds
    Notice: Applied catalog in 10.26 seconds
    ```

    *You can run puppet directly also, but you must specify the module directories like run-puppet.sh does.*

        ```
        puppet apply --modulepath=/etc/puppet/environments/production/code/modules:/etc/puppet/environments/production/r10k_modules --hiera_config=/etc/puppet/environments/production/code/hiera.yaml /etc/puppet/environments/production/code/manifests/
        ```

### Set or create a role (node type)

1. Create a role in modules/roles_profiles/manifests/roles/
*The profiles define settings and modules to apply to the role.*

2. Set the role name in /etc/puppet_role
*run-puppet.sh copies this string into manifests/nodes/nodes.pp*

3. Run puppet on the machine to apply the role.

```
/usr/local/bin/run-puppet.sh
# OR
puppet apply --modulepath=./modules/:../r10k_modules/ --hiera_config=./hiera.yaml ./manifests/
```

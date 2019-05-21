## r10k modules directory

This directory stores snapshots of third party puppet modules and is managed with the r10k utility.

### Updating modules
This will force update all r10k modules as defined in the Puppetfile.
```
$ r10k puppetfile install --moduledir=./r10k_modules -v --force
```

After updating, commit changes to git and push.

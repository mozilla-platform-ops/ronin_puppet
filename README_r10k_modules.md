## r10k modules directory

This directory stores snapshots of third party puppet modules and is managed with the r10k utility.

### Adding new modules

1. Add them to the Puppetfile and run the update command (see below).
2. Check that all dependencies are installed (see below).
3. If any are missing, add to the Puppetfile and start this process over.

#### Detecting missing dependencies

```bash
puppet module list --tree --modulepath=./r10k_modules
```

### Re-installing modules

This will force install all r10k modules as defined in the Puppetfile.

```bash
r10k puppetfile install --moduledir=./r10k_modules -v --force
```

After installing, commit changes to git and push.

### Updating modules

Uses https://github.com/rnelson0/puppet-generate-puppetfile.

```bash
gem install generate-puppetfile
generate-puppetfile -p Puppetfile
# update Puppetfile with output

# reinstall (copied from step above)
r10k puppetfile install --moduledir=./r10k_modules -v --force

# commit
```

### Github Review Visibility

The '.gitattributes' file sets files in the 'r10k_modules' directory to hidden by default as the folder is/should be managed automatically.

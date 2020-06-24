# YAML Inventory

This module includes a yaml plugin for bolt. This allows you to compose
multiple yaml files into a single bolt inventory file.

## Usage

### Resolve Reference

The resolve reference plugin can be used to load data from multiple files into
a central bolt inventory file.

#### Parameters

- `filepath`: The path to the yaml file. Relative paths are resolved in relation to the Bolt project directory

## Examples
For example, to break the inventory file into multiple files based on groups.


```yaml
---
# inventory.yaml
version: 2
groups:
  - _plugin: yaml
    filepath: inventory.d/first_group.yaml
  - _plugin: yaml
    filepath: invenotry.d/second_group.yaml
```

```yaml
---
# inventory.d/first_group.yaml
name: first_group
targets:
  - one.example.com
  - two.example.com
```

```yaml
---
# inventory.d/second_group.yaml
name: second_group
targets:
  - three.example.com
  - four.example.com
```


For example, to load user specific credentials into the inventory file.

```yaml
---
# inventory.yaml
targets:
  - example.com
config:
  ssh:
    _plugin: yaml
    filepath: ~/.my_bolt_credentials.yaml
```

```yaml
# ~/.my_bolt_credentials.yaml
user: me
password: hunter2
```

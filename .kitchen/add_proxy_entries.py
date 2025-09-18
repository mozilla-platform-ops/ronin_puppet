#!/usr/bin/env python3
import sys
from ruamel.yaml import YAML

yaml = YAML()
yaml.indent(mapping=2, sequence=4, offset=2)
yaml.default_flow_style = False

with open(sys.argv[1]) as f:
    data = yaml.load(f)
    provisioner = data.get('provisioner', {})
    # set https_proxy, http_proxy, and no_proxy if they are not set
    if 'https_proxy' not in provisioner:
        provisioner['https_proxy'] = 'http://host.docker.internal:8123'
    if 'http_proxy' not in provisioner:
        provisioner['http_proxy'] = 'http://host.docker.internal:8123'
    if 'no_proxy' not in provisioner:
        provisioner['no_proxy'] = 'localhost,127.0.0.1'
    data['provisioner'] = provisioner

import io
buf = io.StringIO()
yaml.dump(data, buf)
output = buf.getvalue()

# Remove single blank lines between mapping keys
lines = output.splitlines()
new_lines = []
for i, line in enumerate(lines):
    if line.strip() == "" and i > 0 and i < len(lines) - 1:
        # Only skip blank lines between two indented lines
        if lines[i-1].startswith("  ") and lines[i+1].startswith("  "):
            continue
    new_lines.append(line)
output = "\n".join(new_lines)

with open(sys.argv[1], 'w') as f:
    f.write(output)

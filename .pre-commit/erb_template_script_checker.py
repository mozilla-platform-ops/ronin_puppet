#!/usr/bin/env python3
# filepath: .pre-commit/erb_template_script_checker.py

import subprocess
import sys
import os
import tempfile
from pathlib import Path

def render_erb(template_path, fake_data_path=None):
    with open(template_path, 'r') as f:
        content = f.read()
    # Replace all ERB tags with FAKE_STRING
    import re
    return re.sub(r'<%.*?%>', 'FAKE_STRING', content, flags=re.DOTALL)

def check_bash_syntax(script_content):
    with tempfile.NamedTemporaryFile('w', suffix='.sh', delete=False) as tmp:
        tmp.write(script_content)
        tmp_path = tmp.name
    try:
        result = subprocess.run(
            ['/bin/bash', '-n', tmp_path],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(f"Bash syntax error in {tmp_path}:\n{result.stderr}", file=sys.stderr)
            return False
        return True
    finally:
        os.unlink(tmp_path)

def check_powershell_syntax(script_content):
    with tempfile.NamedTemporaryFile('w', suffix='.ps1', delete=False) as tmp:
        tmp.write(script_content)
        tmp_path = tmp.name
    try:
        # pwsh -NoProfile -Command { <file> }
        result = subprocess.run(
            ['pwsh', '-NoProfile', '-Command', f'. "{tmp_path}"'],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(f"PowerShell syntax error in {tmp_path}:\n{result.stderr}", file=sys.stderr)
            return False
        return True
    finally:
        os.unlink(tmp_path)

def main():
    failed = False
    for file_path in sys.argv[1:]:
        path = Path(file_path)
        if path.suffixes[-2:] == ['.sh', '.erb']:
            print(f"Checking Bash ERB template: {file_path}")
            rendered = render_erb(file_path)
            if rendered is None or not check_bash_syntax(rendered):
                failed = True
        # TODO: re-enable ps1 scanning
        # - current issue: powershell does more advanced syntax checking than bash syntax checking
        #  - detects if path is bad... unsure how to make this technique work.
        #
        # elif path.suffixes[-2:] == ['.ps1', '.erb']:
        #     print(f"Checking PowerShell ERB template: {file_path}")
        #     rendered = render_erb(file_path)
        #     if rendered is None or not check_powershell_syntax(rendered):
        #         print(f"PowerShell ERB template failed: {file_path}")
        #         print(f"rendered content:\n{rendered}")
        #         failed = True
        else:
            #print(f"Skipping unsupported file: {file_path}")
            pass
    if failed:
        sys.exit(1)

if __name__ == "__main__":
    main()

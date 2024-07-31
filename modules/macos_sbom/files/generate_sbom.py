import subprocess
import json
import os
import html
import sys

LOG_FILE = "/var/sbom/generate_sbom.log"

def log_message(message):
    with open(LOG_FILE, 'a') as log_file:
        log_file.write(message + '\n')

def get_installed_software():
    try:
        log_message("Fetching installed software...")
        result = subprocess.run(['/usr/sbin/system_profiler', 'SPApplicationsDataType', '-json'], capture_output=True, text=True, check=True, timeout=60)
        log_message(f"Installed software fetched successfully: {result}")
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        log_message(f"Error while fetching installed software: {e}")
        return {}
    except subprocess.TimeoutExpired:
        log_message("Timeout while fetching installed software")
        return {}

def get_binaries_in_usr_local_bin():
    binaries = []
    binaries_path = "/usr/local/bin"
    if os.path.isdir(binaries_path):
        for item in os.listdir(binaries_path):
            item_path = os.path.join(binaries_path, item)
            if os.path.isfile(item_path) and os.access(item_path, os.X_OK):
                try:
                    version_flags = ['--version', '-v', '-V']
                    version_info = "Unknown version"
                    for flag in version_flags:
                        try:
                            version_result = subprocess.run([item_path, flag], capture_output=True, text=True, check=True, timeout=5)
                            version_info = version_result.stdout.split('\n')[0]
                            break
                        except subprocess.CalledProcessError as e:
                            log_message(f"Error getting version with flag {flag} for {item}: {e}")
                            continue
                        except subprocess.TimeoutExpired as e:
                            log_message(f"Timeout getting version with flag {flag} for {item}: {e}")
                            continue
                except Exception as e:
                    log_message(f"Error getting version for {item}: {e}")
                    version_info = "Unknown version"

                binaries.append({
                    "name": item,
                    "version": version_info,
                    "path": item_path
                })
    return binaries

def get_pip_packages():
    try:
        log_message("Fetching pip packages...")
        result = subprocess.run(['pip3', 'list', '--format=json'], capture_output=True, text=True, check=True, timeout=60)
        log_message(f"Pip packages fetched successfully: {result}")
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        log_message(f"Error while fetching pip packages: {e}")
        return []
    except subprocess.TimeoutExpired:
        log_message("Timeout while fetching pip packages")
        return []

def generate_sbom(applications, binaries, pip_packages):
    sbom = {
        "sbom_version": "1.0",
        "macOS_version": "14",
        "software": sorted(applications.get('SPApplicationsDataType', []), key=lambda x: x.get('_name', '').lower()),
        "binaries": binaries,
        "pip_packages": pip_packages
    }
    log_message(f"SBOM generated successfully: {sbom}")
    return sbom

def save_sbom_to_html_file(sbom, filename="/var/sbom/sbom.html"):
    try:
        with open(filename, 'w') as file:
            file.write(f"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Software Bill of Materials (SBOM)</title>
<style>
    body {{ font-family: Arial, sans-serif; margin: 20px; }}
    h1 {{ color: #333; }}
    table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
    table, th, td {{ border: 1px solid #ddd; }}
    th, td {{ padding: 8px; text-align: left; }}
    th {{ background-color: #f4f4f4; }}
    tr:nth-child(even) {{ background-color: #f9f9f9; }}
</style>
</head>
<body>
<h1>Software Bill of Materials (SBOM)</h1>
<p><strong>SBOM Version:</strong> {sbom['sbom_version']}</p>
<p><strong>macOS Version:</strong> {sbom['macOS_version']}</p>

<h2>Installed Applications</h2>
<table>
    <tr>
        <th>Name</th>
        <th>Version</th>
        <th>Path</th>
    </tr>
""")

            for software in sbom["software"]:
                file.write("<tr>")
                file.write(f"<td>{html.escape(software.get('_name', 'Unknown'))}</td>")
                file.write(f"<td>{html.escape(software.get('version', 'Unknown'))}</td>")
                file.write(f"<td>{html.escape(software.get('path', 'Unknown'))}</td>")
                file.write("</tr>")

            file.write("""
</table>

<h2>Binaries in /usr/local/bin</h2>
<table>
    <tr>
        <th>Name</th>
        <th>Version</th>
        <th>Path</th>
    </tr>
""")

            for binary in sbom["binaries"]:
                file.write("<tr>")
                file.write(f"<td>{html.escape(binary['name'])}</td>")
                file.write(f"<td>{html.escape(binary['version'])}</td>")
                file.write(f"<td>{html.escape(binary['path'])}</td>")
                file.write("</tr>")

            file.write("""
</table>

<h2>Installed Pip Packages</h2>
<table>
    <tr>
        <th>Name</th>
        <th>Version</th>
    </tr>
""")

            for package in sbom["pip_packages"]:
                file.write("<tr>")
                file.write(f"<td>{html.escape(package['name'])}</td>")
                file.write(f"<td>{html.escape(package['version'])}</td>")
                file.write("</tr>")

            file.write("""
</table>
</body>
</html>
""")
        log_message(f"SBOM saved to {filename}")
    except Exception as e:
        log_message(f"Error saving SBOM to HTML file: {e}")
        sys.exit(1)

def main():
    try:
        log_message("Starting SBOM generation...")
        applications = get_installed_software()
        binaries = get_binaries_in_usr_local_bin()
        pip_packages = get_pip_packages()
        sbom = generate_sbom(applications, binaries, pip_packages)
        save_sbom_to_html_file(sbom)
        log_message("SBOM generation completed successfully.")
    except Exception as e:
        log_message(f"Error during SBOM generation: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

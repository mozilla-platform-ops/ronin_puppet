import subprocess
import json
import os
import html
import sys

LOG_DIR = "/var/sbom"
LOG_FILE = f"{LOG_DIR}/generate_sbom.log"

def ensure_log_directory():
    if not os.path.exists(LOG_DIR):
        os.makedirs(LOG_DIR, exist_ok=True)

def log_message(message):
    ensure_log_directory()
    with open(LOG_FILE, 'a') as log_file:
        log_file.write(message + '\n')

def get_macos_version():
    try:
        log_message("Fetching macOS version...")
        result = subprocess.run(['/usr/sbin/system_profiler', 'SPSoftwareDataType'], capture_output=True, text=True, check=True, timeout=60)
        for line in result.stdout.split('\n'):
            if 'System Version' in line:
                version = line.split(':')[-1].strip()
                log_message(f"macOS version found: {version}")
                return version
    except subprocess.CalledProcessError as e:
        log_message(f"Error while fetching macOS version: {e}")
    except subprocess.TimeoutExpired:
        log_message("Timeout while fetching macOS version")
    return "Unknown version"

def get_installed_software():
    try:
        log_message("Fetching installed software...")
        result = subprocess.run(['/usr/sbin/system_profiler', 'SPApplicationsDataType', '-json'], capture_output=True, text=True, check=True, timeout=60)
        log_message("Installed software fetched successfully")
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
        log_message("Pip packages fetched successfully")
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        log_message(f"Error while fetching pip packages: {e}")
        return []
    except subprocess.TimeoutExpired:
        log_message("Timeout while fetching pip packages")
        return []

def generate_sbom(applications, binaries, pip_packages, macos_version):
    sbom = {
        "sbom_version": "1.0",
        "macOS_version": macos_version,
        "software": sorted(applications.get('SPApplicationsDataType', []), key=lambda x: x.get('_name', '').lower()),
        "binaries": binaries,
        "pip_packages": pip_packages
    }
    log_message("SBOM generated successfully")
    return sbom

def save_sbom_to_md_file(sbom, filename="/var/sbom/sbom.md"):
    try:
        with open(filename, 'w') as file:
            file.write(f"# Software Bill of Materials (SBOM)\n")
            file.write(f"**SBOM Version:** {sbom['sbom_version']}\n")
            file.write(f"**macOS Version:** {sbom['macOS_version']}\n")
            file.write(f"\n## Installed Applications\n")
            file.write(f"| Name | Version | Path |\n")
            file.write(f"|------|---------|------|\n")

            for software in sbom["software"]:
                file.write(f"| {html.escape(software.get('_name', 'Unknown'))} | {html.escape(software.get('version', 'Unknown'))} | {html.escape(software.get('path', 'Unknown'))} |\n")

            file.write(f"\n## Binaries in /usr/local/bin\n")
            file.write(f"| Name | Version | Path |\n")
            file.write(f"|------|---------|------|\n")

            for binary in sbom["binaries"]:
                file.write(f"| {html.escape(binary['name'])} | {html.escape(binary['version'])} | {html.escape(binary['path'])} |\n")

            file.write(f"\n## Installed Pip Packages\n")
            file.write(f"| Name | Version |\n")
            file.write(f"|------|---------|\n")

            for package in sbom["pip_packages"]:
                file.write(f"| {html.escape(package['name'])} | {html.escape(package['version'])} |\n")

        log_message(f"SBOM saved to {filename}")
    except Exception as e:
        log_message(f"Error saving SBOM to Markdown file: {e}")
        sys.exit(1)

def main():
    try:
        log_message("Starting SBOM generation...")
        macos_version = get_macos_version()
        applications = get_installed_software()
        binaries = get_binaries_in_usr_local_bin()
        pip_packages = get_pip_packages()
        sbom = generate_sbom(applications, binaries, pip_packages, macos_version)
        save_sbom_to_md_file(sbom)
        log_message("SBOM generation completed successfully")
    except Exception as e:
        log_message(f"Error during SBOM generation: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

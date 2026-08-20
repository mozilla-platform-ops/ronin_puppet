#!/usr/local/bin/python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
"""Generate a CycloneDX 1.6 SBOM for a macOS CI worker.

Runs at the end of every Puppet run and writes two files to /var/sbom:

  sbom.cdx.json    Full CycloneDX 1.6 document. Rewritten only when the
                   software inventory actually changes, so its mtime tells
                   you when this host last drifted.
  fingerprint.json Small, always-rewritten summary (hostname, role,
                   sbom_sha256, counts). Cheap for a collector to poll.

Because the fleet is Puppet-managed from a role and VM images are immutable,
many hosts share a byte-identical inventory. The sbom_sha256 in the
fingerprint collapses the fleet to a handful of distinct software states: a
host whose hash differs from its role's usual hash has drifted.

Inventory sources, cheapest first:
  * /var/db/receipts/*.plist  the real macOS installer receipt database,
    read directly with plistlib rather than shelling out to pkgutil per pkg
  * pip, for each Puppet-managed interpreter
  * /usr/local/bin, hashed, with code-signing authority for Mach-O files
  * Homebrew Cellar/Caskroom, if any survived macos_utils::uninstall_homebrew
  * Xcode and the command line tools

Deliberately does NOT use `system_profiler SPApplicationsDataType`: it costs
30-60s per run and reports app bundles, which is the least interesting part
of a CI worker's surface.

Never exits non-zero. A broken SBOM must not fail a Puppet run or take a
worker out of production.
"""

from __future__ import annotations

import glob
import hashlib
import json
import os
import plistlib
import stat
import subprocess
import sys
import time
import uuid

GENERATOR_NAME = "ronin-puppet-macos-sbom"
GENERATOR_VERSION = "2.0.0"

SBOM_DIR = "/var/sbom"
CDX_PATH = os.path.join(SBOM_DIR, "sbom.cdx.json")
FINGERPRINT_PATH = os.path.join(SBOM_DIR, "fingerprint.json")
LOG_PATH = os.path.join(SBOM_DIR, "generate_sbom.log")

RECEIPTS_DIR = "/var/db/receipts"
ROLE_FILE = "/etc/puppet_role"
LOCAL_BIN = "/usr/local/bin"
BREW_PREFIXES = ("/opt/homebrew", "/usr/local")

# World-readable so a collector can scrape over SSH without root.
FILE_MODE = 0o644

# Don't hash anything enormous; nothing in /usr/local/bin should be.
MAX_HASH_BYTES = 256 * 1024 * 1024

# Interpreters to ask for a pip list. /usr/bin/python3 is intentionally
# absent: on a host missing the command line tools it can trigger the
# developer-tools install prompt.
PYTHON_CANDIDATES = (
    "/usr/local/bin/python3",
    "/usr/local/bin/python3.11",
    "/usr/local/bin/python3.9",
    "/usr/local/bin/python3.8",
    "/usr/local/bin/python3.7",
)

# Binaries known to print a version and exit, with the argv each one wants.
# livelog, taskcluster-proxy and start-worker are deliberately absent: they
# ignore --version and start serving, which on a live worker means hanging the
# Puppet run and binding a port. Anything not listed here is identified by
# SHA-256 and code-signing authority, which is what an SBOM wants anyway.
VERSION_COMMANDS = {
    "generic-worker": ["--version"],
    "taskcluster": ["version"],
}

MACHO_MAGIC = (
    b"\xcf\xfa\xed\xfe",  # 64-bit little endian
    b"\xce\xfa\xed\xfe",  # 32-bit little endian
    b"\xfe\xed\xfa\xcf",  # 64-bit big endian
    b"\xfe\xed\xfa\xce",  # 32-bit big endian
    b"\xca\xfe\xba\xbe",  # universal binary
)

_log_lines = []


def log(message):
    """Buffer a log line. Flushed once, truncating, at exit."""
    _log_lines.append("%s %s" % (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), message))


def flush_log():
    """Write the log fresh each run so it cannot grow without bound."""
    try:
        os.makedirs(SBOM_DIR, exist_ok=True)
        with open(LOG_PATH, "w") as handle:
            handle.write("\n".join(_log_lines) + "\n")
        os.chmod(LOG_PATH, FILE_MODE)
    except OSError as err:
        sys.stderr.write("generate_sbom: could not write %s: %s\n" % (LOG_PATH, err))


def run(argv, timeout=30):
    """Run a command, returning (stdout, stderr) as text. Never raises."""
    try:
        proc = subprocess.run(
            argv,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
    except (OSError, subprocess.SubprocessError) as err:
        log("command failed %s: %s" % (argv[0], err))
        return "", ""
    return (
        (proc.stdout or b"").decode("utf-8", "replace"),
        (proc.stderr or b"").decode("utf-8", "replace"),
    )


def prop(name, value):
    return {"name": name, "value": str(value)}


def sha256_file(path):
    """SHA-256 a file, or None if it is unreadable or absurdly large."""
    try:
        if os.path.getsize(path) > MAX_HASH_BYTES:
            return None
        digest = hashlib.sha256()
        with open(path, "rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()
    except OSError:
        return None


def is_macho(path):
    try:
        with open(path, "rb") as handle:
            return handle.read(4) in MACHO_MAGIC
    except OSError:
        return False


def read_first_line(path):
    try:
        with open(path) as handle:
            return handle.readline().strip()
    except OSError:
        return ""


def host_facts():
    """Identity and security posture of the host itself."""
    product, _ = run(["/usr/bin/sw_vers", "-productName"])
    version, _ = run(["/usr/bin/sw_vers", "-productVersion"])
    build, _ = run(["/usr/bin/sw_vers", "-buildVersion"])
    model, _ = run(["/usr/sbin/sysctl", "-n", "hw.model"])
    # SIP state is a recurring source of confusion on this fleet and is
    # never safe to infer, so record what the host actually reports.
    sip, _ = run(["/usr/bin/csrutil", "status"])

    model = model.strip()
    return {
        "hostname": os.uname().nodename,
        "product": product.strip() or "macOS",
        "version": version.strip() or "unknown",
        "build": build.strip(),
        "arch": os.uname().machine,
        "model": model,
        # VirtualMac* is how this fleet distinguishes a tart guest from metal.
        "is_vm": model.startswith("VirtualMac"),
        "sip": sip.strip().replace("System Integrity Protection status: ", "").rstrip("."),
        "role": read_first_line(ROLE_FILE),
    }


def os_component(facts):
    props = [
        prop("macos:build", facts["build"]),
        prop("macos:arch", facts["arch"]),
        prop("macos:hw_model", facts["model"]),
        prop("macos:is_vm", "true" if facts["is_vm"] else "false"),
        prop("macos:sip", facts["sip"]),
    ]
    return [{
        "type": "operating-system",
        "bom-ref": "os:macos",
        "name": facts["product"],
        "version": facts["version"],
        "properties": [p for p in props if p["value"]],
    }]


def receipt_components():
    """Installer receipts: the authoritative record of what was installed."""
    components = []
    for path in sorted(glob.glob(os.path.join(RECEIPTS_DIR, "*.plist"))):
        try:
            with open(path, "rb") as handle:
                receipt = plistlib.load(handle)
        except (OSError, ValueError):
            log("unreadable receipt: %s" % path)
            continue

        identifier = receipt.get("PackageIdentifier") or os.path.basename(path)[:-6]
        version = str(receipt.get("PackageVersion") or "unknown")
        props = []
        # Install dates are recorded but deliberately excluded from the
        # fingerprint: a same-version reinstall is not a software change.
        installed = receipt.get("InstallDate")
        if installed is not None:
            props.append(prop("macos:install_date", installed))
        prefix = receipt.get("InstallPrefixPath")
        if prefix:
            props.append(prop("macos:install_prefix", prefix))

        components.append({
            "type": "application",
            "bom-ref": "pkg:%s" % identifier,
            "name": identifier,
            "version": version,
            "purl": "pkg:generic/%s@%s" % (identifier, version),
            "properties": props,
        })
    log("receipts: %d packages" % len(components))
    return components


def python_interpreters():
    """Distinct, real interpreters worth asking for a pip list."""
    found = []
    seen = set()
    for candidate in (sys.executable,) + PYTHON_CANDIDATES:
        if not candidate:
            continue
        real = os.path.realpath(candidate)
        if real in seen or not os.path.isfile(real) or not os.access(real, os.X_OK):
            continue
        seen.add(real)
        found.append(candidate)
    return found


def pip_components():
    components = []
    for interpreter in python_interpreters():
        stdout, _ = run([interpreter, "-m", "pip", "list", "--format=json"], timeout=120)
        if not stdout.strip():
            log("no pip output from %s" % interpreter)
            continue
        try:
            packages = json.loads(stdout)
        except ValueError:
            log("unparseable pip output from %s" % interpreter)
            continue
        for package in packages:
            name = package.get("name")
            version = str(package.get("version") or "unknown")
            if not name:
                continue
            components.append({
                "type": "library",
                "bom-ref": "pip:%s:%s" % (interpreter, name),
                "name": name,
                "version": version,
                "purl": "pkg:pypi/%s@%s" % (name.lower(), version),
                "properties": [prop("python:interpreter", interpreter)],
            })
        log("pip: %d packages from %s" % (len(packages), interpreter))
    return components


def plausible_version(text):
    """Reject usage text and error output masquerading as a version string."""
    if not text or len(text) > 200:
        return False
    lowered = text.lower()
    if any(marker in lowered for marker in ("error", "unknown flag", "usage")):
        return False
    return any(char.isdigit() for char in text)


def signing_authority(path):
    """Leading codesign authority, e.g. 'Developer ID Application: ...'."""
    _, stderr = run(["/usr/bin/codesign", "-dv", "--verbose=2", path], timeout=15)
    for line in stderr.splitlines():
        if line.startswith("Authority="):
            return line.split("=", 1)[1].strip()
        if "code object is not signed" in line:
            return "unsigned"
    return ""


def local_bin_components():
    """Hash /usr/local/bin. This is where the worker binaries live."""
    components = []
    try:
        entries = sorted(os.listdir(LOCAL_BIN))
    except OSError:
        log("no %s" % LOCAL_BIN)
        return components

    for entry in entries:
        path = os.path.join(LOCAL_BIN, entry)
        try:
            mode = os.stat(path).st_mode
        except OSError:
            continue
        if not stat.S_ISREG(mode) or not os.access(path, os.X_OK):
            continue

        props = []
        real = os.path.realpath(path)
        if real != path:
            props.append(prop("file:target", real))

        version = ""
        version_args = VERSION_COMMANDS.get(entry)
        if version_args:
            stdout, stderr = run([path] + version_args, timeout=5)
            reported = (stdout.strip() or stderr.strip()).splitlines()
            if reported and plausible_version(reported[0].strip()):
                version = reported[0].strip()

        if is_macho(path):
            authority = signing_authority(path)
            if authority:
                props.append(prop("macos:codesign_authority", authority))

        component = {
            "type": "file",
            "bom-ref": "file:%s" % path,
            "name": path,
            "properties": props,
        }
        if version:
            component["version"] = version
        digest = sha256_file(path)
        if digest:
            component["hashes"] = [{"alg": "SHA-256", "content": digest}]
        components.append(component)

    log("%s: %d executables" % (LOCAL_BIN, len(components)))
    return components


def brew_components():
    """Homebrew should be absent, but confirm rather than assume."""
    components = []
    for prefix in BREW_PREFIXES:
        for kind, subdir in (("formula", "Cellar"), ("cask", "Caskroom")):
            root = os.path.join(prefix, subdir)
            if not os.path.isdir(root):
                continue
            try:
                names = sorted(os.listdir(root))
            except OSError:
                continue
            for name in names:
                try:
                    versions = sorted(os.listdir(os.path.join(root, name)))
                except OSError:
                    continue
                for version in versions:
                    if version.startswith("."):
                        continue
                    components.append({
                        "type": "application",
                        "bom-ref": "brew:%s:%s:%s" % (kind, name, version),
                        "name": name,
                        "version": version,
                        "purl": "pkg:brew/%s@%s" % (name, version),
                        "properties": [prop("brew:kind", kind), prop("brew:prefix", prefix)],
                    })
    if components:
        log("homebrew: %d entries (expected none on this fleet)" % len(components))
    return components


def xcode_components():
    components = []
    selected, _ = run(["/usr/bin/xcode-select", "-p"], timeout=15)
    selected = selected.strip()

    for app in sorted(glob.glob("/Applications/Xcode*.app")):
        plist_path = os.path.join(app, "Contents", "version.plist")
        try:
            with open(plist_path, "rb") as handle:
                info = plistlib.load(handle)
        except (OSError, ValueError):
            continue
        version = str(info.get("CFBundleShortVersionString") or "unknown")
        props = [prop("xcode:path", app)]
        build = info.get("ProductBuildVersion")
        if build:
            props.append(prop("xcode:build", str(build)))
        if selected and selected.startswith(app):
            props.append(prop("xcode:selected", "true"))
        components.append({
            "type": "application",
            "bom-ref": "xcode:%s" % app,
            "name": os.path.basename(app),
            "version": version,
            # Give Xcode a purl so it is visible to scanners rather than
            # showing up as an unidentified application.
            "purl": "pkg:generic/xcode@%s" % version,
            "properties": props,
        })

    log("xcode: %d installs, selected=%s" % (len(components), selected or "none"))
    return components


def fingerprint(components):
    """Stable digest over component identity only.

    Excludes timestamps, install dates and the serial number so that two
    hosts built from the same role produce the same hash, and so that a
    single host's hash changes only when its software actually changes.
    """
    identities = []
    for component in components:
        digest = ""
        for entry in component.get("hashes", []):
            if entry.get("alg") == "SHA-256":
                digest = entry.get("content", "")
                break
        identities.append("|".join([
            component.get("type", ""),
            component.get("name", ""),
            component.get("version", "") or "",
            component.get("purl", "") or "",
            digest,
        ]))
    identities.sort()
    return hashlib.sha256("\n".join(identities).encode("utf-8")).hexdigest()


def build_document(facts, components, sbom_sha):
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        # Derived from the content hash so it is stable across runs.
        "serialNumber": "urn:uuid:%s" % uuid.UUID(hex=sbom_sha[:32]),
        "version": 1,
        "metadata": {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "tools": {
                "components": [{
                    "type": "application",
                    "name": GENERATOR_NAME,
                    "version": GENERATOR_VERSION,
                }],
            },
            "component": {
                "type": "device",
                "bom-ref": "host:%s" % facts["hostname"],
                "name": facts["hostname"],
                "version": facts["version"],
                "properties": [p for p in [
                    prop("relops:puppet_role", facts["role"]),
                    prop("relops:hw_model", facts["model"]),
                    prop("relops:is_vm", "true" if facts["is_vm"] else "false"),
                    prop("relops:sip", facts["sip"]),
                    prop("relops:sbom_sha256", sbom_sha),
                ] if p["value"]],
            },
        },
        "components": components,
    }


def write_json(path, payload):
    """Write atomically, then make world-readable for SSH-based collection."""
    temp = "%s.tmp" % path
    with open(temp, "w") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True, default=str)
        handle.write("\n")
    os.chmod(temp, FILE_MODE)
    os.replace(temp, path)


def existing_sha():
    try:
        with open(CDX_PATH) as handle:
            document = json.load(handle)
    except (OSError, ValueError):
        return None
    for entry in document.get("metadata", {}).get("component", {}).get("properties", []):
        if entry.get("name") == "relops:sbom_sha256":
            return entry.get("value")
    return None


def main():
    started = time.time()
    log("starting %s %s" % (GENERATOR_NAME, GENERATOR_VERSION))

    os.makedirs(SBOM_DIR, exist_ok=True)
    facts = host_facts()
    log("host=%s role=%s macos=%s arch=%s vm=%s sip=%s" % (
        facts["hostname"], facts["role"] or "unknown", facts["version"],
        facts["arch"], facts["is_vm"], facts["sip"] or "unknown",
    ))

    components = []
    for name, collector in (
        ("os", lambda: os_component(facts)),
        ("receipts", receipt_components),
        ("xcode", xcode_components),
        ("pip", pip_components),
        ("local_bin", local_bin_components),
        ("homebrew", brew_components),
    ):
        try:
            components.extend(collector())
        except Exception as err:  # a bad collector must not lose the whole SBOM
            log("collector %s failed: %s" % (name, err))

    components.sort(key=lambda c: (
        c.get("type", ""), c.get("name", ""), c.get("version", "") or "",
    ))

    sbom_sha = fingerprint(components)
    previous = existing_sha()

    if previous == sbom_sha:
        log("inventory unchanged (%s), leaving %s as-is" % (sbom_sha[:12], CDX_PATH))
    else:
        write_json(CDX_PATH, build_document(facts, components, sbom_sha))
        log("inventory changed %s -> %s, wrote %s" % (
            (previous or "none")[:12], sbom_sha[:12], CDX_PATH,
        ))

    write_json(FINGERPRINT_PATH, {
        "schema_version": 1,
        "generator": GENERATOR_NAME,
        "generator_version": GENERATOR_VERSION,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "hostname": facts["hostname"],
        "puppet_role": facts["role"],
        "macos_version": facts["version"],
        "macos_build": facts["build"],
        "arch": facts["arch"],
        "hw_model": facts["model"],
        "is_vm": facts["is_vm"],
        "sip": facts["sip"],
        "sbom_sha256": sbom_sha,
        "component_count": len(components),
        "sbom_path": CDX_PATH,
        "changed": previous != sbom_sha,
    })

    log("done: %d components in %.1fs" % (len(components), time.time() - started))


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        # An SBOM is never worth failing a Puppet run over.
        log("fatal: %s" % err)
    finally:
        flush_log()
    sys.exit(0)

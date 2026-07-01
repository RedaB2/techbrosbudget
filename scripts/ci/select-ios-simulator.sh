#!/usr/bin/env bash
set -euo pipefail

python3 - "$@" <<'PY'
import json
import re
import subprocess
import sys

preferred_names = [
    "iPhone 17 Pro Max",
    "iPhone 17 Pro",
    "iPhone 17",
    "iPhone 16 Pro Max",
    "iPhone 16 Pro",
    "iPhone 16",
    "iPhone 15 Pro Max",
    "iPhone 15 Pro",
    "iPhone 15",
]

def parse_version(value):
    parts = [int(part) for part in re.findall(r"\d+", value or "")]
    return tuple(parts) if parts else None

requested_version = sys.argv[1] if len(sys.argv) > 1 else ""
requested_key = parse_version(requested_version)

raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
data = json.loads(raw)

devices = []
available_versions = set()
for runtime, runtime_devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue

    version_parts = [int(part) for part in re.findall(r"\d+", runtime)]
    version_key = tuple(version_parts)
    available_versions.add(version_key)
    if requested_key and version_key != requested_key:
        continue

    for device in runtime_devices:
        name = device.get("name", "")
        if device.get("isAvailable") and name.startswith("iPhone"):
            devices.append((version_key, name, device.get("udid")))

if not devices:
    if requested_version:
        versions = ", ".join(".".join(map(str, version)) for version in sorted(available_versions))
        sys.stderr.write(
            f"No available iPhone simulator found for iOS {requested_version}. "
            f"Available iOS runtimes: {versions or 'none'}.\n"
        )
    else:
        sys.stderr.write("No available iPhone simulator found.\n")
    sys.exit(1)

for preferred_name in preferred_names:
    matches = [device for device in devices if device[1] == preferred_name]
    if matches:
        matches.sort(reverse=True)
        print(matches[0][2])
        sys.exit(0)

devices.sort(reverse=True)
print(devices[0][2])
PY

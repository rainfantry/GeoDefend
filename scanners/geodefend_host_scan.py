"""
GeoDefend Host Persistence Scanner for Windows.

Scans the local machine for common malware persistence mechanisms:
  - Suspicious Run / RunOnce registry keys
  - Startup folder contents
  - Scheduled tasks with suspicious actions
  - Suspicious services
  - WMI persistence subscriptions
  - Active network listeners on known malware ports

This is a defensive verification tool. It does not modify the system.

Run as the user you want to check (HKCU) or as Administrator (HKLM / services).
"""
import os
import re
import sys
import subprocess

# Patterns that flag a persistence entry as suspicious
SUSPICIOUS_PATTERNS = [
    re.compile(r"powershell\.exe\s+.*-WindowStyle\s+Hidden", re.IGNORECASE),
    re.compile(r"powershell\.exe\s+.*-ExecutionPolicy\s+Bypass", re.IGNORECASE),
    re.compile(r"-ep\s+bypass", re.IGNORECASE),
    re.compile(r"wscript\.exe\s+.*\.vbs", re.IGNORECASE),
    re.compile(r"cscript\.exe\s+.*\.vbs", re.IGNORECASE),
    re.compile(r"cmd\.exe\s+/c\s+.*>", re.IGNORECASE),
    re.compile(r"mshta\.exe", re.IGNORECASE),
    re.compile(r"regsvr32\.exe\s+(/s\s+)?[^\s]*\\(?!system32|syswow64)", re.IGNORECASE),
    re.compile(r"rundll32\.exe\s+(/d\s+)?[^\s]*\\(?!system32|syswow64)", re.IGNORECASE),
    re.compile(r"certutil\.exe\s+-(decode|urlcache|split|encode)", re.IGNORECASE),
    re.compile(r"\\AppData\\Roaming\\.*\.(ps1|vbs|bat|cmd|js)"),
    re.compile(r"\\Temp\\.*\.(ps1|vbs|bat|cmd|js|exe)", re.IGNORECASE),
    re.compile(r"svc\.py|r\.vbs|ghost\.ps1|stealer|exodus|atomic|marsalek", re.IGNORECASE),
]

# Names that mimic legitimate Windows services
MIMICRY_NAMES = [
    "svchost_update",
    "systemupdate",
    "winupdate",
    "adobe update",
]

# Explicitly trusted paths / names
TRUSTED_PATHS = [
    r"%windir%\system32\SecurityHealthSystray.exe",
    r"%windir%\system32\rundll32.exe",
    r"%windir%\syswow64\rundll32.exe",
]

TRUSTED_WMI_NAMES = {
    "SCM Event Log Filter",
    "SCM Event Log Consumer",
    "BVTConsumer",
    "KernelLogger",
}

KNOWN_MALWARE_PORTS = {
    "113.30.148.162",
    "46.120.173.142",
    "marsalek.cy",
}


def is_suspicious(text):
    if not text:
        return False, ""
    # Trust explicit known-good paths
    for trusted in TRUSTED_PATHS:
        if trusted.lower() in text.lower():
            return False, ""
    for pattern in SUSPICIOUS_PATTERNS:
        if pattern.search(text):
            return True, f"matched pattern: {pattern.pattern[:40]}"
    lower = text.lower()
    for mimic in MIMICRY_NAMES:
        if mimic in lower:
            return True, f"mimicry name: {mimic}"
    return False, ""


def is_trusted_wmi(name_or_line):
    if not name_or_line:
        return False
    lower = name_or_line.lower()
    return any(trusted.lower() in lower for trusted in TRUSTED_WMI_NAMES)

def check_registry_run(hive, path):
    findings = []
    try:
        result = subprocess.run(
            ["reg", "query", path],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            return findings
        for line in result.stdout.splitlines():
            line = line.strip()
            if not line or line.startswith("HKEY") or line.startswith("!"):
                continue
            parts = line.split(None, 2)
            if len(parts) < 3:
                continue
            name, _, value = parts[0], parts[1], parts[2]
            sus, reason = is_suspicious(value)
            if sus:
                findings.append({
                    "type": "Registry Run",
                    "hive": hive,
                    "path": path,
                    "name": name,
                    "value": value,
                    "reason": reason,
                })
    except Exception as e:
        findings.append({
            "type": "Error",
            "hive": hive,
            "path": path,
            "name": "",
            "value": str(e),
            "reason": "failed to query registry",
        })
    return findings


def check_startup_folder():
    findings = []
    startup_path = os.path.expandvars(
        r"%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
    )
    if not os.path.exists(startup_path):
        return findings
    for entry in os.listdir(startup_path):
        full = os.path.join(startup_path, entry)
        sus, reason = is_suspicious(full)
        if sus or entry.lower().endswith((".ps1", ".vbs", ".bat", ".cmd", ".js")):
            findings.append({
                "type": "Startup Folder",
                "hive": "User",
                "path": startup_path,
                "name": entry,
                "value": full,
                "reason": reason or "script file in startup folder",
            })
    return findings


def check_scheduled_tasks():
    findings = []
    try:
        result = subprocess.run(
            ["schtasks", "/query", "/fo", "LIST", "/v"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            return findings
        current_task = ""
        current_action = ""
        for line in result.stdout.splitlines():
            if line.startswith("TaskName:"):
                current_task = line.split(":", 1)[1].strip()
                current_action = ""
            elif line.strip().startswith("Task To Run:"):
                current_action = line.split(":", 1)[1].strip()
                sus, reason = is_suspicious(current_action)
                if sus:
                    findings.append({
                        "type": "Scheduled Task",
                        "hive": "System/User",
                        "path": "Task Scheduler",
                        "name": current_task,
                        "value": current_action,
                        "reason": reason,
                    })
    except Exception as e:
        findings.append({
            "type": "Error",
            "hive": "System/User",
            "path": "Task Scheduler",
            "name": "",
            "value": str(e),
            "reason": "failed to query scheduled tasks",
        })
    return findings


def check_services():
    findings = []
    try:
        result = subprocess.run(
            ["sc", "query", "type=", "service", "state=", "all"],
            capture_output=True,
            text=True,
            timeout=15,
            errors="ignore",
        )
        if result.returncode != 0 or not result.stdout:
            return findings
        service_names = []
        for line in result.stdout.splitlines():
            if line.strip().startswith("SERVICE_NAME:"):
                service_names.append(line.split(":", 1)[1].strip())

        for svc in service_names:
            try:
                detail = subprocess.run(
                    ["sc", "qc", svc],
                    capture_output=True,
                    text=True,
                    timeout=5,
                    errors="ignore",
                )
                if detail.returncode != 0 or not detail.stdout:
                    continue
                binary_path = ""
                display_name = ""
                for dline in detail.stdout.splitlines():
                    if dline.strip().startswith("BINARY_PATH_NAME"):
                        binary_path = dline.split(":", 1)[1].strip()
                    if dline.strip().startswith("DISPLAY_NAME"):
                        display_name = dline.split(":", 1)[1].strip()

                combined = f"{svc} {display_name} {binary_path}"
                sus, reason = is_suspicious(combined)
                if sus:
                    findings.append({
                        "type": "Service",
                        "hive": "System",
                        "path": "Services",
                        "name": svc,
                        "value": binary_path or display_name,
                        "reason": reason,
                    })
            except Exception:
                continue
    except Exception as e:
        findings.append({
            "type": "Error",
            "hive": "System",
            "path": "Services",
            "name": "",
            "value": str(e),
            "reason": "failed to query services",
        })
    return findings


def check_wmi_subscriptions():
    findings = []
    try:
        result = subprocess.run(
            [
                "powershell.exe",
                "-Command",
                "Get-WmiObject -Class __EventFilter -Namespace root\\subscription | Select-Object Name, Query; "
                "Get-WmiObject -Class CommandLineEventConsumer -Namespace root\\subscription | Select-Object Name, CommandLineTemplate",
            ],
            capture_output=True,
            text=True,
            timeout=15,
            errors="ignore",
        )
        if result.returncode == 0 and result.stdout.strip():
            lines = result.stdout.strip().splitlines()
            suspicious_lines = []
            for line in lines:
                # Skip header/separator lines
                if not line.strip() or line.strip().startswith("Name") or line.strip().startswith("-"):
                    continue
                # Skip trusted WMI names anywhere in the line
                if is_trusted_wmi(line):
                    continue
                suspicious_lines.append(line)
            if suspicious_lines:
                findings.append({
                    "type": "WMI Subscription",
                    "hive": "System",
                    "path": "root\\subscription",
                    "name": "WMI event consumer/filter",
                    "value": "\n".join(suspicious_lines)[:200],
                    "reason": "WMI persistence subscription present — review manually",
                })
    except Exception as e:
        findings.append({
            "type": "Error",
            "hive": "System",
            "path": "WMI",
            "name": "",
            "value": str(e),
            "reason": "failed to query WMI subscriptions",
        })
    return findings


def check_network_listeners():
    findings = []
    try:
        result = subprocess.run(
            ["netstat", "-ano"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            return findings
        for line in result.stdout.splitlines():
            for indicator in KNOWN_MALWARE_PORTS:
                if indicator in line:
                    findings.append({
                        "type": "Network Connection",
                        "hive": "N/A",
                        "path": "Network",
                        "name": indicator,
                        "value": line.strip(),
                        "reason": "connection to known malware infrastructure",
                    })
    except Exception as e:
        findings.append({
            "type": "Error",
            "hive": "N/A",
            "path": "Network",
            "name": "",
            "value": str(e),
            "reason": "failed to query network connections",
        })
    return findings


def main():
    print("[*] GeoDefend Host Persistence Scanner")
    print("[*] Scanning for malware persistence artifacts...")
    print()

    findings = []
    findings.extend(check_registry_run("HKCU", r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run"))
    findings.extend(check_registry_run("HKCU", r"HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce"))
    findings.extend(check_registry_run("HKLM", r"HKLM\Software\Microsoft\Windows\CurrentVersion\Run"))
    findings.extend(check_registry_run("HKLM", r"HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce"))
    findings.extend(check_startup_folder())
    findings.extend(check_scheduled_tasks())
    findings.extend(check_services())
    findings.extend(check_wmi_subscriptions())
    findings.extend(check_network_listeners())

    # Separate errors from real findings
    errors = [f for f in findings if f["type"] == "Error"]
    real_findings = [f for f in findings if f["type"] != "Error"]

    if not real_findings and not errors:
        print("[+] PASS — No suspicious persistence artifacts found.")
        return 0

    if real_findings:
        print(f"[-] FAIL — {len(real_findings)} suspicious persistence artifact(s) found:")
        print()
        for f in real_findings:
            print(f"  Type:   {f['type']}")
            print(f"  Hive:   {f['hive']}")
            print(f"  Name:   {f['name']}")
            print(f"  Value:  {f['value'][:160]}")
            print(f"  Reason: {f['reason']}")
            print()

    if errors:
        print("[!] WARN — Some checks could not complete:")
        for e in errors:
            print(f"  {e['path']}: {e['value']}")
        print()

    return 1 if real_findings else 0


if __name__ == "__main__":
    sys.exit(main())

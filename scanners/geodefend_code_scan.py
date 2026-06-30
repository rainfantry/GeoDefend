"""
GeoDefend Code Scanner — static backdoor/malware indicator detection.

Scans Python files for suspicious indicators: external C2, wallet injection,
process injection APIs, persistence mechanisms, hidden PowerShell execution,
startup folder access, WMI persistence, browser killing, real browser paths,
self-restart, silent pip installs, obfuscated payloads, and low-level network
libraries.

Usage:
    python scanners/geodefend_code_scan.py [target_directory]

Exit code 0 = clean
Exit code 1 = suspicious indicators found
"""
import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Patterns that indicate real malware / backdoor behavior
DANGEROUS_PATTERNS = {
    "external_ip_or_domain": {
        "pattern": re.compile(r"https?://(?:[0-9]{1,3}\.){3}[0-9]{1,3}|https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"),
        "allowed": [
            "http://127.0.0.1", "http://localhost",
            "https://github.com", "https://rainfantry.github.io",
            "https://example.com", "https://test.local"
        ],
        "description": "External IP/domain in URL (possible real C2)",
    },
    "wallet_injection": {
        "pattern": re.compile(r"inject_exodus|inject_atomic|app\.asar|Exodus|Atomic Wallet"),
        "allowed": [],
        "description": "Crypto wallet injection payload",
    },
    "process_injection_apis": {
        "pattern": re.compile(r"CreateRemoteThread|VirtualAllocEx|WriteProcessMemory|NtMapViewOfSection|LoadLibraryA\("),
        "allowed": [],
        "description": "Process injection APIs",
    },
    "persistence_registry": {
        "pattern": re.compile(r"CurrentVersion\\Run|RunOnce|HKEY_|winreg\.CreateKey|winreg\.SetValueEx|TaskScheduler|Schedule\.Service|schtasks"),
        "allowed": [],
        "description": "Registry / scheduled task persistence",
    },
    "powershell_hidden_execution": {
        "pattern": re.compile(r"powershell\.exe.*-WindowStyle Hidden|powershell.*-ExecutionPolicy Bypass|-ep bypass|Start-Process.*-WindowStyle Hidden"),
        "allowed": [],
        "description": "Hidden PowerShell execution (common persistence / malware delivery)",
    },
    "startup_folder_access": {
        "pattern": re.compile(r"Start Menu\\Programs\\Startup|AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Startup"),
        "allowed": [],
        "description": "Windows startup folder access (persistence)",
    },
    "wmi_persistence": {
        "pattern": re.compile(r"Win32_StartupCommand|__EventFilter|CommandLineEventConsumer|__InstanceModificationEvent"),
        "allowed": [],
        "description": "WMI persistence primitives",
    },
    "browser_kill": {
        "pattern": re.compile(r"taskkill.*chrome|taskkill.*firefox|os\.kill.*chrome|terminate.*browser"),
        "allowed": [],
        "description": "Browser process termination (unlocks real cookie DBs)",
    },
    "real_browser_paths": {
        "pattern": re.compile(r"Local\\\\Google\\\\Chrome|Roaming\\\\Mozilla\\\\Firefox|Local\\\\Microsoft\\\\Edge|Login Data|cookies\.sqlite|key4\.db"),
        "allowed": [],
        "description": "Real browser profile paths",
    },
    "self_restart": {
        "pattern": re.compile(r"sys\.exit\(0\).*os\.path\.exists|subprocess\.call\(.*sys\.argv|os\.execl.*sys\.executable"),
        "allowed": [],
        "description": "Self-restart / anti-reinfection logic",
    },
    "silent_pip_install": {
        "pattern": re.compile(r"subprocess\.run\(.*pip|os\.system\(.*pip|pip install"),
        "allowed": ["pip install -r requirements.txt"],
        "description": "Silent pip install of dependencies",
    },
    "obfuscated_payload": {
        "pattern": re.compile(r"Fernet\(|base64\.b64decode\(.*exec|eval\(|exec\(__import__|marshal\.loads"),
        "allowed": [],
        "description": "Obfuscated payload execution",
    },
    "external_network_lib": {
        "pattern": re.compile(r"import socket|import urllib|from urllib|import ftplib|import smtplib|import http\.client"),
        "allowed": [],
        "description": "Low-level external network libraries",
    },
}

def scan_file(path):
    findings = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()

    for line_no, line in enumerate(lines, 1):
        for name, rule in DANGEROUS_PATTERNS.items():
            if rule["pattern"].search(line):
                # Check allowed exceptions
                hit_text = rule["pattern"].search(line).group(0)
                if any(a in line for a in rule["allowed"]):
                    continue
                findings.append({
                    "file": os.path.basename(path),
                    "line": line_no,
                    "indicator": name,
                    "description": rule["description"],
                    "text": line.strip(),
                    "match": hit_text,
                })
    return findings

def main():
    target = sys.argv[1] if len(sys.argv) > 1 else REPO_ROOT
    target = os.path.abspath(target)

    print("[*] GeoDefend Code Scanner")
    print("[*] Target:", target)
    print("[*] Rules:", len(DANGEROUS_PATTERNS))
    print()

    all_findings = []
    scanned = 0
    for root, dirs, files in os.walk(target):
        # Skip venv and reports
        dirs[:] = [d for d in dirs if d not in ("venv", "reports", ".git", "__pycache__", "node_modules")]
        for fname in files:
            if fname.endswith(".py") and fname not in ("geodefend_code_scan.py", "geodefend_host_scan.py"):
                path = os.path.join(root, fname)
                scanned += 1
                findings = scan_file(path)
                all_findings.extend(findings)

    print(f"[*] Scanned {scanned} Python files")
    print()

    if not all_findings:
        print("[+] PASS — No suspicious indicators found.")
        print("[+] Target appears to contain only safe, synthetic, local-only demonstration code.")
        return 0

    print("[-] FAIL — Suspicious indicators found:")
    print()
    for f in all_findings:
        print(f"  File:    {f['file']}:{f['line']}")
        print(f"  Rule:    {f['indicator']}")
        print(f"  Why:     {f['description']}")
        print(f"  Match:   {f['match']}")
        print(f"  Line:    {f['text'][:120]}")
        print()
    return 1

if __name__ == "__main__":
    sys.exit(main())

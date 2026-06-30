#!/usr/bin/env python3
"""
GeoDefend convenience wrapper.

Runs both the code scanner and the host persistence scanner.

Usage:
    python scan.py [target_directory]

If no target directory is given, scans the current repository.
"""
import os
import sys
import subprocess

ROOT = os.path.dirname(os.path.abspath(__file__))

def run_scanner(script, *args):
    cmd = [sys.executable, os.path.join(ROOT, "scanners", script)] + list(args)
    print("\n" + "=" * 60)
    print(f"Running {script}")
    print("=" * 60)
    result = subprocess.run(cmd)
    return result.returncode

def main():
    target = sys.argv[1] if len(sys.argv) > 1 else ROOT
    code_exit = run_scanner("geodefend_code_scan.py", target)
    host_exit = run_scanner("geodefend_host_scan.py")

    print("\n" + "=" * 60)
    print("GeoDefend Scan Summary")
    print("=" * 60)
    print(f"Code scan:  {'PASS' if code_exit == 0 else 'FAIL'} ({code_exit})")
    print(f"Host scan:  {'PASS' if host_exit == 0 else 'FAIL'} ({host_exit})")

    return 0 if code_exit == 0 and host_exit == 0 else 1

if __name__ == "__main__":
    sys.exit(main())

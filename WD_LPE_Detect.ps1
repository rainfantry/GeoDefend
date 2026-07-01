# ============================================================
# WD_LPE_Detect.ps1
# Blue team detection script - BlueHammer/RedSun/UnDefend IOCs
# + 22DIV infostealer malware IOCs (wallet hijack, persistence, C2)
# George Wu | For educational/defensive use only
# Run as Administrator for full results
# ============================================================

$logpath = "$env:USERPROFILE\Desktop\WD_LPE_Detect_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$findings = @()
$alertcount = 0
$structured = @()

function Write-Alert {
    param([string]$msg, [string]$colour = "Red", [string]$level = "ALERT")
    $line = "[$level] $msg"
    Write-Host $line -ForegroundColor $colour
    $script:findings += $line
    $script:structured += [PSCustomObject]@{ level = $level; message = $msg; time = (Get-Date -Format 'HH:mm:ss') }
    if ($level -eq "ALERT") { $script:alertcount++ }
}

function Write-Info {
    param([string]$msg)
    $line = "[INFO] $msg"
    Write-Host $line -ForegroundColor Cyan
    $script:findings += $line
    $script:structured += [PSCustomObject]@{ level = "INFO"; message = $msg; time = (Get-Date -Format 'HH:mm:ss') }
}

function Write-OK {
    param([string]$msg)
    $line = "[OK]   $msg"
    Write-Host $line -ForegroundColor Green
    $script:findings += $line
    $script:structured += [PSCustomObject]@{ level = "OK"; message = $msg; time = (Get-Date -Format 'HH:mm:ss') }
}

function Write-Section {
    param([string]$title)
    $line = "`n====== $title ======"
    Write-Host $line -ForegroundColor White
    $script:findings += $line
}

# ============================================================
# BANNER
# ============================================================
Clear-Host
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "   WD LPE + INFOSTEALER IOC DETECTION SCRIPT    " -ForegroundColor Cyan
Write-Host "   BlueHammer / RedSun / UnDefend / 22DIV       " -ForegroundColor Cyan
Write-Host "   Blue team use only. Run as Administrator.     " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

$findings += "WD LPE + Infostealer Detection Script | Run: $(Get-Date)"
$findings += "Host: $env:COMPUTERNAME | User: $env:USERNAME"

# ============================================================
# CHECK 1 - DEFENDER PLATFORM VERSION
# ============================================================
Write-Section "CHECK 1: DEFENDER PLATFORM VERSION"

try {
    $mpstatus = Get-MpComputerStatus -ErrorAction Stop
    $ver = $mpstatus.AMProductVersion
    $findings += "Defender Platform Version: $ver"

    $minver = [version]"4.18.26050.3011"
    $curver = [version]$ver

    if ($curver -ge $minver) {
        Write-OK "Defender platform version $ver meets minimum ($minver)"
    } else {
        Write-Alert "Defender platform $ver is BELOW minimum safe version $minver" "Red" "ALERT"
        Write-Alert "Vulnerable to BlueHammer class exploits - UPDATE IMMEDIATELY" "Red" "ALERT"
    }

    $defage = (Get-Date) - $mpstatus.AntivirusSignatureLastUpdated
    $agehours = [math]::Round($defage.TotalHours, 1)

    if ($defage.TotalHours -gt 24) {
        Write-Alert "Defender definitions last updated $agehours hours ago" "Yellow" "WARN"
    } else {
        Write-OK "Definitions current ($agehours hours old)"
    }

    if (-not $mpstatus.RealTimeProtectionEnabled) {
        Write-Alert "REAL-TIME PROTECTION IS DISABLED" "Red" "ALERT"
    } else {
        Write-OK "Real-time protection enabled"
    }

} catch {
    Write-Alert "Could not query Defender status - is it disabled or tampered?" "Red" "ALERT"
}

# ============================================================
# CHECK 2 - SUSPICIOUS PARENT/CHILD PROCESS RELATIONSHIPS
# WD spawning a shell is the primary IOC
# ============================================================
Write-Section "CHECK 2: DEFENDER SPAWNING SUSPICIOUS CHILD PROCESSES"

$suspiciouschildren = @("cmd.exe","powershell.exe","pwsh.exe","wscript.exe","cscript.exe","mshta.exe","rundll32.exe","regsvr32.exe")
$wdprocesses = @("MsMpEng.exe","MpDefenderCoreService.exe","MpCmdRun.exe","NisSrv.exe")

try {
    $allprocs = Get-WmiObject Win32_Process -ErrorAction Stop
    $foundSuspicious = $false

    foreach ($wdproc in $wdprocesses) {
        $wdinst = $allprocs | Where-Object { $_.Name -eq $wdproc }
        foreach ($wd in $wdinst) {
            $children = $allprocs | Where-Object { $_.ParentProcessId -eq $wd.ProcessId }
            foreach ($child in $children) {
                if ($suspiciouschildren -contains $child.Name) {
                    Write-Alert "$wdproc (PID $($wd.ProcessId)) spawned $($child.Name) (PID $($child.ProcessId))" "Red" "ALERT"
                    Write-Alert "PRIMARY INDICATOR OF WD LPE EXPLOITATION" "Red" "ALERT"
                    try {
                        Write-Alert "  Command line: $($child.CommandLine)" "Red" "ALERT"
                    } catch {}
                    $foundSuspicious = $true
                }
            }
        }
    }

    if (-not $foundSuspicious) {
        Write-OK "No WD to shell spawning detected"
    }

} catch {
    Write-Alert "Could not enumerate process tree: $_" "Yellow" "WARN"
}

# ============================================================
# CHECK 3 - UNEXPECTED SYSTEM-OWNED SHELL PROCESSES
# ============================================================
Write-Section "CHECK 3: UNEXPECTED SYSTEM-OWNED SHELL PROCESSES"

$shellprocs = @("cmd.exe","powershell.exe","pwsh.exe")
$legitimateparents = @("services.exe","svchost.exe","wininit.exe","smss.exe")

try {
    $allprocs2 = Get-WmiObject Win32_Process -ErrorAction Stop
    $foundshell = $false

    foreach ($shell in $shellprocs) {
        $instances = $allprocs2 | Where-Object { $_.Name -eq $shell }
        foreach ($inst in $instances) {
            try {
                $owner = $inst.GetOwner()
                if ($owner -and $owner.User -eq "SYSTEM") {
                    $parent = $allprocs2 | Where-Object { $_.ProcessId -eq $inst.ParentProcessId }
                    $parentname = if ($parent) { $parent.Name } else { "UNKNOWN" }
                    if ($legitimateparents -notcontains $parentname) {
                        Write-Alert "$shell (PID $($inst.ProcessId)) running as SYSTEM, parent: $parentname" "Red" "ALERT"
                        try { Write-Alert "  CMD: $($inst.CommandLine)" "Red" "ALERT" } catch {}
                        $foundshell = $true
                    }
                }
            } catch {}
        }
    }

    if (-not $foundshell) {
        Write-OK "No unexpected SYSTEM-owned shells detected"
    }

} catch {
    Write-Alert "Could not check shell process ownership: $_" "Yellow" "WARN"
}

# ============================================================
# CHECK 4 - POST-EXPLOIT RECON COMMANDS IN EVENT LOG
# ============================================================
Write-Section "CHECK 4: POST-EXPLOIT RECON COMMANDS IN EVENT LOG"

try {
    $auditpol = auditpol /get /subcategory:"Process Creation" 2>$null
    if ($auditpol -match "No Auditing") {
        Write-Alert "Process creation auditing is DISABLED - cannot detect recon commands" "Yellow" "WARN"
        Write-Info "Enable with: auditpol /set /subcategory:`"Process Creation`" /success:enable"
    } else {
        Write-OK "Process creation auditing enabled"

        $recentevents = Get-WinEvent -FilterHashtable @{
            LogName   = "Security"
            Id        = 4688
            StartTime = (Get-Date).AddHours(-24)
        } -ErrorAction SilentlyContinue

        $recon_cmds = @("whoami","cmdkey","net group","net localgroup","nltest","ipconfig /all","arp -a")
        $found_recon = @()

        foreach ($evt in $recentevents) {
            $msg = $evt.Message
            foreach ($cmd in $recon_cmds) {
                if ($msg -match [regex]::Escape($cmd)) {
                    $found_recon += "[$($evt.TimeCreated)] $cmd detected"
                }
            }
        }

        if ($found_recon.Count -ge 3) {
            Write-Alert "Multiple recon commands detected - possible post-exploit enumeration" "Red" "ALERT"
            $found_recon | ForEach-Object { Write-Alert $_ "Yellow" "WARN" }
        } elseif ($found_recon.Count -gt 0) {
            Write-Info "Some recon commands in log ($($found_recon.Count) hit(s)) - below threshold"
            $found_recon | ForEach-Object { Write-Info $_ }
        } else {
            Write-OK "No suspicious recon command sequences in last 24h"
        }
    }
} catch {
    Write-Info "Event log check requires Administrator access: $_"
}

# ============================================================
# CHECK 5 - VSS SHADOW COPY ACTIVITY
# ============================================================
Write-Section "CHECK 5: VSS SHADOW COPY ACTIVITY"

try {
    $shadows = Get-WmiObject Win32_ShadowCopy -ErrorAction Stop
    if ($shadows) {
        Write-Info "$($shadows.Count) shadow copy/copies exist - baseline these"
        foreach ($s in $shadows) {
            Write-Info "  $($s.DeviceObject) | Created: $($s.InstallDate)"
        }
    } else {
        Write-OK "No shadow copies present"
    }
} catch {
    Write-Info "Could not query VSS (requires Administrator): $_"
}

# ============================================================
# CHECK 6 - DEFENDER DEFINITION UPDATE HEALTH
# UnDefend silently blocks definition updates
# ============================================================
Write-Section "CHECK 6: DEFENDER DEFINITION UPDATE HEALTH"

try {
    $mpstatus3 = Get-MpComputerStatus -ErrorAction Stop
    Write-Info "Signature version: $($mpstatus3.AntivirusSignatureVersion)"
    Write-Info "Last updated: $($mpstatus3.AntivirusSignatureLastUpdated)"

    $defupdpath = "C:\ProgramData\Microsoft\Windows Defender\Definition Updates"
    if (Test-Path $defupdpath) {
        $subdirs = Get-ChildItem $defupdpath -Directory -ErrorAction SilentlyContinue
        Write-Info "Definition update directories: $($subdirs.Count)"
        $recent = $subdirs | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-2) }
        if (-not $recent) {
            Write-Alert "No recent activity in Definition Updates dir - possible UnDefend activity" "Yellow" "WARN"
        } else {
            Write-OK "Recent definition update activity confirmed"
        }
    }
} catch {
    Write-Info "Could not check definition health: $_"
}

# ============================================================
# CHECK 7 - INFOSTEALER MALWARE IOCs
# Detects persistence, C2, and wallet-hijack indicators
# from the 22DIV analyzed dropper family
# ============================================================
Write-Section "CHECK 7: INFOSTEALER MALWARE IOCs"

$malware_iocs = @{
    "C2_DOMAINS" = @("marsalek.cy")
    "C2_IPS" = @("113.30.148.162", "46.120.173.142")
    "WALLET_ENDPOINTS" = @("/exodus", "/atomic")
    "PERSISTENCE_MARKERS" = @("HD Realtek Audio Player", "ghost.ps1", "svc.py", "r.vbs")
    "PROCESS_NAMES" = @("exodus.exe", "Atomic Wallet.exe")
}

# 7a - Hosts file hijacking / known C2 domains
$hostsfile = "$env:SystemRoot\System32\drivers\etc\hosts"
if (Test-Path $hostsfile) {
    $hostcontent = Get-Content $hostsfile -Raw
    foreach ($domain in $malware_iocs["C2_DOMAINS"]) {
        if ($hostcontent -match $domain) {
            Write-Alert "hosts file references known malware C2 domain: $domain" "Red" "ALERT"
        }
    }
}

# 7b - Network connections to known C2 IPs
$netconns = @()
try {
    $netconns = Get-NetTCPConnection -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State
} catch {}

$found_c2_conn = $false
foreach ($conn in $netconns) {
    if ($malware_iocs["C2_IPS"] -contains $conn.RemoteAddress) {
        Write-Alert "Active connection to known malware IP: $($conn.RemoteAddress):$($conn.RemotePort) [$($conn.State)]" "Red" "ALERT"
        $found_c2_conn = $true
    }
}
if (-not $found_c2_conn) {
    Write-OK "No active connections to known infostealer C2 IPs"
}

# 7c - Persistence: Run keys
$run_paths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)
$found_persistence = $false
foreach ($rp in $run_paths) {
    if (Test-Path $rp) {
        $values = Get-ItemProperty $rp -ErrorAction SilentlyContinue
        foreach ($marker in $malware_iocs["PERSISTENCE_MARKERS"]) {
            $matches = $values.PSObject.Properties | Where-Object { $_.Value -and $_.Value.ToString() -match $marker }
            foreach ($m in $matches) {
                Write-Alert "Suspicious Run key '$($m.Name)' in $rp -> $($m.Value)" "Red" "ALERT"
                $found_persistence = $true
            }
        }
        # Also flag hidden PowerShell execution
        $hidden = $values.PSObject.Properties | Where-Object { $_.Value -and $_.Value.ToString() -match "powershell\.exe.*-WindowStyle\s+Hidden" }
        foreach ($h in $hidden) {
            Write-Alert "Hidden PowerShell persistence '$($h.Name)' in $rp" "Red" "ALERT"
            $found_persistence = $true
        }
    }
}
if (-not $found_persistence) {
    Write-OK "No infostealer persistence markers in Run/RunOnce keys"
}

# 7d - Startup folder scripts
$startup_path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
if (Test-Path $startup_path) {
    $startup_files = Get-ChildItem $startup_path -ErrorAction SilentlyContinue
    $sus_startup = $startup_files | Where-Object { $_.Extension -in @(".ps1",".vbs",".bat",".cmd",".js") }
    if ($sus_startup) {
        foreach ($sf in $sus_startup) {
            Write-Alert "Suspicious startup script: $($sf.FullName)" "Red" "ALERT"
        }
    } else {
        Write-OK "No suspicious scripts in user startup folder"
    }
}

# 7e - File system markers
$marker_paths = @(
    "$env:LOCALAPPDATA\HD Realtek Audio Player",
    "$env:TEMP\svc.py",
    "$env:TEMP\r.vbs",
    "$env:APPDATA\Microsoft\Windows\ghost.ps1"
)
$found_marker = $false
foreach ($mp in $marker_paths) {
    if (Test-Path $mp) {
        Write-Alert "Infostealer artifact found: $mp" "Red" "ALERT"
        $found_marker = $true
    }
}
if (-not $found_marker) {
    Write-OK "No infostealer file-system artifacts detected"
}

# 7f - Wallet app.asar tampering
$wallet_paths = @(
    "$env:LOCALAPPDATA\exodus\app-*\resources\app.asar",
    "$env:LOCALAPPDATA\atomic\app-*\resources\app.asar"
)
$found_wallet_tamper = $false
foreach ($wp in $wallet_paths) {
    $matches = Get-Item $wp -ErrorAction SilentlyContinue
    foreach ($m in $matches) {
        # A quick heuristic: app.asar should be large; tiny replacement is suspicious
        if ($m.Length -lt 100KB) {
            Write-Alert "Possible tampered wallet app.asar (tiny size): $($m.FullName) ($($m.Length) bytes)" "Red" "ALERT"
            $found_wallet_tamper = $true
        }
    }
}
if (-not $found_wallet_tamper) {
    Write-OK "No wallet app.asar tampering detected"
}

# 7g - Suspicious processes
$found_susp_proc = $false
try {
    $procs = Get-Process -ErrorAction SilentlyContinue | Select-Object Name, Path
    foreach ($pn in $malware_iocs["PROCESS_NAMES"]) {
        $matches = $procs | Where-Object { $_.Name -eq $pn -or $_.Path -match $pn }
        if ($matches) {
            Write-Info "Wallet process running: $pn (expected if user has wallet installed)"
        }
    }
} catch {}

# ============================================================
# SUMMARY
# ============================================================
Write-Section "SCAN COMPLETE"

if ($alertcount -eq 0) {
    Write-Host "`n[RESULT] NO CRITICAL INDICATORS DETECTED - System appears clean" -ForegroundColor Green
    $findings += "`n[RESULT] CLEAN"
} else {
    Write-Host "`n[RESULT] $alertcount ALERT(S) DETECTED - INVESTIGATE IMMEDIATELY" -ForegroundColor Red
    $findings += "`n[RESULT] $alertcount ALERTS DETECTED"
}

try {
    $findings | Out-File -FilePath $logpath -Encoding UTF8
    Write-Host "`nLog saved to: $logpath" -ForegroundColor Cyan
} catch {
    Write-Host "Could not save log: $_" -ForegroundColor Yellow
}

# JSON output for GeoDefend mobile app
$jsonpath = "$env:USERPROFILE\Desktop\WD_LPE_Latest.json"
$payload = [PSCustomObject]@{
    timestamp  = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    host       = $env:COMPUTERNAME
    user       = $env:USERNAME
    alertCount = $alertcount
    findings   = $structured
}
$payload | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonpath -Encoding UTF8
Write-Host "JSON saved to: $jsonpath" -ForegroundColor Cyan

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

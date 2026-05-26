# ============================================================
# WD_LPE_Detect.ps1
# Blue team detection script - BlueHammer/RedSun/UnDefend IOCs
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
# ADDED LINE - REPEAT FOR INFO + OK FUNCTION REPLACING LEVEL WITH (INFO) & (OK) RESPECTIVELY
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
Write-Host "   WD LPE DETECTION SCRIPT - George Wu           " -ForegroundColor Cyan
Write-Host "   BlueHammer / RedSun / UnDefend IOC Scanner    " -ForegroundColor Cyan
Write-Host "   Blue team use only. Run as Administrator.     " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

$findings += "WD LPE Detection Script | Run: $(Get-Date)"
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
# Huntress documented this exact sequence post-exploit
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

<#
.SYNOPSIS
Stops an Android Emulator without letting "adb emu kill" hang forever.

.EXAMPLE
.\scripts\Stop-AndroidEmulator.ps1

.EXAMPLE
.\scripts\Stop-AndroidEmulator.ps1 -Serial emulator-5556 -TimeoutSeconds 5

.EXAMPLE
.\scripts\Stop-AndroidEmulator.ps1 -WatchSeconds 0
#>
[CmdletBinding()]
param(
    [string]$Serial = "emulator-5554",
    [string]$AvdName = "UneBil_API35",
    [ValidateRange(1, 120)]
    [int]$TimeoutSeconds = 8,
    [ValidateRange(0, 120)]
    [int]$WatchSeconds = 10,
    [switch]$SkipAdbRestart
)

$ErrorActionPreference = "Stop"

function Get-AdbPath {
    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if ($adb) {
        return $adb.Source
    }

    $sdkAdb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Test-Path -LiteralPath $sdkAdb) {
        return $sdkAdb
    }

    throw "adb.exe was not found in PATH or the default Android SDK location."
}

function Join-ProcessArguments {
    param([string[]]$ArgumentList)

    return ($ArgumentList | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        } else {
            $_
        }
    }) -join " "
}

function Invoke-ProcessWithTimeout {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$TimeoutSec = 8
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.Arguments = Join-ProcessArguments -ArgumentList $ArgumentList
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi

    [void]$process.Start()

    if (-not $process.WaitForExit($TimeoutSec * 1000)) {
        try {
            $process.Kill()
        } catch {
            Write-Warning "Timed out and could not kill process $($process.Id): $($_.Exception.Message)"
        }

        return [pscustomobject]@{
            TimedOut = $true
            ExitCode = $null
            StdOut   = ""
            StdErr   = "Timed out after $TimeoutSec second(s)."
        }
    }

    return [pscustomobject]@{
        TimedOut = $false
        ExitCode = $process.ExitCode
        StdOut   = $process.StandardOutput.ReadToEnd()
        StdErr   = $process.StandardError.ReadToEnd()
    }
}

function Get-EmulatorPorts {
    param([string]$DeviceSerial)

    if ($DeviceSerial -notmatch '^emulator-(\d+)$') {
        throw "Serial '$DeviceSerial' is not an Android Emulator serial like emulator-5554."
    }

    $consolePort = [int]$Matches[1]
    return @($consolePort, ($consolePort + 1))
}

function Get-ProcessIdsForPorts {
    param([int[]]$Ports)

    $portLookup = @{}
    foreach ($port in $Ports) {
        $portLookup[[int]$port] = $true
    }

    $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $portLookup.ContainsKey([int]$_.LocalPort) -and $_.OwningProcess -gt 0 }

    $processIds = @($connections | Select-Object -ExpandProperty OwningProcess -Unique)

    if ($processIds.Count -eq 0) {
        $netstatLines = @(netstat -ano -p tcp 2>$null)
        $netstatProcessIds = foreach ($line in $netstatLines) {
            if ($line -match '^\s*TCP\s+\S+:(\d+)\s+\S+\s+LISTENING\s+(\d+)\s*$') {
                $port = [int]$Matches[1]
                $processId = [int]$Matches[2]
                if ($portLookup.ContainsKey($port) -and $processId -gt 0) {
                    $processId
                }
            }
        }
        $processIds = @($netstatProcessIds | Sort-Object -Unique)
    }

    foreach ($processId in @($processIds)) {
        $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
        if ($processInfo -and $processInfo.ParentProcessId) {
            $parentInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($processInfo.ParentProcessId)" -ErrorAction SilentlyContinue
            if ($parentInfo -and $parentInfo.Name -in @("emulator.exe", "qemu-system-x86_64.exe", "qemu-system-i386.exe")) {
                $processIds += [int]$parentInfo.ProcessId
            }
        }
    }

    return @($processIds | Sort-Object -Unique)
}

function Get-ProcessIdsForAvd {
    param([string]$Name)

    $avdArgument = [regex]::Escape("-avd $Name")
    return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -in @("emulator.exe", "qemu-system-x86_64.exe", "qemu-system-i386.exe") -and
            $_.CommandLine -match $avdArgument
        } |
        Select-Object -ExpandProperty ProcessId -Unique)
}

function Stop-ProcessIds {
    param([int[]]$ProcessIds)

    foreach ($processId in $ProcessIds) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if (-not $process) {
            continue
        }

        Write-Host "Stopping $($process.ProcessName) PID $processId..."
        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
    }
}

function Stop-ProcessesForPorts {
    param(
        [int[]]$Ports,
        [int[]]$FallbackProcessIds = @()
    )

    $processIds = @(Get-ProcessIdsForPorts -Ports $Ports)

    if ($processIds.Count -eq 0 -and $FallbackProcessIds.Count -gt 0) {
        Write-Host "No listener found right now; using previously detected PID(s): $($FallbackProcessIds -join ', ')."
        $processIds = @($FallbackProcessIds)
    }

    if ($processIds.Count -eq 0) {
        Write-Host "No emulator/qemu listener found on ports $($Ports -join ', ')."
        return
    }

    Stop-ProcessIds -ProcessIds $processIds
}

function Wait-ForPortsReleased {
    param(
        [int[]]$Ports,
        [int]$Attempts = 5,
        [int]$StableFreeChecks = 2
    )

    $freeChecks = 0

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        Start-Sleep -Milliseconds 800
        $processIds = @(Get-ProcessIdsForPorts -Ports $Ports)

        if ($processIds.Count -eq 0) {
            $freeChecks++
            if ($freeChecks -ge $StableFreeChecks) {
                Write-Host "Emulator ports $($Ports -join ', ') are free."
                return
            }

            Write-Host "Emulator ports $($Ports -join ', ') are free; confirming..."
            continue
        }

        $freeChecks = 0
        Write-Warning "Emulator is still listening on ports $($Ports -join ', ') (PID(s): $($processIds -join ', ')). Forcing shutdown."
        Stop-ProcessesForPorts -Ports $Ports
    }

    Write-Warning "Stop attempts finished. If the emulator appears again, close the active Android Studio/Flutter run session and rerun this script."
}

function Watch-ForEmulatorRestart {
    param(
        [int[]]$Ports,
        [int]$Seconds
    )

    if ($Seconds -le 0) {
        return
    }

    $deadline = (Get-Date).AddSeconds($Seconds)
    $sawRestart = $false

    Write-Host "Watching for emulator restart for $Seconds second(s)..."

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
        $processIds = @(Get-ProcessIdsForPorts -Ports $Ports)

        if ($processIds.Count -eq 0) {
            continue
        }

        $sawRestart = $true
        Write-Warning "Emulator restarted on ports $($Ports -join ', ') (PID(s): $($processIds -join ', ')). Stopping it."
        Stop-ProcessesForPorts -Ports $Ports
    }

    if ($sawRestart) {
        Wait-ForPortsReleased -Ports $Ports -Attempts 3
    }
}

function Remove-StaleAvdLocks {
    param([string]$Name)

    if ((Get-ProcessIdsForAvd -Name $Name).Count -gt 0) {
        Write-Warning "AVD processes are still running; lock files were kept."
        return
    }

    $avdHome = if ($env:ANDROID_AVD_HOME) {
        $env:ANDROID_AVD_HOME
    } elseif (Test-Path -LiteralPath "C:\Android\avd") {
        "C:\Android\avd"
    } else {
        Join-Path $env:USERPROFILE ".android\avd"
    }
    $resolvedHome = (Resolve-Path -LiteralPath $avdHome -ErrorAction SilentlyContinue).Path
    $avdDirectory = Join-Path $resolvedHome "$Name.avd"
    $resolvedAvd = (Resolve-Path -LiteralPath $avdDirectory -ErrorAction SilentlyContinue).Path
    if (-not $resolvedHome -or -not $resolvedAvd -or
        -not $resolvedAvd.StartsWith($resolvedHome + [IO.Path]::DirectorySeparatorChar)) {
        Write-Warning "Could not verify the AVD directory; lock files were kept."
        return
    }

    foreach ($lockName in @("hardware-qemu.ini.lock", "multiinstance.lock")) {
        $lockPath = Join-Path $resolvedAvd $lockName
        if (Test-Path -LiteralPath $lockPath) {
            Remove-Item -LiteralPath $lockPath -Recurse -Force
            Write-Host "Removed stale lock: $lockPath"
        }
    }
}

$adbPath = Get-AdbPath
$ports = Get-EmulatorPorts -DeviceSerial $Serial
$initialProcessIds = @(
    @(Get-ProcessIdsForPorts -Ports $ports) +
    @(Get-ProcessIdsForAvd -Name $AvdName) |
    Sort-Object -Unique
)

if ($initialProcessIds.Count -gt 0) {
    Write-Host "Found emulator/qemu PID(s) on ports $($ports -join ', '): $($initialProcessIds -join ', ')."
}

Write-Host "Trying graceful emulator shutdown for $Serial (timeout: $TimeoutSeconds sec)..."
$killResult = Invoke-ProcessWithTimeout -FilePath $adbPath -ArgumentList @("-s", $Serial, "emu", "kill") -TimeoutSec $TimeoutSeconds

if ($killResult.TimedOut) {
    Write-Warning "adb emu kill did not respond. Falling back to process shutdown."
    Stop-ProcessesForPorts -Ports $ports -FallbackProcessIds $initialProcessIds
} elseif ($killResult.ExitCode -ne 0) {
    Write-Warning "adb emu kill failed with exit code $($killResult.ExitCode). Falling back to process shutdown."
    if ($killResult.StdErr.Trim()) {
        Write-Warning $killResult.StdErr.Trim()
    }
    Stop-ProcessesForPorts -Ports $ports -FallbackProcessIds $initialProcessIds
} else {
    Write-Host "adb emu kill completed."
}

Wait-ForPortsReleased -Ports $ports

if (-not $SkipAdbRestart) {
    Write-Host "Restarting ADB server..."
    [void](Invoke-ProcessWithTimeout -FilePath $adbPath -ArgumentList @("kill-server") -TimeoutSec 5)
    [void](Invoke-ProcessWithTimeout -FilePath $adbPath -ArgumentList @("start-server") -TimeoutSec 10)
    Wait-ForPortsReleased -Ports $ports -Attempts 3
}

Watch-ForEmulatorRestart -Ports $ports -Seconds $WatchSeconds
Remove-StaleAvdLocks -Name $AvdName

Write-Host "Done."

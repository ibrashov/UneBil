<#
.SYNOPSIS
Starts the UneBil emulator with stable graphics and waits for Android to boot.

.EXAMPLE
.\scripts\Start-AndroidEmulator.ps1

.EXAMPLE
.\scripts\Start-AndroidEmulator.ps1 -ColdBoot -RunFlutter:$false

.EXAMPLE
.\scripts\Start-AndroidEmulator.ps1 -WipeData
#>
[CmdletBinding()]
param(
    [string]$AvdName = "UneBil_API35",
    [string]$Serial = "emulator-5554",
    [ValidateSet("auto", "host", "software", "lavapipe", "swiftshader", "swangle")]
    [string]$GpuMode = "swangle",
    [ValidateRange(2048, 8192)]
    [int]$MemoryMb = 3072,
    [ValidateRange(30, 300)]
    [int]$BootTimeoutSeconds = 180,
    [switch]$ColdBoot,
    [switch]$WipeData,
    [bool]$RunFlutter = $true
)

$ErrorActionPreference = "Stop"

$sdkRoot = if ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} elseif ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
} else {
    Join-Path $env:LOCALAPPDATA "Android\Sdk"
}

$sdkRoot = (Resolve-Path -LiteralPath $sdkRoot).Path
if ($sdkRoot -match '[^\x00-\x7F]') {
    # Emulator 36.x can corrupt non-ASCII SDK paths before QEMU starts.
    $fileSystem = New-Object -ComObject Scripting.FileSystemObject
    try {
        $sdkRoot = $fileSystem.GetFolder($sdkRoot).ShortPath
    } finally {
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($fileSystem)
    }
}

$emulatorPath = Join-Path $sdkRoot "emulator\emulator.exe"
$adbPath = Join-Path $sdkRoot "platform-tools\adb.exe"
if (-not (Test-Path -LiteralPath $emulatorPath)) {
    throw "Android Emulator was not found at '$emulatorPath'."
}
if (-not (Test-Path -LiteralPath $adbPath)) {
    throw "adb.exe was not found at '$adbPath'."
}

if (-not $env:ANDROID_AVD_HOME -and (Test-Path -LiteralPath "C:\Android\avd")) {
    $env:ANDROID_AVD_HOME = "C:\Android\avd"
}
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot

$connected = (& $adbPath devices | Out-String)
if ($connected -notmatch "(?m)^$([regex]::Escape($Serial))\s+") {
    $existingAvd = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -in @("emulator.exe", "qemu-system-x86_64.exe", "qemu-system-i386.exe") -and
            $_.CommandLine -match [regex]::Escape("-avd $AvdName")
        })
    if ($existingAvd.Count -gt 0) {
        throw "A stuck $AvdName process already exists. Run .\scripts\Stop-AndroidEmulator.ps1 first."
    }

    $emulatorArguments = @(
        "-avd", $AvdName,
        "-gpu", $GpuMode,
        "-memory", $MemoryMb.ToString(),
        "-no-boot-anim"
    )
    if ($ColdBoot -or $WipeData) {
        $emulatorArguments += "-no-snapshot-load"
    }
    if ($WipeData) {
        $emulatorArguments += "-wipe-data"
    }

    Write-Host "Starting $AvdName with $GpuMode graphics and $MemoryMb MB RAM..."
    Start-Process -FilePath $emulatorPath -ArgumentList $emulatorArguments
}

$deadline = (Get-Date).AddSeconds($BootTimeoutSeconds)
do {
    Start-Sleep -Seconds 2
    $deviceList = (& $adbPath devices | Out-String)
    $deviceReady = $deviceList -match "(?m)^$([regex]::Escape($Serial))\s+device\s*$"
    $bootCompleted = if ($deviceReady) {
        (& $adbPath -s $Serial shell getprop sys.boot_completed | Out-String).Trim()
    } else {
        ""
    }
} while ($bootCompleted -ne "1" -and (Get-Date) -lt $deadline)

if ($bootCompleted -ne "1") {
    throw "Android did not finish booting within $BootTimeoutSeconds seconds."
}

Write-Host "Android is fully booted on $Serial."
if ($RunFlutter) {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    Push-Location $projectRoot
    try {
        flutter run -d $Serial --dart-define=API_BASE_URL=http://10.0.2.2:3000
    } finally {
        Pop-Location
    }
}

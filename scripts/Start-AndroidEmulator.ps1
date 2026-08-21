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

function Get-FreeDriveLetter {
    param([string[]]$Excluded = @())

    foreach ($letter in @("U", "V", "W", "T", "S", "R", "Q")) {
        if ($letter -in $Excluded) {
            continue
        }
        if (-not (Get-PSDrive -Name $letter -ErrorAction SilentlyContinue)) {
            return $letter
        }
    }
    throw "No free temporary drive letter is available for Flutter."
}

function Get-AsciiDirectoryPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ($Path -notmatch '[^\x00-\x7F]') {
        return $Path
    }
    $fileSystem = New-Object -ComObject Scripting.FileSystemObject
    try {
        $shortPath = $fileSystem.GetFolder($Path).ShortPath
    } finally {
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($fileSystem)
    }
    if ($shortPath -match '[^\x00-\x7F]') {
        throw "Windows did not provide an ASCII short path for '$Path'."
    }
    return $shortPath
}

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
    $workingDirectory = (Get-Location).Path
    $projectRoot = if (Test-Path -LiteralPath (Join-Path $workingDirectory "pubspec.yaml")) {
        $workingDirectory
    } else {
        (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    }
    $runRoot = $projectRoot
    $mappedDrives = @()
    $originalPubCacheExists = Test-Path Env:PUB_CACHE
    $originalPubCache = $env:PUB_CACHE
    $pubCacheTarget = if ($originalPubCacheExists) {
        $originalPubCache
    } else {
        Join-Path $env:LOCALAPPDATA "Pub\Cache"
    }
    $restorePackageConfig = $false
    $locationPushed = $false

    try {
        # Android build-tools 36.1 aapt cannot read an APK when any part of
        # its Windows path contains non-ASCII characters. Run Flutter through
        # temporary ASCII drive aliases while keeping the repository in place.
        if ($projectRoot -match '[^\x00-\x7F]') {
            $projectDriveLetter = Get-FreeDriveLetter
            $projectDrive = "${projectDriveLetter}:"
            $projectParent = Split-Path -Parent $projectRoot
            $projectFolderName = Split-Path -Leaf $projectRoot
            if ($projectFolderName -match '[^\x00-\x7F]') {
                throw "The project folder name must contain only ASCII characters."
            }
            $projectSubstTarget = Get-AsciiDirectoryPath $projectParent
            & subst.exe $projectDrive $projectSubstTarget
            if ($LASTEXITCODE -ne 0) {
                throw "Could not map temporary Flutter drive $projectDrive."
            }
            $mappedDrives += $projectDrive
            # Do not run at a drive root: Flutter 3.44 can emit invalid LSP
            # JSON for a workspace whose path is exactly U:\ or similar.
            $runRoot = Join-Path "$projectDrive\" $projectFolderName
            $restorePackageConfig = $true
        }

        if ($pubCacheTarget -match '[^\x00-\x7F]') {
            $excludedLetters = $mappedDrives |
                ForEach-Object { $_.Substring(0, 1) }
            $cacheDriveLetter = Get-FreeDriveLetter -Excluded $excludedLetters
            $cacheDrive = "${cacheDriveLetter}:"
            $cacheSubstTarget = Get-AsciiDirectoryPath $pubCacheTarget
            & subst.exe $cacheDrive $cacheSubstTarget
            if ($LASTEXITCODE -ne 0) {
                throw "Could not map temporary Pub cache drive $cacheDrive."
            }
            $mappedDrives += $cacheDrive
            $env:PUB_CACHE = "$cacheDrive\"
            $restorePackageConfig = $true
        }

        Push-Location $runRoot
        $locationPushed = $true

        if ($restorePackageConfig) {
            & flutter pub get --offline
            if ($LASTEXITCODE -ne 0) {
                throw "Could not prepare packages through ASCII paths."
            }
        }

        $staleDependencyFile = Join-Path `
            $runRoot `
            "build\app\intermediates\flutter\debug\flutter_build.d"
        if (Test-Path -LiteralPath $staleDependencyFile) {
            Remove-Item -LiteralPath $staleDependencyFile -Force
        }

        flutter run -d $Serial --dart-define=API_BASE_URL=http://10.0.2.2:3000
    } finally {
        if ($locationPushed) {
            Pop-Location
        }

        if ($originalPubCacheExists) {
            $env:PUB_CACHE = $originalPubCache
        } else {
            Remove-Item Env:PUB_CACHE -ErrorAction SilentlyContinue
        }

        try {
            if ($restorePackageConfig) {
                Push-Location $projectRoot
                try {
                    & flutter pub get --offline
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Could not restore the normal package paths."
                    }
                } finally {
                    Pop-Location
                }
            }
        } finally {
            foreach ($drive in $mappedDrives) {
                & subst.exe $drive /D
            }
        }
    }
}

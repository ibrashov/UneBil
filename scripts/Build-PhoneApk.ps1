<#
.SYNOPSIS
Builds an UneBil APK for a physical phone and verifies the backend first.

.EXAMPLE
.\scripts\Build-PhoneApk.ps1

.EXAMPLE
.\scripts\Build-PhoneApk.ps1 -ApiBaseUrl https://api.example.com
#>
[CmdletBinding()]
param(
    [string]$ApiBaseUrl,
    [ValidateSet("debug", "release")]
    [string]$BuildMode = "release",
    [string]$OutputFile
)

$ErrorActionPreference = "Stop"

function Get-LanIPv4Address {
    $candidates = foreach (
        $adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
    ) {
        if (
            $adapter.OperationalStatus -ne
                [Net.NetworkInformation.OperationalStatus]::Up -or
            $adapter.NetworkInterfaceType -eq
                [Net.NetworkInformation.NetworkInterfaceType]::Loopback
        ) {
            continue
        }

        $properties = $adapter.GetIPProperties()
        $hasIPv4Gateway = @(
            $properties.GatewayAddresses |
                Where-Object {
                    $_.Address.AddressFamily -eq
                        [Net.Sockets.AddressFamily]::InterNetwork
                }
        ).Count -gt 0

        foreach ($address in $properties.UnicastAddresses) {
            if (
                $address.Address.AddressFamily -ne
                    [Net.Sockets.AddressFamily]::InterNetwork
            ) {
                continue
            }
            $value = $address.Address.ToString()
            if ($value -like "169.254.*" -or $value -eq "127.0.0.1") {
                continue
            }
            [PSCustomObject]@{
                Address = $value
                HasGateway = $hasIPv4Gateway
                IsVpn = "$($adapter.Name) $($adapter.Description)" -match
                    "VPN|Radmin|Virtual|Tunnel"
                IsWifi = $adapter.NetworkInterfaceType -eq
                    [Net.NetworkInformation.NetworkInterfaceType]::Wireless80211
            }
        }
    }

    $selected = $candidates |
        Sort-Object `
            @{ Expression = { if ($_.IsVpn) { 1 } else { 0 } } },
            @{ Expression = { if ($_.HasGateway) { 0 } else { 1 } } },
            @{ Expression = { if ($_.IsWifi) { 0 } else { 1 } } } |
        Select-Object -First 1

    if ($selected) {
        return $selected.Address
    }

    throw "Could not detect the computer LAN IPv4 address. Pass -ApiBaseUrl explicitly."
}

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
    throw "No free temporary drive letter is available for the Android build."
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$gitRoot = (& git -C $projectRoot rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -eq 0 -and $gitRoot) {
    $projectRoot = [IO.Path]::GetFullPath(($gitRoot | Select-Object -First 1))
}
if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $lanAddress = Get-LanIPv4Address
    $ApiBaseUrl = "http://${lanAddress}:3000"
}

$ApiBaseUrl = $ApiBaseUrl.Trim().TrimEnd("/")
$parsedUrl = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$parsedUrl)) {
    throw "ApiBaseUrl must be an absolute HTTP or HTTPS URL."
}
if ($parsedUrl.Scheme -notin @("http", "https")) {
    throw "ApiBaseUrl must use HTTP or HTTPS."
}
if ($parsedUrl.Host -in @("10.0.2.2", "127.0.0.1", "localhost")) {
    throw "'$($parsedUrl.Host)' cannot be reached from a physical phone. Use the computer LAN IP or a public HTTPS backend."
}

$healthUrl = "$ApiBaseUrl/health"
try {
    $healthResponse = Invoke-WebRequest `
        -UseBasicParsing `
        -Uri $healthUrl `
        -TimeoutSec 10
    if ($healthResponse.StatusCode -ne 200) {
        throw "Unexpected health status $($healthResponse.StatusCode)."
    }
} catch {
    throw "Backend is not reachable at '$healthUrl'. Start it before building. $($_.Exception.Message)"
}

if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    $OutputFile = Join-Path $projectRoot "UneBil-phone-$BuildMode.apk"
} elseif (-not [IO.Path]::IsPathRooted($OutputFile)) {
    $OutputFile = Join-Path $projectRoot $OutputFile
}

$outputDirectory = Split-Path -Parent $OutputFile
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    [void](New-Item -ItemType Directory -Path $outputDirectory)
}

$buildRoot = $projectRoot
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
    if ($projectRoot -match '[^\x00-\x7F]') {
        $projectDriveLetter = Get-FreeDriveLetter
        $projectDrive = "${projectDriveLetter}:"
        & subst.exe $projectDrive $projectRoot
        if ($LASTEXITCODE -ne 0) {
            throw "Could not map temporary build drive $projectDrive."
        }
        $mappedDrives += $projectDrive
        $buildRoot = "$projectDrive\"
        $restorePackageConfig = $true
    }

    if ($pubCacheTarget -match '[^\x00-\x7F]') {
        $excludedLetters = $mappedDrives |
            ForEach-Object { $_.Substring(0, 1) }
        $cacheDriveLetter = Get-FreeDriveLetter -Excluded $excludedLetters
        $cacheDrive = "${cacheDriveLetter}:"
        & subst.exe $cacheDrive $pubCacheTarget
        if ($LASTEXITCODE -ne 0) {
            throw "Could not map temporary Pub cache drive $cacheDrive."
        }
        $mappedDrives += $cacheDrive
        $env:PUB_CACHE = "$cacheDrive\"
        $restorePackageConfig = $true
    }

    Push-Location $buildRoot
    $locationPushed = $true

    if ($restorePackageConfig) {
        & flutter pub get --offline
        if ($LASTEXITCODE -ne 0) {
            throw "Could not prepare dependencies through the temporary ASCII paths."
        }
    }

    Write-Host "Backend is healthy at $healthUrl"
    Write-Host "Building $BuildMode APK with API_BASE_URL=$ApiBaseUrl"

    # Older builds may leave a depfile with paths from another drive or an
    # incorrectly decoded Windows user name. Gradle 9 reads that file before
    # Flutter can replace it and fails while preparing task output folders.
    $staleDependencyFile = Join-Path `
        $buildRoot `
        "build\app\intermediates\flutter\$BuildMode\flutter_build.d"
    if (Test-Path -LiteralPath $staleDependencyFile) {
        Remove-Item -LiteralPath $staleDependencyFile -Force
    }

    & flutter build apk "--$BuildMode" --no-pub "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter build failed with exit code $LASTEXITCODE."
    }

    $sourceApk = Join-Path `
        $buildRoot `
        "build\app\outputs\flutter-apk\app-$BuildMode.apk"
    if (-not (Test-Path -LiteralPath $sourceApk)) {
        throw "Flutter reported success, but '$sourceApk' was not created."
    }
    Copy-Item -LiteralPath $sourceApk -Destination $OutputFile -Force
    if (Test-Path -LiteralPath $staleDependencyFile) {
        Remove-Item -LiteralPath $staleDependencyFile -Force
    }
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
                    Write-Warning "The APK build finished, but the normal package paths could not be restored."
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

$artifact = Get-Item -LiteralPath $OutputFile
$hash = (Get-FileHash -LiteralPath $OutputFile -Algorithm SHA256).Hash
Write-Host ""
Write-Host "Phone APK: $($artifact.FullName)"
Write-Host "SHA256: $hash"
Write-Host "Before opening the app, connect the phone to the same Wi-Fi as this computer."
Write-Host "Check from the phone browser: $healthUrl"
if ($parsedUrl.Scheme -eq "http") {
    Write-Warning "This LAN build will not work over 4G/5G. A public HTTPS backend is required for that."
}

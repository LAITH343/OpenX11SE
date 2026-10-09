param(
    [string]$Iscc = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$versionLine = Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)' | Select-Object -First 1
if ($null -eq $versionLine) { throw 'No version found in pubspec.yaml' }
$version = $versionLine.Matches[0].Groups[1].Value

if ($Iscc -eq '') {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
    )
    $Iscc = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($null -eq $Iscc) { throw 'ISCC.exe not found. Install Inno Setup 6 or pass -Iscc.' }
}

Push-Location $root
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed' }
    & $Iscc "/DAppVersion=$version" (Join-Path $root 'windows\packaging\openx11se.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compile failed' }
    $installer = Join-Path $root "build\installer\OpenX11SE-Setup-$version.exe"
    $hash = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -Path "$installer.sha256" -Value "$hash  OpenX11SE-Setup-$version.exe" -Encoding ascii
    Write-Output $installer
}
finally {
    Pop-Location
}

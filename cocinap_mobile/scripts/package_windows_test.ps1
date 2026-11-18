$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$thirdPartyDirectory = Join-Path $projectRoot 'build\third_party'
$archiveName = 'ffmpeg-n9.0-latest-win64-lgpl-shared-9.0.zip'
$archivePath = Join-Path $thirdPartyDirectory $archiveName
$archiveUrl = 'https://github.com/FFmpeg-Builds/FFmpeg-Builds/releases/download/latest/ffmpeg-n9.0-latest-win64-lgpl-shared-9.0.zip'
$expectedSha256 = 'da743e1a461aa35ee3f49cf3ae9d325a1e7c59fc3d70e35a2df0243a39248040'
$releaseDirectory = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$packagePath = Join-Path $projectRoot 'build\CocinaP-Windows-x64-v1.0.15-test.zip'
$quickStartPath = Join-Path (Split-Path -Parent $projectRoot) 'docs\QUICK_START.md'
$extractionDirectory = Join-Path $thirdPartyDirectory 'ffmpeg-package'
$ffmpegPackageDirectory = Join-Path $extractionDirectory 'ffmpeg-n9.0-latest-win64-lgpl-shared-9.0'
$ffmpegDestination = Join-Path $releaseDirectory 'ffmpeg'
$noticePath = Join-Path (Split-Path -Parent $projectRoot) 'docs\third_party\FFMPEG.md'

if (-not (Test-Path -LiteralPath (Join-Path $releaseDirectory 'cocinap_mobile.exe'))) {
    throw "Windows release build not found. Run 'flutter build windows --release' first."
}

New-Item -ItemType Directory -Force -Path $thirdPartyDirectory | Out-Null
if (-not (Test-Path -LiteralPath $archivePath)) {
    Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -UseBasicParsing
}

$actualSha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256) {
    throw "FFmpeg archive checksum mismatch. Expected $expectedSha256, got $actualSha256."
}

if (-not (Test-Path -LiteralPath (Join-Path $ffmpegPackageDirectory 'bin\ffmpeg.exe'))) {
    New-Item -ItemType Directory -Force -Path $extractionDirectory | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractionDirectory -Force
}

if (-not (Test-Path -LiteralPath (Join-Path $ffmpegPackageDirectory 'LICENSE.txt'))) {
    throw "FFmpeg license file was not found in the verified archive."
}
if (-not (Test-Path -LiteralPath $noticePath)) {
    throw "Third-party notice not found: $noticePath"
}
if (-not (Test-Path -LiteralPath $quickStartPath)) {
    throw "Quick-start guide not found: $quickStartPath"
}

if (Test-Path -LiteralPath $ffmpegDestination) {
    Remove-Item -LiteralPath $ffmpegDestination -Recurse -Force
}
New-Item -ItemType Directory -Path $ffmpegDestination | Out-Null
$ffmpegBinDirectory = Join-Path $ffmpegPackageDirectory 'bin'
Copy-Item -LiteralPath (Join-Path $ffmpegBinDirectory 'ffmpeg.exe') -Destination $ffmpegDestination
Copy-Item -Path (Join-Path $ffmpegBinDirectory '*.dll') -Destination $ffmpegDestination
Copy-Item -LiteralPath (Join-Path $ffmpegPackageDirectory 'LICENSE.txt') -Destination $ffmpegDestination
Copy-Item -LiteralPath $noticePath -Destination (Join-Path $ffmpegDestination 'THIRD_PARTY_NOTICES.md')
Copy-Item -LiteralPath $quickStartPath -Destination (Join-Path $releaseDirectory 'QUICK_START.md')

$bundledFfmpeg = Join-Path $ffmpegDestination 'ffmpeg.exe'
$encoderOutput = & $bundledFfmpeg -hide_banner -encoders 2>&1
if ($LASTEXITCODE -ne 0 -or -not (($encoderOutput -join "`n") -match 'libopenh264')) {
    throw 'The verified FFmpeg package does not provide the required libopenh264 encoder.'
}

if (Test-Path -LiteralPath $packagePath) {
    Remove-Item -LiteralPath $packagePath -Force
}
Compress-Archive -Path (Join-Path $releaseDirectory '*') -DestinationPath $packagePath -CompressionLevel Optimal

Write-Output "Created $packagePath"
Write-Output "Verified FFmpeg SHA-256: $actualSha256"

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$flutter = if ($env:FLUTTER_BIN) { $env:FLUTTER_BIN } else { "flutter" }
& $flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

New-Item -ItemType Directory -Force -Path "$root\dist" | Out-Null
Compress-Archive -Path "$root\build\windows\x64\runner\Release\*" -DestinationPath "$root\dist\StageCommander-windows-x64.zip" -Force
Get-ChildItem "$root\dist\StageCommander-windows-x64.zip" | Select-Object Name, Length

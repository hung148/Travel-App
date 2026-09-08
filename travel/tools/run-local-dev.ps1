param(
  [switch]$Help,
  [string]$Device = "windows",
  [string]$Environment = "dev",
  [int]$AiGatewayPort = 8787
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "Usage:"
  Write-Host "  powershell -ExecutionPolicy Bypass -File tools\run-local-dev.ps1"
  Write-Host ""
  Write-Host "Options:"
  Write-Host "  -Device windows|chrome|edge|android"
  Write-Host "  -Environment dev|prod"
  Write-Host "  -AiGatewayPort 8787"
  exit 0
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$functionsRoot = Join-Path $projectRoot "functions"

if (-not (Test-Path (Join-Path $projectRoot "pubspec.yaml"))) {
  throw "Run this script from the Travel App project checkout."
}

$groqKey = Read-Host "Paste your Groq API key"
$googleMapsKey = Read-Host "Paste your Google Maps API key"

$env:GROQ_API_KEY = $groqKey
$env:GOOGLE_MAPS_API_KEY = $googleMapsKey
$env:AI_GATEWAY_PORT = "$AiGatewayPort"

Remove-Variable groqKey
Remove-Variable googleMapsKey

$gatewayUrl = "http://127.0.0.1:$AiGatewayPort/interpretTripRequest"

Write-Host "Starting local AI gateway on $gatewayUrl"
$gateway = Start-Process `
  -FilePath "npm.cmd" `
  -ArgumentList "run", "dev" `
  -WorkingDirectory $functionsRoot `
  -PassThru `
  -WindowStyle Hidden

try {
  Write-Host "Launching Flutter on $Device using $Environment Firebase config"
  flutter run `
    -d $Device `
    --dart-define=ENV=$Environment `
    --dart-define=GOOGLE_MAPS_API_KEY=$env:GOOGLE_MAPS_API_KEY `
    --dart-define=AI_ASSISTANT_URL=$gatewayUrl
}
finally {
  if ($gateway -and -not $gateway.HasExited) {
    Stop-Process -Id $gateway.Id
  }
  Remove-Item Env:\GROQ_API_KEY -ErrorAction SilentlyContinue
  Remove-Item Env:\GOOGLE_MAPS_API_KEY -ErrorAction SilentlyContinue
  Remove-Item Env:\AI_GATEWAY_PORT -ErrorAction SilentlyContinue
}

param(
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = Join-Path $projectRoot '.venv\Scripts\python.exe'
$frontendDir = Join-Path $projectRoot 'frontend'
$dataDir = $env:NOMI_DATA_DIR
if (-not $dataDir) { $dataDir = $env:JOURNAL_DATA_DIR }
if (-not $dataDir) { $dataDir = Join-Path $projectRoot 'data' }
$logDir = Join-Path $dataDir 'logs'
$backendLog = Join-Path $logDir 'backend.log'
$backendErrorLog = Join-Path $logDir 'backend-error.log'
$frontendLog = Join-Path $logDir 'frontend.log'
$frontendErrorLog = Join-Path $logDir 'frontend-error.log'
$backendProcess = $null
$frontendProcess = $null
$backendUrl = 'http://127.0.0.1:8000'
$frontendUrl = 'http://127.0.0.1:5173'

if (-not (Test-Path $python) -or -not (Test-Path (Join-Path $frontendDir 'node_modules'))) {
    throw 'Dependencies are not set up. Run .\setup.ps1 first.'
}
if (Get-Command ollama -ErrorAction SilentlyContinue) {
    try {
        $null = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2
    } catch {
        Write-Warning 'Ollama is not responding. The app will start, but AI features need Ollama running. Start the Ollama app in another window.'
    }
} else {
    Write-Warning 'Ollama is not installed. The app will start, but AI features will be unavailable.'
}

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Write-Host 'Starting Nomi backend and frontend...' -ForegroundColor Cyan
$previousNomiDev = $env:NOMI_DEV
$env:NOMI_DEV = '1'
try {
    $backendProcess = Start-Process -FilePath $python -ArgumentList @('-m', 'uvicorn', 'backend.server:app', '--host', '127.0.0.1', '--port', '8000', '--log-level', 'info') -WorkingDirectory $projectRoot -RedirectStandardOutput $backendLog -RedirectStandardError $backendErrorLog -PassThru -WindowStyle Hidden
} finally {
    if ($null -eq $previousNomiDev) { Remove-Item Env:NOMI_DEV -ErrorAction SilentlyContinue }
    else { $env:NOMI_DEV = $previousNomiDev }
}

try {
    $backendReady = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        if ($backendProcess.HasExited) { throw "Backend stopped during startup. See $backendLog" }
        try {
            $null = Invoke-RestMethod -Uri "$backendUrl/openapi.json" -TimeoutSec 2
            $backendReady = $true
            break
        } catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $backendReady) { throw "Backend did not become ready. See $backendLog" }

    $frontendProcess = Start-Process -FilePath 'npm' -ArgumentList @('run', 'dev', '--', '--host', '127.0.0.1', '--strictPort') -WorkingDirectory $frontendDir -RedirectStandardOutput $frontendLog -RedirectStandardError $frontendErrorLog -PassThru -WindowStyle Hidden
    $frontendReady = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        if ($frontendProcess.HasExited) { throw "Frontend stopped during startup. See $frontendLog" }
        try {
            $response = Invoke-WebRequest -Uri $frontendUrl -TimeoutSec 2
            if ($response.StatusCode -eq 200) { $frontendReady = $true; break }
        } catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $frontendReady) { throw "Frontend did not become ready. See $frontendLog" }

    Write-Host "Nomi is running at $frontendUrl" -ForegroundColor Green
    Write-Host "Backend API: $backendUrl  |  Logs: $logDir"
    Write-Host 'Press Ctrl+C to stop both services.'
    if (-not $NoBrowser) { Start-Process $frontendUrl }
    while (-not $backendProcess.HasExited -and -not $frontendProcess.HasExited) { Start-Sleep -Seconds 1 }
    if ($backendProcess.HasExited) { Write-Warning "Backend exited. See $backendLog" }
    if ($frontendProcess.HasExited) { Write-Warning "Frontend exited. See $frontendLog" }
} finally {
    foreach ($process in @($frontendProcess, $backendProcess)) {
        if ($null -ne $process -and -not $process.HasExited) {
            & taskkill.exe /PID $process.Id /T /F 2>$null | Out-Null
        }
    }
}

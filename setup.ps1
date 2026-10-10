param(
    [switch]$SkipFrontend,
    [switch]$SkipOllamaModels
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendDir = Join-Path $projectRoot 'backend'
$frontendDir = Join-Path $projectRoot 'frontend'
$venvDir = Join-Path $projectRoot '.venv'

function Find-Python {
    foreach ($candidate in @(@('py', '-3'), @('python'), @('python3'))) {
        $command = Get-Command $candidate[0] -ErrorAction SilentlyContinue
        if ($command) {
            $candidateArgs = @($candidate | Select-Object -Skip 1)
            $versionText = & $candidate[0] @candidateArgs --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $versionText -match 'Python (\d+\.\d+\.\d+)') {
                if ([version]$Matches[1] -lt [version]'3.11.0') {
                    throw "Python 3.11 or newer is required. Found Python $($Matches[1])."
                }
                return $candidate
            }
        }
    }
    throw 'Python 3 was not found. Install Python 3.11 or newer and enable the py launcher or add python.exe to PATH.'
}

function Test-OllamaReady {
    try {
        $null = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3
        return $true
    } catch { return $false }
}

Write-Host 'Setting up Nomi...' -ForegroundColor Cyan
$pythonCommand = Find-Python
Write-Host "Using Python command: $($pythonCommand -join ' ')"

if (-not (Test-Path (Join-Path $venvDir 'Scripts\python.exe'))) {
    $pythonArgs = @($pythonCommand | Select-Object -Skip 1)
    & $pythonCommand[0] @pythonArgs -m venv $venvDir
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the Python virtual environment.' }
}
$venvPython = Join-Path $venvDir 'Scripts\python.exe'
& $venvPython -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw 'Could not upgrade pip.' }
& $venvPython -m pip install -r (Join-Path $backendDir 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'Backend dependency installation failed.' }

if (-not $SkipFrontend) {
    if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw 'Node.js (LTS) and npm are required. Install Node.js 22 LTS, reopen PowerShell, and rerun setup.ps1.'
    }
    $nodeVersion = [version](node -p 'process.versions.node')
    if ($nodeVersion -lt [version]'22.12') { throw "Node.js 22.12 or newer is required. Found Node.js $nodeVersion." }
    Push-Location $frontendDir
    try {
        npm ci
        if ($LASTEXITCODE -ne 0) { throw 'Frontend dependency installation failed.' }
    } finally { Pop-Location }
}

New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'data\audio'), (Join-Path $projectRoot 'data\media'), (Join-Path $projectRoot 'data\logs') | Out-Null

if (-not $SkipOllamaModels) {
    if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
        Write-Warning 'Ollama is not installed. Install it from https://ollama.com/download/windows to enable AI features, then rerun setup.ps1.'
    } elseif (-not (Test-OllamaReady)) {
        Write-Warning 'Ollama is installed but its local service is not responding at http://127.0.0.1:11434. Start Ollama, then rerun setup.ps1 to download models.'
    } else {
        foreach ($model in @('qwen2.5:3b', 'nomic-embed-text')) {
            Write-Host "Ensuring Ollama model $model is installed..."
            ollama pull $model
            if ($LASTEXITCODE -ne 0) { throw "Downloading Ollama model '$model' failed." }
        }
    }
}

Write-Host ''
Write-Host 'Setup complete.' -ForegroundColor Green
Write-Host 'Run the application with: .\run.ps1'
Write-Host 'To skip large Ollama model downloads: .\setup.ps1 -SkipOllamaModels'

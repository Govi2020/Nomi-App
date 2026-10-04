param()

$ErrorActionPreference = 'Continue'
$projectRoot = Split-Path -Parent $PSScriptRoot
$missing = [System.Collections.Generic.List[string]]::new()

function Write-Check([string]$Name, [bool]$Passed, [string]$Detail, [string]$InstallCommand = '') {
    $label = if ($Passed) { 'PASS' } else { 'MISSING' }
    $color = if ($Passed) { 'Green' } else { 'Yellow' }
    Write-Host ('[{0}] {1}: {2}' -f $label, $Name, $Detail) -ForegroundColor $color
    if (-not $Passed -and $InstallCommand) { $missing.Add("$Name — $InstallCommand") }
}

Write-Host 'Nomi desktop-build prerequisites (read-only check)' -ForegroundColor Cyan
Write-Host "Repository: $projectRoot"

$rustc = Get-Command rustc -ErrorAction SilentlyContinue
$cargo = Get-Command cargo -ErrorAction SilentlyContinue
$hostTriple = ''
if ($rustc -and $cargo) {
    $rustInfo = & rustc -vV 2>$null | Out-String
    if ($rustInfo -match '(?m)^host:\s*(\S+)') { $hostTriple = $Matches[1] }
}
Write-Check 'Rust toolchain' ([bool]($rustc -and $cargo -and $hostTriple)) $(if ($hostTriple) { "rustc/cargo available; host triple $hostTriple" } else { 'rustc and cargo with a readable host triple are required' }) 'winget install --id Rustlang.Rustup --exact'

$vswhereCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\Installer\vswhere.exe')
)
$vswhere = $vswhereCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$buildTools = $null
if ($vswhere) {
    $buildTools = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
}
$vsCommand = 'winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"'
Write-Check 'MSVC C++ Build Tools' ([bool]$buildTools) $(if ($buildTools) { "VC x64 tools found under $buildTools" } else { 'Visual Studio 2022+ with the Desktop development with C++ workload is required' }) $vsCommand

$webViewPaths = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\EdgeWebView\Application'),
    (Join-Path $env:ProgramFiles 'Microsoft\EdgeWebView\Application'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\EdgeWebView\Application')
)
$webView = $webViewPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
Write-Check 'WebView2 runtime' ([bool]$webView) $(if ($webView) { "runtime directory found: $webView" } else { 'Microsoft Edge WebView2 Evergreen Runtime is required' }) 'Download and install the Evergreen Bootstrapper from https://developer.microsoft.com/microsoft-edge/webview2/'

$node = Get-Command node -ErrorAction SilentlyContinue
$nodeVersion = $null
if ($node) {
    $rawNodeVersion = & node --version 2>$null
    if ($rawNodeVersion -match 'v?(\d+\.\d+\.\d+)') { $nodeVersion = [version]$Matches[1] }
}
Write-Check 'Node.js' ([bool]($nodeVersion -and $nodeVersion -ge [version]'22.12')) $(if ($nodeVersion) { "found $nodeVersion; 22.12 or newer is required" } else { 'not found; 22.12 or newer is required' }) 'winget install --id OpenJS.NodeJS.LTS --exact'
$npm = Get-Command npm -ErrorAction SilentlyContinue
$npmVersion = if ($npm) { & npm --version 2>$null }
Write-Check 'npm' ([bool]$npm) $(if ($npm) { "found version $npmVersion" } else { 'npm is not available in PATH; it is included with the Node.js LTS installer' }) 'winget install --id OpenJS.NodeJS.LTS --exact'

$venvPython = Join-Path $projectRoot '.venv\Scripts\python.exe'
$venvConfig = Join-Path $projectRoot '.venv\pyvenv.cfg'
$pythonVersion = $null
if (Test-Path $venvConfig) {
    $configText = Get-Content -LiteralPath $venvConfig -Raw
    if ($configText -match '(?m)^version\s*=\s*(\d+\.\d+\.\d+)') { $pythonVersion = [version]$Matches[1] }
}
$pythonRan = $false
if (Test-Path $venvPython) {
    try {
        $runtimeVersion = & $venvPython --version 2>&1 | Out-String
        $pythonRan = ($LASTEXITCODE -eq 0)
        if ($runtimeVersion -match '(\d+\.\d+\.\d+)') { $pythonVersion = [version]$Matches[1] }
    } catch { $runtimeVersion = $_.Exception.Message }
}
Write-Check 'Project venv Python' ([bool]($pythonVersion -and $pythonRan)) $(if ($pythonRan) { "Python $pythonVersion" } elseif ($pythonVersion) { "venv says Python $pythonVersion but it could not be launched: $runtimeVersion" } else { 'create the project .venv with supported CPython' }) 'winget install --id Python.Python.3.14 --exact; then rerun .\setup.ps1'

$nuitkaAvailable = $false
$nuitkaVersion = ''
if (Test-Path $venvPython) {
    try {
        $nuitkaVersion = & $venvPython -m nuitka --version 2>&1 | Out-String
        $nuitkaAvailable = ($LASTEXITCODE -eq 0)
    } catch { $nuitkaVersion = $_.Exception.Message }
}
$nuitkaSupported = [bool]($pythonVersion -and $pythonVersion -ge [version]'3.4' -and $pythonVersion -lt [version]'3.15')
$nuitkaReady = $nuitkaAvailable -and $nuitkaSupported
$nuitkaDetail = if (-not $pythonVersion) { 'cannot determine project Python version' } elseif (-not $nuitkaSupported) { "Python $pythonVersion is outside the officially documented supported range (3.4–3.14)" } elseif ($nuitkaAvailable) { "supported Python $pythonVersion; $($nuitkaVersion.Trim() -split "`n" | Select-Object -First 1)" } else { "Python $pythonVersion is in Nuitka's documented range, but Nuitka is not installed in the project venv" }
Write-Check 'Nuitka' $nuitkaReady $nuitkaDetail 'Install in the isolated build venv with: .\.venv-build\Scripts\python.exe -m pip install nuitka zstandard ordered-set'

$ollamaReachable = $false
try {
    $null = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2
    $ollamaReachable = $true
} catch { }
Write-Check 'Ollama local service' $ollamaReachable $(if ($ollamaReachable) { 'reachable at http://127.0.0.1:11434' } else { 'not reachable; optional for building, required for AI runtime checks' }) 'Install Ollama from https://ollama.com/download/windows and start it'

if ($missing.Count -gt 0) {
    Write-Host "`nInstall/check these items before building the desktop app:" -ForegroundColor Yellow
    foreach ($item in $missing) { Write-Host " - $item" }
} else {
    Write-Host "`nAll required desktop-build prerequisites are present. Ollama remains optional for compilation." -ForegroundColor Green
}

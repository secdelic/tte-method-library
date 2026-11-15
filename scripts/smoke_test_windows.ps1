[CmdletBinding()]
param([switch]$SkipProjectDemo)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$statePath = Join-Path $repo '.local\environment.json'
if (-not (Test-Path -LiteralPath $statePath)) { throw 'Run scripts/setup_windows.ps1 -WithWord first.' }
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
if (-not $state.word_dependencies) { throw 'Rerun setup_windows.ps1 -WithWord for the Word smoke test.' }
if (-not (Test-Path -LiteralPath $state.python) -or -not (Test-Path -LiteralPath $state.rscript)) {
    throw 'This PC has no matching local environment. Run setup_windows.ps1 here; do not copy .venv or .local between PCs.'
}
$logs = Join-Path $repo '.local\smoke'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
function Invoke-SmokeStep([string]$Name, [string]$Executable, [string[]]$Arguments) {
    $log = Join-Path $logs ($Name + '.log')
    & $Executable @Arguments *> $log
    if ($LASTEXITCODE -ne 0) { throw "$Name failed; inspect private log $log" }
    Write-Output "$Name=PASS"
}
$previousPath = $env:PATH
$previousIntegration = $env:TTE_RUN_WORKSPACE_INTEGRATION
$previousReporting = $env:TTE_REPORTING_LIBRARY
Push-Location $repo
try {
    $env:PATH = (Split-Path -Parent $state.rscript) + [IO.Path]::PathSeparator + $env:PATH
    $env:TTE_RUN_WORKSPACE_INTEGRATION = '1'
    $env:TTE_REPORTING_LIBRARY = $repo
    Invoke-SmokeStep 'locked_environment' $state.rscript @('scripts/check_environment.R')
    Invoke-SmokeStep 'core_R_tests' $state.rscript @('tests/run_tests.R')
    Invoke-SmokeStep 'legacy_quick_start' $state.rscript @('examples/quick_start/run_quick_start.R')
    Invoke-SmokeStep 'numerical_regression' $state.rscript @('validation/run_public_numerical_regression.R')
    Invoke-SmokeStep 'portable_assets' $state.python @('-m','unittest','discover','-s','tests','-p','test_portable_assets.py','-v')
    Invoke-SmokeStep 'workspace_tests' $state.python @('-m','unittest','discover','-s','tests','-p','test_project_workspace.py','-v')
    Invoke-SmokeStep 'word_tests' $state.python @('-m','unittest','discover','-s','tests','-p','test_word_reporting.py','-v')
    if (-not $SkipProjectDemo) {
        Invoke-SmokeStep 'synthetic_projects_and_Word' $state.python @('examples/project_workspace/run_synthetic_projects.py','--enable-word')
        Write-Output 'WORD_OUTPUTS=project/SYNTHETIC_BINARY/runs/run_001/report/analysis_report.docx; project/SYNTHETIC_CONTINUOUS/runs/run_001/report/analysis_report.docx'
    }
    Write-Output 'SMOKE_TEST=PASSED; synthetic workflow only; this is not second-PC or clinical validation'
} finally {
    $env:PATH = $previousPath
    $env:TTE_RUN_WORKSPACE_INTEGRATION = $previousIntegration
    $env:TTE_REPORTING_LIBRARY = $previousReporting
    Pop-Location
}

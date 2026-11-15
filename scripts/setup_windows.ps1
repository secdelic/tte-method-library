[CmdletBinding()]
param(
    [string]$Python,
    [string]$Rscript,
    [switch]$WithWord,
    [switch]$CheckOnly,
    [switch]$SkipRRestore
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$gitRoot = (& git -C $repo rev-parse --show-toplevel)
if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($gitRoot) -ne $repo) {
    throw 'Run the setup script from an actual method-library Git checkout.'
}

if (-not $Python) {
    $launcher = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($launcher) {
        foreach ($version in @('3.12', '3.13', '3.11')) {
            try {
                $candidate = & $launcher.Source "-$version" -c 'import sys; print(sys.executable)' 2>$null
                if ($LASTEXITCODE -eq 0) { $Python = [string]$candidate; break }
            } catch { continue } # A missing optional interpreter is a discovery miss.
        }
    }
    if (-not $Python) {
        $command = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($command) { $Python = $command.Source }
    }
}
if (-not $Python -or -not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    throw 'Install Python 3.12 (supported: 3.11-3.13), or supply -Python with its executable path.'
}
$pythonInfo = & $Python -c 'import json,sys; print(json.dumps(dict(version=list(sys.version_info[:3]), executable=sys.executable)))'
if ($LASTEXITCODE -ne 0) { throw 'The selected Python executable could not start.' }
$pythonState = $pythonInfo | ConvertFrom-Json
if ($pythonState.version[0] -ne 3 -or $pythonState.version[1] -lt 11 -or $pythonState.version[1] -gt 13) {
    throw 'This portable installation supports Python 3.11-3.13; Python 3.12 is recommended.'
}
$Python = $pythonState.executable

if (-not $Rscript) {
    $command = Get-Command Rscript.exe -ErrorAction SilentlyContinue
    if ($command) { $Rscript = $command.Source }
    if (-not $Rscript) {
        foreach ($key in @('HKCU:\SOFTWARE\R-core\R', 'HKLM:\SOFTWARE\R-core\R', 'HKLM:\SOFTWARE\R-core\R64')) {
            $installation = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
            if ($installation) {
                foreach ($suffix in @('bin\Rscript.exe', 'bin\x64\Rscript.exe')) {
                    $candidate = Join-Path $installation.InstallPath $suffix
                    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $Rscript = $candidate; break }
                }
            }
            if ($Rscript) { break }
        }
    }
}
if (-not $Rscript -or -not (Test-Path -LiteralPath $Rscript -PathType Leaf)) {
    throw 'Install R 4.5.1 or supply -Rscript with the Rscript executable path.'
}
$rVersion = & $Rscript --vanilla -e 'cat(as.character(getRversion()))'
if ($LASTEXITCODE -ne 0 -or ([string]$rVersion).Trim() -ne '4.5.1') {
    throw 'renv.lock targets R 4.5.1. Select that installation with -Rscript.'
}
Write-Output "PYTHON=$($pythonState.version -join '.')"
Write-Output "R=$rVersion"
if ($CheckOnly) { Write-Output 'SETUP_CHECK=PASSED; no installation performed'; return }

$local = Join-Path $repo '.local'
$venv = Join-Path $repo '.venv'
foreach ($directory in @($local, $venv)) {
    if ((Test-Path -LiteralPath $directory) -and
        ((Get-Item -LiteralPath $directory -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Linked local environment directories are not supported.'
    }
}
New-Item -ItemType Directory -Path $local -Force | Out-Null
$probe = Join-Path $local ([guid]::NewGuid().ToString() + '.tmp')
[IO.File]::WriteAllText($probe, 'write check')
Remove-Item -LiteralPath $probe
$venvPython = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venv)) {
    & $Python -m venv $venv
    if ($LASTEXITCODE -ne 0) { throw 'Python venv creation failed; install Python with venv and pip support.' }
}
if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
    throw 'The existing .venv is incomplete. Inspect it before recreating it; do not copy virtual environments between PCs.'
}
& $venvPython -c 'import sys; assert (3,11) <= sys.version_info[:2] < (3,14)'
if ($LASTEXITCODE -ne 0) { throw 'The existing .venv is incompatible with this installation.' }
if ($WithWord) {
    & $venvPython -m pip install --disable-pip-version-check -r (Join-Path $repo 'reporting\requirements.txt') -c (Join-Path $repo 'reporting\constraints.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Optional Word dependency installation failed; inspect the pip error and network access.' }
    & $venvPython -m pip check
    if ($LASTEXITCODE -ne 0) { throw 'The optional Python dependency environment is inconsistent.' }
    & $venvPython -c "import docx,lxml,PIL; print('WORD_DEPENDENCIES=AVAILABLE')"
    if ($LASTEXITCODE -ne 0) { throw 'Optional Word imports failed.' }
} else { Write-Output 'WORD_DEPENDENCIES=NOT_REQUESTED; statistical runs do not require them' }

Push-Location $repo
try {
    if (-not $SkipRRestore) {
        $lock = Get-Content -LiteralPath (Join-Path $repo 'renv.lock') -Raw | ConvertFrom-Json
        & $Rscript --vanilla (Join-Path $repo 'scripts\restore_environment.R') $repo $lock.Packages.renv.Version
        if ($LASTEXITCODE -ne 0) {
            throw 'R restoration failed. Check the package download/build error; install Rtools45 if an exact package needs compilation.'
        }
    }
    & $Rscript (Join-Path $repo 'scripts\check_environment.R')
    if ($LASTEXITCODE -ne 0) { throw 'Installed R versions differ from renv.lock; restore the declared environment.' }
} finally { Pop-Location }
$state = [ordered]@{python=$venvPython; rscript=$Rscript; word_dependencies=[bool]$WithWord; r_restore_skipped=[bool]$SkipRRestore}
$state | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $local 'environment.json') -Encoding UTF8
Write-Output 'SETUP=PASSED; private .venv and .local environment paths are excluded from Git'

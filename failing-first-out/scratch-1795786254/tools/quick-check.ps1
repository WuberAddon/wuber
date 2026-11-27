# Quick check after a merge: runs tools/quick-check.sh through Git Bash. Usage: tools\quick-check.ps1 [repo or worktree]
# Prints the one final line "quick-check: PASS (...)" or "quick-check: FAIL: ..."; exit code 0 / 1.
param([string]$Repo = (Split-Path -Parent $PSScriptRoot))
$bash = if (Get-Command bash -ErrorAction SilentlyContinue) { "bash" } else { Join-Path $env:ProgramFiles "Git\bin\bash.exe" }
if (-not (Test-Path $bash)) { $bash = "bash" }
$sh = (Join-Path $PSScriptRoot "quick-check.sh") -replace '\\', '/'
$r = ($Repo -replace '\\', '/')
& $bash $sh $r
exit $LASTEXITCODE

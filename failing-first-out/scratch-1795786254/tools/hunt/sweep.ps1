# The bug hunt's sweep (tests/hunt/README.md): up to -Procs lua processes (one shard each), then the join's two halves
# on the same processes: --plan groups every shard's raw failures, --shrink-part K/M shrinks each group ONCE (in
# parallel), --join writes FAILURES.md, failures.tsv, cannot.tsv, broken.tsv, summary.txt and KNOWN.md. Run from anywhere:
#   powershell -File tools/hunt/sweep.ps1                       # the normal sweep: pairs, 8 processes, 20 minutes or less
#   powershell -File tools/hunt/sweep.ps1 -Procs 2 -Promise tips. -Minutes 5
#   powershell -File tools/hunt/sweep.ps1 -Addon ..\other-checkout\Wuber -Out tests/out/hunt/old   # another Wuber
#   powershell -File tools/hunt/sweep.ps1 -Deep                 # long sessions: walk mode, 6 walks per process of
#                                                               #   500-2000 steps each, 60 minutes (-N, -Steps, -Minutes)
#   powershell -File tools/hunt/sweep.ps1 -Mode walk -N 40 -Steps 30
# The sequence hunt (tools/hunt/seq_hunt.lua: targeted and random chains of actions, the "always a way out" checks) is a phase of every
# sweep: it runs on one more process beside the promise shards, with -Seed and -Addon, and its results are appended to summary.txt
# and FAILURES.md ("Sequence hunt"; seq.tsv has the lines). -NoSeq skips it; -SeqN sets its random chains (default 12). The pending
# chain (cancel_then_leave, BUGS-NEXT BS-01) counts as KNOWN. The promises of tests/promises/nowayout.lua are in the normal set (every
# tests/promises/*.lua file is loaded). The LAST line is the method line:
#   GAUNTLET hunt result=<pass|fail|error> promises=<n> failures=<n> new=<n> known=<n> seq_chains=<n> seq_failures=<n>
# Exit 0: nothing new; 1: a new failure (a promise or a sequence chain); 2: the sweep could not run.
# -Minutes is the whole run's wall time: 65% for the checks (60% in walk mode) (sweep.lua --deadline-seconds and --total-seconds),
# the rest for the shrinking and the join; a process still running past its phase's end (+60 s) is stopped by its id.
# -Minutes 0: no time limit (the whole set; shrinking then gets --shrink-seconds, 900 s, per process).
# -BudgetSeconds caps each promise per process. -ReproDir: where the repro files (and KNOWN.md next to it) go.
# -KnownDir: the folder whose repro files say which findings are already KNOWN (counted, not shrunk again; default
#   tests/hunt/repro, also when -ReproDir is given). FAILURES.md lists them under "Known (already on the list)"; failures-new.tsv has the new ones.
# -Skip id,id: promises never checked in this run.
# -Seed N: another seed gives other situations for every promise (pairwise sets, random ones, walks, the checks' own
#   choices), so a later sweep covers new ground. -Resume <out dir of an earlier sweep>: skip each (promise, situation)
#   that sweep ran and PASSED (only while that promise's file, the dials, the core and Wuber are unchanged), so a second
#   pass spends its time on new situations; best with the same -Seed and more minutes (the pairwise sets are the same;
#   another -Seed makes other situations, which are all new anyway).
# The pairwise sets are cached in tests/out/hunt/cache (read when the dials and the promise are unchanged).
param(
	[int]$Procs = 8,
	[string]$Mode = "pairs",
	[int]$Seed = 1,
	[int]$N = 0,
	[string]$Steps = "30",
	[string]$Addon = "",
	[string]$Promise = "",
	[string]$Out = "",
	[double]$Minutes = 20,
	[int]$BudgetSeconds = 0,
	[switch]$NoShrink,
	[string]$ReproDir = "",
	[string]$KnownDir = "",
	[string]$Skip = "",
	[switch]$Deep,
	[string]$Resume = "",
	[switch]$NoSeq,
	[int]$SeqN = 12
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $root
$lua = $env:WUBER_LUA
if (-not $lua) { $lua = if ($env:LUA) { $env:LUA } else { "lua5.1" } }
if (-not $env:WUBER_LAB_DIR) { $env:WUBER_LAB_DIR = (Join-Path $PSScriptRoot "..\..\lab\WuberLab") }

$walkN = $N
if ($Deep) {
	$Mode = "walk"
	if (-not $PSBoundParameters.ContainsKey('N')) { $N = 6 }
	if (-not $PSBoundParameters.ContainsKey('Steps')) { $Steps = "500-2000" }
	if (-not $PSBoundParameters.ContainsKey('Minutes')) { $Minutes = 60 }
	$walkN = $N * $Procs   # -N is per process in a deep run
}
if (-not $Out) { $Out = "tests/out/hunt/" + ($(if ($Deep) { "deep" } else { $Mode })) + "-s" + $Seed + "-" + (Get-Date -Format "yyyyMMdd-HHmmss") }
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$common = @("tools/hunt/sweep.lua", "--mode", $Mode, "--seed", "$Seed", "--out", $Out, "--steps", "$Steps")
if ($walkN -gt 0) { $common += @("--n", "$walkN") }
if ($Addon) { $common += @("--addon", $Addon) }
if ($Promise) { $common += @("--promise", $Promise) }
if ($Skip) { $common += @("--skip", $Skip) }
if ($Resume) { $common += @("--resume", $Resume) }
$extra = @()
if ($ReproDir) { $extra += @("--repro-dir", $ReproDir) }
if ($NoShrink) { $extra += "--no-shrink" }

$total = [Math]::Max(0, $Minutes * 60)
$checkSecs = 0
$work = @()
if ($BudgetSeconds -gt 0) { $work += @("--budget-seconds", "$BudgetSeconds") }
if ($total -gt 0) {
	# the checks get 65% of the time (60% in walk mode: replaying long sessions makes the shrinking dearer)
	$share = $(if ($Mode -eq "walk") { 0.60 } else { 0.65 })
	$checkSecs = [int][Math]::Max(60, $total * $share)
	$work += @("--deadline-seconds", "$checkSecs")
	if ($Mode -ne "walk") { $work += @("--total-seconds", [string][int]([Math]::Max(30, $checkSecs - 30))) }
}

function Quote-Arg([string]$a) { if ($a -match '\s') { return '"' + $a + '"' } return $a }

# starts the processes, waits (up to $limit s when > 0), stops any still running by its own id; returns the stopped ones
function Run-Procs($argLists, $logBase, [int]$limit) {
	$ps = @()
	$k = 0
	foreach ($argv in $argLists) {
		$k++
		$log = Join-Path $Out ($logBase + "-" + $k + ".log")
		$q = $argv | ForEach-Object { Quote-Arg $_ }
		$ps += Start-Process -FilePath $lua -ArgumentList $q -RedirectStandardOutput $log -RedirectStandardError ($log + ".err") -NoNewWindow -PassThru
	}
	if ($limit -gt 0) { $ps | Wait-Process -Timeout $limit -ErrorAction SilentlyContinue } else { $ps | Wait-Process }
	$stopped = @()
	$k = 0
	foreach ($p in $ps) {
		$k++
		if (-not $p.HasExited) {
			Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
			$stopped += $k
		}
	}
	return ,$stopped
}

$t0 = Get-Date
$lists = @()
for ($k = 1; $k -le $Procs; $k++) { $lists += ,($common + $work + $extra + @("--shard", "$k/$Procs")) }
Write-Host ("hunt: " + $Procs + " processes (" + $Mode + $(if ($Deep) { ", deep: " + $walkN + " walks of " + $Steps + " steps" } else { "" }) + "), results in " + $Out + $(if ($total -gt 0) { ", " + $Minutes + " min" } else { "" }))
# the sequence hunt: one more process, beside the shards
$seqProc = $null
$seqLog = Join-Path $Out "seq.log"
if (-not $NoSeq) {
	$sa = @("tools/hunt/seq_hunt.lua", "--seed", "$Seed", "--n", "$SeqN", "--steps", "5", "--out", $Out)
	if ($Addon) { $sa += @("--addon", $Addon) }
	$q = $sa | ForEach-Object { Quote-Arg $_ }
	$seqProc = Start-Process -FilePath $lua -ArgumentList $q -RedirectStandardOutput $seqLog -RedirectStandardError ($seqLog + ".err") -NoNewWindow -PassThru
	Write-Host ("hunt: sequence hunt on one more process (seed " + $Seed + ", " + $SeqN + " random chains)")
}
$stopped = Run-Procs $lists "shard" $(if ($checkSecs -gt 0) { $checkSecs + 60 } else { 0 })
$tChecks = ((Get-Date) - $t0).TotalSeconds
if ($stopped.Count -gt 0) { Write-Host ("  shards stopped at the time limit (their files are partial): " + ($stopped -join ", ")) }

# the join, first half: group every raw failure
$t1 = Get-Date
$knownArgs = @($(if ($KnownDir) { @("--known-dir", $KnownDir) } else { @() }))
$planOut = & $lua tools/hunt/sweep.lua --plan $Procs --mode $Mode --seed $Seed --out $Out @($(if ($Addon) { @("--addon", $Addon) } else { @() })) @knownArgs
$planOut | ForEach-Object { Write-Host ("  " + $_) }
$groups = 0
foreach ($l in $planOut) { if ($l -match '^groups: (\d+)') { $groups = [int]$Matches[1] } }
$tPlan = ((Get-Date) - $t1).TotalSeconds

# the shrinking, on all the processes (each group ONCE)
$t2 = Get-Date
$shrinkProcs = [Math]::Min($Procs, $groups)
$shrinkSecs = 0
if ($shrinkProcs -gt 0) {
	$sargs = @("--mode", $Mode, "--seed", "$Seed", "--out", $Out) + $extra
	if ($Addon) { $sargs += @("--addon", $Addon) }
	if ($total -gt 0) {
		$shrinkSecs = [int][Math]::Max(30, $total - ((Get-Date) - $t0).TotalSeconds - 45)
		$sargs += @("--deadline-seconds", "$shrinkSecs")
	}
	$slists = @()
	for ($k = 1; $k -le $shrinkProcs; $k++) { $slists += ,(@("tools/hunt/sweep.lua", "--shrink-part", "$k/$shrinkProcs") + $sargs) }
	Write-Host ("  shrinking " + $groups + " groups on " + $shrinkProcs + " processes" + $(if ($shrinkSecs -gt 0) { " (" + $shrinkSecs + " s)" } else { "" }))
	$sstopped = Run-Procs $slists "shrink" $(if ($shrinkSecs -gt 0) { $shrinkSecs + 60 } else { 0 })
	if ($sstopped.Count -gt 0) { Write-Host ("  shrink processes stopped at the time limit: " + ($sstopped -join ", ")) }
}
$tShrink = ((Get-Date) - $t2).TotalSeconds

$t3 = Get-Date
$joinArgs = @("tools/hunt/sweep.lua", "--join", "$Procs", "--mode", $Mode, "--seed", "$Seed", "--out", $Out) + $(if ($ReproDir) { @("--repro-dir", $ReproDir) } else { @() }) + $knownArgs
if ($Addon) { $joinArgs += @("--addon", $Addon) }
& $lua @joinArgs
$code = $LASTEXITCODE
$tJoin = ((Get-Date) - $t3).TotalSeconds
$wall = ((Get-Date) - $t0).TotalSeconds
Write-Host ("wall time: {0:N0} s ({1:N1} min) on {2} processes: checks {3:N0} s, plan {4:N0} s, shrinking {5:N0} s, join {6:N0} s" -f $wall, ($wall / 60), $Procs, $tChecks, $tPlan, $tShrink, $tJoin)
# the sequence hunt's result joins summary.txt and FAILURES.md
$seqChains = 0; $seqFail = 0; $seqKnown = 0; $seqErr = $false
if ($seqProc) {
	$seqProc | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue
	if (-not $seqProc.HasExited) { Stop-Process -Id $seqProc.Id -Force -ErrorAction SilentlyContinue; $seqErr = $true }
	$seqLines = @(); if (Test-Path $seqLog) { $seqLines = @(Get-Content $seqLog) }
	$sumLine = $seqLines | Where-Object { $_ -match '^SEQ chains=' } | Select-Object -Last 1
	if ($sumLine -match 'chains=(\d+) pass=(\d+) new=(\d+) known=(\d+) cannot=(\d+)') {
		$seqChains = [int]$Matches[1]; $seqFail = [int]$Matches[3]; $seqKnown = [int]$Matches[4]
		if ([int]$Matches[5] -gt 0) { $seqErr = $true }
	} else { $seqErr = $true }
	$md = @("", "## Sequence hunt", "", ("seed " + $Seed + ": " + $seqChains + " chains, new failures " + $seqFail + ", known (pending) " + $seqKnown + $(if ($seqErr) { "; COULD NOT RUN FULLY (see seq.log)" } else { "" })), "")
	foreach ($l in $seqLines) { if ($l -match '^(FAIL|PENDING|CANNOT)') { $md += ("- " + $l) } }
	Add-Content -Path (Join-Path $Out "FAILURES.md") -Value $md
	Add-Content -Path (Join-Path $Out "summary.txt") -Value ("sequence hunt: chains " + $seqChains + ", new " + $seqFail + ", known " + $seqKnown)
	Write-Host ("  sequence hunt: chains " + $seqChains + ", new " + $seqFail + ", known " + $seqKnown)
	if ($seqErr) { Write-Host ("  sequence hunt did not run cleanly: " + $seqLog) }
}
$promises = 0; $fails = 0; $new = 0; $known = 0; $parsed = $false
$sumFile = Join-Path $Out "summary.txt"
if (Test-Path $sumFile) {
	$st = (Get-Content $sumFile | Select-Object -First 1)
	if ($st -match '\((\d+) promises x') { $promises = [int]$Matches[1]; $parsed = $true }
	if ($st -match 'distinct failures (\d+) \(known (\d+), new (\d+)\)') { $fails = [int]$Matches[1]; $known = [int]$Matches[2]; $new = [int]$Matches[3] }
}
$result = "pass"; $exitCode = 0
if (-not $parsed -or $seqErr -or $code -gt 1) { $result = "error"; $exitCode = 2 }
elseif ($new -gt 0 -or $seqFail -gt 0) { $result = "fail"; $exitCode = 1 }
foreach ($k in 1..$Procs) {
	$log = Join-Path $Out ("shard-" + $k + ".log")
	if (Test-Path $log) {
		Get-Content $log | Where-Object { $_ -match '^(shard \d|estimate|walks:|stopped by|LOAD ERROR|set cache|resume:)' } | Select-Object -First 6 | ForEach-Object { Write-Host ("  " + $_) }
	}
	$err = $log + ".err"
	if ((Test-Path $err) -and ((Get-Item $err).Length -gt 0)) { Write-Host ("  shard " + $k + " wrote to stderr: " + $err) }
}
$known += $seqKnown
Write-Host ("GAUNTLET hunt result=" + $result + " promises=" + $promises + " failures=" + ($fails + $seqFail + $seqKnown) + " new=" + ($new + $seqFail) + " known=" + $known + " seq_chains=" + $seqChains + " seq_failures=" + $seqFail)
exit $exitCode

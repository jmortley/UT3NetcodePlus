param(
    [string]$UT3Root = 'C:\Program Files (x86)\Steam\steamapps\common\Unreal Tournament 3',
    [switch]$SkipBuild
)
$ErrorActionPreference='Stop'
if (-not $SkipBuild) { & (Join-Path $PSScriptRoot 'Build.ps1') -UT3Root $UT3Root -Tests }
$log=Join-Path $PSScriptRoot 'Logs\engine-tests.log'
$engineIni=Join-Path $PSScriptRoot 'BuildConfig\RuntimeEngine.ini'
$arguments="server `"DM-Deck?game=UTGame.UTDeathmatch?mutator=NetcodePlusUT3.NCMutator,NCTests.NCTestMutator?bIsLanMatch=true?numplay=0`" -engineini=`"$engineIni`" -multihome=127.0.0.1 -port=17998 -nosound -nosteam -nohomedir -noini -noautoiniupdate -unattended -nopause -nosplash -forcelogflush -abslog=`"$log`""
$process=Start-Process -FilePath (Join-Path $UT3Root 'Binaries\UT3.exe') -ArgumentList $arguments -WorkingDirectory (Join-Path $UT3Root 'Binaries') -WindowStyle Hidden -PassThru -RedirectStandardOutput "$log.console.txt" -RedirectStandardError "$log.stderr.txt"
Write-Output "Test server PID $($process.Id)"
if (-not $process.WaitForExit(45000)) { Stop-Process -Id $process.Id -Force; throw 'Test server timed out' }
$output=Get-Content -LiteralPath $log -Raw
$output -split "`n" | Where-Object { $_ -match '\[NC(Tests|Net)' } | Write-Output
if ($process.ExitCode -ne 0 -or $output -notmatch '\[NCTests\] PASS' -or $output -notmatch '\[NCTests\] FINISHED' -or
    $output -match 'pass=False|ScriptWarning|Accessed None|Critical:|Error:') { throw "Engine checks failed; see $log" }
Write-Output 'Engine checks passed; server exited.'

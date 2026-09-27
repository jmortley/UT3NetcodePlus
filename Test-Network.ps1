param(
    [string]$UT3Root = 'C:\Program Files (x86)\Steam\steamapps\common\Unreal Tournament 3',
    [switch]$SkipBuild,
    [switch]$StockBaseline,
    [ValidateSet('Shock','Sniper','StockSniper','Rockets')][string]$Weapon='Shock',
    [ValidateRange(0,200)][int]$LagMs=0,
    [ValidateRange(0,20)][int]$LossPercent=0
)
$ErrorActionPreference='Stop'
if (-not $SkipBuild) { & (Join-Path $PSScriptRoot 'Build.ps1') -UT3Root $UT3Root -Tests }
foreach ($package in @('NetcodePlusUT3','NCTests')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot "Build\$package.u"))) { throw "Missing compiled $package package" }
}
$binary=Join-Path $UT3Root 'Binaries\UT3.exe'
$binaryDir=Join-Path $UT3Root 'Binaries'
$config=Join-Path $PSScriptRoot 'BuildConfig\RuntimeEngine.ini'
$runName="network-lag$LagMs-loss$LossPercent"
if ($Weapon -ne 'Shock') { $runName="network-$($Weapon.ToLowerInvariant())-lag$LagMs-loss$LossPercent" }
if ($StockBaseline) { $runName='network-stock-baseline' }
$logs=Join-Path $PSScriptRoot ("Logs\$runName\" + (Get-Date).ToString('yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$processes=@()
$common="-engineini=`"$config`" -nohomedir -noini -noautoiniupdate -unattended -nopause -nosplash -nomovie -nostartupmovies -nosound -nosteam -forcelogflush -PktLag=$LagMs -PktLoss=$LossPercent"
try {
    $serverLog=Join-Path $logs 'server.log'
    $gameUrl='DM-Deck?game=NCTests.NCTestNetGame?mutator=NetcodePlusUT3.NCMutator,NCTests.NCTestNetMutator?bIsLanMatch=true?numplay=0'
    if ($Weapon -ne 'Shock') {
        $weaponMutators='NetcodePlusUT3.NCMutator,NCTests.NCTestWeaponNetMutator'
        if ($Weapon -eq 'StockSniper') { $weaponMutators='NCTests.NCTestWeaponNetMutator' }
        $gameUrl="DM-Deck?game=NCTests.NCTestWeaponNetGame?mutator=$weaponMutators`?bIsLanMatch=true?numplay=0?TestWeapon=$Weapon"
    }
    $gameUrl+="?TestLag=$LagMs`?TestLoss=$LossPercent"
    if ($StockBaseline) { $gameUrl='DM-Deck?game=UTGame.UTDeathmatch?mutator=NCTests.NCTestBaseline?bIsLanMatch=true?numplay=0' }
    $server=Start-Process -FilePath $binary -WorkingDirectory $binaryDir -ArgumentList "server `"$gameUrl`" -multihome=127.0.0.1 -port=17999 $common -abslog=`"$serverLog`"" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$serverLog.console.txt" -RedirectStandardError "$serverLog.stderr.txt"
    $processes+=$server
    $readyDeadline=(Get-Date).AddSeconds(15)
    $ready=$false
    do {
        if ($server.HasExited) { throw 'Network server exited during startup' }
        if ((Test-Path -LiteralPath $serverLog) -and (Select-String -LiteralPath $serverLog -SimpleMatch '[NCNet] server-ready' -Quiet)) { $ready=$true; break }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $readyDeadline)
    if (-not $ready) { throw 'Test mutator did not initialize on the network server' }
    foreach ($number in 1..2) {
        $clientLog=Join-Path $logs "client$number.log"
        $client=Start-Process -FilePath $binary -WorkingDirectory $binaryDir -ArgumentList "`"127.0.0.1:17999?Name=NCClient$number`" -windowed -ResX=640 -ResY=480 $common -abslog=`"$clientLog`"" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$clientLog.console.txt" -RedirectStandardError "$clientLog.stderr.txt"
        $processes+=$client
    }
    Write-Output "Network processes: $($processes.Id -join ', '); logs: $logs"
    if (-not $server.WaitForExit(60000)) { throw 'Network server timed out' }
    $serverText=Get-Content -LiteralPath $serverLog -Raw
    $serverText -split "`n" | Where-Object { $_ -match '\[NCNet\]|PktLag|PktLoss' } | Write-Output
    if ($serverText -notmatch '\[NCNet\] PASS' -or $serverText -match 'ScriptWarning|Accessed None|Critical:|Error:|pass=False') { throw 'Network assertions failed' }
    foreach ($number in 1..2) {
        $clientText=Get-Content -LiteralPath (Join-Path $logs "client$number.log") -Raw
        # UTEntryPlayerController emits this stock voice diagnostic before joining.
        # Preserve it in the log; exclude only this exact line from mod failures.
        $clientText=[regex]::Replace($clientText,'(?m)^Error: StopLocalVoiceProcessing: Ignoring stop request for non-owning user\r?\n','')
        if (-not $StockBaseline -and $clientText -notmatch '\[NCNetClient\] Result') { throw "Client $number did not report" }
        if ($clientText -match 'Critical:|ScriptWarning:.*\(Function (NetcodePlusUT3|NCTests)\.') { throw "Client $number failed" }
        $unexpectedErrors=@($clientText -split "`n" | Where-Object { $_ -match '^Error:' -and $_.Trim() -ne "Error: Can't start an online game that hasn't been created" })
        if ($unexpectedErrors.Count -gt 0) { throw "Client $number has unexpected native errors: $($unexpectedErrors -join ' / ')" }
        $diagnostics=@($clientText -split "`n" | Where-Object { $_ -match '^Error:|^ScriptWarning:' })
        if ($diagnostics.Count -gt 0) {
            Write-Output "Client $number retained $($diagnostics.Count) engine/stock-script diagnostics for baseline comparison:"
            $diagnostics | Write-Output
        }
    }
    Write-Output 'Two-client assertions passed. See retained stock diagnostics above; this is not a clean-log claim.'
}
finally {
    foreach ($ownedProcess in $processes) {
        if (-not $ownedProcess.HasExited) { Stop-Process -Id $ownedProcess.Id -Force }
    }
}

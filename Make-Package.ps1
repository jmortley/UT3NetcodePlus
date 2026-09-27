param([switch]$AllowKnownShockVisualMiss)
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$binary=Join-Path $root 'Build\NetcodePlusUT3.u'
if (-not (Test-Path -LiteralPath $binary)) { throw 'Build the package first.' }
$engineLog=Join-Path $root 'Logs\engine-tests.log'
if ((Get-Content -LiteralPath $engineLog -Raw) -notmatch '\[NCTests\] PASS') { throw 'Run the engine checks first.' }
$networkRuns=[ordered]@{}
$validationExceptions=@()
foreach ($case in @('lag80-loss5','lag0-loss0','sniper-lag80-loss5','sniper-lag0-loss0','rockets-lag80-loss5','rockets-lag0-loss0','flak-lag80-loss5','flak-lag0-loss0','stockflak-lag80-loss5','stock-baseline')) {
    $run=Get-ChildItem -LiteralPath (Join-Path $root "Logs\network-$case") -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($null -eq $run) { throw "Complete the $case network checks first." }
    $serverText=Get-Content -LiteralPath (Join-Path $run.FullName 'server.log') -Raw
    if ($serverText -notmatch '\[NCNet\] PASS') {
        # Explicit alpha-only exception for the retained cosmetic failure. Keep
        # Test-Network strict and package its FAILED log, never a fabricated pass.
        if (-not $AllowKnownShockVisualMiss -or $case -ne 'lag80-loss5') { throw "Complete the $case network checks first." }
        $clientResults=[regex]::Matches($serverText,'\[NCNet\] client-result player=\S+ predicted=4 (matched=2 retired=1 residual=0 ammo=42 released=True pass=False|matched=3 retired=1 residual=0 ammo=42 released=True pass=True)')
        $serverWeapons=[regex]::Matches($serverText,'\[NCNet\] server-weapon ammo=42 state=Active pending0=False pending1=False combo=True rewind=0\.0917 caught-up=4 catchup-seconds=0\.0167')
        $preImpact=[regex]::Matches($serverText,'\[NCNet\] pre-impact combo=True ammo=43 caught-up=3 catchup-seconds=0\.0600')
        $pings=[regex]::Matches($serverText,'\[NCNet\] ping samples=8 minimumRTT=0\.1833')
        if ($clientResults.Count -ne 2 -or $serverWeapons.Count -ne 2 -or $preImpact.Count -ne 2 -or $pings.Count -ne 2 -or
            $serverText -notmatch '\[NCNet\] FAILED clients=2' -or $serverText -match 'ScriptWarning|Accessed None|Critical:|Error:|\[NCNet\] TIMEOUT') {
            throw 'Shock failure differs from the reviewed cosmetic-only case; refusing the exception.'
        }
        foreach ($number in 1..2) {
            $clientText=Get-Content -LiteralPath (Join-Path $run.FullName "client$number.log") -Raw
            $clientText=[regex]::Replace($clientText,'(?m)^Error: StopLocalVoiceProcessing: Ignoring stop request for non-owning user\r?\n','')
            $unexpectedErrors=@($clientText -split "`n" | Where-Object { $_ -match '^Error:' -and $_.Trim() -ne "Error: Can't start an online game that hasn't been created" })
            if ($clientText -notmatch '\[NCNetClient\] Result predicted=4 matched=[23] retired=1 residual=0 ammo=42 state=Active' -or
                $clientText -match 'Critical:|ScriptWarning:.*\(Function (NetcodePlusUT3|NCTests)\.' -or $unexpectedErrors.Count -gt 0) {
                throw "Shock client $number does not meet the reviewed exception."
            }
        }
        $validationExceptions+='Shock lag/loss: cosmetic visual-match assertion FAILED; gameplay/ammo/release/cleanup checks passed. See VALIDATION.md and Evidence/lag80-loss5.'
        Write-Warning $validationExceptions[-1]
    }
    $networkRuns[$case]=$run.FullName
}
$stage=Join-Path $root ('Dist\Staging\' + (Get-Date).ToString('yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path (Join-Path $stage 'UTGame\Published\CookedPC\Script'),(Join-Path $stage 'UTGame\Config') -Force | Out-Null
Copy-Item -LiteralPath $binary -Destination (Join-Path $stage 'UTGame\Published\CookedPC\Script')
Copy-Item -LiteralPath (Join-Path $root 'Config\UTNetcodePlusUT3.ini') -Destination (Join-Path $stage 'UTGame\Config')
Copy-Item -LiteralPath (Join-Path $root 'Src') -Destination $stage -Recurse
Copy-Item -LiteralPath (Join-Path $root 'Config') -Destination $stage -Recurse
foreach ($name in @('Build.ps1','Test.ps1','Test-Network.ps1','Play.ps1','Make-Package.ps1','README.md','NOTICE.md','LICENSE','VALIDATION.md')) {
    Copy-Item -LiteralPath (Join-Path $root $name) -Destination $stage
}
$evidence=Join-Path $stage 'Evidence'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
Copy-Item -LiteralPath $engineLog -Destination $evidence
Copy-Item -LiteralPath (Join-Path $root 'Logs\compile.log.console.txt') -Destination $evidence
$regressionLog=Join-Path $root 'Logs\regressions-before-lifecycle-fix\engine-tests.log'
if (Test-Path -LiteralPath $regressionLog) {
    Copy-Item -LiteralPath $regressionLog -Destination (Join-Path $evidence 'regressions-before-lifecycle-fix.log')
}
foreach ($case in $networkRuns.Keys) {
    $destination=Join-Path $evidence $case
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($name in @('server.log','client1.log','client2.log')) {
        Copy-Item -LiteralPath (Join-Path $networkRuns[$case] $name) -Destination $destination
    }
}
# Keep investigated failures and comparison runs alongside final acceptance logs.
# A later pass must not erase evidence of an intermittent failure.
$diagnosticRuns=Join-Path $root 'Logs\diagnostic-runs'
if (Test-Path -LiteralPath $diagnosticRuns) {
    Copy-Item -LiteralPath $diagnosticRuns -Destination $evidence -Recurse
}
$hashes=@()
foreach ($source in (Get-ChildItem -LiteralPath (Join-Path $root 'Src') -File -Recurse | Sort-Object FullName)) {
    $hashes += [ordered]@{path=$source.FullName.Substring($root.Length+1).Replace('\','/'); sha256=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash}
}
$manifest=[ordered]@{name='NetcodePlusUT3 Weapon alpha'; builtFor='UT3 3809'; packageSha256=(Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash; validationExceptions=$validationExceptions; sources=$hashes}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'manifest.json') -Encoding utf8
$zip=Join-Path $root 'Dist\NetcodePlusUT3-Weapons-alpha.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
Write-Output $zip
Get-FileHash -LiteralPath $zip -Algorithm SHA256

$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$binary=Join-Path $root 'Build\NetcodePlusUT3.u'
if (-not (Test-Path -LiteralPath $binary)) { throw 'Build the package first.' }
$engineLog=Join-Path $root 'Logs\engine-tests.log'
if ((Get-Content -LiteralPath $engineLog -Raw) -notmatch '\[NCTests\] PASS') { throw 'Run the engine checks first.' }
$networkRuns=[ordered]@{}
foreach ($case in @('lag80-loss5','lag0-loss0','sniper-lag80-loss5','sniper-lag0-loss0','rockets-lag80-loss5','rockets-lag0-loss0','stock-baseline')) {
    $run=Get-ChildItem -LiteralPath (Join-Path $root "Logs\network-$case") -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($null -eq $run -or (Get-Content -LiteralPath (Join-Path $run.FullName 'server.log') -Raw) -notmatch '\[NCNet\] PASS') { throw "Complete the $case network checks first." }
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
$manifest=[ordered]@{name='NetcodePlusUT3 Weapon alpha'; builtFor='UT3 3809'; packageSha256=(Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash; sources=$hashes}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'manifest.json') -Encoding utf8
$zip=Join-Path $root 'Dist\NetcodePlusUT3-Weapons-alpha.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
Write-Output $zip
Get-FileHash -LiteralPath $zip -Algorithm SHA256

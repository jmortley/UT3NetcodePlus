$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$binary=Join-Path $root 'Build\NetcodePlusUT3.u'
if (-not (Test-Path -LiteralPath $binary)) { throw 'Build the package first.' }
$engineLog=Join-Path $root 'Logs\engine-tests.log'
if ((Get-Content -LiteralPath $engineLog -Raw) -notmatch '\[NCTests\] PASS') { throw 'Run the engine checks first.' }
$networkRun=Get-ChildItem -LiteralPath (Join-Path $root 'Logs\network-lag80-loss5') -Directory | Sort-Object Name -Descending | Select-Object -First 1
$localRun=Get-ChildItem -LiteralPath (Join-Path $root 'Logs\network-lag0-loss0') -Directory | Sort-Object Name -Descending | Select-Object -First 1
$baselineRun=Get-ChildItem -LiteralPath (Join-Path $root 'Logs\network-stock-baseline') -Directory | Sort-Object Name -Descending | Select-Object -First 1
foreach ($run in @($networkRun,$localRun,$baselineRun)) {
    if ($null -eq $run -or (Get-Content -LiteralPath (Join-Path $run.FullName 'server.log') -Raw) -notmatch '\[NCNet\] PASS') { throw 'Complete the network and stock baseline checks first.' }
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
New-Item -ItemType Directory -Path (Join-Path $evidence 'stock-baseline'),(Join-Path $evidence 'lag80-loss5'),(Join-Path $evidence 'lag0-loss0') -Force | Out-Null
Copy-Item -LiteralPath $engineLog -Destination $evidence
Copy-Item -LiteralPath (Join-Path $root 'Logs\compile.log.console.txt') -Destination $evidence
foreach ($name in @('server.log','client1.log','client2.log')) {
    Copy-Item -LiteralPath (Join-Path $baselineRun.FullName $name) -Destination (Join-Path $evidence 'stock-baseline')
    Copy-Item -LiteralPath (Join-Path $networkRun.FullName $name) -Destination (Join-Path $evidence 'lag80-loss5')
    Copy-Item -LiteralPath (Join-Path $localRun.FullName $name) -Destination (Join-Path $evidence 'lag0-loss0')
}
$hashes=@()
foreach ($source in (Get-ChildItem -LiteralPath (Join-Path $root 'Src') -File -Recurse | Sort-Object FullName)) {
    $hashes += [ordered]@{path=$source.FullName.Substring($root.Length+1).Replace('\','/'); sha256=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash}
}
$manifest=[ordered]@{name='NetcodePlusUT3 Shock alpha'; builtFor='UT3 3809'; packageSha256=(Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash; sources=$hashes}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'manifest.json') -Encoding utf8
$zip=Join-Path $root 'Dist\NetcodePlusUT3-Shock-alpha.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
Write-Output $zip
Get-FileHash -LiteralPath $zip -Algorithm SHA256

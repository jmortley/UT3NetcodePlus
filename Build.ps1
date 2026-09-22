param(
    [string]$UT3Root = 'C:\Program Files (x86)\Steam\steamapps\common\Unreal Tournament 3',
    [switch]$Tests
)
$ErrorActionPreference = 'Stop'
$portRoot = $PSScriptRoot
$outDir = Join-Path $portRoot 'Build'
$configDir = Join-Path $portRoot 'BuildConfig'
$logDir = Join-Path $portRoot 'Logs'
New-Item -ItemType Directory -Path $outDir,$configDir,$logDir -Force | Out-Null
$packages = @('NetcodePlusUT3')
if ($Tests) { $packages += 'NCTests' }
$editor = Get-Content -LiteralPath (Join-Path $UT3Root 'UTGame\Config\UTEditor.ini') -Raw
$editor = [regex]::Replace($editor, '(?ms)^\[ModPackages\].*?(?=^\[|\z)', '')
$editor += "`r`n[ModPackages]`r`nModPackagesInPath=$portRoot\Src`r`nModOutputDir=$outDir`r`n"
foreach ($package in $packages) { $editor += "ModPackages=$package`r`n" }
$editorIni = Join-Path $configDir 'UTEditor.ini'
[IO.File]::WriteAllText($editorIni,$editor,[Text.Encoding]::ASCII)
$engine = Get-Content -LiteralPath (Join-Path $UT3Root 'UTGame\Config\UTEngine.ini') -Raw
$engine = $engine.Replace('[Core.System]',"[Core.System]`r`nPaths=$outDir")
$engineIni = Join-Path $configDir 'UTEngine.ini'
[IO.File]::WriteAllText($engineIni,$engine,[Text.Encoding]::ASCII)
$runtimeEngine = $engine.Replace('[Core.System]',"[Core.System]`r`nSeekFreePCPaths=$outDir")
[IO.File]::WriteAllText((Join-Path $configDir 'RuntimeEngine.ini'),$runtimeEngine,[Text.Encoding]::ASCII)
$started = Get-Date
foreach ($package in $packages) {
    $outputPath = [IO.Path]::GetFullPath((Join-Path $outDir "$package.u"))
    if (-not $outputPath.StartsWith(([IO.Path]::GetFullPath($outDir) + '\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Output outside build directory' }
    if (Test-Path -LiteralPath $outputPath) {
        $archive = Join-Path $portRoot ('BuildArchive\' + $started.ToString('yyyyMMdd-HHmmss-fff'))
        New-Item -ItemType Directory -Path $archive -Force | Out-Null
        Move-Item -LiteralPath $outputPath -Destination (Join-Path $archive "$package.u")
    }
}
$log = Join-Path $logDir 'compile.log'
$arguments = "make -editorini=`"$editorIni`" -engineini=`"$engineIni`" -nohomedir -noini -noautoiniupdate -unattended -nopause -nosplash -forcelogflush -abslog=`"$log`""
$process = Start-Process -FilePath (Join-Path $UT3Root 'Binaries\UT3.com') -ArgumentList $arguments -WorkingDirectory (Join-Path $UT3Root 'Binaries') -WindowStyle Hidden -PassThru -RedirectStandardOutput "$log.console.txt" -RedirectStandardError "$log.stderr.txt"
if (-not $process.WaitForExit(45000)) { Stop-Process -Id $process.Id -Force; throw 'UT3 compiler timed out' }
$output = Get-Content -LiteralPath $log -Raw
if ($process.ExitCode -ne 0 -or $output -notmatch 'Success - 0 error\(s\), 0 warning\(s\)') {
    Get-Content -LiteralPath "$log.console.txt" -Tail 55
    throw "UT3 script compilation failed; see $log"
}
foreach ($package in $packages) {
    $file = Get-Item -LiteralPath (Join-Path $outDir "$package.u")
    if ($file.LastWriteTime -lt $started) { throw "No fresh output for $package" }
    Write-Output "Built $($file.Name): $($file.Length) bytes"
}
Write-Output 'Compiler: 0 errors, 0 warnings. Full log retains installed stock-package NetIndex diagnostics.'

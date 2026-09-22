param(
    [string]$UT3Root='C:\Program Files (x86)\Steam\steamapps\common\Unreal Tournament 3',
    [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$Map='DM-Deck'
)
$ErrorActionPreference='Stop'
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Build\NetcodePlusUT3.u'))) { & (Join-Path $PSScriptRoot 'Build.ps1') -UT3Root $UT3Root }
$engineIni=Join-Path $PSScriptRoot 'BuildConfig\RuntimeEngine.ini'
if (-not (Test-Path -LiteralPath $engineIni)) { throw 'Run Build.ps1 first to prepare the local engine config.' }
$log=Join-Path $PSScriptRoot 'Logs\play.log'
$arguments="`"$Map`?game=UTGame.UTDeathmatch?mutator=NetcodePlusUT3.NCMutator?numplay=4`" -engineini=`"$engineIni`" -nohomedir -noini -noautoiniupdate -nomovie -nostartupmovies -windowed -ResX=1280 -ResY=720 -abslog=`"$log`""
# This launcher is explicitly for a user-started interactive game, not a test helper.
Start-Process -FilePath (Join-Path $UT3Root 'Binaries\UT3.exe') -ArgumentList $arguments -WorkingDirectory (Join-Path $UT3Root 'Binaries')

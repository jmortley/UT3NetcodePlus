// Owner-only automation for an actual remote client. Never included in release.
class NCTestClientDriver extends Info;

var bool bReported, bPassed;
var int Stage, VisualCount, MatchCount;
var float StageAt;
var float NextDebugAt;
var NCShockRifle W;
var int TestLag, TestLoss;
replication
{
    if (Role == ROLE_Authority) TestLag, TestLoss;
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    LogInternal("[NCNetClient] driver-spawn role=" $ Role $ " owner=" $ Owner);
}

simulated event Tick(float DeltaTime)
{
    local PlayerController PC;
    if (Role == ROLE_Authority || Stage >= 5) return;
    PC=PlayerController(Owner);
    if (WorldInfo.TimeSeconds >= NextDebugAt)
    {
        NextDebugAt=WorldInfo.TimeSeconds+5;
        if (PC != None && PC.Pawn != None) LogInternal("[NCNetClient] status stage=" $ Stage $ " pawn=" $ PC.Pawn $ " weapon=" $ PC.Pawn.Weapon);
        else LogInternal("[NCNetClient] status stage=" $ Stage $ " owner=" $ Owner);
    }
    if (PC == None || !PC.IsLocalPlayerController() || PC.Pawn == None) return;
    W=NCShockRifle(PC.Pawn.Weapon);
    if (W == None) return;
    if (Stage == 0)
    {
        if (!W.IsInState('Active')) return;
        Stage=1; StageAt=WorldInfo.TimeSeconds;
        LogInternal("[NCNetClient] simulation " $ ConsoleCommand("Net PktLag=" $ TestLag $ " PktLoss=" $ TestLoss));
        LogInternal("[NCNetClient] Ready role=" $ W.Role $ " prediction=" $ W.bPredictionEnabled);
    }
    else if (Stage == 1 && WorldInfo.TimeSeconds-StageAt > 2.0)
    {
        PC.SetRotation(rot(0,0,0));
        W.StartFire(1);
        Stage=2; StageAt=WorldInfo.TimeSeconds;
    }
    else if (Stage == 2 && WorldInfo.TimeSeconds-StageAt > 1.3)
    {
        W.StopFire(1);
        Stage=3; StageAt=WorldInfo.TimeSeconds;
    }
    else if (Stage == 3 && WorldInfo.TimeSeconds-StageAt > 1.0)
    {
        W.StartFire(0); W.StopFire(0);
        Stage=4; StageAt=WorldInfo.TimeSeconds;
    }
    else if (Stage == 4 && WorldInfo.TimeSeconds-StageAt > 1.5)
    {
        W.PruneVisuals();
        LogInternal("[NCNetClient] Result predicted=" $ W.PredictedVisualCount $ " matched=" $ W.MatchedVisualCount
            $ " residual=" $ W.Visuals.Length $ " ammo=" $ W.AmmoCount $ " state=" $ W.GetStateName());
        ServerResult(W.PredictedVisualCount,W.MatchedVisualCount,W.Visuals.Length,W.AmmoCount,!W.PendingFire(0) && !W.PendingFire(1));
        Stage=5;
    }
}

reliable server function ServerResult(int Created, int Matched, int Residual, int Ammo, bool bReleased)
{
    if (bReported) return;
    VisualCount=Created; MatchCount=Matched;
    bPassed=Created == 3 && Matched == 3 && Residual == 0 && bReleased;
    bReported=true;
    LogInternal("[NCNet] client-result player=" $ Owner $ " predicted=" $ Created $ " matched=" $ Matched
        $ " residual=" $ Residual $ " ammo=" $ Ammo $ " released=" $ bReleased $ " pass=" $ bPassed);
}

reliable client function ClientQuit()
{
    ConsoleCommand("quit");
}

defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    bOnlyRelevantToOwner=true
    bSkipActorPropertyReplication=false
    bAlwaysTick=true
    NetUpdateFrequency=10
}

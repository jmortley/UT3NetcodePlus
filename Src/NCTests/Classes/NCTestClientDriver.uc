// Owner-only automation for an actual remote client. Never included in release.
class NCTestClientDriver extends Info;

var bool bReported, bPassed, bPrepared, bComboVerified;
var int Stage, VisualCount, MatchCount;
var int OpenFlightCatchupCount;
var float OpenFlightCatchupSeconds;
var float StageAt;
var float NextDebugAt;
var NCShockRifle W;
var int TestLag, TestLoss;
var bool bDelayedShock;
replication
{
    if (Role == ROLE_Authority) TestLag, TestLoss, bDelayedShock;
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    LogInternal("[NCNetClient] driver-spawn role=" $ Role $ " owner=" $ Owner);
}

simulated event Tick(float DeltaTime)
{
    local PlayerController PC;
    local int LateMatches;
    if (Role == ROLE_Authority || Stage >= 8) return;
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
    // Let all eight ping samples turn over after both net drivers enable lag.
    else if (Stage == 1 && WorldInfo.TimeSeconds-StageAt > 4.5)
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
    else if (Stage == 3 && WorldInfo.TimeSeconds-StageAt > (bDelayedShock ? 2.0 : 1.0))
    {
        W.StartFire(0); W.StopFire(0);
        Stage=4; StageAt=WorldInfo.TimeSeconds;
    }
    else if (Stage == 4 && WorldInfo.TimeSeconds-StageAt > 1.5)
    {
        Stage=5;
        ServerPrepareImpact();
    }
    else if (Stage == 6 && WorldInfo.TimeSeconds-StageAt > 0.3)
    {
        W.StartFire(1); W.StopFire(1);
        Stage=7; StageAt=WorldInfo.TimeSeconds;
    }
    else if (Stage == 7 && WorldInfo.TimeSeconds-StageAt > 1.5)
    {
        W.PruneVisuals();
        if (NCTestDelayedShock(W) != None) LateMatches=NCTestDelayedShock(W).LateVisualMatchCount;
        LogInternal("[NCNetClient] Result predicted=" $ W.PredictedVisualCount $ " matched=" $ W.MatchedVisualCount
            $ " retired=" $ W.RetiredVisualCount $ " residual=" $ W.Visuals.Length $ " ammo=" $ W.AmmoCount $ " state=" $ W.GetStateName());
        ServerResult(W.PredictedVisualCount,W.MatchedVisualCount,W.RetiredVisualCount,W.Visuals.Length,W.AmmoCount,!W.PendingFire(0) && !W.PendingFire(1),LateMatches);
        Stage=8;
    }
}

reliable server function ServerPrepareImpact()
{
    local PlayerController PC;
    local NCTestWorldWall Wall;
    if (bPrepared) return;
    bPrepared=true;
    PC=PlayerController(Owner);
    W=NCShockRifle(PC.Pawn.Weapon);
    bComboVerified=W.bWasACombo && W.AmmoCount == W.MaxAmmoCount-7;
    OpenFlightCatchupCount=W.CaughtUpCoreCount;
    OpenFlightCatchupSeconds=W.LastCoreCatchup;
    // Server-only obstruction: the local visual remains alive until confirmation.
    Wall=Spawn(class'NCTestWorldWall',,,W.GetPhysicalFireStartLoc()+vect(40,0,0));
    bComboVerified=bComboVerified && Wall != None;
    LogInternal("[NCNet] pre-impact combo=" $ bComboVerified $ " ammo=" $ W.AmmoCount
        $ " caught-up=" $ OpenFlightCatchupCount $ " catchup-seconds=" $ OpenFlightCatchupSeconds);
    ClientImpactReady();
}

reliable client function ClientImpactReady()
{
    if (Stage != 5) return;
    Stage=6; StageAt=WorldInfo.TimeSeconds;
}

reliable server function ServerResult(int Created, int Matched, int Retired, int Residual, int Ammo, bool bReleased, int LateMatches)
{
    if (bReported) return;
    VisualCount=Created; MatchCount=Matched;
    // At low RTT the final core can be matched briefly before its retirement arrives.
    bPassed=Created == 4 && Matched >= 3 && Matched <= 4 && Retired <= 1
        && (Matched == 4 || Retired == 1) && Residual == 0 && bReleased && bComboVerified;
    if (TestLag >= 60) bPassed=bPassed && Matched == 3 && Retired == 1;
    if (bDelayedShock) bPassed=bPassed && LateMatches == 3;
    bReported=true;
    LogInternal("[NCNet] client-result player=" $ Owner $ " predicted=" $ Created $ " matched=" $ Matched
        $ " retired=" $ Retired $ " residual=" $ Residual $ " ammo=" $ Ammo $ " released=" $ bReleased $ " pass=" $ bPassed);
    if (bDelayedShock) LogInternal("[NCNet] delayed-handoff matches-after-750ms=" $ LateMatches $ " pass=" $ bPassed);
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

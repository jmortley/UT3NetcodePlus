// Real owning-client calls through inherited UT3 firing and loading states.
class NCTestWeaponClientDriver extends Info;

var bool bReported, bPassed, bStockSniper;
var int Stage, TestLag, TestLoss;
var float StageAt;
var UTWeapon W;

replication
{
    if (Role == ROLE_Authority) TestLag, TestLoss, bStockSniper;
}

simulated event Tick(float DeltaTime)
{
    local PlayerController PC;
    if (Role == ROLE_Authority || Stage >= 8) return;
    PC=PlayerController(Owner);
    if (PC == None || !PC.IsLocalPlayerController() || PC.Pawn == None) return;
    W=UTWeapon(PC.Pawn.Weapon);
    if (W == None) return;
    if (bStockSniper)
    {
        if (W.Class != class'UTWeap_SniperRifle') return;
    }
    else if (NCSniperRifle(W) == None && NCRocketLauncher(W) == None) return;
    if (Stage == 0)
    {
        if (!W.IsInState('Active')) return;
        Stage=1; StageAt=WorldInfo.TimeSeconds;
        W.bDebugWeapon=true;
        LogInternal("[NCNetClient] simulation " $ ConsoleCommand("Net PktLag=" $ TestLag $ " PktLoss=" $ TestLoss));
        LogInternal("[NCNetClient] Ready weapon=" $ W.Class $ " pawn=" $ PC.Pawn.Class);
    }
    else if (Stage == 1 && WorldInfo.TimeSeconds-StageAt > 4.5)
    {
        PC.SetRotation(rot(0,0,0));
        LogWeaponState("primary-start");
        W.StartFire(0);
        if (NCRocketLauncher(W) != None) W.StopFire(0);
        Stage=2; StageAt=WorldInfo.TimeSeconds;
    }
    else if (Stage == 2 && WorldInfo.TimeSeconds-StageAt > 2.8)
    {
        LogWeaponState("primary-stop-before");
        W.StopFire(0);
        LogWeaponState("primary-stop-after");
        Stage=3; StageAt=WorldInfo.TimeSeconds;
    }
    else if (Stage == 3 && WorldInfo.TimeSeconds-StageAt > 1.5)
    {
        if (NCRocketLauncher(W) != None)
        {
            W.StartFire(1);
            Stage=4; StageAt=WorldInfo.TimeSeconds;
        }
        else ReportResult(3);
    }
    else if (Stage == 4 && WorldInfo.TimeSeconds-StageAt > 2.5)
    {
        W.StopFire(1);
        Stage=5; StageAt=WorldInfo.TimeSeconds;
    }
    else if (Stage == 5 && WorldInfo.TimeSeconds-StageAt > 2.0) ReportResult(4);
}

simulated function ReportResult(int ExpectedAmmoSpent)
{
    local bool Passed;
    LogWeaponState("report");
    Passed=W.AmmoCount == W.MaxAmmoCount-ExpectedAmmoSpent && W.IsInState('Active')
        && !W.PendingFire(0) && !W.PendingFire(1);
    if (bStockSniper) Passed=Passed && W.Class == class'UTWeap_SniperRifle';
    else Passed=Passed && NCPawn(W.Instigator) != None;
    LogInternal("[NCNetClient] Result weapon=" $ W.Class $ " ammo=" $ W.AmmoCount
        $ " state=" $ W.GetStateName() $ " pass=" $ Passed);
    ServerResult(Passed,W.AmmoCount);
    Stage=8;
}

simulated function LogWeaponState(string EventName)
{
    LogInternal("[NCNetClient] " $ EventName $ " time=" $ WorldInfo.TimeSeconds
        $ " elapsed=" $ (WorldInfo.TimeSeconds-StageAt) $ " weapon=" $ W
        $ " ammo=" $ W.AmmoCount $ " state=" $ W.GetStateName()
        $ " pending=" $ W.PendingFire(0) $ "/" $ W.PendingFire(1)
        $ " interval=" $ W.GetFireInterval(0) $ " timer=" $ W.GetTimerCount('RefireCheckTimer')
        $ "/" $ W.GetTimerRate('RefireCheckTimer'));
}

reliable server function ServerResult(bool Passed, int ClientAmmo)
{
    if (bReported) return;
    bReported=true; bPassed=Passed;
    LogInternal("[NCNet] client-result player=" $ Owner $ " ammo=" $ ClientAmmo $ " pass=" $ Passed);
}

reliable client function ClientQuit() { ConsoleCommand("quit"); }

defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    bOnlyRelevantToOwner=true
    bSkipActorPropertyReplication=false
    bAlwaysTick=true
    NetUpdateFrequency=10
}

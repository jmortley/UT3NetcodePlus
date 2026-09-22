class NCTestNetMutator extends UTMutator;

var array<NCTestClientDriver> Drivers;
var bool bEnding;
var float StartedAt;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    StartedAt=WorldInfo.TimeSeconds;
    SetTimer(0.25,true,'Service');
    LogInternal("[NCNet] server-ready");
    LogInternal("[NCNet] simulation " $ ConsoleCommand("Net PktLag=" $ NCTestNetGame(WorldInfo.Game).TestLag $ " PktLoss=" $ NCTestNetGame(WorldInfo.Game).TestLoss));
}

function Service()
{
    local PlayerController PC;
    local NCTestClientDriver D;
    local NCShockRifle W;
    local NCRewind N;
    local int i, Finished;
    local bool Passed;
    if (bEnding) return;
    foreach WorldInfo.AllControllers(class'PlayerController',PC)
    {
        if (PC.Pawn == None && PC.PlayerReplicationInfo != None && !PC.PlayerReplicationInfo.bOnlySpectator)
            WorldInfo.Game.RestartPlayer(PC);
        if (PC.Pawn == None || PC.IsLocalPlayerController()) continue;
        for (i=0;i<Drivers.Length;i++) if (Drivers[i].Owner == PC) break;
        if (i < Drivers.Length) continue;
        W=NCShockRifle(PC.Pawn.Weapon);
        if (W == None) continue;
        PC.Pawn.SetPhysics(PHYS_Flying);
        PC.GotoState('PlayerFlying');
        PC.ClientGotoState('PlayerFlying');
        PC.Pawn.SetLocation(vect(0,0,10000)+vect(0,3000,0)*Drivers.Length);
        PC.Pawn.Velocity=vect(0,0,0);
        PC.Pawn.Health=1000;
        W.AmmoCount=W.MaxAmmoCount;
        PC.ClientSetRotation(rot(0,0,0));
        D=Spawn(class'NCTestClientDriver',PC);
        if (D != None)
        {
            D.TestLag=NCTestNetGame(WorldInfo.Game).TestLag;
            D.TestLoss=NCTestNetGame(WorldInfo.Game).TestLoss;
            Drivers.AddItem(D); LogInternal("[NCNet] registered " $ PC);
        }
    }
    Passed=true;
    N=class'NCRewind'.static.Find(self);
    for (i=0;i<Drivers.Length;i++)
    {
        if (!Drivers[i].bReported) continue;
        Finished++;
        Passed=Passed && Drivers[i].bPassed;
    }
    if (Finished >= 2)
    {
        for (i=0;i<Drivers.Length;i++)
        {
            PC=PlayerController(Drivers[i].Owner);
            W=NCShockRifle(PC.Pawn.Weapon);
            // Three cores, one beam, and the stock three-ammo combo surcharge.
            Passed=Passed && W != None && W.AmmoCount == W.MaxAmmoCount-7 && W.bWasACombo && !W.PendingFire(0) && !W.PendingFire(1);
            LogInternal("[NCNet] server-weapon ammo=" $ W.AmmoCount $ " state=" $ W.GetStateName()
                $ " pending0=" $ W.PendingFire(0) $ " pending1=" $ W.PendingFire(1) $ " combo=" $ W.bWasACombo $ " rewind=" $ N.RewindFor(PC.Pawn));
            Drivers[i].ClientQuit();
        }
        for (i=0;i<N.Pings.Length;i++)
        {
            Passed=Passed && N.Pings[i].SampleCount >= 3;
            if (NCTestNetGame(WorldInfo.Game).TestLag > 0)
                Passed=Passed && N.Pings[i].MinimumRTT >= float(NCTestNetGame(WorldInfo.Game).TestLag)*0.001;
            LogInternal("[NCNet] ping samples=" $ N.Pings[i].SampleCount $ " minimumRTT=" $ N.Pings[i].MinimumRTT);
        }
        if (Passed) LogInternal("[NCNet] PASS clients=" $ Finished);
        else LogInternal("[NCNet] FAILED clients=" $ Finished);
        bEnding=true; SetTimer(1.0,false,'Finish');
    }
    else if (WorldInfo.TimeSeconds-StartedAt > 50.0)
    {
        LogInternal("[NCNet] TIMEOUT clients=" $ Drivers.Length $ " finished=" $ Finished);
        for (i=0;i<Drivers.Length;i++) Drivers[i].ClientQuit();
        bEnding=true; SetTimer(1.0,false,'Finish');
    }
}

function Finish() { ConsoleCommand("quit"); }
defaultproperties
{
    bExportMenuData=false
}

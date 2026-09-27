class NCTestWeaponNetMutator extends UTMutator;

var array<NCTestWeaponClientDriver> Drivers;
var bool bEnding, bStockSniper;
var float StartedAt;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    bStockSniper=NCTestWeaponNetGame(WorldInfo.Game).TestWeapon ~= "StockSniper";
    StartedAt=WorldInfo.TimeSeconds;
    SetTimer(0.25,true,'Service');
    LogInternal("[NCNet] server-ready");
    LogInternal("[NCNet] simulation " $ ConsoleCommand("Net PktLag=" $ NCTestNetGame(WorldInfo.Game).TestLag $ " PktLoss=" $ NCTestNetGame(WorldInfo.Game).TestLoss));
}

function Service()
{
    local PlayerController PC;
    local NCTestWeaponClientDriver D;
    local UTWeapon W;
    local NCSniperRifle Sniper;
    local NCRocketLauncher Rockets;
    local NCRewind N;
    local NCPawnHistory History;
    local vector HeadPosition;
    local float HeadRadius;
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
        W=UTWeapon(PC.Pawn.Weapon);
        if (W == None) continue;
        if (bStockSniper)
        {
            if (W.Class != class'UTWeap_SniperRifle') continue;
        }
        else if (NCSniperRifle(W) == None && NCRocketLauncher(W) == None) continue;
        PC.Pawn.SetPhysics(PHYS_Flying);
        PC.GotoState('PlayerFlying'); PC.ClientGotoState('PlayerFlying');
        PC.Pawn.SetLocation(vect(0,0,10000)+vect(0,3000,0)*Drivers.Length);
        PC.Pawn.Velocity=vect(0,0,0); PC.Pawn.Health=1000;
        W.AmmoCount=W.MaxAmmoCount;
        W.bDebugWeapon=true;
        PC.ClientSetRotation(rot(0,0,0));
        D=Spawn(class'NCTestWeaponClientDriver',PC);
        if (D != None)
        {
            D.TestLag=NCTestNetGame(WorldInfo.Game).TestLag;
            D.TestLoss=NCTestNetGame(WorldInfo.Game).TestLoss;
            D.bStockSniper=bStockSniper;
            Drivers.AddItem(D);
            LogInternal("[NCNet] registered " $ PC $ " weapon=" $ W.Class $ " pawn=" $ PC.Pawn.Class);
        }
    }
    Passed=true;
    if (!bStockSniper) N=class'NCRewind'.static.Find(self);
    for (i=0;i<Drivers.Length;i++)
    {
        if (!Drivers[i].bReported) continue;
        Finished++;
        Passed=Passed && Drivers[i].bPassed;
    }
    if (Finished >= 2)
    {
        if (!bStockSniper) N.RecordPawns();
        for (i=0;i<Drivers.Length;i++)
        {
            PC=PlayerController(Drivers[i].Owner);
            W=UTWeapon(PC.Pawn.Weapon);
            Passed=Passed && W != None && W.IsInState('Active') && !W.PendingFire(0) && !W.PendingFire(1);
            if (!bStockSniper) Passed=Passed && NCPawn(PC.Pawn) != None;
            Sniper=NCSniperRifle(W); Rockets=NCRocketLauncher(W);
            if (bStockSniper)
            {
                Passed=Passed && W.Class == class'UTWeap_SniperRifle' && W.AmmoCount == W.MaxAmmoCount-3;
                LogInternal("[NCNet] stock sniper ammo=" $ W.AmmoCount $ " state=" $ W.GetStateName()
                    $ " pending=" $ W.PendingFire(0) $ "/" $ W.PendingFire(1));
            }
            else if (Sniper != None)
            {
                Passed=Passed && W.AmmoCount == W.MaxAmmoCount-3;
                if (NCTestNetGame(WorldInfo.Game).TestLag >= 60) Passed=Passed && Sniper.RewoundShotCount == 3;
                History=N.FindHistory(UTPawn(PC.Pawn));
                Passed=Passed && History != None;
                if (History != None)
                    Passed=Passed && History.HeadAtTime(WorldInfo.TimeSeconds-N.RewindFor(PC.Pawn),HeadPosition,HeadRadius);
                LogInternal("[NCNet] sniper ammo=" $ W.AmmoCount $ " rewound=" $ Sniper.RewoundShotCount);
            }
            else if (Rockets != None)
            {
                Passed=Passed && W.AmmoCount == W.MaxAmmoCount-4 && Rockets.SpawnedRocketCount == 4;
                if (NCTestNetGame(WorldInfo.Game).TestLag >= 60)
                    Passed=Passed && Rockets.CaughtUpRocketCount == 4 && Abs(Rockets.LastRocketCatchup-0.06) < 0.001;
                LogInternal("[NCNet] rockets ammo=" $ W.AmmoCount $ " spawned=" $ Rockets.SpawnedRocketCount
                    $ " caught-up=" $ Rockets.CaughtUpRocketCount $ " catchup-seconds=" $ Rockets.LastRocketCatchup);
            }
            else Passed=false;
            Drivers[i].ClientQuit();
        }
        if (!bStockSniper)
        {
            for (i=0;i<N.Pings.Length;i++)
            {
                Passed=Passed && N.Pings[i].SampleCount >= 3;
                if (NCTestNetGame(WorldInfo.Game).TestLag > 0)
                    Passed=Passed && N.Pings[i].MinimumRTT >= float(NCTestNetGame(WorldInfo.Game).TestLag)*0.001;
                LogInternal("[NCNet] ping samples=" $ N.Pings[i].SampleCount $ " minimumRTT=" $ N.Pings[i].MinimumRTT);
            }
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
defaultproperties { bExportMenuData=false }
